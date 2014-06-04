provider_path = Pathname.new(__FILE__).parent.parent
require 'rexml/document'

include REXML
require 'puppet/idrac/util'

Puppet::Type.type(:powerstate).provide(:powerstate) do
  desc "Dell idrac provider for import system configuration."
  def exists?
    if(checkpowerstate != '2')
      false
    else
      Puppet.info 'Server is already powered on.'
      true
    end
  end

  def create
    ensure_on
  end

  def transport
    @transport ||= Puppet::Idrac::Util.get_transport()
  end

  def ensure_on
    Puppet.info 'Attempting to power server on...'
    response = power_server_on
    if response =~ /xml version=/
      xmldoc = Document.new(response)
      output = XPath.first(xmldoc, '//n1:ReturnValue')
      if(output.text != '0')
        raise 'Could not power server on'
      else
        Puppet.info 'Server is now powering on.'
      end
    elsif response =~ /Authentication failed/
      raise 'Authentication failed, please retry with correct credentials and/or reset the idrac.'
    elsif response =~ /Connection failed./
      raise 'Connection failed, Could not connect to server. Please check IP address credentials.'
    end
  end

  def checkpowerstate
    require 'asm/wsman'
    ASM::WsMan.get_power_state({:host=>transport[:host], :user=>transport[:user], :password=>transport[:password]})
  end

  def power_server_on
    cmd = "wsman invoke -a \"RequestStateChange\" http://schemas.dell.com/wbem/wscim/1/cim-schema/2/root/dcim/DCIM_ComputerSystem?CreationClassName=\"DCIM_ComputerSystem\",Name=\"srv:system\" -h #{transport[:host]} -P 443 -u #{transport[:user]} -p #{transport[:password]} -j utf-8 -c dummy.cert -y basic -V -v -k \"RequestedState=2\""
    response = ""

    PTY.spawn(cmd) do
      |output, input, pid|
      buffer = ''
      output.readpartial(2048, buffer) until buffer =~ /Authentication failed/ || buffer =~ /xml version=/ || buffer =~ /Connection failed./ || buffer =~ /.+/
      response = buffer
    end
    return response
  end
end