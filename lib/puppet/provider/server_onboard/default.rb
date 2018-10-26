# Puppet provider for server on-boarding
# Copyright (C) 2016 Dell, Inc.
provider_path = Pathname.new(__FILE__).parent.parent
require File.join(provider_path, "idrac_racadm")
require "open3"
Puppet::Type.type(:server_onboard).provide(:default, :parent => Puppet::Provider::IdracRacadm) do

  # Puppet resource exists method
  #
  # Puppet invoked method to indicate whether to invoke create or destroy
  #
  # @return [Boolean] indicates whether puppet resource is present or not on target system
  def exists?
    false
  end

  # Puppet resource create method
  #
  # Puppet invoked method to create resource for configuring creds and network
  #
  # @return [void]
  # @raise [StandardError] when either credentials or network type cannot be applied
  def create
    setup_credential
    setup_network
  end

  # Set credential
  #
  # sets relevant username, password
  #
  # @return [void]
  # @raise [StandardError] when credentials cannot be applied
  def setup_credential
    credential = resource[:credential]
    if credential.nil? || credential["username"].nil? || credential["password"].nil?
      raise "username or password not specified"
    end

    root_slot = nil
    empty_slot = nil
    user_slot = nil
    (2..16).each do |i|
      user_name = racadm_get('idrac', 'users', 'username', i )
      root_slot = i if user_name == "root"
      user_slot = i if user_name == credential["username"]
      empty_slot = i if user_name.nil? || user_name == "UserName="
      break if root_slot && (user_slot || empty_slot)
    end

    if root_slot && credential["username"] == "root"
      racadm_set("idrac", "users", "password", credential["password"], root_slot, :raise_on_err => true)
    elsif user_slot
      racadm_set("idrac", "users", "password", credential["password"], user_slot, :raise_on_err => true)
    elsif empty_slot
      racadm_set("idrac", "users", "username", credential["username"], empty_slot, :raise_on_err => true)
      racadm_set("idrac", "users", "password", credential["password"], empty_slot, :raise_on_err => true)
      racadm_set("idrac", "users", "ipmilanprivilege", lan_permissions["Administrator"], empty_slot, :raise_on_err => true)
      racadm_set("idrac", "users", "privilege", local_permissions["Administrator"], empty_slot, :raise_on_err => true)
      racadm_set("idrac", "users", "enable", enabled_bit("Enabled"), empty_slot, :raise_on_err => true)
    else
      raise("No root user found and no empty slots available") if !root_slot && !empty_slot
    end
  end

  # Set network configuration
  #
  # sets network configuration values depending on specified network_type.
  #
  # @return [void]
  # @raise [StandardError] when network configuration cannot be applied
  def setup_network
    return if resource[:networks].nil?

    network_type = resource[:network_type]

    if network_type.to_s == "static"
      network_obj = resource[:networks]
      network_obj = [network_obj] if network_obj.is_a?(Hash)

      Array(network_obj).each do |net|
        raise "network configuration params are not static" if net["staticNetworkConfiguration"].nil? || net["staticNetworkConfiguration"].empty?

        config_static_network net["staticNetworkConfiguration"]
      end
    end
  end

  # Set static network config
  #
  # sets static network configuration values like static IP settings, DNS settings, etc
  #
  # @param config [Hash] static network config to be applied
  # @option config [String] "ipAddress" static IP address
  # @option config [String] "subnet" subnet for the static network
  # @option config [String] "gateway" gateway for the static network
  # @option config [String] "primaryDns" primary DNS server address
  # @option config [String] "secondaryDns" secondary DNS server address
  # @return [void]
  # @raise [StandardError] when network configuration cannot be applied
  def config_static_network(config)
    racadm_set("idrac", "ipv4", "dns1", config["primaryDns"]) if config["primaryDns"]
    racadm_set("idrac", "ipv4", "dns2", config["secondaryDns"]) if config["secondaryDns"]

    Timeout.timeout(60) do
      racadm_cmd("setniccfg", ["-s", config["ipAddress"], config["subnet"], config["gateway"]])
    end

    wait_for_ip(config["ipAddress"])
  end

  # Wait for given IP
  #
  # using wsman command, wait for certain period of time for given IP address
  #
  # @param ip [String] IP address to wait on
  # @param max_wait [Integer] maximum seconds to wait for the IP to connect
  # @return [void]
  # @raise [StandardError] when times out waiting for static IP address
  def wait_for_ip(ip, max_wait=300)
    current_time = Time.now

    require "asm/wsman"
    username = resource[:credential]["username"]
    password = resource[:credential]["password"]
    wsman = ASM::WsMan.new({:host => ip, :user => username, :password => password})

    # Invoke wsman identify command in a loop until max wait has elapsed or we get output indicating availability
    while Time.now - current_time < max_wait
      sleep 10
      output = wsman.identify(10)
      if output
        Puppet.info("IP %s is now available" % ip)
        return
      end
    end

    # If we reach here, it means no confirmation of connectivity
    raise("Timed out waiting for static IP address to be set for %s" % resource[:name])
  end
end
