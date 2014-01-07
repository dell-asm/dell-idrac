#-------------------------------------------------------------------------------
# Access Mechanism
#-------------------------------------------------------------------------------

The Dell iDrac module uses wsman to interact with the Server iDrac.

#-------------------------------------------------------------------------------
# Functionality Supported
#-------------------------------------------------------------------------------

- Enable NIC Partitioning
- Disable NIC Partitioning

#-------------------------------------------------------------------------------
# Description
#-------------------------------------------------------------------------------

The importnparsetting type/provider supports the functionality to Enable 
and Disable NPAR setting on the Dell Server. 

#-------------------------------------------------------------------------------
# Summary of Parameters
#-------------------------------------------------------------------------------

  1. nic - (Mandatory) This parameter defines the target NIC where the NPAR 
			  settings are to be modified.
    
  2. status - (Mandatory) This parameter defines whether to enable or disable the NIC partitioning on a given NIC.
    
	3. dracipaddress - (Mandatory) This parameter defines the server iDRAC IP Address.
    
	4. dracusername - (Mandatory) This parameter defines the server iDRAC username.
				
	5. dracpassword - (Mandatory) This parameter defines the server iDRAC password.
				
	6. nfsipaddress - (Mandatory) This parameter defines the local NFS server IP address.
	
	7. nfssharepath - (Mandatory) This parameter defines the local NFS export path.
					   Note: NFS export must be created or mounted on a local machine.
    
#-------------------------------------------------------------------------------
# Usage
#-------------------------------------------------------------------------------

The Dell iDRAC module can be used by calling the importnparsetting type from the manifest
file (.pp) in the manifest folder, as shown in the example below:

Usage:- Enable NIC Partitioning:

	importnparsetting { 'nicapplyconfig':
		nic => 'NIC.Integrated.1-1-1',
		status => 'Enabled',
		dracipaddress => '172.17.15.109',
		dracusername => 'root',
		dracpassword => 'calvin',
		nfsipaddress => '172.28.15.192',
		nfssharepath => '/root/nfsexport1',
	}

Usage:- Disable NIC Partitioning:

	importnparsetting { 'nicapplyconfig':
		nic => 'NIC.Integrated.1-1-1',
		status => 'Disabled',
		dracipaddress => '172.17.15.109',
		dracusername => "root",
		dracpassword => 'calvin',
		nfsipaddress => '172.28.15.192',
		nfssharepath => '/root/nfsexport1',
	}

