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

The raid type/provider can be used to configure RAID on the Dell Server.

#-------------------------------------------------------------------------------
# Summary of Parameters
#-------------------------------------------------------------------------------

	1. dracipaddress - (Mandatory) This parameter defines the server iDRAC IP Address.
    
	2. dracusername - (Mandatory) This parameter defines the server iDRAC username.
				
	3. dracpassword - (Mandatory) This parameter defines the server iDRAC password.
				
	4. nfsipaddress - (Mandatory) This parameter defines the local NFS server IP 
                    address.
	
	5. nfssharepath - (Mandatory) This parameter defines the local NFS export path.
					   Note: NFS export must be created or mounted on the local machine.
  
  6. disk - This parameter denotes the comma seperated list of disks that are 
            to be used for the RAID configuration.

  7. raidtype - This parameter denotes the RAID level to be set. The valid values
      are 0 or 1. The default value is 0.



