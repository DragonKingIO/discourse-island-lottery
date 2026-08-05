import { click, visit } from "@ember/test-helpers";
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
      .dom(".island-lottery-composer-fields")
      .exists("the lottery settings are displayed in the composer");
  });
});
