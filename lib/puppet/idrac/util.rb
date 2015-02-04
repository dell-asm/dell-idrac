require 'rexml/document'

include REXML
require 'pty'

module Puppet
  module Idrac
    module Util
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
    end
  end
end