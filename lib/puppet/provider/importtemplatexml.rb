require 'rexml/document'
include REXML

class Puppet::Provider::Importtemplatexml <  Puppet::Provider
  def initialize (ip,username,password,configxmlfilename,nfsipaddress,nfssharepath)
    @ip = ip
    @username = username
    @password = password
    @configxmlfilename = configxmlfilename
    @nfsipaddress = nfsipaddress
    @nfssharepath = nfssharepath
  end

  def importtemplatexml
    puts "#{@ip} -V -v -c dummy.cert -P 443 -u #{@username} -p #{@password} -a ImportSystemConfiguration -k IPAddress=#{@nfsipaddress} -k ShareName=#{@nfssharepath}  -k FileName=#{@configxmlfilename}"
    response = `wsman invoke http://schemas.dmtf.org/wbem/wscim/1/cim-schema/2/root/dcim/DCIM_LCService?SystemCreationClassName="DCIM_ComputerSystem",CreationClassName="DCIM_LCService",SystemName="DCIM:ComputerSystem",Name="DCIM:LCService" -h #{@ip} -V -v -c dummy.cert -P 443 -u #{@username} -p #{@password} -a ImportSystemConfiguration -k "IPAddress=#{@nfsipaddress}" -k "ShareName=#{@nfssharepath}" -k "ShareType=0" -k "FileName=#{@configxmlfilename}"`
    puts response
    # get instance id
    xmldoc = Document.new(response)
    instancenode = XPath.first(xmldoc, '//wsman:Selector Name="InstanceID"')
    instanceid=instancenode.text
    puts "Instance id #{instanceid}"
    return instanceid
  end  
end
