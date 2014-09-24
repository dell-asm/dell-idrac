 require 'json'

 Puppet::Type.newtype(:idrac_settings) do
  desc "Used for setting up miscellaneous idrac settings"

  newparam(:name, :namevar => true) do
    desc "The cert name of the idrac"
  end

  #dns_name must come before register_dns (opposite of racadm with cmc)
  #Puppet evaluates properties in the order they are defined here
  newproperty(:dns_name) do
    desc "The DNS name to register the idrac with"
  end

  newproperty(:register_dns) do
    desc "Whether to register the CMC name on the DNS"
    munge do |value|
      if value == true
        '1'
      elsif value == false
        '0'
      else
        raise "Invalid value #{value} for ntp_enabled"
      end
    end
  end

  newproperty(:users) do
    desc "A hash of local users to set through the cmc"
    munge do |value|
      JSON.parse(value)
    end
  end

  newproperty(:alert_destinations) do
    desc ""
    munge do |value|
      JSON.parse(value)
    end
  end

  newproperty(:smtp_server) do
    desc ""
  end

  newproperty(:email_destinations) do
    desc ""
    munge do |value|
      JSON.parse(value)
    end
  end

  newproperty(:ntp_enabled) do
    desc "Enable or disable NTP server access to iDRAC"
    munge do |value|
      if value == true
        '1'
      elsif value == false
        '0'
      else
        raise "Invalid value #{value} for ntp_enabled"
      end
    end
  end

  newproperty(:ntp_preferred) do
    desc ""
  end

  newproperty(:ntp_secondary) do 
    desc ""
  end

  newproperty(:time_zone) do
    desc ""
  end

  newproperty(:ipmi_over_lan) do
    desc "Enable or disable IMPI over LAN interface"
    munge do |value|
      if value == true
        '1'
      elsif value == false
        '0'
      else
        raise "Invalid value #{value} for ntp_enabled"
      end
    end
  end

  newproperty(:chassis_name) do
    desc "The chassis' name for this server"
  end

  newproperty(:datacenter) do
    desc "Indicates name of the data center where the server is located"
  end

  newproperty(:aisle) do
    desc "Indicates aisle where server is located"
  end

  newproperty(:rack) do
    desc "Indicates rack where server is located"
  end

  newproperty(:rackslot) do
    desc "Indicates slot this server is located"
  end

end