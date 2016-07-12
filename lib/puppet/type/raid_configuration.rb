Puppet::Type.newtype(:raid_configuration) do
  @doc = "RAID controller management for idracs."

  newparam(:name) do
    desc "The controller name to configure"

    validate do |value|
      if value.strip.length == 0
        raise ArgumentError, "The name must contain a value. It cannot be null."
      end
    end
  end

  def self.disk_property(name)
    newproperty(name) do
      # override insync? to check if the list of disks already in mode
      # contains all the disks trying to set, as opposed to checking
      # that the 2 lists are exactly equal
      def insync?(is)
        (should - is).empty?
      end
      munge do |value|
        return [value] if value && !value.is_a?(Array)
        value.sort
      end
    end
  end

  disk_property(:raid_disks)
  disk_property(:nonraid_disks)

end
