# frozen_string_literal: true

class BackfillIslandLotteryMarkers < ActiveRecord::Migration[7.2]
  def up
    return unless table_exists?(:island_lotteries)
    return unless defined?(DiscourseIslandLottery::Lottery)

    say_with_time "Backfilling IsleBBS lottery markers" do
      DiscourseIslandLottery::Lottery.find_each do |lottery|
        topic = Topic.find_by(id: lottery.topic_id)
        post = topic && Post.find_by(topic_id: topic.id, post_number: 1)
        next if topic.nil? || post.nil? || post.trashed?
        next if DiscourseIslandLottery::Marker.extract(post.raw).present?

        marker_params = {
          prize: lottery.prize,
          closes_at: lottery.closes_at,
          winners_count: lottery.winners_count,
          min_trust_level: lottery.min_trust_level,
          max_trust_level: lottery.max_trust_level,
        }

        revised =
          PostRevisor.new(post, topic).revise!(
            Discourse.system_user,
            {
              raw: DiscourseIslandLottery::Marker.append(post.raw, marker_params),
              edit_reason: I18n.t(
                "island_lottery.edit_reason",
                default: "Update lottery information",
              ),
            },
            silent: true,
          )

        raise "Could not add lottery marker to post #{post.id}" unless revised
      end
    end
  end

  def down
    # Do not remove markers that may have been edited by the author.
  end
end
