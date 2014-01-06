require 'rexml/document'
include REXML
require 'pty'

class Puppet::Provider::Checklcstatus <  Puppet::Provider
  def initialize (ip,username,password)
    @ip = ip
    @username = username
    @password = password
  end

  def checklcstatus

    cmd = "wsman invoke -a \"GetRemoteServicesAPIStatus\"  http://schemas.dmtf.org/wbem/wscim/1/cim-schema/2/root/dcim/DCIM_LCService?SystemCreationClassName=\"DCIM_ComputerSystem\",CreationClassName=\"DCIM_LCService\",SystemName=\"DCIM:ComputerSystem\",Name=\"DCIM:LCService\" -h #{@ip} -V -v -c dummy.cert -P 443 -u #{@username} -p #{@password} -j utf-8 -y basic"
    #puts ("#{cmd}")
    lcstatus = ""
    response = ""

    PTY.spawn(cmd) do
        |output, input, pid|
        #input.write("hello from parent\n")
        buffer = ""
        output.readpartial(2048, buffer) until buffer =~ /Authentication failed/ || buffer =~ /xml version=/ || buffer =~ /Connection failed./ || buffer =~ /.+/
        #puts "#{buffer}"
        response = buffer
    end
   
    if response =~ /xml version=/
        xmldoc = Document.new(response)
        lcnode = XPath.first(xmldoc, "//n1:LCStatus")
        templcnode = lcnode
        if templcnode.to_s == ""
         raise "LC status not valid"
        end
        lcstatus=lcnode.text
        Puppet.info "lc status #{lcstatus}"
       # return lcstatus
    end

    if response =~ /Authentication failed/
        raise "Authentication failed, please retry with correct credentials after resetting the iDrac."
    end

     if response =~ /Connection failed./
         raise "Connection failed, Couldn't connect to server. Please check IP address credentials."
     end

return lcstatus
  end
end
