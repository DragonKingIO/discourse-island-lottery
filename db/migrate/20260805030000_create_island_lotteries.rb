# frozen_string_literal: true

class CreateIslandLotteries < ActiveRecord::Migration[7.2]
  def change
    create_table :island_lotteries do |t|
      t.bigint :topic_id, null: false
      t.bigint :creator_id, null: false
      t.datetime :closes_at, null: false
      t.integer :winners_count, null: false
      t.integer :min_trust_level, null: false, default: 0
      t.integer :max_trust_level, null: false, default: 4
      t.integer :status, null: false, default: 0
      t.text :prize
      t.string :seed, null: false
      t.string :seed_digest, null: false
      t.jsonb :participant_user_ids, null: false, default: []
      t.jsonb :winner_user_ids, null: false, default: []
      t.datetime :drawn_at
      t.bigint :result_post_id
      t.timestamps
    end

    add_index :island_lotteries, :topic_id, unique: true
    add_index :island_lotteries, :creator_id
    add_index :island_lotteries, %i[status closes_at]
  end
end
