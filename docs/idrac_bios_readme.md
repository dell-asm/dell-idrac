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

The bios type/provider can be used to configures various BIOS parameters
on the Dell Server.

#-------------------------------------------------------------------------------
# Summary of Params
#-------------------------------------------------------------------------------

	1. dracipaddress - (Mandatory) This parameter defines server iDRAC Ip Address.
    
	2. dracusername - (Mandatory) This parameter defines server iDRAC username.
				
	3. dracpassword - (Mandatory) This parameter defines server iDRAC password.
				
	4. nfsipaddress - (Mandatory) This parameter defines local nfs server Ip address.
	
	5. nfssharepath - (Mandatory) This parameter defines local nfs export path.
					   Note: nfs export should be created or mounted on local machine.
  
  6. memtest - This parameter configures memtest on the server.
              Valid values are Enabled or Disabled. Default value is Disabled.

  7. procvirtualization - This parameter enables or disables VT for the processor
              Valid values are Enabled or Disabled. Default value is Enabled.

  8. proccores - This parameter sets the number of Processor cores to be
        enabled. Default value is "All"

  9. bootmode - This parameters sets the BIOS boot mode.
          Default value is "bios".

  10. bootseqretry - This parameter determines if the bios should retry boot 
        or not. Valid values are Enabled or Disabled. Default value is Enabled.

  11. integratedraid - This parameters enabled or disables the Integrated RAID
        controller. Valid values are Enabled or Disabled. Default value is Disabled.
    
  12. usbports - This parameter sets the number of usb ports to be enabled.
          Default value is "AllOn"

  13. internalusb - This parameter defines wether the internal USB controller is 
        on or off. Default value is "off"

  14. internalsdcard - This parameter defines wether the internal SD card is on
        or off. Default value is "on"

  15. internalsdcardredundancy - This parameters sets redundancy for the internal
        SD card. Default value is "Mirror"

  16. integratednetwork1 - This parameters defines wether the first integrated 
        network controller is enabled or disabled. Default value is Enabled.



