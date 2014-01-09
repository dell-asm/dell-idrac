#! /usr/bin/env ruby
require 'spec_helper'
describe Puppet::Type.type(:importsystemconfiguration) do
	sys_conf =YAML.load_file(get_configpath('idrac','system_config.yml'))
	sys_attrib = sys_conf['sys_configuration_type']
	
	let(:title) { 'importsystemconfiguration' }
	context "should compile with given test params"  do 

    let(:params) {{
          :ensure			=> sys_attrib['ensure'],
           :name            => sys_attrib['name'],
           :dracipaddress   => sys_attrib['dracipaddress'],
           :dracusername    => sys_attrib['dracusername'],
           :dracpassword    => sys_attrib['dracpassword'],
           :configxmlfilename => sys_attrib['configxmlfilename'],
           :nfsipaddress    => sys_attrib['nfsipaddress'],
           :nfssharepath    => sys_attrib['nfssharepath']
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
            [:dracipaddress,:dracusername,:dracpassword,:nfsipaddress,:nfssharepath,:configxmlfilename].each do |param| 
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
			:ensure			=> sys_attrib['ensure'],
           :name            => sys_attrib['name'],
           :dracipaddress   => sys_attrib['dracipaddress'],
           :dracusername    => sys_attrib['dracusername'],
           :dracpassword    => sys_attrib['dracpassword'],
           :configxmlfilename => sys_attrib['configxmlfilename'],
           :nfsipaddress    => sys_attrib['nfsipaddress'],
           :nfssharepath    => sys_attrib['nfssharepath']
				)[:name].should ==sys_attrib['name']
			end
			it "should not allow blank value in the name" do
				expect { described_class.new(
				:ensure			=> sys_attrib['ensure'],
			   :name            => '',
			   :dracipaddress   => sys_attrib['dracipaddress'],
			   :dracusername    => sys_attrib['dracusername'],
			   :dracpassword    => sys_attrib['dracpassword'],
			   :configxmlfilename => sys_attrib['configxmlfilename'],
			   :nfsipaddress    => sys_attrib['nfsipaddress'],
			   :nfssharepath    => sys_attrib['nfssharepath']
				)}.to raise_error Puppet::Error
			end
		end
		#================================
		it "should allow a ensure property" do
				described_class.new(
			:ensure			=> sys_attrib['ensure'],
           :name            => sys_attrib['name'],
           :dracipaddress   => sys_attrib['dracipaddress'],
           :dracusername    => sys_attrib['dracusername'],
           :dracpassword    => sys_attrib['dracpassword'],
           :configxmlfilename => sys_attrib['configxmlfilename'],
           :nfsipaddress    => sys_attrib['nfsipaddress'],
           :nfssharepath    => sys_attrib['nfssharepath']
				)[:ensure].should == (sys_attrib['ensure'] == 'present' ? :present : (sys_attrib['ensure'] == 'absent' ? :absent : sys_attrib['ensure']))
		end	
		it "should not allow values other than present or absent" do
				expect {described_class.new(
			:ensure			=> 'sdasadsadsa',
           :name            => sys_attrib['name'],
           :dracipaddress   => sys_attrib['dracipaddress'],
           :dracusername    => sys_attrib['dracusername'],
           :dracpassword    => sys_attrib['dracpassword'],
           :configxmlfilename => sys_attrib['configxmlfilename'],
           :nfsipaddress    => sys_attrib['nfsipaddress'],
           :nfssharepath    => sys_attrib['nfssharepath']
				)}.to raise_error Puppet::Error
		end	
		#================================
		#================================
		it "should support dracipaddress value" do
				described_class.new(
					:ensure			=> sys_attrib['ensure'],
           :name            => sys_attrib['name'],
           :dracipaddress   => sys_attrib['dracipaddress'],
           :dracusername    => sys_attrib['dracusername'],
           :dracpassword    => sys_attrib['dracpassword'],
           :configxmlfilename => sys_attrib['configxmlfilename'],
           :nfsipaddress    => sys_attrib['nfsipaddress'],
           :nfssharepath    => sys_attrib['nfssharepath'])[:dracipaddress].should == sys_attrib['dracipaddress']
			end
			it "should not support dracipaddress empty value" do
				expect { described_class.new(
					:ensure			=> sys_attrib['ensure'],
           :name            => sys_attrib['name'],
           :dracipaddress   => '',
           :dracusername    => sys_attrib['dracusername'],
           :dracpassword    => sys_attrib['dracpassword'],
           :configxmlfilename => sys_attrib['configxmlfilename'],
           :nfsipaddress    => sys_attrib['nfsipaddress'],
           :nfssharepath    => sys_attrib['nfssharepath']) }.to raise_error Puppet::Error
			end
			
			it "should support dracusername value" do
				described_class.new(
					:ensure			=> sys_attrib['ensure'],
           :name            => sys_attrib['name'],
           :dracipaddress   => sys_attrib['dracipaddress'],
           :dracusername    => sys_attrib['dracusername'],
           :dracpassword    => sys_attrib['dracpassword'],
           :configxmlfilename => sys_attrib['configxmlfilename'],
           :nfsipaddress    => sys_attrib['nfsipaddress'],
           :nfssharepath    => sys_attrib['nfssharepath'])[:dracusername].should == sys_attrib['dracusername']
			end
			it "should not support dracusername empty value" do
				expect { described_class.new(
					:ensure			=> sys_attrib['ensure'],
           :name            => sys_attrib['name'],
           :dracipaddress   => sys_attrib['dracipaddress'],
           :dracusername    => '',
           :dracpassword    => sys_attrib['dracpassword'],
           :configxmlfilename => sys_attrib['configxmlfilename'],
           :nfsipaddress    => sys_attrib['nfsipaddress'],
           :nfssharepath    => sys_attrib['nfssharepath']) }.to raise_error Puppet::Error
			end
			
			#+++++++++++++++++
			it "should support dracpassword value" do
				described_class.new(
					:ensure			=> sys_attrib['ensure'],
           :name            => sys_attrib['name'],
           :dracipaddress   => sys_attrib['dracipaddress'],
           :dracusername    => sys_attrib['dracusername'],
           :dracpassword    => sys_attrib['dracpassword'],
           :configxmlfilename => sys_attrib['configxmlfilename'],
           :nfsipaddress    => sys_attrib['nfsipaddress'],
           :nfssharepath    => sys_attrib['nfssharepath'])[:dracpassword].should == sys_attrib['dracpassword']
			end
			it "should not support dracpassword empty value" do
				expect { described_class.new(
					:ensure			=> sys_attrib['ensure'],
           :name            => sys_attrib['name'],
           :dracipaddress   => sys_attrib['dracipaddress'],
           :dracusername    => sys_attrib['dracusername'],
           :dracpassword    => '',
           :configxmlfilename => sys_attrib['configxmlfilename'],
           :nfsipaddress    => sys_attrib['nfsipaddress'],
           :nfssharepath    => sys_attrib['nfssharepath']) }.to raise_error Puppet::Error
			end
			it "should support nfsipaddress value" do
				described_class.new(
					:ensure			=> sys_attrib['ensure'],
           :name            => sys_attrib['name'],
           :dracipaddress   => sys_attrib['dracipaddress'],
           :dracusername    => sys_attrib['dracusername'],
           :dracpassword    => sys_attrib['dracpassword'],
           :configxmlfilename => sys_attrib['configxmlfilename'],
           :nfsipaddress    => sys_attrib['nfsipaddress'],
           :nfssharepath    => sys_attrib['nfssharepath'])[:nfsipaddress].should == sys_attrib['nfsipaddress']
			end
			it "should not support nfsipaddress empty value" do
				expect { described_class.new(
					:ensure			=> sys_attrib['ensure'],
           :name            => sys_attrib['name'],
           :dracipaddress   => sys_attrib['dracipaddress'],
           :dracusername    => sys_attrib['dracusername'],
           :dracpassword    => sys_attrib['dracpassword'],
           :configxmlfilename => sys_attrib['configxmlfilename'],
           :nfsipaddress    => '',
           :nfssharepath    => sys_attrib['nfssharepath']) }.to raise_error Puppet::Error
			end
			it "should support nfssharepath value" do
				described_class.new(
			:ensure			=> sys_attrib['ensure'],
           :name            => sys_attrib['name'],
           :dracipaddress   => sys_attrib['dracipaddress'],
           :dracusername    => sys_attrib['dracusername'],
           :dracpassword    => sys_attrib['dracpassword'],
           :configxmlfilename => sys_attrib['configxmlfilename'],
           :nfsipaddress    => sys_attrib['nfsipaddress'],
           :nfssharepath    => sys_attrib['nfssharepath'])[:nfssharepath].should == sys_attrib['nfssharepath']
			end
			it "should not support nfssharepath empty value" do
				expect { described_class.new(
					:ensure			=> sys_attrib['ensure'],
           :name            => sys_attrib['name'],
           :dracipaddress   => sys_attrib['dracipaddress'],
           :dracusername    => sys_attrib['dracusername'],
           :dracpassword    => sys_attrib['dracpassword'],
           :configxmlfilename => sys_attrib['configxmlfilename'],
           :nfsipaddress    => sys_attrib['nfsipaddress'],
           :nfssharepath    => '') }.to raise_error Puppet::Error
			end
			it "should support configxmlfilename value" do
				described_class.new(
					:ensure			=> sys_attrib['ensure'],
           :name            => sys_attrib['name'],
           :dracipaddress   => sys_attrib['dracipaddress'],
           :dracusername    => sys_attrib['dracusername'],
           :dracpassword    => sys_attrib['dracpassword'],
           :configxmlfilename => sys_attrib['configxmlfilename'],
           :nfsipaddress    => sys_attrib['nfsipaddress'],
           :nfssharepath    => sys_attrib['nfssharepath'])[:configxmlfilename].should == sys_attrib['configxmlfilename']
			end
			it "should not support configxmlfilename empty value" do
				expect { described_class.new(
					:ensure			=> sys_attrib['ensure'],
           :name            => sys_attrib['name'],
           :dracipaddress   => sys_attrib['dracipaddress'],
           :dracusername    => sys_attrib['dracusername'],
           :dracpassword    => sys_attrib['dracpassword'],
           :configxmlfilename => '',
           :nfsipaddress    => sys_attrib['nfsipaddress'],
           :nfssharepath    => sys_attrib['nfssharepath']) }.to raise_error Puppet::Error
			end
			#+++++++++++++++++
			
   end
end