#! /usr/bin/env ruby
require 'spec_helper'

describe Puppet::Type.type(:importraidconfiguration) do
	
	raid_conf=YAML.load_file(get_configpath('idrac','raid_config.yml'))
	raid_attrib = raid_conf['raid_configuration_type']
	
let(:title) { 'importraidconfiguration' }
	context "should compile with given test params"  do 

    let(:params) {{
           :ensure			=> raid_attrib['ensure'],
           :name            => raid_attrib['name'],
           :dracipaddress   => raid_attrib['dracipaddress'],
           :dracusername    => raid_attrib['dracusername'],
           :dracpassword    => raid_attrib['dracpassword'],
           :raidtype        => raid_attrib['raidtype'], 
           :nfsipaddress    => raid_attrib['nfsipaddress'],
           :nfssharepath    => raid_attrib['nfssharepath'],
           :disk            => raid_attrib['disk']
    } }
    it do
        expect { should compile }
	end 
   end  
   context "when validating attributes" do
    
       it "should have name as its keyattribute" do
	   
         described_class.key_attributes.should == [:name]
        end

        describe "when vslidating attribute" do
            [:dracipaddress,:dracusername,:dracpassword,:raidtype,:nfsipaddress,:nfssharepath,:disk].each do |param| 
            it "should hava a #{param} parameter" do
                described_class.attrtype(param).should == :param
            end

        end
        
         [:ensure].each do |property|
            it "should have a #{property} property" do
                 described_class.attrtype(property).should == :property
            end
         end

       end
   
   end
   describe "when validating values" do
		describe "validating name" do
			it "should allow a valid name" do
				described_class.new(
			:ensure			=> raid_attrib['ensure'],
           :name            => raid_attrib['name'],
           :dracipaddress   => raid_attrib['dracipaddress'],
           :dracusername    => raid_attrib['dracusername'],
           :dracpassword    => raid_attrib['dracpassword'],
           :raidtype        => raid_attrib['raidtype'], 
           :nfsipaddress    => raid_attrib['nfsipaddress'],
           :nfssharepath    => raid_attrib['nfssharepath'],
           :disk            => raid_attrib['disk']
				)[:name].should == raid_attrib['name']
			end
			it "should not allow blank value in the name" do
				expect { described_class.new(
			:ensure			=> raid_attrib['ensure'],
           :name            => '',
           :dracipaddress   => raid_attrib['dracipaddress'],
           :dracusername    => raid_attrib['dracusername'],
           :dracpassword    => raid_attrib['dracpassword'],
           :raidtype        => raid_attrib['raidtype'], 
           :nfsipaddress    => raid_attrib['nfsipaddress'],
           :nfssharepath    => raid_attrib['nfssharepath'],
           :disk            => raid_attrib['disk']
				)}.to raise_error Puppet::Error
			end
		end
		#================================
		it "should allow a ensure property" do
				described_class.new(
					:ensure			=> raid_attrib['ensure'],
           :name            => raid_attrib['name'],
           :dracipaddress   => raid_attrib['dracipaddress'],
           :dracusername    => raid_attrib['dracusername'],
           :dracpassword    => raid_attrib['dracpassword'],
           :raidtype        => raid_attrib['raidtype'], 
           :nfsipaddress    => raid_attrib['nfsipaddress'],
           :nfssharepath    => raid_attrib['nfssharepath'],
           :disk            => raid_attrib['disk']
				)[:ensure].should == (raid_attrib['ensure'] == 'present' ? :present : (raid_attrib['ensure'] == 'absent' ? :absent : raid_attrib['ensure']))
		end	
		it "should not allow values other than present or absent" do
				expect {described_class.new(
					:ensure			=> 'sadsad',
           :name            => raid_attrib['name'],
           :dracipaddress   => raid_attrib['dracipaddress'],
           :dracusername    => raid_attrib['dracusername'],
           :dracpassword    => raid_attrib['dracpassword'],
           :raidtype        => raid_attrib['raidtype'], 
           :nfsipaddress    => raid_attrib['nfsipaddress'],
           :nfssharepath    => raid_attrib['nfssharepath'],
           :disk            => raid_attrib['disk']
				)}.to raise_error Puppet::Error
		end	
		#================================
		#================================
		it "should support dracipaddress value" do
				described_class.new(
			:ensure			=> raid_attrib['ensure'],
           :name            => raid_attrib['name'],
           :dracipaddress   => raid_attrib['dracipaddress'],
           :dracusername    => raid_attrib['dracusername'],
           :dracpassword    => raid_attrib['dracpassword'],
           :raidtype        => raid_attrib['raidtype'], 
           :nfsipaddress    => raid_attrib['nfsipaddress'],
           :nfssharepath    => raid_attrib['nfssharepath'],
           :disk            => raid_attrib['disk'])[:dracipaddress].should == raid_attrib['dracipaddress']
			end
			it "should not support dracipaddress empty value" do
				expect { described_class.new(
					:ensure			=> raid_attrib['ensure'],
           :name            => raid_attrib['name'],
           :dracipaddress   => '',
           :dracusername    => raid_attrib['dracusername'],
           :dracpassword    => raid_attrib['dracpassword'],
           :raidtype        => raid_attrib['raidtype'], 
           :nfsipaddress    => raid_attrib['nfsipaddress'],
           :nfssharepath    => raid_attrib['nfssharepath'],
           :disk            => raid_attrib['disk']) }.to raise_error Puppet::Error
			end
			
			it "should support dracusername value" do
				described_class.new(
			:ensure			=> 'present',
			:ensure			=> raid_attrib['ensure'],
           :name            => raid_attrib['name'],
           :dracipaddress   => raid_attrib['dracipaddress'],
           :dracusername    => raid_attrib['dracusername'],
           :dracpassword    => raid_attrib['dracpassword'],
           :raidtype        => raid_attrib['raidtype'], 
           :nfsipaddress    => raid_attrib['nfsipaddress'],
           :nfssharepath    => raid_attrib['nfssharepath'],
           :disk            => raid_attrib['disk'])[:dracusername].should == raid_attrib['dracusername']
			end
			it "should not support dracusername empty value" do
				expect { described_class.new(
			:ensure			=> raid_attrib['ensure'],
           :name            => raid_attrib['name'],
           :dracipaddress   => raid_attrib['dracipaddress'],
           :dracusername    => '',
           :dracpassword    => raid_attrib['dracpassword'],
           :raidtype        => raid_attrib['raidtype'], 
           :nfsipaddress    => raid_attrib['nfsipaddress'],
           :nfssharepath    => raid_attrib['nfssharepath'],
           :disk            => raid_attrib['disk']) }.to raise_error Puppet::Error
			end
			
			#+++++++++++++++++
			it "should support dracpassword value" do
				described_class.new(
					:ensure			=> raid_attrib['ensure'],
           :name            => raid_attrib['name'],
           :dracipaddress   => raid_attrib['dracipaddress'],
           :dracusername    => raid_attrib['dracusername'],
           :dracpassword    => raid_attrib['dracpassword'],
           :raidtype        => raid_attrib['raidtype'], 
           :nfsipaddress    => raid_attrib['nfsipaddress'],
           :nfssharepath    => raid_attrib['nfssharepath'],
           :disk            => raid_attrib['disk'])[:dracpassword].should == raid_attrib['dracpassword']
			end
			it "should not support dracpassword empty value" do
				expect { described_class.new(
					:ensure			=> raid_attrib['ensure'],
           :name            => raid_attrib['name'],
           :dracipaddress   => raid_attrib['dracipaddress'],
           :dracusername    => raid_attrib['dracusername'],
           :dracpassword    => '',
           :raidtype        => raid_attrib['raidtype'], 
           :nfsipaddress    => raid_attrib['nfsipaddress'],
           :nfssharepath    => raid_attrib['nfssharepath'],
           :disk            => raid_attrib['disk']) }.to raise_error Puppet::Error
			end
			it "should support nfsipaddress value" do
				described_class.new(
			:ensure			=> raid_attrib['ensure'],
           :name            => raid_attrib['name'],
           :dracipaddress   => raid_attrib['dracipaddress'],
           :dracusername    => raid_attrib['dracusername'],
           :dracpassword    => raid_attrib['dracpassword'],
           :raidtype        => raid_attrib['raidtype'], 
           :nfsipaddress    => raid_attrib['nfsipaddress'],
           :nfssharepath    => raid_attrib['nfssharepath'],
           :disk            => raid_attrib['disk'])[:nfsipaddress].should == raid_attrib['nfsipaddress']
			end
			it "should not support nfsipaddress empty value" do
				expect { described_class.new(
			:ensure			=> raid_attrib['ensure'],
           :name            => raid_attrib['name'],
           :dracipaddress   => raid_attrib['dracipaddress'],
           :dracusername    => raid_attrib['dracusername'],
           :dracpassword    => raid_attrib['dracpassword'],
           :raidtype        => raid_attrib['raidtype'], 
           :nfsipaddress    => '',
           :nfssharepath    => raid_attrib['nfssharepath'],
           :disk            => raid_attrib['disk']) }.to raise_error Puppet::Error
			end
			#+++++++++++++++++
			#+++++++++++++++++
			it "should support nfssharepath value" do
				described_class.new(
					:ensure			=> raid_attrib['ensure'],
           :name            => raid_attrib['name'],
           :dracipaddress   => raid_attrib['dracipaddress'],
           :dracusername    => raid_attrib['dracusername'],
           :dracpassword    => raid_attrib['dracpassword'],
           :raidtype        => raid_attrib['raidtype'], 
           :nfsipaddress    => raid_attrib['nfsipaddress'],
           :nfssharepath    => raid_attrib['nfssharepath'],
           :disk            => raid_attrib['disk'])[:nfssharepath].should == raid_attrib['nfssharepath']
			end
			it "should not support nfssharepath empty value" do
				expect { described_class.new(
				:ensure			=> raid_attrib['ensure'],
           :name            => raid_attrib['name'],
           :dracipaddress   => raid_attrib['dracipaddress'],
           :dracusername    => raid_attrib['dracusername'],
           :dracpassword    => raid_attrib['dracpassword'],
           :raidtype        => raid_attrib['raidtype'], 
           :nfsipaddress    => raid_attrib['nfsipaddress'],
           :nfssharepath    => '',
           :disk            => raid_attrib['disk']) }.to raise_error Puppet::Error
			end
			it "should support disk value" do
				described_class.new(
					:ensure			=> raid_attrib['ensure'],
           :name            => raid_attrib['name'],
           :dracipaddress   => raid_attrib['dracipaddress'],
           :dracusername    => raid_attrib['dracusername'],
           :dracpassword    => raid_attrib['dracpassword'],
           :raidtype        => raid_attrib['raidtype'], 
           :nfsipaddress    => raid_attrib['nfsipaddress'],
           :nfssharepath    => raid_attrib['nfssharepath'],
           :disk            => raid_attrib['disk'])[:disk].should == raid_attrib['disk']
			end
			it "should not support disk empty value" do
				expect { described_class.new(
				:ensure			=> raid_attrib['ensure'],
           :name            => raid_attrib['name'],
           :dracipaddress   => raid_attrib['dracipaddress'],
           :dracusername    => raid_attrib['dracusername'],
           :dracpassword    => raid_attrib['dracpassword'],
           :raidtype        => raid_attrib['raidtype'], 
           :nfsipaddress    => raid_attrib['nfsipaddress'],
           :nfssharepath    => raid_attrib['nfssharepath'],
           :disk            => '') }.to raise_error Puppet::Error
			end
			#========================
			it "should support raidtype value" do
				described_class.new(
					:ensure			=> raid_attrib['ensure'],
           :name            => raid_attrib['name'],
           :dracipaddress   => raid_attrib['dracipaddress'],
           :dracusername    => raid_attrib['dracusername'],
           :dracpassword    => raid_attrib['dracpassword'],
           :raidtype        => raid_attrib['raidtype'], 
           :nfsipaddress    => raid_attrib['nfsipaddress'],
           :nfssharepath    => raid_attrib['nfssharepath'],
           :disk            => raid_attrib['disk'])[:raidtype].should == raid_attrib['raidtype']
			end
			it "should not support raidtype empty value" do
				expect { described_class.new(
				:ensure			=> raid_attrib['ensure'],
           :name            => raid_attrib['name'],
           :dracipaddress   => raid_attrib['dracipaddress'],
           :dracusername    => raid_attrib['dracusername'],
           :dracpassword    => raid_attrib['dracpassword'],
           :raidtype        => '', 
           :nfsipaddress    => raid_attrib['nfsipaddress'],
           :nfssharepath    => raid_attrib['nfssharepath'],
           :disk            => raid_attrib['disk']) }.to raise_error Puppet::Error
			end
		#================================
   end
end