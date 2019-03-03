module EchonetLite
  module Profiles
    LOOKUP = Hash.new({})

    def self.build(eoj)
      LOOKUP[eoj[0]][eoj[1]].new(eoj[2])
    end

    class Base
      def self.inherited(subclass)
        subclass.class_eval do
          def self.inherited(subclass)
            register(subclass)
          end
        end
      end

      def self.register(subclass)
        return unless subclass.const_defined?(:CODE)

        class_group_code = subclass.superclass.const_get(:CODE)
        class_code = subclass.const_get(:CODE)

        LOOKUP[class_group_code][class_code] = subclass
      end

      attr_reader :id

      def initialize(id = 0x01)
        @id = id
      end

      def eoj
        [class_group_code, class_code, id]
      end

      def class_group_code
        self.class.superclass.class_variable_get(:CODE)
      end

      def class_code
        self.class.class_variable_get(:CODE)
      end

      def parse_edt(property_name, edt)
        send("parse_#{property_name}", edt.dup)
      end
    end

    class AirConditionerRelatedDeviceGroup < Base
      CODE = 0x01

      class HomeAirConditioner < AirConditionerRelatedDeviceGroup
        CODE = 0x30
      end
    end

    class ManagementControlRelatedDeviceGroup < Base
      CODE = 0x05

      class Controller < ManagementControlRelatedDeviceGroup
        CODE = 0xFF
      end
    end

    class ProfileGroup < Base
      CODE = 0x0E

      class NodeProfile < ProfileGroup
        CODE = 0xF0

        EPC = {
          operating_status: 0x80,
          self_node_instance_list_s: 0xD6
        }

        def parse_operating_status(edt)
          status = case edt
          when 0x30 then :booting
          when 0x31 then :not_booting
          else
            :unknown
          end

          { operating_status: status }
        end

        def parse_self_node_instance_list_s(edt)
          instances_count = edt.shift

          profiles = instances_count.times.map do
            instance_eoj = edt.shift(3)
            Profile.build(instance_eoj)
          end

          { self_node_instance_list_s: profiles }
        end
      end
    end
  end
end
