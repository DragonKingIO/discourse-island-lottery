import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { or } from "discourse/truth-helpers";
import DButton from "discourse/ui-kit/d-button";
import DModal from "discourse/ui-kit/d-modal";
import { i18n } from "discourse-i18n";

export default class IslandLotteryCreate extends Component {
  @tracked prize = "";
  @tracked winnersCount = 1;
  @tracked minTrustLevel = 0;
  @tracked maxTrustLevel = 4;
  @tracked closesAt = this.defaultCloseTime;
  @tracked saving = false;

  get defaultCloseTime() {
    const date = new Date(Date.now() + 24 * 60 * 60 * 1000);
    date.setMinutes(date.getMinutes() - date.getTimezoneOffset());
    return date.toISOString().slice(0, 16);
  }

  get invalid() {
    return (
      !this.closesAt ||
      this.winnersCount < 1 ||
      Number(this.minTrustLevel) > Number(this.maxTrustLevel)
    );
  }

  @action setPrize(event) {
    this.prize = event.target.value;
  }

  @action setCloseTime(event) {
    this.closesAt = event.target.value;
  }

  @action setWinnersCount(event) {
    this.winnersCount = Number(event.target.value);
  }

  @action setMinTrustLevel(event) {
    this.minTrustLevel = Number(event.target.value);
  }

  @action setMaxTrustLevel(event) {
    this.maxTrustLevel = Number(event.target.value);
  }

  @action async createLottery() {
    if (this.invalid) {
      return;
    }

    this.saving = true;
    try {
      const response = await ajax("/island-lottery", {
        type: "POST",
        data: {
          topic_id: this.args.model.topic.id,
          prize: this.prize,
          closes_at: new Date(this.closesAt).toISOString(),
          winners_count: this.winnersCount,
          min_trust_level: this.minTrustLevel,
          max_trust_level: this.maxTrustLevel,
        },
      });

      this.args.model.topic.set("island_lottery", response.lottery);
      this.args.model.topic.set("can_create_island_lottery", false);
      this.args.closeModal();
    } catch (error) {
      popupAjaxError(error);
    } finally {
      this.saving = false;
    }
  }

  <template>
    <DModal @title={{i18n "island_lottery.create"}} @closeModal={{@closeModal}}>
      <:body>
        <form class="island-lottery-form">
          <label>
            {{i18n "island_lottery.prize"}}
            <textarea
              value={{this.prize}}
              placeholder={{i18n "island_lottery.prize_placeholder"}}
              maxlength="1000"
              {{on "input" this.setPrize}}
            ></textarea>
          </label>

          <label>
            {{i18n "island_lottery.closes_at"}}
            <input
              type="datetime-local"
              value={{this.closesAt}}
              {{on "input" this.setCloseTime}}
            />
          </label>

          <label>
            {{i18n "island_lottery.winners_count"}}
            <input
              type="number"
              min="1"
              max="20"
              value={{this.winnersCount}}
              {{on "input" this.setWinnersCount}}
            />
          </label>

          <div class="island-lottery-form__levels">
            <label>
              {{i18n "island_lottery.min_trust_level"}}
              <select value={{this.minTrustLevel}} {{on "change" this.setMinTrustLevel}}>
                <option value="0">TL0</option><option value="1">TL1</option>
                <option value="2">TL2</option><option value="3">TL3</option>
                <option value="4">TL4</option>
              </select>
            </label>
            <label>
              {{i18n "island_lottery.max_trust_level"}}
              <select value={{this.maxTrustLevel}} {{on "change" this.setMaxTrustLevel}}>
                <option value="0">TL0</option><option value="1">TL1</option>
                <option value="2">TL2</option><option value="3">TL3</option>
                <option value="4">TL4</option>
              </select>
            </label>
          </div>

          <p class="island-lottery-form__help">{{i18n "island_lottery.all_levels"}}</p>
          <p class="island-lottery-form__help">{{i18n "island_lottery.duplicate_notice"}}</p>
        </form>
      </:body>
      <:footer>
        <DButton
          @action={{this.createLottery}}
          @label="island_lottery.submit"
          @icon="gift"
          @disabled={{or this.invalid this.saving}}
          class="btn-primary"
        />
        <DButton @action={{@closeModal}} @label="island_lottery.cancel" />
      </:footer>
    </DModal>
  </template>
}
