require "mitsubishi_ac/version"
require "echonet_lite"

module MitsubishiAc
  def self.start
    devices = EchonetLite.discover

    # Only air conditioners
    devices.select! do |device|
      device.profile.is_a?(EchonetLite::Profiles::AirConditionerRelatedDeviceGroup::HomeAirConditioner)
    end
  end
end
