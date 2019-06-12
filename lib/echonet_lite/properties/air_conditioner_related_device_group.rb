module EchonetLite
  module Profiles
    class AirConditionerRelatedDeviceGroup
      class HomeAirConditioner
        register_property(0xB0, "operation_mode_setting", {
          access: %i[get set],
          type: :hash,
          values: {
            0x41 => "automatic",
            0x42 => "cooling",
            0x43 => "heating",
            0x44 => "dehumidification",
            0x45 => "air_circulator",
            0x40 => "other"
          }
        })

        register_property(0xB3, "set_temperature_value", {
          access: %i[get set],
          type: :temp,
          min: 0,
          max: 50
        })

        register_property(0xBB, "measured_value_of_room_temperature", {
          access: %i[get],
          type: :temp
        })
      end
    end
  end
end
