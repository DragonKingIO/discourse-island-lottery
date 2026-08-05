# frozen_string_literal: true

module DiscourseIslandLottery
  class CreateService
    def self.call(topic:, creator:, params:, now: Time.zone.now)
      new(topic:, creator:, params:, now:).call
    end

    def initialize(topic:, creator:, params:, now:)
      @topic = topic
      @creator = creator
      @params = params
      @now = now
    end

    def call
      closes_at = parse_time(fetch(:closes_at))
      winners_count = integer_param(:winners_count)
      min_trust_level = integer_param(:min_trust_level, default: TrustLevel[0])
      max_trust_level = integer_param(:max_trust_level, default: TrustLevel[4])

      validate_closes_at!(closes_at)
      validate_counts!(winners_count, min_trust_level, max_trust_level)

      seed = SecureRandom.hex(32)
      lottery =
        Lottery.create!(
          topic: @topic,
          creator: @creator,
          closes_at:,
          winners_count:,
          min_trust_level:,
          max_trust_level:,
          prize: fetch(:prize, required: false).to_s.strip.first(1000),
          seed:,
          seed_digest: Digest::SHA256.hexdigest(seed),
        )

      Jobs.enqueue_at(lottery.closes_at, :island_lottery_draw, lottery_id: lottery.id)
      lottery
    end

    private

    def fetch(name, required: true)
      value = @params[name] || @params[name.to_s]
      raise Discourse::InvalidParameters.new(name) if required && value.blank?

      value
    end

    def parse_time(value)
      Time.zone.parse(value.to_s)
    rescue ArgumentError, TypeError
      raise Discourse::InvalidParameters.new(:closes_at)
    end

    def integer_param(name, default: nil)
      Integer(fetch(name, required: false).presence || default)
    rescue ArgumentError, TypeError
      raise Discourse::InvalidParameters.new(name)
    end

    def validate_closes_at!(closes_at)
      min_time = @now + SiteSetting.island_lottery_min_close_minutes.minutes
      max_time = @now + SiteSetting.island_lottery_max_duration_days.days
      invalid = closes_at.nil? || closes_at < min_time || closes_at > max_time
      raise Discourse::InvalidParameters.new(:closes_at) if invalid
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
