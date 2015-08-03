require 'rexml/document'

include REXML

# TODO: This class doesn't really need to exist.  Could be shoved into a common method instead, maybe in Puppet::Idrac::Util
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
    job_status, job_message, message_id = ASM::WsMan.invoke(endpoint, 'get', schema,
                                                :logger => Puppet,
                                                :selector => ["//n1:JobStatus", "//n1:Message", "//n1:MessageID"])
    if message_id =~ /SYS051/i
      message_id
    elsif job_status =~ /completed with errors/i || job_message =~ /completed with errors/i
      'Failed'
    elsif job_status.nil? || job_status.empty?
      raise "Job ID not created"
    else
      job_status
    end
  end

end

