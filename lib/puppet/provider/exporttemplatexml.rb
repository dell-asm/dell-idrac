require 'rexml/document'
require 'puppet/provider/checkjdstatus'

include REXML

class Puppet::Provider::Exporttemplatexml <  Puppet::Provider

  def initialize (ip,username,password, resource, nfswritepath='/var/nfs', name_postfix='original')
    @ip = ip
    @username = username
    @password = password
    @resource = resource
    @nfswritepath = nfswritepath
    @file_name = File.basename(@resource[:configxmlfilename], ".xml")+ "_#{name_postfix}.xml"
  end

  def exporttemplatexml
    require 'asm/wsman'
    endpoint = {:host => @ip, :user => @username, :password => @password}
    method = 'ExportSystemConfiguration'
    schema = 'http://schemas.dmtf.org/wbem/wscim/1/cim-schema/2/root/dcim/DCIM_LCService?SystemCreationClassName="DCIM_ComputerSystem",CreationClassName="DCIM_LCService",SystemName="DCIM:ComputerSystem",Name="DCIM:LCService"'
    jid = ASM::WsMan.invoke(endpoint, method, schema,
                            :logger => Puppet,
                            :selector => '//wsman:Selector Name="InstanceID"',
                            :props => {'IPAddress' => @resource[:nfsipaddress],
                                       'ShareName' => @nfswritepath,
                                       'ShareType' => 0,
                                       'FileName' => @file_name, })
    raise "Job ID not created" unless jid && !jid.empty?
    puts "Instance id #{jid}"
    move_config_xml(jid)
    jid
  end

  #TODO:  This needs to be changed to not use /var/nfs, and instead write to /var/nfs/idrac_config_xml
  #Just puts the xml in the idrac_config_xml folder (for use with importsystemconfiguration later), writing to /var/nfs due to nfs write permissions
  def move_config_xml(instanceid)
    obj = Puppet::Provider::Checkjdstatus.new(@ip,@username,@password,instanceid)
    for i in 0..30
      response = obj.checkjdstatus
      if response  == "Completed"
        Puppet.info "Export System Configuration is completed."
        file_path = File.join(@nfswritepath, @file_name)
        #Need to remove this section because of potentially sensitive data
        xml = Nokogiri::XML(File.read(file_path))
        xml.xpath("//Component[@FQDD='iDRAC.Embedded.1']").remove()
        File.open(file_path, 'w+') { |file| file.write(xml.root.to_xml(:indent => 2)) }
        FileUtils.mv(file_path, @resource[:nfssharepath])
        break
      else
        if response  == "Failed"
          raise "Job Failed."
        else
          Puppet.info "Job is running, wait for 1 minute."
          sleep 5
        end
      end
    end
    if response != "Completed"
      raise "Export System Configuration has not completed."
    end
  end
end
