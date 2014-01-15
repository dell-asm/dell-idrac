#! /usr/bin/env ruby
require 'spec_helper'
require 'yaml'
require 'rspec/expectations'
require 'rspec/mocks'
require 'puppet/provider'
require 'fixtures/unit/puppet/provider/import_system_conf_fixture'
describe "import system configuration" do
	before(:each) do
	
		@fixture=Import_system_conf_fixture.new
	end
	context "when import system configuration provider have methods" do
		it "should have a exists method defined for import system configuration" do
			@fixture.provider.class.instance_method(:exists?).should_not==nil
		end
		it "should have a create method defined for import system configuration" do
			@fixture.provider.class.instance_method(:create).should_not==nil
		end
	end
	context "when iimport system configuration is created " do
		it "should check for lc status retun false" do
			@fixture.provider.should_receive(:lcstatus).once.and_return("0")
			@fixture.provider.exists?.should ==false
		end
		it "should import system configuration" do
			@fixture.provider.should_receive(:importtemplate).once.and_return("JID_896466295795")
			@fixture.provider.should_receive(:checkjobstatus).once.with("JID_896466295795").and_return("Completed")
			@fixture.provider.create
		end
		it "should raise error if job id not created for import system configuration " do
			@fixture.provider.should_receive(:importtemplate).once.and_return("Job ID not created")
			@fixture.provider.should_receive(:checkjobstatus).once.with("Job ID not created").and_return("Failed")
			expect{@fixture.provider.create}.to raise_error("Job ID is not created.")
		end
		it "should raise error if job id created for import system configuration but failed to get job status" do
			@fixture.provider.should_receive(:importtemplate).once.and_return("JID_896466295795")
			@fixture.provider.should_receive(:checkjobstatus).once.with("JID_896466295795").and_return("Failed")
			expect{@fixture.provider.create}.to raise_error("Job ID is not created.")
		end
		
	end
end
