Puppet::Type.newtype(:server_onboard) do
  desc "Puppet type to setup networking and new creds on a server through racadm"

  ensurable

  newparam(:name, :namevar => true) do
    desc "certname of the server"
  end

  # Credential property
  #
  # specify username and password for connecting to server
  #
  # @param credential [Hash] Options for specifying the credential
  #
  # @option credential [String] "username" username for connecting to the server
  # @option credential [String] "password" password for connecting to the server
  #
  # @example puppet manifest to specify credential
  #  server_onboard { "rackserver-abcd123" :
  #    credential = {
  #      "username" => "foo",
  #      "password" => "bar"
  #    }
  #  }
  newproperty(:credential) do
    desc "credential specifying username and password for connecting to the server"
  end

  # Network Configuration parameter
  #
  # specification for network configuration like static IP, DNS settings
  #
  # @param networks [Hash] Options for specifying the network config
  #
  # @option networks [Boolean] "static" specifies whether config is static or not
  # @option networks [Hash] "staticNetworkConfiguration" specifies config parameters such as
  #                          ipAddress, gateway, subnet, primaryDns, secondaryDns
  #
  # @example puppet manifest to specify static network config
  #  server_onboard { "rackserver-abcd123" :
  #    networks = {
  #      "static" => true,
  #      "staticNetworkConfiguration" => {
  #        "gateway" => "172.27.0.1",
  #        "subnet" => "255.255.0.0",
  #        "primaryDns" => null,
  #        "secondaryDns" => null,
  #        "ipAddress" => "172.27.15.14"
  #      }
  #    }
  #  }
  newparam(:networks) do
    desc "network configuration for setting the idrac networks"
  end

  newproperty(:network_type) do
    desc "type of network to setup on the server"
    newvalue(:static)
    newvalue(:existing)
  end
  newproperty(:idrac_init_snmp) do
    desc "initialize the idrac to send snmp traps to flex manager"
  end
end
