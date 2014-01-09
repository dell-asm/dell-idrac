#! /usr/bin/env ruby
provider_path = Pathname.new(__FILE__).parent.parent
require 'spec_helper'
require 'yaml'

describe Puppet::Type.type(:importnparsetting).provider(:importnparsetting) do
		
	npar_conf = YAML.load_file(get_configpath('idrac','npar_config.yml'))
	npar_attrib = npar_conf['npar_configuration_provider']
	
    let :importnparsetting do
        Puppet::Type.type(:importnparsetting).new(
		   :ensure			=> npar_attrib['ensure'],
           :name            => npar_attrib['name'],
           :nic             => npar_attrib['nic'], 
           :status          => npar_attrib['status'],
           :dracipaddress   => npar_attrib['dracipaddress'],
           :dracusername    => npar_attrib['dracusername'],
           :dracpassword    => npar_attrib['dracpassword'],
           :nfsipaddress    => npar_attrib['nfsipaddress'],
           :nfssharepath    => npar_attrib['nfssharepath']
        )
    end

    describe "when asking exists?" do
        it "should retun true if resource is present" do
             importnparsetting.provider.set(:ensure => :present)
             #importnparsetting.provider.should_not be_exists
        end
        it "Create npar setting" do
            #importnparsetting.provider.create
           
        end
    end
    

end
