require 'rexml/parsers/treeparser'
require 'uri'
require '/etc/puppetlabs/puppet/modules/asm_lib/lib/security/encode'

provider_path = Pathname.new(__FILE__).parent
require 'rexml/document'

include REXML
require File.join(provider_path, 'idrac')
require File.join(provider_path, 'checklcstatus')
require File.join(provider_path, 'checkjdstatus')
require File.join(provider_path, 'reboot')

class Puppet::Provider::BiosConfig <  Puppet::Provider
  def initialize (ip,username,password,boottype)
    @ip = ip
    @username = username
    @password = password
	@password = URI.decode(asm_decrypt(@password))
    @boottype  = boottype
    @instid = ""

  end

  def GetBootSourceSetting
    xmlresp= wsmancmd "bootorder"
    puts xmlresp
    if (xmlresp !="")
      varbootseq=  parseResponse xmlresp
      puts "varbootseq : #{varbootseq}"
      if (varbootseq .length >0)
        retval=  creatBootSeq varbootseq
        if retval == true
          resp=wsmancmd "updatebootorder"
          puts "Response : #{resp}"
          # get response msg
          xmldoc = Document.new(resp)
          msg = XPath.first(xmldoc, '//n1:Message')
          tempmsg = msg
          if tempmsg.to_s == ""
            raise "Failed to update boot order Sequence"
          end
          msg=msg.text
          puts "MESSAGE : #{msg}"
          if msg =~ /Success/i
            resp= wsmancmd "changebootsource"
            puts resp
            createJobid
          end
        end
      end
    end
  end

  def createJobid
    #Reboot
    instanceid = rebootinstanse
    if instanceid == "success"
     return 
    end
    puts "instanceid : #{instanceid}"
    Puppet.info "instanceid : #{instanceid}"
    for i in 0..30
      response = checkjobstatus instanceid
      Puppet.info "JD status : #{response}"
      if response  == "Completed" || response == "Reboot Completed"
        Puppet.info "Boot order Sequence is completed."
        break
      else
        if response  == "Failed"
          raise "Job ID is not created."
        else
          Puppet.info "Job is running, wait for 1 minute"
          sleep 60
        end
      end
    end
    if response != "Completed" && response != "Reboot Completed"
      raise "Boot order Sequence is still running."
    end
  end

  def wsmancmd(cmd)
    resp=""
    if cmd =="bootorder" then
      resp = `wsman enumerate http://schemas.dmtf.org/wbem/wscim/1/cim-schema/2/root/dcim/DCIM_BootSourceSetting -h #{@ip}  -V -v -c dummy.cert -P 443 -u #{@username} -p #{@password} -j utf-8 -y basic`
      return   resp
    end
    if cmd == "updatebootorder"
      resp = `wsman invoke -a ChangeBootOrderByInstanceID http://schemas.dmtf.org/wbem/wscim/1/cim-schema/2/root/dcim/DCIM_BootConfigSetting?InstanceID=IPL -h #{@ip} -V -v -c dummy.cert -P 443 -u #{@username} -p #{@password} -J /tmp/ChangeBootOrder_#{@ip}.xml -j utf-8 -y basic`
      return   resp
    end
    if cmd == "changebootsource"
      resp = `wsman invoke -a ChangeBootSourceState http://schemas.dmtf.org/wbem/wscim/1/cim-schema/2/root/dcim/DCIM_BootConfigSetting?InstanceID=IPL -h #{@ip} -V -v -c dummy.cert -P 443 -u #{@username} -p #{@password} -k EnabledState=0 -k source=#{@instid} -j utf-8 -y basic`
      return   resp
    end

  end

  def parseResponse(xmldata)
    ary= Array.new
    data=xmldata.split(/\n/)
    data.each do |ele|
      if ele.to_s =~ /<n1:InstanceID>(\S+)<\/n1:InstanceID>/
        vardata = $1
        if vardata =~ /\#BootSeq\#/
          @instid = vardata
          ary.push(vardata)
        end
      end
    end
    return ary
  end

  def creatBootSeq(ary)
    _flag =false
    bootorderfilepath = File.join(Pathname.new(__FILE__).parent.parent.parent.parent, 'files/defaultxmls/ChangeBootOrder.xml')
    file = File.new(bootorderfilepath)
    xmldoc = Document.new(file)
    xmlroot = xmldoc.root
    ary.each do |val|
      if val.to_s =~ /#{@boottype}/i
        instanceID = val
        pdarray = Element.new "p:source"
        pdarray.text = "#{instanceID}"
        xmlroot.add_element pdarray
      end
    end
    file = File.open("/tmp/ChangeBootOrder_#{@ip}.xml", "w")
    xmldoc.write(file)
    file.close
    _flag= true
    return _flag
  end

  def rebootinstanse
    #Reboot
    rebootfilepath = File.join(Pathname.new(__FILE__).parent.parent.parent.parent, 'files/defaultxmls/rebootidrac.xml')
    obj = Puppet::Provider::Reboot.new(@ip,@username,@password,rebootfilepath)
    instanceid = obj.rebootidrac
    puts "instanceid : #{instanceid}"
    return instanceid
  end

  def checkjobstatus(instanceid)
    obj = Puppet::Provider::Checkjdstatus.new(@ip,@username,@password,instanceid)
    response = obj.checkjdstatus
  end

end

