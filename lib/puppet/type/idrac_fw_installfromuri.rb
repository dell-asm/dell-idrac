Puppet::Type.newtype(:idrac_fw_installfromuri) do
  desc "Implements the WSMan-DCIM_SoftwareInstallationService .InstallFromURI method"

  ensurable

  newparam(:instance_id, :namevar => true) do
    desc "InstanceID to be updated (InstanceID is the SofwareIdentity instanceID that represents the firmware that is to be updated)"
  end

  newparam(:idrac_firmware) do
    desc "Array of hashes containing [{instance_id, component_id, uri_path},]"
  end

  newparam(:force_restart) do
    desc "Forces the restart now"
  end
end
