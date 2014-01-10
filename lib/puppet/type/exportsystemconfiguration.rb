#
# Import idrac configuration
#

Puppet::Type.newtype(:exportsystemconfiguration) do
  @doc = "Export idrac system configuration."

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

  newparam(:dracipaddress) do
    desc "The Ip address of idrac."
    munge do |value|
      value.to_s
    end

    validate do |value|
      if value.strip.length == 0
        raise ArgumentError, "The dracipaddress must contain a value. It cannot be null."
      end
    end
  end

  newparam(:dracusername) do
    desc "User name."
    munge do |value|
      value.to_s
    end

    validate do |value|
      if value.strip.length == 0
        raise ArgumentError, "The dracusername must contain a value. It cannot be null."
      end
    end
  end

  newparam(:dracpassword) do
    desc "Password."
    munge do |value|
      value.to_s
    end

    validate do |value|
      if value.strip.length == 0
        raise ArgumentError, "The dracpassword must contain a value. It cannot be null."
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

end
