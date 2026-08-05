import Component from "@glimmer/component";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { CREATE_TOPIC } from "discourse/models/composer";
import { i18n } from "discourse-i18n";

export default class IslandLotteryFields extends Component {
  static shouldRender(args) {
    return args.model?.action === CREATE_TOPIC && args.model.islandLotteryCreate;
  }

  get composer() {
    return this.args.outletArgs.model;
  }

  get closesAtInput() {
    const value = this.composer.islandLotteryClosesAt;
    if (!value) {
      return "";
    }

    const date = new Date(value);
    date.setMinutes(date.getMinutes() - date.getTimezoneOffset());
    return date.toISOString().slice(0, 16);
  }

  @action setPrize(event) {
    this.composer.set("islandLotteryPrize", event.target.value);
  }

  @action setCloseTime(event) {
    const date = new Date(event.target.value);
    this.composer.set(
      "islandLotteryClosesAt",
      Number.isNaN(date.getTime()) ? null : date.toISOString()
    );
  }

  @action setWinnersCount(event) {
    this.composer.set("islandLotteryWinnersCount", Number(event.target.value));
  }

  @action setMinTrustLevel(event) {
    this.composer.set("islandLotteryMinTrustLevel", Number(event.target.value));
  }

  @action setMaxTrustLevel(event) {
    this.composer.set("islandLotteryMaxTrustLevel", Number(event.target.value));
  }

  <template>
    <fieldset class="island-lottery-composer-fields">
      <legend>🎁 {{i18n "island_lottery.composer_fields_title"}}</legend>

      <label>
        {{i18n "island_lottery.prize"}}
        <input
          type="text"
          value={{this.composer.islandLotteryPrize}}
          placeholder={{i18n "island_lottery.prize_placeholder"}}
          maxlength="1000"
          {{on "input" this.setPrize}}
        />
      </label>

      <div class="island-lottery-composer-fields__row">
        <label>
          {{i18n "island_lottery.closes_at"}}
          <input
            type="datetime-local"
            value={{this.closesAtInput}}
            required
            {{on "input" this.setCloseTime}}
          />
        </label>

        <label>
          {{i18n "island_lottery.winners_count"}}
          <input
            type="number"
            min="1"
            max="20"
            value={{this.composer.islandLotteryWinnersCount}}
            required
            {{on "input" this.setWinnersCount}}
          />
        </label>
      </div>

      <div class="island-lottery-composer-fields__row">
        <label>
          {{i18n "island_lottery.min_trust_level"}}
          <select
            value={{this.composer.islandLotteryMinTrustLevel}}
            {{on "change" this.setMinTrustLevel}}
          >
            <option value="0">TL0</option><option value="1">TL1</option>
            <option value="2">TL2</option><option value="3">TL3</option>
            <option value="4">TL4</option>
          </select>
        </label>

        <label>
          {{i18n "island_lottery.max_trust_level"}}
          <select
            value={{this.composer.islandLotteryMaxTrustLevel}}
            {{on "change" this.setMaxTrustLevel}}
          >
            <option value="0">TL0</option><option value="1">TL1</option>
            <option value="2">TL2</option><option value="3">TL3</option>
            <option value="4">TL4</option>
          </select>
        </label>
      </div>

      <p>{{i18n "island_lottery.duplicate_notice"}}</p>
    </fieldset>
  </template>
}
