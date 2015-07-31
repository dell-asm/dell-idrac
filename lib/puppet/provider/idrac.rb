require 'asm/util'
require 'uri'
provider_path = Pathname.new(__FILE__).parent
require File.join(provider_path, 'checklcstatus')
require File.join(provider_path, 'checkjdstatus')
require File.join(provider_path, 'exporttemplatexml')
require File.join(provider_path, 'importtemplatexml')
require 'asm/wsman'
require 'puppet/idrac/util'
require 'net/ssh'
require 'puppet/util/warnings'
require 'fileutils'

class Puppet::Provider::Idrac <  Puppet::Provider
  def exists?
    wait_for_lc_ready
    exporttemplate
    synced = resource[:ensure] != :teardown && !resource[:force_reboot] && config_in_sync?
    Puppet.info("Server is already configured.  Skipping import...") if synced
    synced
  end

  #This function will exit when the LC status is 0, or a puppet error will be raised if the LC status never is 0 (never stops being busy)
  def wait_for_lc_ready
    lc_ready = false
    30.times do
      status = Puppet::Idrac::Util.lcstatus.to_i
      if status == 0
        lc_ready = true
        break
      else
        Puppet.debug "LC status is busy: status code #{status}. Waiting..."
        sleep sleep_time
      end
    end
    raise(Puppet::Error, "Life cycle controller is busy") unless lc_ready
  end

  # how much time to sleep during wait_for_lc_ready method
  #For some reason, this doens't actually sleep for 1 minute as expected.  It seems to sleep closer to 4-6 seconds.
  def sleep_time
    60
  end

  #this could probably be more "integrated" with importtemplatexml's munge_config_xml with some reasonable changes to that function
  def config_in_sync?(export_postfix='original')
    in_sync = true
    import_obj = Puppet::Provider::Importtemplatexml.new(
      transport[:host],
      transport[:user],
      transport[:password],
      resource,
      export_postfix
    )
    changes = import_obj.get_config_changes
    exported_config = File.basename(resource[:configxmlfilename], ".xml")+"_#{export_postfix}.xml"
    config_xml_path = File.join(resource[:nfssharepath], exported_config)
    f = File.open(config_xml_path)
    xml_doc = Nokogiri::XML(f.read) do |config|
      config.default_xml.noblanks
    end
    xml_base = xml_doc.xpath('/SystemConfiguration')
    #can check partial and whole node changes in the same way
    edits = changes['whole'].merge(changes['partial'])
    check_for_important_attrs(xml_base, edits)
    edits.each do |fqdd, children|
      component_path = "//Component[@FQDD='#{fqdd}']"
      in_sync &= check_changes(children, component_path, xml_base)
      break unless in_sync
    end
    changes['remove']['attributes'].each do |fqdd, children|
      break unless in_sync
      component_path = "//Component[@FQDD='#{fqdd}']"
      in_sync &= check_removes(fqdd, children, "/SystemConfiguration", xml_base, "Attribute")
    end
    changes['remove']['components'].each do |fqdd, children|
      break if !in_sync
      component_path = "//Component[@FQDD='#{fqdd}']"
      in_sync &= check_removes(fqdd, children, "/SystemConfiguration", xml_base, "Component")
    end
    in_sync &= import_obj.raid_in_sync?(xml_base, true) if in_sync
    return in_sync
  end

  def check_for_important_attrs(xml_base, changes)
    bios_settings_path = "//Component[@FQDD='BIOS.Setup.1-1']"
    ['InternalSdCard'].each do |attr_name|
      node = xml_base.at_xpath("#{bios_settings_path}/Attribute[@Name='#{attr_name}']")
      value = changes['BIOS.Setup.1-1'][attr_name]
      if node.nil? && ['On', 'Enabled'].include?(value)
        raise("Need to set #{attr_name} to #{value}, but that attribute does not exist on the server.")
      end
    end
  end


  def check_removes(node_name, data, path, xml_base, node_type)
    in_sync = true
    name_attr = node_type == "Component" ? "FQDD" : "Name"
    if(!data.nil? && data.size != 0)
      new_path = "#{path}/Component[@FQDD='#{node_name}']"
      data.each do |name, child_data|
        in_sync &= check_removes(name, child_data,new_path, xml_base, node_type)
      end
    else
      node_path = "#{path}/#{node_type}[@#{name_attr}='#{node_name}']"
      existing = xml_base.at_xpath(node_path)
      if(!existing.nil?)
        Puppet.debug("#{node_type} #{node_name} under xpath #{node_path} exists in the exported config.xml.  Need to import to ensure the #{node_type.downcase} is removed from configuration.")
        in_sync = false
      end
    end
    return in_sync
  end

  def check_changes(changes, path, xml_base)
    in_sync = true
    changes.each do |key, value|
      if(value.is_a?(String))
        node = xml_base.at_xpath("#{path}/Attribute[@Name='#{key}']")
        existing_val = node.nil? ? find_commented_attr_val(key, xml_base) : node.content
        if(existing_val.nil?)
          Puppet.debug("Could not find a value for #{key} under FQDD at xpath #{path}. Will need need to import new configuration.")
          in_sync=false
        elsif(existing_val != value)
          if(key == "BiosBootSeq")
            compare = value.delete(' ').split(',').zip(existing_val.delete(' ').split(',')).select{|new_val, exist_val| new_val != exist_val}
            if(compare.size != 0 && @resource[:ensure] != :teardown)
              Puppet.debug("Value of BiosBootSeq does not match up. Existing Seq: #{existing_val}, trying to set to  #{value}")
              in_sync = false
              break
            end
          else
            Puppet.debug("Need to set #{key}=#{value} under FQDD at xpath #{path}.  Server's config has this set to #{key}=#{existing_val}.")
            in_sync = false
            break
          end
        end
      elsif(value.is_a?(Hash))
        new_path = "#{path}/Component[@FQDD='#{key}']"
        in_sync &= check_changes(value, new_path, xml_base)
        if(!in_sync)
          break;
        end
      end
    end
    in_sync
  end

  def find_commented_attr_val(name, xml_base)
    xml_base.xpath("//comment()").each do |comment|
      if comment.content.include?(name)
        node = Nokogiri::XML(comment.content)
        if node.at_xpath("/Attribute")['Name'] == name
          return node.at_xpath("/Attribute").content
        end
      end
    end
    nil
  end

  def transport
    @transport ||= Puppet::Idrac::Util.get_transport
  end

  def exporttemplate(postfix='original')
    begin
      execute_export_config(postfix)
    rescue Exception=>e
      Puppet.debug "Export template failed with exception: #{e}"
      Puppet::Idrac::Util.reset
      execute_export_config(postfix)
    end
  end

  def execute_export_config(postfix='original')
    #TODO:  remove /var/nfs and prefer to use resource[:nfssharepath]
    obj = Puppet::Provider::Exporttemplatexml.new(
        transport[:host],
        transport[:user],
        transport[:password],
        resource,
        '/var/nfs',
        postfix
    )
    obj.exporttemplatexml
  end

  def checkjobstatus(instanceid)
    obj = Puppet::Provider::Checkjdstatus.new(
      transport[:host],
      transport[:user],
      transport[:password],
      instanceid
    )
    obj.checkjdstatus
  end

  def reboot
    ASM::WsMan.reboot({:host=>transport[:host], :user=>transport[:user], :password=>transport[:password]})
  end

end
