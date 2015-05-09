require 'rexml/document'

include REXML
require 'pty'

module Puppet
  module Idrac
    module Util
      class ConfigError < Exception; end
      def self.get_transport
        require 'asm/device_management'
        @transport ||= begin
          ASM::DeviceManagement.parse_device_config(Puppet[:certname])
        end
      end

      def self.view_disks(type=:virtual)
        transport = get_transport
        output = ASM::WsMan.invoke({:host => transport[:host], :user => transport[:user], :password => transport[:password]}, 'enumerate', "http://schemas.dmtf.org/wbem/wscim/1/cim-schema/2/root/dcim/DCIM_#{type.capitalize}DiskView")
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

      def self.wait_for_running_jobs
        require 'asm/wsman'
        transport = get_transport
        Puppet.info("Checking for running jobs")
        10.times do
          endpoint={:host=>transport[:host], :user=>transport[:user], :password=>transport[:password]}
          schema ="http://schemas.dell.com/wbem/wscim/1/cim-schema/2/DCIM_LifeCycleJob"
          out = ASM::WsMan.invoke(endpoint, 'enumerate', schema)
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