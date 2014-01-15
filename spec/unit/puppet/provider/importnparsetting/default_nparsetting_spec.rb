#! /usr/bin/env ruby
require 'spec_helper'
require 'yaml'
require 'rspec/expectations'
require 'rspec/mocks'
require 'puppet/provider'
require 'fixtures/unit/puppet/provider/import_npar_conf_fixture'
describe "import npar setting" do
	before(:each) do
	
		@fixture=Import_npar_conf_fixture.new
	end
	
	context "when npar setting provider have methods" do
		it "should have a exists method defined for npar setting" do
			@fixture.provider.class.instance_method(:exists?).should_not==nil
		end
		it "should have a create method defined for npar setting" do
			@fixture.provider.class.instance_method(:create).should_not==nil
		end
		
	end
	
	context "when npar setting is created " do
		it "should check for lc status retun false" do
			@fixture.provider.should_receive(:lcstatus).once.and_return("0")
			@fixture.provider.exists?.should ==false
		end
		it "should import npar setting" do
			@fixture.provider.should_receive(:importtemplate).once.and_return("JID_896466295795")
			@fixture.provider.should_receive(:checkjobstatus).once.and_return("Completed")
			@fixture.provider.create
		end
		it "should raise error if job id not created for import npar setting  " do
			@fixture.provider.should_receive(:importtemplate).once.and_return("Job ID not created")
			@fixture.provider.should_receive(:checkjobstatus).once.and_return("Job ID not created")
			expect{@fixture.provider.create}.to raise_error("Failed to apply NPAR settings configuration.")
		end
		it "should raise error if job id created for import npar setting but failed to get job status" do
			@fixture.provider.should_receive(:importtemplate).once.and_return("JID_896466295795")
			@fixture.provider.should_receive(:checkjobstatus).once.and_return("Job ID not created")
			expect{@fixture.provider.create}.to raise_error("Failed to apply NPAR settings configuration.")
		end
		it "should raise error if job id created for import npar setting and job is failed" do
			@fixture.provider.should_receive(:importtemplate).once.and_return("JID_896466295795")
			@fixture.provider.should_receive(:checkjobstatus).once.and_return("failed")
			expect{@fixture.provider.create}.to raise_error("Failed to apply NPAR settings configuration.")
		end
		
		
	end
end
