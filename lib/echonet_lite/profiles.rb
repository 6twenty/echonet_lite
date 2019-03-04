module EchonetLite
  module Profiles
    LOOKUP = Hash.new { |hash, key| hash[key] = {} }

    def self.from_eoj(eoj, device)
      LOOKUP[eoj[0]][eoj[1]].new(device)
    end

    class Base
      def self.register(code)
        self.const_set(:CODE, code)

        return if self.superclass == Base

        group_code = self.superclass.const_get(:CODE)

        LOOKUP[group_code][code] = self
      end

      attr_reader :device

      def initialize(device = nil)
        @device = device
      end

      def type
        "#{self.class.superclass}::#{self.class}"
      end

      def class_group_code
        self.class.superclass.const_get(:CODE)
      end

      def class_code
        self.class.const_get(:CODE)
      end

      def can_process_epc?(epc)
        return false unless self.class.const_defined?(:EPC)
        return false unless self.class::EPC.invert.key?(epc)

        true
      end

      def process_epc(epc, edt)
        return unless can_process_epc?(epc)

        epc_name = self.class::EPC.invert[epc]
        send("receive_#{epc_name}", edt.dup)
      end
    end

    class AirConditionerRelatedDeviceGroup < Base
      register(0x01)

      class HomeAirConditioner < AirConditionerRelatedDeviceGroup
        register(0x30)

        EPC = {
          operation_status: 0x80,
          operation_mode_setting: 0xB0
        }

        def receive_operation_status(edt)
          values = {
            0x30 => :on,
            0x31 => :off
          }

          values.fetch(edt[0], :unknown)
        end

        def receive_operation_mode_setting(edt)

        end
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
          self_node_instance_list_s: 0xD6
        }

        def receive_self_node_instance_list_s(edt)
          instances_count = edt.shift

          instances_count.times.map do
            instance_eoj = edt.shift(3)
            Device.from_eoj(instance_eoj, device.ip)
          end
        end
      end
    end
  end
end
