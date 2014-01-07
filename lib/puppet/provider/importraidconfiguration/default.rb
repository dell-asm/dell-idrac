provider_path = Pathname.new(__FILE__).parent.parent
require 'rexml/document'
include REXML
require File.join(provider_path, 'idrac')
require File.join(provider_path, 'checklcstatus')
require File.join(provider_path, 'checkjdstatus')
require File.join(provider_path, 'reboot')

Puppet::Type.type(:importraidconfiguration).provide(:importraidconfiguration, :parent => Puppet::Provider::Idrac) do
  desc "Dell idrac provider for import system configuration."
  $count = 0
  $maxcount = 30

  def create
   @ip = resource[:dracipaddress]
   @username = resource[:dracusername]
   @password = resource[:dracpassword]
   #Reset Configuration
   resetfilepath = File.join(Pathname.new(__FILE__).parent.parent.parent.parent.parent, 'files/defaultxmls/resetconfig.xml')
   #puts resetfilepath

   response = `wsman invoke -a ResetConfig http://schemas.dmtf.org/wbem/wscim/1/cim-schema/2/root/dcim/DCIM_RAIDService?SystemCreationClassName=DCIM_ComputerSystem,CreationClassName=DCIM_RAIDService,SystemName=DCIM:ComputerSystem,Name=DCIM:RAIDService -h #{@ip} -V -v -c dummy.cert -P 443 -u #{@username} -p #{@password} -J #{resetfilepath} -j utf-8 -y basic`
   #puts response
   
   #Reboot
   rebootfilepath = File.join(Pathname.new(__FILE__).parent.parent.parent.parent.parent, 'files/defaultxmls/reboot.xml')
   #puts rebootfilepath
   obj = Puppet::Provider::Reboot.new(resource[:dracipaddress],resource[:dracusername],resource[:dracpassword],rebootfilepath)
   instanceid = obj.reboot
   Puppet.info "instanceid : #{instanceid}"
   for i in 0..30
        obj = Puppet::Provider::Checkjdstatus.new(resource[:dracipaddress],resource[:dracusername],resource[:dracpassword],instanceid)
        response = obj.checkjdstatus
        Puppet.info "JD status : #{response}"
        if response  == "Completed"
            Puppet.info "Reset raid configuration is completed."
            break
        else
            if response  == "Failed"
				raise "Job ID is not created."
			else
				Puppet.info "Job is running, wait for 1 minute"
				sleep 60
			end
        end
    end
    if response != "Completed"
      raise "Reset raid configuration is still running."
    end
 
   #Apply raid configuration
   raidtype = resource[:raidtype]
   disk = resource[:disk]
   #puts raidtype
   #puts disk
   if raidtype == "0"
     xmlfilePath = File.join(Pathname.new(__FILE__).parent.parent.parent.parent.parent, 'files/defaultxmls/raid0configuration.xml')
   else
     xmlfilePath = File.join(Pathname.new(__FILE__).parent.parent.parent.parent.parent, 'files/defaultxmls/raid1configuration.xml')
   end
   file = File.new(xmlfilePath)
   xmldoc = Document.new(file)
   xmlroot = xmldoc.root
   #disklist = [disk]
   disklist = disk.split(/,/)
   disklist.each do |disk|
    #puts "#{disk}"
     pdarray = Element.new "p:PDArray"
     pdarray.text = "#{disk}"
     xmlroot.add_element pdarray
   end
   raidconfigurationfile = "#{resource[:nfssharepath]}/raidconfiguration_#{resource[:dracipaddress]}.xml"
   #puts raidconfigurationfile
   file = File.open("#{raidconfigurationfile}", "w")
   xmldoc.write(file)
   #Need to close the file
   file.close

   response = `wsman invoke -a CreateVirtualDisk http://schemas.dmtf.org/wbem/wscim/1/cim-schema/2/root/dcim/DCIM_RAIDService?SystemCreationClassName=DCIM_ComputerSystem,CreationClassName=DCIM_RAIDService,SystemName=DCIM:ComputerSystem,Name=DCIM:RAIDService -h #{@ip} -V -v -c dummy.cert -P 443 -u #{@username} -p #{@password} -J #{raidconfigurationfile} -j utf-8 -y basic`
   #puts response

   #Reboot
   obj = Puppet::Provider::Reboot.new(resource[:dracipaddress],resource[:dracusername],resource[:dracpassword],rebootfilepath)
   instanceid = obj.reboot
   Puppet.info "instanceid : #{instanceid}"
   for i in 0..30
        obj = Puppet::Provider::Checkjdstatus.new(resource[:dracipaddress],resource[:dracusername],resource[:dracpassword],instanceid)
        response = obj.checkjdstatus
        Puppet.info "JD status : #{response}"
        if response  == "Completed"
            Puppet.info "Raid configuration is completed."
            break
        else
            if response  == "Failed"
				raise "Job ID is not created."
			else
				Puppet.info "Job is running, wait for 1 minute"
				sleep 60
			end
        end
    end
    if response != "Completed"
      raise "Raid configuration is still running."
    end
 
  end
  
  def exists?
    #puts "Inside exist"
    obj = Puppet::Provider::Checklcstatus.new(resource[:dracipaddress],resource[:dracusername],resource[:dracpassword])
    response = obj.checklcstatus
    response = response.to_i
    if response == 0
        return false
    else
        #recursive call  method exists till lcstatus =0
        while $count < $maxcount  do
            Puppet.info "LC status busy, wait for 1 minute"
            sleep 60
            $count +=1
            exists?
        end
        raise Puppet::Error, "Life cycle controller is busy"
        return true
    end
  end

end

