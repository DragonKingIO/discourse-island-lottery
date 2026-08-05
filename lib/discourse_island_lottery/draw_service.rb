# frozen_string_literal: true

require "digest"

module DiscourseIslandLottery
  class DrawService
    class TooEarly < StandardError; end

    def self.call(lottery, now: Time.zone.now)
      new(lottery, now: now).call
    end

    def initialize(lottery, now:)
      @lottery = lottery
      @now = now
    end

    def call
      @lottery.with_lock do
        return @lottery if @lottery.drawn? || @lottery.cancelled?
        raise TooEarly, "lottery has not closed" if @now < @lottery.closes_at

        raise "seed commitment mismatch" unless valid_seed_commitment?

        participant_ids = eligible_participant_ids
        winner_ids = ranked_winner_ids(participant_ids)
        result_post = create_result_post(participant_ids, winner_ids)

        @lottery.update!(
          status: :drawn,
          participant_user_ids: participant_ids,
          winner_user_ids: winner_ids,
          drawn_at: @now,
          result_post_id: result_post.id,
        )
      end

      @lottery
    end

    private

    def valid_seed_commitment?
      Digest::SHA256.hexdigest(@lottery.seed) == @lottery.seed_digest
    end

    def eligible_participant_ids
      reply_user_ids =
        Post
          .where(topic_id: @lottery.topic_id, post_type: Post.types[:regular])
          .where("post_number > 1 AND created_at <= ?", @lottery.closes_at)
          .where(deleted_at: nil, hidden: false)
          .where.not(user_id: nil)
          .distinct
          .pluck(:user_id)

      User
        .where(id: reply_user_ids, active: true, staged: false)
        .where(trust_level: @lottery.min_trust_level..@lottery.max_trust_level)
        .where("suspended_till IS NULL OR suspended_till < ?", @now)
        .where.not(id: excluded_user_ids)
        .order(:id)
        .pluck(:id)
    end

    def excluded_user_ids
      [@lottery.topic.user_id, Discourse::SYSTEM_USER_ID].compact.uniq
    end

    def ranked_winner_ids(participant_ids)
      participant_ids
        .sort_by do |user_id|
          Digest::SHA256.hexdigest(
            [@lottery.seed, @lottery.id, @lottery.topic_id, user_id].join(":"),
          )
        end
        .first(@lottery.winners_count)
    end

    def create_result_post(participant_ids, winner_ids)
      users = User.where(id: winner_ids).index_by(&:id)
      winner_lines =
        if winner_ids.empty?
          "本期没有符合条件的参与者。"
        else
          winner_ids.each_with_index.map { |id, index| "#{index + 1}. @#{users.fetch(id).username}" }.join("\n")
        end

      raw = <<~MD
        ## 🎉 抽奖结果

        符合条件的参与者：**#{participant_ids.length}** 人  
        计划抽取：**#{@lottery.winners_count}** 人  
        实际中奖：**#{winner_ids.length}** 人

        #{winner_lines}

        ---
        信任等级范围：TL#{@lottery.min_trust_level}～TL#{@lottery.max_trust_level}  
        种子承诺：`#{@lottery.seed_digest}`  
        公开种子：`#{@lottery.seed}`  
        开奖时间：#{@now.utc.iso8601}

        同一用户的多次回复只计算一次。结果由固定种子和参与者快照确定，可重复验证。
      MD

      PostCreator.create!(
        Discourse.system_user,
        topic_id: @lottery.topic_id,
        raw: raw,
        skip_validations: true,
      )
    end
  end
end
