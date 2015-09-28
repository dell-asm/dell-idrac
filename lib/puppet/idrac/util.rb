require 'rexml/document'

include REXML
require 'pty'

module Puppet
  module Idrac
    class ConfigError < Exception; end
    class JobClearError < Exception; end
    class ShutdownError < Exception; end
    class PendingChangesError < Exception; end
    module Util
      # FIXME: asm/device_management is dependent on asm-deployer, which should be eliminated as a dependency for this module
      def self.get_transport
        require 'asm/device_management'
        @transport ||= begin
          ASM::DeviceManagement.parse_device_config(Puppet[:certname])
        end
      end

      def self.view_disks(type=:virtual)
        output = ASM::WsMan.invoke(get_transport, 'enumerate', "http://schemas.dmtf.org/wbem/wscim/1/cim-schema/2/root/dcim/DCIM_#{type.capitalize}DiskView")
        #Response will return multiple base nodes, which will error out with Nokogiri, so we wrap response output
        xml = Nokogiri::XML("<Envelopes>#{output}</Envelopes>")
        #Name spaces makes data hard to search through later
        xml.remove_namespaces!
        return xml
      end

      def self.virtual_disks_ready?
        response = view_disks
        response.xpath('//DCIM_VirtualDiskView').each do |disk|
          current_op = disk.at_xpath('//OperationName').content
          unless current_op =~ /None|Background/
            fqdd = disk.at_xpath('FQDD').content
            percent = disk.at_xpath('OperationPercentComplete').content
            Puppet.info("Virtual disk #{fqdd} is currently performing operation #{current_op} at #{percent} percent completion. Waiting...")
            return false
          end
        end
        true
      end

      #This method waits for any running jobs to complete, and raises an exception after 5 minutes
      def self.wait_for_running_jobs
        require 'asm/wsman'
        Puppet.info("Checking for running jobs")
        10.times do
          schema ="http://schemas.dell.com/wbem/wscim/1/cim-schema/2/DCIM_LifeCycleJob"
          out = ASM::WsMan.invoke(get_transport, 'enumerate', schema)
          xml = Nokogiri::XML("<results>#{out}</results>")
          xml.remove_namespaces!
          running_jobs = xml.xpath("//DCIM_LifeCycleJob").find_all{|x| x.at_xpath("JobStatus[text()='Running']")}.collect{|x| x.at_xpath("InstanceID").text}
          if running_jobs.empty?
            Puppet.info("No running jobs.  Continuing execution...")
            return
          else
            Puppet.debug("Job(s) still running: #{running_jobs}.")
            Puppet.info("Waiting for currently running jobs to complete...")
            sleep 30
          end
        end
        raise("Timed out waiting for running jobs to complete.")
      end

      # Waits for running jobs, and clears the job queue(with reset if necessary) if we time out waiting for it to be empty
      def self.wait_or_clear_running_jobs(allowReset=true)
        begin
          wait_for_running_jobs
        rescue
          if allowReset
            clear_job_queue_with_retry
          else
            clear_job_queue
          end
        end
      end

      #Clears the job queue and waits for it to be empty.  Raises a JobClearError from wait_for_jobs_clear if the job queue isn't empty after 2 minutes.
      def self.clear_job_queue
        Puppet.debug("Clearing Job Queue")
        tries = 1
        begin
          schema = "http://schemas.dell.com/wbem/wscim/1/cim-schema/2/DCIM_JobService?CreationClassName=\"DCIM_JobService\",SystemName=\"Idrac\",Name=\"JobService\",SystemCreationClassName=\"DCIM_ComputerSystem\""
          options = {:props=>{'JobID'=> 'JID_CLEARALL'}, :selector => '//n1:ReturnValue', :logger => Puppet}
          resp = ASM::WsMan.invoke(get_transport, 'DeleteJobQueue', schema, options)
          if resp == '0'
            Puppet.debug("Job Queue cleared successfully")
            wait_for_jobs_clear
          else
            raise Puppet::Error, "Error clearing job queue.  Message: #{doc.xpath('//n1:Message')}"
          end
        rescue Puppet::Error => e
          raise e if tries > 4
          tries += 1
          Puppet.info("Could not reset job queue.  Retrying in 30 seconds...")
          sleep 30
          retry
        end
      end

      #Clears the job queue, but resets the idrac and retries if the job queue can't be cleared the first time
      def self.clear_job_queue_with_retry
        attempts = 0
        begin
          attempts += 1
          clear_job_queue
        rescue Puppet::Idrac::JobClearError
          raise("Job queue cannot be cleared.") if attempts > 1
          Puppet.warning("Job queue still shows jobs exist after attempting to clear the job queue.")
          reset
          retry
        end
      end

      # Waits 150 seconds for the job queue to be empty.  Raises JobClearError if it doesn't clear in that time
      def self.wait_for_jobs_clear
        Puppet.info("Waiting for job queue to be empty...")
        schema = "http://schemas.dell.com/wbem/wscim/1/cim-schema/2/DCIM_JobService"
        10.times do
          resp = ASM::WsMan.invoke(get_transport, 'enumerate', schema)
          doc = Nokogiri::XML("<results>#{resp}</results>")
          doc.remove_namespaces!
          Puppet.debug("Response from DCIM_JobService:\n#{doc}")
          if doc.xpath('//CurrentNumberOfJobs').text == '0'
            Puppet.info("Job Queue is empty.")
            return
          else
            sleep 15
          end
        end
        raise(Puppet::Idrac::JobClearError, "Timed out waiting for job queue to clear out.")
      end

      def self.reset
        Puppet.info("Resetting Idrac...")
        transport = get_transport
        Net::SSH.start( transport[:host],
                        transport[:user],
                        :password => transport[:password],
                        :paranoid => Net::SSH::Verifiers::Null.new,
                        :global_known_hosts_file=>"/dev/null" ) do |ssh|
          ssh.exec "racadm racreset soft" do |ch, stream, data|
            Puppet.debug(data)

            #Issue warning for the message 'Could not chdir to home directory /flash/data0/home/root: No such file or directory' else raise error
            if data.include? "Could not chdir to home directory"
              Puppet.warning "Warning for message - #{data}"
            elsif stream == :stderr
              raise Puppet::Error, 'Error resetting Idrac'
            end
          end
        end
        wait_for_idrac
      end

      def self.wait_for_idrac (timeout = 180, state = 0)
        raise Puppet::Error, 'Timeout waiting for Idrac' if timeout == 0
        Puppet.debug("waiting #{timeout} seconds for Idrac...")
        sleep timeout
        begin
          wait_for_idrac(timeout/2) if lcstatus.to_i != state
        rescue
          wait_for_idrac(timeout/2)
        end
      end

      def self.lcstatus
        transport = get_transport
        obj = Puppet::Provider::Checklcstatus.new(
            transport[:host],
            transport[:user],
            transport[:password]
        )
        obj.checklcstatus
      end

      def self.wsman_system_config_action(type, props={})
        require 'asm/wsman'
        schema ='http://schemas.dmtf.org/wbem/wscim/1/cim-schema/2/root/dcim/DCIM_LCService?SystemCreationClassName="DCIM_ComputerSystem",CreationClassName="DCIM_LCService",SystemName="DCIM:ComputerSystem",Name="DCIM:LCService"'
        options = {:props=>props, :logger => Puppet}
        job_id = ''
        action = "#{type.capitalize}SystemConfiguration"
        10.times do
          out = ASM::WsMan.invoke(get_transport, action, schema, options)
          response = Nokogiri::XML(out)
          response.remove_namespaces!
          job_id = response.at_xpath("//Selector[@Name='InstanceID']")
          if job_id.nil?
            message_id = response.at_xpath("//#{action}_OUTPUT/MessageID")
            #LC062 indicates a failure due to other job already running, so we want to wait and retry.exi
            if message_id && message_id.text == 'LC062'
              Puppet.info("Job was already running on idrac.  Waiting 1 minute to retry #{action}...")
              sleep 60
            else
              message = response.at_xpath("//#{action}_OUTPUT/Message")
              output = message ? message.text : "Response is invalid"
              raise "#{action} Job could not be created:  #{output}"
            end
          else
            job_id = job_id.text
            Puppet.info("#{action} job started with JobID #{job_id}")
            break
          end
        end
        if job_id == ""
          raise "#{action} Job could not be created"
        end
        job_id
      end

    end
  end
end