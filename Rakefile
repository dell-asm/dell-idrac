require "rake"
require "puppetlabs_spec_helper/rake_tasks"
require "rspec/core/rake_task"

# Customize lint option
task :lint do
  PuppetLint.configuration.send("disable_80chars")
  PuppetLint.configuration.send("disable_class_parameter_defaults")
  PuppetLint.configuration.ignore_paths = ["spec/**/*.pp", "pkg/**/*.pp"]
end

def spec_opts
  begin
    File.read("spec/spec.opts").chomp || ""
  rescue
    ""
  end
end

desc "Run all RSpec code examples"
RSpec::Core::RakeTask.new(:rspec) do |t|
  t.rspec_opts = spec_opts
end

SPEC_SUITES = (Dir.entries('spec') - ['.', '..','fixtures']).select {|e| File.directory? "spec/#{e}" }
namespace :rspec do
  SPEC_SUITES.each do |suite|
    desc "Run #{suite} RSpec code examples"
    RSpec::Core::RakeTask.new(suite) do |t|
      t.pattern = "spec/#{suite}/**/*_spec.rb"
      t.rspec_opts = spec_opts
    end
  end
end
task :default => :spec

begin
  if Gem::Specification::find_by_name('puppet-lint')
    require 'puppet-lint/tasks/puppet-lint'
    PuppetLint.configuration.ignore_paths = ["spec/**/*.pp", "vendor/**/*.pp"]
    task :default => [:rspec, :lint]
  end
rescue Gem::LoadError
end
