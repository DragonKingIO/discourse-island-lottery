# frozen_string_literal: true

module DiscourseIslandLottery
  class Params
    def self.call(params:, now: Time.zone.now, existing: nil)
      new(params:, now:, existing:).call
    end

    def initialize(params:, now:, existing:)
      @params = params
      @now = now
      @existing = existing
    end

    def call
      closes_at = parse_time(value(:closes_at))
      winners_count = integer_param(:winners_count)
      min_trust_level = integer_param(:min_trust_level, default: TrustLevel[0])
      max_trust_level = integer_param(:max_trust_level, default: TrustLevel[4])

      validate_closes_at!(closes_at)
      validate_counts!(winners_count, min_trust_level, max_trust_level)

      {
        prize: value(:prize, default: "").to_s.strip.first(1000),
        closes_at:,
        winners_count:,
        min_trust_level:,
        max_trust_level:,
      }
    end

    private

    def value(name, default: nil)
      if @params.respond_to?(:key?) && (@params.key?(name) || @params.key?(name.to_s))
        @params[name] || @params[name.to_s]
      elsif @existing
        @existing.public_send(name)
      else
        default
      end
    end

    def parse_time(value)
      return value.in_time_zone if value.respond_to?(:in_time_zone)

      Time.zone.parse(value.to_s)
    rescue ArgumentError, TypeError
      raise Discourse::InvalidParameters.new(:closes_at)
    end

    def integer_param(name, default: nil)
      Integer(value(name, default:).presence || default)
    rescue ArgumentError, TypeError
      raise Discourse::InvalidParameters.new(name)
    end

    def validate_closes_at!(closes_at)
      # Keeping the existing deadline while editing the prize or eligibility
      # should remain valid even when the minimum waiting window has passed.
      return if @existing && closes_at == @existing.closes_at

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
