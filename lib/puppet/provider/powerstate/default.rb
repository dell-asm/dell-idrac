provider_path = Pathname.new(__FILE__).parent.parent
require 'rexml/document'
include REXML
require 'puppet/idrac/util'
require File.join(provider_path, 'idrac')

Puppet::Type.type(:powerstate).provide(:powerstate,
                                       :parent => Puppet::Provider::Idrac) do
  desc "Dell idrac provider for import system configuration."
  def exists?
    if checkpowerstate != :on
      false
    else
      Puppet.info 'Server is already powered on.'
      true
    end
  end

  def create
    ensure_on
  end

  def ensure_on
    Puppet.info 'Attempting to power server on...'
    response = power_server_on
    Puppet.debug("Response of power-on operation: #{response}")
  end

  def checkpowerstate
    require 'asm/wsman'
    ASM::WsMan.get_power_state({:host=>transport[:host], :user=>transport[:user], :password=>transport[:password]})
  end

  def power_server_on
    endpoint = {:host => transport[:host], :user => transport[:user], :password => transport[:password]}
    options = {'RequestedState' => '2'}
    ASM::WsMan.invoke(endpoint, 'RequestStateChange',
    'http://schemas.dell.com/wbem/wscim/1/cim-schema/2/root/dcim/DCIM_ComputerSystem?CreationClassName="DCIM_ComputerSystem",Name="srv:system"',
    :selector => '//n1:ReturnValue',
    :logger => Puppet,
    :props => options)
  end
end
