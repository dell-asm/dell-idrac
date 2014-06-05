require 'rexml/document'
require 'json'
require 'nokogiri'
require 'hashie'
require 'active_support'

include REXML

class Puppet::Provider::Importtemplatexml <  Puppet::Provider

  def initialize (ip,username,password,resource)
    @ip = ip
    @username = username
    @password = password
    @configxmlfilename = resource[:configxmlfilename]
    @nfsipaddress = resource[:nfsipaddress]
    @nfssharepath = resource[:nfssharepath]
    @resource = resource
    @bios_settings = resource[:bios_settings]
    @network_config_data = resource[:network_config]
  end

  def importtemplatexml
    munge_config_xml
    response=executeimportcmd
    Puppet.info "#{response}"
    # get instance id
    xmldoc = Document.new(response)
    instancenode = XPath.first(xmldoc, '//wsman:Selector Name="InstanceID"')
    tempinstancenode = instancenode
    if tempinstancenode.to_s == ""
      raise "Job ID not created"
    end
    instanceid=instancenode.text
    Puppet.info "Instance id #{instanceid}"
    return instanceid
  end

  def executeimportcmd
    command = "wsman invoke http://schemas.dmtf.org/wbem/wscim/1/cim-schema/2/root/dcim/DCIM_LCService?SystemCreationClassName=\"DCIM_ComputerSystem\",CreationClassName=\"DCIM_LCService\",SystemName=\"DCIM:ComputerSystem\",Name=\"DCIM:LCService\" -h #{@ip} -V -v -c dummy.cert -P 443 -u #{@username} -p #{@password} -a ImportSystemConfiguration -k \"IPAddress=#{@resource['nfsipaddress']}\" -k \"ShareName=#{@resource['nfssharepath']}\" -k \"ShareType=0\" -k \"FileName=#{@resource['configxmlfilename']}\" -k \"ShutdownType=1\""
    resp = `#{command}`
  end

  def get_config_changes
    templates_dir = File.join(Puppet::Module.find('idrac').path, 'templates')
    file_name = File.exist?("#{templates_dir}/#{@resource[:model]}-config.erb") ? "#{@resource[:model]}-config.erb" : "default-config.erb"
    path_to_template = File.join(templates_dir, file_name)
    template = File.open(path_to_template)
    erb = ERB.new(template.read)
    template.close
    changes = JSON.parse(erb.result(binding))
    
    nic_changes = process_nics
    changes.deep_merge!(nic_changes)

    #if idrac is booting from san, configure networks / virtual identities
    munge_network_configuration(@resource[:network_config], changes, @resource[:target_boot_device]) if @resource[:target_boot_device] == 'iSCSI' || @resource[:target_boot_device] == 'FC'

    munge_bfs_bootdevice(changes) if @resource[:target_boot_device] == 'iSCSI' || @resource[:target_boot_device] == 'FC'
    return changes
  end

  def munge_config_xml
    changes = get_config_changes
    config_xml_path = "#{@resource[:nfssharepath]}/#{@resource[:configxmlfilename]}"
    #Export from server is not needed here, since the exists? method in the importsystemconfiguration provider will do an export beforehand to check values
    if(!@resource[:config_xml].nil?)
      config_xml = Nokogiri::XML(@resource[:config_xml])
      File.open(config_xml_path, 'w+') { |file| file.write(config_xml.to_xml(:indent => 2)) }
    end
    f = File.open(config_xml_path)
    xml_doc = Nokogiri::XML(f.read) do |config|
      config.default_xml.noblanks
    end
    xml_base = xml_doc.xpath('/SystemConfiguration').first
    f.close
    #REMOVE all existing NIC data.  All NIC FQDDs will contain "NIC."
    xml_base.xpath("//Component[contains(@FQDD, 'NIC.')]").remove()
    xml_base['ServiceTag'] = @resource[:servicetag]
    #Current workaround for LC issue, where if BiotBootSeq is already set to what ASM needs it to be, setting it again to the same thing will cause an error.
    existing_boot_seq = find_bios_boot_seq(xml_base)
    boot_seq_change = changes['partial']['BIOS.Setup.1-1']['BiosBootSeq']
    if(existing_boot_seq && boot_seq_change)
      if(existing_boot_seq.start_with?(boot_seq_change))
        changes['partial']['BIOS.Setup.1-1'].delete('BiosBootSeq')
      end
    end
    #Handle partial node changes (node should exist already, but needs data edited/added within)
    changes['partial'].keys.each do |parent|
      process_partials(parent, changes['partial'][parent], xml_base)
    end
    #Handle whole nodes (node should be replaced if exists, or should be created if not)
    changes["whole"].keys.each do |name|
      path = "/SystemConfiguration/Component[@FQDD='#{name}']"
      existing = xml_base.xpath(path).first
      #if node exists there, just go ahead and remove it
      if(!existing.nil?)
        existing.remove
      end 
      create_full_node(name, changes["whole"][name], xml_base, xml_base.xpath("/SystemConfiguration").first)
    end
    #Handle node removal (ensure nodes listed here don't exist)
    changes["remove"]["attributes"].keys.each do |parent|
      process_remove_nodes(parent, changes["remove"]["attributes"][parent], xml_base, "Attribute")
    end
    changes["remove"]["components"].keys.each do |parent|
      process_remove_nodes(parent, changes["remove"]["components"][parent], xml_base, "Component")
    end
    ##Clean up the config file of all the commented text
    xml_doc.xpath('//comment()').remove
    # Disable SD card and RAID controller for boot from SAN
    File.open(config_xml_path, 'w+') { |file| file.write(xml_doc.root.to_xml(:indent => 2)) }
    xml_doc
  end

  #Helper function which just searches through the xml comments for BiosBootSeq value, since it will be commented out
  def find_bios_boot_seq(xml_base)
    xml_base.xpath("//Component[@FQDD='BIOS.Setup.1-1']/comment()").each do |comment|
      if comment.content.include?("BiosBootSeq")
        node = Nokogiri::XML(comment.content)
        #Other names are possible for the node that contain "BiosBootSeq", such as "OneTimeBiosBootSeq", so must ensure it is exactly "BiosBootSeq"
        if(node.at_xpath("/Attribute")['Name'] == "BiosBootSeq")
          return node.at_xpath("/Attribute").content
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
    munge_virt_mac_addr(nc, changes)
    changes['remove']['components']['RAID.Integrated.1-1'] = {}
    changes
  end
  
  def munge_iscsi_partitions(nc, changes)
    iscsi_partitions = nc.get_partitions('STORAGE_ISCSI_SAN')
    bios_boot_sequence = []
    iscsi_partitions.each do |partition|
        iscsi_network = get_iscsi_network(partition['networkObjects'])
        if (ASM::Util.to_boolean(iscsi_network.static))
          changes['partial'].deep_merge!(
          { partition.nic.fqdd =>
            {
                  'VirtualizationMode' => 'NONE',
                  'VirtMacAddr' => partition['lanMacAddress'],
                  'VirtIscsiMacAddr' => partition['iscsiMacAddress'],
                  'TcpIpViaDHCP' => 'Disabled',
                  'IscsiViaDHCP' => 'Disabled',
                  'ChapAuthEnable' => 'Disabled',
                  'IscsiTgtBoot' => 'Enabled',
                  'IscsiInitiatorIpAddr' => iscsi_network['staticNetworkConfiguration']['ipAddress'],
                  'IscsiInitiatorSubnet' => iscsi_network['staticNetworkConfiguration']['subnet'],
                  'IscsiInitiatorGateway' => iscsi_network['staticNetworkConfiguration']['gateway'],
                  'IscsiInitiatorName' => partition['iscsiIQN'],
                  'ConnectFirstTgt' => 'Enabled',
                  'FirstTgtIpAddress' => @resource[:target_ip],
                  'FirstTgtTcpPort' => '3260',
                  'FirstTgtIscsiName' => @resource[:target_iscsi],
                  'LegacyBootProto' => 'iSCSI',
                  'iScsiOffloadMode' => 'Enabled'
            }
          })
          bios_boot_sequence.push(partition.nic.fqdd)
        else
          Puppet.warn("Found non-static iSCSI network while configuring boot from SAN")
        end
    end
    changes['partial'].deep_merge!({'BIOS.Setup.1-1' => { 'BiosBootSeq' => bios_boot_sequence.join(',') } })
  end
  
  def munge_virt_mac_addr(nc, changes)
    partitions = nc.get_all_partitions
    partitions.each do |partition|
      if(!partition['lanMacAddress'].nil?)
	      changes['partial'].deep_merge!({
	        partition.nic.fqdd => {
	          'VirtMacAddr' => partition['lanMacAddress']
	        }
	      })
	  end
    end
  end

  def get_iscsi_network(network_objects)
    network_objects.detect do |network|
      network['type'] == 'STORAGE_ISCSI_SAN'
    end
  end

  def process_remove_nodes(node_name, data, xml_base, type, path="/SystemConfiguration")
    name_attr = type == "Component" ? "FQDD" : "Name" 
    #If data is a list, it is a list of items under the node to delete
    if(!data.nil? && data.size != 0)
      new_path = "#{path}/Component[@FQDD='#{node_name}']"
      data.each do |name, child_data|
        process_remove_nodes(name, child_data, xml_base, type, new_path)
      end
    else
      node_path = "#{path}/#{type}[@#{name_attr}='#{node_name}']"
      existing = xml_base.xpath(node_path).first
      if(!existing.nil?)
        existing.remove
      end
    end
  end

  def create_full_node(node_name, content, xml_base, parent)
    # IF content data is a hash, then it is a component node, otherwise it is just an attribute node
    if(content.is_a?(Hash))
      new_component = Nokogiri::XML::Node.new "Component", xml_base
      new_component.parent = parent
      new_component["FQDD"] = node_name
      content.keys.each do |child_name|
        create_full_node(child_name, content[child_name], xml_base, new_component)
      end
    else
      if(content.is_a?(Array))
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
    if(data.is_a?(Hash))
      new_path = "#{path}/Component[@FQDD='#{node_name}']"
      existing = xml_base.xpath(new_path).first
      if(existing.nil?)
        new_node = Nokogiri::XML::Node.new "Component", xml_base
        new_node.parent = xml_base.xpath(path).first
        new_node["FQDD"] = node_name
      end
      data.keys.each do |child|
        process_partials(child, data[child], xml_base, new_path)
      end
    #If the data is an Array, it is a list of attributes with the same Name but different values
    elsif(data.is_a?(Array))
      data.each_with_index do |content, index|
        existing = xml_base.xpath("#{path}[#{index+1}]").first.content = content
        if(existing)
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
      if(existing)
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
    config = {'partial'=>{}, 'whole'=>{}, 'remove'=> {'attributes'=>{}, 'components'=>{}}}
    net_config.cards.each do |card|
      card.interfaces.each do |interface|
        partitioned = interface['partitioned']
        interface.partitions.each do |partition|
          fqdd = partition.fqdd
          #
          # SET UP NIC IN CASE INTERFACE IS BEING PARTITIONED, equivalent to the enable_npar parameter
          #
          changes = config['partial'][fqdd] = {}
          removes = config['remove']['attributes'][fqdd] = []
          partition_no = partition.partition_no
          changes["NicMode"] = "Enabled"
          changes["VLanMode"] = "Disabled" if partition_no == 1
          if partitioned
            if(partition_no == 1)
              changes["VirtualizationMode"] = "NPAR"
              changes["NicPartitioning"] = "Enabled"
            end
          else
            if partition_no > 1
              #If not being partitioned, and we have a partition that was in the list of NICs, we have to be sure to remove it, and then continue with the loop of partitions
              config['changes']['remove']['components'][fqdd] = []
              #These removes are ultimately unnecessary, but just exist to clean up the config hash that will be passed back.
              config['partial'].remove(fqdd)
              config['remove']['attributes'].remove(fqdd)
              next
            else
              changes["VirtualizationMode"] = "NONE"
              changes["NicPartitioning"] = "Disabled"
              removes.push('FCoEOffloadMode')
            end
          end
          changes['MinBandwidth'] = partition.minimum
          changes['MaxBandwidth'] = partition.maximum
          #
          # CONFIGURE ISCSI NETWORK
          #
          if partition['networkObjects'] && !partition['networkObjects'].find { |obj| obj["type"].include?("ISCSI") }.nil?
            changes['iScsiOffloadMode'] = "Enabled"
            #FCoEOffloadMode MUST be disabled if iScsiOffloadMode is Enabled
            changes['FCoEOffloadMode'] = "Disabled"
          else
            changes['iScsiOffloadMode'] = "Disabled"
            #Curently always setting FCoEOffloadMode to Disabled, but any logic to set it otherwise should probably go here in the future
            changes['FCoEOffloadMode'] = "Disabled"
          end
          #
          # CONFIGURE LEGACYBOOTPROTO IN CASE NIC IS FOR PXE
          #
          if partition['networkObjects'] && !partition['networkObjects'].find { |obj| obj["type"] =="PXE" }.nil?
            changes["LegacyBootProto"] = "PXE"
          else
            #Make sure any LegacyBootProto is removed
            removes.push("LegacyBootProto")
          end
        end
      end
    end
    config
  end

end

