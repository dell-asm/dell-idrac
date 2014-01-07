#-------------------------------------------------------------------------------
# Access Mechanism
#-------------------------------------------------------------------------------

The Dell iDrac module uses wsman to interact with the Server iDrac.

#-------------------------------------------------------------------------------
# Functionality Supported
#-------------------------------------------------------------------------------

- Enable/Disable Memtest 
- Enable/Disable VT setting for the processor
- Enable/Disable ProcCores
- Set Bootmode
- Enable/Disable Integrated RAID controller
- Enable/Disable Internal USB
- Enable/Disable Internal SD Card
- Enable/Disable Integrated Network card

#-------------------------------------------------------------------------------
# Description
#-------------------------------------------------------------------------------

The BIOS type/provider can be used to configure various BIOS parameters
on the Dell Server.

#-------------------------------------------------------------------------------
# Summary of Parameters
#-------------------------------------------------------------------------------

	1. dracipaddress - (Mandatory) This parameter defines the server iDRAC IP Address.
    
	2. dracusername - (Mandatory) This parameter defines the server iDRAC username.
				
	3. dracpassword - (Mandatory) This parameter defines the server iDRAC password.
				
	4. nfsipaddress - (Mandatory) This parameter defines the local NFS server IP address.
	
	5. nfssharepath - (Mandatory) This parameter defines the local NFS export path.
					   Note: NFS export must be created or mounted on the local machine.
  
  6. memtest - This parameter configures memtest on the server.
              The valid values are Enabled or Disabled. The default value is 
              Disabled.

  7. procvirtualization - This parameter enables or disables VT for the processor.
              The valid values are Enabled or Disabled. The default value is Enabled.

  8. proccores - This parameter sets the number of processor cores to be
        enabled. The default value is "All"

  9. bootmode - This parameter sets the BIOS boot mode.
          The default value is "bios".

  10. bootseqretry - This parameter determines whether or not the BIOS must 
                    retry the boot. The valid values are Enabled or Disabled. 
                    The default value is Enabled.

  11. integratedraid - This parameter enables or disables the Integrated RAID
        controller. The valid values are Enabled or Disabled. The default value is Disabled.
    
  12. usbports - This parameter sets the number of USB ports to be enabled.
          The default value is "AllOn".

  13. internalusb - This parameter defines if the internal USB controller is 
        on or off. The default value is "off".

  14. internalsdcard - This parameter defines if the internal SD card is on
        or off. The default value is "on".

  15. internalsdcardredundancy - This parameter sets the redundancy for the internal
        SD card. The default value is "Mirror".

  16. integratednetwork1 - This parameter defines if the first integrated 
        network controller is enabled or disabled. The default value is Enabled.




