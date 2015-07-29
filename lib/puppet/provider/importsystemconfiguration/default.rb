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
    new_file = File.join(resource[:nfssharepath], "#{resource[:servicetag]}_base.xml")
    original_file = File.join(resource[:nfssharepath], "#{resource[:servicetag]}_original.xml")
    FileUtils.cp(original_file, new_file)
    import_main_config
  end

  def teardown
    import_main_config
  end

  def import_main_config
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
    Puppet::Idrac::Util.wait_for_running_jobs
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
        if attempts == 2
          Puppet.info("Resetting the iDRAC before performing any other operation")
          reset
          Puppet.info("Waiting for Lifecycle Controller to be ready")
          lcstatus
          clear_job_queue
          reboot
          lcstatus
          exporttemplate('base')
          synced = !resource[:force_reboot] && config_in_sync?('base')
          if synced
            Puppet.info("Configuration is already in sync. Skipping the retry on ImportSystemConfiguration")
            return
          end
          retry
        end
      else
        raise "ImportSystemConfiguration job failed"
      end
    rescue Exception => e
      raise e
    end
  end

  #TODO:  Similar code to idrac_fw_update.  Could be moved to somewhere both places can use.
  def clear_job_queue
    Puppet.debug("Clearing Job Queue")
    tries = 1
    begin
      endpoint={:host => transport[:host], :user => transport[:user], :password => transport[:password]}
      schema = "http://schemas.dell.com/wbem/wscim/1/cim-schema/2/DCIM_JobService?CreationClassName=\"DCIM_JobService\",SystemName=\"Idrac\",Name=\"JobService\",SystemCreationClassName=\"DCIM_ComputerSystem\""
      options = {:props=>{'JobID'=> 'JID_CLEARALL'}, :selector => '//n1:ReturnValue', :logger => Puppet}
      resp = ASM::WsMan.invoke(endpoint, 'DeleteJobQueue', schema, options)
      if resp == '0'
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
