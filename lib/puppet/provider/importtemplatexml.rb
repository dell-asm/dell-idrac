require 'rexml/document'
require 'json'
require 'nokogiri'

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

  def munge_config_xml
    templates_dir = File.join(Puppet::Module.find('idrac').path, 'templates')
    file_name = File.exist?("#{templates_dir}/#{@resource[:model]}-config.erb") ? "#{@resource[:model]}-config.erb" : "default-config.erb"
    path_to_template = File.join(templates_dir, file_name)

    template = File.open(path_to_template)
    erb = ERB.new(template.read)
    template.close
    changes = JSON.parse(erb.result(binding))

    config_xml_path = "#{@resource[:nfssharepath]}/#{@resource[:configxmlfilename]}"
    if(@resource[:config_xml].nil?)
      obj = Puppet::Provider::Exporttemplatexml.new(@ip, @username, @password, resource)
      obj.exporttemplatexml
    else
      config_xml = Nokogiri::XML(@resource[:config_xml])
      File.open(config_xml_path, 'w+') { |file| file.write(config_xml.to_xml(:indent => 2)) }
    end
    f = File.open(config_xml_path)
    xml_doc = Nokogiri::XML(f.read) do |config|
      config.default_xml.noblanks
    end
    xml_base = xml_doc.xpath('/SystemConfiguration').first
    f.close

    xml_base['ServiceTag'] = @resource[:servicetag]

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
    File.open(config_xml_path, 'w+') { |file| file.write(xml_doc.to_xml(:indent => 2)) }
    xml_doc
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

end
