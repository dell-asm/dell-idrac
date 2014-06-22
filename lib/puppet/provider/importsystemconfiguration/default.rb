provider_path = Pathname.new(__FILE__).parent.parent
require 'rexml/document'

include REXML
require File.join(provider_path, 'idrac')

Puppet::Type.type(:importsystemconfiguration).provide(
  :importsystemconfiguration,
  :parent => Puppet::Provider::Idrac
) do
  desc "Dell idrac provider for import system configuration."

  def create
    import_try = 1
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
    if response != "Completed"
      raise "Import System Configuration is still running."
    end
  end
  
  def retry_import
    Puppet.debug("Import operation failed in the first attempt, retrying import operation")
    Puppet.debug("Resetting the iDRAC before performing any other operation")
    reset
    Puppet.debug("Waiting for Lifecycle Controller be ready")
    lcstatus
    reboot
    lcstatus
    exporttemplate
    
    synced = !resource[:force_reboot] && config_in_sync?
    if synced
      Puppet.debug("Configuration are already in synced, skipping the import operation")
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
