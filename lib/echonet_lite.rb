require "socket"
require "ipaddr"

require "echonet_lite/device"
require "echonet_lite/property"
require "echonet_lite/profiles"
require "echonet_lite/frame"

require "echonet_lite/properties/air_conditioner_related_device_group"
require "echonet_lite/properties/management_control_related_device_group"
require "echonet_lite/properties/profile_group"

module EchonetLite
  EchonetLiteError = Class.new(StandardError)
end
