provider_path = Pathname.new(__FILE__).parent.parent
require 'rexml/document'
require 'puppet/idrac/util'
require 'asm/wsman'

include REXML
require File.join(provider_path, 'idrac')

Puppet::Type.type(:importsystemconfiguration).provide(
  :importsystemconfiguration,
  :parent => Puppet::Provider::Idrac
) do
  desc "Dell idrac provider for import system configuration."

  def create
    instance_id = setup_idrac
    wait_for_import(instance_id) if instance_id
    import_config
  end

  def teardown
    import_config
  end

  def import_config
    exporttemplate('base')
    instance_id = importtemplate
    wait_for_import(instance_id)

    # For config XML case, its observed that we have to invoke the import
    # operation twice as a workaround for fcoe not being toggled when the partition has iscsi offload enabled.
    # TODO:  Move flipping the fcoeEnabled attribute into the setup_idrac flow
    unless @resource[:config_xml].nil?
      Puppet.info('For referenced server configuration, need to perform the configuration XML twice')
      sleep(60)
      retry_import(true)
    end
    disks_ready = false
    Puppet.info('Checking for virtual disks to be out of any running operation...')
    for j in 0..30
      disks_ready = Puppet::Idrac::Util.virtual_disks_ready?
      if(disks_ready)
        break
      else
        sleep 60
      end
    end
    if !disks_ready
      raise 'Virtual disk(s) currently busy.'
    end
  end

  def wait_for_import(instance_id, is_retry=false)
    import_try = 1
    Puppet.info "Instance id #{instance_id}"
    for i in 0..30
      response = checkjobstatus instance_id
      Puppet.info "JD status : #{response}"
      if response  == "Completed"
        Puppet.info "Import System Configuration is completed."
        break
      else
        if response  == "Failed"
          if import_try == 1 && !is_retry
            Puppet.info("Import operation failed in the first attempt, retrying import operation")
            return retry_import
          else
            raise "Job Failed ."
          end
        else
          Puppet.info "Job is running, wait for 1 minute"
          sleep 60
        end
      end
    end
    if response != "Completed"
      raise "Import System Configuration is still running."
    end
  end

  def retry_import(skip_reset=false)
    unless skip_reset
      Puppet.info("Resetting the iDRAC before performing any other operation")
      reset
      Puppet.info("Waiting for Lifecycle Controller be ready")
      lcstatus
      clear_job_queue
      reboot
      lcstatus
    end
    exporttemplate('base')

    synced = !resource[:force_reboot] && config_in_sync?
    if synced
      Puppet.info("Configuration is already in sync. Skipping the import operation")
      return true
    end
    instanceid = importtemplate
    wait_for_import(instanceid, true)
  end

  #TODO:  Similar code to idrac_fw_update.  Could be moved to somewhere both places can use.
  def clear_job_queue
    Puppet.debug("Clearing Job Queue")
    tries = 1
    begin
      endpoint={:host => transport[:host], :user => transport[:user], :password => transport[:password]}
      schema = "http://schemas.dell.com/wbem/wscim/1/cim-schema/2/DCIM_JobService?CreationClassName=\"DCIM_JobService\",SystemName=\"Idrac\",Name=\"JobService\",SystemCreationClassName=\"DCIM_ComputerSystem\""
      options = {:props=>{'JobID'=> 'JID_CLEARALL'}}
      resp = ASM::WsMan.invoke(endpoint, 'DeleteJobQueue', schema, options)
      doc = Nokogiri::XML(resp)
      Puppet.debug("Response from DeleteJobQueue: #{doc}")
      if doc.xpath('//n1:ReturnValue').text == '0'
        Puppet.debug("Job Queue cleared successfully")
      else
        raise Puppet::Error, "Error clearing job queue.  Message: #{doc.xpath('//n1:Message')}"
      end
    rescue Puppet::Error => e
      raise e if tries > 4
      tries += 1
      Puppet.info("Could not reset job queue.  Retrying in 30 seconds...")
      sleep 30
      retry
    end
    wait_for_jobs_clear
  end

  def wait_for_jobs_clear
    Puppet.info("Waiting for job queue to be empty...")
    endpoint={:host => transport[:host], :user => transport[:user], :password => transport[:password]}
    schema = "http://schemas.dell.com/wbem/wscim/1/cim-schema/2/DCIM_JobService"
    10.times do
      resp = ASM::WsMan.invoke(endpoint, 'enumerate', schema)
      doc = Nokogiri::XML("<results>#{resp}</results>")
      doc.remove_namespaces!
      Puppet.debug("Response from DCIM_JobService:\n#{doc}")
      if doc.xpath('//CurrentNumberOfJobs').text == '0'
        Puppet.info("Job Queue is empty.")
        return
      else
        sleep 15
      end
    end
    Puppet.warning("Job queue still shows jobs exist.  This could cause issues during import of system config.")
  end
end
