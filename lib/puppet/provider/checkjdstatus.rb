require 'rexml/document'

include REXML

class Puppet::Provider::Checkjdstatus <  Puppet::Provider
  def initialize (ip,username,password,instanceid)
    @ip = ip
    @username = username
    @password = password
    @instanceid = instanceid
  end

  #Get the job status
  def checkjdstatus
    response = executecmd
    Puppet.info "#{response}"
    xmldoc = Document.new(response)
    jdnode = XPath.first(xmldoc, "//n1:JobStatus")
    if !jdnode || jdnode.text.empty?
      raise "Job ID not created"
    else 
      jdnode.text
    end
  end

  def executecmd
    resp = `wsman get "http://schemas.dmtf.org/wbem/wscim/1/cim-schema/2/root/dcim/DCIM_LifecycleJob?InstanceID=#{@instanceid}" -h #{@ip} -V -v -c dummy.cert -P 443 -u #{@username} -p #{@password} -j utf-8 -y basic`
    return resp
  end
end

