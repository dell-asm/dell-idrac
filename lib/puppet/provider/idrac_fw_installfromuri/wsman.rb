provider_path = Pathname.new(__FILE__).parent.parent
require 'puppet/idrac/util'
require 'nokogiri'
require 'erb'
require 'tempfile'
require 'asm/util'
require File.join(provider_path, 'idrac')

Puppet::Type.type(:idrac_fw_installfromuri).provide(
  :wsman,
  :parent => Puppet::Provider::Idrac
) do
  # Special component ids
  IDRAC_ID = 25227
  LC_ID = 28897
  UEFI_DIAGNOSTICS_ID = 25806
  DRIVER_PACK = 18981

  # Component ids that do not require a reboot
  NO_REBOOT_COMPONENT_IDS = [IDRAC_ID, LC_ID, UEFI_DIAGNOSTICS_ID, DRIVER_PACK]

  # Max time to wait for a job to complete
  MAX_WAIT_SECONDS = 1800


  def exists?
    @force_restart = resource[:force_restart]
    @firmwares = ASM::Util.asm_json_array(resource[:idrac_firmware])
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

      # idrac restarts after the firmware is installed. Sleep for a minute to
      # ensure that is underway before we check for LC ready below.
      sleep(60)
    end

    # Ensure LC is up and in good state before exiting
    wait_for_lc_ready
  end

  def update(firmware_list)
    statuses = {}

    # Initiate all firmware update jobs
    firmware_list.each do |fw|
      Puppet.debug(fw)
      config_file = create_xml_config_file(fw["instance_id"],fw["uri_path"])
      job_id = install_from_uri(config_file)
      raise(Puppet::Error, "Failed to initiate firmware job for #{fw}") unless job_id
      raise(Puppet::Error, "Duplicate job id #{job_id} for firmware #{fw}: #{statuses[job_id]}") if statuses[job_id]
      statuses[job_id] = { :job_id => job_id, :status => 'new', :firmware => fw, :start_time => Time.now }
      until statuses[job_id][:status] =~ /Downloaded|Completed|Failed/
        sleep 30
        begin
          statuses[job_id][:status] = checkjobstatus job_id
        rescue ASM::WsMan::Error => e
          statuses[job_id][:status] = 'TemporaryFailure'
          Puppet.warning("Look up job status for #{job_id} failed: #{e}")
        end
        Puppet.debug("Job Status: #{statuses[job_id][:status]}")
        if Time.now - statuses[job_id][:start_time] > MAX_WAIT_SECONDS
          Puppet.warning("Timed out waiting for firmware job #{job_id} to complete")
          statuses[job_id][:status] = 'Failed'
        end
      end
      if statuses[job_id][:status] ==  "Completed"
        Puppet.debug("Firmware update completed successfully")
      elsif statuses[job_id][:status]  ==  "Failed"
        raise Puppet::Error, "Firmware update failed in the lifecycle controller.  Please refer to LifeCycle job logs"
      elsif statuses[job_id][:status] ==  "Downloaded"
        Puppet.debug("Firmware downloaded to idrac, scheduling apply")
      end
    end

    # Reboot if necessary
    reboot_job_ids = statuses.values.map do |v|
      v[:job_id] unless NO_REBOOT_COMPONENT_IDS.include?(v[:firmware]['component_id'].to_i)
    end.compact
    if reboot_job_ids.empty?
      Puppet.debug("Reboot not required")
      reboot_required = false
      update_complete = 'Completed'
    else
      reboot_required = true
      update_complete = @force_restart ? 'Completed' : 'Scheduled'
    end
    reboot_id = nil
    if reboot_required
      if @force_restart
        reboot_config_file = create_reboot_config_file
        reboot_id = create_reboot_job(reboot_config_file)
      end
      job_queue_config_file = create_job_queue_config(reboot_job_ids,reboot_id)
      setup_job_queue(job_queue_config_file)
      if @force_restart
        reboot_status = 'new'
        until reboot_status == 'Reboot Completed'
          sleep 30
          reboot_status = checkjobstatus reboot_id
          Puppet.debug("Reboot Status: #{reboot_status}")
        end
      end
    end

    # Poll for all jobs to complete or time out
    until statuses.values.all? { |v| v[:status] =~ /#{update_complete}|Failed|InternalTimeout/ }
      statuses.each do |key, val|
        if Time.now - val[:start_time] > MAX_WAIT_SECONDS
          val[:status] = 'InternalTimeout'
        else
          val[:status] = checkjobstatus key
          Puppet.debug("Job Status #{key}: #{val[:status]}")
        end
      end
      sleep 30
    end

    # Raise an error if any firmware jobs failed
    failures = statuses.values.find_all { |v| v[:status] =~ /Failed|InternalTimeout/ }
    if failures.empty?
      Puppet.debug("Firmware update completed successfully")
    else
      Puppet.info("Failed firmware jobs: #{failures}")
      raise Puppet::Error, "Firmware update failed in the lifecycle controller.  Please refer to LifeCycle job logs"
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
    wait_for_lc_ready
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

  def install_from_uri(config_file)
    config_file_path = config_file.path
    wsman_cmd = "wsman invoke -a InstallFromURI http://schemas.dmtf.org/wbem/wscim/1/cim-schema/2/root/dcim/DCIM_SoftwareInstallationService?CreationClassName=DCIM_SoftwareInstallationService,SystemCreationClassName=DCIM_ComputerSystem,SystemName=IDRAC:ID,Name=SoftwareUpdate -h #{transport[:host]} -V -v -c Dummy -P 443 -u #{transport[:user]} -p #{transport[:password]} -J #{config_file_path} -j utf-8 -y basic"
    resp = run_wsman(wsman_cmd)
    doc = Nokogiri::XML(resp)
    if doc.xpath('//n1:ReturnValue').text == '4096'
      job_id = doc.xpath('//wsman:Selector').first.text
      Puppet.debug("InstallFromURI started")
      Puppet.debug("JOB_ID: #{job_id}")
      return job_id
    else
      Puppet.debug("Install From URI config: #{config_file.read}")
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
    temp_file
  end

  def create_reboot_config_file
    template = <<-EOF
<p:CreateRebootJob_INPUT xmlns:p="http://schemas.dmtf.org/wbem/wscim/1/cim-schema/2/root/dcim/DCIM_SoftwareInstallationService">
  <p:RebootJobType>1</p:RebootJobType>
</p:CreateRebootJob_INPUT>
EOF
    temp_file = Tempfile.new('reboot_config')
    temp_file.write(template)
    temp_file.close
    temp_file
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
    temp_file
  end

  def create_reboot_job(reboot_file)
    wsman_cmd = "wsman invoke -a CreateRebootJob http://schemas.dmtf.org/wbem/wscim/1/cim-schema/2/root/dcim/DCIM_SoftwareInstallationService?CreationClassName=DCIM_SoftwareInstallationService,SystemCreationClassName=DCIM_ComputerSystem,SystemName=IDRAC:ID,Name=SoftwareUpdate -h #{transport[:host]} -V -v -c Dummy -P 443 -u #{transport[:user]} -p #{transport[:password]} -J #{reboot_file.path} -j utf-8 -y basic"
    Puppet.debug("Creating Reboot Job")
    resp = run_wsman(wsman_cmd)
    doc = Nokogiri::XML(resp)
    if doc.xpath('//n1:ReturnValue').text == '4096'
      reboot_id = doc.xpath('//wsman:Selector').first.text
      Puppet.debug("Reboot Job scheduled successfully")
      Puppet.debug("Reboot Job ID: #{reboot_id}")
      return reboot_id
    else
      Puppet.debug("Reboot Job config: #{reboot_file.read}")
      raise Puppet::Error, "Problem scheduling reboot.  Problem message: #{doc.xpath('//n1:Message').text}"
    end
  end

  def setup_job_queue(job_queue_config_file)
    wsman_cmd = "wsman invoke -a SetupJobQueue http://schemas.dell.com/wbem/wscim/1/cim-schema/2/DCIM_JobService?CreationClassName=\"DCIM_JobService\",SystemName=\"Idrac\",Name=\"JobService\",SystemCreationClassName=\"DCIM_ComputerSystem\" -N root/dcim -u #{transport[:user]} -p #{transport[:password]} -h #{transport[:host]} -P 443 -v -j utf-8 -y basic -o -m 256 -c Dummy -V -J #{job_queue_config_file.path}"
    Puppet.debug("Setting up Job Queue")
    4.times do |t|
      resp = run_wsman(wsman_cmd)
      doc = Nokogiri::XML(resp)
      if doc.xpath('//n1:ReturnValue').text == '0'
        Puppet.debug("Job Queue created successfully")
        break
      else
        if t < 3
          Puppet.debug('Error scheduling Job Queue.  ..retrying')
          sleep 10
        else
          Puppet.debug("Job Queue config: #{job_queue_config_file.read}")
          raise Puppet::Error, "Problem scheduling the job queue.  Message: #{doc.xpath('//n1:Message').text}"
        end
      end
    end
  end


end
