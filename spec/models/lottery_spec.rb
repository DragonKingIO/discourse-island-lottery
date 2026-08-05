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

  it "rejects an inverted trust-level range" do
    lottery = build_lottery(min_trust_level: 3, max_trust_level: 1)
    expect(lottery).not_to be_valid
  end

  it "allows only one lottery per topic" do
    build_lottery.save!
    expect(build_lottery).not_to be_valid
  end
end
