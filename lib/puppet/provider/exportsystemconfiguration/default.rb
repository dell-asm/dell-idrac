provider_path = Pathname.new(__FILE__).parent.parent
require 'rexml/document'

include REXML
require File.join(provider_path, 'idrac')

Puppet::Type.type(:exportsystemconfiguration).provide(
  :exportsystemconfiguration,
  :parent => Puppet::Provider::Idrac
) do
  desc "Dell idrac provider for export system configuration."

  def create
    #Export System Configuration
    instanceid = exporttemplate
    for i in 0..30
      response = checkjobstatus instanceid
      if response  == "Completed"
        Puppet.info "Export System Configuration is completed."
        break
      else
        if response  == "Failed"
          raise "Job Failed."
        else
          Puppet.info "Job is running, wait for 1 minute."
          sleep 60
        end
      end
    end
    if response != "Completed"
      raise "Export System Configuration has not completed."
    end
  end

  def sleep_time
    5
  end

end

