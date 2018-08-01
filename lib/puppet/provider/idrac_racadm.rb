require "pathname"
begin
  require "puppet_x/puppetlabs/transport"
rescue LoadError # WORK_AROUND #14073 and #7788
  mod = Puppet::Module.find("transport", Puppet[:environment].to_s)
  require File.join mod.path, "lib/puppet_x/puppetlabs/transport" if mod
end
begin
  require "puppet_x/puppetlabs/transport/racadm"
rescue LoadError # WORK_AROUND #14073 and #7788
  mod = Puppet::Module.find("transport", Puppet[:environment].to_s)
  begin
    require File.join mod.path, "lib/puppet_x/puppetlabs/transport/racadm" if mod
  rescue LoadError  # This would happen in CI scenario, ignore it since we anyways will mock racadm out
  end
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
    @transport ||= PuppetX::Puppetlabs::Transport.retrieve(:resource_ref => resource[:transport], :catalog => resource.catalog, :provider => "racadm")
    @transport.ssh
  end

  # Racadm command
  #
  # Executes desired racadm command and parses resulting output
  #
  # @param subcommand [String] racadm subcommand to invoke
  # @param params [Array<String>] list of params to be appended to racadm set <fqdd>.<group>.<object>.<index>
  # @param process_opts [Hash] extra options for processing results
  # @option process_opts [Boolean] :raise_on_err flag to indicate whether to raise exception if command errs
  # @return [Object] output for the command result. Can be either a string, or list of strings
  # @raise [StandardError] when racadm command fails and :raise_on_err flag is set
  def racadm_cmd(subcommand, params=[], process_opts={})
    cmd = "racadm %s" % subcommand
    cmd << " %s" % Array(params).join(" ")unless params.empty?
    output = client.exec!(cmd)
    Puppet.info("racadm %s result: %s" % [subcommand, output])
    if output.include?("ERROR:")
      msg = "Error in racadm command %s" % subcommand
      Puppet.err(msg)
      raise msg if process_opts[:raise_on_err]
    else
      Puppet.info("Successfully executed %s" % subcommand)
    end
    parse_output_values(output)
  end

  # Racadm set command
  #
  # Executes desired racadm set command and parses resulting output
  #
  # @param fqdd [String] FQDD to be used in racadm set <fqdd>.<group>.<object>.<index>
  # @param group [String] group to be used in racadm set <fqdd>.<group>.<object>.<index>
  # @param config_object [String] config to be used in racadm set <fqdd>.<group>.<object>.<index>
  # @param params [Array<String>] list of params to be appended to racadm set <fqdd>.<group>.<object>.<index>
  # @param index [String] index to be used in racadm set <fqdd>.<group>.<object>.<index>
  # @param process_opts [Hash] extra options for processing results
  # @option process_opts [Boolean] :raise_on_err flag to indicate whether to raise exception if command errs
  # @return [Object] output for the command result. Can be either a string, or list of strings
  # @raise [StandardError] when racadm command fails and :raise_on_err flag is set
  def racadm_set(fqdd, group, config_object="", params=[], index="", process_opts={})
    path = "%s.%s.%s" % [fqdd, group, config_object]
    path << ".%s" % index unless index.to_s.empty?
    racadm_cmd("set %s" % path, params, process_opts)
  end

  # Racadm get command
  #
  # Executes desired racadm get command and parses output from the command
  #
  # @param fqdd [String] FQDD to be used in racadm set <fqdd>.<group>.<object>.<index>
  # @param group [String] group to be used in racadm set <fqdd>.<group>.<object>.<index>
  # @param config_object [String] config to be used in racadm set <fqdd>.<group>.<object>.<index>
  # @param index [String] index to be used in racadm set <fqdd>.<group>.<object>.<index>
  # @return [Object] output for the command result. Can be either a string, or list of strings
  def racadm_get(fqdd, group="", config_object="", index="")
    path = "%s.%s.%s" % [fqdd, group, config_object]
    unless index.to_s.empty?
      path << ".%s" % index
    end
    cmd = "racadm get %s" % path
    parse_output_values(client.exec!(cmd))
  end

  def parse_output_values(output)
    lines = output.split("\n").map do |line|
      # Get rid of "Warning: It is recommended not to use the default user name" message
      next if line.start_with?("Warning: It is recommended not to use the default user name")

      # First line of idrac racadm returns something like [Key=Foo.Bar.Foobar] which is unnecessary for use in this module
      next if line.start_with?("[") && line.end_with?("]")

      line
    end.compact

    return "" if lines.empty?

    #If we can split by =, it"s a return with key/values we can parse.  Otherwise, just return the output as is split by new line character
    if(lines.first.split("=").size > 1)
      output = Hash[lines.map{|str| str.split("=")}.collect{|line|
        key = line[0].strip
        #Sometimes, the line starts with # or !!symbol.  Just clean if it does so we return a nice hash
        if(key.start_with?("#"))
          key = key[1..-1].strip
        elsif(key.start_with?("!!"))
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
