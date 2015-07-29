provider_path = Pathname.new(__FILE__).parent.parent
require 'rexml/document'
require 'uri'

include REXML
require File.join(provider_path, 'idrac')
require File.join(provider_path, 'reboot')

Puppet::Type.type(:importraidconfiguration).provide(
  :importraidconfiguration,
  :parent => Puppet::Provider::Idrac
) do

  desc "Dell idrac provider for import system configuration."

  def create
    @ip       = transport[:host]
    @username = transport[:user]
    @password = transport[:password]
    #Reset Configuration
    resetfilepath = File.join(Pathname.new(__FILE__).parent.parent.parent.parent.parent, 'files/defaultxmls/resetconfig.xml')
    resetconf

    #Reboot
    instanceid = rebootinstanse
    Puppet.info "instanceid : #{instanceid}"
    for i in 0..30
      response = checkjobstatus instanceid
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
      pdarray = Element.new "p:PDArray"
      pdarray.text = "#{disk}"
      xmlroot.add_element pdarray
    end
    raidconfigurationfile = "#{resource[:nfssharepath]}/raidconfiguration_#{transport[:host]}.xml"
    file = File.open("#{raidconfigurationfile}", "w")
    xmldoc.write(file)
    #Need to close the file
    file.close
    applyraidconf raidconfigurationfile

    #Reboot
    instanceid = rebootinstanse
    Puppet.info "instanceid : #{instanceid}"
    for i in 0..30
      response = checkjobstatus instanceid
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

  def applyraidconf(raidconfigurationfile)
    @ip       = transport[:host]
    @username = transport[:user]
    @password = transport[:password]

    response = `wsman invoke -a CreateVirtualDisk http://schemas.dmtf.org/wbem/wscim/1/cim-schema/2/root/dcim/DCIM_RAIDService?SystemCreationClassName=DCIM_ComputerSystem,CreationClassName=DCIM_RAIDService,SystemName=DCIM:ComputerSystem,Name=DCIM:RAIDService -h #{@ip} -V -v -c dummy.cert -P 443 -u #{@username} -p #{@password} -J #{raidconfigurationfile} -j utf-8 -y basic`
  end

  def rebootinstanse
	 #Reboot
    rebootfilepath = File.join(Pathname.new(__FILE__).parent.parent.parent.parent.parent, 'files/defaultxmls/reboot.xml')
    puts rebootfilepath
    obj = Puppet::Provider::Reboot.new(
      transport[:host],
      transport[:user],
      transport[:password],
      rebootfilepath
    )
    instanceid = obj.reboot
    return instanceid
  end

  def resetconf
    @ip       = transport[:host]
    @username = transport[:user]
    @password = transport[:password]
    #Reset Configuration
    resetfilepath = File.join(Pathname.new(__FILE__).parent.parent.parent.parent.parent, 'files/defaultxmls/resetconfig.xml')

    response = `wsman invoke -a ResetConfig http://schemas.dmtf.org/wbem/wscim/1/cim-schema/2/root/dcim/DCIM_RAIDService?SystemCreationClassName=DCIM_ComputerSystem,CreationClassName=DCIM_RAIDService,SystemName=DCIM:ComputerSystem,Name=DCIM:RAIDService -h #{@ip} -V -v -c dummy.cert -P 443 -u #{@username} -p #{@password} -J #{resetfilepath} -j utf-8 -y basic`
    #puts response
  end

end
