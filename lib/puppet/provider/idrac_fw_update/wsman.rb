require 'puppet/idrac/util'
require 'nokogiri'
require 'active_support'

Puppet::Type.type(:idrac_fw_update).provide(:wsman) do

  def exists?
    @share = resource[:path].split('/')[0..-2].join('/')
    @catalog_name = resource[:path].split('/')[-1]
    @asm_hostname = resource[:asm_hostname]
    @restart = resource[:force_restart]
    updates_available = check_for_update
    if !updates_available
      create
    end
  end


  def check_for_update
    wsman_cmd =  "wsman invoke -a 'InstallFromRepository' http://schemas.dell.com/wbem/wscim/1/cim-schema/2/root/dcim/DCIM_SoftwareInstallationService?CreationClassName=DCIM_SoftwareInstallationService+SystemCreationClassName=DCIM_ComputerSystem+SystemName=IDRAC:ID+Name=SoftwareUpdate -h #{transport[:host]} -P 443 -u #{transport[:user]} -p #{transport[:password]} -c Dummy -y basic -V -v -k \"ipaddress=#{@asm_hostname}\" -k \"sharename=#{@share}\" -k \"sharetype=0\" -k \"RebootNeeded=#{@restart}\" -k \"ApplyUpdate=0\" -k \"CatalogName=#{@catalog_name}\""
    resp = run_wsman(wsman_cmd)
    Puppet.debug(resp)
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
    sleeptime = 30
    4.times do
      resp = %x[#{cmd}]
      if resp.length == 0
        Puppet.debug("WSMAN O length response received, retrying after sleep")
        sleep sleeptime
        sleeptime += 30
      elsif resp.include? 'Authentication failed'
        Puppet.debug("WSMAN authentication failed, retrying after sleep")
        sleep sleeptime
        sleeptime += 30
      elsif resp.include? 'Connection failed'
        Puppet.debug("WSMAN connection failed, retrying after sleep")
        sleep sleeptime
        sleeptime += 30
      else
        return resp.encode('utf-8', 'binary', :invalid => :replace, :undef => :replace)
      end
    end
    raise Puppet::Error, "Could not connect connect to wsman endpoint"
  end

  def parse_for_updates
    #Returns true when there is no updates to be installed
    wsman_cmd = "wsman invoke -a \"GetRepoBasedUpdateList\" http://schemas.dell.com/wbem/wscim/1/cim-schema/2/root/dcim/DCIM_SoftwareInstallationService?CreationClassName=DCIM_SoftwareInstallationService+SystemCreationClassName=DCIM_ComputerSystem+SystemName=IDRAC:ID+Name=SoftwareUpdate -h #{transport[:host]} -u #{transport[:user]} -p #{transport[:password]} -P 443 -c Dummy -y basic -V -v"
    Puppet.debug("WSMAN invoking: GetRepoBasedUpdateList")
    sleep 30
    resp = run_wsman(wsman_cmd)
    doc = Nokogiri::XML(resp)
    doc.encoding = 'UTF-8'
    if doc.xpath('//n1:ReturnValue').text == '2'
      if doc.xpath('//n1:MessageID').text == 'SUP029'
        Puppet.debug doc.xpath('//n1:Message').text
        Puppet.debug("---------- NO UPDATES AVAILABLE -----------")
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
    updates = []
    @targets = []
    switch = 0
    out.first.to_s.each_line do |ln|
      if ln.include? "DisplayName"
        switch = 1
      elsif switch == 1
        updates << ln.split(/&lt;\/?VALUE&gt;/).join
        switch = 0
      elsif ln.include? "\"Target\""
        switch = 2
      elsif switch == 2
        @targets << ln.split(/&lt;\/?VALUE&gt;/).join.gsub(' ','').chop
        switch = 0
      else
        switch = 0
      end
    end
    updates.each do |update|
      Puppet.debug("Firmware update available for: #{update}")
    end
    false
  end

  def create
    Puppet.debug('ABOUT TO APPLY FIRMWARE UPDATES')
    wsman_cmd =  "wsman invoke -a 'InstallFromRepository' http://schemas.dell.com/wbem/wscim/1/cim-schema/2/root/dcim/DCIM_SoftwareInstallationService?CreationClassName=DCIM_SoftwareInstallationService+SystemCreationClassName=DCIM_ComputerSystem+SystemName=IDRAC:ID+Name=SoftwareUpdate -h #{transport[:host]} -P 443 -u #{transport[:user]} -p #{transport[:password]} -c Dummy -y basic -V -v -k \"ipaddress=#{@asm_hostname}\" -k \"sharename=#{@share}\" -k \"sharetype=0\" -k \"RebootNeeded=#{@restart}\" -k \"ApplyUpdate=1\" -k \"CatalogName=#{@catalog_name}\""
    Puppet.debug("WSMAN invoking: InstallFromRepository")
    resp = run_wsman(wsman_cmd)
    Puppet.debug("WSMAN RESPONSE: #{resp}")
    doc = Nokogiri::XML(resp)
    if doc.xpath('//n1:ReturnValue').text == '4096'
      job_id = doc.xpath('//wsman:Selector').first.text
      Puppet.debug("Firmware update job started successfully")
      Puppet.debug("Job ID: #{job_id}")
      if @restart == "false"
        Puppet.debug("Any firmware updates requiring restart will occur on next reboot")
      else
        sleep 20
        finished = false
        @status = {}
        @looking_for = []
        @targets.each do |target|
          @looking_for << "update:#{target}"
          @status["update:#{target}"] = 'unknown'
        end
        until finished
          finished = get_update_logs(job_id)
        end
      end
    else
      raise Puppet::Error, "Error running wsman: InstallFromRepository. Error message: #{doc.xpath('//n1:Message').text}"
    end
  end

  def get_update_logs(job_id)
    #What updates are we tracking?
    data = get_data
    new_data = get_new_data(data,job_id)
    new_data.values.each do |value|
      @looking_for.any? do |l|
        if value["Name"] =~ /#{l}/
          @status[l] = value["JobStatus"]
        end
      end
    end
    if @status.values.all? {|v| v =~ /Completed|Failed/ }
      Puppet.debug(@status)
      return true
    else
      Puppet.debug(@status)
      sleep 30
      return false
    end
  end


  def get_data
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
          "MessageID"       => info["MessageID"],
          "PercentComplete" => info["PercentComplete"] }
      end
    end
    data
  end
 
  def get_new_data(data,job_id)
    ##Gets on the job events for this run
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
