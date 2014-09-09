Puppet::Type.newtype(:idrac_fw_update) do
  desc "Implements the wsman -DCIM_SoftwareInstallationService .InstallfromRepository utility"

  ensurable

  newparam(:name, :namevar => true) do
    desc "Name variable, can be anything unique"
  end

  newparam(:asm_hostname) do
    desc "The ip address for the remote location of the firmware"
    validate do |value|
      unless value =~ /^(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$/
        raise ArgumentError, "%s is not a valid IP Address" % value
      end
    end
  end

  newparam(:path) do
    desc "The path to the remote location of the firmwre (on the network share)"
    validate do |value|
      unless File.directory? value
        raise ArgumentErrorm, "The path: %x does not exist" % value
      end
    end
  end
 
  newparam(:force_restart, :boolean => true) do 
    desc "Force the restarts to happen automatically (if needed) or wait until the next restart"
  end
end
