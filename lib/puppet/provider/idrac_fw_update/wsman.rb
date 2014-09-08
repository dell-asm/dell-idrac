require 'asm/util'
require 'uri'
require 'puppet/idrac/util'
require 'net/ssh'
require 'nokogiri'
require 'active_support'

Puppet::Type.type(:idrac_fw_update).provide(:wsman) do

  def exists?
    @path = resource[:path]
    @asm_hostname = resource[:asm_hostname]
    @restart = resource[:force_restart]
    updates_available = check_for_update
    if !updates_available
      create
    end
  end


  def check_for_update
    wsman_cmd =  "wsman invoke -a 'InstallFromRepository' http://schemas.dell.com/wbem/wscim/1/cim-schema/2/root/dcim/DCIM_SoftwareInstallationService?CreationClassName=DCIM_SoftwareInstallationService+SystemCreationClassName=DCIM_ComputerSystem+SystemName=IDRAC:ID+Name=SoftwareUpdate -h #{transport[:host]} -P 443 -u #{transport[:user]} -p #{transport[:password]} -c Dummy -y basic -V -v -k \"ipaddress=#{@asm_hostname}\" -k \"sharename=/var/nfs\" -k \"sharetype=0\" -k \"RebootNeeded=#{@restart}\" -k \"ApplyUpdate=0\""
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

  def run_wsman(cmd)
    i = 0
    until i == 3
      resp = %x[#{cmd}]
      if resp.length == 0
        sleep 30
      elsif i == 3
        Puppet.error("Could not connect connect to wsman enpoint")
      else
        return resp
      end
    end
  end

  def parse_for_updates
    #Returns true when there is no updates to be installed
    wsman_cmd = "wsman invoke -a \"GetRepoBasedUpdateList\" http://schemas.dell.com/wbem/wscim/1/cim-schema/2/root/dcim/DCIM_SoftwareInstallationService?CreationClassName=DCIM_SoftwareInstallationService+SystemCreationClassName=DCIM_ComputerSystem+SystemName=IDRAC:ID+Name=SoftwareUpdate   -h #{transport[:host]} -u #{transport[:user]} -p #{transport[:password]} -P 443 -c Dummy -y basic -V -v"
    resp = run_wsman(wsman_cmd)
    doc = Nokogiri::XML(resp)
    if doc.xpath('//n1:ReturnValue').text == '2'
      if doc.xpath('//n1:MessageID').text == 'SUP029'
        Puppet.debug doc.xpath('//n1:Message').text
        return true
      else
        raise Puppet::Error, doc.xpath('//n1:Message').text
      end
    else
      return show_available_updates(doc)
    end
  end


  def show_available_updates(doc)
    out = doc.xpath('//n1:PackageList')
    $updates = []
    switch = false
    out.first.to_s.each_line do |ln|
      if ln.include? "DisplayName"
        switch = true
      elsif switch
        $updates << ln.split(/&lt;\/?VALUE&gt;/).join
        switch = false
      else
        switch = false
      end
    end
    $updates.each do |update|
      Puppet.debug("Firmware update available for: #{update}")
    end
    false
  end

  def create
    Puppet.debug('ABOUT TO APPLY FIRMWARE UPDATES')
    wsman_cmd =  "wsman invoke -a 'InstallFromRepository' http://schemas.dell.com/wbem/wscim/1/cim-schema/2/root/dcim/DCIM_SoftwareInstallationService?CreationClassName=DCIM_SoftwareInstallationService+SystemCreationClassName=DCIM_ComputerSystem+SystemName=IDRAC:ID+Name=SoftwareUpdate -h #{transport[:host]} -P 443 -u #{transport[:user]} -p #{transport[:password]} -c Dummy -y basic -V -v -k \"ipaddress=#{@asm_hostname}\" -k \"sharename=/var/nfs\" -k \"sharetype=0\" -k \"RebootNeeded=#{@restart}\" -k \"ApplyUpdate=1\""
    Puppet.debug("Running command: #{wsman_cmd}")
    resp = run_wsman(wsman_cmd)
    Puppet.debug("WSMAN RESPONSE: #{resp}")
    doc = Nokogiri::XML(resp)
    if doc.xpath('//n1:ReturnValue').text == '4096'
      job_id = doc.xpath('//wsman:Selector').first.text
      Puppet.debug("Firmware update job started successfully")
      Puppet.debug("Job ID: #{job_id}")
      sleep 20
      finished = false
      until finished
        finished = get_update_logs(job_id)
      end
    end
  end

  def get_update_logs(job_id)
    #What updates are we tracking?
    status = {}
    looking_for = []
    $updates.each do |u|
      if u.match(/Integrated Dell Remote/i)
        looking_for << '#iDRAC'
        status['#iDRAC'] = 'unknown'
      elsif u.match(/BIOS/i)
        looking_for << 'BIOS'
        status['BIOS'] = 'unknown'
      elsif u.match(/Lifecycle Controller/i)
        looking_for << 'LC.Embedded'
        status['LC.Embedded'] = 'unknown'
      end
    end
    data = get_data(job_id)
    data.values.each do |value|
      looking_for.any? do |l|
        if value["Name"] =~ /#{l}/
          status[l] = value["JobStatus"]
        end
      end
    end
    if status.values.all? {|v| v =~ /Completed|Failed/ }
      Puppet.debug(status)
      return true
    else
      Puppet.debug(status)
      sleep 30
      return false
    end
  end


  def get_data(job_id)
    wsman_cmd = "wsman enumerate \"http://schemas.dmtf.org/wbem/wscim/1/cim-schema/2/root/dcim/DCIM_LifecycleJob\" -h #{transport[:host]} -V -v -c Dummy -P 443 -u #{transport[:user]} -p #{transport[:password]} -j utf-8 -y basic -V -v"
    resp = run_wsman(wsman_cmd)
    header =  "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n"
    bucket = []
    bucket << header
    bucket << "<Logs>\n"
    resp.each_line do |line|
      if !line.include? '<?xml version="1.0" encoding="UTF-8"?>'
        bucket << line
      end
    end
    bucket << '</Logs>'
    all = bucket.join
    doc = Nokogiri::XML(all)
    hash = Hash.from_xml(doc.to_s)

    envelopes = hash["Logs"]["Envelope"]
    data = {}
    envelopes.each do |e|
      if e["Body"]["PullResponse"]
        response = e["Body"]["PullResponse"]
        info = response["Items"]["DCIM_LifecycleJob"]
        data[info["InstanceID"]] = {
          "JobStatus"       => info["JobStatus"],
          "Message"         => info["Message"],
          "Name"            => info["Name"],
          "PercentComplete" => info["PercentComplete"] }
      end
    end
    #Get only the job events for this run
    data.keys.each do |jid|
      if jid == job_id
        break
      else
        data.delete(jid)
      end
    end
    data
  end

end
