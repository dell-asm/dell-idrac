provider_path = Pathname.new(__FILE__).parent.parent
require 'rexml/document'
require 'puppet/idrac/util'

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
    if !@resource[:config_xml].nil?
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
    Puppet.info("Resetting the iDRAC before performing any other operation") unless skip_reset
    reset unless skip_reset
    Puppet.info("Waiting for Lifecycle Controller be ready")
    lcstatus
    reboot unless skip_reset
    lcstatus
    exporttemplate('base')

    synced = !resource[:force_reboot] && config_in_sync?
    if synced
      Puppet.info("Configuration is already in sync. Skipping the import operation")
      return true
    end
    instanceid = importtemplate
    wait_for_import(instanceid, true)
  end

  def sleep_time
    5
  end
end
