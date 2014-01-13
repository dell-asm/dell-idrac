#iDrac

####Table of Contents

1. [Overview](#overview)

##Overview

The Dell iDrac module allows the user to configure the iDrac on a Dell server. The module can be used to configure RAID, bios and network settings by providing valid XML input to the Dell Lifecycle controller.

##importbiosconfiguration

###Description

The BIOS type/provider can be used to configure various BIOS parameters
on the Dell Server

####Summary of Properties

1. _dracipaddress_ - (Mandatory) This parameter defines the server iDRAC IP Address.
    
2. _dracusername_ - (Mandatory) This parameter defines the server iDRAC username.
				
3. _dracpassword_ - (Mandatory) This parameter defines the server iDRAC password.
				
4. _nfsipaddress_ - (Mandatory) This parameter defines the local NFS server IP address.
	
5. _nfssharepath_ - (Mandatory) This parameter defines the local NFS export path. Note: NFS export must be created or mounted on the local machine.
  
6. _memtest_ - This parameter configures memtest on the server. The valid values are Enabled or Disabled. The default value is Disabled.

7. _procvirtualization_ - This parameter enables or disables VT for the processor. The valid values are Enabled or Disabled. The default value is Enabled.

8. _proccores_ - This parameter sets the number of processor cores to be enabled. The default value is "All"

9. _bootmode_ - This parameter sets the BIOS boot mode. The default value is "bios".

10. _bootseqretry_ - This parameter determines whether or not the BIOS must retry the boot. The valid values are Enabled or Disabled. The default value is Enabled.

11. _integratedraid_ - This parameter enables or disables the Integrated RAID controller. The valid values are Enabled or Disabled. The default value is Disabled.
    
12. _usbports_ - This parameter sets the number of USB ports to be enabled. The default value is "AllOn".

13. _internalusb_ - This parameter defines if the internal USB controller is on or off. The default value is "off".

14. _internalsdcard_ - This parameter defines if the internal SD card is on or off. The default value is "on".

15. _internalsdcardredundancy_ - This parameter sets the redundancy for the internal SD card. The default value is "Mirror".

16. integratednetwork1 - This parameter defines if the first integrated network controller is enabled or disabled. The default value is Enabled.


##importnpartsetting

###Description

The importnparsetting type/provider supports the functionality to Enable and Disable NPAR setting on the Dell Server. 

####Summary of Properties

1. _nic_ - (Mandatory) This parameter defines the target NIC where the NPAR settings are to be modified.
    
2. _status_ - (Mandatory) This parameter defines whether to enable or disable the NIC partitioning on a given NIC.
    
3. _dracipaddress_ - (Mandatory) This parameter defines the server iDRAC IP Address.
    
4. _dracusername_ - (Mandatory) This parameter defines the server iDRAC username.
				
5. _dracpassword_ - (Mandatory) This parameter defines the server iDRAC password.
				
6. _nfsipaddress_ - (Mandatory) This parameter defines the local NFS server IP address.
	
7. _nfssharepath_ - (Mandatory) This parameter defines the local NFS export path. Note: NFS export must be created or mounted on a local machine.

##importraidconfiguration

###Description

The raid type/provider can be used to configure RAID on the Dell Server.

####Summary of Properties

1. _dracipaddress_ - (Mandatory) This parameter defines the server iDRAC IP Address.
    
2. _dracusername_ - (Mandatory) This parameter defines the server iDRAC username.
				
3. _dracpassword_ - (Mandatory) This parameter defines the server iDRAC password.
				
4. _nfsipaddress_ - (Mandatory) This parameter defines the local NFS server IP address.
	
5. _nfssharepath_ - (Mandatory) This parameter defines the local NFS export path. Note: NFS export must be created or mounted on the local machine.
  
6. _disk_ - This parameter denotes the comma seperated list of disks that are to be used for the RAID configuration.

7. _raidtype_ - This parameter denotes the RAID level to be set. The valid values are 0 or 1. The default value is 0.

##importsystemconfiguration

###Description

The importsystemconfiguration type/provider can be used to import a single XML that defines the complete iDrac state.

####Summary of Properties

1. _dracipaddress_ - (Mandatory) This parameter defines the server iDRAC IP Address.
    
2. _dracusername_ - (Mandatory) This parameter defines the server iDRAC username.
				
3. _dracpassword_ - (Mandatory) This parameter defines the server iDRAC password.
				
4. _nfsipaddress_ - (Mandatory) This parameter defines the local NFS server IP address.
	
5. _nfssharepath_ - (Mandatory) This parameter defines the local NFS export path. Note: NFS export must be created or mounted on the local machine.

6. _configxmlfilename_ - (Mandatory) This parameter denotes the name of the XML file that is to be applied on the remote iDrac. This file should already be present on the nfs share path defined above.

##exportsystemconfiguration

###Description

The exportsystemconfiguration type/provider can be used to export the current iDrac configuration XML to a defined nfs share.

####Summary of Properties


1. _dracipaddress_ - (Mandatory) This parameter defines the server iDRAC IP Address.
    
2. _dracusername_ - (Mandatory) This parameter defines the server iDRAC username.
				
3. _dracpassword_ - (Mandatory) This parameter defines the server iDRAC password.
				
4. _nfsipaddress_ - (Mandatory) This parameter defines the local NFS server IP address.
	
5. _nfssharepath_ - (Mandatory) This parameter defines the local NFS export path. Note: NFS export must be created or mounted on the local machine.

6. _configxmlfilename_ - (Mandator) This parameter describes the name of the XML file that will contain the iDrac system configuration after the export is completed.


