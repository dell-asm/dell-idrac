source 'https://rubygems.org'

gem 'activesupport'
gem 'nokogiri', '~> 1.8.2'
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
  gem 'rspec', '~> 3.7.0', :require => false
  gem 'mocha', '~> 1.4.0', :require => false
  gem 'puppetlabs_spec_helper', '~> 2.6.2', :require => false
  gem 'json_pure', '~> 2.1.0'
  if puppetversion = ENV['PUPPET_GEM_VERSION']
    gem 'puppet', puppetversion
  else
    gem 'puppet', '5.4.0'
  end
  gem 'puppet-lint'
end
