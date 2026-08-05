# frozen_string_literal: true

# name: discourse-island-lottery
# about: Auditable reply-based lotteries for IsleBBS
# meta_topic_id: 0
# version: 0.3.0
# authors: IsleBBS
# url: https://islabbs.com
# required_version: 3.4.0

enabled_site_setting :island_lottery_enabled

register_asset "stylesheets/island-lottery.scss"

module ::DiscourseIslandLottery
  PLUGIN_NAME = "discourse-island-lottery"
end

after_initialize do
  require_relative "app/controllers/discourse_island_lottery/lotteries_controller"
  require_relative "app/models/discourse_island_lottery/lottery"
  require_relative "lib/discourse_island_lottery/create_service"
  require_relative "lib/discourse_island_lottery/draw_service"
  require_relative "jobs/regular/island_lottery_draw"

  Discourse::Application.routes.append do
    get "/island-lottery/topic/:topic_id" => "discourse_island_lottery/lotteries#show"
    post "/island-lottery" => "discourse_island_lottery/lotteries#create"
    post "/island-lottery/:id/draw" => "discourse_island_lottery/lotteries#draw"
    post "/island-lottery/:id/cancel" => "discourse_island_lottery/lotteries#cancel"
  end

  %i[
    island_lottery_create
    island_lottery_prize
    island_lottery_closes_at
    island_lottery_winners_count
    island_lottery_min_trust_level
    island_lottery_max_trust_level
  ].each { |param| add_permitted_post_create_param(param) }

  on(:post_created) do |post, options, user|
    next unless SiteSetting.island_lottery_enabled
    next unless post.post_number == 1 && post.topic&.archetype == Archetype.default
    next unless options[:island_lottery_create].to_s == "true"

    ::DiscourseIslandLottery::CreateService.call(
      topic: post.topic,
      creator: user,
      params: {
        prize: options[:island_lottery_prize],
        closes_at: options[:island_lottery_closes_at],
        winners_count: options[:island_lottery_winners_count],
        min_trust_level: options[:island_lottery_min_trust_level],
        max_trust_level: options[:island_lottery_max_trust_level],
      },
    )
  end

  add_to_serializer(:topic_view, :island_lottery) do
    lottery = ::DiscourseIslandLottery::Lottery.find_by(topic_id: object.topic.id)
    next nil if lottery.nil?

    lottery.public_payload(scope)
  end

  add_to_serializer(:topic_view, :can_create_island_lottery) do
    next false if ::DiscourseIslandLottery::Lottery.exists?(topic_id: object.topic.id)
    next false if scope.user.nil?

    scope.user.staff? || object.topic.user_id == scope.user.id
  end
end
