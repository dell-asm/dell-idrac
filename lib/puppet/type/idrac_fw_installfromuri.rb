require 'puppet/parameter/boolean'

Puppet::Type.newtype(:idrac_fw_installfromuri) do
  desc "Implements the WSMan-DCIM_SoftwareInstallationService .InstallFromURI method"

  ensurable

  newparam(:instance_id, :namevar => true) do
    desc "InstanceID to be updated (InstanceID is the SofwareIdentity instanceID that represents the firmware that is to be updated)"
  end

  newparam(:idrac_firmware) do
    desc "Array of hashes containing [{instance_id, component_id, uri_path},]"
  end

  newparam(:force_restart, :boolean => true, :parent => Puppet::Parameter::Boolean) do
    desc "Forces the restart now"
  end

  newparam(:skip_clear_job_queue, :boolean => true, :parent => Puppet::Parameter::Boolean) do
    desc "Forces the restart now"
    defaultto false
  end

  newparam(:disruptive_firmware_update, :boolean => true, :parent => Puppet::Parameter::Boolean) do
    desc "Disruptive firmware update"
    defaultto false
  end

  newparam(:install_staged_firmware, :boolean => true, :parent => Puppet::Parameter::Boolean) do
    desc "Install staged firmware update"
    defaultto false
  end
end
