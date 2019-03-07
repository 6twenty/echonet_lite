module EchonetLite
  module Profiles
    LOOKUP = Hash.new { |hash, key| hash[key] = {} }
    PROPERTIES = {}

    class Base
      def self.properties
        PROPERTIES[self].all
      end

      def self.register_class_group(code)
        self.const_set(:CODE, code)
      end

      def self.register_class(code)
        self.const_set(:CODE, code)

        group_code = self.superclass.const_get(:CODE)

        LOOKUP[group_code][code] = self
      end

      def self.register_property(code, name, detail)
        detail[:epc] = code
        detail[:name] = name

        PROPERTIES[self] ||= Properties.new(self)

        PROPERTIES[self].add(code, name, detail)
      end

      def self.class_group_code
        self.superclass.const_get(:CODE)
      end

      def self.class_code
        self.const_get(:CODE)
      end
    end

    class AirConditionerRelatedDeviceGroup < Base
      register_class_group 0x01

      class HomeAirConditioner < AirConditionerRelatedDeviceGroup
        register_class 0x30
      end
    end

    class ManagementControlRelatedDeviceGroup < Base
      register_class_group 0x05

      class Controller < ManagementControlRelatedDeviceGroup
        register_class 0xFF
      end
    end

    class ProfileGroup < Base
      register_class_group 0x0E

      class NodeProfile < ProfileGroup
        register_class 0xF0
      end
    end
  end
end
