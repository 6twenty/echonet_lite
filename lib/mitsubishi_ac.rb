require "mitsubishi_ac/version"
require "echonet_lite"

module MitsubishiAc
  def self.start
    devices = EchonetLite.discover

    # Only air conditioners
    devices.select! do |device|
      device.profile.class.to_s.rpartition("::").last == "HomeAirConditioner"
    end

    devices.each(&:update)
  end
end
