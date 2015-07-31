require 'rexml/document'
require 'puppet/provider/checkjdstatus'
require 'puppet/idrac/util'

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
    Puppet::Idrac::Util.wait_or_clear_running_jobs
    require 'asm/util'
    props = {'IPAddress' => @resource[:nfsipaddress] || ASM::Util.get_preferred_ip(@ip),
             'ShareName' => @nfswritepath,
             'ShareType' => 0,
             'FileName' => @file_name, }
    job_id = Puppet::Idrac::Util.wsman_system_config_action(:export, props)
    Puppet.debug("ExportSystemConfiguration job id: #{job_id}")
    move_config_xml(job_id)
    job_id
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
        xml.xpath("//Component[not(contains(@FQDD, 'NIC.') or contains(@FQDD, 'BIOS.') or contains(@FQDD, 'RAID.') or contains(@FQDD, 'LifecycleController.'))]").remove
        #The remove above leaves many empty lines in the xml.  Just remove all the text() at the top level to keep file clean
        xml.xpath('/SystemConfiguration/text()').remove
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
