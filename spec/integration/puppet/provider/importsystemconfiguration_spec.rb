#! /usr/bin/env ruby
provider_path = Pathname.new(__FILE__).parent.parent
require 'spec_helper'
require 'yaml'

describe Puppet::Type.type(:importsystemconfiguration).provider(:importsystemconfiguration) do
	sys_conf = YAML.load_file(get_configpath('idrac','system_config.yml'))
	sys_attrib = sys_conf['sys_configuration_provider']
	
    let :importsystemconfiguration do
        Puppet::Type.type(:importsystemconfiguration).new(
		   :ensure			=> sys_attrib['ensure'],
           :name            => sys_attrib['name'],
           :dracipaddress   => sys_attrib['dracipaddress'],
           :dracusername    => sys_attrib['dracusername'],
           :dracpassword    => sys_attrib['dracpassword'],
           :configxmlfilename => sys_attrib['configxmlfilename'],
           :nfsipaddress    => sys_attrib['nfsipaddress'],
           :nfssharepath    => sys_attrib['nfssharepath']
        )
    end

    describe "when asking exists?" do
        it "should retun true if resource is present" do
             importsystemconfiguration.provider.set(:ensure => :present)
           #  importsystemconfiguration.provider.should_not be_exists
        end
        it "Create system configuration" do
            #importsystemconfiguration.provider.create
           
        end
    end
    

end
