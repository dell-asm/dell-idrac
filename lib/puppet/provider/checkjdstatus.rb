# TODO: This class doesn't really need to exist.  Could be shoved into a common method instead, maybe in Puppet::Idrac::Util
class Puppet::Provider::Checkjdstatus < Puppet::Provider
  def initialize (ip, username, password, instanceid)
    @ip = ip
    @username = username
    @password = password
    @instanceid = instanceid
  end

  def wsman
    require 'asm/wsman'
    @__wsman ||= ASM::WsMan.new({:host => @ip, :user => @username, :password => @password}, :logger => Puppet)
  end

  def checkjdstatus
    resp = wsman.get_lc_job(@instanceid)
    if resp[:message_id] =~ /SYS051|LC068/i
      resp[:message_id]
    elsif resp[:code]
      wsman_err = WsManError.new
      wsman_err.code = resp[:code]
      wsman_err.reason = resp[:reason] if resp[:reason]

      raise wsman_err
    elsif resp[:percent_complete] == "100" && (resp[:job_status] =~ /completed with errors/i || resp[:message] =~ /completed with errors/i)
      'Failed'
    elsif resp[:job_status].nil? || resp[:job_status].empty?
      raise "Job ID not created"
    else
      resp[:job_status]
    end
  end

end

