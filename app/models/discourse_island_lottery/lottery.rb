# frozen_string_literal: true

module DiscourseIslandLottery
  class Lottery < ActiveRecord::Base
    self.table_name = "island_lotteries"

    EDITABLE_FIELDS = %i[prize closes_at winners_count min_trust_level max_trust_level].freeze

    belongs_to :topic
    belongs_to :creator, class_name: "User"
    belongs_to :result_post, class_name: "Post", optional: true

    enum :status, { open: 0, drawing: 1, drawn: 2, cancelled: 3 }, scopes: true

    validates :topic_id, uniqueness: true
    validates :winners_count, numericality: { only_integer: true, greater_than: 0 }
    validates :min_trust_level, :max_trust_level,
              inclusion: { in: TrustLevel.levels.values }
    validate :valid_trust_level_range

    def public_payload(guardian)
      winner_users =
        if drawn?
          users = User.where(id: winner_user_ids).index_by(&:id)
          winner_user_ids.filter_map do |user_id|
            user = users[user_id]
            user && { id: user.id, username: user.username, name: user.name }
          end
        else
          []
        end

      payload = {
        id: id,
        topic_id: topic_id,
        creator_id: creator_id,
        closes_at: closes_at,
        winners_count: winners_count,
        min_trust_level: min_trust_level,
        max_trust_level: max_trust_level,
        status: status,
        prize: prize,
        seed_digest: seed_digest,
        participant_count: participant_user_ids.length,
        winner_user_ids: drawn? ? winner_user_ids : [],
        winner_users: winner_users,
        drawn_at: drawn_at,
        result_post_id: result_post_id,
      }

      payload[:revealed_seed] = seed if drawn?
      payload[:can_manage] = can_manage?(guardian.user)
      payload
    end

    def can_manage?(user, now: Time.zone.now)
      return false unless user.present? && open?
      return true if user.staff?

      user.id == creator_id && created_at.present? && created_at > 1.hour.ago(now)
    end

    private

    def valid_trust_level_range
      return if min_trust_level.nil? || max_trust_level.nil?
      errors.add(:min_trust_level, :invalid) if min_trust_level > max_trust_level
    end
  end
end

# == Schema Information
#
# Table name: island_lotteries
#
#  id                   :bigint           not null, primary key
#  closes_at            :datetime         not null
#  drawn_at             :datetime
#  max_trust_level      :integer          default(4), not null
#  min_trust_level      :integer          default(0), not null
#  participant_user_ids :jsonb            not null
#  prize                :text
#  seed                 :string           not null
#  seed_digest          :string           not null
#  status               :integer          default("open"), not null
#  winner_user_ids      :jsonb            not null
#  winners_count        :integer          not null
#  created_at           :datetime         not null
#  updated_at           :datetime         not null
#  creator_id           :bigint           not null
#  result_post_id       :bigint
#  topic_id             :bigint           not null
#
# Indexes
#
#  index_island_lotteries_on_creator_id            (creator_id)
#  index_island_lotteries_on_status_and_closes_at  (status,closes_at)
#  index_island_lotteries_on_topic_id              (topic_id) UNIQUE
#
