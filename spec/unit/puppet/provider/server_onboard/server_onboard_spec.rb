require "spec_helper_ext"
require "rspec/expectations"

describe Puppet::Type.type(:server_onboard).provider(:default) do
  let(:resource) { Puppet::Type.type(:server_onboard).new({ :name => "rackserver-ABCD123"}) }

  let(:provider) {resource.provider}

  context "instance validation" do
    it "should have instance object" do
      expect(provider.class).to eq(Puppet::Type::Server_onboard::ProviderDefault)
    end
  end

  context "set credential" do
    it "should raise error when credentials are not set" do
      provider.resource[:credential] = {}
      expect {provider.setup_credential}.to raise_error(/not specified/)
    end

    it "should invoke racadm_set commands for specified credentials" do
      provider.stubs(:racadm_get).with(anything()).returns("foo")
      provider.expects(:racadm_get).times(15)
      provider.stubs(:racadm_set).with(anything()).returns("Object Executed Successfully")
      provider.expects(:racadm_set).times(5)
      provider.resource[:credential] = {"username" => "foo", "password" => "bar"}
      provider.setup_credential
    end
  end

  context "set network type" do
    before(:each) do
      provider.stubs(:config_static_network).with(anything())
    end

    it "should not invoke static config when not specified" do
      provider.expects(:config_static_network).never
      provider.resource[:network_type] = "existing"
      provider.setup_network
    end

    it "should invoke static config when specified" do
      provider.expects(:config_static_network).once
      provider.resource[:networks] = {
        "staticNetworkConfiguration" => {
          "ipAddress" => "1.2.3.4", "subnet" => "1.1.0.0", "gateway" => "1.2.0.1" }
      }
      provider.resource[:network_type] = "static"
      provider.setup_network
    end

    it "should raise error when static type specified without config" do
      provider.expects(:config_static_network).never
      provider.resource[:networks] = {}
      provider.resource[:network_type] = "static"
      expect {provider.setup_network}.to raise_error(/not static/)
    end
  end

  context "set static configuration" do
    before(:each) do
      provider.stubs(:racadm_set).with(anything()).returns("Object Executed Successfully")
      provider.stubs(:racadm_cmd).with(anything()).returns("Object Executed Successfully")
      provider.stubs(:wait_for_ip).with(anything())
      provider.stubs(:wait_for_discover_endpoint).with(anything())
    end

    it "should set only static IP and not dns configs" do
      provider.expects(:racadm_set).never
      provider.expects(:racadm_cmd).once
      provider.expects(:wait_for_ip).once
      provider.expects(:wait_for_discover_endpoint).once
      provider.config_static_network("ipAddress" => "1.2.3.4", "subnet" => "1.1.0.0", "gateway" => "1.2.0.1")
    end

    it "should set static IP and primary dns" do
      provider.expects(:racadm_set).once
      provider.expects(:racadm_cmd).once
      provider.expects(:wait_for_ip).once
      provider.expects(:wait_for_discover_endpoint).once
      provider.config_static_network(
        "ipAddress" => "1.2.3.4", "subnet" => "1.1.0.0", "gateway" => "1.2.0.1", "primaryDns" => "4.5.6.7"
      )
    end

    it "should set static IP and all dsn configs" do
      provider.expects(:racadm_set).times(2)
      provider.expects(:racadm_cmd).once
      provider.expects(:wait_for_ip).once
      provider.expects(:wait_for_discover_endpoint).once
      provider.config_static_network(
        "ipAddress" => "1.2.3.4", "subnet" => "1.1.0.0", "gateway" => "1.2.0.1",
        "primaryDns" => "4.5.6.7", "secondaryDns" => "8.9.10.11"
      )
    end
  end
end
