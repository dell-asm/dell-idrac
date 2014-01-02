#
#  Enable/Disables Nic Partitioning on server
#

Puppet::Type.newtype(:importnparsetting) do
    @doc = "Enable/Disable NIC partitioning on server."

    ensurable do
        newvalue(:present) do
            provider.create
        end
     defaultto(:present)
    end

    newparam(:name) do
        desc "The Namevar."
        isnamevar
        validate do |value|
            unless value =~ /^\w+$/
                raise "\'%s\' is not a valid title." % value
            end
        end

    end

    newparam(:nic) do
      desc "The Target NIC where nic partitioning has to be modified."
      isrequired
      validate do |value|
            unless value =~ /\w+/
                raise "\'%s\' is not a valid nic name. Eg. NIC.Integrated.1-1-1" % value
            end
        end
    end
    
    newparam(:status) do
        desc "The Required status of Nic Partitioning."
        isrequired
        newvalues("Enabled", "Disabled")
        munge do |value|
            if value.strip.length == 0
                value.to_s
            else
                value.to_s
            end
        end

    end

    newparam(:dracipaddress) do
      desc "The Ip address of idrac."
      validate do |value|
        if value.strip.length == 0
          raise ArgumentError, "Server drac Ip address must contain a value. It cannot be null."
        end
      end
    end

    newparam(:dracusername) do
      desc "User name."
 	  validate do |value|
        if value.strip.length == 0
          raise ArgumentError, "Server drac username must contain a value. It cannot be null."
        end
      end
    end

    newparam(:dracpassword) do
      desc "Password."
 	  validate do |value|
        if value.strip.length == 0
          raise ArgumentError, "Server drac password must contain a value. It cannot be null."
        end
      end
    end

    newparam(:nfsipaddress) do
      desc "NFS Server ipaddress."
 	  validate do |value|
        if value.strip.length == 0
          raise ArgumentError, "The NFS share ipaddress must contain a value. It cannot be null."
        end
      end
    end

    newparam(:nfssharepath) do
      desc "NFS share path." 
      validate do |value|
        if value.strip.length == 0
          raise ArgumentError, "The NFS sharepath must contain a value. It cannot be null."
        end
      end
    end

end
