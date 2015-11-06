require 'spec_helper'
require 'puppet/provider/importtemplatexml'
require 'puppet/provider/exporttemplatexml'
require 'yaml'
require 'rspec/expectations'
require 'hashie'
require 'asm/network_configuration'

describe Puppet::Provider::Importtemplatexml do

	before(:each) do
    @test_config_dir = URI(File.join(Dir.pwd, "spec", "fixtures"))
    @view_disk_xml = File.read(@test_config_dir.path + '/disks.xml')
    Puppet::Module.stub(:find).with("idrac").and_return(@test_config_dir)
    @mock_net_config_data =
      Hashie::Mash.new({
        "interfaces" => [
          {"name" => "Interface",
            "enabled" => true,
            "nictype" => "2",
            "fabrictype" => "ethernet",
            "interfaces" =>
            [{ "partitioned"=>true,
              "name" => "Port 1",
              "partitions"=>
              [{ "name" => "1",
                  "minimum" => "0",
                  "maximum" => "100",
                  "networkObjects"=>[
                    {
                      "type" => "HYPERVISOR_MANAGEMENT"
                    },
                  ]
                },
                { "name" => "2",
                  "minimum" => "0",
                  "maximum" => "100",

                  "networkObjects"=>[
                    {
                      "type" => "STORAGE_ISCSI_SAN"
                    },
                  ]
                },
                { "name" => "3",
                  "minimum" => "0",
                  "maximum" => "100",

                  "networkObjects"=>[
                    {
                      "type" => "PXE"
                    },
                  ]
                },
                { "name" => "4",
                  "minimum" => "0",
                  "maximum" => "100",

                  "networkObjects"=>[
                    {
                      "type" => "PRIVATE_LAN"
                    },
                  ]}]}]}]})

    @mock_raid_config_data =
        {
            "virtualDisks" => [
                {
                    "raidLevel" => "raid0",
                    "physicalDisks" => [
                        "Disk.Bay.3:Enclosure.Internal.0-1:RAID.Integrated.1-1",
                        "Disk.Bay.2:Enclosure.Internal.0-1:RAID.Integrated.1-1"
                    ],
                    "controller" => "RAID.Integrated.1-1"
                },
                {
                    "raidLevel" => "raid1",
                    "physicalDisks" => [
                        "Disk.Bay.1:Enclosure.Internal.0-1:RAID.Integrated.1-1",
                        "Disk.Bay.0:Enclosure.Internal.0-1:RAID.Integrated.1-1"
                    ],
                    "controller" => "RAID.Integrated.1-1"
                }
            ],
            "hddHotSpares" => [
                "Disk.Bay.5:Enclosure.Internal.0-1:RAID.Integrated.1-1"
            ],
            "ssdHotSpares" => [

            ]
        }
    @mock_raid_config = {
        "virtualDisks"=> [
            {
                "raidLevel"=> "raid10",
                "physicalDisks"=> [
                    "Disk.Bay.5:Enclosure.Internal.0-1:RAID.Integrated.1-1",
                    "Disk.Bay.4:Enclosure.Internal.0-1:RAID.Integrated.1-1",
                    "Disk.Bay.3:Enclosure.Internal.0-1:RAID.Integrated.1-1",
                    "Disk.Bay.2:Enclosure.Internal.0-1:RAID.Integrated.1-1"
                ],
                "controller"=> "RAID.Integrated.1-1"
            },
            {
                "raidLevel"=> "raid1",
                "physicalDisks"=> [
                    "Disk.Bay.1:Enclosure.Internal.0-1:RAID.Integrated.1-1",
                    "Disk.Bay.0:Enclosure.Internal.0-1:RAID.Integrated.1-1"
                ],
                "controller"=> "RAID.Integrated.1-1"
            }
        ],
        "hddHotSpares"=> [
            "Disk.Bay.6:Enclosure.Internal.0-1:RAID.Integrated.1-1"
        ],
        "ssdHotSpares"=> [

        ],
        "externalVirtualDisks"=> [], "externalHddHotSpares"=>[], "externalSsdHotSpares"=>[]
    }

    @idrac_attrib = {
          :ip => '127.0.0.1',
          :username => 'root',
          :password => 'calvin',
          :configxmlfilename => 'FOOTAG.xml',
          :nfsipaddress => '172.28.10.191',
          :enable_npar => 'true',
          :target_boot_device => 'HD',
          :servicetag => 'FOOTAG',
          :nfssharepath => @test_config_dir.to_s,
          :network_config => @mock_net_config_data,
          :raid_configuration =>@mock_raid_config,
          :bios_settings      => {'InternalSdCard' => 'Enabled'}
        }
    @fixture=Puppet::Provider::Importtemplatexml.new(@idrac_attrib['ip'],@idrac_attrib['username'],@idrac_attrib['password'],@idrac_attrib)
    #@fixture.stub(:initialize).and_return("")
