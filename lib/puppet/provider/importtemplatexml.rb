require 'rexml/document'
require 'json'
require 'nokogiri'
require 'hashie'
require 'active_support'
require 'active_support/core_ext'
require 'puppet/idrac/util'

include REXML

class Puppet::Provider::Importtemplatexml <  Puppet::Provider

  attr_accessor :embedded_sata_change
  attr_accessor :attempt

  def initialize (ip,username,password,resource, exported_postfix='base')
    @ip = ip
    @username = username
    @password = password
    @resource = resource
    @bios_settings = resource[:bios_settings]
    @templates_dir = File.join(Puppet::Module.find('idrac').path, 'templates')
    @exported_postfix = exported_postfix
    @boot_device = resource[:target_boot_device]
    @boot_mode = @bios_settings['boot_mode']

    if fc630_with_vsan_on_hdd?
      @resource[:raid_configuration] = fc630_raid_configuration
    end
    Puppet.info("Boot mode is %s" %[@boot_mode])
    if @boot_mode == 'BIOS_MODE' && @boot_device =~ /LOCAL_FLASH_STORAGE/i
      if boss_controller
        Puppet.debug("Found BOSS controller: " + boss_controller.to_s + " including RAID config for Local Flash Storage.")
      elsif get_satadom
        Puppet.debug("Found SATADOM for Local Flash Storage: " + get_satadom.to_s)
      else
        raise("No Local Flash Storage Found.  BOSS controller with 2 disks or SATADOM required.")
      end
    end
  end

  def importtemplatexml
    Puppet::Idrac::Util.wait_for_lc_ready
    reset_xml_base
    munge_config_xml
    execute_import
  end

  # Helper check that just sees if the iscsi/fcoe offloads are set as we want them.  Helps to avoid an extra import sometimes
  def offloads_in_sync?
    get_config_changes
    additions = @changes['whole'].merge(@changes['partial'])
    offload_attrs = ['FCoEOffloadMode', 'iScsiOffloadMode']
    nic_changes = additions.select do  |k,v|
      k.include?('NIC.') && offload_attrs.any? {|attr| v[attr]}
    end
    nic_changes.each do |nic_fqdd, attrs|
      attrs.each do |attr, value|
        if offload_attrs.include?(attr)
          existing_value = find_attribute_value(xml_base, nic_fqdd, attr, true)
          unless existing_value == value
            return false
          end
        end
      end
    end
    true
  end

  def execute_import(file_name=@resource['configxmlfilename'])
    require 'asm/util'
    pending_attempts = 1
    props = {'IPAddress' => @resource[:nfsipaddress] || ASM::Util.get_preferred_ip(@ip),
             'ShareName' => @resource['nfssharepath'],
             'ShareType' => '0',
             'FileName' => file_name,
             'ShutdownType' => '0'}
    forced_shutdown = false
    begin
      job_id = Puppet::Idrac::Util.wsman_system_config_action(:import, props)
      wait_for_import(job_id)
    rescue Puppet::Idrac::ShutdownError
      if forced_shutdown
        raise('Server could not be shut down during ImportSystemConfiguration')
      else
        Puppet.info("Server could not be shut down gracefully with import.  Forcing shutdown...")
        forced_shutdown = true
        props['ShutdownType'] = '1'
        retry
      end
    rescue Puppet::Idrac::PendingChangesError
      pending_attempts += 1
      if pending_attempts <= 10
        Puppet.info("Server has pending changes.  Waiting to give them time to clear...")
        sleep 30
        retry
      elsif pending_attempts == 11
        Puppet::Idrac::Util.wait_for_running_jobs
        Puppet.info("Server still has pending changes. Clearing job queue")
        Puppet::Idrac::Util.clear_job_queue(false)
        Puppet::Idrac::Util.wait_for_idrac
        retry
      elsif pending_attempts == 12
        Puppet::Idrac::Util.wait_for_running_jobs
        Puppet.warn("Server still has pending changes. No jobs running. Executing CLEARALL_FORCE")
        Puppet::Idrac::Util.clear_job_queue(true)
        Puppet::Idrac::Util.wait_for_idrac
        retry
      else
        raise('Server has pending changes that are not clearing on their own.')
      end
    end

  end

  def wait_for_import(instance_id)
    timed_out = false
    job_status_obj = Puppet::Provider::Checkjdstatus.new(@ip, @username, @password, instance_id)
    Puppet.info "Instance id #{instance_id}"
    for i in 0..30
      response = job_status_obj.checkjdstatus
      Puppet.info "JD status : #{response}"
      case response
        when 'Completed'
          Puppet.info 'Import System Configuration is completed.'
          return
        when 'Failed'
          raise(Puppet::Idrac::ConfigError, 'ImportSystemConfiguration job failed')
        when 'SYS051'
          raise(Puppet::Idrac::ShutdownError, 'System could not be gracefully shut down')
        when 'LC068'
          raise(Puppet::Idrac::PendingChangesError, 'System has changes pending')
        else
          Puppet.info "Job is running, wait for 1 minute"
          sleep 60
      end
    end

    timed_out = true
    raise "Import System Configuration is still running."
  ensure
    raise $! if timed_out

    begin
      # After ImportSystemConfiguration completes iDrac will automatically kick off an
      # ExportSystemConfiguration. The sleep here is recommended by the LC team to make
      # sure that job has started before waiting for LC ready.
      sleep 60
      Puppet::Idrac::Util.wait_for_lc_ready
    rescue
      Puppet.info("Failed to wait for LC ready: %s: %s" % [$!.class, $!.to_s])
    end
  end

  def find_target_bios_setting(attr_name)
    @__bios_enumeration ||= wsman.bios_enumerations.inject({}) do |acc, enum|
      acc[enum[:attribute_name]] = enum
      acc
    end

    @__bios_enumeration[attr_name]
  end

  def get_config_changes
    return @changes if @changes
    changes = default_changes
    nic_changes = process_nics
    changes.deep_merge!(nic_changes)
    #if idrac is booting from san, configure networks / virtual identities
    munge_network_configuration(@resource[:network_config], changes, @boot_device) if @boot_device == 'iSCSI' || @boot_device == 'FC'
    if @resource[:ensure] != :teardown && (@boot_device == 'iSCSI' || @boot_device == 'FC')
      munge_bfs_bootdevice(changes)
    end
    @changes = changes
  end

  # Format of data for partial/whole changes:
  #  Key is Name/FQDD of Attribute/Component.  If the value is a hash, it is assumed to be a component (and the hash contains the attributes)
  # If the value is a string, it is assumed to be an attribute (or if it is a list, it is a list of the attributes that have the same Name, but different values in the same Component)
  #
  #Format of data for removing changes:
  # changes['remove'] is the list of components to remove. The key name corresponds to a component; if the value for that key is an empty list, remove the component corresponding to the key name.  Otherwise, remove the nodes in the list under that key.
  #For example:  {node1: [], node2: ["attr1"=>[]]}.  Component FQDD=node1 will be removed, and Attribute Name=attr1 under Component FQDD=node2 will be removed
  #
  #
  def default_changes
    changes = {"partial"=>{"BIOS.Setup.1-1"=>{}}, "whole"=>{}, "remove"=> {"attributes"=>{}, "components"=>{}}}
    changes["whole"]["LifecycleController.Embedded.1"] = { "LCAttributes.1#CollectSystemInventoryOnRestart" => "Enabled" }
    #We populate the BIOS settings from incoming data first, because we may need to overwrite a setting for our purposes later
    @bios_settings.keys.each do |key|
      unless @bios_settings[key].nil? || @bios_settings[key].empty?
        if @bios_settings[key] == 'n/a'
          changes["remove"]["attributes"]["BIOS.Setup.1-1"] ||= []
          changes["remove"]["attributes"]["BIOS.Setup.1-1"] << key
        else
          changes["partial"]["BIOS.Setup.1-1"][key] = @bios_settings[key]
        end
      end
    end

    # Always disable ErrPrompt so we can avoid a hangup due to a user needing to put input on the server manually
    changes["partial"]["BIOS.Setup.1-1"]["ErrPrompt"] = "Disabled"

    # Always want to turn on IntegratedRaid with teardown, so RAID info can still be gathered from idrac/wsman queries
    if @boot_device =~ /WITH_RAID|HD/i || @resource[:ensure] == :teardown
      changes["partial"].deep_merge!("BIOS.Setup.1-1" => {"IntegratedRaid" => "Enabled"})
    end

    # RAID is disabled in BIOS and re-enabled after teardown
    if @boot_device == 'SD' && @resource[:ensure] != :teardown
      changes["partial"].deep_merge!("BIOS.Setup.1-1" => {"IntegratedRaid" => "Disabled"})
    end

    if @boot_device =~ /LOCAL_FLASH_STORAGE/i
      if @boot_mode == 'BIOS_MODE'
        #First check for BOSS device, if no BOSS device, we have to have SATADOM or fail
        storage_fqdd = boss_controller
        storage_fqdd ||= get_satadom
        raise("No valid storage controller. Local flash storage boot requires BOSS or SATADOM storage.") unless storage_fqdd
        Puppet.info("Boot device controller is: " + storage_fqdd)
        changes["partial"].deep_merge!("BIOS.Setup.1-1" => {"HddSeq" => storage_fqdd})
      end
      if is_sd_card?
        changes["partial"].deep_merge!("BIOS.Setup.1-1" => {"InternalSdCard" => "Off"})
        changes["remove"]["attributes"]["BIOS.Setup.1-1"] ||= []
        changes["remove"]["attributes"]["BIOS.Setup.1-1"].push("InternalSdCardRedundancy", "InternalSdCardPrimaryCard")
      end
    end

    if @boot_device =~ /HD/i
      #We turn off SD card in case of Hdd boot.  We don't want it on to potentially interfere with the esxi boot order (it doesn't follow the BiosBootSeq)
      changes["partial"].deep_merge!("BIOS.Setup.1-1" => {"InternalSdCard" => "Off"})
      # since we set SD card to off, ensure we don't set any other SD card related attributes
      changes["remove"]["attributes"]["BIOS.Setup.1-1"] ||= []
      changes["remove"]["attributes"]["BIOS.Setup.1-1"].push("InternalSdCardRedundancy", "InternalSdCardPrimaryCard")
      if is_embedded_raid?
        changes["partial"].deep_merge!("BIOS.Setup.1-1" => {"EmbSata" => "RaidMode"})
        changes["partial"].deep_merge!("BIOS.Setup.1-1" => {"SecurityFreezeLock" => "Disabled"})
        changes["partial"].deep_merge!("BIOS.Setup.1-1" => {"WriteCache" => "Disabled"})
      end
    end

    #Boot Device could be SD_WITHOUT_RAID or SD_WITH_RAID.  Raid Settings are handled above for WITH_RAID
    if @boot_device =~ /SD/i
      changes["partial"].deep_merge!("BIOS.Setup.1-1" => {"InternalSdCard" => "On"})
      changes["partial"].deep_merge!("BIOS.Setup.1-1" => {"InternalSdCardRedundancy" => "Mirror"})
      changes["partial"].deep_merge!("BIOS.Setup.1-1" => {"HddSeq" => "Disk.SDInternal.1-1"})
    end

    if fc630_with_vsan_on_hdd?
      xml_base.xpath("//Component[contains(@FQDD, 'RAID.Embedded.')]").remove
      changes["partial"].deep_merge!("BIOS.Setup.1-1" => {"EmbSata" => "RaidMode"})
      changes["partial"].deep_merge!("BIOS.Setup.1-1" => {"IntegratedRaid" => "Enabled"})
      #TODO Needs to remove the hard-code value.
      changes["partial"].deep_merge!("BIOS.Setup.1-1" => {"HddSeq" => "RAID.Integrated.1-1"})
      changes["partial"].deep_merge!("BIOS.Setup.1-1" => {"InternalSdCard" => "Off"}) if is_sd_card?

      changes["remove"]["attributes"]["BIOS.Setup.1-1"] ||= []
      changes["remove"]["attributes"]["BIOS.Setup.1-1"] << "SecurityFreezeLock"
    elsif @boot_device =~ /AHCI_VSAN/i
      # Delete embedded disk component in case we are setting EmbSata to AhciMode
      xml_base.xpath("//Component[contains(@FQDD, 'RAID.Embedded.')]").remove
      changes["partial"].deep_merge!("BIOS.Setup.1-1" => {"EmbSata" => "AhciMode"})
      changes["partial"].deep_merge!("BIOS.Setup.1-1" => {"SecurityFreezeLock" => "Disabled"})
      changes["partial"].deep_merge!("BIOS.Setup.1-1" => {"WriteCache" => "Disabled"})
      changes["partial"].deep_merge!("BIOS.Setup.1-1" => {"HddSeq" => get_boot_sata_disk})
      changes["partial"].deep_merge!("BIOS.Setup.1-1" => {"InternalSdCard" => "Off"}) if is_sd_card?
    elsif @boot_device =~ /VSAN/i
      changes["partial"].deep_merge!("BIOS.Setup.1-1" => {"InternalSdCard" => "On"})
      changes["partial"].deep_merge!("BIOS.Setup.1-1" => {"InternalSdCardRedundancy" => "Mirror"})
      changes["partial"].deep_merge!("BIOS.Setup.1-1" => {"IntegratedRaid" => "Enabled"})
      changes["partial"].deep_merge!("BIOS.Setup.1-1" => {"HddSeq" => "Disk.SDInternal.1-1"})
    end

    #If we have target boot device = NONE or NONE_WITH_RAID, we don't want to edit boot settings.
    #If installing an OS, we need BootMode=Bios
    if @boot_device =~ /^NONE/i
      changes["remove"]["attributes"]["BIOS.Setup.1-1"] ||= []
      changes["remove"]["attributes"]["BIOS.Setup.1-1"] << "BiosBootSeq"
    else
      if @boot_mode == 'UEFI_MODE'
        changes["partial"]["BIOS.Setup.1-1"]["BootMode"] = "Uefi"
      else
        changes["partial"]["BIOS.Setup.1-1"]["BootMode"] = "Bios"
      end
    end

    unless nvdimm_attrs_in_sync?
      changes["partial"]["BIOS.Setup.1-1"]["PersistentMemoryMode"] = "NVDIMM"
      changes["partial"]["BIOS.Setup.1-1"]["NvdimmFactoryDefault"] = "NvdimmFactoryDefaultEnable"
      changes["partial"]["BIOS.Setup.1-1"]["NvdimmReadOnly"] = "NvdimmReadOnlyDisable"
      changes["partial"]["BIOS.Setup.1-1"]["NvdimmInterleaveSupport"] = "NvdimmInterleaveDisable"
    end

    changes
  end

  def physical_disks
    @physical_disks ||= Puppet::Idrac::Util.view_disks(:physical)
  end

  def is_sd_card?
    disks_enum = physical_disks
    sd_disks = []
    disks_enum.xpath('//Envelope/Body/PullResponse/Items/DCIM_PhysicalDiskView').each do |x|
      sd_disks << x.at_xpath('FQDD') if x.at_xpath('MediaType').text != '0'
    end
    !sd_disks.empty?
  end

  def get_boot_sata_disk
    # If we find a SATADOM device, prefer it, else fallback to getting first SATA disk
    sata_disk = get_satadom
    if sata_disk
      sata_disk
    else
      get_first_sata_disk
    end
  end

  def get_first_sata_disk
    disks_enum = physical_disks
    sata_disks = []
    disks_enum.xpath('//Envelope/Body/PullResponse/Items/DCIM_PhysicalDiskView').each do |x|
      slot = x.xpath('Slot').text
      connector = x.xpath('Connector').text
      bus_protocol = x.xpath('BusProtocol').text
      sata_disks << "%s-%s" % [slot, connector] if bus_protocol == '5'
    end
    raise("Embedded SATA Disk not found") if sata_disks.empty?

    Puppet.debug("SATA Disk: #{sata_disks}")

    suffix = sata_disks.sort.first.split('-')
    disk_name = ('A'..'Z').to_a[suffix[0].to_i]
    "Disk.SATAEmbedded.%s-%s" % [ disk_name, '1' ]
  end

  def reset_xml_base
    @xml_base = nil
  end

  def xml_base
    @xml_base ||= get_xml
  end

  def get_xml(postfix=@exported_postfix)
    exported_file_name = File.basename(@resource[:configxmlfilename], ".xml")+"_#{postfix}.xml"
    @config_xml_path = File.join(@resource[:nfssharepath], @resource[:configxmlfilename])
    f = File.open(File.join(@resource[:nfssharepath], exported_file_name))
    xml_doc = Nokogiri::XML(f.read) do |config|
      config.default_xml.noblanks
    end
    f.close
    xml_doc.xpath('/SystemConfiguration').first
  end

  # Munge config xml
  #
  # This builds out the appropriate xml file for the requested configuration changes
  #
  # @return [Nokogiri::XML::Document] xml_doc
  def munge_config_xml
    get_config_changes
    xml_base.xpath("//Component[contains(@FQDD, 'NIC.') or contains(@FQDD, 'FC.')]").remove unless @changes['whole'].find_all{|k,v| k =~ /^(NIC|FC)\./}.empty?
    xml_base['ServiceTag'] = @resource[:servicetag]

    handle_missing_devices(xml_base, @changes)
    @nonraid_to_raid = false

    if embedded_sata_change
      Puppet.debug("Embedded Mode Change detected running with RAID teardown only")
      @changes.deep_merge!(get_raid_config_changes(xml_base, raid_reset=true))
    else
      @changes.deep_merge!(get_raid_config_changes(xml_base)) if attempt == 0
    end

    %w(BiosBootSeq HddSeq).each do |attr|
      existing_attr_val = find_current_boot_attribute(attr.downcase.to_sym)
      requested_val = @changes['partial']['BIOS.Setup.1-1'][attr]
      message = "Attribute: %s, Existing value: %s, Requested value: %s" % [attr, existing_attr_val, requested_val]
      Puppet.debug(message)
      if existing_attr_val && requested_val
        seq_diff = requested_val.delete(' ').split(',').zip(existing_attr_val.delete(' ').split(',')).select{|new_val, exist_val| new_val != exist_val}
        #If tearing down, the HDD will already be removed from the boot sequence
        if seq_diff.size ==0 || @resource[:ensure] == :teardown
          @changes['partial']['BIOS.Setup.1-1'].delete(attr)
        end
      end
    end

    # If we are tearing down and there are nonraid volumes, we need to make them raid volumes to
    # be able to boot from this controller again
    nonraid_disks = raid_configuration.select{|_,v| !v[:nonraid].empty?}
    if (@resource[:ensure] == :teardown && !nonraid_disks.empty?)
      # Move the nonraids to raid
      nonraid_map = {}
      raid_configuration.each{|k,v| nonraid_map[k] = v[:nonraid] if v[:nonraid]}
      nonraid_map.each do |controller, disks|
        @raid_configuration[controller][:virtual_disks] = [{:disks => disks, :level => "raid0", :type => :hdd}]
        @raid_configuration[controller][:nonraid] = []
      end
      # run #get_raid_config_changes again with overwritten raid_configuration
      @nonraid_to_raid = true
      @changes.deep_merge!(get_raid_config_changes(xml_base))
    end
    #Handle whole nodes (node should be replaced if exists, or should be created if not)
    @changes["whole"].keys.each do |name|
      path = "/SystemConfiguration/Component[@FQDD='#{name}']"
      existing = xml_base.xpath(path).first
      #if node exists there, just go ahead and remove it
      if !existing.nil?
        existing.remove
      end
      create_full_node(name, @changes["whole"][name], xml_base, xml_base.xpath("/SystemConfiguration").first)
    end
    #Handle partial node changes (node should exist already, but needs data edited/added within)
    @changes['partial'].keys.each do |parent|
      process_partials(parent, @changes['partial'][parent], xml_base)
    end
    #Handle node removal (ensure nodes listed here don't exist)
    @changes["remove"]["attributes"].keys.each do |parent|
      process_remove_nodes(parent, @changes["remove"]["attributes"][parent], xml_base, "Attribute")
    end
    @changes["remove"]["components"].keys.each do |parent|
      process_remove_nodes(parent, @changes["remove"]["components"][parent], xml_base, "Component")
    end

    ##Clean up the config file of all the commented text
    xml_base.xpath('//comment()').remove
    remove_invalid_settings(xml_base)
    # Disable SD card and RAID controller for boot from SAN

    # Include NVDIMM setting that will only be included after NVDIMM enabled
    unless nvdimm_attrs_in_sync?
      @changes["partial"]["BIOS.Setup.1-1"]["PersistentMemoryScrubbing"] = "Auto"
    end

    # Rotate the old xml files
    unless attempt == 0
      rotate_config_xml_file
    end
    File.open(@config_xml_path, 'w+') do |file|
      if embsata_in_sync?
        file.write(xml_base.to_xml(:indent => 2))
      else
        # If Embedded Sata mode is out of sync we need to change the FQDD's to what they will be
        # after the EmbSat mode is changed to RAIDmode
        file.write(xml_base.to_xml(:indent => 2).gsub("AHCI.Embedded", "RAID.Embedded").gsub("ATA.Embedded","RAID.Embedded"))
      end
    end
    xml_base
  end

  # Rotate the current config xml file for debugging
  #
  # First import attempt: {file}_1.xml, Second attempt: {file}_2.xml etc..
  #
  # @return void
  def rotate_config_xml_file
    return unless File.exists?(@config_xml_path)
    new_file_name = File.basename(@resource[:configxmlfilename], ".xml")+"_%s.xml" % attempt
    new_file_path = File.join(@resource[:nfssharepath], new_file_name)
    Puppet.info("Moving current XML config file from: %s to %s" % [@config_xml_path, new_file_path])
    File.rename(@config_xml_path, new_file_path)
  end

  def remove_invalid_settings(xml_to_edit)
    # Compare the changes to BIOS.Setup.1-1 with the bios settings that exist on the target server.
    # We do not attempt to set if we cannot find the bios setting in the server's BIOS enumeration
    bios_settings = xml_to_edit.xpath("//Component[@FQDD='BIOS.Setup.1-1']/Attribute")
    bios_settings.each do |attr_node|
      name = attr_node.attr("Name")
      # BiosBootSeq doesn't show up in the BIOSEnumeration call, so make sure we don't strip them out accidentally
      unless %w(BiosBootSeq HddSeq).include?(name)
        attr_value = find_target_bios_setting(name)
        if attr_value.nil?
          Puppet.info("Trying to set bios setting #{name}, but it does not exist on target server.  The attribute will not be set.")
          attr_node.remove
        end
      end
    end
  end

  def original_xml
    @original_xml ||=
      begin
        original_xml_name  = File.basename(@resource[:configxmlfilename], ".xml")+"_original.xml"
        xml_path = File.join(@resource[:nfssharepath], original_xml_name)
        original_xml_file = File.open(xml_path)
        original_xml = Nokogiri::XML(original_xml_file.read) do |config|
          config.default_xml.noblanks
        end
        original_xml_file.close
        original_xml
      end
  end

  #Helper function which will let us ignore device values that don't exist if we can (ex: Ignoring that the server doesn't have an SD card if we're setting SD to off anyway)
  def handle_missing_devices(xml_base, changes)
    ['InternalSdCard', 'IntegratedRaid'].each do |dev_attr|
      #Check if Attribute name exists in the xml, and if it doesn't, check if we're trying to set to disabled.  If so, delete from the list of changes.
      if xml_base.at_xpath("//Attribute[@Name='#{dev_attr}']").nil?
        value = changes['partial']['BIOS.Setup.1-1'][dev_attr]
        if ['Off', 'Disabled'].include?(value)
          Puppet.debug("Trying to set #{dev_attr} to #{value}, but the relevant device does not exist on the server. The attribute will be ignored.")
          changes['partial']['BIOS.Setup.1-1'].delete(dev_attr)
        end
      end
    end
  end

  #Helper function which just searches through the xml comments for HddSeq value, since it will be commented out
  def find_bios_attribute(xml_base, attr_name)
    uncommented = xml_base.at_xpath("//Attribute[@Name='#{attr_name}']")
    unless uncommented.nil?
      return uncommented.content
    else
      xml_base.xpath("//Component[@FQDD='BIOS.Setup.1-1']/comment()").each do |comment|
        if comment.content.include?(attr_name)
          node = Nokogiri::XML(comment.content)
          if node.at_xpath("/Attribute")['Name'] == attr_name
            return node.at_xpath("/Attribute").content
          end
        end
      end
    end
    nil
  end

  def munge_bfs_bootdevice(changes)
    Puppet.debug("configuring the bfs boot device")
    changes['partial'].deep_merge!({'BIOS.Setup.1-1' => { 'InternalSdCard' => "Off",  'IntegratedRaid' => 'Disabled'} })
  end

  def munge_network_configuration(network_configuration, changes, target_boot)
    require 'asm/network_configuration'
    nc = ASM::NetworkConfiguration.new(network_configuration)
    endpoint = Hashie::Mash.new({:host => @ip, :user => @username, :password => @password})
    nc.add_nics!(endpoint, :add_partitions => true)
    munge_iscsi_partitions(nc, changes) if target_boot == 'iSCSI'
    changes['partial'].deep_merge!({'BIOS.Setup.1-1' => { 'BiosBootSeq' => 'HardDisk.List.1-1' } }) if target_boot == 'FC'
    if @resource[:ensure] == :teardown
      Puppet.debug("Resetting virtual mac addresses to permanent mac addresses.")
      nc.reset_virt_mac_addr(endpoint)
    end
    munge_virt_mac_addr(nc, changes)
    changes
  end

  def munge_iscsi_partitions(nc, changes)
    iscsi_partitions = nc.get_partitions('STORAGE_ISCSI_SAN')
    bios_boot_sequence = []
    iscsi_partitions.each do |partition|
        iscsi_network = get_iscsi_network(partition['networkObjects'])
        if ASM::Util.to_boolean(iscsi_network.static)
          changes['whole'].deep_merge!(
          { partition.fqdd =>
            {
                  'TcpIpViaDHCP' => 'Disabled',
                  'IscsiViaDHCP' => 'Disabled',
                  'ChapAuthEnable' => 'Disabled',
                  'IscsiTgtBoot' => 'Enabled',
                  'IscsiInitiatorIpAddr' => iscsi_network['staticNetworkConfiguration']['ipAddress'],
                  'IscsiInitiatorSubnet' => iscsi_network['staticNetworkConfiguration']['subnet'],
                  'IscsiInitiatorGateway' => iscsi_network['staticNetworkConfiguration']['gateway'],
                  'IscsiInitiatorName' => partition['iscsiIQN'],
                  'ConnectFirstTgt' => 'Enabled',
                  'FirstTgtIpAddress' => @resource[:ensure] == :teardown ? '0.0.0.0' : @resource[:target_ip],
                  'FirstTgtTcpPort' => '3260',
                  'FirstTgtIscsiName' => @resource[:ensure] == :teardown ? '' : @resource[:target_iscsi],
                  'LegacyBootProto' => 'iSCSI'
            }.delete_if{|k,v| v.nil?}
          })
          bios_boot_sequence.push(partition.fqdd)
        else
          Puppet.warning("Found non-static iSCSI network while configuring boot from SAN")
        end
    end
    changes['partial'].deep_merge!({'BIOS.Setup.1-1' => { 'BiosBootSeq' => bios_boot_sequence.join(',') } })
  end

  def munge_virt_mac_addr(nc, changes)
    partitions = nc.get_all_partitions
    partitions.each do |partition|
      virtMacAddr = ''
      virtIscsiMacAddr = ''
      macs = {}
      if @resource[:ensure] == :teardown
        virtMacAddr = '00:00:00:00:00:00'
        virtIscsiMacAddr = '00:00:00:00:00:00'
      else
        virtMacAddr = partition['lanMacAddress'] unless partition['lanMacAddress'].nil?
        virtIscsiMacAddr = partition['iscsiMacAddress'] unless partition['iscsiMacAddress'].nil?
      end
      macs['VirtMacAddr'] = virtMacAddr unless virtMacAddr.empty?
      macs['VirtIscsiMacAddr'] = virtIscsiMacAddr unless virtIscsiMacAddr.empty?
      changes['partial'].deep_merge!({partition.fqdd => macs}) unless macs.empty?
    end
  end

  def raid_configuration
    # For scenario where non-raid disks already exists on the server but current configruation haven't requested it
    # Need to convert all non-raid disks to raid disks
    # Specifically required for Windows deployment where OS installation is failing due to pre-existing non-raid disks
    if !non_raid_disks.empty? && non_raid_not_requested? && !(@boot_device =~ /vsan/i) && !(@boot_device =~ /LOCAL_FLASH_STORAGE/i)
      @nonraid_to_raid = true
      @resource[:raid_configuration]["virtualDisks"] << non_raid_disks
    end

    # Check that any non-raid virtual disks are being requested on a controller that supports configuration.
    # Currently only the HBA330 Mini does not support configuration and should already be in non-raid
    # mode.
    unless @resource[:raid_configuration].nil? || @resource[:raid_configuration]["virtualDisks"].nil?
      @resource[:raid_configuration]["virtualDisks"].delete_if do |vd|
        vd["raidLevel"] == "nonraid" && !controller_supports_non_raid?(vd["controller"])
      end
    end

    @raid_configuration ||=
        begin
          unprocessed = @resource[:raid_configuration] || {}
          %w(virtualDisks externalVirtualDisks externalSsdHotSpares externalHddHotSpares ssdHotSpares hddHotSpares).each do |key|
            unprocessed[key] ||= []
          end
          #For Local Flash boot device with BOSS we need to add RAID 1
          #configuration to our existing RAID configuration
          if boss_controller && @boot_device =~ /LOCAL_FLASH_STORAGE/i
            # If there is an existing RAID configuration, we just want to add boss virtual disk
            unprocessed["virtualDisks"].push(boss_virtual_disk)
          end
          raid_configuration = Hash.new { |h, k| h[k] = {:virtual_disks => [], :hotspares => [], :nonraid => []} }
          disk_types = {}
          disks_enum = Puppet::Idrac::Util.view_disks(:physical)

          disks_enum.xpath('//Envelope/Body/PullResponse/Items/DCIM_PhysicalDiskView').each do |x|
            fqdd = x.xpath('FQDD').text
            type = x.at_xpath('MediaType').text == '0' ? :hdd : :ssd
            disk_types[fqdd] = type
          end

          if (unprocessed.empty?) && @boot_device.match(/VSAN/i)
            disk_types.keys.each do |disk|
              controller = disk.split(':').last
              raid_configuration[controller][:hotspares] << disk
            end
            Puppet.debug("Inside VSAN RAID Configuration: #{raid_configuration}")
          elsif unprocessed.empty?
            Puppet.debug("No RAID Configuration required")
          elsif !(unprocessed['virtualDisks'].empty? && unprocessed['externalVirtualDisks'].empty?)
            (unprocessed['virtualDisks'] + unprocessed['externalVirtualDisks']).each do |config|
              #Just check first disk in the list to get what type of virtual disk it is
              type = disk_types[config["physicalDisks"].first]
              if config["raidLevel"] == "nonraid"
                raid_configuration[config["controller"]][:nonraid].concat(config["physicalDisks"])
              else
                raid_configuration[config["controller"]][:virtual_disks] << {:disks => config["physicalDisks"], :level => config["raidLevel"], :type => type}
              end
            end

            hotspares = []

            [:internal, :external].each do |raid_type|
              [:ssd, :hdd].each do |disk_type|
                key = raid_type == :internal ? "#{disk_type}HotSpares" : "external#{disk_type.capitalize}HotSpares"
                if disk_types.collect{|x| x[1] if x[1] == disk_type}.compact.empty? && !unprocessed[key].empty?
                  Puppet.warning("Trying to assign #{disk_type.upcase} hotspares, but no #{disk_type.upcase} virtual disks are being created.  Ignoring #{disk_type}HotSpares...")
                else
                  hotspares += unprocessed[key]
                end
              end

              hotspares.each do |disk|
                controller = disk.split(':').last
                raid_configuration[controller][:hotspares] << disk
              end
            end
          end
          raid_configuration
        end
  end

  def get_raid_config_changes(target_current_xml, raid_reset=false)
    changes = {'partial'=>{}, 'whole'=>{}, 'remove'=> {'attributes'=>{}, 'components'=>{}}}
    if (@resource[:ensure] == :teardown && !boss_controller.nil? && @boot_device =~ /LOCAL_FLASH_STORAGE/i)
      changes['whole'][boss_controller] = { 'RAIDresetConfig' => "True" }
    end
    if (@resource[:ensure] == :teardown && !@resource[:raid_configuration].nil? && !@nonraid_to_raid) || raid_reset
      Puppet.debug("Setting RAID configuration to be cleared as part of %s" % (raid_reset ? "raid reset" : "teardown"))
      raid_configuration.keys.each{|controller| changes['whole'][controller] = { 'RAIDresetConfig' => "True" } }
    else
      if @boot_device =~ /VSAN/i && !fc630_with_vsan_on_hdd?
        if target_current_xml.to_s.match(/="CurrentControllerMode">RAID/)
          raids = (raid_configuration.keys || []).reject {|x| x.match(/Embedded/)}
          unless raids.empty?
            changes['whole'][raids.first] = { 'CurrentControllerMode' => "HBA" }
          end
        end
      elsif @boot_device =~ /WITH_RAID|HD/i || fc630_with_vsan_on_hdd? || @boot_device =~ /LOCAL_FLASH_STORAGE/i
        if fc630_with_vsan_on_hdd?
          raids = (raid_configuration.keys || []).reject {|x| x.match(/Embedded/)}
          unless raids.empty?
            changes['whole'][raids.first] = { 'CurrentControllerMode' => "RAID" }
          end
        end
        changes['partial'] = {'BIOS.Setup.1-1'=> {'HddSeq' => raid_configuration.keys.first}} if @boot_device =~ /HD/i && @boot_mode == 'BIOS_MODE'
        unless raid_in_sync?(target_current_xml, true)
          #Getting the first key should get the first internal disk controller, or the first external if no internal on the server
          vd_index = 0
          raid_configuration.keys.each do |raid_fqdd|
            changes['whole'][raid_fqdd] = { "RAIDresetConfig" => "True", "RAIDforeignConfig" => "Clear"}

            # CurrentControllerMode is not a valid attribute on IDRAC 7
            if find_attribute_value(target_current_xml, raid_fqdd, "CurrentControllerMode", true)
              changes["whole"][raid_fqdd]["CurrentControllerMode"] = "RAID"
            end

            raid_configuration[raid_fqdd][:virtual_disks].each_with_index do |disk_config, index|
              case disk_config[:level]
                when 'raid10'
                  span_depth = disk_config[:disks].size / 2
                  span_length = '2'
                when 'raid50'
                  span_depth = disk_config[:disks].size / 3
                  span_length = '3'
                when 'raid60'
                  span_depth = disk_config[:disks].size / 4
                  span_length = '4'
                else
                  span_depth = '1'
                  span_length = disk_config[:disks].size
              end
              raid_settings = {
                "RAIDaction"        => "Create",
                "Name"              => "VD #{vd_index}",
                "Size"              => "0",
                "StripeSize"        => "128",
                "SpanDepth"         => span_depth,
                "SpanLength"        => span_length,
                "RAIDTypes"         => disk_config[:level].sub("raid", "RAID "),
                "IncludedPhysicalDiskID"=> disk_config[:disks]
              }
              vd_index += 1
              # This settings is not supported on RAID_Mode.  It defaults to Fast
              raid_settings["RAIDinitOperation"] = "Fast" unless is_embedded_raid?

              changes['whole'][raid_fqdd]["Disk.Virtual.#{index}:#{raid_fqdd}"] = raid_settings
              # If it is BOSS, we don't want to get the disks, but if it is a regular RAID config
              # we'll want to allow the disks to get configured.
              unless @boot_device =~ /LOCAL_FLASH_STORAGE/i && raid_fqdd =~ /AHCI/i
                set_disk_changes!(disk_config[:disks], :raid, changes["whole"][raid_fqdd])
              end
            end
            set_disk_changes!(raid_configuration[raid_fqdd][:hotspares], :hotspare, changes["whole"][raid_fqdd])
            set_disk_changes!(raid_configuration[raid_fqdd][:nonraid], :nonraid, changes["whole"][raid_fqdd])
          end
        end
      else
        raid_fqdds = target_current_xml.xpath("/SystemConfiguration/Component[contains(@FQDD, 'RAID.')]").collect{|node| node.attr('FQDD')}
        raid_fqdds.each{|raid_fqdd| changes['remove']['components'][raid_fqdd] = {} }
      end
    end

    changes
  end

  def set_disk_changes!(disks, type, controller_changes)
    disks.each do |disk_fqdd|
      disk_attributes = {}
      _bay, enclosure_fqdd = disk_fqdd.split(':', 2)

      disk_attributes["RAIDPDState"] = type == :nonraid ? "Non-RAID" : "Ready"
      disk_attributes["RAIDHotSpareStatus"] = "Global" if type == :hotspare

      if @non_raid_info
        disk_attributes["RAIDPDState"] = "Ready"
      end

      if is_embedded_raid?
        # Embedded s130 do not have an enclosure
        controller_changes[disk_fqdd] = disk_attributes
      else
        controller_changes[enclosure_fqdd] ||= {}
        controller_changes[enclosure_fqdd].merge!({disk_fqdd => disk_attributes})
      end
    end
  end

  def raid_in_sync?(xml_base, log=false)
    if @boot_device =~ /WITH_RAID|HD/i && !(@boot_device =~ /SD_WITH_RAID_VSAN|AHCI_VSAN/i) || fc630_with_vsan_on_hdd? || @boot_device =~ /LOCAL_FLASH_STORAGE/i
      raid_configuration.keys.each do |raid_fqdd|
        raid_fqdd_xpath = "//Component[@FQDD='#{raid_fqdd}']"
        controller_xml = xml_base.xpath(raid_fqdd_xpath)
        existing_virtual_disks = controller_xml.xpath("Component[starts-with(@FQDD, 'Disk.Virtual')]")

        raid_configuration[raid_fqdd][:nonraid].each do |nonraid_disk|
          _, enclosure_fqdd = nonraid_disk.split(":", 2)
          enclosure_xml = controller_xml.xpath("Component[@FQDD='%s']" % enclosure_fqdd)

          unless find_attribute_value(enclosure_xml, nonraid_disk, "RAIDPDState", true) == "Non-RAID"
            Puppet.debug("RAID config needs to be updated. %s is in RAID mode." % nonraid_disk)
            return false
          end

          if @non_raid_info && (@non_raid_info["physicalDisks"] || []).include?(nonraid_disk)
            Puppet.debug("Disks %s is configured as Non-Raid. Need to be converted to RAID" % [nonraid_disk])
            return false
          end
        end

        if existing_virtual_disks.empty? || existing_virtual_disks.size != raid_configuration[raid_fqdd][:virtual_disks].size
          Puppet.debug("RAID config needs to be updated. Existing virtual disks don't match up to requested configuration for #{raid_fqdd}") if log
          return false
        end

        existing_virtual_disks.each do |disk|
          disk_name, controller = disk.attr('FQDD').split(':')
          disk_num = disk_name.split('.').last.to_i
          requested_config = raid_configuration[controller][:virtual_disks][disk_num]
          if requested_config == nil
            Puppet.debug("RAID config needs to be updated. Extra disk(s) found on the server's current RAID configuration.") if log
            return false
          end
          raid_level = disk.at_xpath('Attribute[@Name="RAIDTypes"]')
          #Sometimes, the RAIDTypes will be commented out.  Need to check for that.
          if raid_level.nil?
            raid_level = disk.xpath('comment()').map{|c| Nokogiri::XML(c.content).at_xpath("/Attribute").content if c.content.include?("RAIDTypes")}.compact.first
          else
            raid_level = raid_level.content
          end
          raid_level.delete!(' ').downcase!
          if raid_level != requested_config[:level]
            Puppet.debug("RAID config needs to be updated.  Needed #{disk_name}'s raid level to be #{requested_config[:level]}, but got #{raid_level}") if log
            return false
          end
          requested_disks = requested_config[:disks]
          #the existing physical disks are contained inside the comments of the virtual disk
          existing_phys_disks = disk.xpath('comment()').collect{|c| Nokogiri::XML(c.content).at_xpath("/Attribute").content if c.content.include?("IncludedPhysicalDiskID")}.compact
          if existing_phys_disks.sort != requested_disks.sort
            Puppet.debug("RAID config needs to be updated.  Needed IncludedPhysicalDiskIDs to be #{requested_disks.sort} for #{disk_name}, but got #{existing_phys_disks.sort}") if log
            return false
          end
        end
      end

      #Won't reach this point if the raid is out of sync, as we'll have returned false above.
      if @resource[:ensure] == :teardown
        Puppet.debug("RAID config needs to be cleared for teardown.") if log
        return false
      end

    end

    Puppet.info("RAID configuration does not need to be updated.")
    true
  end

  def nvdimm_attrs_in_sync?
    mem_view = wsman.memory_views
    nvdimms = mem_view.select {|mem| mem[:rank] == "1" }
    nvdimms.empty? ? true: false
  end

  def get_iscsi_network(network_objects)
    network_objects.detect do |network|
      network['type'] == 'STORAGE_ISCSI_SAN'
    end
  end

  def process_remove_nodes(node_name, data, xml_base, type, path="/SystemConfiguration")
    name_attr = type == "Component" ? "FQDD" : "Name"
    #If data is a list, it is a list of items under the node to delete
    if !data.nil? && data.size != 0
      new_path = "#{path}/Component[@FQDD='#{node_name}']"
      data.each do |name, child_data|
        process_remove_nodes(name, child_data, xml_base, type, new_path)
      end
    else
      node_path = "#{path}/#{type}[@#{name_attr}='#{node_name}']"
      existing = xml_base.xpath(node_path).first
      if !existing.nil?
        existing.remove
      end
    end
  end

  def create_full_node(node_name, content, xml_base, parent)
    # IF content data is a hash, then it is a component node, otherwise it is just an attribute node
    if content.is_a?(Hash)
      new_component = Nokogiri::XML::Node.new "Component", xml_base
      new_component.parent = parent
      new_component["FQDD"] = node_name
      content.keys.each do |child_name|
        create_full_node(child_name, content[child_name], xml_base, new_component)
      end
    else
      if content.is_a?(Array)
        content.each_with_index do |value|
          new_node = Nokogiri::XML::Node.new "Attribute", xml_base
          new_node.parent = parent
          new_node.content = value
          new_node["Name"] = node_name
        end
      else
        new_node = Nokogiri::XML::Node.new "Attribute", xml_base
        new_node.parent = parent
        new_node.content = content
        new_node["Name"] = node_name
      end
    end
  end

  #Used to process partial changes to xml
  def process_partials(node_name, data, xml_base, path="/SystemConfiguration")
    #If the data is a hash, it is a component, recurse through to process
    if data.is_a?(Hash)
      new_path = "#{path}/Component[@FQDD='#{node_name}']"
      existing = xml_base.xpath(new_path).first
      if existing.nil?
        new_node = Nokogiri::XML::Node.new "Component", xml_base
        new_node.parent = xml_base.xpath(path).first
        new_node["FQDD"] = node_name
      end
      data.keys.each do |child|
        process_partials(child, data[child], xml_base, new_path)
      end
    #If the data is an Array, it is a list of attributes with the same Name but different values
    elsif data.is_a?(Array)
      data.each_with_index do |content, index|
        existing = xml_base.xpath("#{path}[#{index+1}]").first.content = content
        if existing
          existing.content = data[index]
        else
          new_node = Nokogiri::XML::Node.new "Attribute", xml_base
          new_node.parent = xml_base.xpath(path).first
          new_node["Name"] = node_name
          new_node.content = content
        end
      end
    #Otherwise, it should just be the value of the attribute to set
    else
      attr_path = "#{path}/Attribute[@Name='#{node_name}']"
      existing = xml_base.xpath(attr_path).first
      if existing
        existing.content = data
      else
        new_node = Nokogiri::XML::Node.new "Attribute", xml_base
        new_node.parent = xml_base.xpath(path).first
        new_node["Name"] = node_name
        new_node.content = data
      end
    end
  end

  def process_nics
    require 'asm/network_configuration'
    net_config = ASM::NetworkConfiguration.new(resource[:network_config])
    endpoint = Hashie::Mash.new({:host => @ip, :user => @username, :password => @password})
    net_config.add_nics!(endpoint, :add_partitions => true)
    fqdds_existing = xml_base.xpath("//Component[contains(@FQDD, 'NIC.') or contains(@FQDD, 'FC.')]").collect {|x| x.attribute("FQDD").value}
    fqdds_to_set = net_config.get_all_fqdds
    config = {'partial'=>{}, 'whole'=>{}, 'remove'=> {'attributes'=>{}, 'components'=>{}}}
    #fqdds_existing - fqdds_to_set will leave us a list of NICs that need to be removed from the config.xml
    #If going from npar to unpartitioned, leftover component blocks for partitions 2-4 will cause errors.
    #TODO:  This can probably be phased out with the setup_idrac workflow, which should give a base xml to work with that has the correct number of partitions.
    (fqdds_existing - fqdds_to_set).each do |fqdd|
        config['remove']['components'][fqdd] = {}
    end
    #Don't mess with the boot order if the target_boot_device = none
    unless @boot_device =~ /^NONE/i
      if @boot_mode == 'BIOS_MODE'
        config['partial']['BIOS.Setup.1-1'] = {'BiosBootSeq'=> "HardDisk.List.1-1"}
      end
    end
    net_config.cards.each do |card|
      card.interfaces.each do |interface|
        partitioned = interface['partitioned']
        interface.partitions.each do |partition|
          fqdd = partition.fqdd
          #
          # SET UP NIC IN CASE INTERFACE IS BEING PARTITIONED, equivalent to the enable_npar parameter
          #
          if @boot_device !~ /^NONE/i || !partition.networkObjects.nil?
            changes = config['whole'][fqdd] = {}
            partition_no = partition.partition_no
            #Intel cards don't have VLanMode, so we check if it exists before trying to set.
            if partition_no == 1 && xml_base.at_xpath("//Component[@FQDD='#{fqdd}']/Attribute[@Name='VLanMode']")
              changes['VLanMode'] = 'Disabled'
            end
            if partitioned
              #
              # CONFIGURE ISCSI NETWORK
              #
              changes['NicMode'] = 'Enabled'
              if @boot_device != 'iSCSI' && @boot_device != 'FC'
                if partition['networkObjects'] && !partition['networkObjects'].find { |obj| obj['type'].include?('ISCSI') }.nil?
                  changes['iScsiOffloadMode'] = 'Enabled'
                  #FCoEOffloadMode MUST be disabled if iScsiOffloadMode is Enabled
                  changes['FCoEOffloadMode'] = 'Disabled'
                elsif partition['networkObjects'] && !partition['networkObjects'].find { |obj| obj['type'].include?('FCOE') }.nil?
                  changes['iScsiOffloadMode'] = 'Disabled'
                  #FCoEOffloadMode MUST be disabled if iScsiOffloadMode is Enabled
                  changes['FCoEOffloadMode'] = 'Enabled'
                  changes['NicMode'] = 'Disabled'
                else
                  changes['iScsiOffloadMode'] = 'Disabled'
                  #Curently always setting FCoEOffloadMode to Disabled, but any logic to set it otherwise should probably go here in the future
                  changes['FCoEOffloadMode'] = 'Disabled'
                end
              end

              # Reset virtual mac addresses by default
              if changes['NicMode'] == 'Enabled'
                changes['VirtMacAddr'] = '00:00:00:00:00:00'
              end
              if changes['iScsiOffloadMode'] == 'Enabled'
                changes['VirtIscsiMacAddr'] = '00:00:00:00:00:00'
              end

              changes['MinBandwidth'] = partition.minimum
              changes['MaxBandwidth'] = partition.maximum
              if partition_no == 1
                changes['VirtualizationMode'] = 'NPAR'
                changes['NicPartitioning'] = 'Enabled'
              end
            else
              if partition_no == 1
               handle_missing_attributes(changes,fqdd)
              else
                #This is just to clean up the changes hash, but should be unnecessary
                config['partial'].remove(fqdd)
              end
            end
            #
            # CONFIGURE LEGACYBOOTPROTO IN CASE NIC IS FOR PXE
            #
            if @boot_mode =='BIOS_MODE' && partition['networkObjects'] && !partition['networkObjects'].find { |obj| obj['type'] =='PXE' }.nil?
              changes['LegacyBootProto'] = 'PXE'
            else
              changes['LegacyBootProto'] = 'NONE'
            end
          end
        end
      end
    end
    config
  end

   #Helper function to remove two attributes from nic configuration. Should be for Intel cards only.
  def handle_missing_attributes(changes, fqdd)
    changes['VirtualizationMode'] = 'NONE'
    changes['NicPartitioning'] = 'Disabled'
    ['VirtualizationMode','NicPartitioning'].each do |dev_attr|
      #Check if Attribute name exists in the xml, and if it doesn't, check if we're trying to set to disabled.  If so, delete from the list of changes.
      if xml_base.at_xpath("//Component[@FQDD='#{fqdd}']/Attribute[@Name='#{dev_attr}']").nil?
        Puppet.debug("Trying to set #{dev_attr}  but the relevant device does not exist on the server. The attribute will be ignored.")
         changes.delete(dev_attr)
      end
    end
  end

  #TODO: Use this function whereever we're doing a search for certain attributes, such as in handle_missing_attributes
  def find_attribute_value(xml, component, attribute, search_comments=false)
    attr_node = xml.at_xpath("//Component[@FQDD='#{component}']//Attribute[@Name='#{attribute}']")
    if attr_node.nil? && search_comments
      xml.xpath("//Component[@FQDD='#{component}']/comment()").each do |comment|
        if comment.content.include?(attribute)
          node = Nokogiri::XML(comment.content)
          if node.at_xpath("/Attribute")['Name'] == attribute
            attr_node = node.at_xpath("/Attribute")
            break
          end
        end
      end
    end
    attr_node.nil? ? nil : attr_node.content
  end

  # Returns true if this is a deployment to an embedded raid (S130) controller
  #
  # @return Boolean
  def is_embedded_raid?
    return false unless @resource[:raid_configuration]
    virtual_disks = @resource[:raid_configuration].fetch("virtualDisks", [])
    virtual_disks.each do |vd|
      controller = vd.fetch("controller", "")
      return true if controller.match(/Embedded/i)
    end
    false
  end

  # Figure out of the requested RAID controller for nonRAID actually supports nonRAID
  # Currently only HBA330 mini doesn't support nonRAID, and should already be configured
  # as a passthrough device.
  #
  # @return Boolean
  def controller_supports_non_raid?(non_raid_fqdd)
    non_raid_disk_controller = disk_controllers.find { |c| c[:fqdd].include?(non_raid_fqdd) }
    !(non_raid_disk_controller.nil? || non_raid_disk_controller[:product_name] =~ /Dell HBA330/i)
  end

  # Check for Embedded Sata in sync
  #
  # If the current embedded sata mode is not what is required
  # this method returns true
  # @return Boolean
  def embsata_in_sync?
    return true unless is_embedded_raid?
    find_bios_attribute(original_xml, "EmbSata") == "RaidMode"
  end

  def fc630_with_vsan_on_hdd?
    @resource[:model] == "fc630" && @resource[:target_boot_device] == "AHCI_VSAN"
  end

  def disk_controllers
    @disk_controllers ||= Puppet::Idrac::Util.disk_controller
  end

  def controller_disk_fqdd(controller_type)
    device_id = nil
    disk_controllers.each do |x|
      product_name = x[:product_name]
      if controller_type.include?(product_name)
        device_id = x[:fqdd]
      end
    end
    return device_id
  end

  def boss_controller
    disk_controller = disk_controllers.find { |c| c[:product_name].include?("BOSS") }

    return nil unless disk_controller

    disk_controller[:fqdd]
  end

  def fc630_controllers
    ["PERC H330 Mini", "PERC H730 Mini"]
  end

  def fc630_disks
    disks = []
    device_fqdd = controller_disk_fqdd(fc630_controllers)
    raise("Failed to find disks added to controller '%s'" % [fc630_controllers]) unless device_fqdd
    physical_disks.xpath("//Envelope/Body/PullResponse/Items/DCIM_PhysicalDiskView").each do |x|
      fqdd = x.xpath("FQDD").text
      disks << fqdd if fqdd =~ /\S+#{device_fqdd}/i
    end
    raise("Expect 2 disks, got %d" % [disks.size]) if disks.size != 2
    disks
  end

  def boss_disks
    device_fqdd = boss_controller
    raise("Failed to find BOSS controller.") unless device_fqdd
    disks = get_disks_for_controller(device_fqdd)
    raise("Expect 2 disks, got %d" % [disks.size]) if disks.size != 2
    disks
  end

  def get_satadom
    boot_sources = Puppet::Idrac::Util.boot_source_settings
    satadom_instance_id = boot_sources.select {|d| d[:boot_string] =~ /SATADOM/ || d[:boot_string] =~ /Embedded SATA Port Disk [A-Z]/}[0][:instance_id] rescue nil
    unless satadom_instance_id.nil?
      satadom_instance_id.split("#")[2]
    end
  end

  def get_disks_for_controller(controller_fqdd)
    disks = []
    physical_disks.xpath("//Envelope/Body/PullResponse/Items/DCIM_PhysicalDiskView").each do |x|
      fqdd = x.xpath("FQDD").text
      disks << fqdd if fqdd =~ /\S+#{controller_fqdd}/i
    end
    disks
  end
  
  #TODO: Find disks under H330 controller
  def fc630_raid_configuration
    {
      "externalVirtualDisks" => [],
      "externalSsdHotSpares" => [],
      "externalHddHotSpares" => [],
      "ssdHotSpares" => [],
      "virtualDisks" => [
        {
          "physicalDisks" => fc630_disks,
          "raidLevel" => "raid1",
          "controller" => controller_disk_fqdd(fc630_controllers),
          "configuration" => {
            "raidlevel" => "raid1",
            "numberofdisks" => 1,
            "comparator" => "minimum",
            "disktype" => "any"
          },
          "mediaType" => "ANY"
        }
      ],
      "hddHotSpares" =>[]
    }
  end

  def boss_virtual_disk
    {
      "physicalDisks" => boss_disks,
      "raidLevel" => "raid1",
      "controller" => boss_controller,
      "configuration" => {
        "raidlevel" => "raid1",
        "numberofdisks" => 2,
        "comparator" => "exact",
        "disktype" => "any"
      },
      "mediaType" => "ANY"
    }
  end

  def non_raid_not_requested?
    vds = (@resource["raid_configuration"] || {})["virtualDisks"]
    return false unless vds
    !vds.find { |vd| vd["raidLevel"] == "nonraid" }
  end

  def wsman
    require "asm/wsman"
    @wsman ||= begin
      endpoint = {:host => @ip, :user => @username, :password => @password}
      ASM::WsMan.new(endpoint, :logger => Puppet)
    end
  end

  # Finds the current boot atrribute
  #
  # This will make a wsman call to the current server to get the
  # the attribute at this point in time
  #
  # @param [:biosbootseq, :hddseq] attribute attribute we are looking for
  # @return [String] the attribute value
  def find_current_boot_attribute(attribute)
    boot_source_settings = wsman.boot_source_settings
    if attribute == :hddseq
      sorted_hdd = boot_source_settings.select{ |b| b[:boot_source_type] == "BCV" && b[:current_enabled_status] == "1"
      }.sort_by{|b| b[:current_assigned_sequence]}
      return "" if sorted_hdd.empty?
      sorted_hdd.first[:instance_id].split("#")[2]
    else
      sorted_bss = boot_source_settings.select{|b| b[:boot_source_type] == "IPL"}.sort_by{|b| b[:current_assigned_sequence]}
      sorted_bss.map{|x| x[:instance_id].split("#")[2]}.join(", ")
    end

  end

  def non_raid_disks
    return @non_raid_info if @non_raid_info
    disks = []
    controllers = []
    physical_disks.xpath("//Envelope/Body/PullResponse/Items/DCIM_PhysicalDiskView").each do |x|
      raid_status = x.xpath("RaidStatus").text
      fqdd = x.xpath("FQDD").text
      Puppet.debug("FQDD: #{fqdd}, raid_status: #{raid_status}")
      if raid_status.to_i == 8
        disks << fqdd
        controllers << fqdd.scan(/\S+:(\S+)/).flatten.first
      end
    end
    return {} if disks.empty?

    @non_raid_info = {
      "raidLevel" => "nonraid",
      "physicalDisks" => disks,
      "controller" => controllers.first,
      "configuration" => {
        "raidlevel" => "nonraid",
        "comparator" => "minimum",
        "numberofdisks" => "1",
        "disktype" => "any",
      },
      "mediaType" => "ANY"
    }
  end

end
