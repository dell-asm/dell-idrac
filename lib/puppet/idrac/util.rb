require 'rexml/document'

include REXML
require 'pty'

module Puppet
  module Idrac
    module Util 
      def self.get_transport
        require 'asm/util'
        @transport ||= begin
          t = Puppet::Idrac::Util.parse_device_config(Puppet[:certname])
          t[:password] = URI.decode(t[:password])
          t
        end
      end

      # WARNING: methods below here are copy-and-paste from ASM::Util, needs
      # to be factored out into a separate library both dell-idrac and
      # asm-deployer can use

      PUPPET_CONF_DIR='/etc/puppetlabs/puppet'
      DEVICE_CONF_DIR="#{PUPPET_CONF_DIR}/devices"
      DEVICE_SSL_DIR="/var/opt/lib/pe-puppet/devices"

      def self.to_boolean(b)
        if(b.is_a?(String))
          b.downcase == "true"
        else
          b
        end
      end

      def self.get_plain_password(encoded_password)
        # NOTE: The actual decryption code in encode_asm.rb is being executed in
        # MRI ruby because it fails in jruby with "OpenSSL::Cipher::CipherError:
        # Illegal key size".
        #
        # Additionally the env command is being used to clear the environment
        # before running MRI ruby to ensure that any torquebox environment
        # variables do not confuse the execution. We saw a few strange cases
        # where jruby gems were being pulled into MRI that were causing
        # decryption failures.
        cmd = "env --ignore-environment /opt/puppet/bin/ruby /opt/asm-deployer/lib/asm/encode_asm.rb #{encoded_password}"
        results = run_command_success(cmd)
        URI.decode(results.stdout.strip)
      end

      def self.parse_device_config(cert_name)
        conf_file = File.join(DEVICE_CONF_DIR, "#{cert_name}.conf")
        return nil unless File.exists?(conf_file)
        conf_file_data = parse_device_config_file(conf_file)
        uri = URI.parse(conf_file_data[cert_name].url)
        host = uri.host
        user = URI.decode(uri.user)
        enc_password = URI.decode(uri.password)
        Hashie::Mash.new({
                             :cert_name => cert_name,
                             :host => host,
                             :user => user,
                             :enc_password => enc_password,
                             :password => get_plain_password(enc_password),
                             :url => uri,
                             :conf_file_data => conf_file_data
                         })
      end

      # Parse puppet device config files, code cribbed from
      # Puppet::Util::NetworkDevice::Config
      def self.parse_device_config_file(file)
        begin
          devices = {}
          device = nil
          File.open(file) { |f|
            count = 1
            f.each { |line|
              case line
                when /^\s*#/ # skip comments
                  count += 1
                  next
                when /^\s*$/  # skip blank lines
                  count += 1
                  next
                when /^\[([\w.-]+)\]\s*$/ # [device.fqdn]
                  name = $1
                  name.chomp!
                  raise(Exception, "Duplicate device found at line #{count}, already found at #{device.line}") if devices.include?(name)
                  device = OpenStruct.new
                  device.name = name
                  device.line = count
                  device.options = { :debug => false }
                  devices[name] = device
                when /^\s*(type|url|debug)(\s+(.+))*$/
                  parse_device_config_directive(device, $1, $3, count)
                else
                  raise(Exception, "Invalid line #{count}: #{line}")
              end
              count += 1
            }
          }
          devices
        end
      end

      def self.parse_device_config_directive(device, var, value, count)
        case var
          when "type"
            device.provider = value
          when "url"
            device.url = value
          when "debug"
            device.options[:debug] = true
          else
            raise(Exception, "Invalid argument '#{var}' at line #{count}")
        end
      end


    end
end
end