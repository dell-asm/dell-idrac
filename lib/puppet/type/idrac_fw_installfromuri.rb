Puppet::Type.newtype(:idrac_fw_installfromuri) do
  desc "Implements the WSMan-DCIM_SoftwareInstallationService .InstallFromURI method"

  ensurable

  newparam(:instance_id, :namevar => true) do
    desc "InstanceID to be updated (InstanceID is the SofwareIdentity instanceID that represents the firmware that is to be updated)"
  end

  newparam(:uri_path) do
    desc "The URI to the firmware that will be applied \n(Example: nfs://IPADRESS/LOCATION/DUPFILENAME;mountpoint=MOUNTNAME)"
  end
 
  newparam(:force_restart, :boolean => true) do 
    desc "Force the restarts to happen automatically (if needed) or wait until the next restart"
  end

end
