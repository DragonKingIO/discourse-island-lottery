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
      lottery = CreateService.call(topic:, creator: current_user, params:)
      render json: { lottery: lottery.public_payload(guardian) }
    rescue ActiveRecord::RecordInvalid => e
      render_json_error(e.record.errors.full_messages, status: 422)
    end

    def update
      lottery = Lottery.find(params[:id])
      raise Discourse::InvalidAccess unless lottery.can_manage?(current_user)

      lottery = UpdateService.call(lottery:, actor: current_user, params:)
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

  end
end
