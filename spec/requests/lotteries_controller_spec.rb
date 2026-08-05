# frozen_string_literal: true

require "rails_helper"

RSpec.describe DiscourseIslandLottery::LotteriesController do
  fab!(:creator, :user)
  fab!(:other_user, :user)
  fab!(:admin)
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

  it "creates a lottery together with a new topic from composer parameters" do
    sign_in(admin)

    post "/posts.json",
         params: {
           title: "带抽奖的新话题",
           raw: "回复本话题即可参与抽奖。",
           archetype: Archetype.default,
           island_lottery_create: true,
           island_lottery_prize: "测试奖品",
           island_lottery_closes_at: 1.day.from_now.iso8601,
           island_lottery_winners_count: 3,
           island_lottery_min_trust_level: 1,
           island_lottery_max_trust_level: 3,
         }

    expect(response.status).to eq(200)
    topic_id = response.parsed_body.dig("post", "topic_id") || response.parsed_body["topic_id"]
    lottery = DiscourseIslandLottery::Lottery.find_by!(topic_id:)
    expect(lottery).to have_attributes(
      creator_id: admin.id,
      prize: "测试奖品",
      winners_count: 3,
      min_trust_level: 1,
      max_trust_level: 3,
    )
  end

  it "creates a lottery from the marker in the first post" do
    sign_in(creator)

    post "/posts.json",
         params: {
           title: "正文抽奖标记",
           raw: <<~RAW,
             回复即可参与。

             [island-lottery]
             prize: 一份正文奖品
             closes_at: #{2.days.from_now.iso8601}
             winners_count: 2
             min_trust_level: 0
             max_trust_level: 4
             [/island-lottery]
           RAW
           archetype: Archetype.default,
         }

    expect(response.status).to eq(200)
    topic_id = response.parsed_body.dig("post", "topic_id") || response.parsed_body["topic_id"]
    lottery = DiscourseIslandLottery::Lottery.find_by!(topic_id:)
    expect(lottery.prize).to eq("一份正文奖品")
    expect(Post.find_by!(topic_id:, post_number: 1).raw).to include("[island-lottery]")
  end

  it "lets the creator update the lottery and synchronizes the marker" do
    lottery = DiscourseIslandLottery::Lottery.create!(
      topic: topic,
      creator: creator,
      closes_at: 1.day.from_now,
      winners_count: 1,
      min_trust_level: 0,
      max_trust_level: 4,
      prize: "旧奖品",
      seed: "test-seed",
      seed_digest: Digest::SHA256.hexdigest("test-seed"),
    )
    sign_in(creator)

    patch "/island-lottery/#{lottery.id}.json",
          params: {
            prize: "新奖品",
            closes_at: 2.days.from_now.iso8601,
            winners_count: 2,
            min_trust_level: 1,
            max_trust_level: 3,
          }

    expect(response.status).to eq(200)
    expect(lottery.reload).to have_attributes(
      prize: "新奖品",
      winners_count: 2,
      min_trust_level: 1,
      max_trust_level: 3,
    )
    expect(topic.first_post.reload.raw).to include("prize: 新奖品", "winners_count: 2")
  end

  it "blocks the creator after one hour but keeps staff access" do
    lottery = DiscourseIslandLottery::Lottery.create!(
      topic: topic,
      creator: creator,
      created_at: 2.hours.ago,
      updated_at: 2.hours.ago,
      closes_at: 1.day.from_now,
      winners_count: 1,
      min_trust_level: 0,
      max_trust_level: 4,
      seed: "old-seed",
      seed_digest: Digest::SHA256.hexdigest("old-seed"),
    )

    sign_in(creator)
    patch "/island-lottery/#{lottery.id}.json", params: { prize: "不应生效" }
    expect(response.status).to eq(403)
    expect(lottery.reload.prize).not_to eq("不应生效")

    sign_in(admin)
    patch "/island-lottery/#{lottery.id}.json", params: { prize: "管理员修改" }
    expect(response.status).to eq(200)
    expect(lottery.reload.prize).to eq("管理员修改")
  end
end
