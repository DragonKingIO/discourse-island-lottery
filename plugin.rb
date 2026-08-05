# frozen_string_literal: true

# name: discourse-island-lottery
# about: Auditable reply-based lotteries for IsleBBS
# meta_topic_id: 0
# version: 0.4.0
# authors: IsleBBS
# url: https://islabbs.com
# required_version: 3.4.0

enabled_site_setting :island_lottery_enabled

register_asset "stylesheets/island-lottery.scss"
register_svg_icon "ticket-simple"

module ::DiscourseIslandLottery
  PLUGIN_NAME = "discourse-island-lottery"
end

after_initialize do
  require_relative "app/controllers/discourse_island_lottery/lotteries_controller"
  require_relative "app/models/discourse_island_lottery/lottery"
  require_relative "lib/discourse_island_lottery/marker"
  require_relative "lib/discourse_island_lottery/params"
  require_relative "lib/discourse_island_lottery/create_service"
  require_relative "lib/discourse_island_lottery/update_service"
  require_relative "lib/discourse_island_lottery/draw_service"
  require_relative "jobs/regular/island_lottery_draw"

  Discourse::Application.routes.append do
    get "/island-lottery/topic/:topic_id" => "discourse_island_lottery/lotteries#show"
    post "/island-lottery" => "discourse_island_lottery/lotteries#create"
    patch "/island-lottery/:id" => "discourse_island_lottery/lotteries#update"
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

  validate(:post, :validate_island_lottery_marker) do
    next true unless raw_changed?

    marker = ::DiscourseIslandLottery::Marker.extract(raw)
    lottery =
      if persisted? && topic_id.present?
        ::DiscourseIslandLottery::Lottery.find_by(topic_id: topic_id)
      end
    editor = acting_user || last_editor || user

    if lottery
      # Older lotteries may predate the marker. They continue to render through
      # the topic payload; once a marker exists, its edits are protected here.
      old_marker = ::DiscourseIslandLottery::Marker.extract(raw_was)
      next true if marker.nil? && old_marker.nil?

      unless marker && lottery.can_manage?(editor)
        errors.add(:raw, I18n.t("island_lottery.errors.edit_forbidden"))
        next false
      end

      begin
        ::DiscourseIslandLottery::Params.call(
          params: marker,
          existing: lottery,
          now: Time.zone.now,
        )
      rescue Discourse::InvalidParameters
        errors.add(:raw, I18n.t("island_lottery.errors.invalid_marker"))
        next false
      end
    elsif marker
      begin
        ::DiscourseIslandLottery::Params.call(params: marker, now: Time.zone.now)
      rescue Discourse::InvalidParameters
        errors.add(:raw, I18n.t("island_lottery.errors.invalid_marker"))
        next false
      end
    end

    true
  end

  on(:post_created) do |post, options, user|
    next unless SiteSetting.island_lottery_enabled
    next unless post.post_number == 1 && post.topic&.archetype == Archetype.default
    marker = ::DiscourseIslandLottery::Marker.extract(post.raw)
    next if marker.nil? && options[:island_lottery_create].to_s != "true"

    ::DiscourseIslandLottery::CreateService.call(
      topic: post.topic,
      creator: user,
      params: {
        prize: marker&.fetch(:prize, nil) || options[:island_lottery_prize],
        closes_at: marker&.fetch(:closes_at, nil) || options[:island_lottery_closes_at],
        winners_count: marker&.fetch(:winners_count, nil) || options[:island_lottery_winners_count],
        min_trust_level: marker&.fetch(:min_trust_level, nil) || options[:island_lottery_min_trust_level],
        max_trust_level: marker&.fetch(:max_trust_level, nil) || options[:island_lottery_max_trust_level],
      },
    )
  end

  on(:post_edited) do |post|
    next unless SiteSetting.island_lottery_enabled
    next unless post.post_number == 1 && post.topic&.archetype == Archetype.default

    lottery = ::DiscourseIslandLottery::Lottery.find_by(topic_id: post.topic_id)
    marker = ::DiscourseIslandLottery::Marker.extract(post.raw)
    next if lottery.nil? || marker.nil?

    actor = post.acting_user || post.last_editor || post.user
    begin
      ::DiscourseIslandLottery::UpdateService.call(
        lottery:,
        actor:,
        params: marker,
        sync_post: false,
      )
    rescue Discourse::InvalidAccess, Discourse::InvalidParameters => e
      Rails.logger.warn("Island lottery marker sync skipped: #{e.message}")
    end
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
