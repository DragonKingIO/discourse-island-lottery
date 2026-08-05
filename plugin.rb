# frozen_string_literal: true

# name: discourse-island-lottery
# about: Auditable reply-based lotteries for IsleBBS
# meta_topic_id: 0
# version: 0.1.0
# authors: IsleBBS
# url: https://islabbs.com
# required_version: 3.4.0

enabled_site_setting :island_lottery_enabled

register_asset "stylesheets/island-lottery.scss"

module ::DiscourseIslandLottery
  PLUGIN_NAME = "discourse-island-lottery"
end

require_relative "lib/discourse_island_lottery/engine"

after_initialize do
  Discourse::Application.routes.append do
    mount ::DiscourseIslandLottery::Engine, at: "/island-lottery"
  end

  require_relative "app/models/discourse_island_lottery/lottery"
  require_relative "lib/discourse_island_lottery/draw_service"
  require_relative "jobs/regular/island_lottery_draw"

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
