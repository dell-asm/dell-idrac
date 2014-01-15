require 'spec_helper'
require 'puppet/provider/exporttemplatexml'
require 'yaml'
require 'rspec/expectations'
describe Puppet::Provider::Exporttemplatexml do
	
	before(:each) do
		@idrac_conf=YAML.load_file(get_configpath('idrac','idrac_config.yml'))
		@idrac_attrib = @idrac_conf['idrac_cred']
		@fixture=Puppet::Provider::Exporttemplatexml.new(@idrac_attrib['ip'],@idrac_attrib['username'],@idrac_attrib['password'],@idrac_attrib['configxmlfilename'],@idrac_attrib['nfsipaddress'],@idrac_attrib['nfssharepath'])
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
			jobid = @fixture.exporttemplatexml
			jobid.should == "JID_896386820311"
		end
		it "should not get Job it if export template fail" do
			 @fixture.should_receive(:commandexe).once.and_return(@failedcommandoutput)
			 expect{ @fixture.exporttemplatexml}.to raise_error("Job ID not created")
		     
		end
	end
end