#! /usr/bin/env ruby
require 'spec_helper'
require 'yaml'
require 'rspec/expectations'
require 'rspec/mocks'
require 'puppet/provider'
require 'fixtures/unit/puppet/provider/export_system_config_fixture'
describe "import bios configuration" do
	
	before(:each) do
	
		@fixture=Export_system_conf_fixture.new
	end
	context "when system config provider have methods" do
		it "should have a exists method defined for system config" do
			@fixture.provider.class.instance_method(:exists?).should_not==nil
		end
		it "should have a create method defined for system config" do
			@fixture.provider.class.instance_method(:create).should_not==nil
		end
		
	end
	context "when export system configuration is created " do
		it "should check for lc status retun false" do
			@fixture.provider.should_receive(:lcstatus).once.and_return("0")
			@fixture.provider.exists?.should ==false
		end
		it "should export system configuration" do
			@fixture.provider.should_receive(:exporttemplate).once.and_return("JID_896466295795")
			@fixture.provider.should_receive(:checkjobstatus).once.and_return("Completed")
			@fixture.provider.create
		end
		it "should raise error if job id not created for export template config  failed" do
			@fixture.provider.should_receive(:exporttemplate).once.and_return("Job ID not created")
			@fixture.provider.should_receive(:checkjobstatus).once.and_return("Failed")
			expect{@fixture.provider.create}.to raise_error("Job ID is not created.")
		end
		it "should raise error if job id created for export system config but failed to get job status" do
			@fixture.provider.should_receive(:exporttemplate).once.and_return("JID_896466295795")
			@fixture.provider.should_receive(:checkjobstatus).twice.and_return("Job ID not created","Failed")
			expect{@fixture.provider.create}.to raise_error("Job ID is not created.")
		end
		
		
	end
	
	
end