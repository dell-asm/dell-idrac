provider_path = Pathname.new(__FILE__).parent.parent
require 'rexml/document'

include REXML
require File.join(provider_path, 'idrac')
require File.join(provider_path, 'checklcstatus')
require File.join(provider_path, 'checkjdstatus')
require File.join(provider_path, 'importtemplatexml')

Puppet::Type.type(:importsystemconfiguration).provide(
  :importsystemconfiguration,
  :parent => Puppet::Provider::Idrac
) do
  desc "Dell idrac provider for import system configuration."
  $count = 0
  $maxcount = 60

  def create
    instanceid = importtemplate
    Puppet.info "Instance id #{instanceid}"
    for i in $count..$maxcount
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
  
  def checkjobstatus(instanceid)
    obj = Puppet::Provider::Checkjdstatus.new(resource[:dracipaddress],resource[:dracusername],resource[:dracpassword],instanceid)
    response = obj.checkjdstatus
	  return response
  end

  def importtemplate
	  obj = Puppet::Provider::Importtemplatexml.new(resource[:dracipaddress],resource[:dracusername],resource[:dracpassword],resource[:configxmlfilename],resource[:nfsipaddress],resource[:nfssharepath])
    instanceid = obj.importtemplatexml
	  return instanceid
  end

  def lcstatus
    obj = Puppet::Provider::Checklcstatus.new(resource[:dracipaddress],resource[:dracusername],resource[:dracpassword])
    response = obj.checklcstatus
	  return response
  end

  def exists?
	  response = lcstatus
    response = response.to_i
    if response == 0
      return false
    else
      #recursive call  method exists till lcstatus =0
      while $count < $maxcount  do
        Puppet.info "LC status busy, wait for 1 minute"
        sleep 5
        $count +=1
        exists?
      end
      raise Puppet::Error, "Life cycle controller is busy"
      return true
    end
  end
end
