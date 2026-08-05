# frozen_string_literal: true

module DiscourseIslandLottery
  class LotteriesController < ::ApplicationController
    requires_plugin PLUGIN_NAME

    before_action :ensure_enabled
    before_action :ensure_logged_in, except: [:show]

    def show
      topic = Topic.find(params[:topic_id])
      guardian.ensure_can_see!(topic)
      lottery = Lottery.find_by!(topic_id: topic.id)
      render json: { lottery: lottery.public_payload(guardian) }
    end

    def create
      topic = Topic.find(params.require(:topic_id))
      guardian.ensure_can_see!(topic)
      ensure_can_manage_topic!(topic)

      closes_at = parse_time(params.require(:closes_at))
      validate_closes_at!(closes_at)

      winners_count = integer_param(:winners_count)
      min_trust_level = integer_param(:min_trust_level, default: TrustLevel[0])
      max_trust_level = integer_param(:max_trust_level, default: TrustLevel[4])
      validate_counts!(winners_count, min_trust_level, max_trust_level)

      seed = SecureRandom.hex(32)
      lottery =
        Lottery.create!(
          topic: topic,
          creator: current_user,
          closes_at: closes_at,
          winners_count: winners_count,
          min_trust_level: min_trust_level,
          max_trust_level: max_trust_level,
          prize: params[:prize].to_s.strip.first(1000),
          seed: seed,
          seed_digest: Digest::SHA256.hexdigest(seed),
        )

      Jobs.enqueue_at(lottery.closes_at, :island_lottery_draw, lottery_id: lottery.id)
      render json: { lottery: lottery.public_payload(guardian) }
    rescue ActiveRecord::RecordInvalid => e
      render_json_error(e.record.errors.full_messages, status: 422)
    end

    def draw
      lottery = Lottery.find(params[:id])
      raise Discourse::InvalidAccess unless current_user.staff?

      DrawService.call(lottery)
      render json: { lottery: lottery.reload.public_payload(guardian) }
    rescue DrawService::TooEarly => e
      render_json_error(e.message, status: 422)
    end

    def cancel
      lottery = Lottery.find(params[:id])
      raise Discourse::InvalidAccess unless lottery.can_manage?(current_user)
      raise Discourse::InvalidParameters.new(:status) unless lottery.open?
      raise Discourse::InvalidParameters.new(:closes_at) if lottery.closes_at <= Time.zone.now

      lottery.update!(status: :cancelled)
      render json: { lottery: lottery.public_payload(guardian) }
    end

    private

    def ensure_enabled
      raise Discourse::NotFound unless SiteSetting.island_lottery_enabled
    end

    def ensure_logged_in
      raise Discourse::NotLoggedIn if current_user.nil?
    end

    def ensure_can_manage_topic!(topic)
      allowed = current_user.staff? || topic.user_id == current_user.id
      raise Discourse::InvalidAccess unless allowed && !topic.closed && !topic.archived
    end

    def parse_time(value)
      Time.zone.parse(value.to_s)
    rescue ArgumentError, TypeError
      raise Discourse::InvalidParameters.new(:closes_at)
    end

    def validate_closes_at!(closes_at)
      min_time = SiteSetting.island_lottery_min_close_minutes.minutes.from_now
      max_time = SiteSetting.island_lottery_max_duration_days.days.from_now
      raise Discourse::InvalidParameters.new(:closes_at) if closes_at.nil? || closes_at < min_time || closes_at > max_time
    end

    def integer_param(name, default: nil)
      value = params[name].presence || default
      Integer(value)
    rescue ArgumentError, TypeError
      raise Discourse::InvalidParameters.new(name)
    end

    def validate_counts!(winners_count, min_trust_level, max_trust_level)
      valid_levels = TrustLevel.levels.values
      valid =
        winners_count.between?(1, SiteSetting.island_lottery_max_winners) &&
          valid_levels.include?(min_trust_level) && valid_levels.include?(max_trust_level) &&
          min_trust_level <= max_trust_level
      raise Discourse::InvalidParameters.new(:eligibility) unless valid
    end
  end
end
