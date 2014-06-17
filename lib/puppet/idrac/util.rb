require 'rexml/document'

include REXML
require 'pty'

module Puppet
  module Idrac
    module Util 
      def self.get_transport
        require 'asm/util'
        @transport ||= begin
          t = ASM::Util.parse_device_config(Puppet[:certname])
          t[:password] = URI.decode(t[:password])
          t
        end
      end
  end
end
end