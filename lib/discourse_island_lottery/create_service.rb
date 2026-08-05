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
      attributes = Params.call(params: @params, now: @now)

      seed = SecureRandom.hex(32)
      lottery =
        Lottery.create!(
          topic: @topic,
          creator: @creator,
          **attributes,
          seed:,
          seed_digest: Digest::SHA256.hexdigest(seed),
        )

      sync_marker!(lottery)
      Jobs.enqueue_at(lottery.closes_at, :island_lottery_draw, lottery_id: lottery.id)
      lottery
    end

    private

    def sync_marker!(lottery)
      post = lottery.topic&.first_post
      return if post.nil? || post.trashed? || Marker.extract(post.raw).present?

      marker_params = {
        prize: lottery.prize,
        closes_at: lottery.closes_at,
        winners_count: lottery.winners_count,
        min_trust_level: lottery.min_trust_level,
        max_trust_level: lottery.max_trust_level,
      }

      PostRevisor.new(post, lottery.topic).revise!(
        @creator,
        {
          raw: Marker.append(post.raw, marker_params),
          edit_reason: I18n.t("island_lottery.edit_reason"),
        },
        silent: true,
      )
    end

  end
end
