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
        validate do |value|
            unless value =~ /^\w+$/
                raise "\'%s\' is not a valid nic partitioning status. Valid values are \"Enabled\" or \"Disabled\"" % value
            end
        end
    end

    newparam(:dracipaddress) do
      desc "The Ip address of idrac."
    end

    newparam(:dracusername) do
      desc "User name."
    end

    newparam(:dracpassword) do
      desc "Password."
    end

    newparam(:nfsipaddress) do
      desc "NFS Server ipaddress."
    end

    newparam(:nfssharepath) do
      desc "NFS share path."
    end

end
