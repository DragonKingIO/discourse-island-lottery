import { withPluginApi } from "discourse/lib/plugin-api";
import { CREATE_TOPIC } from "discourse/models/composer";
import { i18n } from "discourse-i18n";

function defaultCloseTime() {
  return new Date(Date.now() + 24 * 60 * 60 * 1000).toISOString();
}

export default {
  name: "island-lottery-composer",

  initialize() {
    withPluginApi((api) => {
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

      api.modifyClass("component:composer-actions", {
        pluginId: "discourse-island-lottery",

        toggleIslandLotterySelected(_options, model) {
          model.toggleProperty("islandLotteryCreate");

          if (model.islandLotteryCreate) {
            model.set(
              "islandLotteryClosesAt",
              model.islandLotteryClosesAt || defaultCloseTime()
            );
            model.set(
              "islandLotteryWinnersCount",
              model.islandLotteryWinnersCount || 1
            );
            model.set(
              "islandLotteryMinTrustLevel",
              model.islandLotteryMinTrustLevel ?? 0
            );
            model.set(
              "islandLotteryMaxTrustLevel",
              model.islandLotteryMaxTrustLevel ?? 4
            );
          }

          model.notifyPropertyChange("replyOptions");
          model.notifyPropertyChange("action");
        },
      });

      api.modifySelectKit("composer-actions").appendContent((options) => {
        if (options.action !== CREATE_TOPIC) {
          return [];
        }

        const selected = options.composerModel.islandLotteryCreate;
        return [
          {
            name: i18n(
              selected
                ? "island_lottery.composer_remove"
                : "island_lottery.composer_create"
            ),
            description: i18n(
              selected
                ? "island_lottery.composer_remove_description"
                : "island_lottery.composer_create_description"
            ),
            icon: "gift",
            id: "toggleIslandLottery",
          },
        ];
      });

      // Discourse's redesigned composer actions menu uses transformers instead
      // of the legacy SelectKit extension above. Keep both registrations so the
      // lottery action works regardless of which composer UI is enabled.
      api.registerValueTransformer(
        "composer-actions-content",
        ({ value, context }) => {
          if (context.action !== CREATE_TOPIC) {
            return value;
          }

          const selected = context.composerModel.islandLotteryCreate;
          value.push({
            name: i18n(
              selected
                ? "island_lottery.composer_remove"
                : "island_lottery.composer_create"
            ),
            description: i18n(
              selected
                ? "island_lottery.composer_remove_description"
                : "island_lottery.composer_create_description"
            ),
            icon: "gift",
            id: "toggleIslandLottery",
          });

          return value;
        }
      );

      api.registerBehaviorTransformer(
        "composer-actions-on-select",
        ({ context, next }) => {
          if (context.actionId === "toggleIslandLottery") {
            const model = context.model;
            model.toggleProperty("islandLotteryCreate");

            if (model.islandLotteryCreate) {
              model.set(
                "islandLotteryClosesAt",
                model.islandLotteryClosesAt || defaultCloseTime()
              );
              model.set(
                "islandLotteryWinnersCount",
                model.islandLotteryWinnersCount || 1
              );
              model.set(
                "islandLotteryMinTrustLevel",
                model.islandLotteryMinTrustLevel ?? 0
              );
              model.set(
                "islandLotteryMaxTrustLevel",
                model.islandLotteryMaxTrustLevel ?? 4
              );
            }

            model.notifyPropertyChange("replyOptions");
            model.notifyPropertyChange("action");
          } else {
            next();
          }
        }
      );
    });
  },
};
