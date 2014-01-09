#! /usr/bin/env ruby

require 'spec_helper'
describe Puppet::Type.type(:importnparsetting) do
	
	npar_conf =YAML.load_file(get_configpath('idrac','npar_config.yml'))
	npar_attrib = npar_conf['npar_configuration_type']
	
	let(:title) { 'importnparsetting' }
	context "should compile with given test params"  do 

    let(:params) {{
           :name            => npar_attrib['name'],
           :nic             => npar_attrib['nic'], 
           :status          => npar_attrib['status'],
           :dracipaddress   => npar_attrib['dracipaddress'],
           :dracusername    => npar_attrib['dracusername'],
           :dracpassword    => npar_attrib['dracpassword'],
           :nfsipaddress    => npar_attrib['nfsipaddress'],
           :nfssharepath    => npar_attrib['nfssharepath']
    } }
    it do
        expect { should compile }
	end 
   end  
   #++++++++++++++++++++++++++++++++++++++++++++++++++++
	context "when validating attributes" do
    
       it "should have name as its keyattribute" do
	   
         described_class.key_attributes.should == [:name]
        end

        describe "when vslidating attribute" do
            [:nic,:status,:dracipaddress,:dracusername,:dracpassword,:nfsipaddress,:nfssharepath].each do |param| 
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
   #++++++++++++++++++++++++++++++++++++++++++++++++++++
	describe "when validating values" do
		describe "validating name" do
			it "should allow a valid name" do
				described_class.new(
			:ensure			=> npar_attrib['ensure'],
           :name            => npar_attrib['name'],
           :nic             => npar_attrib['nic'], 
           :status          => npar_attrib['status'],
           :dracipaddress   => npar_attrib['dracipaddress'],
           :dracusername    => npar_attrib['dracusername'],
           :dracpassword    => npar_attrib['dracpassword'],
           :nfsipaddress    => npar_attrib['nfsipaddress'],
           :nfssharepath    => npar_attrib['nfssharepath']
				)[:name].should ==npar_attrib['name']
			end
			it "should not allow blank value in the name" do
				expect { described_class.new(
			:ensure			=> '',
           :name            => npar_attrib['name'],
           :nic             => npar_attrib['nic'], 
           :status          => npar_attrib['status'],
           :dracipaddress   => npar_attrib['dracipaddress'],
           :dracusername    => npar_attrib['dracusername'],
           :dracpassword    => npar_attrib['dracpassword'],
           :nfsipaddress    => npar_attrib['nfsipaddress'],
           :nfssharepath    => npar_attrib['nfssharepath']
				)}.to raise_error Puppet::Error
			end
			
		end
		#================================
		it "should allow a ensure property" do
				described_class.new(
			:ensure			=> npar_attrib['ensure'],
           :name            => npar_attrib['name'],
           :nic             => npar_attrib['nic'], 
           :status          => npar_attrib['status'],
           :dracipaddress   => npar_attrib['dracipaddress'],
           :dracusername    => npar_attrib['dracusername'],
           :dracpassword    => npar_attrib['dracpassword'],
           :nfsipaddress    => npar_attrib['nfsipaddress'],
           :nfssharepath    => npar_attrib['nfssharepath']
				)[:ensure].should == (npar_attrib['ensure'] == 'present' ? :present : (npar_attrib['ensure'] == 'absent' ? :absent : npar_attrib['ensure']))
		end	
		it "should not allow values other than present or absent" do
				expect {described_class.new(
					:ensure			=> 'ssadsadsasa',
           :name            => npar_attrib['name'],
           :nic             => npar_attrib['nic'], 
           :status          => npar_attrib['status'],
           :dracipaddress   => npar_attrib['dracipaddress'],
           :dracusername    => npar_attrib['dracusername'],
           :dracpassword    => npar_attrib['dracpassword'],
           :nfsipaddress    => npar_attrib['nfsipaddress'],
           :nfssharepath    => npar_attrib['nfssharepath']
				)}.to raise_error Puppet::Error
		end	
		
			
		#================================
		it "should support nic value" do
				described_class.new(
			:ensure			=> npar_attrib['ensure'],
           :name            => npar_attrib['name'],
           :nic             => npar_attrib['nic'], 
           :status          => npar_attrib['status'],
           :dracipaddress   => npar_attrib['dracipaddress'],
           :dracusername    => npar_attrib['dracusername'],
           :dracpassword    => npar_attrib['dracpassword'],
           :nfsipaddress    => npar_attrib['nfsipaddress'],
           :nfssharepath    => npar_attrib['nfssharepath']
				)[:nic].should == npar_attrib['nic']
		end	
		it "should not support nic  empty value" do
				expect {described_class.new(
					:ensure			=> npar_attrib['ensure'],
           :name            => npar_attrib['name'],
           :nic             => '', 
           :status          => npar_attrib['status'],
           :dracipaddress   => npar_attrib['dracipaddress'],
           :dracusername    => npar_attrib['dracusername'],
           :dracpassword    => npar_attrib['dracpassword'],
           :nfsipaddress    => npar_attrib['nfsipaddress'],
           :nfssharepath    => npar_attrib['nfssharepath']
				)}.to raise_error Puppet::Error
		end	
		#================================
		it "should support status value" do
				described_class.new(
			:ensure			=> npar_attrib['ensure'],
           :name            => npar_attrib['name'],
           :nic             => npar_attrib['nic'], 
           :status          => npar_attrib['status'],
           :dracipaddress   => npar_attrib['dracipaddress'],
           :dracusername    => npar_attrib['dracusername'],
           :dracpassword    => npar_attrib['dracpassword'],
           :nfsipaddress    => npar_attrib['nfsipaddress'],
           :nfssharepath    => npar_attrib['nfssharepath']
				)[:status].should == npar_attrib['status']
		end	
		it "should not allow values other than Enabled or Disabled" do
				expect {described_class.new(
			:ensure			=> npar_attrib['ensure'],
           :name            => npar_attrib['name'],
           :nic             => npar_attrib['nic'], 
           :status          => 'sadasdas',
           :dracipaddress   => npar_attrib['dracipaddress'],
           :dracusername    => npar_attrib['dracusername'],
           :dracpassword    => npar_attrib['dracpassword'],
           :nfsipaddress    => npar_attrib['nfsipaddress'],
           :nfssharepath    => npar_attrib['nfssharepath']
				)}.to raise_error Puppet::Error
		end	
		it "should not support nic  empty value" do
				expect {described_class.new(
					:ensure			=> npar_attrib['ensure'],
           :name            => npar_attrib['name'],
           :nic             => npar_attrib['nic'], 
           :status          => '',
           :dracipaddress   => npar_attrib['dracipaddress'],
           :dracusername    => npar_attrib['dracusername'],
           :dracpassword    => npar_attrib['dracpassword'],
           :nfsipaddress    => npar_attrib['nfsipaddress'],
           :nfssharepath    => npar_attrib['nfssharepath']
				)}.to raise_error Puppet::Error
		end	
		#================================
		it "should support dracipaddress value" do
				described_class.new(
			:ensure			=> npar_attrib['ensure'],
           :name            => npar_attrib['name'],
           :nic             => npar_attrib['nic'], 
           :status          => npar_attrib['status'],
           :dracipaddress   => npar_attrib['dracipaddress'],
           :dracusername    => npar_attrib['dracusername'],
           :dracpassword    => npar_attrib['dracpassword'],
           :nfsipaddress    => npar_attrib['nfsipaddress'],
           :nfssharepath    => npar_attrib['nfssharepath'])[:dracipaddress].should == npar_attrib['dracipaddress']
			end
			it "should not support dracipaddress empty value" do
				expect { described_class.new(
			:ensure			=> npar_attrib['ensure'],
           :name            => npar_attrib['name'],
           :nic             => npar_attrib['nic'], 
           :status          => npar_attrib['status'],
           :dracipaddress   => '',
           :dracusername    => npar_attrib['dracusername'],
           :dracpassword    => npar_attrib['dracpassword'],
           :nfsipaddress    => npar_attrib['nfsipaddress'],
           :nfssharepath    => npar_attrib['nfssharepath']) }.to raise_error Puppet::Error
			end
			
			it "should support dracusername value" do
				described_class.new(
			:ensure			=> npar_attrib['ensure'],
           :name            => npar_attrib['name'],
           :nic             => npar_attrib['nic'], 
           :status          => npar_attrib['status'],
           :dracipaddress   => npar_attrib['dracipaddress'],
           :dracusername    => npar_attrib['dracusername'],
           :dracpassword    => npar_attrib['dracpassword'],
           :nfsipaddress    => npar_attrib['nfsipaddress'],
           :nfssharepath    => npar_attrib['nfssharepath'])[:dracusername].should == npar_attrib['dracusername']
			end
			it "should not support dracusername empty value" do
				expect { described_class.new(
			:ensure			=> npar_attrib['ensure'],
           :name            => npar_attrib['name'],
           :nic             => npar_attrib['nic'], 
           :status          => npar_attrib['status'],
           :dracipaddress   => npar_attrib['dracipaddress'],
           :dracusername    => '',
           :dracpassword    => npar_attrib['dracpassword'],
           :nfsipaddress    => npar_attrib['nfsipaddress'],
           :nfssharepath    => npar_attrib['nfssharepath']) }.to raise_error Puppet::Error
			end
			
			#+++++++++++++++++
			it "should support dracpassword value" do
				described_class.new(
			:ensure			=> npar_attrib['ensure'],
           :name            => npar_attrib['name'],
           :nic             => npar_attrib['nic'], 
           :status          => npar_attrib['status'],
           :dracipaddress   => npar_attrib['dracipaddress'],
           :dracusername    => npar_attrib['dracusername'],
           :dracpassword    => npar_attrib['dracpassword'],
           :nfsipaddress    => npar_attrib['nfsipaddress'],
           :nfssharepath    => npar_attrib['nfssharepath'])[:dracpassword].should == npar_attrib['dracpassword']
			end
			it "should not support dracpassword empty value" do
				expect { described_class.new(
			:ensure			=> npar_attrib['ensure'],
           :name            => npar_attrib['name'],
           :nic             => npar_attrib['nic'], 
           :status          => npar_attrib['status'],
           :dracipaddress   => npar_attrib['dracipaddress'],
           :dracusername    => npar_attrib['dracusername'],
           :dracpassword    => '',
           :nfsipaddress    => npar_attrib['nfsipaddress'],
           :nfssharepath    => npar_attrib['nfssharepath']) }.to raise_error Puppet::Error
			end
			#+++++++++++++++++
			it "should support nfsipaddress value" do
				described_class.new(
			:ensure			=> npar_attrib['ensure'],
           :name            => npar_attrib['name'],
           :nic             => npar_attrib['nic'], 
           :status          => npar_attrib['status'],
           :dracipaddress   => npar_attrib['dracipaddress'],
           :dracusername    => npar_attrib['dracusername'],
           :dracpassword    => npar_attrib['dracpassword'],
           :nfsipaddress    => npar_attrib['nfsipaddress'],
           :nfssharepath    => npar_attrib['nfssharepath'])[:nfsipaddress].should == npar_attrib['nfsipaddress']
			end
			it "should not support nfsipaddress empty value" do
				expect { described_class.new(
			:ensure			=> npar_attrib['ensure'],
           :name            => npar_attrib['name'],
           :nic             => npar_attrib['nic'], 
           :status          => npar_attrib['status'],
           :dracipaddress   => npar_attrib['dracipaddress'],
           :dracusername    => npar_attrib['dracusername'],
           :dracpassword    => npar_attrib['dracpassword'],
           :nfsipaddress    => '',
           :nfssharepath    => npar_attrib['nfssharepath']) }.to raise_error Puppet::Error
			end
			#+++++++++++++++++
			#+++++++++++++++++
			it "should support nfssharepath value" do
				described_class.new(
			:ensure			=> npar_attrib['ensure'],
           :name            => npar_attrib['name'],
           :nic             => npar_attrib['nic'], 
           :status          => npar_attrib['status'],
           :dracipaddress   => npar_attrib['dracipaddress'],
           :dracusername    => npar_attrib['dracusername'],
           :dracpassword    => npar_attrib['dracpassword'],
           :nfsipaddress    => npar_attrib['nfsipaddress'],
           :nfssharepath    => npar_attrib['nfssharepath'])[:nfssharepath].should == npar_attrib['nfssharepath']
			end
			it "should not support nfssharepath empty value" do
				expect { described_class.new(
			:ensure			=> npar_attrib['ensure'],
           :name            => npar_attrib['name'],
           :nic             => npar_attrib['nic'], 
           :status          => npar_attrib['status'],
           :dracipaddress   => npar_attrib['dracipaddress'],
           :dracusername    => npar_attrib['dracusername'],
           :dracpassword    => npar_attrib['dracpassword'],
           :nfsipaddress    => npar_attrib['nfsipaddress'],
           :nfssharepath    => '') }.to raise_error Puppet::Error
			end
			#+++++++++++++++++
		#================================
		
	end
end