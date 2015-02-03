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
    wait_for_import(instance_id)
    #Need to export again so we have a template with updated values from the setup step before.
    exporttemplate('base')
    instance_id = importtemplate
    wait_for_import(instance_id)
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
      raise 'Virtual disk(s) currrently busy.'
    end
  end

  def wait_for_import(instance_id)
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
          if import_try == 1
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
    # For config XML case, its observed that we have to invoke the import
    # operation twice as a workaround.
    # This may no longer be necessary with the initial "setup" import workflow.
    if response == "Completed" and !@resource[:config_xml].nil?
      Puppet.info('For referenced server configuration, need to perform the configuration XML twice')
      sleep(60)
      retry_import(skip_reset=true)
    end
    if response != "Completed"
      raise "Import System Configuration is still running."
    end
  end

  def retry_import(skip_reset=false)
    Puppet.debug("Import operation failed in the first attempt, retrying import operation")
    Puppet.debug("Resetting the iDRAC before performing any other operation")
    reset if !skip_reset
    Puppet.debug("Waiting for Lifecycle Controller be ready")
    lcstatus
    reboot if !skip_reset
    lcstatus
    exporttemplate('base')

    synced = !resource[:force_reboot] && config_in_sync?
    if synced
      Puppet.debug("Configuration is already in sync. Skipping the import operation")
      return true
    end

    instanceid = importtemplate
    Puppet.info "Instance id #{instanceid}"
    for i in 0..30
      response = checkjobstatus instanceid
      Puppet.info "JD status : #{response}"
      if response  == "Completed"
        Puppet.info "Import System Configuration is completed."
        break
      else
        if response  == "Failed"
          raise "Job Failed ."
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

  def sleep_time
    5
  end
end
