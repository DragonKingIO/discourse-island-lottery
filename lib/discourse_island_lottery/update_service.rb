# frozen_string_literal: true

module DiscourseIslandLottery
  class UpdateService
    def self.call(lottery:, actor:, params:, now: Time.zone.now, sync_post: true)
      new(lottery:, actor:, params:, now:, sync_post:).call
    end

    def initialize(lottery:, actor:, params:, now:, sync_post:)
      @lottery = lottery
      @actor = actor
      @params = params
      @now = now
      @sync_post = sync_post
    end

    def call
      raise Discourse::InvalidAccess unless @lottery.can_manage?(@actor, now: @now)
      raise Discourse::InvalidParameters.new(:status) unless @lottery.open?

      attributes = Params.call(params: @params, now: @now, existing: @lottery)
      changed = false
      deadline_changed = false

      @lottery.with_lock do
        raise Discourse::InvalidAccess unless @lottery.can_manage?(@actor, now: @now)
        raise Discourse::InvalidParameters.new(:status) unless @lottery.open?

        changed = Lottery::EDITABLE_FIELDS.any? do |field|
          @lottery.public_send(field) != attributes[field]
        end
        deadline_changed = @lottery.closes_at != attributes[:closes_at]

        if changed
          seed = SecureRandom.hex(32)
          @lottery.update!(
            attributes.merge(seed:, seed_digest: Digest::SHA256.hexdigest(seed)),
          )
        end
      end

      if changed && deadline_changed
        Jobs.cancel_scheduled_job(:island_lottery_draw, lottery_id: @lottery.id)
        Jobs.enqueue_at(@lottery.closes_at, :island_lottery_draw, lottery_id: @lottery.id)
      end

      sync_post! if @sync_post
      @lottery
    end

    private

    def sync_post!
      post = @lottery.topic&.first_post
      return if post.nil? || post.trashed?

      marker_params = {
        prize: @lottery.prize,
        closes_at: @lottery.closes_at,
        winners_count: @lottery.winners_count,
        min_trust_level: @lottery.min_trust_level,
        max_trust_level: @lottery.max_trust_level,
      }
      desired_marker = Marker.render(marker_params)
      current_marker = Marker.extract(post.raw)&.fetch(:marker, nil)
      return if current_marker == desired_marker

      raw =
        if current_marker
          Marker.replace(post.raw, marker_params)
        else
          Marker.append(post.raw, marker_params)
        end

      PostRevisor.new(post, @lottery.topic).revise!(
        @actor,
        { raw:, edit_reason: I18n.t("island_lottery.edit_reason") },
        silent: true,
      )
    end
  end
end
