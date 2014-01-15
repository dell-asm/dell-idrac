#! /usr/bin/env ruby
require 'spec_helper'
require 'yaml'
require 'rspec/expectations'
require 'rspec/mocks'
require 'puppet/provider'
require 'fixtures/unit/puppet/provider/import_raid_conf_fixture'
describe "import raid configuration" do
	before(:each) do
	
		@fixture=Import_raid_conf_fixture.new
	end
	context "when import raid configuration provider have methods" do
		it "should have a exists method defined for import raid configuration" do
			@fixture.provider.class.instance_method(:exists?).should_not==nil
		end
		it "should have a create method defined for import raid configuration" do
			@fixture.provider.class.instance_method(:create).should_not==nil
		end
		
	end
	context "when iimport raid configuration is created " do
		it "should check for lc status retun false" do
			@fixture.provider.should_receive(:lcstatus).once.and_return("0")
			@fixture.provider.exists?.should ==false
		end
		it "should import raid configuration" do
			@fixture.provider.should_receive(:resetconf).once.and_return("")
			@fixture.provider.should_receive(:rebootinstanse).once.and_return("JID_896466295790")
			@fixture.provider.should_receive(:checkjobstatus).once.with("JID_896466295790").and_return("Completed")
			@fixture.provider.should_receive(:applyraidconf).once.and_return("")
			@fixture.provider.should_receive(:rebootinstanse).once.and_return("JID_896466295791")
			@fixture.provider.should_receive(:checkjobstatus).once.with("JID_896466295791").and_return("Completed")
			@fixture.provider.create
		end
		it "should raise error if job id not created for rebootinstanse " do
			@fixture.provider.should_receive(:resetconf).once.and_return("")
			@fixture.provider.should_receive(:rebootinstanse).once.and_return("Failed")
			expect{@fixture.provider.create}.to raise_error("Job ID not created")
		end
		it "should raise error if job id created for import raid configuration but failed to get job status" do
			@fixture.provider.should_receive(:resetconf).once.and_return("")
			@fixture.provider.should_receive(:rebootinstanse).once.and_return("JID_896466295790")
			@fixture.provider.should_receive(:checkjobstatus).once.with("JID_896466295790").and_return("Failed")
			expect{@fixture.provider.create}.to raise_error("Job ID is not created.")
		end
		
		
		
	end
end
