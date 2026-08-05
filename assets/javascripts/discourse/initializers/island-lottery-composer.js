import { withPluginApi } from "discourse/lib/plugin-api";
import { CREATE_TOPIC } from "discourse/models/composer";
import IslandLotteryComposer from "../components/modal/island-lottery-composer";

export default {
  name: "island-lottery-composer",

  initialize() {
    withPluginApi((api) => {
      const composerService = api.container.lookup("service:composer");
      const modal = api.container.lookup("service:modal");

      api.serializeOnCreate("island_lottery_create", "islandLotteryCreate");
      api.serializeOnCreate("island_lottery_prize", "islandLotteryPrize");
      api.serializeOnCreate(
        "island_lottery_closes_at",
        "islandLotteryClosesAt"
      );
      api.serializeOnCreate(
        "island_lottery_winners_count",
        "islandLotteryWinnersCount"
      );
      api.serializeOnCreate(
        "island_lottery_min_trust_level",
        "islandLotteryMinTrustLevel"
      );
      api.serializeOnCreate(
        "island_lottery_max_trust_level",
        "islandLotteryMaxTrustLevel"
      );

      api.addComposerToolbarPopupMenuOption({
        name: "island-lottery",
        group: "insertions",
        icon: "ticket-simple",
        label: "island_lottery.composer_toolbar_create",
        action: (toolbarEvent) => {
          const composer = composerService.model;
          if (composer) {
            modal.show(IslandLotteryComposer, {
              model: { composer, toolbarEvent },
            });
          }
        },
        condition: (composer) => composer.model?.action === CREATE_TOPIC,
      });
    });
  },
};
