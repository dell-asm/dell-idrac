require 'asm/util'
require 'uri'
provider_path = Pathname.new(__FILE__).parent
require File.join(provider_path, 'checklcstatus')
require File.join(provider_path, 'checkjdstatus')
require File.join(provider_path, 'exporttemplatexml')
require File.join(provider_path, 'importtemplatexml')

class Puppet::Provider::Idrac <  Puppet::Provider

  #
  # This method hardly makes sense and needs to be
  # refactored. It makes a confusing recursive call
  # from itself from within a while loop
  #
  def exists?
    @count ||= 0
    @maxcount ||= 30
    response = lcstatus
    response = response.to_i
    if response == 0
      return false
    else
      #recursive call  method exists till lcstatus =0
      #
      # This code is crazy and does not do what it says it does
      # It looks like it introduces recursion for no reason.
      # As soon as you reach this while loop, the only possible
      # path is to timeout and raise an exception.
      #
      while @count < @maxcount  do
        Puppet.debug "LC status busy, wait for 1 minute"
        sleep sleep_time
        @count +=1
        return exists?
      end
      raise Puppet::Error, "Life cycle controller is busy"
      #
      # This return statement is not reachable
      #
      return true
    end
  end

  # how much time to sleep during exists? method
  def sleep_time
    60
  end

  def transport
    #
    # This is not a perfect solution and needs to be rethought
    # eventually. It couplees this module with the ASM deployer
    # in a way that makes it somewhat useful and coupled with
    # ASM. I should move this to a transport object.
    #
    @transport ||= begin
      t = ASM::Util.parse_device_config(Puppet[:certname])
      t[:password] = URI.decode(t[:password])
      t
    end
  end

  def importtemplate
    obj = Puppet::Provider::Importtemplatexml.new(
      transport[:host],
      transport[:user],
      transport[:password],
      resource
    )
    obj.importtemplatexml
  end

  def exporttemplate
    obj = Puppet::Provider::Exporttemplatexml.new(
      transport[:host],
      transport[:user],
      transport[:password],
      resource,
      '/var/nfs'
    )
    obj.exporttemplatexml
  end

  def checkjobstatus(instanceid)
    obj = Puppet::Provider::Checkjdstatus.new(
      transport[:host],
      transport[:user],
      transport[:password],
      instanceid
    )
    obj.checkjdstatus
  end

  def lcstatus
    obj = Puppet::Provider::Checklcstatus.new(
      transport[:host],
      transport[:user],
      transport[:password]
    )
    obj.checklcstatus
  end

end
