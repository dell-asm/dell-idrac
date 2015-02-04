#
# Import idrac configuration
#

Puppet::Type.newtype(:importsystemconfiguration) do
  @doc = "Import idrac system configuration."

  ensurable do
    newvalue(:present) do
      provider.create
    end
    defaultto(:present)
  end

  newparam(:name) do
    desc "The test name."
    munge do |value|
      value.to_s
    end

    validate do |value|
      if value.strip.length == 0
        raise ArgumentError, "The name must contain a value. It cannot be null."
      end
    end
  end

  newparam(:configxmlfilename) do
    desc "Config Xml file name."
    munge do |value|
      value.to_s
    end

    validate do |value|
      if value.strip.length == 0
        raise ArgumentError, "The Config Xml file name must contain a value. It cannot be null."
      end
    end
  end

  newparam(:nfsipaddress) do
    desc "NFS Server ipaddress."
    munge do |value|
      value.to_s
    end

    validate do |value|
      if value.strip.length == 0
        raise ArgumentError, "The nfsipaddress must contain a value. It cannot be null."
      end
    end
  end

  newparam(:nfssharepath) do
    desc "NFS share path."
    munge do |value|
      value.to_s
    end

    validate do |value|
      if value.strip.length == 0
        raise ArgumentError, "The nfssharepath must contain a value. It cannot be null."
      end
    end
  end

  newparam(:enable_npar) do
    desc "Whether nic partitioning should be enabled"
    newvalues(true, false)
    defaultto(true)
  end

  newparam(:sysprofile) do
    desc "power setting as configured in idrac via sysprofile"
    munge do |value|
      value.to_s
    end
  end

  newparam(:target_boot_device) do
    desc "Either SD, HD, or SAN for SD card, Hard Drive, or SAN boot"
    munge do |value|
      value.to_s
    end

    validate do |value|
      if value.strip.length == 0
        raise ArgumentError, "The target_boot_device must contain a value. It cannot be null."
      end
    end
  end

  newparam(:raid_configuration) do
    desc 'The requested virtual disk configuration'
  end

  newparam(:servicetag) do
    desc "The Dell server service tag, e.g. JH870W1"
    munge do |value|
      value.to_s
    end

    validate do |value|
      if value.strip.length == 0
        raise ArgumentError, "servicetag must contain a value. It cannot be null."
      end
    end
  end

  newparam(:model) do
    desc "The Dell server model, e.g. m420, m620, m820, r620, r720."
    munge do |value|
      value.to_s
    end

    validate do |value|
      if value.strip.length == 0
        raise ArgumentError, "model must contain a value. It cannot be null."
      end
    end
  end

  newparam(:config_xml) do
    desc "The config.xml blob to use instead of exporting the server configuration"
    munge do |value|
      value.to_s
    end
  end

  newparam(:bios_settings) do
    desc "A hash of the individual BIOS Settings the user wants to set"
    munge do |settings|
      settings.keys.each do |key|
        # If settings are specified as boolean values, translate them to the
        # format idrac expects: Enabled or Disabled.
        val = settings[key]
        if val == :undef
          # This seems weird; we allow nil to stay in?
          settings.delete(key)
        elsif val.is_a?(String)
          settings[key] = 'Enabled' if ['true', 'yes'].include?(val.downcase)
          settings[key] = 'Disabled' if ['false', 'no'].include?(val.downcase)
        elsif val.is_a?(TrueClass)
          settings[key] = 'Enabled'
        elsif val.is_a?(FalseClass)
          settings[key] = 'Disabled'
        end
      end
      settings
    end
  end

  newparam(:network_config) do
    desc 'Network configuration settings'
  end

  newparam(:target_ip) do
    desc "the first target ip address"
  end

  newparam(:target_iscsi) do
    desc "the first target iscsi name"
  end

  newparam(:force_reboot) do
    desc "Whether or not the server should be rebooted"
  end

  newparam(:raid_action) do
    desc "The raid action to be performed (CREATE,UPDATE,DELETE)"
    newvalues("create", "update", "delete")
  end

end
