require 'pathname'
require 'rexml/document'
require 'hashie'

# WARNING: This code is copy-and-paste from asm-deployer module, it needs to be
# factored out into a separate dependency asm-deployer and dell-idrac can both use
module Puppet
  module Idrac
    module WsMan

      # Wrapper for the wsman client. endpoint should be a hash of
      # :host, :user, :password
      def self.invoke(endpoint, method, schema, options = {})
        options = {
            :selector => nil,
            :props => {},
            :input_file => nil,
            :logger => nil,
        }.merge(options)

        cmd = 'wsman'
        if method == 'enumerate'
          args = ['enumerate', schema]
        else
          args = ['invoke', '-a', method, schema]
        end

        args += ['-h', endpoint[:host],
                 '-V', '-v', '-c', 'dummy.cert', '-P', '443',
                 '-u', endpoint[:user], '-p', endpoint[:password],
                 '-j', 'utf-8', '-y', 'basic',]
        if options[:input_file]
          args += ['-J', options[:input_file]]
        end
        options[:props].each do |key, val|
          args += ['-k', "#{key}=#{val}"]
        end

        if options[:logger]
          masked_args = args.dup
          masked_args[args.find_index('-p') + 1] = '******'
          options[:logger].debug("Executing #{cmd} #{masked_args.join(' ')}")
        end
        result = Puppet::Idrac::WsMan.run_command_with_args(cmd, *args)
        options[:logger].debug("Result = #{result}") if options[:logger]

        # The wsman cli does not set exit_status properly on failure, so we
        # have to check stderr as well...
        unless result.exit_status == 0 && result.stderr.empty?
          if result['stdout'] =~ /Authentication failed/
            msg = "Authentication failed, please retry with correct credentials after resetting the iDrac at #{endpoint[:host]}."
          elsif result['stdout'] =~ /Connection failed./
            msg = "Connection failed, Couldn't connect to server. Please check IP address credentials for iDrac at #{endpoint[:host]}."
          else
            msg = "Failed to execute wsman command against server #{endpoint[:host]}"
          end
          options[:logger].error(msg) if options[:logger]
          raise(Exception, "#{msg}: #{result}")
        end

        if options[:selector]
          doc = REXML::Document.new(result['stdout'])
          node = REXML::XPath.first(doc, options[:selector])
          if node
            node.text
          else
            msg = "Invalid WS-MAN response from server #{endpoint[:host]}"
            options[:logger].error(msg) if options[:logger]
            raise(Exception, msg)
          end
        else
          result['stdout']
        end
      end

      def self.reboot(endpoint, logger = nil)
        # Create the reboot job
        logger.debug("Rebooting server #{endpoint[:host]}") if logger
        input_file = File.join(Pathname.new(__FILE__).parent, 'reboot.xml')
        instanceid = invoke(endpoint,
                            'CreateRebootJob',
                            'http://schemas.dmtf.org/wbem/wscim/1/cim-schema/2/root/dcim/DCIM_SoftwareInstallationService?CreationClassName=DCIM_SoftwareInstallationService,SystemCreationClassName=DCIM_ComputerSystem,SystemName=IDRAC:ID,Name=SoftwareUpdate',
                            :selector => '//wsman:Selector Name="InstanceID"',
                            :props => {'RebootJobType' => '2'},
                            :input_file => input_file,
                            :logger => logger)

        # Execute job
        jobmessage = invoke(endpoint,
                            'SetupJobQueue',
                            'http://schemas.dmtf.org/wbem/wscim/1/cim-schema/2/root/dcim/DCIM_JobService?CreationClassName=DCIM_JobService,Name=JobService,SystemName=Idrac,SystemCreationClassName=DCIM_ComputerSystem',
                            :selector => '//n1:Message',
                            :props => {
                                'JobArray' => instanceid,
                                'StartTimeInterval' => 'TIME_NOW'
                            },
                            :logger => logger)
        logger.debug "Job Message #{jobmessage}" if logger
        return true
      end

      def self.poweroff(endpoint, logger = nil)
        # Create the reboot job
        logger.debug("Power off server #{endpoint[:host]}") if logger

        power_state = get_power_state(endpoint, logger)
        if power_state.to_i != 13
          response = invoke(endpoint, 'RequestStateChange',
                            'http://schemas.dell.com/wbem/wscim/1/cim-schema/2/DCIM_ComputerSystem?CreationClassName=DCIM_ComputerSystem,Name=srv:system',
                            :props => {'RequestedState' => "3"},
                            :logger => logger)
        else
          logger.debug "Server is already powered off" if logger
        end
        return true
      end

      def self.get_power_state(endpoint, logger = nil)
        # Create the reboot job
        logger.debug("Getting the power state of the server with iDRAC IP: #{endpoint[:host]}") if logger
        response = invoke(endpoint,
                          'enumerate',
                          'http://schemas.dmtf.org/wbem/wscim/1/cim-schema/2/DCIM_CSAssociatedPowerManagementService',
                          :logger => logger)
        updated_xml = match_array=response.scan(/(<\?xml.*?<\/s:Envelope>?)/m)
        xmldoc = REXML::Document.new(updated_xml[1][0])
        powerstate_node = REXML::XPath.first(xmldoc, '//n1:PowerState')
        powerstate = powerstate_node.text
        logger.debug("Power State: #{powerstate}") if logger
        powerstate
      end

      def self.get_wwpns(endpoint, logger = nil)
        wsmanCmdResponse = invoke(endpoint, 'enumerate',
                                  'http://schemas.dmtf.org/wbem/wscim/1/cim-schema/2/root/DCIM/DCIM_FCView',
                                  :logger => logger)
        wsmanCmdResponse.split(/\n/).collect do |ele|
          if ele =~ /<n1:VirtualWWPN>(\S+)<\/n1:VirtualWWPN>/
            $1
          end
        end.compact
      end

      # Return all the server MAC Address along with the interface location
      # in a hash format
      def self.get_mac_addresses(endpoint, logger = nil)
        get_nic_view(endpoint, 'CurrentMACAddress', logger)
      end

      def self.get_permanent_mac_addresses(endpoint, logger = nil)
        get_nic_view(endpoint, 'PermanentMACAddress', logger)
      end

      #Gets Nic View data for a specified fqdd
      def self.get_nic_view(endpoint, fqdd, logger = nil)
        mac_info = {}
        resp = invoke(endpoint, 'enumerate',
                      'http://schemas.dmtf.org/wbem/wscim/1/cim-schema/2/root/dcim/DCIM_NICView',
                      :logger => logger)
        nic_views = resp.split("<n1:DCIM_NICView>")
        nic_views.shift
        nic_views.each do |nic_view|
          nic_name = nil
          nic_view.split("\n").each do |line|
            if line =~ /<n1:FQDD>(\S+)<\/n1:FQDD>/
              nic_name = $1
            end
          end
          nic_view.split("\n").each do |line|
            if line =~ /<n1:#{fqdd}>(\S+)<\/n1:#{fqdd}>/
              mac_address = $1
              mac_info[nic_name] = mac_address
            end
          end
        end
        logger.debug("********* MAC Address List is #{mac_info.inspect} **************") if logger
        mac_info
      end

    end
  end
end
