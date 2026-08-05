import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { ajax } from "discourse/lib/ajax";
import DButton from "discourse/ui-kit/d-button";
import DModal from "discourse/ui-kit/d-modal";
import { i18n } from "discourse-i18n";
import {
  buildIslandLotteryMarker,
  parseIslandLotteryMarker,
} from "../../../lib/island-lottery-marker";

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
  @tracked isSaving = false;
  @tracked errorMessage;

  constructor() {
    super(...arguments);
    const model = this.args.model;
    const composer = model.composer;
    const lottery = model.lottery;
    const marker = model.toolbarEvent
      ? parseIslandLotteryMarker(model.toolbarEvent.getText())
      : null;

    this.prize = lottery?.prize || composer?.islandLotteryPrize || marker?.prize || "";
    this.closesAt = localDateTime(
      lottery?.closes_at || composer?.islandLotteryClosesAt || marker?.closes_at
    );
    this.winnersCount =
      lottery?.winners_count || composer?.islandLotteryWinnersCount || marker?.winners_count || 1;
    this.minTrustLevel =
      lottery?.min_trust_level ?? composer?.islandLotteryMinTrustLevel ?? marker?.min_trust_level ?? 0;
    this.maxTrustLevel =
      lottery?.max_trust_level ?? composer?.islandLotteryMaxTrustLevel ?? marker?.max_trust_level ?? 4;
  }

  get composer() {
    return this.args.model.composer;
  }

  get lottery() {
    return this.args.model.lottery;
  }

  get editing() {
    return Boolean(this.lottery);
  }

  get configured() {
    return Boolean(this.composer?.islandLotteryCreate);
  }

  get submitDisabled() {
    return this.invalid || this.isSaving;
  }

  get showRemoveButton() {
    return this.configured && !this.editing;
  }

  get invalid() {
    return (
      !this.closesAt ||
      Number(this.winnersCount) < 1 ||
      Number(this.minTrustLevel) < 0 ||
      Number(this.maxTrustLevel) > 4 ||
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

  @action async applyLottery() {
    if (this.invalid) {
      return;
    }

    const closesAt = new Date(this.closesAt).toISOString();

    if (this.editing) {
      this.isSaving = true;
      this.errorMessage = null;

      try {
        const result = await ajax(`/island-lottery/${this.lottery.id}.json`, {
          type: "PATCH",
          data: {
            prize: this.prize,
            closes_at: closesAt,
            winners_count: this.winnersCount,
            min_trust_level: this.minTrustLevel,
            max_trust_level: this.maxTrustLevel,
          },
        });
        this.args.model.onSaved?.(result.lottery);
        this.args.closeModal();
      } catch (error) {
        this.errorMessage =
          error?.jqXHR?.responseJSON?.errors?.join(" ") ||
          i18n("island_lottery.save_failed");
      } finally {
        this.isSaving = false;
      }
      return;
    }

    this.composer?.setProperties({
      islandLotteryCreate: true,
      islandLotteryPrize: this.prize,
      islandLotteryClosesAt: closesAt,
      islandLotteryWinnersCount: this.winnersCount,
      islandLotteryMinTrustLevel: this.minTrustLevel,
      islandLotteryMaxTrustLevel: this.maxTrustLevel,
    });
    this.composer?.notifyPropertyChange("action");

    const toolbarEvent = this.args.model.toolbarEvent;
    if (toolbarEvent) {
      const marker = buildIslandLotteryMarker({
        prize: this.prize,
        closesAt,
        winnersCount: this.winnersCount,
        minTrustLevel: this.minTrustLevel,
        maxTrustLevel: this.maxTrustLevel,
      });
      const existingMarker = parseIslandLotteryMarker(toolbarEvent.getText());

      if (existingMarker?.raw) {
        toolbarEvent.replaceText(existingMarker.raw, marker);
      } else {
        toolbarEvent.addText(`\n${marker}\n`);
      }
    }

    this.args.closeModal();
  }

  @action removeLottery() {
    const toolbarEvent = this.args.model.toolbarEvent;
    const existingMarker = toolbarEvent
      ? parseIslandLotteryMarker(toolbarEvent.getText())
      : null;
    if (existingMarker?.raw) {
      toolbarEvent.replaceText(existingMarker.raw, "");
    }

    this.composer?.set("islandLotteryCreate", false);
    this.composer?.notifyPropertyChange("action");
    this.args.closeModal();
  }

  <template>
    <DModal
      @title={{if this.editing (i18n "island_lottery.edit_modal_title") (i18n "island_lottery.composer_modal_title")}}
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
          {{#if this.errorMessage}}
            <p class="island-lottery-form__error">{{this.errorMessage}}</p>
          {{/if}}
        </form>
      </:body>
      <:footer>
        <DButton
          @action={{this.applyLottery}}
          @label={{if this.editing "island_lottery.save_edit" "island_lottery.composer_apply"}}
          @icon="gift"
          @disabled={{this.submitDisabled}}
          @isLoading={{this.isSaving}}
          class="btn-primary island-lottery-composer-apply"
        />
        {{#if this.showRemoveButton}}
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
