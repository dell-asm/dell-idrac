#!/opt/puppet/bin/ruby

require 'trollop'
require 'json'
require_relative '../lib/discovery'

opts = Trollop::options do
  banner <<-EOS
Get Idrac device inventory

Usage:
       discovery.rb [options]

where [options] are:
  EOS

  opt :server, 'idrac address', :type => :string, :required => true
  opt :credential_id, 'and ID needed to make an ASM request', :type => :string, :required => true
  opt :timeout, 'Raise an exception after timeout seconds', :type => :int, :default => 1800
  opt :output, "output facts to a file", :type => :string
  opt :username, 'dummy value for ASM, not used'
  opt :password, 'dummy value for ASM, not used'

end
STDERR.puts "Running idrac discovery for #{{:server => opts[:server],
                                            :timeout => opts[:timeout]}}"
idrac_discovery = Idrac::Discovery.new({:server => opts[:server],
                                        :credential_id => opts[:credential_id],
                                        :timeout => opts[:timeout]})
idrac_discovery.asm_manager_server_discovery_request
idrac_discovery.java_resource_adapter_framework_discovery
idrac_discovery.wait_for_complete
idrac_discovery.get_discovered_devices
facts = JSON.parse(idrac_discovery.asm_manager_server)
if facts && !facts.empty? && opts[:output] && !opts[:output].empty?
  # Note: The immediate consumers of these puppet facts require
  # each fact value to be a string. Hence, loop through all values and
  # encode non-string values inside a string.
  encoded_list = []
  facts.each do |k,v|
    unless v.is_a?(String)
      facts[k] = v.to_json
      encoded_list.push(k)
    end
  end
  facts[:encoded_facts] = encoded_list.to_json
  File.write(opts[:output], facts.to_json)
end
