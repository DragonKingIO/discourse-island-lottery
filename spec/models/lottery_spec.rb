# frozen_string_literal: true

require "rails_helper"

RSpec.describe DiscourseIslandLottery::Lottery do
  fab!(:creator, :user)
  fab!(:topic) { Fabricate(:topic, user: creator) }

  def build_lottery(overrides = {})
    described_class.new(
      {
        topic: topic,
        creator: creator,
        closes_at: 1.day.from_now,
        winners_count: 1,
        min_trust_level: 0,
        max_trust_level: 4,
        seed: "seed",
        seed_digest: Digest::SHA256.hexdigest("seed"),
      }.merge(overrides),
    )
  end

  it "accepts the default all-level eligibility range" do
    expect(build_lottery).to be_valid
  end

  it "reports unique live participants and the current user's participation" do
    participant = Fabricate(:user, trust_level: 1)
    Fabricate(:post, topic: topic, user: participant)
    Fabricate(:post, topic: topic, user: participant)
    lottery = build_lottery
    lottery.save!

    payload = lottery.public_payload(Guardian.new(participant))

    expect(payload[:participant_count]).to eq(1)
    expect(payload[:current_user_participated]).to be(true)
  end

  it "rejects an inverted trust-level range" do
    lottery = build_lottery(min_trust_level: 3, max_trust_level: 1)
    expect(lottery).not_to be_valid
  end

  it "allows only one lottery per topic" do
    build_lottery.save!
    expect(build_lottery).not_to be_valid
  end

  it "lets the creator edit for one hour and staff edit while it is open" do
    lottery = build_lottery
    lottery.save!

    expect(lottery.can_manage?(creator, now: lottery.created_at + 59.minutes)).to be(true)
    expect(lottery.can_manage?(creator, now: lottery.created_at + 1.hour)).to be(false)
    expect(lottery.can_manage?(Fabricate(:admin), now: lottery.created_at + 2.days)).to be(true)
  end

  it "does not allow edits after the lottery has been drawn" do
    lottery = build_lottery(status: :drawn)
    expect(lottery.can_manage?(creator)).to be(false)
  end
end
