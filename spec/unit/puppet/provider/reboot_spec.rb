require 'spec_helper'
require 'puppet/provider/reboot'
require 'yaml'
require 'rspec/expectations'
describe Puppet::Provider::Reboot do
	before(:each) do
		@idrac_conf=YAML.load_file(get_configpath('idrac','idrac_config.yml'))
		@idrac_attrib = @idrac_conf['idrac_cred']
		@fixture=Puppet::Provider::Reboot.new(@idrac_attrib['ip'],@idrac_attrib['username'],@idrac_attrib['password'],@idrac_attrib['rebootfilepath'])
		@fixture.stub(:initialize).and_return("")
		@responseoutput = <<END
		
<?xml version="1.0" encoding="UTF-8"?>
<s:Envelope xmlns:s="http://www.w3.org/2003/05/soap-envelope" xmlns:wsa="http://schemas.xmlsoap.org/ws/2004/08/addressing" xmlns:n1="http://schemas.dmtf.org/wbem/wscim/1/cim-schema/2/root/dcim/DCIM_LCService" xmlns:wsman="http://schemas.dmtf.org/wbem/wsman/1/wsman.xsd">
  <s:Header>
    <wsa:To>http://schemas.xmlsoap.org/ws/2004/08/addressing/role/anonymous</wsa:To>
    <wsa:Action>http://schemas.dmtf.org/wbem/wscim/1/cim-schema/2/root/dcim/DCIM_LCService/ImportSystemConfigurationResponse</wsa:Action>
    <wsa:RelatesTo>uuid:c8687f4e-efcf-1fcf-8002-9f3392565000</wsa:RelatesTo>
    <wsa:MessageID>uuid:51b947e2-efe0-1fe0-81e0-502ed9ddf95c</wsa:MessageID>
  </s:Header>
  <s:Body>
	<n1:CreateTargetedConfigJob_OUTPUT>
		<n1:Job>
		<wsa:Address>http://schemas.xmlsoap.org/ws/2004/08/addressing/role/anonymous</wsa:Address>
		<wsa:ReferenceParameters>
			<wsman:ResourceURI>http://schemas.dell.com/wbem/wscim/1/cimschema/2/DCIM_LifecycleJob</wsman:ResourceURI>
			<wsman:SelectorSet>
			<wsman:Selector Name="InstanceID">JID_001300633744</wsman:Selector>
			<wsman:Selector Name="__cimnamespace">root/dcim</wsman:Selector>
			</wsman:SelectorSet>
			</wsa:ReferenceParameters>
		</n1:Job>
		<n1:ReturnValue>4096</n1:ReturnValue>
	</n1:CreateTargetedConfigJob_OUTPUT>
	</s:Body>
</s:Envelope>
END
		@failedoutput= <<END
		<?xml version="1.0" encoding="UTF-8"?>
<s:Envelope xmlns:s="http://www.w3.org/2003/05/soap-envelope" xmlns:wsa="http://schemas.xmlsoap.org/ws/2004/08/addressing" xmlns:n1="http://schemas.dmtf.org/wbem/wscim/1/cim-schema/2/root/dcim/DCIM_RAIDService">
  <s:Header>
    <wsa:To>http://schemas.xmlsoap.org/ws/2004/08/addressing/role/anonymous</wsa:To>
    <wsa:Action>http://schemas.dmtf.org/wbem/wscim/1/cim-schema/2/root/dcim/DCIM_RAIDService/CreateTargetedConfigJobResponse</wsa:Action>
    <wsa:RelatesTo>uuid:62a74741-efd0-1fd0-8002-9f3392565000</wsa:RelatesTo>
    <wsa:MessageID>uuid:ebe49422-efe0-1fe0-8201-502ed9ddf95c</wsa:MessageID>
  </s:Header>
  <s:Body>
    <n1:CreateTargetedConfigJob_OUTPUT>
      <n1:Message>Configuration Job not Created, there are no pending Configuration changes</n1:Message>
      <n1:MessageID>STOR026</n1:MessageID>
      <n1:ReturnValue>2</n1:ReturnValue>
    </n1:CreateTargetedConfigJob_OUTPUT>
  </s:Body>
</s:Envelope>
END
	end
	context " instance validation " do
		it "should have instance object" do
			@fixture.should be_kind_of(Puppet::Provider::Reboot)
			
		end
		it "should get the instance variable value"  do
			
			@fixture.instance_variable_get(:@ip).should eql(@idrac_attrib['ip'])
			@fixture.instance_variable_get(:@username).should eql(@idrac_attrib['username'])
			@fixture.instance_variable_get(:@password).should eql(@idrac_attrib['password'])
			@fixture.instance_variable_get(:@rebootfilepath).should eql(@idrac_attrib['rebootfilepath'])
		end
		it "should have method " do
			@fixture.class.instance_method(:reboot).should_not == nil
		end
	end
	context "when reboot" do
		it "should get Job id for rebooting"  do
			@fixture.should_receive(:executerebootcmd).once.and_return(@responseoutput)
			jobid = @fixture.reboot
			jobid.should == "JID_001300633744"
		end
		it "should not get Job id if no pending Configuration changes" do
			@fixture.should_receive(:executerebootcmd).once.and_return(@failedoutput)
			expect{ @fixture.reboot}.to raise_error("Job ID not created")
		     
		end
	end
end