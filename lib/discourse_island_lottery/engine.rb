# frozen_string_literal: true

module ::DiscourseIslandLottery
  class Engine < ::Rails::Engine
    engine_name PLUGIN_NAME
    isolate_namespace DiscourseIslandLottery
  end
end
