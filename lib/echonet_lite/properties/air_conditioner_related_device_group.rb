module EchonetLite
  module Profiles
    class AirConditionerRelatedDeviceGroup
      class HomeAirConditioner
        register_property(0x80, :operation_status, {
          access: %i[get set],
          type: :hash,
          values: {
            0x30 => :on,
            0x31 => :off
          }
        })

        register_property(0xB0, :operation_mode_setting, {
          access: %i[get set],
          type: :hash,
          values: {
            0x41 => :automatic,
            0x42 => :cooling,
            0x43 => :heating,
            0x44 => :dehumidification,
            0x45 => :air_circulator,
            0x40 => :other
          }
        })

        register_property(0xB3, :set_temperature_value, {
          access: %i[get set],
          type: :temp,
          min: 0,
          max: 50
        })

        register_property(0xBB, :measured_value_of_room_temperature, {
          access: %i[get],
          type: :temp
        })

        register_property(0xBE, :measured_outdoor_air_temperature, {
          access: %i[get],
          type: :temp
        })

        register_property(0xA0, :air_flow_rate_setting, {
          access: %i[get set],
          type: :hash,
          values: {
            0x41 => :auto,
            0x31 => :minimum,
            0x32 => :low,
            0x33 => :medium_low,
            0x34 => :medium,
            0x35 => :medium_high,
            0x36 => :high,
            0x37 => :higher,
            0x38 => :maximum
          }
        })

        register_property(0xAA, :special_state, {
          access: %i[get],
          type: :hash,
          values: {
            0x40 => :normal,
            0x41 => :defrosting,
            0x42 => :preheating,
            0x43 => :heat_removal
          }
        })
      end
    end
  end
end
