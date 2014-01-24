provider_path = Pathname.new(__FILE__).parent.parent
require File.join(provider_path, 'BiosConfig')
require 'rexml/document'

include REXML
require File.join(provider_path, 'idrac')
require File.join(provider_path, 'checklcstatus')
require File.join(provider_path, 'checkjdstatus')
require File.join(provider_path, 'reboot')

Puppet::Type.type(:updatebootorderconfiguration).provide(:updatebootorderconfiguration, :parent => Puppet::Provider::Idrac) do
  $count = 0
  $maxcount = 30
  def create
    obj = Puppet::Provider::BiosConfig.new(resource[:dracipaddress],resource[:dracusername],resource[:dracpassword],resource[:target_boot_device])
    obj.GetBootSourceSetting
  end

  def lcstatus
    obj = Puppet::Provider::Checklcstatus.new(resource[:dracipaddress],resource[:dracusername],resource[:dracpassword])
    response = obj.checklcstatus
    return response
  end

  def exists?
    response =  lcstatus
    response = response.to_i
    if response == 0
      return false
    else
      #recursive call  method exists till lcstatus =0
      while $count < $maxcount  do
        Puppet.info "LC status busy, wait for 1 minute"
        sleep 60
        $count +=1
        exists?
      end
      raise Puppet::Error, "Life cycle controller is busy"
      return true
    end
  end
end

