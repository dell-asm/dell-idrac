require "spec_helper_ext"
require "rspec/expectations"
require "puppet/provider/idrac_racadm"

describe Puppet::Provider::IdracRacadm do
  context "instance validation" do
    let(:racadm) { Puppet::Provider::IdracRacadm.new }
    let(:ssh) { Object.new }

    it "should have instance object" do
      expect(racadm.class).to eq(Puppet::Provider::IdracRacadm)
    end
  end

  context "#racadm_cmd" do
    let(:racadm) { Puppet::Provider::IdracRacadm.new }
    let(:ssh) { "rspec" }

    it "should execute fine for successful command having params" do
      ssh.stubs(:exec!).with("racadm cmd foo bar").returns("Object executed successfully")
      racadm.stubs(:client).returns(ssh)
      expect(racadm.racadm_cmd("cmd", ["foo", "bar"] )).to eq("Object executed successfully")
    end

    it "should fail when command errors and raise on err is specified" do
      ssh.stubs(:exec!).returns("ERROR: Something went wrong")
      racadm.stubs(:client).returns(ssh)
      expect {racadm.racadm_cmd("cmd", [], :raise_on_err => true)}.to raise_error(/Error in racadm command/)
    end

    it "should return an array for command that returns multi-line output" do
      ssh.stubs(:exec!).returns("Result\nGood")
      racadm.stubs(:client).returns(ssh)
      expect(racadm.racadm_cmd("cmd", [], :raise_on_err => true)).to eq(["Result", "Good"])
    end
  end
end
