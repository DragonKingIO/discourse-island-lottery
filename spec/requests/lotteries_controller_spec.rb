# frozen_string_literal: true

require "rails_helper"

RSpec.describe DiscourseIslandLottery::LotteriesController do
  fab!(:creator) { Fabricate(:user) }
  fab!(:other_user) { Fabricate(:user) }
  fab!(:topic) { Fabricate(:topic, user: creator) }

  before { SiteSetting.island_lottery_enabled = true }

  it "allows a topic creator to create a default all-level lottery" do
    sign_in(creator)

    post "/island-lottery.json",
         params: {
           topic_id: topic.id,
           closes_at: 1.day.from_now.iso8601,
           winners_count: 2,
           min_trust_level: 0,
           max_trust_level: 4,
           prize: "测试奖品",
         }

    expect(response.status).to eq(200)
    lottery = DiscourseIslandLottery::Lottery.find_by!(topic_id: topic.id)
    expect(lottery.creator).to eq(creator)
    expect(lottery.seed_digest).to be_present
    expect(response.parsed_body.dig("lottery", "revealed_seed")).to be_nil
  end

  it "does not allow an unrelated user to create the lottery" do
    sign_in(other_user)

    post "/island-lottery.json",
         params: {
           topic_id: topic.id,
           closes_at: 1.day.from_now.iso8601,
           winners_count: 1,
           min_trust_level: 0,
           max_trust_level: 4,
         }

    expect(response.status).to eq(403)
  end

  it "rejects an inverted trust-level range" do
    sign_in(creator)

    post "/island-lottery.json",
         params: {
           topic_id: topic.id,
           closes_at: 1.day.from_now.iso8601,
           winners_count: 1,
           min_trust_level: 4,
           max_trust_level: 1,
         }

    expect(response.status).to eq(400)
  end
end
