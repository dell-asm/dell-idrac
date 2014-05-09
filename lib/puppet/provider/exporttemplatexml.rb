require 'rexml/document'
require 'puppet/provider/checkjdstatus'

include REXML

class Puppet::Provider::Exporttemplatexml <  Puppet::Provider
  def initialize (ip,username,password, resource, nfswritepath='/var/nfs')
    @ip = ip
    @username = username
    @password = password
    @resource = resource
    @nfswritepath = nfswritepath
  end

  def exporttemplatexml
	  response =commandexe
    Puppet.info "#{response}"
    # get instance id
    xmldoc = Document.new(response)
    instancenode = XPath.first(xmldoc, '//wsman:Selector Name="InstanceID"')
    tempinstancenode = instancenode
    if tempinstancenode.to_s == ""
      raise "Job ID not created"
    end
    instanceid=instancenode.text
    puts "Instance id #{instanceid}"
    move_config_xml(instanceid)
    return instanceid
  end

  def commandexe
    command = "wsman invoke http://schemas.dmtf.org/wbem/wscim/1/cim-schema/2/root/dcim/DCIM_LCService?SystemCreationClassName=\"DCIM_ComputerSystem\",CreationClassName=\"DCIM_LCService\",SystemName=\"DCIM:ComputerSystem\",Name=\"DCIM:LCService\" -h #{@ip} -V -v -c dummy.cert -P 443 -u #{@username} -p #{@password} -a ExportSystemConfiguration -k \"IPAddress=#{@resource['nfsipaddress']}\" -k \"ShareName=#{@nfswritepath}\" -k \"ShareType=0\" -k \"FileName=#{@resource['configxmlfilename']}\""
	  resp = `#{command}`
	  return resp
  end

  #Just puts the xml in the idrac_config_xml folder (for use with importsystemconfiguration later), writing to /var/nfs due to nfs write permissions
  def move_config_xml(instanceid)
    obj = Puppet::Provider::Checkjdstatus.new(@ip,@username,@password,instanceid)
    for i in 0..30
      response = obj.checkjdstatus
      if response  == "Completed"
        Puppet.info "Export System Configuration is completed."
        FileUtils.mv("#{@nfswritepath}/#{@resource[:configxmlfilename]}", @resource[:nfssharepath])
        break
      else
        if response  == "Failed"
          raise "Job Failed."
        else
          Puppet.info "Job is running, wait for 1 minute."
          sleep 5
        end
      end
    end
    if response != "Completed"
      raise "Export System Configuration has not completed."
    end
  end
end
