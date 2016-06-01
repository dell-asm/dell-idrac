provider_path = Pathname.new(__FILE__).parent.parent
require 'puppet/idrac/util'
require 'nokogiri'
require 'erb'
require 'tempfile'
require 'asm/util'
require 'asm/wsman'
require 'puppet/idrac/util'
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
  OS_COLLECTOR = 101734

  # Component ids that do not require a reboot (DIRECT UPDATES)
  NO_REBOOT_COMPONENT_IDS = [IDRAC_ID, LC_ID, UEFI_DIAGNOSTICS_ID, DRIVER_PACK, OS_COLLECTOR]

  # Max time to wait for a job to complete
  MAX_WAIT_SECONDS = 1800


  def exists?
    transport # Force initialization, Puppet::Idrac::Util depends on it
    @force_restart = resource[:force_restart]
    @firmwares = ASM::Util.asm_json_array(resource[:idrac_firmware])
    false
  end

  def create
    Puppet::Idrac::Util.clear_job_queue_with_retry
    sleep 20
    pre = []
    main = []
    @firmwares.each do |firmware|
      Puppet.debug(firmware)
      if [LC_ID, IDRAC_ID].include? firmware['component_id'].to_i
        pre << firmware
      else
        main << firmware
      end
    end
    if pre.size > 0
      Puppet.debug("LC Update required, installing first")
      update(pre)
    end
    update(main)
    # Ensure LC is up and in good state before exiting
    Puppet::Idrac::Util.wait_for_lc_ready
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
        Puppet.debug("Firmware downloaded to idrac")
      end
    end

    statuses.each do |_,v|
      if NO_REBOOT_COMPONENT_IDS.include?(v[:firmware]['component_id'].to_i)
        v[:desired] = "Completed"
        v[:reboot_required] = false
      else
        @force_restart ? v[:desired] = "Completed" : v[:desired] = "Scheduled"
        v[:reboot_required] = true
      end
    end

    reboot_firmwares = statuses.select {|_,v| v[:reboot_required]}
    completed_endstate_firmwares = statuses.select {|_,v| v[:desired] == "Completed"}
    scheduled_endstate_firmwares = statuses.select{|_,v| v[:desired] == "Scheduled"}

    unless reboot_firmwares.empty?
      reboot_id = nil
      if @force_restart
        reboot_config_file = create_reboot_config_file
        reboot_id = create_reboot_job(reboot_config_file)
      end
      job_queue_config_file = create_job_queue_config(reboot_firmwares.keys,reboot_id)
      Puppet.debug("#{File.read(job_queue_config_file.path)}")
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

    [scheduled_endstate_firmwares, completed_endstate_firmwares].each do |firmware_set|
      until firmware_set.values.all? {|v| v[:status] =~ /#{v[:desired]}|Failed|InternalTimeout/}
        firmware_set.each do |key, val|
          if Time.now - val[:start_time] > MAX_WAIT_SECONDS
            val[:status] = 'InternalTimeout'
          else
            val[:status] = checkjobstatus key
            Puppet.debug("Job Status #{key}: #{val[:status]}")
          end
        end
        sleep 30
      end
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

  def wsman_client
    @wsman_client ||= ASM::WsMan::Client.new(transport, {:logger => Puppet})
  end

  def install_from_uri(config_file)
    config_file_path = config_file.path
    schema = "http://schemas.dmtf.org/wbem/wscim/1/cim-schema/2/root/dcim/DCIM_SoftwareInstallationService?CreationClassName=DCIM_SoftwareInstallationService,SystemCreationClassName=DCIM_ComputerSystem,SystemName=IDRAC:ID,Name=SoftwareUpdate"
    resp = wsman_client.invoke("InstallFromURI", schema, :input_file => config_file_path)
    if resp[:return_value] == '4096'
      job_id = resp[:job]
      Puppet.debug("InstallFromURI started")
      Puppet.debug("JOB_ID: #{job_id}")
      return job_id
    else
      Puppet.debug("Error installing From URI config: #{config_file.read}")
      raise Puppet::Error, "Problem running InstallFromURI: #{resp[:message]}"
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
    url = "http://schemas.dmtf.org/wbem/wscim/1/cim-schema/2/root/dcim/DCIM_SoftwareInstallationService?CreationClassName=DCIM_SoftwareInstallationService,SystemCreationClassName=DCIM_ComputerSystem,SystemName=IDRAC:ID,Name=SoftwareUpdate"
    Puppet.debug("Creating Reboot Job")
    resp = wsman_client.invoke("CreateRebootJob", url, :input_file => reboot_file.path)
    if resp[:return_value] == '4096'
      reboot_id = resp[:reboot_job_id]
      Puppet.debug("Reboot Job scheduled successfully")
      Puppet.debug("Reboot Job ID: #{reboot_id}")
      return reboot_id
    else
      Puppet.debug("Error with Reboot Job config: #{reboot_file.read}")
      raise Puppet::Error, "Problem scheduling reboot.  Problem message: #{resp[:message]}"
    end
  end

  def setup_job_queue(job_queue_config_file)
    url = "http://schemas.dell.com/wbem/wscim/1/cim-schema/2/DCIM_JobService?CreationClassName=\"DCIM_JobService\",SystemName=\"Idrac\",Name=\"JobService\",SystemCreationClassName=\"DCIM_ComputerSystem\" -N root/dcim"
    Puppet.debug("Setting up Job Queue")
    4.times do |t|
      resp = wsman_client.invoke("SetupJobQueue", url, :input_file => job_queue_config_file.path)
      if resp[:return_value] == '0'
        Puppet.debug("Job Queue created successfully")
        break
      else
        if t < 3
          Puppet.debug('Error scheduling Job Queue.  ..retrying')
          sleep 10
        else
          Puppet.debug("Error Job Queue config: #{File.read(job_queue_config_file.path)}")
          raise Puppet::Error, "Problem scheduling the job queue.  Message: #{resp[:message]}"
        end
      end
    end
  end
end
