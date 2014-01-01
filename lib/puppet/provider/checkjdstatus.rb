require 'rexml/document'
include REXML

class Puppet::Provider::Checkjdstatus <  Puppet::Provider
  def initialize (ip,username,password,instanceid)
    @ip = ip
    @username = username
    @password = password
    @instanceid = instanceid
  end
  def checkjdstatus
    #Get the job status
    puts "InstanceID=#{@instanceid} -h #{@ip} -V -v -c dummy.cert -P 443 -u #{@username} -p #{@password} -j utf-8 -y basic"
    response = `wsman get "http://schemas.dmtf.org/wbem/wscim/1/cim-schema/2/root/dcim/DCIM_LifecycleJob?InstanceID=#{@instanceid}" -h #{@ip} -V -v -c dummy.cert -P 443 -u #{@username} -p #{@password} -j utf-8 -y basic`
    puts response
    xmldoc = Document.new(response)
    jdnode = XPath.first(xmldoc, "//n1:JobStatus")
    jdstatus=jdnode.text
    puts "jd status #{jdstatus}"
    return jdstatus
  end
end

