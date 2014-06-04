#
# Manage idrac server power
#

Puppet::Type.newtype(:powerstate) do
  @doc = "Power state management for idracs."

  ensurable do
    newvalue(:present) do
      provider.ensure_on
    end
    aliasvalue(:on, :present)
  end

  newparam(:name) do
    desc "The test name."

    validate do |value|
      if value.strip.length == 0
        raise ArgumentError, "The name must contain a value. It cannot be null."
      end
    end
  end

end
