provider_path = Pathname.new(__FILE__).parent.parent
require File.join(provider_path, 'BiosConfig')
require 'rexml/document'

include REXML
require File.join(provider_path, 'idrac')
require File.join(provider_path, 'reboot')

Puppet::Type.type(:updatebootorderconfiguration).provide(
  :updatebootorderconfiguration,
  :parent => Puppet::Provider::Idrac
) do

  def create
    obj = Puppet::Provider::BiosConfig.new(
      transport[:host],
      transport[:user],
      transport[:password],
      resource[:target_boot_device]
    )
    obj.GetBootSourceSetting
  end

end

