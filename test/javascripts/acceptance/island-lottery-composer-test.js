import { click, fillIn, visit } from "@ember/test-helpers";
import { test } from "qunit";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";

acceptance("Island Lottery | composer toolbar", function (needs) {
  needs.user();
  needs.settings({
    allow_uncategorized_topics: true,
    island_lottery_enabled: true,
  });

  test("creates a lottery from the new-topic toolbar menu", async function (assert) {
    await visit("/latest");
    await click("#create-topic");
    await click(".toolbar-menu__options-trigger");

    assert
      .dom("[data-name='island-lottery']")
      .exists("the lottery action is shown in the plus menu");

    await click("[data-name='island-lottery']");

    assert
      .dom(".island-lottery-composer-modal")
      .exists("the native lottery settings modal is displayed");

    await fillIn(
      ".island-lottery-composer-modal textarea",
      "一份小岛纪念品"
    );
    await click(".island-lottery-composer-apply");

    assert.dom(".island-lottery-composer-modal").doesNotExist();
    assert.true(this.container.lookup("service:composer").model.islandLotteryCreate);
    assert.strictEqual(
      this.container.lookup("service:composer").model.islandLotteryPrize,
      "一份小岛纪念品"
    );
  });
});
