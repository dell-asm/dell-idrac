source 'https://rubygems.org'

gem 'activesupport'
gem 'nokogiri', '1.5.10'
gem 'dell-asm-util', :git => 'https://github.com/dell-asm/dell-asm-util.git'

group :development, :test do
  gem 'asm-deployer', :git => 'git@github.com:dell-asm/asm-deployer.git'
  gem 'rake'
  gem 'rspec'
  gem 'puppetlabs_spec_helper'
  if puppetversion = ENV['PUPPET_GEM_VERSION']
    gem 'puppet', puppetversion
  else
    gem 'puppet', '3.4.2'
  end
  gem 'puppet-lint'
end
