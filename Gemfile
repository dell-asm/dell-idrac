source 'https://rubygems.org'

gem 'activesupport'
gem 'nokogiri', '1.5.10'
gem 'dell-asm-util', :git => 'https://github.com/dell-asm/dell-asm-util.git', :branch => 'master'

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
  gem 'rake'
  gem 'rspec'
  gem 'json_pure', '2.0.1' # pin this puppet dependency to 1.9-compat version
  gem 'puppetlabs_spec_helper'
  if puppetversion = ENV['PUPPET_GEM_VERSION']
    gem 'puppet', puppetversion
  else
    gem 'puppet', '3.4.2'
  end
  gem 'puppet-lint'
end
