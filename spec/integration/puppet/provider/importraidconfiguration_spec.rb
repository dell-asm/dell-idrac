#! /usr/bin/env ruby
provider_path = Pathname.new(__FILE__).parent.parent
require 'spec_helper'
require 'yaml'

describe Puppet::Type.type(:importraidconfiguration).provider(:importraidconfiguration) do
	raid_conf =YAML.load_file(get_configpath('idrac','raid_config.yml'))
	raid_attrib = raid_conf['raid_configuration_provider']
	
    let :importraidconfiguration do
        Puppet::Type.type(:importraidconfiguration).new(
		   :ensure			=> raid_attrib['ensure'],
           :name            => raid_attrib['name'],
           :dracipaddress   => raid_attrib['dracipaddress'],
           :dracusername    => raid_attrib['dracusername'],
           :dracpassword    => raid_attrib['dracpassword'],
           :raidtype        => raid_attrib['raidtype'], 
           :nfsipaddress    => raid_attrib['nfsipaddress'],
           :nfssharepath    => raid_attrib['nfssharepath'],
           :disk            => raid_attrib['disk']
        )
    end

    describe "when asking exists?" do
        it "should retun true if resource is present" do
            importraidconfiguration.provider.set(:ensure => :present)
            importraidconfiguration.provider.should_not be_exists
        end
        it "Create npar setting" do
            importraidconfiguration.provider.create
           
        end
    end
    

end
