# frozen_string_literal: true

module DiscourseIslandLottery
  module Marker
    TAG_PATTERN = /\[island-lottery\](?<body>.*?)\[\/island-lottery\]/im
    FIELDS = %i[prize closes_at winners_count min_trust_level max_trust_level].freeze

    module_function

    def extract(raw)
      match = raw.to_s.match(TAG_PATTERN)
      return if match.nil?

      values = {}
      current_field = nil

      match[:body].to_s.each_line do |line|
        line = line.chomp
        field_match = line.match(
          /\A\s*(prize|closes_at|winners_count|min_trust_level|max_trust_level)\s*:\s?(.*)\z/i,
        )

        if field_match
          current_field = field_match[1].downcase.to_sym
          values[current_field] = field_match[2].to_s.strip
        elsif current_field == :prize && line.strip.present?
          values[:prize] = [values[:prize], line.strip].reject(&:blank?).join("\n")
        end
      end

      values.merge(marker: match[0])
    end

    def render(params)
      prize = value(params, :prize).to_s.strip
      prize = prize.gsub(/\[\/island-lottery\]/i, "")

      [
        "[island-lottery]",
        "prize: #{prize}",
        "closes_at: #{timestamp(value(params, :closes_at))}",
        "winners_count: #{value(params, :winners_count)}",
        "min_trust_level: #{value(params, :min_trust_level)}",
        "max_trust_level: #{value(params, :max_trust_level)}",
        "[/island-lottery]",
      ].join("\n")
    end

    def replace(raw, params)
      raw.to_s.sub(TAG_PATTERN) { render(params) }
    end

    def append(raw, params)
      current = raw.to_s.rstrip
      marker = render(params)
      current.present? ? "#{current}\n\n#{marker}\n" : "#{marker}\n"
    end

    def value(params, name)
      if params.respond_to?(:key?) && (params.key?(name) || params.key?(name.to_s))
        params[name] || params[name.to_s]
      else
        params.public_send(name)
      end
    end

    def timestamp(value)
      return value.iso8601 if value.respond_to?(:iso8601)

      value.to_s
    end
  end
end
