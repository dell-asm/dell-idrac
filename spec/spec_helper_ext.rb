require "spec_helper"
require "mocha/api"

fixture_path = File.expand_path(File.join(__FILE__, "..", "fixtures"))
# Set module path to locally downloaded modules to fixtures directory
Puppet[:modulepath] = File.join(fixture_path, "modules")
