# frozen_string_literal: true

module ::DiscourseIslandLottery
  class Engine < ::Rails::Engine
    engine_name PLUGIN_NAME
    isolate_namespace DiscourseIslandLottery
  end
end

DiscourseIslandLottery::Engine.routes.draw do
  get "/topic/:topic_id" => "lotteries#show"
  post "/" => "lotteries#create"
  post "/:id/draw" => "lotteries#draw"
  post "/:id/cancel" => "lotteries#cancel"
end

Discourse::Application.routes.append do
  mount ::DiscourseIslandLottery::Engine, at: "/island-lottery"
end
