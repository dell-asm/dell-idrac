require 'spec_helper'
require 'puppet/provider/importtemplatexml'
require 'puppet/provider/exporttemplatexml'
require 'yaml'
require 'rspec/expectations'
require 'hashie'
require 'asm/network_configuration'

describe Puppet::Provider::Importtemplatexml do

  def build_nic_views(fqdd_to_mac, vendor = nil, product = nil)
    fqdd_to_mac.keys.map do |fqdd|
      mac = fqdd_to_mac[fqdd]
      nic_view = {"FQDD" => fqdd, "PermanentMACAddress" => mac, "CurrentMACAddress" => mac}
      unless block_given? && yield(nic_view)
        nic_view["LinkSpeed"] = "5"
        nic_view["VendorName"] = vendor if vendor
        nic_view["ProductName"] = product if product
      end
      nic_view
    end
  end

  before(:each) do
    @test_config_dir = URI( File.expand_path("../../../../fixtures", __FILE__))
    @view_disk_xml = File.read(@test_config_dir.path + '/disks.xml')
    Puppet::Module.stub(:find).with("idrac").and_return(@test_config_dir)
    @mock_net_config_data =
        Hashie::Mash.new({"interfaces" => [
            {"name" => "Interface",
             "enabled" => true,
             "nictype" => "2",
             "fabrictype" => "ethernet",
             "interfaces" =>
                 [{"partitioned" => true,
                   "name" => "Port 1",
                   "partitions" =>
                       [{"name" => "1",
                         "minimum" => "0",
                         "maximum" => "100",
                         "networkObjects" => [
                             {
                                 "type" => "HYPERVISOR_MANAGEMENT"
                             },
                         ]
                        },
                        {"name" => "2",
                         "minimum" => "0",
                         "maximum" => "100",

                         "networkObjects" => [
                             {
                                 "type" => "STORAGE_ISCSI_SAN"
                             },
                         ]
                        },
                        {"name" => "3",
                         "minimum" => "0",
                         "maximum" => "100",

                         "networkObjects" => [
                             {
                                 "type" => "PXE"
                             },
                         ]
                        },
                        {"name" => "4",
                         "minimum" => "0",
                         "maximum" => "100",

                         "networkObjects" => [
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
        "virtualDisks" => [
            {
                "raidLevel" => "raid10",
                "physicalDisks" => [
                    "Disk.Bay.5:Enclosure.Internal.0-1:RAID.Integrated.1-1",
                    "Disk.Bay.4:Enclosure.Internal.0-1:RAID.Integrated.1-1",
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
            "Disk.Bay.6:Enclosure.Internal.0-1:RAID.Integrated.1-1"
        ],
        "ssdHotSpares" => [

        ],
        "externalVirtualDisks" => [], "externalHddHotSpares" => [], "externalSsdHotSpares" => []
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
        :nfssharepath => @test_config_dir.path.to_s,
        :network_config => @mock_net_config_data,
        :raid_configuration => @mock_raid_config,
        :bios_settings => {'InternalSdCard' => 'Enabled'}
    }
    @fixture=Puppet::Provider::Importtemplatexml.new(@idrac_attrib['ip'], @idrac_attrib['username'], @idrac_attrib['password'], @idrac_attrib)
    ASM::WsMan.stub(:get_bios_enumeration).and_return([])
  end

  context " instance validation " do
    it "should have instance object" do
      @fixture.should be_kind_of(Puppet::Provider::Importtemplatexml)
    end

    it "should get the instance variable value" do
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
    it "should get Job id for Export template xml" do
      @fixture.should_receive(:execute_import).once.and_return('JID_896466295795')
      @fixture.stub(:munge_config_xml)
      jobid = @fixture.importtemplatexml
      jobid.should == "JID_896466295795"
    end

    it "should not get Job id if import template fail" do
      ASM::WsMan.should_receive(:invoke).once.and_return(nil)
      @fixture.stub(:munge_config_xml)
      expect { @fixture.importtemplatexml }.to raise_error("ImportSystemConfiguration Job could not be created:  Response is invalid")
    end
  end

  context "when importing template" do
    let(:fqdd_to_mac) { {'NIC.Integrated.1-1-1' => '00:0E:1E:0D:8C:30',
                         'NIC.Integrated.1-1-2' => '00:0E:1E:0D:8C:32',
                         'NIC.Integrated.1-1-3' => '00:0E:1E:0D:8C:34',
                         'NIC.Integrated.1-1-4' => '00:0E:1E:0D:8C:36',
                         'NIC.Integrated.1-2-1' => '00:0E:1E:0D:8C:31',
                         'NIC.Integrated.1-2-2' => '00:0E:1E:0D:8C:33',
                         'NIC.Integrated.1-2-3' => '00:0E:1E:0D:8C:35',
                         'NIC.Integrated.1-2-4' => '00:0E:1E:0D:8C:37', } }

    before(:each) do
      @exported_name = File.basename(@idrac_attrib[:configxmlfilename], ".xml") + "_base.xml"
      #Needed to call original open method by default
      original_method = FileUtils.method(:cp)
      FileUtils.stub(:cp).with(anything()) { |*args| original_method.call(*args) }
      FileUtils.stub(:cp).with(File.join(@test_config_dir.path, @exported_name), File.join(@idrac_attrib[:nfssharepath], @idrac_attrib[:configxmlfilename])).and_return('')
      original_method = File.method(:open)
      File.stub(:open).with(anything()) { |*args| original_method.call(*args) }
      File.stub(:open).with(File.join(@test_config_dir.path, @idrac_attrib[:configxmlfilename]), "w+").and_return('')

      ASM::WsMan.stub(:get_nic_view).and_return(build_nic_views(fqdd_to_mac, "Broadcom", "57810"))
    end

    it "should munge basic config xml data" do
      Puppet::Module.stub(:find).with("idrac").and_return(@test_config_dir)
      Puppet::Idrac::Util.stub(:get_transport).and_return({:host => '1.1.1.1', :user => 'root', :password => 'calvin'})
      Puppet::Provider::Exporttemplatexml.any_instance.stub(:exporttemplatexml).and_return("12341234")
      Puppet::Provider::Importtemplatexml.any_instance.stub(:process_nics).and_return({"partial" => {"NIC.Integrated.1-1-1" => {"IntegratedRaid" => "Disabled"}}})
      Puppet::Provider::Importtemplatexml.any_instance.stub(:get_raid_config_changes).and_return({})
      Puppet::Provider::Importtemplatexml.any_instance.stub(:remove_invalid_settings).and_return({})
      Puppet::Provider::Importtemplatexml.any_instance.stub(:default_changes).and_return(
          {'partial' => {'BIOS.Setup.1-1' => {'ProcVirtualization' => 'Disabled'}},
           'whole' => {'LifecycleController.Embedded.1' => {'ProcVirtualization' => 'Enabled'}},
           'remove' => {'attributes' => {'BIOS.Setup.1-1' => ["Remove"]}, 'components' => {'RemoveMe' => []}}})
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
      Puppet::Provider::Importtemplatexml.any_instance.stub(:find_attribute_value).and_return("RAID")
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
      net_config = ASM::NetworkConfiguration.new(@mock_net_config_data)
      ASM::NetworkConfiguration.stub(:new).and_return(net_config)
      ASM::WsMan.stub(:invoke).and_return(@view_disk_xml)
      Puppet::Provider::Importtemplatexml.any_instance.stub(:get_raid_config_changes).and_return({})
      Puppet::Provider::Importtemplatexml.any_instance.stub(:find_attribute_value).and_return("RAID.Integrated.1-1")
      @fixture.stub(:find_target_bios_setting).and_return("value")
      @fixture.stub(:find_target_bios_setting).with('InvalidAttribute').and_return(nil)
      #The xml that @fixture will read (FOOTAG_original) will have the InvalidAttribute attribute. It should not exist after munging.
      xml = @fixture.munge_config_xml
      xml.at_xpath("//Component[@FQDD='BIOS.Setup.1-1']//Attribute[@Name='InvalidAttribute']").should == nil
    end
  end

  context "when munging network_configuration" do
    let(:fqdd_to_mac) { {'NIC.Integrated.1-1-1' => '00:0E:1E:0D:8C:30',
                         'NIC.Integrated.1-1-2' => '00:0E:1E:0D:8C:32',
                         'NIC.Integrated.1-1-3' => '00:0E:1E:0D:8C:34',
                         'NIC.Integrated.1-1-4' => '00:0E:1E:0D:8C:36',
                         'NIC.Integrated.1-2-1' => '00:0E:1E:0D:8C:31',
                         'NIC.Integrated.1-2-2' => '00:0E:1E:0D:8C:33',
                         'NIC.Integrated.1-2-3' => '00:0E:1E:0D:8C:35',
                         'NIC.Integrated.1-2-4' => '00:0E:1E:0D:8C:37', } }

    before(:each) do
      ASM::WsMan.stub(:get_nic_view).and_return(build_nic_views(fqdd_to_mac, "Broadcom", "57810"))
    end

    it 'should configure nic partitions in config.xml' do
      @network_configuration = JSON.parse(File.read(@test_config_dir.path + '/network_configuration.json'))['networkConfiguration']
      changes = {'partial' => {}, 'whole' => {}, 'remove' => {'components' => {}}}
      @fixture.munge_network_configuration(@network_configuration, changes, 'iSCSI')
      changes['partial']['NIC.Integrated.1-1-1'].should_not == nil
      changes['partial']['NIC.Integrated.1-2-1'].should_not == nil
    end

    it 'should configure nic partitions in config.xml FC case' do
      @network_configuration = JSON.parse(File.read(@test_config_dir.path + '/network_configuration_fc.json'))['networkConfiguration']
      changes = {'partial' => {}, 'remove' => {'components' => {}}}
      @fixture.munge_network_configuration(@network_configuration, changes, 'FC')
      changes['partial']['NIC.Integrated.1-1-1'].should_not == nil
      changes['partial']['NIC.Integrated.1-2-1'].should_not == nil
    end

    it "when munging BFS parameters" do
      Puppet::Provider::Importtemplatexml.any_instance.stub(:get_raid_config_changes).and_return({})
      Puppet::Provider::Importtemplatexml.any_instance.stub(:raid_configuration).and_return({})
      @network_configuration = JSON.parse(File.read(@test_config_dir.path + '/network_configuration.json'))['networkConfiguration']
      #ASM::NetworkConfiguration.any_instance.stub(:new).and_return(ASM::NetworkConfiguration.new(@network_configuration))
      #ASM::NetworkConfiguration.any_instance.stub(:add_nics!).and_return(nil)
      @test_config_dir = URI( File.expand_path("../../../../fixtures", __FILE__))
      Puppet::Module.stub(:find).with("idrac").and_return(@test_config_dir)
      #Puppet::Provider::Importtemplatexml.any_instance.stub(:process_nics).and_return({"partial" => {"NIC.Integrated.1-1-1" => {"IntegratedRaid"=>"Disabled"}}})
      @fixture.resource[:target_boot_device] = 'iSCSI'
      @fixture.resource[:network_config] = @network_configuration
      @fixture.resource[:target_ip] = "172.16.15.100"
      @fixture.resource[:target_iscsi] = "mytargetiscsiiqn"
      @fixture.resource[:enable_npar] = 'false'
      changes = {'partial' => {}, 'remove' => {'components' => {}}}
      @fixture=Puppet::Provider::Importtemplatexml.new(@idrac_attrib['ip'], @idrac_attrib['username'], @idrac_attrib['password'], @idrac_attrib)
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

  describe "#is_embedded_raid?" do
    it "should return false when no virtual disks use embedded controllers" do
      expect(@fixture.is_embedded_raid?).to eq(false)
    end

    it "should return true when there are virtual disks on embedded controller" do
      resource = {:raid_configuration => {"virtualDisks" => [{"controller" => "NonRAID.Embedded.2-1"}]}}
      @fixture.instance_variable_set(:@resource, resource)
      expect(@fixture.is_embedded_raid?).to eq(true)
    end
  end

  describe "#embsata_in_sync?" do
    it "should return true when embSata Raid not required" do
      expect(@fixture.embsata_in_sync?).to eq(true)
    end

    it "should return true when embSata required but mode is already set" do
      resource = {:configxmlfilename => "BARTAG.xml", :nfssharepath => @test_config_dir.path.to_s}
      @fixture.stub(:is_embedded_raid?).and_return(true)
      @fixture.instance_variable_set(:@resource, resource)
      expect(@fixture.embsata_in_sync?).to eq(true)
    end

    it "should return false when embSata Raid required and not current" do
      @fixture.stub(:is_embedded_raid?).and_return(true)
      expect(@fixture.embsata_in_sync?).to eq(false)
    end
  end

   context "when getting SATA disk for boot" do
     it "should raise error if no SATA disk is found" do
       ASM::WsMan.stub(:invoke).and_return("")
       expect { @fixture.get_first_sata_disk }.to raise_error(RuntimeError, /Embedded SATA Disk not found/)
     end

     it "should find SATADOM when found in boot source settings" do
       mock_boot_source_settings = [
         {
           :bios_boot_string=>"NIC in Slot 1 Port 2 Partition 1: IBA XE Slot 0401 v2334 BootSeq",
           :boot_source_type=>"IPL",
           :boot_string=>"NIC in Slot 1 Port 2 Partition 1: IBA XE Slot 0401 v2334 BootSeq",
           :current_assigned_sequence=>"5",
           :current_enabled_status=>"1",
           :instance_id=>"IPL:BIOS.Setup.1-1#BootSeq#NIC.Slot.1-2-1#27d35f79888d0fa3f74312ff1da778fb"
         },
         {
            :bios_boot_string=>"Embedded SATA Port Disk J: SATADOM-ML 3ME HddSeq",
            :boot_source_type=>"BCV",
            :boot_string=>"Embedded SATA Port Disk J: SATADOM-ML 3ME HddSeq",
            :current_assigned_sequence=>"0",
            :current_enabled_status=>"1",
            :instance_id=>"BCV:BIOS.Setup.1-1#HddSeq#Disk.SATAEmbedded.J-1#4e861c42e369a695a66a0cd22fd492c3"
         }
       ]
       Puppet::Idrac::Util.stub(:boot_source_settings).and_return(mock_boot_source_settings)
       expect(@fixture.get_boot_sata_disk).to eq("Disk.SATAEmbedded.J-1")
     end

     it "should return any available SATA disk if SATADOM is not found" do
       mock_boot_source_settings = [
           {
               :bios_boot_string=>"NIC in Slot 1 Port 2 Partition 1: IBA XE Slot 0401 v2334 BootSeq",
               :boot_source_type=>"IPL",
               :boot_string=>"NIC in Slot 1 Port 2 Partition 1: IBA XE Slot 0401 v2334 BootSeq",
               :current_assigned_sequence=>"5",
               :current_enabled_status=>"1",
               :instance_id=>"IPL:BIOS.Setup.1-1#BootSeq#NIC.Slot.1-2-1#27d35f79888d0fa3f74312ff1da778fb"
           }
       ]

       mock_physical_disks = <<EOF
        <?xml version="1.0" encoding="UTF-8"?>
        <s:Envelope xmlns:s="http://www.w3.org/2003/05/soap-envelope" xmlns:wsa="http://schemas.xmlsoap.org/ws/2004/08/addressing" xmlns:wsen="http://schemas.xmlsoap.org/ws/2004/09/enumeration" xmlns:n1="http://schemas.dell.com/wbem/wscim/1/cim-schema/2/DCIM_PhysicalDiskView">
        <s:Body>
        <wsen:PullResponse>
          <wsen:Items>
            <n1:DCIM_PhysicalDiskView>
              <n1:FQDD>Disk.Direct.5-9:AHCI.Embedded.2-1</n1:FQDD>
              <n1:FreeSizeInBytes>0</n1:FreeSizeInBytes>
              <n1:HotSpareStatus>0</n1:HotSpareStatus>
              <n1:InstanceID>Disk.Direct.5-9:AHCI.Embedded.2-1</n1:InstanceID>
              <n1:BusProtocol>5</n1:BusProtocol>
              <n1:Connector>5</n1:Connector>
              <n1:Slot>5</n1:Slot>
            </n1:DCIM_PhysicalDiskView>
          </wsen:Items>
          <wsen:EndOfSequence/>
        </wsen:PullResponse>
        </s:Body>
        </s:Envelope>
EOF
       ASM::WsMan.stub(:invoke).and_return(mock_physical_disks)
       Puppet::Idrac::Util.stub(:boot_source_settings).and_return(mock_boot_source_settings)
       expect(@fixture.get_boot_sata_disk).to eq("Disk.SATAEmbedded.F-1")
     end
   end

  describe "#get_raid_config_changes" do
    before(:each) do
      export_file_name = File.basename("FOOTAG.xml", ".xml") + "_base.xml"
      og_xml = File.join(@test_config_dir.path, export_file_name)
      xml_doc = Nokogiri::XML(File.read(og_xml)) {|config| config.default_xml.noblanks}
      @fixture.stub(:xml_base).and_return(xml_doc.xpath('/SystemConfiguration').first)
    end

    context "when Embedded Sata HD" do
      before(:each) do
        resource_raid_config = {"virtualDisks"=>
           [{"raidLevel"=>"raid0",
             "physicalDisks"=>["Disk.Direct.1-1:RAID.Embedded.1-1", "Disk.Direct.0-0:RAID.Embedded.1-1"],
             "controller"=>"RAID.Embedded.1-1",
             "configuration"=>{"id"=>"10763ffd-6bea-4edb-9273-57e7259d1fa5", "raidlevel"=>"raid0", "comparator"=>"minimum", "numberofdisks"=>"1", "disktype"=>"any"},
             "mediatype"=>"ANY"}],
         "hddHotSpares"=>[],
         "ssdHotSpares"=>[],
         "externalVirtualDisks"=>[],
         "externalHddHotSpares"=>[],
         "externalSsdHotSpares"=>[]}

        resource = {:ensure => :present, :raid_configuration => resource_raid_config}
        @fixture.instance_variable_set(:@resource, resource)

        raid_config = {"RAID.Embedded.1-1" => {:virtual_disks => [
          {:disks => ["Disk.Direct.1-1:RAID.Embedded.1-1", "Disk.Direct.0-0:RAID.Embedded.1-1"],
           :level => "raid0", :type=>:ssd}], :hotspares=>[], :nonraid=>[]}}

        @fixture.stub(:raid_configuration).and_return(raid_config)
        @fixture.instance_variable_set(:@boot_device, "HD")
        @fixture.stub(:raid_in_sync).and_return(false)
        @fixture.stub(:is_embedded_raid?).and_return(true)
      end

      it "should return the correct hash" do
        raid_changes = @fixture.get_raid_config_changes(@fixture.xml_base)

        expected_changes = {
          "partial" => {"BIOS.Setup.1-1" => {"HddSeq" => "RAID.Embedded.1-1"}},
          "remove" => {"attributes" => {}, "components" => {}},
          "whole" => { "RAID.Embedded.1-1" =>{
            "RAIDresetConfig" => "True",
            "RAIDforeignConfig" => "Clear",
            "Disk.Virtual.0:RAID.Embedded.1-1" => {
              "RAIDaction"=>"Create", "Name"=>"ASM VD0", "Size"=>"0",
              "StripeSize"=>"128", "SpanDepth"=>"1", "SpanLength"=>2,
              "RAIDTypes"=>"RAID 0",
              "IncludedPhysicalDiskID"=> ["Disk.Direct.1-1:RAID.Embedded.1-1", "Disk.Direct.0-0:RAID.Embedded.1-1"]},
            "Disk.Direct.1-1:RAID.Embedded.1-1" => {"RAIDPDState"=>"Ready"},
            "Disk.Direct.0-0:RAID.Embedded.1-1"=>{"RAIDPDState"=>"Ready"}}}
          }
        expect(raid_changes).to eq(expected_changes)
      end
    end

    context "when integrated RAID" do
      before(:each) do
        resource_raid_config = {"virtualDisks"=>
                                  [{"raidLevel"=>"raid0",
                                    "physicalDisks"=>["Disk.Bay.1:Enclosure.Internal.0-1:RAID.Integrated.1-1", "Disk.Bay.0:Enclosure.Internal.0-1:RAID.Integrated.1-1"],
                                    "controller"=>"RAID.Integrated.1-1",
                                    "configuration"=>{"id"=>"10763ffd-6bea-4edb-9273-57e7259d1fa5", "raidlevel"=>"raid0", "comparator"=>"minimum", "numberofdisks"=>"1", "disktype"=>"any"},
                                    "mediatype"=>"ANY"}],
                                "hddHotSpares"=>[],
                                "ssdHotSpares"=>[],
                                "externalVirtualDisks"=>[],
                                "externalHddHotSpares"=>[],
                                "externalSsdHotSpares"=>[]}

        resource = {:ensure => :present, :raid_configuration => resource_raid_config}
        @fixture.instance_variable_set(:@resource, resource)

        raid_config = {"RAID.Integrated.1-1" => {:virtual_disks => [
          {:disks => ["Disk.Bay.1:Enclosure.Internal.0-1:RAID.Integrated.1-1", "Disk.Bay.0:Enclosure.Internal.0-1:RAID.Integrated.1-1"],
           :level => "raid0", :type=>:ssd}], :hotspares=>[], :nonraid=>[]}}

        @fixture.stub(:raid_configuration).and_return(raid_config)
        @fixture.instance_variable_set(:@boot_device, "HD")
        @fixture.stub(:raid_in_sync).and_return(false)
      end

      it "should return the correct hash" do
        raid_changes = @fixture.get_raid_config_changes(@fixture.xml_base)

        expected_changes = {
          "partial" => {"BIOS.Setup.1-1" => {"HddSeq" => "RAID.Integrated.1-1"}},
          "whole" => {
            "RAID.Integrated.1-1" =>{
              "RAIDresetConfig" => "True",
              "RAIDforeignConfig" => "Clear",
              "Disk.Virtual.0:RAID.Integrated.1-1" => {
                "RAIDaction"=>"Create", "Name"=>"ASM VD0", "Size"=>"0",
                "StripeSize"=>"128", "SpanDepth"=>"1", "SpanLength"=>2,
                "RAIDTypes"=>"RAID 0",
                "IncludedPhysicalDiskID"=> [
                  "Disk.Bay.1:Enclosure.Internal.0-1:RAID.Integrated.1-1",
                  "Disk.Bay.0:Enclosure.Internal.0-1:RAID.Integrated.1-1"
                ],
                "RAIDinitOperation" => "Fast",
              },
              "Enclosure.Internal.0-1:RAID.Integrated.1-1" => {
                "Disk.Bay.1:Enclosure.Internal.0-1:RAID.Integrated.1-1" => {"RAIDPDState"=>"Ready"},
                "Disk.Bay.0:Enclosure.Internal.0-1:RAID.Integrated.1-1" => {"RAIDPDState"=>"Ready"}
              }
            }
          },
          "remove" => {"attributes" => {}, "components" => {}},
        }
        expect(raid_changes).to eq(expected_changes)
      end
    end
  end
end
