require 'rexml/document'
require 'json'
require 'nokogiri'
require 'hashie'
require 'active_support'
require 'active_support/core_ext'
require 'puppet/idrac/util'

include REXML

class Puppet::Provider::Importtemplatexml <  Puppet::Provider

  def initialize (ip,username,password,resource, exported_postfix='base')
    @ip = ip
    @username = username
    @password = password
    @configxmlfilename = resource[:configxmlfilename]
    @resource = resource
    @bios_settings = resource[:bios_settings]
    @network_config_data = resource[:network_config]
    @templates_dir = File.join(Puppet::Module.find('idrac').path, 'templates')
    @exported_postfix = exported_postfix
  end

  def importtemplatexml
    munge_config_xml unless @xml_processed
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
    end

  end

  def wait_for_import(instance_id)
    job_status_obj = Puppet::Provider::Checkjdstatus.new(@ip, @username, @password, instance_id)
    Puppet.info "Instance id #{instance_id}"
    for i in 0..30
      response = job_status_obj.checkjdstatus
      Puppet.info "JD status : #{response}"
      if response  == "Completed"
        Puppet.info "Import System Configuration is completed."
        break
      else
        if response  == "Failed"
          raise(Puppet::Idrac::ConfigError, "ImportSystemConfiguration job failed")
        elsif response.downcase == 'sys051'
          raise(Puppet::Idrac::ShutdownError, 'System could not be gracefully shut down')
        else
          Puppet.info "Job is running, wait for 1 minute"
          sleep 60
        end
      end
    end
    if response != "Completed"
      raise "Import System Configuration is still running."
    end
  end

  def find_target_bios_setting(attr_name)
    @bios_enumeration ||=
      begin
        cmd = "wsman enumerate http://schemas.dmtf.org/wbem/wscim/1/cim-schema/2/root/dcim/DCIM_BIOSEnumeration -h #{@ip} -P 443 -u #{@username} -p #{@password} -c dummy.cert -y basic -V -v"
        response = `#{cmd}`
        bios_xml = Nokogiri::XML("<result>#{response}</result>")
        bios_xml.remove_namespaces!
      end
    enum = @bios_enumeration.at_xpath("//DCIM_BIOSEnumeration[AttributeName='#{attr_name}']")
    return nil if enum.nil?
    Hash.from_xml(enum.to_xml)['DCIM_BIOSEnumeration']
  end

  def get_config_changes
    return @changes if @changes
    changes = default_changes
    nic_changes = process_nics
    changes.deep_merge!(nic_changes)
    #if idrac is booting from san, configure networks / virtual identities
    munge_network_configuration(@resource[:network_config], changes, @resource[:target_boot_device]) if @resource[:target_boot_device] == 'iSCSI' || @resource[:target_boot_device] == 'FC'
    if @resource[:ensure] != :teardown && (@resource[:target_boot_device] == 'iSCSI' || @resource[:target_boot_device] == 'FC')
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
    changes = {'partial'=>{'BIOS.Setup.1-1'=>{}}, 'whole'=>{}, 'remove'=> {'attributes'=>{}, 'components'=>{}}}
    changes['whole']['LifecycleController.Embedded.1'] = { 'LCAttributes.1#CollectSystemInventoryOnRestart' => 'Enabled' }
    @bios_settings.keys.each do |key|
      unless @bios_settings[key].nil? || @bios_settings[key].empty?
        if @bios_settings[key] == 'n/a'
          changes['remove']['attributes']['BIOS.Setup.1-1'] ||= []
          changes['remove']['attributes']['BIOS.Setup.1-1'] << key
        else
          changes['partial']['BIOS.Setup.1-1'][key] = @bios_settings[key]
        end
      end
    end
    unless @resource[:target_boot_device].start_with?('none')
      changes['partial']['BIOS.Setup.1-1']['ProcVirtualization'] = 'Enabled'
      changes['partial']['BIOS.Setup.1-1']['BootMode'] = 'Bios'
    end
    # target_boot_device settings
    # Always want to turn on IntegratedRaid with teardown, so ASM can continue to inventory RAID info later.
    if @resource[:ensure] == :teardown
      changes['partial'].deep_merge!('BIOS.Setup.1-1' => {'IntegratedRaid' => 'Enabled'})
    elsif @resource[:target_boot_device] == "HD"
      changes['partial'].deep_merge!(
          {'BIOS.Setup.1-1' =>
               {
                   'IntegratedRaid' => 'Enabled',
                   'InternalSdCard'  => 'Off'
               }
          })
    elsif @resource[:target_boot_device] == "SD"
      changes['partial'].deep_merge!(
          {'BIOS.Setup.1-1' =>
               {
                   'IntegratedRaid' => 'Disabled',
                   'InternalSdCard' => 'On'
               }
          })
    elsif @resource[:target_boot_device].downcase.start_with?('none')
      changes['remove']['attributes']['BIOS.Setup.1-1'] ||= []
      changes['remove']['attributes']['BIOS.Setup.1-1'] << 'BiosBootSeq'
    end
    changes
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

  def munge_config_xml
    get_config_changes
    xml_base.xpath("//Component[contains(@FQDD, 'NIC.') or contains(@FQDD, 'FC.')]").remove unless @changes['whole'].find_all{|k,v| k =~ /^(NIC|FC)\./}.empty?
    xml_base['ServiceTag'] = @resource[:servicetag]
    # Current workaround for LC issue, where if BiotBootSeq is already set to what ASM needs it to be, setting it again to the same thing will cause an error.
    existing_boot_seq = find_bios_boot_seq(xml_base)
    boot_seq_change = @changes['partial']['BIOS.Setup.1-1']['BiosBootSeq']
    if existing_boot_seq && boot_seq_change
      seq_diff = boot_seq_change.delete(' ').split(',').zip(existing_boot_seq.delete(' ').split(',')).select{|new_val, exist_val| new_val != exist_val}
      #If tearing down, the HDD will already be removed from the boot sequence
      if seq_diff.size ==0 || @resource[:ensure] == :teardown
        @changes['partial']['BIOS.Setup.1-1'].delete('BiosBootSeq')
      end
    end
    handle_missing_devices(xml_base, @changes)
    @changes.deep_merge!(get_raid_config_changes(xml_base))
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
    File.open(@config_xml_path, 'w+') { |file| file.write(xml_base.to_xml(:indent => 2)) }
    @xml_processed = true
    xml_base
  end

  def remove_invalid_settings(xml_to_edit)
    # HddSeq seems to cause a lot of issues by letting it stay.
    # We only allow it to stay if we're specifically trying to set it for booting from hard drive
    hdd_seq = find_attribute_value(xml_to_edit, 'BIOS.Setup.1-1', 'HddSeq', false)
    hdd_seq.remove unless hdd_seq.nil? || @changes['partial']['BIOS.Setup.1-1']['HddSeq']
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

  #Helper function which just searches through the xml comments for BiosBootSeq value, since it will be commented out
  def find_bios_boot_seq(xml_base)
    uncommented = xml_base.at_xpath("//Attribute[@Name='BiosBootSeq']")
    unless uncommented.nil?
      return uncommented.content
    else
      xml_base.xpath("//Component[@FQDD='BIOS.Setup.1-1']/comment()").each do |comment|
        if comment.content.include?("BiosBootSeq")
          node = Nokogiri::XML(comment.content)
          #Other names are possible for the node that contain "BiosBootSeq", such as "OneTimeBiosBootSeq", so must ensure it is exactly "BiosBootSeq"
          if node.at_xpath("/Attribute")['Name'] == "BiosBootSeq"
            return node.at_xpath("/Attribute").content
          end
        end
      end
    end
    nil
  end

  def munge_bfs_bootdevice(changes)
    Puppet.debug("configuring the bfs boot device")
    changes['partial'].deep_merge!({'BIOS.Setup.1-1' => { 'InternalSDCard' => "Off",  'IntegratedRaid' => 'Disabled'} })
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
    @raid_configuration ||=
        begin
          unprocessed = @resource[:raid_configuration]
          disks_enum = Puppet::Idrac::Util.view_disks(:physical)
          disk_types = {}
          disks_enum.xpath('//Envelope/Body/PullResponse/Items/DCIM_PhysicalDiskView').each do |x|
            fqdd = x.xpath('FQDD').text
            type = x.at_xpath('MediaType').text == '0' ? :hdd : :ssd
            disk_types[fqdd] = type
          end
          raid_configuration = Hash.new { |h, k| h[k] = {:virtual_disks => [], :hotspares => []} }
          unless unprocessed['virtualDisks'].empty? && unprocessed['externalVirtualDisks'].empty?
            (unprocessed['virtualDisks'] + unprocessed['externalVirtualDisks']).each do |config|
              type = disk_types[config['physicalDisks'].first]
              #Just check first disk in the list to get what type of virtual disk it is
              raid_configuration[config['controller']][:virtual_disks] << {:disks => config['physicalDisks'], :level => config['raidLevel'], :type => type}
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

  def get_raid_config_changes(target_current_xml)
    changes = {'partial'=>{}, 'whole'=>{}, 'remove'=> {'attributes'=>{}, 'components'=>{}}}
    if @resource[:ensure] == :teardown && !@resource[:raid_configuration].nil?
      Puppet.debug("Setting RAID configuration to be cleared as part of teardown.")
      raid_configuration.keys.each{|controller| changes['whole'][controller] = { 'RAIDresetConfig' => "True" } }
    else
      if ['none_with_raid', 'hd'].include?(@resource[:target_boot_device].downcase)
        changes['partial'] = {'BIOS.Setup.1-1'=> {'HddSeq' => raid_configuration.keys.first}}
        unless raid_in_sync?(target_current_xml, true)
          #Getting the first key should get the first internal disk controller, or the first external if no internal on the server
          raid_configuration.keys.each do |raid_fqdd|
            changes['whole'][raid_fqdd] = { 'RAIDresetConfig' => "True", 'RAIDforeignConfig' => 'Clear'}
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
              changes['whole'][raid_fqdd]["Disk.Virtual.#{index}:#{raid_fqdd}"] =
                {
                  'RAIDaction'=>'Create',
                  'RAIDinitOperation'=>'Fast',
                  'Name'=>"ASM VD#{index}",
                  'Size'=>'0',
                  'StripeSize'=>'128',
                  'SpanDepth'=>span_depth,
                  'SpanLength'=>span_length,
                  'RAIDTypes'=> disk_config[:level].sub('raid', 'RAID '),
                  'IncludedPhysicalDiskID'=> disk_config[:disks]
                }
              disk_config[:disks].each do |disk_fqdd|
                controller_changes = changes['whole'][raid_fqdd]
                bay, *enclosure_fqdd = disk_fqdd.split(':')
                enclosure_fqdd = enclosure_fqdd.join(':')
                controller_changes[enclosure_fqdd] = {} if controller_changes[enclosure_fqdd].nil?
                controller_changes[enclosure_fqdd].merge!({disk_fqdd=>{'RAIDPDState' => 'Ready'}})
              end
            end
            raid_configuration[raid_fqdd][:hotspares].each do |disk_fqdd|
              bay, *enclosure_fqdd = disk_fqdd.split(':')
              enclosure_fqdd = enclosure_fqdd.join(':')
              controller_changes = changes['whole'][raid_fqdd]
              controller_changes[enclosure_fqdd] = {} if controller_changes[enclosure_fqdd].nil?
              controller_changes[enclosure_fqdd].merge!({disk_fqdd => {'RAIDHotSpareStatus' => 'Global', 'RAIDPDState' => 'Ready'}})
            end
          end
        end
      else
        raid_fqdds = target_current_xml.xpath("/SystemConfiguration/Component[contains(@FQDD, 'RAID.')]").collect{|node| node.attr('FQDD')}
        raid_fqdds.each{|raid_fqdd| changes['remove']['components'][raid_fqdd] = {} }
      end
    end
    changes
  end

  def raid_in_sync?(xml_base, log=false)
    if ['none_with_raid', 'hd'].include?(@resource[:target_boot_device].downcase)
      raid_configuration.keys.each do |raid_fqdd|
        raid_fqdd_xpath = "//Component[@FQDD='#{raid_fqdd}']"
        controller_xml = xml_base.xpath(raid_fqdd_xpath)
        existing_virtual_disks = controller_xml.xpath("Component[starts-with(@FQDD, 'Disk.')]")
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
    net_config = ASM::NetworkConfiguration.new(@network_config_data)
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
    unless @resource[:target_boot_device].downcase.start_with?('none')
      if net_config.get_partitions('PXE').first.nil?
        boot_seq = ['HardDisk.List.1-1'].join(', ')
      else
        boot_seq = [net_config.get_partitions('PXE').first.fqdd, 'HardDisk.List.1-1'].join(', ')
      end
      config['partial']['BIOS.Setup.1-1'] = {'BiosBootSeq'=>boot_seq}
    end
    net_config.cards.each do |card|
      card.interfaces.each do |interface|
        partitioned = interface['partitioned']
        interface.partitions.each do |partition|
          fqdd = partition.fqdd
          #
          # SET UP NIC IN CASE INTERFACE IS BEING PARTITIONED, equivalent to the enable_npar parameter
          #
          if !@resource[:target_boot_device].downcase.start_with?('none') || !partition.networkObjects.nil?
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
              if @resource[:target_boot_device] != 'iSCSI' && @resource[:target_boot_device] != 'FC'
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
               handle_missing_attributes(changes)
              else
                #This is just to clean up the changes hash, but should be unnecessary
                config['partial'].remove(fqdd)
              end
            end
            #
            # CONFIGURE LEGACYBOOTPROTO IN CASE NIC IS FOR PXE
            #
            if partition['networkObjects'] && !partition['networkObjects'].find { |obj| obj['type'] =='PXE' }.nil?
              changes['LegacyBootProto'] = 'PXE'
            end
          end
        end
      end
    end
    config
  end

   #Helper function to remove two attributes from nic configuration. Should be for Intel cards only.
  def handle_missing_attributes(changes)
    changes['VirtualizationMode'] = 'NONE'
    changes['NicPartitioning'] = 'Disabled'
    ['VirtualizationMode','NicPartitioning'].each do |dev_attr|
      #Check if Attribute name exists in the xml, and if it doesn't, check if we're trying to set to disabled.  If so, delete from the list of changes.
      if xml_base.at_xpath("//Attribute[@Name='#{dev_attr}']").nil?
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
end
