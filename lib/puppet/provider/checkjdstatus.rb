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
    require 'asm/wsman'
    endpoint = {:host => @ip, :user => @username, :password => @password}
    schema = "http://schemas.dmtf.org/wbem/wscim/1/cim-schema/2/root/dcim/DCIM_LifecycleJob?InstanceID=#{@instanceid}"
    job_status, job_message = ASM::WsMan.invoke(endpoint, 'get', schema,
                                                :logger => Puppet,
                                                :selector => ["//n1:JobStatus", "//n1:Message"])
    if job_status =~ /completed with errors/i || job_message =~ /completed with errors/i
      'Failed'
    elsif job_status.nil? || job_status.empty?
      raise "Job ID not created"
    else
      job_status
    end
  end

end

