#! /usr/bin/env ruby
require 'spec_helper'
require 'yaml'
require 'rspec/expectations'
require 'rspec/mocks'
require 'puppet/provider'
require 'fixtures/unit/puppet/provider/import_bios_conf_fixture'
describe "import bios configuration" do
	
	before(:each) do
	
		@fixture=Import_bios_conf_fixture.new
		#@fakeobj=double(@fixture)
		#puts stub(@fixture)
	end
	context "when bios config provider have methods" do
		it "should have a exists method defined for bios config" do
			@fixture.provider.class.instance_method(:exists?).should_not==nil
		end
		it "should have a create method defined for bios config" do
			@fixture.provider.class.instance_method(:create).should_not==nil
		end
		
	end
	context "when import bios configuration is created " do
		it "should import the bios configuration" do
			@fixture.provider.should_receive(:getinstanceid).once.and_return("JID_896466295795")
			@fixture.provider.should_receive(:getjobstatus).once.and_return("Completed")
			@fixture.provider.create
		end
		it "should raise error if job id not created for import bios config" do
			@fixture.provider.should_receive(:getinstanceid).once.and_return("Job ID not created")
			@fixture.provider.should_receive(:getjobstatus).once.and_return("Job ID not created")
			expect{@fixture.provider.create}.to raise_error("Failed to apply BIOS configuration.")
		end
		it "should raise error if job id created for import bios config but failed to get job status" do
			@fixture.provider.should_receive(:getinstanceid).once.and_return("JID_896466295795")
			@fixture.provider.should_receive(:getjobstatus).once.and_return("Job ID not created")
			expect{@fixture.provider.create}.to raise_error("Failed to apply BIOS configuration.")
		end
		it "should raise error if job id created for import bios config and job is failed" do
			@fixture.provider.should_receive(:getinstanceid).once.and_return("JID_896466295795")
			@fixture.provider.should_receive(:getjobstatus).once.and_return("failed")
			expect{@fixture.provider.create}.to raise_error("Failed to apply BIOS configuration.")
		end
	end
end