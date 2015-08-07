provider_path = Pathname.new(__FILE__).parent.parent
require 'rexml/document'
require 'puppet/idrac/util'
require 'asm/wsman'
require 'fileutils'

include REXML
require File.join(provider_path, 'idrac')

Puppet::Type.type(:importsystemconfiguration).provide(
  :importsystemconfiguration,
  :parent => Puppet::Provider::Idrac
) do
  desc "Dell idrac provider for import system configuration."

  def create
    import_main_config
  end

  def teardown
    import_main_config
  end

  def import_main_config
    new_file = File.join(resource[:nfssharepath], "#{resource[:servicetag]}_base.xml")
    original_file = File.join(resource[:nfssharepath], "#{resource[:servicetag]}_original.xml")
    FileUtils.cp(original_file, new_file)
    importtemplate
    disks_ready = false
    Puppet.info('Checking for virtual disks to be out of any running operation...')
    for j in 0..30
      disks_ready = Puppet::Idrac::Util.virtual_disks_ready?
      if disks_ready
        break
      else
        sleep 60
      end
    end
    unless disks_ready
      raise 'Virtual disk(s) currently busy.'
    end
  end

  def importtemplate
    Puppet::Idrac::Util.wait_or_clear_running_jobs
    obj = Puppet::Provider::Importtemplatexml.new(
        transport[:host],
        transport[:user],
        transport[:password],
        resource,
        'base')
    attempts = 0
    begin
      obj.importtemplatexml
    rescue Puppet::Idrac::ConfigError => e
      attempts += 1
      case attempts
      when 1
        Puppet.info("First import failed.  Retrying import....")
        retry
      when 2
        Puppet.info("Resetting the iDRAC before performing any other operation")
        Puppet::Idrac::Util.reset
        Puppet.info("Waiting for Lifecycle Controller to be ready")
        Puppet::Idrac::Util.lcstatus
        Puppet::Idrac::Util.clear_job_queue
        reboot
        Puppet::Idrac::Util.lcstatus
        exporttemplate('base')
        synced = !resource[:force_reboot] && config_in_sync?('base')
        if synced
          Puppet.info("Configuration is already in sync. Skipping the retry on ImportSystemConfiguration")
          return
        end
        retry
      else
        raise "ImportSystemConfiguration job failed"
      end
    rescue Exception => e
      raise e
    end
  end
end


