# frozen_string_literal: true

DiscourseIslandLottery::Engine.routes.draw do
  get "/topic/:topic_id" => "lotteries#show"
  post "/" => "lotteries#create"
  post "/:id/draw" => "lotteries#draw"
  post "/:id/cancel" => "lotteries#cancel"
end
