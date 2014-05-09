require 'spec_helper'
require 'puppet/provider/exporttemplatexml'
require 'yaml'
require 'rspec/expectations'
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
		@fixture=Puppet::Provider::Exporttemplatexml.new(@idrac_attrib['ip'],@idrac_attrib['username'],@idrac_attrib['password'],@idrac_attrib,File.join(test_config_dir, "mock_nfs"))
		@fixture.stub(:initialize).and_return("")
		@commandoutput = <<END
		<?xml version="1.0" encoding="UTF-8"?>
<s:Envelope xmlns:s="http://www.w3.org/2003/05/soap-envelope" xmlns:wsa="http://schemas.xmlsoap.org/ws/2004/08/addressing" xmlns:n1="http://schemas.dmtf.org/wbem/wscim/1/cim-schema/2/root/dcim/DCIM_LCService" xmlns:wsman="http://schemas.dmtf.org/wbem/wsman/1/wsman.xsd">
  <s:Header>
    <wsa:To>http://schemas.xmlsoap.org/ws/2004/08/addressing/role/anonymous</wsa:To>
    <wsa:Action>http://schemas.dmtf.org/wbem/wscim/1/cim-schema/2/root/dcim/DCIM_LCService/ExportSystemConfigurationResponse</wsa:Action>
    <wsa:RelatesTo>uuid:eea1d72e-efcd-1fcd-8002-9f3392565000</wsa:RelatesTo>
    <wsa:MessageID>uuid:7803a3f2-efde-1fde-81d7-502ed9ddf95c</wsa:MessageID>
  </s:Header>
  <s:Body>
    <n1:ExportSystemConfiguration_OUTPUT>
      <n1:Job>
        <wsa:EndpointReference>
          <wsa:Address>http://schemas.xmlsoap.org/ws/2004/08/addressing/role/anonymous</wsa:Address>
          <wsa:ReferenceParameters>
            <wsman:ResourceURI>http://schemas.dell.com/wbem/wscim/1/cim-schema/2/DCIM_LifeCycleJob</wsman:ResourceURI>
            <wsman:SelectorSet>
              <wsman:Selector Name="InstanceID">JID_896386820311</wsman:Selector>
              <wsman:Selector Name="__cimnamespace">root/dcim</wsman:Selector>
            </wsman:SelectorSet>
          </wsa:ReferenceParameters>
        </wsa:EndpointReference>
      </n1:Job>
      <n1:ReturnValue>4096</n1:ReturnValue>
    </n1:ExportSystemConfiguration_OUTPUT>
  </s:Body>
</s:Envelope>
END
	@failedcommandoutput = <<END
	<?xml version="1.0" encoding="UTF-8"?>
<s:Envelope xmlns:s="http://www.w3.org/2003/05/soap-envelope" xmlns:wsa="http://schemas.xmlsoap.org/ws/2004/08/addressing" xmlns:wsman="http://schemas.dmtf.org/wbem/wsman/1/wsman.xsd">
  <s:Header>
    <wsa:To>http://schemas.xmlsoap.org/ws/2004/08/addressing/role/anonymous</wsa:To>
    <wsa:Action>http://schemas.dmtf.org/wbem/wsman/1/wsman/fault</wsa:Action>
    <wsa:RelatesTo>uuid:da4b90fc-efcd-1fcd-8002-9f3392565000</wsa:RelatesTo>
    <wsa:MessageID>uuid:6fb8c614-efde-1fde-8083-562ed9ddf95c</wsa:MessageID>
  </s:Header>
  <s:Body>
    <s:Fault>
      <s:Code>
        <s:Value>s:Receiver</s:Value>
        <s:Subcode>
          <s:Value>wsman:TimedOut</s:Value>
        </s:Subcode>
      </s:Code>
      <s:Reason>
        <s:Text xml:lang="en">The operation has timed out.</s:Text>
      </s:Reason>
    </s:Fault>
  </s:Body>
</s:Envelope>

END
	end
	
	context " instance validation " do
		it "should have instance object" do
			@fixture.should be_kind_of(Puppet::Provider::Exporttemplatexml)
			
		end
		it "should get the instance variable value"  do
			
			@fixture.instance_variable_get(:@ip).should eql(@idrac_attrib['ip'])
			@fixture.instance_variable_get(:@username).should eql(@idrac_attrib['username'])
			@fixture.instance_variable_get(:@password).should eql(@idrac_attrib['password'])
			@fixture.instance_variable_get(:@configxmlfilename).should eql(@idrac_attrib['configxmlfilename'])
			@fixture.instance_variable_get(:@nfsipaddress).should eql(@idrac_attrib['nfsipaddress'])
			@fixture.instance_variable_get(:@nfssharepath).should eql(@idrac_attrib['nfssharepath'])
		end
		it "should have method " do
			@fixture.class.instance_method(:exporttemplatexml).should_not == nil
		end
	end
	context "when exporting template" do
		it "should get Job id for Export template xml"  do
			@fixture.should_receive(:commandexe).once.and_return(@commandoutput)

			Puppet::Provider::Checkjdstatus.any_instance.stub(:checkjdstatus) do
				xml_doc = Nokogiri::XML::Builder.new do |xml|
					xml.send(:"SystemConfiguration")
				end
				File.open(File.join(test_config_dir, "mock_nfs", "EXPORT.xml"), 'w+') { |file| file.write(xml_doc.to_xml(:indent => 2)) }
				"Completed"	
			end
			jobid = @fixture.exporttemplatexml
			jobid.should == "JID_896386820311"
			File.exist?(File.join(test_config_dir, "EXPORT.xml")).should == true
			File.exist?(File.join(test_config_dir, "mock_nfs", "EXPORT.xml")).should_not == true

		end
		it "should not get Job it if export template fail" do
			 @fixture.should_receive(:commandexe).once.and_return(@failedcommandoutput)
			 expect{ @fixture.exporttemplatexml}.to raise_error("Job ID not created")
		     
		end

		after(:all) do
			FileUtils.rm(File.join(test_config_dir, "EXPORT.xml"))
		end
	end
end
