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
    response = `wsman invoke -a CreateTargetedConfigJob http://schemas.dmtf.org/wbem/wscim/1/cim-schema/2/root/dcim/DCIM_RAIDService?SystemCreationClassName=DCIM_ComputerSystem,CreationClassName=DCIM_RAIDService,SystemName=DCIM:ComputerSystem,Name=DCIM:RAIDService -h #{@ip} -V -v -c dummy.cert -P 443 -u #{@username} -p #{@password} -J #{@rebootfilepath} -j utf-8 -y basic`
    puts response
    # get instance id
    xmldoc = Document.new(response)
    instancenode = XPath.first(xmldoc, '//wsman:Selector Name="InstanceID"')
    tempinstancenode = instancenode
    if tempinstancenode.to_s == ""
      raise "Job ID not created"
    end
    instanceid=instancenode.text
    puts "Instance id #{instanceid}"
    return instanceid
  end  
end
