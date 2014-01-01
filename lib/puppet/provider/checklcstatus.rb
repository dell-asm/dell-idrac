require 'rexml/document'
include REXML

class Puppet::Provider::Checklcstatus <  Puppet::Provider
  def initialize (ip,username,password)
    @ip = ip
    @username = username
    @password = password
  end
  def checklcstatus
    response = `wsman invoke -a "GetRemoteServicesAPIStatus"  http://schemas.dmtf.org/wbem/wscim/1/cim-schema/2/root/dcim/DCIM_LCService?SystemCreationClassName="DCIM_ComputerSystem",CreationClassName="DCIM_LCService",SystemName="DCIM:ComputerSystem",Name="DCIM:LCService" -h #{@ip} -V -v -c dummy.cert -P 443 -u #{@username} -p #{@password} -j utf-8 -y basic`
    puts response
    xmldoc = Document.new(response)
    lcnode = XPath.first(xmldoc, "//n1:LCStatus")
    lcstatus=lcnode.text
    puts "lc status #{lcstatus}"
    return lcstatus 
  end
end
