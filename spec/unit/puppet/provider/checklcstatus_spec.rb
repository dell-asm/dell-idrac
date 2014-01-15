require 'spec_helper'
require 'puppet/provider/checklcstatus'
require 'yaml'
require 'rspec/expectations'

describe Puppet::Provider::Checklcstatus do
	
	
	before(:each) do
		@idrac_conf=YAML.load_file(get_configpath('idrac','idrac_config.yml'))
		@idrac_attrib = @idrac_conf['idrac_cred']

		@fixture=Puppet::Provider::Checklcstatus.new(@idrac_attrib['ip'],@idrac_attrib['username'],@idrac_attrib['password'])
		@fixture.stub(:initialize).and_return("")
		@response= <<END
		<?xml version="1.0" encoding="UTF-8"?>
<s:Envelope xmlns:s="http://www.w3.org/2003/05/soap-envelope" xmlns:wsa="http://schemas.xmlsoap.org/ws/2004/08/addressing" xmlns:n1="http://schemas.dmtf.org/wbem/wscim/1/cim-schema/2/root/dcim/DCIM_LCService">
  <s:Header>
    <wsa:To>http://schemas.xmlsoap.org/ws/2004/08/addressing/role/anonymous</wsa:To>
    <wsa:Action>http://schemas.dmtf.org/wbem/wscim/1/cim-schema/2/root/dcim/DCIM_LCService/GetRemoteServicesAPIStatusResponse</wsa:Action>
    <wsa:RelatesTo>uuid:4b836feb-efcf-1fcf-8002-9f3392565000</wsa:RelatesTo>
    <wsa:MessageID>uuid:d4e10863-efdf-1fdf-81de-502ed9ddf95c</wsa:MessageID>
  </s:Header>
  <s:Body>
    <n1:GetRemoteServicesAPIStatus_OUTPUT>
      <n1:LCStatus>0</n1:LCStatus>
      <n1:Message>Lifecycle Controller Remote Services is ready.</n1:Message>
      <n1:MessageID>LC061</n1:MessageID>
      <n1:ReturnValue>0</n1:ReturnValue>
      <n1:ServerStatus>2</n1:ServerStatus>
      <n1:Status>0</n1:Status>
    </n1:GetRemoteServicesAPIStatus_OUTPUT>
  </s:Body>
</s:Envelope>
END
	end
	
	after(:each) do
	
	end
	context " instance validation " do
		it "should have instance object" do
			@fixture.should be_kind_of(Puppet::Provider::Checklcstatus)
			
		end
		it "should get the instance variable value"  do
			
			@fixture.instance_variable_get(:@ip).should eql(@idrac_attrib['ip'])
			@fixture.instance_variable_get(:@username).should eql(@idrac_attrib['username'])
			@fixture.instance_variable_get(:@password).should eql(@idrac_attrib['password'])
		end
		it "should have method " do
			@fixture.class.instance_method(:checklcstatus).should_not == nil
		end
	end
	
	context "when checking lc status" do
		it "should lc check status retun value"  do
			@fixture.should_receive(:executelccmd).once.and_return(@response)
			status = @fixture.checklcstatus
			status.should == "0"
		end
		
	end
	
end