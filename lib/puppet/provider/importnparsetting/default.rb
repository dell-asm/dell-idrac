provider_path = Pathname.new(__FILE__).parent.parent
require 'rexml/document'

include REXML
require File.join(provider_path, 'idrac')

Puppet::Type.type(:importnparsetting).provide(
  :importnparsetting,
  :parent => Puppet::Provider::Idrac
) do
  desc "Dell idrac provider for  nic partitioning."

  def create
    requiredstatus = resource[:status]
    targetnic = resource[:nic]

    xmlfilePath = File.join(Pathname.new(__FILE__).parent.parent.parent.parent.parent, 'files/defaultxmls/nparsetting.xml')
    file = File.new(xmlfilePath)
    xmldoc = Document.new(file)

    xmldoc.elements.each("SystemConfiguration/Component") do |e|
      e.attributes["FQDD"] = "#{targetnic}"
    end

    xmldoc.elements.each("SystemConfiguration/Component/Attribute") do |e|
      if e.attributes["Name"] == "NicPartitioning"
        e.text = requiredstatus
      end
    end

    nparsettingfilename = "nparsetting_#{transport[:host]}.xml"
    nparsettingfilepath = "#{resource[:nfssharepath]}/#{nparsettingfilename}"
    file = File.open("#{nparsettingfilepath}", "w")
    xmldoc.write(file)
    file.close

    #Import System Configuration
    instanceid = importtemplate nparsettingfilename
    Puppet.info "Instance id #{instanceid}"
    for i in 0..30
      response = checkjobstatus instanceid
      Puppet.info "JD status : #{response}"
      if response  == "Completed"
        Puppet.info "Import NPAR settings is completed."
        break
      else
        if response  == "Running"
          Puppet.info "Job is running, wait for 1 minute"
          sleep 60
        else
          raise "Failed to apply NPAR settings configuration."
        end
      end
    end
    if response != "Completed"
      raise "Import NPAR Settings is still running."
    end
    File.delete("#{nparsettingfilepath}")
  end

end
