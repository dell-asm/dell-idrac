require 'puppet/idrac/util'
require 'puppet_x/puppetlabs/transport/idrac'
require 'asm/wsman'


Puppet::Type.type(:raid_configuration).provide(:default, :parent => Puppet::Provider) do
  desc "Dell idrac provider for managing raid configuration through wsman"

  mk_resource_methods

  def transport
    @transport ||= begin
      transport = PuppetX::Puppetlabs::Transport.retrieve(:resource_ref => resource[:transport], :catalog => resource.catalog, :provider => 'idrac')
      Puppet::Idrac::Util.transport = transport.endpoint
      transport.endpoint
    end
  end

  def wsman
    @wsman ||= ASM::WsMan.new(transport, :logger => Puppet)
  end

  def wsman_client
    wsman.client
  end

  def flush
    wsman.run_raid_config_job(:target => resource[:name])
  end

  def nonraid_disks
    current_disk_modes[:nonraid]
  end

  def nonraid_disks=(disks)
    reset_config
    set_disk_modes(disks, :nonraid)
  end

  def raid_disks
    current_disk_modes[:raid]
  end

  def raid_disks=(disks)
    reset_config
    set_disk_modes(disks, :raid)
  end

  def physical_disks
    @physical_disks ||= wsman.physical_disk_views
  end

  def current_disk_modes
    disk_modes = {:raid => [], :nonraid => []}

    physical_disks.each do |disk|
      if disk[:raid_status] == "8"
        disk_modes[:nonraid] << disk[:fqdd]
      else
        disk_modes[:raid] << disk[:fqdd]
      end
    end

    disk_modes
  end

  def reset_config
    # Reset configuration job only needs to be triggered once, don't keep adding the same job
    return if @reset_queued

    wsman_client.invoke("ResetConfig", ASM::WsMan::RAID_SERVICE,
                        :params => {:target => resource[:name]},
                        :required_params => [:target],
                        :optional_params => [],
                        :return_value => "0")

    @reset_queued = true
  end

  def set_disk_modes(disks_to_set, mode)
    disks_to_set.each do |disk|
      # We will get an error if we try to set the disk to the same mode it's already in
      next if current_disk_modes[mode].include?(disk)

      action = mode == :nonraid ? "ConvertToNonRAID" : "ConvertToRAID"
      wsman_client.invoke(action, ASM::WsMan::RAID_SERVICE,
                          :params => {"PDArray" => disk},
                          :required_params => ["PDArray"],
                          :optional_params => [],
                          :return_value => "0")
    end
  end

end


