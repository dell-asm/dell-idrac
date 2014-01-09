#! /usr/bin/env ruby
provider_path = Pathname.new(__FILE__).parent.parent
#require File.join(provider_path, 'idrac')

require 'spec_helper'
require 'yaml'
require 'rspec/expectations'
#require 'puppet/provider/importbiosconfiguration'

describe Puppet::Type.type(:importbiosconfiguration).provider(:importbiosconfiguration) do
	bios_conf=YAML.load_file(get_configpath('idrac','bios_config.yml'))
	bios_attrib = bios_conf['bios_configuration_provider']
	
    let :importbiosconfiguration do
        Puppet::Type.type(:importbiosconfiguration).new(
           :ensure          => bios_attrib['ensure'],
           :name            => bios_attrib['name'],
           :dracipaddress   => bios_attrib['dracipaddress'],
           :dracusername    => bios_attrib['dracusername'],
           :dracpassword    => bios_attrib['dracpassword'],
           :nfsipaddress    => bios_attrib['nfsipaddress'],
           :nfssharepath    => bios_attrib['nfssharepath'],
           :memtest         => bios_attrib['memtest'],
           :procvirtualization => bios_attrib['procvirtualization'],
           :proccores       => bios_attrib['proccores'],
           :bootmode => bios_attrib['bootmode'],
           :bootseqretry => bios_attrib['bootseqretry'],
           :integratedraid => bios_attrib['integratedraid'],
           :usbports => bios_attrib['usbports'],
           :internalusb => bios_attrib['internalusb'],
           :internalsdcard => bios_attrib['internalsdcard'],
           :internalsdcardredundancy => bios_attrib['internalsdcardredundancy'],
           :integratednetwork1 => bios_attrib['integratednetwork1']            
        )
    end

    describe "when asking exists?" do
        it "should retun true if resource is present" do
             importbiosconfiguration.provider.set(:ensure => :present)
             importbiosconfiguration.provider.should_not be_exists
        end
        it "Create bios configuration" do
            importbiosconfiguration.provider.create
           
        end
    end
    

end
