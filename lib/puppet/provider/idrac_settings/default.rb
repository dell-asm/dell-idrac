# Copyright (C) 2014 Dell, Inc.
provider_path = Pathname.new(__FILE__).parent.parent
require File.join(provider_path, 'idrac_racadm')
Puppet::Type.type(:idrac_settings).provide(:default, :parent => Puppet::Provider::IdracRacadm) do

  def dns_name
    racadm_get('idrac', 'nic', 'dnsracname')
  end
  
  def dns_name=(name)
    racadm_set('idrac', 'nic', 'dnsracname', name)
  end

  def register_dns
    output = racadm_get('idrac', 'nic', 'dnsregister')
    enabled_bit(output)
  end

  def register_dns=(register_dns)
    racadm_set('idrac', 'nic', 'dnsregister', register_dns)
  end

  def users; end

  def users=(users)
    #User #1 is anonymous user (can't touch), and User #2 is the root user.  Let it be, let it be.
    (3..16).each do |i|
      racadm_set('idrac', 'users', 'username', '""', i )
    end
    users.each.with_index(3) do |user, index|
      user = users[index-3]
      racadm_set('idrac', 'users', 'username', user['username'], index)
      racadm_set('idrac', 'users', 'password', get_password(user['password']), index)
      racadm_set('idrac', 'users', 'ipmilanprivilege', lan_permissions[user['lan']], index)
      racadm_set('idrac', 'users', 'privilege', local_permissions[user['idracrole']], index)
      racadm_set('idrac', 'users', 'enable', enabled_bit(user['enabled']), index)
    end
  end

  #This method is used for extending this provider, in order to add custom decryption to the password field if desired
  def get_password(password)
    password
  end

  def alert_destinations; end

  def alert_destinations=(destinations)
    if(!destinations.empty?)
      #We just use the very first alert destination as the reference for the snmp community string
      comm_string = get_community_string(destinations.first['communityString'])
      racadm_set('idrac', 'snmp', 'agentcommunity', comm_string)
      destinations.each.with_index(1) do |destination, index|
        racadm_set('idrac', 'snmp', 'alert.destaddr', destination['destinationIpAddress'], index)
        racadm_set('idrac', 'snmp', 'alert.enable', "1", index)
      end
    end
  end

  #This method is used for extending this provider, in order to add custom decryption/retrieval of the community string if desired
  def get_community_string(string)
    string
  end

  
  def smtp_server
    racadm_get('idrac', 'remotehosts', 'smtpserveripaddress')
  end

  def smtp_server=(smtp_server)
    racadm_set('idrac', 'remotehosts', 'smtpserveripaddress', smtp_server)
  end

  def email_destinations; end

  def email_destinations=(destinations)
    destinations.each.with_index(1) do |destination, index|
      racadm_set('idrac', 'emailalert','address', destination['email'], index)
      racadm_set('idrac', 'emailalert', 'enable', "1", index)
    end
  end

  def ntp_enabled
    enabled_bit(racadm_get('idrac', 'ntpconfiggroup', 'ntpenable'))
  end

  def ntp_enabled=(enabled)
    racadm_get('idrac', 'ntpconfiggroup', 'ntpenable', enabled)
  end
  
  def ntp_preferred
    racadm_get('idrac', 'ntpconfiggroup', 'ntp1')
  end

  def ntp_preferred=(ntp_preferred)
    racadm_set('idrac', 'ntpconfiggroup', 'ntp1', ntp_preferred)
  end
  
  def ntp_secondary
    racadm_get('idrac', 'ntpconfiggroup', 'ntp2')
  end
  def ntp_secondary=(ntp_secondary)
    racadm_set('idrac', 'ntpconfiggroup', 'ntp2', ntp_secondary)
  end

  def time_zone
    racadm_get('idrac','time', 'timezone')
  end

  def time_zone=(time_zone)
    racadm_set('idrac','time', 'timezone', time_zone)
  end

  def ipmi_over_lan
    enabled_bit(racadm_get('idrac','ipmilan', 'enable'))
  end
  
  def ipmi_over_lan=(ipmi_over_lan)
    racadm_set('idrac','ipmilan', 'enable', ipmi_over_lan)
  end

  def chassis_name
    racadm_get('system', 'location', 'chassis.name')
  end

  def chassis_name=(chassis_name)
    racadm_set('system', 'location', 'chassis.name', chassis_name)
  end

  def datacenter
    racadm_get('system', 'location', 'datacenter')
  end

  def datacenter=(datacenter)
    racadm_set('system', 'location', 'datacenter', datacenter)
  end

  def aisle
    racadm_get('system', 'location', 'aisle')
  end

  def aisle=(aisle)
    racadm_set('system', 'location', 'aisle', aisle)
  end

  def rack
    racadm_get('system', 'location', 'rack.name')
  end

  def rack=(rack)
    racadm_set('system', 'location', 'rack.name', rack)
  end

  def rackslot
    racadm_get('system', 'location', 'rack.slot')
  end

  def rackslot=(rackslot)
    racadm_set('system', 'location', 'rack.slot', rackslot)
  end


end