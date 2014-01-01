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

    newparam(:configxmlfilename) do
      desc "Config Xml file name."
    end

    newparam(:nfsipaddress) do
      desc "NFS Server ipaddress."
    end

    newparam(:nfssharepath) do
      desc "NFS share path."
    end
end
