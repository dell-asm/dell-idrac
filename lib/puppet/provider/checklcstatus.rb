require 'rexml/document'
require 'asm/wsman'

include REXML

class Puppet::Provider::Checklcstatus < Puppet::Provider
  def initialize (ip, username, password)
    @ip = ip
    @username = username
    @password = password
  end

  def checklcstatus
    executelccmd
  end

  def executelccmd
    endpoint = {:host => @ip, :user => @username, :password => @password}
    ASM::WsMan.invoke(endpoint, 'GetRemoteServicesAPIStatus',
                      'http://schemas.dmtf.org/wbem/wscim/1/cim-schema/2/root/dcim/DCIM_LCService?SystemCreationClassName="DCIM_ComputerSystem"&CreationClassName="DCIM_LCService"&SystemName="DCIM:ComputerSystem"&Name="DCIM:LCService"',
                      :selector => '//n1:LCStatus',
                      :logger => Puppet)
  end

end
