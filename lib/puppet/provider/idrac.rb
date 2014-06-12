require 'asm/util'
require 'uri'
provider_path = Pathname.new(__FILE__).parent
require File.join(provider_path, 'checklcstatus')
require File.join(provider_path, 'checkjdstatus')
require File.join(provider_path, 'exporttemplatexml')
require File.join(provider_path, 'importtemplatexml')
require 'puppet/idrac/util'
require 'net/ssh'

class Puppet::Provider::Idrac <  Puppet::Provider

  def exists?
    wait_for_lc_ready
    begin
      exporttemplate
    rescue
      Puppet.debug 'Export template failed.'
      reset
      exporttemplate
    end
    synced = !resource[:force_reboot] && config_in_sync?
    Puppet.info("Server is already configured.  Skipping import...") if synced
    synced
  end

  #This function will exit when the LC status is 0, or a puppet error will be raised if the LC status never is 0 (never stops being busy)
  def wait_for_lc_ready(attempts=0, max_attempts=30)
    if(attempts > max_attempts)
      raise Puppet::Error, "Life cycle controller is busy"
    else
      status = lcstatus.to_i
      if(status == 0)
        return
      else
        Puppet.debug "LC status is busy: status code #{status}. Waiting..."
        sleep sleep_time
        wait_for_lc_ready(attempts+1, max_attempts)
      end
    end
  end

  # how much time to sleep during wait_for_lc_ready method
  #For some reason, this doens't actually sleep for 1 minute as expected.  It seems to sleep closer to 4-6 seconds.
  def sleep_time
    60
  end

  #this could probably be more "integrated" with importtemplatexml's munge_config_xml with some reasonable changes to that function
  def config_in_sync?
    in_sync = true
    import_obj = Puppet::Provider::Importtemplatexml.new(
      transport[:host],
      transport[:user],
      transport[:password],
      resource
    )
    changes = import_obj.get_config_changes
    config_xml_path = "#{resource[:nfssharepath]}/#{resource[:configxmlfilename]}"
    f = File.open(config_xml_path)
    xml_doc = Nokogiri::XML(f.read) do |config|
      config.default_xml.noblanks
    end
    xml_base = xml_doc.xpath('/SystemConfiguration')
    #can check partial and whole node changes in the same way
    changes['whole'].merge(changes['partial']).each do |fqdd, children|
      component_path = "//Component[@FQDD='#{fqdd}']"
      in_sync &= check_changes(children, component_path, xml_base)
      if(!in_sync)
        break;
      end
    end
    changes['remove']['attributes'].each do |fqdd, children|
      break if !in_sync
      component_path = "//Component[@FQDD='#{fqdd}']"
      in_sync &= check_removes(fqdd, children, "/SystemConfiguration", xml_base, "Attribute")
    end
    changes['remove']['components'].each do |fqdd, children|
      break if !in_sync
      component_path = "//Component[@FQDD='#{fqdd}']"
      in_sync &= check_removes(fqdd, children, "/SystemConfiguration", xml_base, "Component")
    end
    return in_sync
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
        in_sync = false
      end
    end
    return in_sync
  end

  def check_changes(changes, path, xml_base)
    in_sync = true
    changes.each do |key, value|
      if(value.is_a?(String))
        #BiosBootSeq never seems to be exactly the same after setting it.
        #For example, we set 'NIC.Integrated.1-1-1, HardDisk.List.1-1', but it might still come back as "NIC.Integrated.1-1-1, HardDisk.List.1-1, Floppy.USBFront.1-1, Optical.USBFront.2-1, NIC.Integrated.1-2-1"
        if(key == "BiosBootSeq")
          node = xml_base.at_xpath("#{path}/Attribute[@Name='#{key}']")
          existing_seq = node.nil? ? find_commented_attr_val(key, xml_base) : node.content
          compare = value.delete(' ').split(',').zip(existing_seq.delete(' ').split(',')).select{|new_val, exist_val| new_val != exist_val}
          if(compare.size != 0)
            in_sync = false
            break
          end
        # These are attributes that will change from our imported values.  They are not important to be the same value though, so they are ignored.
        elsif(!["RAIDresetConfig", "RAIDaction", "RAIDinitOperation", "Size"].include?(key))
          node = xml_base.at_xpath("#{path}/Attribute[@Name='#{key}']")
          if(node.nil?)
            #Still a possibility the value is just commented out, so need to check for that.
            commented_val = find_commented_attr_val(key, xml_base)
              if(!commented_val.nil? && find_commented_attr_val(key, xml_base) != value)
              in_sync = false
              break;
            end
          elsif(node.content != value)
            in_sync=false
            break;
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
    return in_sync
  end

  def find_commented_attr_val(name, xml_base)
    xml_base.xpath("//comment()").each do |comment|
      if comment.content.include?(name)
        node = Nokogiri::XML(comment.content)
        if(node.at_xpath("/Attribute")['Name'] == name)
          return node.at_xpath("/Attribute").content
        end
      end
    end
    nil
  end

  def reset
    Puppet.info("Resetting Idrac...")
    Net::SSH.start( transport[:host],
                    transport[:user], 
                    :password => transport[:password] ) do |ssh|
      ssh.exec "racadm racreset hard" do |ch, stream, data|
        Puppet.debug(data)
        raise Puppet::Error, 'Error resetting Idrac' if stream == :stderr
      end
    end
    wait_for_idrac
  end

  def wait_for_idrac (timeout = 180, state = 0)
    raise Puppet::Error, 'Timeout waiting for Idrac' if timeout == 0
    Puppet.debug("waiting #{timeout} seconds for Idrac...")
    sleep timeout
    begin
      wait_for_idrac(timeout/2) if lcstatus.to_i != state
    rescue
      wait_for_idrac(timeout/2)
    end
  end

  def transport
    @transport ||= Puppet::Idrac::Util.get_transport()
  end

  def importtemplate
    obj = Puppet::Provider::Importtemplatexml.new(
      transport[:host],
      transport[:user],
      transport[:password],
      resource
    )
    obj.importtemplatexml
  end

  def exporttemplate
    obj = Puppet::Provider::Exporttemplatexml.new(
      transport[:host],
      transport[:user],
      transport[:password],
      resource,
      '/var/nfs'
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

  def lcstatus
    obj = Puppet::Provider::Checklcstatus.new(
      transport[:host],
      transport[:user],
      transport[:password]
    )
    obj.checklcstatus
  end
end
