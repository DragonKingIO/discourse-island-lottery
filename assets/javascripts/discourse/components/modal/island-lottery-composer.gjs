import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import DButton from "discourse/ui-kit/d-button";
import DModal from "discourse/ui-kit/d-modal";
import { i18n } from "discourse-i18n";

function localDateTime(value) {
  const date = value ? new Date(value) : new Date(Date.now() + 86400000);
  date.setMinutes(date.getMinutes() - date.getTimezoneOffset());
  return date.toISOString().slice(0, 16);
}

export default class IslandLotteryComposer extends Component {
  @tracked prize;
  @tracked closesAt;
  @tracked winnersCount;
  @tracked minTrustLevel;
  @tracked maxTrustLevel;

  constructor() {
    super(...arguments);
    const composer = this.args.model.composer;
    this.prize = composer.islandLotteryPrize || "";
    this.closesAt = localDateTime(composer.islandLotteryClosesAt);
    this.winnersCount = composer.islandLotteryWinnersCount || 1;
    this.minTrustLevel = composer.islandLotteryMinTrustLevel ?? 0;
    this.maxTrustLevel = composer.islandLotteryMaxTrustLevel ?? 4;
  }

  get composer() {
    return this.args.model.composer;
  }

  get configured() {
    return Boolean(this.composer.islandLotteryCreate);
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

  @action applyLottery() {
    if (this.invalid) {
      return;
    }

    this.composer.setProperties({
      islandLotteryCreate: true,
      islandLotteryPrize: this.prize,
      islandLotteryClosesAt: new Date(this.closesAt).toISOString(),
      islandLotteryWinnersCount: this.winnersCount,
      islandLotteryMinTrustLevel: this.minTrustLevel,
      islandLotteryMaxTrustLevel: this.maxTrustLevel,
    });
    this.composer.notifyPropertyChange("action");
    this.args.closeModal();
  }

  @action removeLottery() {
    this.composer.set("islandLotteryCreate", false);
    this.composer.notifyPropertyChange("action");
    this.args.closeModal();
  }

  <template>
    <DModal
      @title={{i18n "island_lottery.composer_modal_title"}}
      @closeModal={{@closeModal}}
    >
      <:body>
        <form class="island-lottery-form island-lottery-composer-modal">
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

          <p class="island-lottery-form__help">{{i18n "island_lottery.duplicate_notice"}}</p>
        </form>
      </:body>
      <:footer>
        <DButton
          @action={{this.applyLottery}}
          @label="island_lottery.composer_apply"
          @icon="gift"
          @disabled={{this.invalid}}
          class="btn-primary island-lottery-composer-apply"
        />
        {{#if this.configured}}
          <DButton
            @action={{this.removeLottery}}
            @label="island_lottery.composer_remove"
            class="btn-danger"
          />
        {{/if}}
        <DButton @action={{@closeModal}} @label="island_lottery.cancel" />
      </:footer>
    </DModal>
  </template>
}
