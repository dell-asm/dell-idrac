require "spec_helper"
require "discovery"
include RSpec::Mocks::ExampleMethods

describe Idrac::Discovery do

  let(:idrac_discovery) { Idrac::Discovery.new({:server => "172.17.2.175",
                                                :credential_id => "ff808081531a089801531a0a9eff0009"
                                               }) }

  it "should be a Idrac::Discovery" do
    expect(idrac_discovery).to be_a(Idrac::Discovery)
  end

  it "should submit a discovery request with asm_manager" do
    ASM::Api = double("ASM::Api", :sign => "{\"refId\" : \"ff80808154a0d0d20154bafc99861b54\"}")
    STDERR.should_receive(:puts).with("Idrac::Discovery received refId: ff80808154a0d0d20154bafc99861b54 from /AsmManager/ServerDiscoveryRequest")
    idrac_discovery.asm_manager_server_discovery_request.should == "ff80808154a0d0d20154bafc99861b54"
  end

  it "should start discovery on ASM with java_resource_adapter_framework_discovery " do
    ASM::Api = double("ASM::Api", :sign => "{\"jobName\" : \"Job-eb346c6c-620c-4281-bf45-d2c587261057\"}")
    STDERR.should_receive(:puts).with("Idrac::Discovery received jobName: Job-eb346c6c-620c-4281-bf45-d2c587261057 from /JRAF/discovery")
    idrac_discovery.java_resource_adapter_framework_discovery.should == "Job-eb346c6c-620c-4281-bf45-d2c587261057"
    idrac_discovery.discovery_job_name.should == "Job-eb346c6c-620c-4281-bf45-d2c587261057"
  end

  it "should return nil when checking job status and there is not a discovery job name" do
    idrac_discovery.job_status.should be_nil
  end

  it "should return a job status" do
    ASM::Api = double("ASM::Api", :sign => "\"IN_PROGRESS\"")
    idrac_discovery.discovery_job_name = "Job-eb346c6c-620c-4281-bf45-d2c587261057"
    idrac_discovery.job_status.should == "\"IN_PROGRESS\""
  end

  it "should return the refId from the discovery result" do
    discovery_xml = File.read(File.expand_path("spec/fixtures/discovery_result.xml"))
    ASM::Api = double("ASM::Api", :sign => discovery_xml)
    STDERR.should_receive(:puts).with("Idrac::Discovery received refId: ff8080815471c3b50154a0cb562233d7 from /JRAF/discovery/Job-eb346c6c-620c-4281-bf45-d2c587261057/devices")
    idrac_discovery.discovery_job_name = "Job-eb346c6c-620c-4281-bf45-d2c587261057"
    idrac_discovery.get_discovered_devices.should == "ff8080815471c3b50154a0cb562233d7"
  end

  it "should use the reference id to get device information" do
    ASM::Api = double("ASM::Api", :sign => "json")
    STDERR.should_receive(:puts).with("Idrac::Discovery getting server json from /AsmManager/Server/ff8080815471c3b50154a0cb562233d7")
    idrac_discovery.reference_id = "ff8080815471c3b50154a0cb562233d7"
    idrac_discovery.asm_manager_server.should == "json"
  end

  it "should timeout" do
    STDERR.should_receive(:puts).with("Idrac::Discovery Waiting for discovery to complete. Timeout: -1 seconds Job status is ")
    idrac_discovery.timeout=0
    start_time=DateTime.now
    sleep 1
    expect { idrac_discovery.check_timeout(start_time) }.to raise_error
  end

  it "should set timeout to 1800 seconds or 30 minutes by default" do
    idrac_discovery.timeout.should==1800
  end


end
