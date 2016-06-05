require 'rexml/document'

include REXML

class Puppet::Provider::Reboot <  Puppet::Provider
  def initialize (ip,username,password,rebootfilepath)
    @ip = ip
    @username = username
    @password = password
    @rebootfilepath = rebootfilepath
  end

  def reboot
    response = executerebootcmd
    Puppet.info "#{response}"
    # get instance id
    xmldoc = Document.new(response)
    instancenode = XPath.first(xmldoc, '//wsman:Selector Name="InstanceID"')
    tempinstancenode = instancenode
    if tempinstancenode.to_s == ""
      raise "Job ID not created"
    end
    instanceid=instancenode.text
    Puppet.info "Instance id #{instanceid}"
    return instanceid
  end

  def rebootidrac
    # Create the reboot job
    puts "Rebooting server #{@ip}"
    #response = `wsman invoke -a CreateRebootJob http://schemas.dmtf.org/wbem/wscim/1/cim-schema/2/root/dcim/DCIM_SoftwareInstallationService?CreationClassName=DCIM_SoftwareInstallationService&SystemCreationClassName=DCIM_ComputerSystem&SystemName=IDRAC:ID&Name=SoftwareUpdate -h "#{@ip}" -V -v -c dummy.cert -P 443 -u "#{@username}" -p "#{@password}" -J #{@rebootfilepath} -j utf-8 -y basic -k "RebootJobType=2" -k "ShutdownType=1"`
    response = `wsman invoke -a CreateTargetedConfigJob http://schemas.dmtf.org/wbem/wscim/1/cim-schema/2/root/dcim/DCIM_BIOSService?SystemCreationClassName=DCIM_ComputerSystem&CreationClassName=DCIM_BIOSService&SystemName=DCIM:ComputerSystem&Name=DCIM:BIOSService -h "#{@ip}" -V -v -c dummy.cert -P 443 -u "#{@username}" -p "#{@password}" -J #{@rebootfilepath} -j utf-8 -y basic`
    xmldoc = Document.new(response)
    instancenode = XPath.first(xmldoc, '//wsman:Selector Name="InstanceID"')
    tempinstancenode = instancenode
    if tempinstancenode.to_s == ""
      msgnode = XPath.first(xmldoc, '//n1:Message')
      if msgnode.to_s =~ /No pending data present to create a Configuration job/
        return "success"
      end
      raise "Job ID not created"
    end
    instanceid=instancenode.text
    puts "instanceid #{instanceid}"
    return instanceid
  end

  def executerebootcmd
    resp = `wsman invoke -a CreateTargetedConfigJob http://schemas.dmtf.org/wbem/wscim/1/cim-schema/2/root/dcim/DCIM_RAIDService?SystemCreationClassName=DCIM_ComputerSystem,CreationClassName=DCIM_RAIDService,SystemName=DCIM:ComputerSystem,Name=DCIM:RAIDService -h #{@ip} -V -v -c dummy.cert -P 443 -u #{@username} -p #{@password} -J #{@rebootfilepath} -j utf-8 -y basic`
    return resp
  end
end
