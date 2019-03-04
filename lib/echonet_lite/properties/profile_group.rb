module EchonetLite
  module Profiles
    class ProfileGroup
      class NodeProfile
        register_property(0xD6, :self_node_instance_list_s, {
          access: %i[get],
          type: :eoj_list
        })
      end
    end
  end
end
