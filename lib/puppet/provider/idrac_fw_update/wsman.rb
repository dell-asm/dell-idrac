require 'asm/util'
require 'uri'
require 'asm/wsman'
require 'puppet/idrac/util'
require 'net/ssh'
require 'nokogiri'

Puppet::Type.type(:idrac_fw_update).provide(:wsman) do

  
  def exists?
    @path = resource[:path]
    @asm_hostname = resource[:asm_hostname]
    updates_available = check_for_update
    updates_available
  end


  def check_for_update
    wsman_cmd =  "wsman invoke -a 'InstallFromRepository' http://schemas.dell.com/wbem/wscim/1/cim-schema/2/root/dcim/DCIM_SoftwareInstallationService?CreationClassName=DCIM_SoftwareInstallationService+SystemCreationClassName=DCIM_ComputerSystem+SystemName=IDRAC:ID+Name=SoftwareUpdate -h #{transport[:host]} -P 443 -u #{transport[:user]} -p #{transport[:password]} -c Dummy -y basic -V -v -k \"ipaddress=#{@asm_hostname}\" -k \"sharename=/var/nfs\" -k \"sharetype=0\" -k \"RebootNeeded=true\" -k \"ApplyUpdate=0\""
    resp = %x[ #{wsman_cmd} ]
    doc = Nokogiri::XML(resp)
    if doc.xpath('//n1:ReturnValue').text == '4096'
      return parse_for_updates
    else
      raise Puppet::Error, doc.xpath('//n1:Message')
    end
  end

  def transport
    @transport ||= Puppet::Idrac::Util.get_transport()
  end


  def parse_for_updates
    #Returns true when there is no updates to be installed
    wsman_cmd = "wsman invoke -a \"GetRepoBasedUpdateList\" http://schemas.dell.com/wbem/wscim/1/cim-schema/2/root/dcim/DCIM_SoftwareInstallationService?CreationClassName=DCIM_SoftwareInstallationService+SystemCreationClassName=DCIM_ComputerSystem+SystemName=IDRAC:ID+Name=SoftwareUpdate   -h #{transport[:host]} -u #{transport[:user]} -p #{transport[:password]} -P 443 -c Dummy -y basic -V -v"
    resp = %x[ #{wsman_cmd} ]
    doc = Nokogiri::XML(resp)
    if doc.xpath('//n1:ReturnValue').text == '2'
      if doc.xpath('//n1:MessageID').text == 'SUP029'
        Puppet.debug doc.xpath('//n1:Message').text
        return true
      else
        Puppet.debug ("here")
        raise Puppet::Error, doc.xpath('//n1:Message').text
      end
    else
      show_available_updates(doc)
    end
  end


  def show_available_updates(doc)
    out = doc.xpath('//n1:PackageList')
    updates = []
    switch = false
    out.first.to_s.each_line do |ln|
      if ln.include? "DisplayName"
        switch = true
      elsif switch
        updates << ln.split(/&lt;\/?VALUE&gt;/).join
        switch = false
      else
        switch = false
      end
    end
    updates.each do |update|
      Puppet.debug("Firmware update available for: #{update}")
    end
    false
  end

  def create
    Puppet.debug("CREATION BLOCK 8****************************")
  end
end
