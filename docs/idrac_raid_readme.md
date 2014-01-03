#-------------------------------------------------------------------------------
# Access Mechanism
#-------------------------------------------------------------------------------

The Dell iDrac module uses wsman to interact with the Server iDrac.

#-------------------------------------------------------------------------------
# Functionality Supported
#-------------------------------------------------------------------------------

- Set RAID level

#-------------------------------------------------------------------------------
# Description
#-------------------------------------------------------------------------------

The raid type/provider can be used to configure RAID on the Dell Server

#-------------------------------------------------------------------------------
# Summary of Params
#-------------------------------------------------------------------------------

	1. dracipaddress - (Mandatory) This parameter defines server iDRAC Ip Address.
    
	2. dracusername - (Mandatory) This parameter defines server iDRAC username.
				
	3. dracpassword - (Mandatory) This parameter defines server iDRAC password.
				
	4. nfsipaddress - (Mandatory) This parameter defines local nfs server Ip address.
	
	5. nfssharepath - (Mandatory) This parameter defines local nfs export path.
					   Note: nfs export should be created or mounted on local machine.
  
  6. disk - This parameter denotes the comma seperated list of disks that
      will be used for the RAID configuration.

  7. raidtype - This parameters denotes the RAID level to be set. Valid values
      are 0 or 1. Default value is 0.


