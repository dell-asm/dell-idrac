require 'rexml/document'
require 'puppet/provider/checkjdstatus'
require 'puppet/idrac/util'

include REXML

class Puppet::Provider::Exporttemplatexml <  Puppet::Provider

  def initialize (ip,username,password, resource, name_postfix='original')
    @ip = ip
    @username = username
    @password = password
    @resource = resource
    @nfswritepath = resource[:nfssharepath]
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
    wait_for_job(job_id)
    process_xml
    job_id
  end

  def wait_for_job(instanceid)
    obj = Puppet::Provider::Checkjdstatus.new(@ip,@username,@password,instanceid)
    for i in 0..10
      response = obj.checkjdstatus
      if response  == "Completed"
        Puppet.info "Export System Configuration is completed."
        break
      else
        if response  == "Failed"
          raise "Job Failed."
        else
          Puppet.info "Export job is still running, waiting..."
          sleep 15
        end
      end
    end
    if response != "Completed"
      raise "Export System Configuration has not completed."
    end
  end

  def process_xml
    file_path = File.join(@nfswritepath, @file_name)
    #Need to remove this section because of potentially sensitive data
    xml = Nokogiri::XML(File.read(file_path))
    xml.xpath("//Component[not(contains(@FQDD, 'NIC.') or contains(@FQDD, 'RAID.') or contains(@FQDD, 'AHCI.Slot.') or contains(@FQDD, 'BIOS.') or contains(@FQDD, 'LifecycleController.'))]").remove
    #The remove above leaves many empty lines in the xml.  Just remove all the text() at the top level to keep file clean
    xml.xpath('/SystemConfiguration/text()').remove
    File.open(file_path, 'w+') {|file| file.write(xml.root.to_xml(:indent => 2))}
  end
end
