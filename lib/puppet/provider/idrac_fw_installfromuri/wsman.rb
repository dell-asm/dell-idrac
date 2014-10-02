require 'puppet/idrac/util'
require 'nokogiri'
require 'active_support'
require 'liquid'

Puppet::Type.type(:idrac_fw_installfromuri).provide(:wsman) do

  def exists?
    @uri_path = resource[:uri_path]
    @instance_id = resource[:instance_id]
    @force_restart = resource[:force_restart]
    true
  end
    
  def create 
    clear_out_jobqueue
    config_file_path = create_xml_config_file
    job_id = install_from_uri(config_file_path)
    remove_config_file(config_file_path)
    job_status = 'new'
    until job_status =~ /Downloaded|Completed|Failed/
      sleep 30
      job_status = get_job_status(job_id)
      Puppet.debug("Job Status: #{job_status}")
    end
    case job_status
    when "Completed"
      Puppet.debug("Firmware update completed successfully")
    when "Failed"
      raise Puppet::Error, "Firmware update failed in the lifecycle controller.  Please refer to LifeCycle job logs"
    when "Downloaded"
      Puppet.debug("Firmware downloaded to idrac, scheduling apply")
      reboot_config_file_path = create_reboot_config_file
      reboot_id = create_reboot_job(reboot_config_file_path)
      remove_config_file(reboot_config_file_path)
      reboot_status = get_job_status(reboot_id)
      job_queue_config_file = create_job_queue_config(job_id,reboot_id)
      setup_job_queue(job_queue_config_file)
      remove_config_file(job_queue_config_file)
      reboot_status = 'new'
      until reboot_status == 'Reboot Completed'
        sleep 30
        reboot_status = get_job_status(reboot_id)
        Puppet.debug("Reboot Status: #{reboot_status}")
      end
      until job_status =~ /Completed|Failed/
        sleep 30
        job_status = get_job_status(job_id)
        Puppet.debug("Job Status: #{job_status}")
      end
      case job_status
      when "Completed"
        Puppet.debug("Firmware update completed successfully")
      when "Failed"
        raise Puppet::Error, "Firmware update failed in the lifecycle controller.  Please refer to LifeCycle job logs"
      end
    end
  end


  def clear_out_jobqueue
    Puppet.debug("Clearing old job queue")
    wsman_cmd = "wsman invoke -a \"DeleteJobQueue\" http://schemas.dell.com/wbem/wscim/1/cim-schema/2/DCIM_JobService?CreationClassName=\"DCIM_JobService\",SystemName=\"Idrac\",Name=\"JobService\",SystemCreationClassName=\"DCIM_ComputerSystem\" -N root/dcim -u #{transport[:user]} -p #{transport[:password]} -h #{transport[:host]} -P 443 -v -j utf-8 -y basic -o -m 256 -c Dummy -V  -k \"JobID=JID_CLEARALL\""
    resp = run_wsman(wsman_cmd)
    Puppet.debug(resp)
    doc = Nokogiri::XML(resp)
    if doc.xpath('//n1:MessageID').text == 'SUP020'
      Puppet.debug("Job queue cleared successfully")
    else
      raise Puppet::Error, "Error clearing job queue: #{doc.xpath('//n1.Message').text}"
    end
  end

  def transport
    @transport ||= Puppet::Idrac::Util.get_transport()
  end

  def run_wsman(cmd)
    sleeptime = 30
    4.times do
      resp = %x[#{cmd}]
      if resp.length == 0
        Puppet.debug("WSMAN O length response received, retrying after sleep")
        sleep sleeptime
        sleeptime += 30
      elsif resp.include? 'Authentication failed'
        Puppet.debug("WSMAN authentication failed, retrying after sleep")
        sleep sleeptime
        sleeptime += 30
      elsif resp.include? 'Connection failed'
        Puppet.debug("WSMAN connection failed, retrying after sleep")
        sleep sleeptime
        sleeptime += 30
      else
        return resp.encode('utf-8', 'binary', :invalid => :replace, :undef => :replace)
      end
    end
    raise Puppet::Error, "Could not connect connect to wsman endpoint"
  end

  def install_from_uri(config_file_path)
    wsman_cmd = "wsman invoke -a InstallFromURI http://schemas.dmtf.org/wbem/wscim/1/cim-schema/2/root/dcim/DCIM_SoftwareInstallationService?CreationClassName=DCIM_SoftwareInstallationService,SystemCreationClassName=DCIM_ComputerSystem,SystemName=IDRAC:ID,Name=SoftwareUpdate -h #{transport[:host]} -V -v -c Dummy -P 443 -u #{transport[:user]} -p #{transport[:password]} -J #{config_file_path} -j utf-8 -y basic"
    resp = run_wsman(wsman_cmd)
    Puppet.debug(resp)
    doc = Nokogiri::XML(resp)
    if doc.xpath('//n1:ReturnValue').text == '4096'
      job_id = doc.xpath('//wsman:Selector').first.text
      Puppet.debug("InstallFromURI started")
      Puppet.debug("JOB_ID: #{job_id}")
      return job_id
    else
      raise Puppet::Error, "Problem running InstallFromURI: #{doc.xpatch('//n1:Message')}"
    end
  end
  
  def create_xml_config_file
    random_hash = rand(36**24).to_s(36)
    template = <<-EOF
<p:InstallFromURI_INPUT xmlns:p="http://schemas.dmtf.org/wbem/wscim/1/cim-schema/2/root/dcim/DCIM_SoftwareInstallationService">
<p:URI>http://xx.xx.xx.xx:1278/install_packages/Packages/ESM_Firmware_NV7KM_WN32_1.31.30_A00.EXE</p:URI>
<p:Target xmlns:a="http://schemas.xmlsoap.org/ws/2004/08/addressing" xmlns:w="http://schemas.dmtf.org/wbem/wsman/1/wsman.xsd">
<a:Address>http://schemas.xmlsoap.org/ws/2004/08/addressing/role/anonymous</a:Address>
<a:ReferenceParameters>
<w:ResourceURI>http://schemas.dell.com/wbem/wscim/1/cim-schema/2/DCIM_SoftwareIdentity</w:ResourceURI>
<w:SelectorSet>
<w:Selector Name="InstanceID">DCIM:INSTALLED#iDRAC.Embedded.1-1#IDRACinfo</w:Selector>
</w:SelectorSet> </a:ReferenceParameters> </p:Target> </p:InstallFromURI_INPUT>
    EOF
    xml_template = Liquid::Template.parse(template)
    xml_config = xml_template.render('uri_path' => @uri_path, 'instance_id' => @instance_id)
    File.open("/tmp/#{random_hash}.xml","w") do |f|
      f.puts xml_config
    end
    return "/tmp/#{random_hash}.xml"
  end

  def create_reboot_config_file
    random_hash = rand(36**24).to_s(26)
    template = <<-EOF
<p:CreateRebootJob_INPUT xmlns:p="http://schemas.dmtf.org/wbem/wscim/1/cim-schema/2/root/dcim/DCIM_SoftwareInstallationService">
  <p:RebootJobType>3</p:RebootJobType>
</p:CreateRebootJob_INPUT>
EOF
    file_path = "/tmp/#{random_hash}.xml"
    File.open(file_path,'w') do |f|
      f.puts template
    end
    file_path
  end

  def create_job_queue_config(job_id,reboot_id)
    random_hash = rand(36**24).to_s(26)
    template = <<-EOF
<p:SetupJobQueue_INPUT xmlns:p="http://schemas.dell.com/wbem/wscim/1/cim-schema/2/DCIM_JobService">
<p:JobArray>{{job_id}}</p:JobArray>
<p:JobArray>{{reboot_id}}</p:JobArray>
<p:RunMonth>6</p:RunMonth>
  <p:RunDay>18</p:RunDay>
<p:StartTimeInterval>TIME_NOW</p:StartTimeInterval>
</p:SetupJobQueue_INPUT>
EOF
    xml_template - Liquid::Template.parse(template)
    xml_config = xml_template.render('job_id' => job_id, 'reboot_id' => reboot_id)
    file_path = "/tmp/#{random_hash}.xml"
    File.open(file_path,'w') do |f|
      f.puts xml_config
    end
    file_path
  end

  def get_job_status(id)
    wsman_cmd = "wsman get http://schemas.dell.com/wbem/wscim/1/cim-schema/2/DCIM_LifecycleJob?InstanceID=\"#{id}\" -N root/dcim -u #{transport[:user]} -p #{transport[:password]} -h #{transport[:host]} -P 443 -v -j utf-8 -y basic -o -m 256 -c Dummy -V"
    resp = run_wsman(wsman_cmd)
    doc = Nokogiri::XML(resp)
    status = doc.xpath('//n1:JobStatus').text
    Puppet.debub("JOB_ID Status: #{status}")
    status
  end

  def create_reboot_job(reboot_file)
    wsman_cmd = "wsman invoke -a InstallFromURI http://schemas.dmtf.org/wbem/wscim/1/cim-schema/2/root/dcim/DCIM_SoftwareInstallationService?CreationClassName=DCIM_SoftwareInstallationService,SystemCreationClassName=DCIM_ComputerSystem,SystemName=IDRAC:ID,Name=SoftwareUpdate -h #{transport[:host]} -V -v -c Dummy -P 443 -u #{transport[:root]} -p #{transport[:password]} -J #{reboot_file} -j utf-8 -y basic"
    Puppet.debug("Creating Reboot Job")
    resp = run_wsman(wsman_cmd)
    doc = Nokogiri::XML(resp)
    if doc.xpath('//n1:ReturnValue').text == '4096'
      reboot_id = doc.xpath('//wsman:Selector').first.text
      Puppet.debug("Reboot Job scheduled successfully")
      Puppet.debug("Reboot Job ID: #{reboot_id}")
      return reboot_id
    else
      raise Puppet::Error, "Problem scheduling reboot.  Problem message: #{doc.xpath('//n1:Message').text}"
    end
  end

  def remove_config_file(config_file_path)
    FileUtil.rm(config_file_path)
  end

  def setup_job_queue(job_queue_config_file)
    wsman_cmd = "wsman invoke -a SetupJobQueue http://schemas.dell.com/wbem/wscim/1/cim-schema/2/DCIM_JobService?CreationClassName=\"DCIM_JobService\",SystemName=\"Idrac\",Name=\"JobService\",SystemCreationClassName=\"DCIM_ComputerSystem\" -N root/dcim -u #{transport[:user]} -p #{transport[:password]} -h #{transport[:host]} -P 443 -v -j utf-8 -y basic -o -m 256 -c Dummy -V -J #{job_queue_config_file}"
    Puppet.debug("Setting up Job Queue")
    resp = run_wsman(wsman_cmd)
    doc = Nokogiri::XML(resp)
    if doc.xpath('//n1:MessageID').text == 'SUP025'
      Puppet.debug("Job Queue created successfully")
    else
      raise Puppet::Error, "Problem scheduling the job queue.  Message: #{doc.xpath('//n1:Message').text}"
    end
  end
    
end

