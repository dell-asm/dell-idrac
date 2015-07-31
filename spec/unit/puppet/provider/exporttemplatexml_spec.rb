require 'spec_helper'
require 'puppet/provider/exporttemplatexml'
require 'yaml'
require 'rspec/expectations'
require 'asm/wsman'
require 'nokogiri'
require 'puppet/idrac/util'

describe Puppet::Provider::Exporttemplatexml do
	let(:test_config_dir){ File.join(Dir.pwd, "spec", "fixtures") }
	before(:each) do
		Puppet::Module.stub(:find).with("idrac").and_return(test_config_dir)
		@idrac_attrib = {
          :ip => '172.17.10.106',
          :username => 'root',
          :password => 'calvin',
          :configxmlfilename => 'EXPORT.xml',
          :nfsipaddress => '172.28.10.191',
          :enable_npar => 'true',
          :target_boot_device => 'HD',
          :servicetag => 'EXPORT',
          :nfssharepath => test_config_dir
        }
		@fixture=Puppet::Provider::Exporttemplatexml.new(@idrac_attrib[:ip],@idrac_attrib[:username],@idrac_attrib[:password], @idrac_attrib,File.join(test_config_dir, "mock_nfs"))
		@fixture.stub(:initialize).and_return("")
	end

	context " instance validation " do
		it "should have instance object" do
			@fixture.should be_kind_of(Puppet::Provider::Exporttemplatexml)

		end
		it "should get the instance variable value"  do

			@fixture.instance_variable_get(:@ip).should eql(@idrac_attrib[:ip])
			@fixture.instance_variable_get(:@username).should eql(@idrac_attrib[:username])
			@fixture.instance_variable_get(:@password).should eql(@idrac_attrib[:password])
			#@fixture.instance_variable_get(:@file_name).should eql(@idrac_attrib[:configxmlfilename])
			#@fixture.instance_variable_get(:@nfsipaddress).should eql(@idrac_attrib[:nfsipaddress])
			@fixture.instance_variable_get(:@nfswritepath).should eql(File.join(test_config_dir, "mock_nfs"))
		end
		it "should have method " do
			@fixture.class.instance_method(:exporttemplatexml).should_not == nil
		end
	end
	context "when exporting template" do
		it "should get Job id for Export template xml"  do
      ASM::WsMan.should_receive(:invoke).and_return('<Selector Name="InstanceID">JID_896386820311</Selector>')
      Puppet::Idrac::Util.stub(:wait_or_clear_running_jobs).and_return(nil)

      Puppet::Provider::Checkjdstatus.any_instance.stub(:checkjdstatus) do
				xml_doc = Nokogiri::XML::Builder.new do |xml|
					xml.send(:"SystemConfiguration")
				end
				File.open(File.join(test_config_dir, "mock_nfs", "EXPORT_original.xml"), 'w+') { |file| file.write(xml_doc.to_xml(:indent => 2)) }
				"Completed"
			end
			jobid = @fixture.exporttemplatexml
			jobid.should == "JID_896386820311"
			File.exist?(File.join(test_config_dir, "EXPORT_original.xml")).should == true
			File.exist?(File.join(test_config_dir, "mock_nfs", "EXPORT_original.xml")).should_not == true

		end
		it "should not get Job it if export template fail" do
      Puppet::Idrac::Util.stub(:wait_or_clear_running_jobs).and_return(nil)
			ASM::WsMan.should_receive(:invoke).and_return(nil)
			 expect{ @fixture.exporttemplatexml}.to raise_error("ExportSystemConfiguration Job could not be created:  Response is invalid")

		end

		after(:all) do
			FileUtils.rm(File.join(File.join(Dir.pwd, "spec", "fixtures"), "EXPORT_original.xml"), :force=>true)
			FileUtils.rm(File.join(File.join(Dir.pwd, "spec", "fixtures"), "EXPORT.xml"), :force=>true)
		end
	end
end
