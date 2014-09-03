Puppet::Type.newtype(:idrac_fw_update) do
  desc "Implements the wsman -DCIM_SoftwareInstallationService .InstallfromRepository utility"

  ensurable

  newparam(:name, :namevar => true) do
    desc "Name variable, can be anything unique"
  end

  newparam(:asm_hostname) do
    desc "The ip address for the remote location of the firmware"
  end

  newparam(:path) do
    desc "The path to the remote location of the firmwre (on the network share)"
  end
end
