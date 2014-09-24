begin
  require 'puppet_x/puppetlabs/transport'
  require 'puppet_x/puppetlabs/transport/idrac'
rescue LoadError
  require 'pathname' # WORK_AROUND #14073 and #7788
  mod = Puppet::Module.find('transport', Puppet[:environment].to_s)
  require File.join mod.path, 'lib/puppet_x/puppetlabs/transport'
  require File.join mod.path, 'lib/puppet_x/puppetlabs/transport/idrac'
end

class Puppet::Provider::IdracRacadm <  Puppet::Provider

  def local_permissions
    {"Administrator" => "0x1ff", "Operator" => "0x1f3", "ReadOnly" => "0x1", "None" => "0x0"}
  end

  def lan_permissions
    {"Administrator" => "4", "Operator" => "3", "User" => "2", "No Access" => "15"}
  end

  def enabled_bit(value)
    (value == true || value == "Enabled") ? "1" : "0"
  end

  def client
    @transport ||= PuppetX::Puppetlabs::Transport.retrieve(:resource_ref => resource[:transport], :catalog => resource.catalog, :provider => 'idrac')
    @transport.ssh
  end

  def racadm_cmd(subcommand, flags={}, params='')
    cmd = "racadm #{subcommand}"
    if(!params.empty?)
      param_string = param_values.is_a?(Array) ? params.join(" ") : params.to_s
      cmd << " #{param_string}"
    end
    output = client.exec!(cmd)
    Puppet.info("racadm #{subcommand} result: #{output}")
    Puppet.err("Could not send command racadm #{subcommand}") if output.include?('ERROR:')
    parse_output_values(output)
  end

  def racadm_set(fqdd, group, config_object='', params=[], index='')
    path = "#{fqdd}.#{group}.#{config_object}"
    if(!index.to_s.empty?)
      path << ".#{index}"
    end
    cmd = "racadm set #{path}"
    if(!params.empty?)
      param_string = params.is_a?(Array) ? params.join(' ') : params.to_s
      cmd << " #{param_string}"
    end
    output = client.exec!(cmd)
    Puppet.info("racadm_set result: #{output}")
    Puppet.err("Could not set #{path}") if output.include?('ERROR:')
    parse_output_values(output)
  end

  def racadm_get(fqdd, group='', config_object='', index='')
    path = "#{fqdd}.#{group}.#{config_object}"
    if(!index.to_s.empty?)
      path << ".#{index}"
    end
    cmd = "racadm get #{path}"
    parse_output_values(client.exec!(cmd))
  end

  def parse_output_values(output)
    lines = output.split("\n")
    #First line of idrac racadm returns something like [Key=Foo.Bar.Foobar] which is unnecessary for use in this module
    lines.shift if lines.first.start_with?('[') && lines.first.end_with?(']')
    #If we can split by =, it's a return with key/values we can parse.  Otherwise, just return the output as is split by new line character
    if(lines.first.split("=").size > 1)
      output = Hash[lines.map{|str| str.split("=")}.collect{|line|
        key = line[0].strip
        #Sometimes, the line starts with # or !!symbol.  Just clean if it does so we return a nice hash
        if(key.start_with?('#'))
          key = key[1..-1].strip
        elsif(key.start_with?('!!'))
          key = key[2..-1].strip
        end
        value = line[1].nil? ? "" : line[1].strip
        [key, value]
        }]
      if output.size == 1
        return output.values.first
      else
        return output
      end
    elsif(lines.size == 1)
      lines.first
    else
      lines
    end
  end
end
