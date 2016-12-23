require "spec_helper"
require "puppet/provider/checkjdstatus"
require "asm/wsman"

describe Puppet::Provider::Checkjdstatus do
  let(:job_id) { "JID_621911093617" }
  let(:wsman) { stub("mock wsman") }
  let(:endpoint) { {:host => "172.17.9.172", :user => "root", :password => "calvin" } }
  let(:check_jd_status) { Puppet::Provider::Checkjdstatus.new(endpoint[:host], endpoint[:user], endpoint[:password], job_id) }

  it "should be a provider" do
    check_jd_status.should be_kind_of(Puppet::Provider::Checkjdstatus)
  end

  it "has class variables" do
    check_jd_status.instance_variable_get(:@ip).should eql(endpoint[:host])
    check_jd_status.instance_variable_get(:@username).should eql(endpoint[:user])
    check_jd_status.instance_variable_get(:@password).should eql(endpoint[:password])
    check_jd_status.instance_variable_get(:@instanceid).should eql(job_id)
  end

  it "should return job_status when successful" do
    ASM::WsMan.should_receive(:new).with(endpoint, :logger => Puppet).once.and_return(wsman)
    wsman.should_receive(:get_lc_job).with(job_id)
        .once.and_return(:job_status => "Completed", :message => "Successfully exported system configuration XML file.", :message_id => "SYS043")
    check_jd_status.checkjdstatus.should == "Completed"
  end

  it "should return SYS051 when message_id is SYS051" do
    ASM::WsMan.should_receive(:new).with(endpoint, :logger => Puppet).once.and_return(wsman)
    wsman.should_receive(:get_lc_job).with(job_id).once.and_return(:message_id => "SYS051")
    check_jd_status.checkjdstatus.should == "SYS051"
  end

  it "should return LC068 message_id is LC068" do
    ASM::WsMan.should_receive(:new).with(endpoint, :logger => Puppet).once.and_return(wsman)
    wsman.should_receive(:get_lc_job).with(job_id).once.and_return(:message_id => "LC068")
    check_jd_status.checkjdstatus.should == "LC068"
  end

  it "should return Failed if job_status is completed with errors and 100% complete" do
    ASM::WsMan.should_receive(:new).with(endpoint, :logger => Puppet).once.and_return(wsman)
    wsman.should_receive(:get_lc_job).with(job_id).once.and_return(:job_status => "completed with errors", :percent_complete => "100")
    check_jd_status.checkjdstatus.should == "Failed"
  end

  it "should return Failed if job_message is completed with errors and 100% complete" do
    ASM::WsMan.should_receive(:new).with(endpoint, :logger => Puppet).once.and_return(wsman)
    wsman.should_receive(:get_lc_job).with(job_id).once.and_return(:message => "completed with errors", :percent_complete => "100")
    check_jd_status.checkjdstatus.should == "Failed"
  end

  it "should return job_status if failed but not 100% complete" do
    ASM::WsMan.should_receive(:new).with(endpoint, :logger => Puppet).once.and_return(wsman)
    wsman.should_receive(:get_lc_job).with(job_id).once.and_return(:job_status => "Running")
    check_jd_status.checkjdstatus.should == "Running"
  end

  it "should raise an error when job_status is an empty string" do
    ASM::WsMan.should_receive(:new).with(endpoint, :logger => Puppet).once.and_return(wsman)
    wsman.should_receive(:get_lc_job).with(job_id).once.and_return(:job_status => "")
    expect { check_jd_status.checkjdstatus }.to raise_error(RuntimeError, "Job ID not created")
  end

  it "should raise an error when job_status is nil" do
    ASM::WsMan.should_receive(:new).with(endpoint, :logger => Puppet).once.and_return(wsman)
    wsman.should_receive(:get_lc_job).with(job_id).once.and_return(:job_status => "")
    expect { check_jd_status.checkjdstatus }.to raise_error(RuntimeError, "Job ID not created")
  end

end
