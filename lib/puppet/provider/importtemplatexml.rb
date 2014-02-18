require 'rexml/document'
require 'uri'
require '/etc/puppetlabs/puppet/modules/asm_lib/lib/security/encode'

include REXML

class Puppet::Provider::Importtemplatexml <  Puppet::Provider
  def initialize (ip,username,password,configxmlfilename,nfsipaddress,nfssharepath)
    @ip = ip
    @username = username
    @password = password
	  @password = URI.decode(asm_decrypt(@password))
    @configxmlfilename = configxmlfilename
    @nfsipaddress = nfsipaddress
    @nfssharepath = nfssharepath
  end

  def importtemplatexml
    response=executeimportcmd
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

  def executeimportcmd
	  resp = `wsman invoke http://schemas.dmtf.org/wbem/wscim/1/cim-schema/2/root/dcim/DCIM_LCService?SystemCreationClassName="DCIM_ComputerSystem",CreationClassName="DCIM_LCService",SystemName="DCIM:ComputerSystem",Name="DCIM:LCService" -h #{@ip} -V -v -c dummy.cert -P 443 -u #{@username} -p #{@password} -a ImportSystemConfiguration -k "IPAddress=#{@nfsipaddress}" -k "ShareName=#{@nfssharepath}" -k "ShareType=0" -k "FileName=#{@configxmlfilename}" -k "ShutdownType=1"`
	  return resp
  end
end
