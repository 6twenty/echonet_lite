module EchonetLite
  module Profiles
    LOOKUP = {}

    def self.build(eoj)
      LOOKUP[eoj[0]][eoj[1]].new(eoj[2])
    end

    class Base
      def self.register(code)
        self.const_set(:CODE, code)

        return if self.superclass == Base

        group_code = self.superclass.const_get(:CODE)

        LOOKUP[group_code] ||= {}

        LOOKUP[group_code][code] = self
      end

      attr_reader :id

      def initialize(id = 0x01)
        @id = id
      end

      def eoj
        [class_group_code, class_code, id]
      end

      def class_group_code
        self.class.superclass.const_get(:CODE)
      end

      def class_code
        self.class.const_get(:CODE)
      end

      def parse_edt(property_name, edt)
        send("parse_#{property_name}", edt.dup)
      end
    end

    class AirConditionerRelatedDeviceGroup < Base
      register(0x01)

      class HomeAirConditioner < AirConditionerRelatedDeviceGroup
        register(0x30)
      end
    end

    class ManagementControlRelatedDeviceGroup < Base
      register(0x05)

      class Controller < ManagementControlRelatedDeviceGroup
        register(0xFF)
      end
    end

    class ProfileGroup < Base
      register(0x0E)

      class NodeProfile < ProfileGroup
        register(0xF0)

        EPC = {
          operating_status: 0x80,
          self_node_instance_list_s: 0xD6
        }

        def parse_operating_status(edt)
          values = {
            0x30 => :booting,
            0x31 => :not_booting
          }

          { operating_status: values.fetch(edt, :unknown) }
        end

        def parse_self_node_instance_list_s(edt)
          instances_count = edt.shift

          profiles = instances_count.times.map do
            instance_eoj = edt.shift(3)
            Profiles.build(instance_eoj)
          end

          { self_node_instance_list_s: profiles }
        end
      end
    end
  end
end
