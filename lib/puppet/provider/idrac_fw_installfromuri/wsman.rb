require 'puppet/idrac/util'
require 'nokogiri'
require 'erb'
require 'tempfile'

Puppet::Type.type(:idrac_fw_installfromuri).provide(:wsman) do
  IDRAC_ID = 25227
  LC_ID = 28897
  UEFI_DIAGNOSTICS_ID = 25806

  def exists?
    @force_restart = resource[:force_restart]
    @firmwares = resource[:idrac_firmware]
    false
  end

  def create
    clear_out_jobqueue
    sleep 20
    pre = []
    main = []
    post = []
    @firmwares.each do |firmware|
    Puppet.debug(firmware)
      if firmware["component_id"].to_i == LC_ID
        pre << firmware
      elsif firmware["component_id"].to_i == IDRAC_ID
        post << firmware
      else
        main << firmware
      end
    end
    if pre.size > 0
      Puppet.debug("LC Update required, installing first")
      update(pre)
    end
    update(main)
    if post.size > 0
      Puppet.debug("IDRAC update required, installing last")
      update(post)
    end
  end
      
  def update(firmware_list)
    job_ids = []
    statuses = {}
    firmware_list.each do |fw|
      Puppet.debug(fw)
      config_file_path = create_xml_config_file(fw["instance_id"],fw["uri_path"])
      job_id = install_from_uri(config_file_path)
      if fw["component_id"].to_s !~ /#{UEFI_DIAGNOSTICS_ID}|#{LC_ID}|#{IDRAC_ID}/
        job_ids << job_id
      end
      remove_config_file(config_file_path)
      job_status = 'new'
      until job_status =~ /Downloaded|Completed|Failed/
        sleep 30
        job_status = get_job_status(job_id)
        statuses[job_id] = job_status
        Puppet.debug("Job Status: #{job_status}")
      end
      if job_status ==  "Completed"
        Puppet.debug("Firmware update completed successfully")
      elsif job_status  ==  "Failed"
        raise Puppet::Error, "Firmware update failed in the lifecycle controller.  Please refer to LifeCycle job logs"
      elsif job_status ==  "Downloaded"
        Puppet.debug("Firmware downloaded to idrac, scheduling apply")
      end
    end
    components = []
    firmware_list.each do |f|
      components << f["component_id"]
    end
    reboot_required = true
    if components.all? {|c| c.to_s =~ /#{UEFI_DIAGNOSTICS_ID}|#{LC_ID}|#{IDRAC_ID}/}
      Puppet.debug("Reboot not required")
      reboot_required = false
      update_complete = 'Completed'
    end
    if !update_complete
      update_complete = @force_restart ? 'Completed' :  'Scheduled'
    end
    reboot_id = nil
    if reboot_required
      if @force_restart
        reboot_config_file_path = create_reboot_config_file
        reboot_id = create_reboot_job(reboot_config_file_path)
      end
      job_queue_config_file = create_job_queue_config(job_ids,reboot_id)
      setup_job_queue(job_queue_config_file)
      if @force_restart
        reboot_status = 'new'
        until reboot_status == 'Reboot Completed'
          sleep 30
          reboot_status = get_job_status(reboot_id)
          Puppet.debug("Reboot Status: #{reboot_status}")
        end
      end
    end
    until statuses.all? {|k,v| v =~ /#{update_complete}|Failed/}
      statuses.each do |key,val|
        job_status = get_job_status(key)
        statuses[key] = job_status
        Puppet.debug("Job Status #{key}: #{val}")
      end
      sleep 30
    end
    if statuses.values.include? "Failed"
      raise Puppet::Error, "Firmware update failed in the lifecycle controller.  Please refer to LifeCycle job logs"
    else
      Puppet.debug("Firmware update completed successfully")
    end
  end


  def clear_out_jobqueue
    Puppet.debug("Clearing old job queue")
    wsman_cmd = "wsman invoke -a \"DeleteJobQueue\" http://schemas.dell.com/wbem/wscim/1/cim-schema/2/DCIM_JobService?CreationClassName=\"DCIM_JobService\",SystemName=\"Idrac\",Name=\"JobService\",SystemCreationClassName=\"DCIM_ComputerSystem\" -N root/dcim -u #{transport[:user]} -p #{transport[:password]} -h #{transport[:host]} -P 443 -v -j utf-8 -y basic -o -m 256 -c Dummy -V  -k \"JobID=JID_CLEARALL\""
    resp = run_wsman(wsman_cmd)
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
    api_status = 'busy'
    until api_status == 'ready'
      api_status = get_api_status
    end
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
      elsif resp.include? 'TimedOut'
        Puppetd.debug("WSMAN API timed out, retrying after sleep")
        sleep sleeptime
        sleeptime += 30
      else
        Puppet.debug("WSMAN RESPONSE:  #{resp}")
        return resp.encode('utf-8', 'binary', :invalid => :replace, :undef => :replace)
      end
    end
    raise Puppet::Error, "Could not connect connect to wsman endpoint"
  end

  def install_from_uri(config_file_path)
    wsman_cmd = "wsman invoke -a InstallFromURI http://schemas.dmtf.org/wbem/wscim/1/cim-schema/2/root/dcim/DCIM_SoftwareInstallationService?CreationClassName=DCIM_SoftwareInstallationService,SystemCreationClassName=DCIM_ComputerSystem,SystemName=IDRAC:ID,Name=SoftwareUpdate -h #{transport[:host]} -V -v -c Dummy -P 443 -u #{transport[:user]} -p #{transport[:password]} -J #{config_file_path} -j utf-8 -y basic"
    resp = run_wsman(wsman_cmd)
    doc = Nokogiri::XML(resp)
    if doc.xpath('//n1:ReturnValue').text == '4096'
      job_id = doc.xpath('//wsman:Selector').first.text
      Puppet.debug("InstallFromURI started")
      Puppet.debug("JOB_ID: #{job_id}")
      return job_id
    else
      raise Puppet::Error, "Problem running InstallFromURI: #{doc.xpath('//n1:Message')}"
    end
  end
  
  def create_xml_config_file(instance_id,path)
    template = <<-EOF
<p:InstallFromURI_INPUT xmlns:p="http://schemas.dmtf.org/wbem/wscim/1/cim-schema/2/root/dcim/DCIM_SoftwareInstallationService">
<p:URI><%= path %></p:URI>
<p:Target xmlns:a="http://schemas.xmlsoap.org/ws/2004/08/addressing" xmlns:w="http://schemas.dmtf.org/wbem/wsman/1/wsman.xsd">
<a:Address>http://schemas.xmlsoap.org/ws/2004/08/addressing/role/anonymous</a:Address>
<a:ReferenceParameters>
<w:ResourceURI>http://schemas.dell.com/wbem/wscim/1/cim-schema/2/DCIM_SoftwareIdentity</w:ResourceURI>
<w:SelectorSet>
<w:Selector Name="InstanceID"><%= instance_id %></w:Selector>
</w:SelectorSet> </a:ReferenceParameters> </p:Target> </p:InstallFromURI_INPUT>
    EOF
    xmlout = ERB.new(template)
    temp_file = Tempfile.new('xml_config')
    temp_file.write(xmlout.result(binding))
    temp_file.close
    temp_file.path
  end

  def create_reboot_config_file
    template = <<-EOF
<p:CreateRebootJob_INPUT xmlns:p="http://schemas.dmtf.org/wbem/wscim/1/cim-schema/2/root/dcim/DCIM_SoftwareInstallationService">
  <p:RebootJobType>3</p:RebootJobType>
</p:CreateRebootJob_INPUT>
EOF
    temp_file = Tempfile.new('reboot_config')
    temp_file.write(template)
    temp_file.close
    temp_file.path
  end

  def create_job_queue_config(job_ids,reboot_id=nil)
    template = <<-EOF
<p:SetupJobQueue_INPUT xmlns:p="http://schemas.dell.com/wbem/wscim/1/cim-schema/2/DCIM_JobService"><% job_ids.each do |job_id| %>
<p:JobArray><%= job_id %></p:JobArray><% end %><% if reboot_id %>
<p:JobArray><%= reboot_id %></p:JobArray><% end %>
<p:RunMonth>6</p:RunMonth>
  <p:RunDay>18</p:RunDay>
<p:StartTimeInterval>TIME_NOW</p:StartTimeInterval>
</p:SetupJobQueue_INPUT>
EOF
    xmlout = ERB.new(template)
    temp_file = Tempfile.new('jq_config')
    temp_file.write(xmlout.result(binding))
    temp_file.close
    temp_file.path
  end

  def get_job_status(id)
    wsman_cmd = "wsman get http://schemas.dell.com/wbem/wscim/1/cim-schema/2/DCIM_LifecycleJob?InstanceID=\"#{id}\" -N root/dcim -u #{transport[:user]} -p #{transport[:password]} -h #{transport[:host]} -P 443 -v -j utf-8 -y basic -o -m 256 -c Dummy -V"
    resp = run_wsman(wsman_cmd)
    doc = Nokogiri::XML(resp)
    status = doc.xpath('//n1:JobStatus').text
    status
  end

  def create_reboot_job(reboot_file)
    wsman_cmd = "wsman invoke -a CreateRebootJob http://schemas.dmtf.org/wbem/wscim/1/cim-schema/2/root/dcim/DCIM_SoftwareInstallationService?CreationClassName=DCIM_SoftwareInstallationService,SystemCreationClassName=DCIM_ComputerSystem,SystemName=IDRAC:ID,Name=SoftwareUpdate -h #{transport[:host]} -V -v -c Dummy -P 443 -u #{transport[:user]} -p #{transport[:password]} -J #{reboot_file} -j utf-8 -y basic"
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
    FileUtils.rm(config_file_path)
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

  def get_api_status
    try = 0
    Puppet.debug("Checking API Status")
    wsman_cmd = "wsman invoke -a GetRemoteServicesAPIStatus http://schemas.dmtf.org/wbem/wscim/1/cim-schema/2/root/dcim/DCIM_LCService?SystemCreationClassName=\"DCIM_ComputerSystem\",CreationClassName=\"DCIM_LCService\",SystemName=\"DCIM:ComputerSystem\",Name=\"DCIM:LCService\" -u #{transport[:user]} -p #{transport[:password]} -h #{transport[:host]} -P 443 -v -y basic -c Dummy -V"
    begin
      try += 1
      resp = %x[ #{wsman_cmd} ]
      doc = Nokogiri::XML(resp)
      if doc.xpath('//n1:LCStatus').text == "0"
        Puppet.debug("API Ready")
        return "ready"
      else
        Puppet.debug("API Not Ready, checking again in 30 seconds")
        sleep 30
        return "busy"
      end
    rescue
      if try > 9
        raise Puppet::Error, "Error getting API Status"
      else
        Puppet.debug("API Status check error, retrying in 30 seconds")
        sleep 30
        retry
      end
    end
  end

    
end

