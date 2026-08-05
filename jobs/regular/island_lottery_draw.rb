# frozen_string_literal: true

module Jobs
  class IslandLotteryDraw < ::Jobs::Base
    def execute(args)
      lottery = ::DiscourseIslandLottery::Lottery.find_by(id: args[:lottery_id])
      return if lottery.nil? || lottery.drawn? || lottery.cancelled?

      if lottery.closes_at > Time.zone.now
        Jobs.enqueue_at(lottery.closes_at, :island_lottery_draw, lottery_id: lottery.id)
        return
      end

      ::DiscourseIslandLottery::DrawService.call(lottery)
    end
  end
end
