# frozen_string_literal: true

require "rails_helper"

RSpec.describe DiscourseIslandLottery::DrawService do
  fab!(:creator) { Fabricate(:user, trust_level: 2) }
  fab!(:topic) { Fabricate(:topic, user: creator) }
  fab!(:eligible_user) { Fabricate(:user, trust_level: 2) }
  fab!(:second_eligible_user) { Fabricate(:user, trust_level: 3) }
  fab!(:low_level_user) { Fabricate(:user, trust_level: 0) }

  let(:seed) { "fixed-test-seed" }
  let!(:lottery) do
    DiscourseIslandLottery::Lottery.create!(
      topic: topic,
      creator: creator,
      closes_at: 1.hour.ago,
      winners_count: 2,
      min_trust_level: 1,
      max_trust_level: 4,
      seed: seed,
      seed_digest: Digest::SHA256.hexdigest(seed),
    )
  end

  before do
    Fabricate(:post, topic: topic, user: eligible_user, created_at: 2.hours.ago)
    Fabricate(:post, topic: topic, user: eligible_user, created_at: 90.minutes.ago)
    Fabricate(:post, topic: topic, user: second_eligible_user, created_at: 80.minutes.ago)
    Fabricate(:post, topic: topic, user: low_level_user, created_at: 70.minutes.ago)
    Fabricate(:post, topic: topic, user: creator, created_at: 70.minutes.ago)
    Fabricate(:post, topic: topic, user: Fabricate(:user), created_at: 10.minutes.ago)
  end

  it "deduplicates replies and filters by trust level, deadline, and topic creator" do
    described_class.call(lottery)
    lottery.reload

    expect(lottery.participant_user_ids).to contain_exactly(eligible_user.id, second_eligible_user.id)
    expect(lottery.winner_user_ids).to contain_exactly(eligible_user.id, second_eligible_user.id)
    expect(lottery).to be_drawn
    expect(lottery.result_post_id).to be_present
  end

  it "is idempotent" do
    described_class.call(lottery)
    result_post_id = lottery.reload.result_post_id

    expect { described_class.call(lottery.reload) }.not_to change { Post.count }
    expect(lottery.reload.result_post_id).to eq(result_post_id)
  end

  it "refuses to draw before the deadline" do
    lottery.update!(closes_at: 1.hour.from_now)
    expect { described_class.call(lottery) }.to raise_error(described_class::TooEarly)
  end

  it "detects a changed random seed" do
    lottery.update_columns(seed: "tampered")
    expect { described_class.call(lottery) }.to raise_error("seed commitment mismatch")
  end
end
