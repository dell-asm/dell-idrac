#
# Import idrac configuration
#

Puppet::Type.newtype(:importbiosconfiguration) do
  @doc = "Import idrac bios configuration."

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

  newparam(:memtest) do
    desc "MemTest is Enable or Disable."
    newvalues("Enabled", "Disabled")
    defaultto("Disabled")
    munge do |value|
      if value.strip.length == 0
        value.to_s
      else
        value.to_s
      end
    end
  end

  newparam(:procvirtualization) do
    desc "ProcVirtualization is Enable or Disable."
    newvalues("Enabled", "Disabled")
    defaultto("Enabled")
    munge do |value|
      if value.strip.length == 0
        value.to_s
      else
        value.to_s
      end
    end
  end

  newparam(:proccores) do
    desc "ProcCores."
    defaultto("All")
    munge do |value|
      if value.strip.length == 0
        value.to_s
      else
        value.to_s
      end
    end
  end

  newparam(:bootmode) do
    desc "BootMode."
    defaultto("Bios")
    munge do |value|
      if value.strip.length == 0
        value.to_s
      else
        value.to_s
      end
    end
  end

  newparam(:bootseqretry) do
    desc "BootSeqRetry is Enable or Disable."
    newvalues("Enabled", "Disabled")
    defaultto("Disabled")
    munge do |value|
      if value.strip.length == 0
        value.to_s
      else
        value.to_s
      end
    end
  end

  newparam(:integratedraid) do
    desc "IntegratedRaid is Enable or Disable."
    newvalues("Enabled", "Disabled")
    defaultto("Disabled")
    munge do |value|
      if value.strip.length == 0
        value.to_s
      else
        value.to_s
      end
    end
  end

  newparam(:usbports) do
    desc "UsbPorts"
    defaultto("AllOn")
    munge do |value|
      if value.strip.length == 0
        value.to_s
      else
        value.to_s
      end
    end
  end

  newparam(:internalusb) do
    desc "InternalUsb is On or Off."
    newvalues("On", "Off")
    defaultto("Off")
    munge do |value|
      if value.strip.length == 0
        value.to_s
      else
        value.to_s
      end
    end
  end

  newparam(:internalsdcard) do
    desc "InternalSdCard is On or Off."
    newvalues("On", "Off")
    defaultto("On")
    munge do |value|
      if value.strip.length == 0
        value.to_s
      else
        value.to_s
      end
    end
  end

  newparam(:internalsdcardredundancy) do
    desc "InternalSdCardRedundancy"
    defaultto("Mirror")
    munge do |value|
      if value.strip.length == 0
        value.to_s
      else
        value.to_s
      end
    end
  end

  newparam(:integratednetwork1) do
    desc "IntegratedNetwork1 is Enable or Disable."
    newvalues("Enabled", "Disabled")
    defaultto("Enabled")
    munge do |value|
      if value.strip.length == 0
        value.to_s
      else
        value.to_s
      end
    end
  end

  newparam(:biosbootseq) do
    desc "BiosBootSeq"
    defaultto("HardDisk.List.1-1, NIC.Integrated.1-1-1, NIC.Integrated.1-2-1")
    munge do |value|
      if value.strip.length == 0
        value.to_s
      else
        value.to_s
      end
    end
  end

end