end

	context " instance validation " do
		it "should have instance object" do
			@fixture.should be_kind_of(Puppet::Provider::Importtemplatexml)

		end
		it "should get the instance variable value"  do
			@fixture.instance_variable_get(:@ip).should eql(@idrac_attrib['ip'])
			@fixture.instance_variable_get(:@username).should eql(@idrac_attrib['username'])
			@fixture.instance_variable_get(:@password).should eql(@idrac_attrib['password'])
			@fixture.instance_variable_get(:@resource)['configxmlfilename'].should eql(@idrac_attrib['configxmlfilename'])
			@fixture.instance_variable_get(:@resource)['nfsipaddress'].should eql(@idrac_attrib['nfsipaddress'])
			@fixture.instance_variable_get(:@resource)['nfssharepath'].should eql(@idrac_attrib['nfssharepath'])
			@fixture.instance_variable_get(:@resource)['enable_npar'].should eql(@idrac_attrib['enable_npar'])
			@fixture.instance_variable_get(:@resource)['servicetag'].should eql(@idrac_attrib['servicetag'])
			@fixture.instance_variable_get(:@resource)['target_boot_device'].should eql(@idrac_attrib['target_boot_device'])
		end
		it "should have method " do
			@fixture.class.instance_method(:importtemplatexml).should_not == nil
		end
	end
	context "when exporting template" do
		it "should get Job id for Export template xml"  do
			@fixture.should_receive(:execute_import).once.and_return('JID_896466295795')
			@fixture.stub(:munge_config_xml)
			jobid = @fixture.importtemplatexml
			jobid.should == "JID_896466295795"
		end
		it "should not get Job id if import template fail" do
      ASM::WsMan.should_receive(:invoke).once.and_return(nil)
			@fixture.stub(:munge_config_xml)
			expect{ @fixture.importtemplatexml}.to raise_error("ImportSystemConfiguration Job could not be created:  Response is invalid")
		end
	end
	context "when importing template" do
    before(:each) do
      @exported_name = File.basename(@idrac_attrib[:configxmlfilename], ".xml") + "_base.xml"
      #Needed to call original open method by default
      original_method = FileUtils.method(:cp)
      FileUtils.stub(:cp).with(anything()) { |*args| original_method.call(*args) }
      FileUtils.stub(:cp).with(File.join(@test_config_dir.path, @exported_name), File.join(@idrac_attrib[:nfssharepath], @idrac_attrib[:configxmlfilename])).and_return('')
      original_method = File.method(:open)
      File.stub(:open).with(anything()) { |*args| original_method.call(*args) }
      File.stub(:open).with(File.join(@test_config_dir.path, @idrac_attrib[:configxmlfilename]), "w+").and_return('')
    end

		it "should munge basic config xml data" do
			Puppet::Module.stub(:find).with("idrac").and_return(@test_config_dir)
      Puppet::Idrac::Util.stub(:get_transport).and_return({:host => '1.1.1.1', :user => 'root', :password => 'calvin'})
      Puppet::Provider::Exporttemplatexml.any_instance.stub(:exporttemplatexml).and_return("12341234")
      Puppet::Provider::Importtemplatexml.any_instance.stub(:process_nics).and_return({"partial" => {"NIC.Integrated.1-1-1" => {"IntegratedRaid"=>"Disabled"}}})
      Puppet::Provider::Importtemplatexml.any_instance.stub(:get_raid_config_changes).and_return({})
      Puppet::Provider::Importtemplatexml.any_instance.stub(:remove_invalid_settings).and_return({})
      Puppet::Provider::Importtemplatexml.any_instance.stub(:default_changes).and_return(
          {'partial'=>{'BIOS.Setup.1-1'=> {'ProcVirtualization' => 'Disabled'}},
           'whole'=>{'LifecycleController.Embedded.1' => {'ProcVirtualization' => 'Enabled'}},
           'remove'=> {'attributes'=>{'BIOS.Setup.1-1' => ["Remove"]}, 'components'=>{'RemoveMe' => []}}})
      ASM::WsMan.stub(:invoke).and_return(@view_disk_xml)
      #Needed to call original open method by default
      original_method = File.method(:open)
      xml = @fixture.munge_config_xml
      xml.xpath("//Attribute[@Name='Remove']").size.should == 0
      xml.xpath("//Component[@FQDD='RemoveMe']").size.should == 0
      xml.xpath("//Component[@FQDD='BIOS.Setup.1-1']/Attribute").first.content.should == "Disabled"
      xml.xpath("//Component[@FQDD='LifecycleController.Embedded.1']/Attribute").size.should_not == 0
    end

    it "should get changes based on raid configuration hash" do
      Puppet::Provider::Exporttemplatexml.any_instance.stub(:exporttemplatexml).and_return("12341234")
      Puppet::Provider::Importtemplatexml.any_instance.stub(:raid_in_sync?).and_return(false)
      ASM::WsMan.stub(:invoke).and_return(@view_disk_xml)
      Puppet::Idrac::Util.stub(:get_transport).and_return({:host => '1.1.1.1', :user => 'root', :password => 'calvin'})
      changes = @fixture.get_raid_config_changes(nil)
      changes['whole']['RAID.Integrated.1-1'].should_not == nil
      virtual_disk_changes = changes['whole']['RAID.Integrated.1-1']['Disk.Virtual.0:RAID.Integrated.1-1']
      virtual_disk_changes.should_not == nil
      virtual_disk_changes['IncludedPhysicalDiskID'].sort.should ==
          ["Disk.Bay.5:Enclosure.Internal.0-1:RAID.Integrated.1-1", "Disk.Bay.4:Enclosure.Internal.0-1:RAID.Integrated.1-1",
          "Disk.Bay.3:Enclosure.Internal.0-1:RAID.Integrated.1-1", "Disk.Bay.2:Enclosure.Internal.0-1:RAID.Integrated.1-1"].sort
      virtual_disk_changes['SpanLength'].to_s.should == '2'
      virtual_disk_changes['SpanDepth'].to_s.should == '2'
    end

    it "should get changes based on network configuration hash" do
      fqdd_to_mac = {'NIC.Integrated.1-1-1' => '00:0E:1E:0D:8C:30',
                     'NIC.Integrated.1-1-2' => '00:0E:1E:0D:8C:32',
                     'NIC.Integrated.1-1-3' => '00:0E:1E:0D:8C:34',
                     'NIC.Integrated.1-1-4' => '00:0E:1E:0D:8C:36'
      }
      ASM::WsMan.stub(:get_mac_addresses).and_return(fqdd_to_mac)
      ASM::WsMan.stub(:get_all_fqdds).and_return(fqdd_to_mac.keys)
      net_config = ASM::NetworkConfiguration.new(@mock_net_config_data)
      ASM::NetworkConfiguration.stub(:new).and_return(net_config)
      changes = @fixture.process_nics

      ['NIC.Integrated.1-1-1', 'NIC.Integrated.1-1-2', 'NIC.Integrated.1-1-3', 'NIC.Integrated.1-1-4'].all? do |s|
        changes['whole'].key?(s).should == true
        nic_changes = changes['whole'][s]
        case s
        when "NIC.Integrated.1-1-1"
          nic_changes['NicMode'].should == "Enabled"
          nic_changes['VirtualizationMode'].should == "NPAR"
          nic_changes['iScsiOffloadMode'].should == "Disabled"
        when "NIC.Integrated.1-1-2"
          nic_changes['NicMode'].should == "Enabled"
          nic_changes['iScsiOffloadMode'].should == "Enabled"
        when "NIC.Integrated.1-1-3"
          nic_changes['NicMode'].should == "Enabled"
          nic_changes['iScsiOffloadMode'].should == "Disabled"
        when "NIC.Integrated.1-1-4"
          nic_changes['NicMode'].should == "Enabled"
          nic_changes['iScsiOffloadMode'].should == "Disabled"
        end
      end
    end

    it "should use the network data to munge the config.xml" do
      Puppet::Module.stub(:find).with("idrac").and_return(@test_config_dir)
      Puppet::Idrac::Util.stub(:get_transport).and_return({:host => '1.1.1.1', :user => 'root', :password => 'calvin'})
      Puppet::Provider::Exporttemplatexml.any_instance.stub(:exporttemplatexml).and_return("12341234")
      fqdd_to_mac = {'NIC.Integrated.1-1-1' => '00:0E:1E:0D:8C:30',
                     'NIC.Integrated.1-1-2' => '00:0E:1E:0D:8C:32',
                     'NIC.Integrated.1-1-3' => '00:0E:1E:0D:8C:34',
                     'NIC.Integrated.1-1-4' => '00:0E:1E:0D:8C:36'
      }
      ASM::WsMan.stub(:get_mac_addresses).and_return(fqdd_to_mac)
      net_config = ASM::NetworkConfiguration.new(@mock_net_config_data)
      ASM::NetworkConfiguration.stub(:new).and_return(net_config)
      ASM::WsMan.stub(:invoke).and_return(@view_disk_xml)
      Puppet::Provider::Importtemplatexml.any_instance.stub(:get_raid_config_changes).and_return({})
      Puppet::Provider::Importtemplatexml.any_instance.stub(:remove_invalid_settings).and_return({})
      xml = @fixture.munge_config_xml
      xml.xpath("//Component[@FQDD='NIC.Integrated.1-1-1']")
      ['NIC.Integrated.1-1-1', 'NIC.Integrated.1-1-2', 'NIC.Integrated.1-1-3', 'NIC.Integrated.1-1-4'].all? do |s|
        comp = xml.at_xpath("//Component[@FQDD='#{s}']")
        comp.should_not == nil
        case s
        when "NIC.Integrated.1-1-1"
          comp.at_xpath("Attribute[@Name='NicMode']").content.should == "Enabled"
          comp.at_xpath("Attribute[@Name='VirtualizationMode']").content.should == "NPAR"
          comp.at_xpath("Attribute[@Name='iScsiOffloadMode']").content.should == "Disabled"
        when "NIC.Integrated.1-1-2"
          comp.at_xpath("Attribute[@Name='NicMode']").content.should == "Enabled"
          comp.at_xpath("Attribute[@Name='iScsiOffloadMode']").content.should == "Enabled"
        when "NIC.Integrated.1-1-3"
          comp.at_xpath("Attribute[@Name='NicMode']").content.should == "Enabled"
          comp.at_xpath("Attribute[@Name='iScsiOffloadMode']").content.should == "Disabled"
        when "NIC.Integrated.1-1-4"
          comp.at_xpath("Attribute[@Name='NicMode']").content.should == "Enabled"
          comp.at_xpath("Attribute[@Name='iScsiOffloadMode']").content.should == "Disabled"
        end
      end
    end

    it "should remove any bios attributes that don't exist on the server" do
      Puppet::Module.stub(:find).with("idrac").and_return(@test_config_dir)
      Puppet::Idrac::Util.stub(:get_transport).and_return({:host => '1.1.1.1', :user => 'root', :password => 'calvin'})
      Puppet::Provider::Exporttemplatexml.any_instance.stub(:exporttemplatexml).and_return("12341234")
      fqdd_to_mac = {'NIC.Integrated.1-1-1' => '00:0E:1E:0D:8C:30',
                     'NIC.Integrated.1-1-2' => '00:0E:1E:0D:8C:32',
                     'NIC.Integrated.1-1-3' => '00:0E:1E:0D:8C:34',
                     'NIC.Integrated.1-1-4' => '00:0E:1E:0D:8C:36'
      }
      ASM::WsMan.stub(:get_mac_addresses).and_return(fqdd_to_mac)
      net_config = ASM::NetworkConfiguration.new(@mock_net_config_data)
      ASM::NetworkConfiguration.stub(:new).and_return(net_config)
      ASM::WsMan.stub(:invoke).and_return(@view_disk_xml)
      Puppet::Provider::Importtemplatexml.any_instance.stub(:get_raid_config_changes).and_return({})
      @fixture.stub(:find_target_bios_setting).and_return("value")
      @fixture.stub(:find_target_bios_setting).with('InvalidAttribute').and_return(nil)
      #The xml that @fixture will read (FOOTAG_original) will have the InvalidAttribute attribute. It should not exist after munging.
      xml = @fixture.munge_config_xml
      xml.at_xpath("//Component[@FQDD='BIOS.Setup.1-1']//Attribute[@Name='InvalidAttribute']").should == nil
    end
	end

    context "when munging network_configuration" do
          it 'should configure nic partitions in config.xml' do
            @network_configuration = JSON.parse(File.read(@test_config_dir.path + '/network_configuration.json'))['networkConfiguration']
            changes = {'partial' => {}, 'whole'=>{}, 'remove' => {'components' => {}} }
            fqdd_to_mac = {'NIC.Integrated.1-1-1' => '00:0E:1E:0D:8C:30',
                     'NIC.Integrated.1-1-2' => '00:0E:1E:0D:8C:32',
                     'NIC.Integrated.1-1-3' => '00:0E:1E:0D:8C:34',
                     'NIC.Integrated.1-1-4' => '00:0E:1E:0D:8C:36',
                     'NIC.Integrated.1-2-1' => '00:0E:1E:0D:8C:31',
                     'NIC.Integrated.1-2-2' => '00:0E:1E:0D:8C:33',
                     'NIC.Integrated.1-2-3' => '00:0E:1E:0D:8C:35',
                     'NIC.Integrated.1-2-4' => '00:0E:1E:0D:8C:37',
            }
            require 'asm'
            ASM::WsMan.stub(:get_mac_addresses).and_return(fqdd_to_mac)
            @fixture.munge_network_configuration(@network_configuration, changes, 'iSCSI')
            changes['partial']['NIC.Integrated.1-1-1'].should_not == nil
            changes['partial']['NIC.Integrated.1-2-1'].should_not == nil
          end
          it 'should configure nic partitions in config.xml FC case' do
            @network_configuration = JSON.parse(File.read(@test_config_dir.path + '/network_configuration_fc.json'))['networkConfiguration']
            changes = {'partial' => {}, 'remove' => {'components' => {}} }
            fqdd_to_mac = {'NIC.Integrated.1-1-1' => '00:0E:1E:0D:8C:30',
                     'NIC.Integrated.1-1-2' => '00:0E:1E:0D:8C:32',
                     'NIC.Integrated.1-1-3' => '00:0E:1E:0D:8C:34',
                     'NIC.Integrated.1-1-4' => '00:0E:1E:0D:8C:36',
                     'NIC.Integrated.1-2-1' => '00:0E:1E:0D:8C:31',
                     'NIC.Integrated.1-2-2' => '00:0E:1E:0D:8C:33',
                     'NIC.Integrated.1-2-3' => '00:0E:1E:0D:8C:35',
                     'NIC.Integrated.1-2-4' => '00:0E:1E:0D:8C:37',
            }
            require 'asm'
            ASM::WsMan.stub(:get_mac_addresses).and_return(fqdd_to_mac)
            @fixture.munge_network_configuration(@network_configuration, changes, 'FC')
            changes['partial']['NIC.Integrated.1-1-1'].should_not == nil
            changes['partial']['NIC.Integrated.1-2-1'].should_not == nil
          end

          it "when munging BFS parameters" do
            @network_configuration = JSON.parse(File.read(@test_config_dir.path + '/network_configuration.json'))['networkConfiguration']
            #ASM::NetworkConfiguration.any_instance.stub(:new).and_return(ASM::NetworkConfiguration.new(@network_configuration))
            #ASM::NetworkConfiguration.any_instance.stub(:add_nics!).and_return(nil)
            @test_config_dir = URI(File.join(Dir.pwd, "spec", "fixtures"))
            Puppet::Module.stub(:find).with("idrac").and_return(@test_config_dir)
            #Puppet::Provider::Importtemplatexml.any_instance.stub(:process_nics).and_return({"partial" => {"NIC.Integrated.1-1-1" => {"IntegratedRaid"=>"Disabled"}}})
            @fixture.resource[:target_boot_device] = 'iSCSI'
            @fixture.resource[:network_config] = @network_configuration
            @fixture.resource[:target_ip] = "172.16.15.100"
            @fixture.resource[:target_iscsi] = "mytargetiscsiiqn"
            @fixture.resource[:enable_npar] = 'false'
            changes = {'partial' => {}, 'remove' => {'components' => {}} }
            fqdd_to_mac = {'NIC.Integrated.1-1-1' => '00:0E:1E:0D:8C:30',
               'NIC.Integrated.1-1-2' => '00:0E:1E:0D:8C:32',
               'NIC.Integrated.1-1-3' => '00:0E:1E:0D:8C:34',
               'NIC.Integrated.1-1-4' => '00:0E:1E:0D:8C:36',
               'NIC.Integrated.1-2-1' => '00:0E:1E:0D:8C:31',
               'NIC.Integrated.1-2-2' => '00:0E:1E:0D:8C:33',
               'NIC.Integrated.1-2-3' => '00:0E:1E:0D:8C:35',
               'NIC.Integrated.1-2-4' => '00:0E:1E:0D:8C:37',
            }
            require 'asm'
            ASM::WsMan.stub(:get_mac_addresses).and_return(fqdd_to_mac)
            @fixture=Puppet::Provider::Importtemplatexml.new(@idrac_attrib['ip'],@idrac_attrib['username'],@idrac_attrib['password'],@idrac_attrib)
            @exported_name = File.basename(@idrac_attrib[:configxmlfilename], ".xml") + "_base.xml"
            #Needed to call original open method by default
            original_method = FileUtils.method(:cp)
            FileUtils.stub(:cp).with(anything()) { |*args| original_method.call(*args) }
            FileUtils.stub(:cp).with(File.join(@test_config_dir.path, @exported_name), File.join(@idrac_attrib[:nfssharepath], @idrac_attrib[:configxmlfilename])).and_return('')
            Puppet::Provider::Importtemplatexml.any_instance.stub(:remove_invalid_settings).and_return({})
            original_method = File.method(:open)
            File.stub(:open).with(anything()) { |*args| original_method.call(*args) }
            File.stub(:open).with(File.join(@test_config_dir.path, @idrac_attrib[:configxmlfilename]), "w+").and_return('')
            xml = @fixture.munge_config_xml
            xml.xpath("//Component[@FQDD='NIC.Integrated.1-1-1']")
            comp = xml.at_xpath("//Component[@FQDD='NIC.Integrated.1-1-1']")
            comp.should_not == nil
            comp.at_xpath("Attribute[@Name='VirtualizationMode']").content.should == "NONE"
            comp.at_xpath("Attribute[@Name='VirtMacAddr']").content.should == "00:0E:AA:6B:00:05"
            comp.at_xpath("Attribute[@Name='VirtIscsiMacAddr']").content.should == "00:0E:AA:6B:00:01"
            comp.at_xpath("Attribute[@Name='TcpIpViaDHCP']").content.should == "Disabled"
            comp.at_xpath("Attribute[@Name='IscsiViaDHCP']").content.should == "Disabled"
            comp.at_xpath("Attribute[@Name='ChapAuthEnable']").content.should == "Disabled"
            comp.at_xpath("Attribute[@Name='IscsiTgtBoot']").content.should == "Enabled"
            comp.at_xpath("Attribute[@Name='IscsiInitiatorIpAddr']").content.should == "172.16.119.3"
            comp.at_xpath("Attribute[@Name='IscsiInitiatorSubnet']").content.should == "255.255.0.0"
            comp.at_xpath("Attribute[@Name='IscsiInitiatorGateway']").content.should == "172.16.0.1"
            comp.at_xpath("Attribute[@Name='IscsiInitiatorName']").content.should == "iqn.asm:software-asm-01-0000000000:0000000002"
            comp.at_xpath("Attribute[@Name='ConnectFirstTgt']").content.should == "Enabled"
            comp.at_xpath("Attribute[@Name='FirstTgtIpAddress']").content.should == @fixture.resource[:target_ip]
            comp.at_xpath("Attribute[@Name='FirstTgtTcpPort']").content.should == "3260"
            comp.at_xpath("Attribute[@Name='FirstTgtIscsiName']").content.should == @fixture.resource[:target_iscsi]
            comp.at_xpath("Attribute[@Name='LegacyBootProto']").content.should == "iSCSI"
            comp.at_xpath("Attribute[@Name='iScsiOffloadMode']").should == nil
          end

    end
end
