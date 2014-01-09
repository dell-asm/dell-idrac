#! /usr/bin/env ruby

require 'spec_helper'
describe Puppet::Type.type(:importbiosconfiguration) do
	bios_conf = YAML.load_file(get_configpath('idrac','bios_config.yml'))
	bios_attrib = bios_conf['bios_configuration_type'] 
	
    let(:title) { 'importbiosconfiguration' }
	#++++++++++++++++++++++++++++++++++++++++++++++++++++
   context "should compile with given test params"  do 

    let(:params) {{
           :ensure          		=> bios_attrib['ensure'],
           :name            		=> bios_attrib['name'],
           :dracipaddress   		=> bios_attrib['dracipaddress'],
           :dracusername    		=> bios_attrib['dracusername'],
           :dracpassword    		=> bios_attrib['dracpassword'],
           :nfsipaddress    		=> bios_attrib['nfsipaddress'],
           :nfssharepath    		=> bios_attrib['nfssharepath'],
           :memtest         		=> bios_attrib['memtest'],
           :procvirtualization 		=> bios_attrib['procvirtualization'],
           :proccores       		=> bios_attrib['proccores'],
           :bootmode 				=> bios_attrib['bootmode'],
           :bootseqretry 			=> bios_attrib['bootseqretry'],
           :integratedraid 			=> bios_attrib['integratedraid'],
           :usbports 				=> bios_attrib['usbports'],
           :internalusb 			=> bios_attrib['internalusb'],
           :internalsdcard 			=> bios_attrib['internalsdcard'],
           :internalsdcardredundancy => bios_attrib['internalsdcardredundancy'],
           :integratednetwork1 		=> bios_attrib['integratednetwork1'],  
		   :biosbootseq				=> bios_attrib['biosbootseq'] 
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
            [:dracipaddress,:dracusername,:dracpassword,:nfsipaddress,:nfssharepath,:memtest,:procvirtualization,:proccores,:bootmode,:bootseqretry,:integratedraid,:usbports,:internalusb,:internalsdcard,:internalsdcardredundancy,:integratednetwork1,:biosbootseq].each do |param| 
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
			:ensure          		=> bios_attrib['ensure'],
           :name            		=> bios_attrib['name'],
           :dracipaddress   		=> bios_attrib['dracipaddress'],
           :dracusername    		=> bios_attrib['dracusername'],
           :dracpassword    		=> bios_attrib['dracpassword'],
           :nfsipaddress    		=> bios_attrib['nfsipaddress'],
           :nfssharepath    		=> bios_attrib['nfssharepath'],
           :memtest         		=> bios_attrib['memtest'],
           :procvirtualization 		=> bios_attrib['procvirtualization'],
           :proccores       		=> bios_attrib['proccores'],
           :bootmode 				=> bios_attrib['bootmode'],
           :bootseqretry 			=> bios_attrib['bootseqretry'],
           :integratedraid 			=> bios_attrib['integratedraid'],
           :usbports 				=> bios_attrib['usbports'],
           :internalusb 			=> bios_attrib['internalusb'],
           :internalsdcard 			=> bios_attrib['internalsdcard'],
           :internalsdcardredundancy => bios_attrib['internalsdcardredundancy'],
           :integratednetwork1 		=> bios_attrib['integratednetwork1'],  
		   :biosbootseq				=> bios_attrib['biosbootseq'] )[:name].should == bios_attrib['name']
			end
			 
		  it "should not allow blank value in the name" do
			expect { described_class.new(
			:ensure          		=> bios_attrib['ensure'],
           :name            		=> '',
           :dracipaddress   		=> bios_attrib['dracipaddress'],
           :dracusername    		=> bios_attrib['dracusername'],
           :dracpassword    		=> bios_attrib['dracpassword'],
           :nfsipaddress    		=> bios_attrib['nfsipaddress'],
           :nfssharepath    		=> bios_attrib['nfssharepath'],
           :memtest         		=> bios_attrib['memtest'],
           :procvirtualization 		=> bios_attrib['procvirtualization'],
           :proccores       		=> bios_attrib['proccores'],
           :bootmode 				=> bios_attrib['bootmode'],
           :bootseqretry 			=> bios_attrib['bootseqretry'],
           :integratedraid 			=> bios_attrib['integratedraid'],
           :usbports 				=> bios_attrib['usbports'],
           :internalusb 			=> bios_attrib['internalusb'],
           :internalsdcard 			=> bios_attrib['internalsdcard'],
           :internalsdcardredundancy => bios_attrib['internalsdcardredundancy'],
           :integratednetwork1 		=> bios_attrib['integratednetwork1'],  
		   :biosbootseq				=> bios_attrib['biosbootseq']) }.to raise_error Puppet::Error
		  end
		 		  
		end
		#describe "validating ensure property" do
			it "should support present value" do
				described_class.new(
		   
           :name            		=> bios_attrib['name'],
           :dracipaddress   		=> bios_attrib['dracipaddress'],
           :dracusername    		=> bios_attrib['dracusername'],
           :dracpassword    		=> bios_attrib['dracpassword'],
           :nfsipaddress    		=> bios_attrib['nfsipaddress'],
           :nfssharepath    		=> bios_attrib['nfssharepath'],
           :memtest         		=> bios_attrib['memtest'],
           :procvirtualization 		=> bios_attrib['procvirtualization'],
           :proccores       		=> bios_attrib['proccores'],
           :bootmode 				=> bios_attrib['bootmode'],
           :bootseqretry 			=> bios_attrib['bootseqretry'],
           :integratedraid 			=> bios_attrib['integratedraid'],
           :usbports 				=> bios_attrib['usbports'],
           :internalusb 			=> bios_attrib['internalusb'],
           :internalsdcard 			=> bios_attrib['internalsdcard'],
           :internalsdcardredundancy => bios_attrib['internalsdcardredundancy'],
           :integratednetwork1 		=> bios_attrib['integratednetwork1'],  
		   :biosbootseq				=> bios_attrib['biosbootseq'])[:ensure].should == (bios_attrib['ensure'] == 'present' ? :present : (bios_attrib['ensure'] == 'absent' ? :absent : bios_attrib['ensure']))
			end
=begin
			it "should support absent value" do
			described_class.new(:name => 'importbiosconfiguration',
			:ensure          => 'present',
			:dracipaddress   => '172.17.10.106',
            :dracusername    => 'root',
            :dracpassword    => 'calvin',
            :nfsipaddress    => '172.28.10.191',
            :nfssharepath    => '/root/SharedNFS',
            :memtest         => 'Disabled',
            :procvirtualization => 'Enabled',
            :proccores       => 'All',
            :bootmode        => 'Bios',
            :bootseqretry    => 'Disabled',
            :integratedraid  => 'Disabled',
            :usbports        => 'AllOn',
            :internalusb     => 'Off',
            :internalsdcard  => 'On',
            :internalsdcardredundancy => 'Mirror',
            :integratednetwork1 => 'Enabled',:biosbootseq		=> 'HardDisk.List.1-1, NIC.Integrated.1-1-1, NIC.Integrated.1-2-1' )[:ensure].should == :absent
			end
=end			
			it "should not allow values other than present or absent" do
				expect { described_class.new(
			:ensure          		=> 'sasadas',
           :name            		=> bios_attrib['name'],
           :dracipaddress   		=> bios_attrib['dracipaddress'],
           :dracusername    		=> bios_attrib['dracusername'],
           :dracpassword    		=> bios_attrib['dracpassword'],
           :nfsipaddress    		=> bios_attrib['nfsipaddress'],
           :nfssharepath    		=> bios_attrib['nfssharepath'],
           :memtest         		=> bios_attrib['memtest'],
           :procvirtualization 		=> bios_attrib['procvirtualization'],
           :proccores       		=> bios_attrib['proccores'],
           :bootmode 				=> bios_attrib['bootmode'],
           :bootseqretry 			=> bios_attrib['bootseqretry'],
           :integratedraid 			=> bios_attrib['integratedraid'],
           :usbports 				=> bios_attrib['usbports'],
           :internalusb 			=> bios_attrib['internalusb'],
           :internalsdcard 			=> bios_attrib['internalsdcard'],
           :internalsdcardredundancy => bios_attrib['internalsdcardredundancy'],
           :integratednetwork1 		=> bios_attrib['integratednetwork1'],  
		   :biosbootseq				=> bios_attrib['biosbootseq']) }.to raise_error Puppet::Error
			end
			it "should support dracipaddress value" do
				described_class.new(
			:ensure          		=> bios_attrib['ensure'],
           :name            		=> bios_attrib['name'],
           :dracipaddress   		=> bios_attrib['dracipaddress'],
           :dracusername    		=> bios_attrib['dracusername'],
           :dracpassword    		=> bios_attrib['dracpassword'],
           :nfsipaddress    		=> bios_attrib['nfsipaddress'],
           :nfssharepath    		=> bios_attrib['nfssharepath'],
           :memtest         		=> bios_attrib['memtest'],
           :procvirtualization 		=> bios_attrib['procvirtualization'],
           :proccores       		=> bios_attrib['proccores'],
           :bootmode 				=> bios_attrib['bootmode'],
           :bootseqretry 			=> bios_attrib['bootseqretry'],
           :integratedraid 			=> bios_attrib['integratedraid'],
           :usbports 				=> bios_attrib['usbports'],
           :internalusb 			=> bios_attrib['internalusb'],
           :internalsdcard 			=> bios_attrib['internalsdcard'],
           :internalsdcardredundancy => bios_attrib['internalsdcardredundancy'],
           :integratednetwork1 		=> bios_attrib['integratednetwork1'],  
		   :biosbootseq				=> bios_attrib['biosbootseq'])[:dracipaddress].should == bios_attrib['dracipaddress']
			end
			it "should not support dracipaddress empty value" do
				expect { described_class.new(
			:ensure          		=> bios_attrib['ensure'],
           :name            		=> bios_attrib['name'],
           :dracipaddress   		=> '',
           :dracusername    		=> bios_attrib['dracusername'],
           :dracpassword    		=> bios_attrib['dracpassword'],
           :nfsipaddress    		=> bios_attrib['nfsipaddress'],
           :nfssharepath    		=> bios_attrib['nfssharepath'],
           :memtest         		=> bios_attrib['memtest'],
           :procvirtualization 		=> bios_attrib['procvirtualization'],
           :proccores       		=> bios_attrib['proccores'],
           :bootmode 				=> bios_attrib['bootmode'],
           :bootseqretry 			=> bios_attrib['bootseqretry'],
           :integratedraid 			=> bios_attrib['integratedraid'],
           :usbports 				=> bios_attrib['usbports'],
           :internalusb 			=> bios_attrib['internalusb'],
           :internalsdcard 			=> bios_attrib['internalsdcard'],
           :internalsdcardredundancy => bios_attrib['internalsdcardredundancy'],
           :integratednetwork1 		=> bios_attrib['integratednetwork1'],  
		   :biosbootseq				=> bios_attrib['biosbootseq']) }.to raise_error Puppet::Error
			end
			
			it "should support dracusername value" do
				described_class.new(
			 :ensure          		=> bios_attrib['ensure'],
           :name            		=> bios_attrib['name'],
           :dracipaddress   		=> bios_attrib['dracipaddress'],
           :dracusername    		=> bios_attrib['dracusername'],
           :dracpassword    		=> bios_attrib['dracpassword'],
           :nfsipaddress    		=> bios_attrib['nfsipaddress'],
           :nfssharepath    		=> bios_attrib['nfssharepath'],
           :memtest         		=> bios_attrib['memtest'],
           :procvirtualization 		=> bios_attrib['procvirtualization'],
           :proccores       		=> bios_attrib['proccores'],
           :bootmode 				=> bios_attrib['bootmode'],
           :bootseqretry 			=> bios_attrib['bootseqretry'],
           :integratedraid 			=> bios_attrib['integratedraid'],
           :usbports 				=> bios_attrib['usbports'],
           :internalusb 			=> bios_attrib['internalusb'],
           :internalsdcard 			=> bios_attrib['internalsdcard'],
           :internalsdcardredundancy => bios_attrib['internalsdcardredundancy'],
           :integratednetwork1 		=> bios_attrib['integratednetwork1'],  
		   :biosbootseq				=> bios_attrib['biosbootseq'])[:dracusername].should == bios_attrib['dracusername']
			end
			it "should not support dracusername empty value" do
				expect { described_class.new(
			 :ensure          		=> bios_attrib['ensure'],
           :name            		=> bios_attrib['name'],
           :dracipaddress   		=> bios_attrib['dracipaddress'],
           :dracusername    		=> '',
           :dracpassword    		=> bios_attrib['dracpassword'],
           :nfsipaddress    		=> bios_attrib['nfsipaddress'],
           :nfssharepath    		=> bios_attrib['nfssharepath'],
           :memtest         		=> bios_attrib['memtest'],
           :procvirtualization 		=> bios_attrib['procvirtualization'],
           :proccores       		=> bios_attrib['proccores'],
           :bootmode 				=> bios_attrib['bootmode'],
           :bootseqretry 			=> bios_attrib['bootseqretry'],
           :integratedraid 			=> bios_attrib['integratedraid'],
           :usbports 				=> bios_attrib['usbports'],
           :internalusb 			=> bios_attrib['internalusb'],
           :internalsdcard 			=> bios_attrib['internalsdcard'],
           :internalsdcardredundancy => bios_attrib['internalsdcardredundancy'],
           :integratednetwork1 		=> bios_attrib['integratednetwork1'],  
		   :biosbootseq				=> bios_attrib['biosbootseq']) }.to raise_error Puppet::Error
			end
			
			#+++++++++++++++++
			it "should support dracpassword value" do
				described_class.new(
		   :ensure          		=> bios_attrib['ensure'],
           :name            		=> bios_attrib['name'],
           :dracipaddress   		=> bios_attrib['dracipaddress'],
           :dracusername    		=> bios_attrib['dracusername'],
           :dracpassword    		=> bios_attrib['dracpassword'],
           :nfsipaddress    		=> bios_attrib['nfsipaddress'],
           :nfssharepath    		=> bios_attrib['nfssharepath'],
           :memtest         		=> bios_attrib['memtest'],
           :procvirtualization 		=> bios_attrib['procvirtualization'],
           :proccores       		=> bios_attrib['proccores'],
           :bootmode 				=> bios_attrib['bootmode'],
           :bootseqretry 			=> bios_attrib['bootseqretry'],
           :integratedraid 			=> bios_attrib['integratedraid'],
           :usbports 				=> bios_attrib['usbports'],
           :internalusb 			=> bios_attrib['internalusb'],
           :internalsdcard 			=> bios_attrib['internalsdcard'],
           :internalsdcardredundancy => bios_attrib['internalsdcardredundancy'],
           :integratednetwork1 		=> bios_attrib['integratednetwork1'],  
		   :biosbootseq				=> bios_attrib['biosbootseq'])[:dracpassword].should == bios_attrib['dracpassword']
			end
			it "should not support dracpassword empty value" do
				expect { described_class.new(
			:ensure          		=> bios_attrib['ensure'],
           :name            		=> bios_attrib['name'],
           :dracipaddress   		=> bios_attrib['dracipaddress'],
           :dracusername    		=> bios_attrib['dracusername'],
           :dracpassword    		=> '',
           :nfsipaddress    		=> bios_attrib['nfsipaddress'],
           :nfssharepath    		=> bios_attrib['nfssharepath'],
           :memtest         		=> bios_attrib['memtest'],
           :procvirtualization 		=> bios_attrib['procvirtualization'],
           :proccores       		=> bios_attrib['proccores'],
           :bootmode 				=> bios_attrib['bootmode'],
           :bootseqretry 			=> bios_attrib['bootseqretry'],
           :integratedraid 			=> bios_attrib['integratedraid'],
           :usbports 				=> bios_attrib['usbports'],
           :internalusb 			=> bios_attrib['internalusb'],
           :internalsdcard 			=> bios_attrib['internalsdcard'],
           :internalsdcardredundancy => bios_attrib['internalsdcardredundancy'],
           :integratednetwork1 		=> bios_attrib['integratednetwork1'],  
		   :biosbootseq				=> bios_attrib['biosbootseq']) }.to raise_error Puppet::Error
			end
			#+++++++++++++++++
			it "should support nfsipaddress value" do
				described_class.new(
			:ensure          		=> bios_attrib['ensure'],
           :name            		=> bios_attrib['name'],
           :dracipaddress   		=> bios_attrib['dracipaddress'],
           :dracusername    		=> bios_attrib['dracusername'],
           :dracpassword    		=> bios_attrib['dracpassword'],
           :nfsipaddress    		=> bios_attrib['nfsipaddress'],
           :nfssharepath    		=> bios_attrib['nfssharepath'],
           :memtest         		=> bios_attrib['memtest'],
           :procvirtualization 		=> bios_attrib['procvirtualization'],
           :proccores       		=> bios_attrib['proccores'],
           :bootmode 				=> bios_attrib['bootmode'],
           :bootseqretry 			=> bios_attrib['bootseqretry'],
           :integratedraid 			=> bios_attrib['integratedraid'],
           :usbports 				=> bios_attrib['usbports'],
           :internalusb 			=> bios_attrib['internalusb'],
           :internalsdcard 			=> bios_attrib['internalsdcard'],
           :internalsdcardredundancy => bios_attrib['internalsdcardredundancy'],
           :integratednetwork1 		=> bios_attrib['integratednetwork1'],  
		   :biosbootseq				=> bios_attrib['biosbootseq'])[:nfsipaddress].should == bios_attrib['nfsipaddress']
			end
			it "should not support nfsipaddress empty value" do
				expect { described_class.new(
			:ensure          		=> bios_attrib['ensure'],
           :name            		=> bios_attrib['name'],
           :dracipaddress   		=> bios_attrib['dracipaddress'],
           :dracusername    		=> bios_attrib['dracusername'],
           :dracpassword    		=> bios_attrib['dracpassword'],
           :nfsipaddress    		=> '',
           :nfssharepath    		=> bios_attrib['nfssharepath'],
           :memtest         		=> bios_attrib['memtest'],
           :procvirtualization 		=> bios_attrib['procvirtualization'],
           :proccores       		=> bios_attrib['proccores'],
           :bootmode 				=> bios_attrib['bootmode'],
           :bootseqretry 			=> bios_attrib['bootseqretry'],
           :integratedraid 			=> bios_attrib['integratedraid'],
           :usbports 				=> bios_attrib['usbports'],
           :internalusb 			=> bios_attrib['internalusb'],
           :internalsdcard 			=> bios_attrib['internalsdcard'],
           :internalsdcardredundancy => bios_attrib['internalsdcardredundancy'],
           :integratednetwork1 		=> bios_attrib['integratednetwork1'],  
		   :biosbootseq				=> bios_attrib['biosbootseq']) }.to raise_error Puppet::Error
			end
			#+++++++++++++++++
			#+++++++++++++++++
			it "should support nfssharepath value" do
				described_class.new(
			:ensure          		=> bios_attrib['ensure'],
           :name            		=> bios_attrib['name'],
           :dracipaddress   		=> bios_attrib['dracipaddress'],
           :dracusername    		=> bios_attrib['dracusername'],
           :dracpassword    		=> bios_attrib['dracpassword'],
           :nfsipaddress    		=> bios_attrib['nfsipaddress'],
           :nfssharepath    		=> bios_attrib['nfssharepath'],
           :memtest         		=> bios_attrib['memtest'],
           :procvirtualization 		=> bios_attrib['procvirtualization'],
           :proccores       		=> bios_attrib['proccores'],
           :bootmode 				=> bios_attrib['bootmode'],
           :bootseqretry 			=> bios_attrib['bootseqretry'],
           :integratedraid 			=> bios_attrib['integratedraid'],
           :usbports 				=> bios_attrib['usbports'],
           :internalusb 			=> bios_attrib['internalusb'],
           :internalsdcard 			=> bios_attrib['internalsdcard'],
           :internalsdcardredundancy => bios_attrib['internalsdcardredundancy'],
           :integratednetwork1 		=> bios_attrib['integratednetwork1'],  
		   :biosbootseq				=> bios_attrib['biosbootseq'])[:nfssharepath].should == bios_attrib['nfssharepath']
			end
			it "should not support nfssharepath empty value" do
				expect { described_class.new(
			:ensure          		=> bios_attrib['ensure'],
           :name            		=> bios_attrib['name'],
           :dracipaddress   		=> bios_attrib['dracipaddress'],
           :dracusername    		=> bios_attrib['dracusername'],
           :dracpassword    		=> bios_attrib['dracpassword'],
           :nfsipaddress    		=> bios_attrib['nfsipaddress'],
           :nfssharepath    		=> '',
           :memtest         		=> bios_attrib['memtest'],
           :procvirtualization 		=> bios_attrib['procvirtualization'],
           :proccores       		=> bios_attrib['proccores'],
           :bootmode 				=> bios_attrib['bootmode'],
           :bootseqretry 			=> bios_attrib['bootseqretry'],
           :integratedraid 			=> bios_attrib['integratedraid'],
           :usbports 				=> bios_attrib['usbports'],
           :internalusb 			=> bios_attrib['internalusb'],
           :internalsdcard 			=> bios_attrib['internalsdcard'],
           :internalsdcardredundancy => bios_attrib['internalsdcardredundancy'],
           :integratednetwork1 		=> bios_attrib['integratednetwork1'],  
		   :biosbootseq				=> bios_attrib['biosbootseq']) }.to raise_error Puppet::Error
			end
			#+++++++++++++++++
			#+++++++++++++++++
			it "should support memtest value" do
				described_class.new(
			:ensure          		=> bios_attrib['ensure'],
           :name            		=> bios_attrib['name'],
           :dracipaddress   		=> bios_attrib['dracipaddress'],
           :dracusername    		=> bios_attrib['dracusername'],
           :dracpassword    		=> bios_attrib['dracpassword'],
           :nfsipaddress    		=> bios_attrib['nfsipaddress'],
           :nfssharepath    		=> bios_attrib['nfssharepath'],
           :memtest         		=> bios_attrib['memtest'],
           :procvirtualization 		=> bios_attrib['procvirtualization'],
           :proccores       		=> bios_attrib['proccores'],
           :bootmode 				=> bios_attrib['bootmode'],
           :bootseqretry 			=> bios_attrib['bootseqretry'],
           :integratedraid 			=> bios_attrib['integratedraid'],
           :usbports 				=> bios_attrib['usbports'],
           :internalusb 			=> bios_attrib['internalusb'],
           :internalsdcard 			=> bios_attrib['internalsdcard'],
           :internalsdcardredundancy => bios_attrib['internalsdcardredundancy'],
           :integratednetwork1 		=> bios_attrib['integratednetwork1'],  
		   :biosbootseq				=> bios_attrib['biosbootseq'])[:memtest].should == bios_attrib['memtest']
			end
			it "should not allow values other than Enabled or Disabled" do
				expect { described_class.new(
			:ensure          		=> bios_attrib['ensure'],
           :name            		=> bios_attrib['name'],
           :dracipaddress   		=> bios_attrib['dracipaddress'],
           :dracusername    		=> bios_attrib['dracusername'],
           :dracpassword    		=> bios_attrib['dracpassword'],
           :nfsipaddress    		=> bios_attrib['nfsipaddress'],
           :nfssharepath    		=> bios_attrib['nfssharepath'],
           :memtest         		=> 'sasasas',
           :procvirtualization 		=> bios_attrib['procvirtualization'],
           :proccores       		=> bios_attrib['proccores'],
           :bootmode 				=> bios_attrib['bootmode'],
           :bootseqretry 			=> bios_attrib['bootseqretry'],
           :integratedraid 			=> bios_attrib['integratedraid'],
           :usbports 				=> bios_attrib['usbports'],
           :internalusb 			=> bios_attrib['internalusb'],
           :internalsdcard 			=> bios_attrib['internalsdcard'],
           :internalsdcardredundancy => bios_attrib['internalsdcardredundancy'],
           :integratednetwork1 		=> bios_attrib['integratednetwork1'],  
		   :biosbootseq				=> bios_attrib['biosbootseq']) }.to raise_error Puppet::Error
			end
			it "should not support memtest empty value" do
				expect { described_class.new(
			:ensure          		=> bios_attrib['ensure'],
           :name            		=> bios_attrib['name'],
           :dracipaddress   		=> bios_attrib['dracipaddress'],
           :dracusername    		=> bios_attrib['dracusername'],
           :dracpassword    		=> bios_attrib['dracpassword'],
           :nfsipaddress    		=> bios_attrib['nfsipaddress'],
           :nfssharepath    		=> bios_attrib['nfssharepath'],
           :memtest         		=> '',
           :procvirtualization 		=> bios_attrib['procvirtualization'],
           :proccores       		=> bios_attrib['proccores'],
           :bootmode 				=> bios_attrib['bootmode'],
           :bootseqretry 			=> bios_attrib['bootseqretry'],
           :integratedraid 			=> bios_attrib['integratedraid'],
           :usbports 				=> bios_attrib['usbports'],
           :internalusb 			=> bios_attrib['internalusb'],
           :internalsdcard 			=> bios_attrib['internalsdcard'],
           :internalsdcardredundancy => bios_attrib['internalsdcardredundancy'],
           :integratednetwork1 		=> bios_attrib['integratednetwork1'],  
		   :biosbootseq				=> bios_attrib['biosbootseq'] ) }.to raise_error Puppet::Error
			end
			#+++++++++++++++++
			#+++++++++++++++++
			it "should support procvirtualization value" do
				described_class.new(
			:ensure          		=> bios_attrib['ensure'],
           :name            		=> bios_attrib['name'],
           :dracipaddress   		=> bios_attrib['dracipaddress'],
           :dracusername    		=> bios_attrib['dracusername'],
           :dracpassword    		=> bios_attrib['dracpassword'],
           :nfsipaddress    		=> bios_attrib['nfsipaddress'],
           :nfssharepath    		=> bios_attrib['nfssharepath'],
           :memtest         		=> bios_attrib['memtest'],
           :procvirtualization 		=> bios_attrib['procvirtualization'],
           :proccores       		=> bios_attrib['proccores'],
           :bootmode 				=> bios_attrib['bootmode'],
           :bootseqretry 			=> bios_attrib['bootseqretry'],
           :integratedraid 			=> bios_attrib['integratedraid'],
           :usbports 				=> bios_attrib['usbports'],
           :internalusb 			=> bios_attrib['internalusb'],
           :internalsdcard 			=> bios_attrib['internalsdcard'],
           :internalsdcardredundancy => bios_attrib['internalsdcardredundancy'],
           :integratednetwork1 		=> bios_attrib['integratednetwork1'],  
		   :biosbootseq				=> bios_attrib['biosbootseq'] )[:procvirtualization].should == bios_attrib['procvirtualization']
			end
			it "should not allow values other than Enabled or Disabled" do
				expect { described_class.new(
			:ensure          		=> bios_attrib['ensure'],
           :name            		=> bios_attrib['name'],
           :dracipaddress   		=> bios_attrib['dracipaddress'],
           :dracusername    		=> bios_attrib['dracusername'],
           :dracpassword    		=> bios_attrib['dracpassword'],
           :nfsipaddress    		=> bios_attrib['nfsipaddress'],
           :nfssharepath    		=> bios_attrib['nfssharepath'],
           :memtest         		=> bios_attrib['memtest'],
           :procvirtualization 		=> 'sdfdsfds',
           :proccores       		=> bios_attrib['proccores'],
           :bootmode 				=> bios_attrib['bootmode'],
           :bootseqretry 			=> bios_attrib['bootseqretry'],
           :integratedraid 			=> bios_attrib['integratedraid'],
           :usbports 				=> bios_attrib['usbports'],
           :internalusb 			=> bios_attrib['internalusb'],
           :internalsdcard 			=> bios_attrib['internalsdcard'],
           :internalsdcardredundancy => bios_attrib['internalsdcardredundancy'],
           :integratednetwork1 		=> bios_attrib['integratednetwork1'],  
		   :biosbootseq				=> bios_attrib['biosbootseq'] ) }.to raise_error Puppet::Error
			end
			it "should not support procvirtualization empty value" do
				expect { described_class.new(
			:ensure          		=> bios_attrib['ensure'],
           :name            		=> bios_attrib['name'],
           :dracipaddress   		=> bios_attrib['dracipaddress'],
           :dracusername    		=> bios_attrib['dracusername'],
           :dracpassword    		=> bios_attrib['dracpassword'],
           :nfsipaddress    		=> bios_attrib['nfsipaddress'],
           :nfssharepath    		=> bios_attrib['nfssharepath'],
           :memtest         		=> bios_attrib['memtest'],
           :procvirtualization 		=> '',
           :proccores       		=> bios_attrib['proccores'],
           :bootmode 				=> bios_attrib['bootmode'],
           :bootseqretry 			=> bios_attrib['bootseqretry'],
           :integratedraid 			=> bios_attrib['integratedraid'],
           :usbports 				=> bios_attrib['usbports'],
           :internalusb 			=> bios_attrib['internalusb'],
           :internalsdcard 			=> bios_attrib['internalsdcard'],
           :internalsdcardredundancy => bios_attrib['internalsdcardredundancy'],
           :integratednetwork1 		=> bios_attrib['integratednetwork1'],  
		   :biosbootseq				=> bios_attrib['biosbootseq'] ) }.to raise_error Puppet::Error
			end
			#+++++++++++++++++
			#+++++++++++++++++
			it "should support proccores value" do
				described_class.new(
			:ensure          		=> bios_attrib['ensure'],
           :name            		=> bios_attrib['name'],
           :dracipaddress   		=> bios_attrib['dracipaddress'],
           :dracusername    		=> bios_attrib['dracusername'],
           :dracpassword    		=> bios_attrib['dracpassword'],
           :nfsipaddress    		=> bios_attrib['nfsipaddress'],
           :nfssharepath    		=> bios_attrib['nfssharepath'],
           :memtest         		=> bios_attrib['memtest'],
           :procvirtualization 		=> bios_attrib['procvirtualization'],
           :proccores       		=> bios_attrib['proccores'],
           :bootmode 				=> bios_attrib['bootmode'],
           :bootseqretry 			=> bios_attrib['bootseqretry'],
           :integratedraid 			=> bios_attrib['integratedraid'],
           :usbports 				=> bios_attrib['usbports'],
           :internalusb 			=> bios_attrib['internalusb'],
           :internalsdcard 			=> bios_attrib['internalsdcard'],
           :internalsdcardredundancy => bios_attrib['internalsdcardredundancy'],
           :integratednetwork1 		=> bios_attrib['integratednetwork1'],  
		   :biosbootseq				=> bios_attrib['biosbootseq']  )[:proccores].should == bios_attrib['proccores']
			end
			
			it "should not support proccores empty value" do
				 described_class.new(
			:ensure          		=> bios_attrib['ensure'],
           :name            		=> bios_attrib['name'],
           :dracipaddress   		=> bios_attrib['dracipaddress'],
           :dracusername    		=> bios_attrib['dracusername'],
           :dracpassword    		=> bios_attrib['dracpassword'],
           :nfsipaddress    		=> bios_attrib['nfsipaddress'],
           :nfssharepath    		=> bios_attrib['nfssharepath'],
           :memtest         		=> bios_attrib['memtest'],
           :procvirtualization 		=> bios_attrib['procvirtualization'],
           :proccores       		=> '',
           :bootmode 				=> bios_attrib['bootmode'],
           :bootseqretry 			=> bios_attrib['bootseqretry'],
           :integratedraid 			=> bios_attrib['integratedraid'],
           :usbports 				=> bios_attrib['usbports'],
           :internalusb 			=> bios_attrib['internalusb'],
           :internalsdcard 			=> bios_attrib['internalsdcard'],
           :internalsdcardredundancy => bios_attrib['internalsdcardredundancy'],
           :integratednetwork1 		=> bios_attrib['integratednetwork1'],  
		   :biosbootseq				=> bios_attrib['biosbootseq']) 
			end
			#+++++++++++++++++
			#+++++++++++++++++
			it "should support bootmode value" do
				described_class.new(
			:ensure          		=> bios_attrib['ensure'],
           :name            		=> bios_attrib['name'],
           :dracipaddress   		=> bios_attrib['dracipaddress'],
           :dracusername    		=> bios_attrib['dracusername'],
           :dracpassword    		=> bios_attrib['dracpassword'],
           :nfsipaddress    		=> bios_attrib['nfsipaddress'],
           :nfssharepath    		=> bios_attrib['nfssharepath'],
           :memtest         		=> bios_attrib['memtest'],
           :procvirtualization 		=> bios_attrib['procvirtualization'],
           :proccores       		=> bios_attrib['proccores'],
           :bootmode 				=> bios_attrib['bootmode'],
           :bootseqretry 			=> bios_attrib['bootseqretry'],
           :integratedraid 			=> bios_attrib['integratedraid'],
           :usbports 				=> bios_attrib['usbports'],
           :internalusb 			=> bios_attrib['internalusb'],
           :internalsdcard 			=> bios_attrib['internalsdcard'],
           :internalsdcardredundancy => bios_attrib['internalsdcardredundancy'],
           :integratednetwork1 		=> bios_attrib['integratednetwork1'],  
		   :biosbootseq				=> bios_attrib['biosbootseq']  )[:bootmode].should == bios_attrib['bootmode']
			end
=begin			
			it "should not support bootmode empty value" do
				expect { described_class.new(:name => 'importbiosconfiguration',
            :dracipaddress   => '172.17.10.106',
            :dracusername    => 'root',
            :dracpassword    => 'calvin',
            :nfsipaddress    => '172.28.10.191',
            :nfssharepath    => '/root/SharedNFS',
            :memtest         => 'Disabled',
            :procvirtualization => 'Enabled',
            :proccores       => 'ALL',
            :bootmode        => '',
            :bootseqretry    => 'Disabled',
            :integratedraid  => 'Disabled',
            :usbports        => 'AllOn',
            :internalusb     => 'Off',
            :internalsdcard  => 'On',
            :internalsdcardredundancy => 'Mirror',
            :integratednetwork1 => 'Enabled',:biosbootseq		=> 'HardDisk.List.1-1, NIC.Integrated.1-1-1, NIC.Integrated.1-2-1' ) }.to raise_error Puppet::Error
			end
=end			
			#+++++++++++++++++
			#+++++++++++++++++
			it "should support bootseqretry value" do
				described_class.new(
			:ensure          		=> bios_attrib['ensure'],
           :name            		=> bios_attrib['name'],
           :dracipaddress   		=> bios_attrib['dracipaddress'],
           :dracusername    		=> bios_attrib['dracusername'],
           :dracpassword    		=> bios_attrib['dracpassword'],
           :nfsipaddress    		=> bios_attrib['nfsipaddress'],
           :nfssharepath    		=> bios_attrib['nfssharepath'],
           :memtest         		=> bios_attrib['memtest'],
           :procvirtualization 		=> bios_attrib['procvirtualization'],
           :proccores       		=> bios_attrib['proccores'],
           :bootmode 				=> bios_attrib['bootmode'],
           :bootseqretry 			=> bios_attrib['bootseqretry'],
           :integratedraid 			=> bios_attrib['integratedraid'],
           :usbports 				=> bios_attrib['usbports'],
           :internalusb 			=> bios_attrib['internalusb'],
           :internalsdcard 			=> bios_attrib['internalsdcard'],
           :internalsdcardredundancy => bios_attrib['internalsdcardredundancy'],
           :integratednetwork1 		=> bios_attrib['integratednetwork1'],  
		   :biosbootseq				=> bios_attrib['biosbootseq'])[:bootseqretry].should == bios_attrib['bootseqretry']
			end
			it "should not allow values other than Enabled or Disabled" do
				expect { described_class.new(
			:ensure          		=> bios_attrib['ensure'],
           :name            		=> bios_attrib['name'],
           :dracipaddress   		=> bios_attrib['dracipaddress'],
           :dracusername    		=> bios_attrib['dracusername'],
           :dracpassword    		=> bios_attrib['dracpassword'],
           :nfsipaddress    		=> bios_attrib['nfsipaddress'],
           :nfssharepath    		=> bios_attrib['nfssharepath'],
           :memtest         		=> bios_attrib['memtest'],
           :procvirtualization 		=> bios_attrib['procvirtualization'],
           :proccores       		=> bios_attrib['proccores'],
           :bootmode 				=> bios_attrib['bootmode'],
           :bootseqretry 			=> 'asdass',
           :integratedraid 			=> bios_attrib['integratedraid'],
           :usbports 				=> bios_attrib['usbports'],
           :internalusb 			=> bios_attrib['internalusb'],
           :internalsdcard 			=> bios_attrib['internalsdcard'],
           :internalsdcardredundancy => bios_attrib['internalsdcardredundancy'],
           :integratednetwork1 		=> bios_attrib['integratednetwork1'],  
		   :biosbootseq				=> bios_attrib['biosbootseq'] ) }.to raise_error Puppet::Error
			end
			it "should not support bootseqretry empty value" do
				expect { described_class.new(
			:ensure          		=> bios_attrib['ensure'],
           :name            		=> bios_attrib['name'],
           :dracipaddress   		=> bios_attrib['dracipaddress'],
           :dracusername    		=> bios_attrib['dracusername'],
           :dracpassword    		=> bios_attrib['dracpassword'],
           :nfsipaddress    		=> bios_attrib['nfsipaddress'],
           :nfssharepath    		=> bios_attrib['nfssharepath'],
           :memtest         		=> bios_attrib['memtest'],
           :procvirtualization 		=> bios_attrib['procvirtualization'],
           :proccores       		=> bios_attrib['proccores'],
           :bootmode 				=> bios_attrib['bootmode'],
           :bootseqretry 			=> '',
           :integratedraid 			=> bios_attrib['integratedraid'],
           :usbports 				=> bios_attrib['usbports'],
           :internalusb 			=> bios_attrib['internalusb'],
           :internalsdcard 			=> bios_attrib['internalsdcard'],
           :internalsdcardredundancy => bios_attrib['internalsdcardredundancy'],
           :integratednetwork1 		=> bios_attrib['integratednetwork1'],  
		   :biosbootseq				=> bios_attrib['biosbootseq'] ) }.to raise_error Puppet::Error
			end
			#+++++++++++++++++
			#+++++++++++++++++
			it "should support integratedraid value" do
				described_class.new(
			:ensure          		=> bios_attrib['ensure'],
           :name            		=> bios_attrib['name'],
           :dracipaddress   		=> bios_attrib['dracipaddress'],
           :dracusername    		=> bios_attrib['dracusername'],
           :dracpassword    		=> bios_attrib['dracpassword'],
           :nfsipaddress    		=> bios_attrib['nfsipaddress'],
           :nfssharepath    		=> bios_attrib['nfssharepath'],
           :memtest         		=> bios_attrib['memtest'],
           :procvirtualization 		=> bios_attrib['procvirtualization'],
           :proccores       		=> bios_attrib['proccores'],
           :bootmode 				=> bios_attrib['bootmode'],
           :bootseqretry 			=> bios_attrib['bootseqretry'],
           :integratedraid 			=> bios_attrib['integratedraid'],
           :usbports 				=> bios_attrib['usbports'],
           :internalusb 			=> bios_attrib['internalusb'],
           :internalsdcard 			=> bios_attrib['internalsdcard'],
           :internalsdcardredundancy => bios_attrib['internalsdcardredundancy'],
           :integratednetwork1 		=> bios_attrib['integratednetwork1'],  
		   :biosbootseq				=> bios_attrib['biosbootseq'] )[:integratedraid].should == bios_attrib['integratedraid']
			end
			it "should not allow values other than Enabled or Disabled" do
				expect { described_class.new(
			:ensure          		=> bios_attrib['ensure'],
           :name            		=> bios_attrib['name'],
           :dracipaddress   		=> bios_attrib['dracipaddress'],
           :dracusername    		=> bios_attrib['dracusername'],
           :dracpassword    		=> bios_attrib['dracpassword'],
           :nfsipaddress    		=> bios_attrib['nfsipaddress'],
           :nfssharepath    		=> bios_attrib['nfssharepath'],
           :memtest         		=> bios_attrib['memtest'],
           :procvirtualization 		=> bios_attrib['procvirtualization'],
           :proccores       		=> bios_attrib['proccores'],
           :bootmode 				=> bios_attrib['bootmode'],
           :bootseqretry 			=> bios_attrib['bootseqretry'],
           :integratedraid 			=> 'asdassadsa',
           :usbports 				=> bios_attrib['usbports'],
           :internalusb 			=> bios_attrib['internalusb'],
           :internalsdcard 			=> bios_attrib['internalsdcard'],
           :internalsdcardredundancy => bios_attrib['internalsdcardredundancy'],
           :integratednetwork1 		=> bios_attrib['integratednetwork1'],  
		   :biosbootseq				=> bios_attrib['biosbootseq'] ) }.to raise_error Puppet::Error
			end
			it "should not support integratedraid empty value" do
				expect { described_class.new(
			:ensure          		=> bios_attrib['ensure'],
           :name            		=> bios_attrib['name'],
           :dracipaddress   		=> bios_attrib['dracipaddress'],
           :dracusername    		=> bios_attrib['dracusername'],
           :dracpassword    		=> bios_attrib['dracpassword'],
           :nfsipaddress    		=> bios_attrib['nfsipaddress'],
           :nfssharepath    		=> bios_attrib['nfssharepath'],
           :memtest         		=> bios_attrib['memtest'],
           :procvirtualization 		=> bios_attrib['procvirtualization'],
           :proccores       		=> bios_attrib['proccores'],
           :bootmode 				=> bios_attrib['bootmode'],
           :bootseqretry 			=> bios_attrib['bootseqretry'],
           :integratedraid 			=> '',
           :usbports 				=> bios_attrib['usbports'],
           :internalusb 			=> bios_attrib['internalusb'],
           :internalsdcard 			=> bios_attrib['internalsdcard'],
           :internalsdcardredundancy => bios_attrib['internalsdcardredundancy'],
           :integratednetwork1 		=> bios_attrib['integratednetwork1'],  
		   :biosbootseq				=> bios_attrib['biosbootseq'] ) }.to raise_error Puppet::Error
			end
			#+++++++++++++++++
			#+++++++++++++++++
			it "should support usbports value" do
				described_class.new(
			:ensure          		=> bios_attrib['ensure'],
           :name            		=> bios_attrib['name'],
           :dracipaddress   		=> bios_attrib['dracipaddress'],
           :dracusername    		=> bios_attrib['dracusername'],
           :dracpassword    		=> bios_attrib['dracpassword'],
           :nfsipaddress    		=> bios_attrib['nfsipaddress'],
           :nfssharepath    		=> bios_attrib['nfssharepath'],
           :memtest         		=> bios_attrib['memtest'],
           :procvirtualization 		=> bios_attrib['procvirtualization'],
           :proccores       		=> bios_attrib['proccores'],
           :bootmode 				=> bios_attrib['bootmode'],
           :bootseqretry 			=> bios_attrib['bootseqretry'],
           :integratedraid 			=> bios_attrib['integratedraid'],
           :usbports 				=> bios_attrib['usbports'],
           :internalusb 			=> bios_attrib['internalusb'],
           :internalsdcard 			=> bios_attrib['internalsdcard'],
           :internalsdcardredundancy => bios_attrib['internalsdcardredundancy'],
           :integratednetwork1 		=> bios_attrib['integratednetwork1'],  
		   :biosbootseq				=> bios_attrib['biosbootseq'] )[:usbports].should == bios_attrib['usbports']
			end
			
			it "should not support usbports empty value" do
				described_class.new(
			:ensure          		=> bios_attrib['ensure'],
           :name            		=> bios_attrib['name'],
           :dracipaddress   		=> bios_attrib['dracipaddress'],
           :dracusername    		=> bios_attrib['dracusername'],
           :dracpassword    		=> bios_attrib['dracpassword'],
           :nfsipaddress    		=> bios_attrib['nfsipaddress'],
           :nfssharepath    		=> bios_attrib['nfssharepath'],
           :memtest         		=> bios_attrib['memtest'],
           :procvirtualization 		=> bios_attrib['procvirtualization'],
           :proccores       		=> bios_attrib['proccores'],
           :bootmode 				=> bios_attrib['bootmode'],
           :bootseqretry 			=> bios_attrib['bootseqretry'],
           :integratedraid 			=> bios_attrib['integratedraid'],
           :usbports 				=> '',
           :internalusb 			=> bios_attrib['internalusb'],
           :internalsdcard 			=> bios_attrib['internalsdcard'],
           :internalsdcardredundancy => bios_attrib['internalsdcardredundancy'],
           :integratednetwork1 		=> bios_attrib['integratednetwork1'],  
		   :biosbootseq				=> bios_attrib['biosbootseq']  ) 
			end
			#+++++++++++++++++
			#+++++++++++++++++
			it "should support internalusb value" do
				described_class.new(
			:ensure          		=> bios_attrib['ensure'],
           :name            		=> bios_attrib['name'],
           :dracipaddress   		=> bios_attrib['dracipaddress'],
           :dracusername    		=> bios_attrib['dracusername'],
           :dracpassword    		=> bios_attrib['dracpassword'],
           :nfsipaddress    		=> bios_attrib['nfsipaddress'],
           :nfssharepath    		=> bios_attrib['nfssharepath'],
           :memtest         		=> bios_attrib['memtest'],
           :procvirtualization 		=> bios_attrib['procvirtualization'],
           :proccores       		=> bios_attrib['proccores'],
           :bootmode 				=> bios_attrib['bootmode'],
           :bootseqretry 			=> bios_attrib['bootseqretry'],
           :integratedraid 			=> bios_attrib['integratedraid'],
           :usbports 				=> bios_attrib['usbports'],
           :internalusb 			=> bios_attrib['internalusb'],
           :internalsdcard 			=> bios_attrib['internalsdcard'],
           :internalsdcardredundancy => bios_attrib['internalsdcardredundancy'],
           :integratednetwork1 		=> bios_attrib['integratednetwork1'],  
		   :biosbootseq				=> bios_attrib['biosbootseq']  )[:internalusb].should == bios_attrib['internalusb']
			end
			it "should not allow values other than On or off" do
				expect { described_class.new(
			:ensure          		=> bios_attrib['ensure'],
           :name            		=> bios_attrib['name'],
           :dracipaddress   		=> bios_attrib['dracipaddress'],
           :dracusername    		=> bios_attrib['dracusername'],
           :dracpassword    		=> bios_attrib['dracpassword'],
           :nfsipaddress    		=> bios_attrib['nfsipaddress'],
           :nfssharepath    		=> bios_attrib['nfssharepath'],
           :memtest         		=> bios_attrib['memtest'],
           :procvirtualization 		=> bios_attrib['procvirtualization'],
           :proccores       		=> bios_attrib['proccores'],
           :bootmode 				=> bios_attrib['bootmode'],
           :bootseqretry 			=> bios_attrib['bootseqretry'],
           :integratedraid 			=> bios_attrib['integratedraid'],
           :usbports 				=> bios_attrib['usbports'],
           :internalusb 			=> 'asdsadsada',
           :internalsdcard 			=> bios_attrib['internalsdcard'],
           :internalsdcardredundancy => bios_attrib['internalsdcardredundancy'],
           :integratednetwork1 		=> bios_attrib['integratednetwork1'],  
		   :biosbootseq				=> bios_attrib['biosbootseq'] ) }.to raise_error Puppet::Error
			end
			it "should not support internalusb empty value" do
				expect { described_class.new(
			:ensure          		=> bios_attrib['ensure'],
           :name            		=> bios_attrib['name'],
           :dracipaddress   		=> bios_attrib['dracipaddress'],
           :dracusername    		=> bios_attrib['dracusername'],
           :dracpassword    		=> bios_attrib['dracpassword'],
           :nfsipaddress    		=> bios_attrib['nfsipaddress'],
           :nfssharepath    		=> bios_attrib['nfssharepath'],
           :memtest         		=> bios_attrib['memtest'],
           :procvirtualization 		=> bios_attrib['procvirtualization'],
           :proccores       		=> bios_attrib['proccores'],
           :bootmode 				=> bios_attrib['bootmode'],
           :bootseqretry 			=> bios_attrib['bootseqretry'],
           :integratedraid 			=> bios_attrib['integratedraid'],
           :usbports 				=> bios_attrib['usbports'],
           :internalusb 			=> '',
           :internalsdcard 			=> bios_attrib['internalsdcard'],
           :internalsdcardredundancy => bios_attrib['internalsdcardredundancy'],
           :integratednetwork1 		=> bios_attrib['integratednetwork1'],  
		   :biosbootseq				=> bios_attrib['biosbootseq'] ) }.to raise_error Puppet::Error
			end
			#+++++++++++++++++
			#+++++++++++++++++
			it "should support internalsdcard value" do
				described_class.new(
			:ensure          		=> bios_attrib['ensure'],
           :name            		=> bios_attrib['name'],
           :dracipaddress   		=> bios_attrib['dracipaddress'],
           :dracusername    		=> bios_attrib['dracusername'],
           :dracpassword    		=> bios_attrib['dracpassword'],
           :nfsipaddress    		=> bios_attrib['nfsipaddress'],
           :nfssharepath    		=> bios_attrib['nfssharepath'],
           :memtest         		=> bios_attrib['memtest'],
           :procvirtualization 		=> bios_attrib['procvirtualization'],
           :proccores       		=> bios_attrib['proccores'],
           :bootmode 				=> bios_attrib['bootmode'],
           :bootseqretry 			=> bios_attrib['bootseqretry'],
           :integratedraid 			=> bios_attrib['integratedraid'],
           :usbports 				=> bios_attrib['usbports'],
           :internalusb 			=> bios_attrib['internalusb'],
           :internalsdcard 			=> bios_attrib['internalsdcard'],
           :internalsdcardredundancy => bios_attrib['internalsdcardredundancy'],
           :integratednetwork1 		=> bios_attrib['integratednetwork1'],  
		   :biosbootseq				=> bios_attrib['biosbootseq'] )[:internalsdcard].should == bios_attrib['internalsdcard']
			end
			it "should not allow values other than On or off" do
				expect { described_class.new(
			:ensure          		=> bios_attrib['ensure'],
           :name            		=> bios_attrib['name'],
           :dracipaddress   		=> bios_attrib['dracipaddress'],
           :dracusername    		=> bios_attrib['dracusername'],
           :dracpassword    		=> bios_attrib['dracpassword'],
           :nfsipaddress    		=> bios_attrib['nfsipaddress'],
           :nfssharepath    		=> bios_attrib['nfssharepath'],
           :memtest         		=> bios_attrib['memtest'],
           :procvirtualization 		=> bios_attrib['procvirtualization'],
           :proccores       		=> bios_attrib['proccores'],
           :bootmode 				=> bios_attrib['bootmode'],
           :bootseqretry 			=> bios_attrib['bootseqretry'],
           :integratedraid 			=> bios_attrib['integratedraid'],
           :usbports 				=> bios_attrib['usbports'],
           :internalusb 			=> bios_attrib['internalusb'],
           :internalsdcard 			=> 'asdasdasdasda',
           :internalsdcardredundancy => bios_attrib['internalsdcardredundancy'],
           :integratednetwork1 		=> bios_attrib['integratednetwork1'],  
		   :biosbootseq				=> bios_attrib['biosbootseq'] ) }.to raise_error Puppet::Error
			end
			it "should not support internalsdcard empty value" do
				expect { described_class.new(
			:ensure          		=> bios_attrib['ensure'],
           :name            		=> bios_attrib['name'],
           :dracipaddress   		=> bios_attrib['dracipaddress'],
           :dracusername    		=> bios_attrib['dracusername'],
           :dracpassword    		=> bios_attrib['dracpassword'],
           :nfsipaddress    		=> bios_attrib['nfsipaddress'],
           :nfssharepath    		=> bios_attrib['nfssharepath'],
           :memtest         		=> bios_attrib['memtest'],
           :procvirtualization 		=> bios_attrib['procvirtualization'],
           :proccores       		=> bios_attrib['proccores'],
           :bootmode 				=> bios_attrib['bootmode'],
           :bootseqretry 			=> bios_attrib['bootseqretry'],
           :integratedraid 			=> bios_attrib['integratedraid'],
           :usbports 				=> bios_attrib['usbports'],
           :internalusb 			=> bios_attrib['internalusb'],
           :internalsdcard 			=> '',
           :internalsdcardredundancy => bios_attrib['internalsdcardredundancy'],
           :integratednetwork1 		=> bios_attrib['integratednetwork1'],  
		   :biosbootseq				=> bios_attrib['biosbootseq'] ) }.to raise_error Puppet::Error
			end
			#+++++++++++++++++
			#+++++++++++++++++
			it "should support internalsdcardredundancy value" do
				described_class.new(
			:ensure          		=> bios_attrib['ensure'],
           :name            		=> bios_attrib['name'],
           :dracipaddress   		=> bios_attrib['dracipaddress'],
           :dracusername    		=> bios_attrib['dracusername'],
           :dracpassword    		=> bios_attrib['dracpassword'],
           :nfsipaddress    		=> bios_attrib['nfsipaddress'],
           :nfssharepath    		=> bios_attrib['nfssharepath'],
           :memtest         		=> bios_attrib['memtest'],
           :procvirtualization 		=> bios_attrib['procvirtualization'],
           :proccores       		=> bios_attrib['proccores'],
           :bootmode 				=> bios_attrib['bootmode'],
           :bootseqretry 			=> bios_attrib['bootseqretry'],
           :integratedraid 			=> bios_attrib['integratedraid'],
           :usbports 				=> bios_attrib['usbports'],
           :internalusb 			=> bios_attrib['internalusb'],
           :internalsdcard 			=> bios_attrib['internalsdcard'],
           :internalsdcardredundancy => bios_attrib['internalsdcardredundancy'],
           :integratednetwork1 		=> bios_attrib['integratednetwork1'],  
		   :biosbootseq				=> bios_attrib['biosbootseq'] )[:internalsdcardredundancy].should == bios_attrib['internalsdcardredundancy']
			end
			
			it "should not support internalsdcardredundancy empty value" do
				 described_class.new(
			:ensure          		=> bios_attrib['ensure'],
           :name            		=> bios_attrib['name'],
           :dracipaddress   		=> bios_attrib['dracipaddress'],
           :dracusername    		=> bios_attrib['dracusername'],
           :dracpassword    		=> bios_attrib['dracpassword'],
           :nfsipaddress    		=> bios_attrib['nfsipaddress'],
           :nfssharepath    		=> bios_attrib['nfssharepath'],
           :memtest         		=> bios_attrib['memtest'],
           :procvirtualization 		=> bios_attrib['procvirtualization'],
           :proccores       		=> bios_attrib['proccores'],
           :bootmode 				=> bios_attrib['bootmode'],
           :bootseqretry 			=> bios_attrib['bootseqretry'],
           :integratedraid 			=> bios_attrib['integratedraid'],
           :usbports 				=> bios_attrib['usbports'],
           :internalusb 			=> bios_attrib['internalusb'],
           :internalsdcard 			=> bios_attrib['internalsdcard'],
           :internalsdcardredundancy => '',
           :integratednetwork1 		=> bios_attrib['integratednetwork1'],  
		   :biosbootseq				=> bios_attrib['biosbootseq'] ) 
			end
			#+++++++++++++++++
			#+++++++++++++++++
			it "should support integratednetwork1 value" do
				described_class.new(
			:ensure          		=> bios_attrib['ensure'],
           :name            		=> bios_attrib['name'],
           :dracipaddress   		=> bios_attrib['dracipaddress'],
           :dracusername    		=> bios_attrib['dracusername'],
           :dracpassword    		=> bios_attrib['dracpassword'],
           :nfsipaddress    		=> bios_attrib['nfsipaddress'],
           :nfssharepath    		=> bios_attrib['nfssharepath'],
           :memtest         		=> bios_attrib['memtest'],
           :procvirtualization 		=> bios_attrib['procvirtualization'],
           :proccores       		=> bios_attrib['proccores'],
           :bootmode 				=> bios_attrib['bootmode'],
           :bootseqretry 			=> bios_attrib['bootseqretry'],
           :integratedraid 			=> bios_attrib['integratedraid'],
           :usbports 				=> bios_attrib['usbports'],
           :internalusb 			=> bios_attrib['internalusb'],
           :internalsdcard 			=> bios_attrib['internalsdcard'],
           :internalsdcardredundancy => bios_attrib['internalsdcardredundancy'],
           :integratednetwork1 		=> bios_attrib['integratednetwork1'],  
		   :biosbootseq				=> bios_attrib['biosbootseq'] )[:integratednetwork1].should == bios_attrib['integratednetwork1']
			end
			it "should not allow values other than Enabled or Disabled" do
				expect { described_class.new(
			:ensure          		=> bios_attrib['ensure'],
           :name            		=> bios_attrib['name'],
           :dracipaddress   		=> bios_attrib['dracipaddress'],
           :dracusername    		=> bios_attrib['dracusername'],
           :dracpassword    		=> bios_attrib['dracpassword'],
           :nfsipaddress    		=> bios_attrib['nfsipaddress'],
           :nfssharepath    		=> bios_attrib['nfssharepath'],
           :memtest         		=> bios_attrib['memtest'],
           :procvirtualization 		=> bios_attrib['procvirtualization'],
           :proccores       		=> bios_attrib['proccores'],
           :bootmode 				=> bios_attrib['bootmode'],
           :bootseqretry 			=> bios_attrib['bootseqretry'],
           :integratedraid 			=> bios_attrib['integratedraid'],
           :usbports 				=> bios_attrib['usbports'],
           :internalusb 			=> bios_attrib['internalusb'],
           :internalsdcard 			=> bios_attrib['internalsdcard'],
           :internalsdcardredundancy => bios_attrib['internalsdcardredundancy'],
           :integratednetwork1 		=> 'sadsadasdas',  
		   :biosbootseq				=> bios_attrib['biosbootseq']) }.to raise_error Puppet::Error
			end
			it "should not support integratednetwork1 empty value" do
				expect { described_class.new(
			:ensure          		=> bios_attrib['ensure'],
           :name            		=> bios_attrib['name'],
           :dracipaddress   		=> bios_attrib['dracipaddress'],
           :dracusername    		=> bios_attrib['dracusername'],
           :dracpassword    		=> bios_attrib['dracpassword'],
           :nfsipaddress    		=> bios_attrib['nfsipaddress'],
           :nfssharepath    		=> bios_attrib['nfssharepath'],
           :memtest         		=> bios_attrib['memtest'],
           :procvirtualization 		=> bios_attrib['procvirtualization'],
           :proccores       		=> bios_attrib['proccores'],
           :bootmode 				=> bios_attrib['bootmode'],
           :bootseqretry 			=> bios_attrib['bootseqretry'],
           :integratedraid 			=> bios_attrib['integratedraid'],
           :usbports 				=> bios_attrib['usbports'],
           :internalusb 			=> bios_attrib['internalusb'],
           :internalsdcard 			=> bios_attrib['internalsdcard'],
           :internalsdcardredundancy => bios_attrib['internalsdcardredundancy'],
           :integratednetwork1 		=> '',  
		   :biosbootseq				=> bios_attrib['biosbootseq']) }.to raise_error Puppet::Error
			end
			#+++++++++++++++++
			#+++++++++++++++++
			it "should support biosbootseq value" do
				described_class.new(
			:ensure          		=> bios_attrib['ensure'],
           :name            		=> bios_attrib['name'],
           :dracipaddress   		=> bios_attrib['dracipaddress'],
           :dracusername    		=> bios_attrib['dracusername'],
           :dracpassword    		=> bios_attrib['dracpassword'],
           :nfsipaddress    		=> bios_attrib['nfsipaddress'],
           :nfssharepath    		=> bios_attrib['nfssharepath'],
           :memtest         		=> bios_attrib['memtest'],
           :procvirtualization 		=> bios_attrib['procvirtualization'],
           :proccores       		=> bios_attrib['proccores'],
           :bootmode 				=> bios_attrib['bootmode'],
           :bootseqretry 			=> bios_attrib['bootseqretry'],
           :integratedraid 			=> bios_attrib['integratedraid'],
           :usbports 				=> bios_attrib['usbports'],
           :internalusb 			=> bios_attrib['internalusb'],
           :internalsdcard 			=> bios_attrib['internalsdcard'],
           :internalsdcardredundancy => bios_attrib['internalsdcardredundancy'],
           :integratednetwork1 		=> bios_attrib['integratednetwork1'],  
		   :biosbootseq				=> bios_attrib['biosbootseq'] )[:biosbootseq].should == bios_attrib['biosbootseq']
			end
			
			it "should not support biosbootseq empty value" do
				described_class.new(
		   :ensure          		=> bios_attrib['ensure'],
           :name            		=> bios_attrib['name'],
           :dracipaddress   		=> bios_attrib['dracipaddress'],
           :dracusername    		=> bios_attrib['dracusername'],
           :dracpassword    		=> bios_attrib['dracpassword'],
           :nfsipaddress    		=> bios_attrib['nfsipaddress'],
           :nfssharepath    		=> bios_attrib['nfssharepath'],
           :memtest         		=> bios_attrib['memtest'],
           :procvirtualization 		=> bios_attrib['procvirtualization'],
           :proccores       		=> bios_attrib['proccores'],
           :bootmode 				=> bios_attrib['bootmode'],
           :bootseqretry 			=> bios_attrib['bootseqretry'],
           :integratedraid 			=> bios_attrib['integratedraid'],
           :usbports 				=> bios_attrib['usbports'],
           :internalusb 			=> bios_attrib['internalusb'],
           :internalsdcard 			=> bios_attrib['internalsdcard'],
           :internalsdcardredundancy => bios_attrib['internalsdcardredundancy'],
           :integratednetwork1 		=> bios_attrib['integratednetwork1'],  
		   :biosbootseq				=> '') 
			end
			#+++++++++++++++++
    
	end
    
end
