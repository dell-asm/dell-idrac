require "spec_helper"
require "puppet/provider/checkjdstatus"
require "asm/wsman"

describe Puppet::Provider::Checkjdstatus do
  let(:check_jd_status) { Puppet::Provider::Checkjdstatus.new("172.17.9.172",
                                                              "root",
                                                              "calvin",
                                                              "JID_621911093617") }
  it "should be a provider" do
    check_jd_status.should be_kind_of(Puppet::Provider::Checkjdstatus)
  end

  it "has class variables" do
    check_jd_status.instance_variable_get(:@ip).should eql("172.17.9.172")
    check_jd_status.instance_variable_get(:@username).should eql("root")
    check_jd_status.instance_variable_get(:@password).should eql("calvin")
    check_jd_status.instance_variable_get(:@instanceid).should eql("JID_621911093617")
  end

  it "should ASM::WsMan.invoke with initalized variables" do
    ASM::WsMan.should_receive(:invoke).with({:host => "172.17.9.172", :user => "root", :password => "calvin"},
                                            "get",
                                            "http://schemas.dmtf.org/wbem/wscim/1/cim-schema/2/root/dcim/DCIM_LifecycleJob?InstanceID=JID_621911093617",
                                            :logger => Puppet,
                                            :selector => ["//n1:JobStatus", "//n1:Message", "//n1:MessageID"]
    ).once.and_return(["Completed",
                       "Successfully exported system configuration XML file.",
                       "SYS043"])
    check_jd_status.checkjdstatus.should == "Completed"
  end

  it "should return job_status when successful" do
    ASM::WsMan.should_receive(:invoke).once.and_return(["Completed", "Successfully exported system configuration XML file.", "SYS043"])
    check_jd_status.checkjdstatus.should == "Completed"
  end

  it "should return SYS051 when message_id is SYS051" do
    ASM::WsMan.should_receive(:invoke).once.and_return(["", "", "SYS051"])
    check_jd_status.checkjdstatus.should == "SYS051"
  end

  it "should return LC068 message_id is LC068" do
    ASM::WsMan.should_receive(:invoke).once.and_return(["", "", "LC068"])
    check_jd_status.checkjdstatus.should == "LC068"
  end

  it "should return Failed if job_status is completed with errors" do
    ASM::WsMan.should_receive(:invoke).once.and_return(["completed with errors", "", ""])
    check_jd_status.checkjdstatus.should == "Failed"
  end

  it "should return Failed if job_message is completed with errors" do
    ASM::WsMan.should_receive(:invoke).once.and_return(["", "completed with errors", ""])
    check_jd_status.checkjdstatus.should == "Failed"
  end

  it "should raise an error when job_status is an empty string" do
    ASM::WsMan.should_receive(:invoke).once.and_return(["", "", ""])
    expect { check_jd_status.checkjdstatus }.to raise_error(RuntimeError, "Job ID not created")
  end

  it "should raise an error when job_status is nil" do
    ASM::WsMan.should_receive(:invoke).once.and_return([nil, "", ""])
    expect { check_jd_status.checkjdstatus }.to raise_error(RuntimeError, "Job ID not created")
  end

end
