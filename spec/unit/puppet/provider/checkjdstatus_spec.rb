require 'spec_helper'
require 'puppet/provider/checkjdstatus'
require 'yaml'
require 'rspec/expectations'

describe Puppet::Provider::Checkjdstatus do
	
	before(:each) do
		@idrac_attrib = {
          :ip => '172.17.10.106',
          :username => 'root',
          :password => 'calvin',
          :configxmlfilename => 'FOOTAG.xml',
          :nfsipaddress => '172.28.10.191',
          :enable_npar => 'true',
          :target_boot_device => 'HD',
          :servicetag => 'FOOTAG',
          :nfssharepath => @test_config_dir
        }
		@fixture=Puppet::Provider::Checkjdstatus.new(@idrac_attrib['ip'],@idrac_attrib['username'],@idrac_attrib['password'],@idrac_attrib['dummy_job_id'])
		@fixture.stub(:initialize).and_return("")
		@respjdstatus= <<END
		<?xml version="1.0" encoding="UTF-8"?>
		<s:Envelope xmlns:s="http://www.w3.org/2003/05/soap-envelope" xmlns:wsa="http://schemas.xmlsoap.org/ws/2004/08/addressing" xmlns:n1="http://schemas.dmtf.org/wbem/wscim/1/cim-schema/2/root/dcim/DCIM_LifecycleJob">
		  <s:Header>
			<wsa:To>http://schemas.xmlsoap.org/ws/2004/08/addressing/role/anonymous</wsa:To>
			<wsa:Action>http://schemas.xmlsoap.org/ws/2004/09/transfer/GetResponse</wsa:Action>
			<wsa:RelatesTo>uuid:09b21a27-efcf-1fcf-8002-9f3392565000</wsa:RelatesTo>
			<wsa:MessageID>uuid:9301dff1-efdf-1fdf-81d8-502ed9ddf95c</wsa:MessageID>
		  </s:Header>
		  <s:Body>
			<n1:DCIM_LifecycleJob>
			  <n1:ElapsedTimeSinceCompletion>78</n1:ElapsedTimeSinceCompletion>
			  <n1:InstanceID>JID_896386820311</n1:InstanceID>
			  <n1:JobStartTime>NA</n1:JobStartTime>
			  <n1:JobStatus>Completed</n1:JobStatus>
			  <n1:JobUntilTime>NA</n1:JobUntilTime>
			  <n1:Message>Successfully exported system configuration XML file.</n1:Message>
			  <n1:MessageArguments>NA</n1:MessageArguments>
			  <n1:MessageID>SYS043</n1:MessageID>
			  <n1:Name>Export Configuration</n1:Name>
			  <n1:PercentComplete>100</n1:PercentComplete>
			</n1:DCIM_LifecycleJob>
		  </s:Body>
		</s:Envelope>
END
	@failedresp= <<END
	<?xml version="1.0" encoding="UTF-8"?>
<s:Envelope xmlns:s="http://www.w3.org/2003/05/soap-envelope" xmlns:wsa="http://schemas.xmlsoap.org/ws/2004/08/addressing" xmlns:wsman="http://schemas.dmtf.org/wbem/wsman/1/wsman.xsd">
  <s:Header>
    <wsa:To>http://schemas.xmlsoap.org/ws/2004/08/addressing/role/anonymous</wsa:To>
    <wsa:Action>http://schemas.dmtf.org/wbem/wsman/1/wsman/fault</wsa:Action>
    <wsa:RelatesTo>uuid:243235b0-efcf-1fcf-8002-9f3392565000</wsa:RelatesTo>
    <wsa:MessageID>uuid:ad7be40f-efdf-1fdf-81db-502ed9ddf95c</wsa:MessageID>
  </s:Header>
  <s:Body>
    <s:Fault>
      <s:Code>
        <s:Value>s:Sender</s:Value>
        <s:Subcode>
          <s:Value>wsman:InvalidParameter</s:Value>
        </s:Subcode>
      </s:Code>
      <s:Reason>
        <s:Text xml:lang="en">CMPI_RC_ERR_INVALID_PARAMETER</s:Text>
      </s:Reason>
      <s:Detail>
        <wsman:FaultDetail>http://schemas.dmtf.org/wbem/wsman/1/wsman/faultDetail/MissingValues</wsman:FaultDetail>
      </s:Detail>
    </s:Fault>
  </s:Body>
</s:Envelope>
END
	end
	context " instance validation " do
		it "should have instance object" do
			@fixture.should be_kind_of(Puppet::Provider::Checkjdstatus)
			
		end
		it "should get the instance variable value"  do
			
			@fixture.instance_variable_get(:@ip).should eql(@idrac_attrib['ip'])
			@fixture.instance_variable_get(:@username).should eql(@idrac_attrib['username'])
			@fixture.instance_variable_get(:@password).should eql(@idrac_attrib['password'])
			@fixture.instance_variable_get(:@instanceid).should eql(@idrac_attrib['dummy_job_id'])
		end
		it "should have method " do
			@fixture.class.instance_method(:checkjdstatus).should_not == nil
		end
	end
	context "when checking lc status" do
		it "should job check status job id"  do
		    @fixture.should_receive(:executecmd).once.and_return(@respjdstatus)
			status = @fixture.checkjdstatus
			status.should == "Completed"
		end
		it "should fail if invalid job id passed" do
			@fixture.should_receive(:executecmd).once.and_return(@failedresp)
			expect {@fixture.checkjdstatus}.to raise_error("Job ID not created")
		end
	end
end