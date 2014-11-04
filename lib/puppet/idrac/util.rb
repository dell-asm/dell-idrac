require 'rexml/document'

include REXML
require 'pty'

module Puppet
  module Idrac
    module Util 
      def self.get_transport
        require 'asm/device_management'
        @transport ||= begin
          t = ASM::DeviceManagement.parse_device_config(Puppet[:certname])
          t[:password] = URI.decode(t[:password])
          t
        end
      end
  end
end
end