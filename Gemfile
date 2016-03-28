source 'https://rubygems.org'
ruby "1.9.3"

gem 'activesupport'
gem 'nokogiri', '1.5.10'
gem 'dell-asm-util', :git => 'https://github.com/dell-asm/dell-asm-util.git', :branch => 'master'

platforms :ruby, :mswin, :mingw do
  gem 'pg', '0.17.1'
end

# Add gems necessary to run facter on Windows
platforms :mswin, :mingw do
  gem 'sys-admin'
  gem 'win32-process'
  gem 'win32-dir'
  gem 'win32-security'
  gem 'win32-service'
  gem 'win32-taskscheduler'
  gem 'windows-pr'
end

group :development, :test do
  #private github gems need ssh from travis ci and https from the dev environment
  gem 'asm-deployer', :git => 'https://github.com/dell-asm/asm-deployer.git', :branch => 'master'
  gem 'rake',"~> 10.0"
  gem 'rspec', '~> 2.14'
  gem 'puppetlabs_spec_helper'
  if puppetversion = ENV['PUPPET_GEM_VERSION']
    gem 'puppet', puppetversion
  else
    gem 'puppet', '3.4.2'
  end
  gem 'puppet-lint'
  # gem 'ruby-debug-ide', '0.6.1.beta2'
end
