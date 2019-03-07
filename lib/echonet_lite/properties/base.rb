module EchonetLite
  module Profiles
    class Base
      register_property(0x80, :operation_status, {
        access: %i[get set],
        type: :hash,
        values: {
          0x30 => :on,
          0x31 => :off
        }
      })
    end
  end
end
