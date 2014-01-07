#
# Import idrac configuration
#

Puppet::Type.newtype(:importraidconfiguration) do
    @doc = "Import idrac raid configuration."

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

    newparam(:raidtype) do
      desc "RAIDType"
      newvalues("0", "1")
      defaultto("0")
      munge do |value|
        if value.strip.length == 0
          value.to_s
        else
          value.to_s
        end
      end
    end

    newparam(:disk) do
      desc "Disks in comma separated"
      munge do |value|
        value.to_s
      end

      validate do |value|
        if value.strip.length == 0
          raise ArgumentError, "The disk must contain a value. It cannot be null."
        end
      end
    end
end
