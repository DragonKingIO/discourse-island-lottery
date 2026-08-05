import Component from "@glimmer/component";
import { registerDestructor } from "@ember/destroyable";
import { action } from "@ember/object";
import { later, cancel } from "@ember/runloop";
import { service } from "@ember/service";
import { tracked } from "@glimmer/tracking";
import DButton from "discourse/ui-kit/d-button";
import DRelativeDate from "discourse/ui-kit/d-relative-date";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";
import IslandLotteryComposer from "./modal/island-lottery-composer";

export default class IslandLotteryCard extends Component {
  @service modal;
  @tracked now = Date.now();

  constructor(...args) {
    super(...args);
    this.scheduleCountdownTick();
    registerDestructor(this, () => cancel(this.countdownTimer));
  }

  scheduleCountdownTick() {
    this.countdownTimer = later(this, () => {
      this.now = Date.now();
      this.scheduleCountdownTick();
    }, 1000);
  }

  get post() {
    return this.args.data?.post;
  }

  get lottery() {
    return this.post?.topic?.island_lottery;
  }

  get statusLabel() {
    switch (this.lottery?.status) {
      case "drawn":
        return i18n("island_lottery.drawn");
      case "cancelled":
        return i18n("island_lottery.cancelled");
      case "drawing":
        return i18n("island_lottery.drawing");
      default:
        return this.countdownSeconds > 0
          ? i18n("island_lottery.open")
          : i18n("island_lottery.drawing");
    }
  }

  get isOpen() {
    return this.lottery?.status === "open";
  }

  get isDrawn() {
    return this.lottery?.status === "drawn";
  }

  get isCancelled() {
    return this.lottery?.status === "cancelled";
  }

  get closesAtMs() {
    const timestamp = Date.parse(this.lottery?.closes_at || "");
    return Number.isNaN(timestamp) ? null : timestamp;
  }

  get countdownSeconds() {
    if (!this.isOpen || this.closesAtMs === null) {
      return 0;
    }

    return Math.max(0, Math.floor((this.closesAtMs - this.now) / 1000));
  }

  get countdownValue() {
    const totalSeconds = this.countdownSeconds;
    const days = Math.floor(totalSeconds / 86400);
    const hours = Math.floor((totalSeconds % 86400) / 3600);
    const minutes = Math.floor((totalSeconds % 3600) / 60);
    const seconds = totalSeconds % 60;
    const pad = (value) => String(value).padStart(2, "0");

    if (days > 0) {
      return `${days}d ${pad(hours)}:${pad(minutes)}:${pad(seconds)}`;
    }

    return `${pad(hours)}:${pad(minutes)}:${pad(seconds)}`;
  }

  get countdownLabel() {
    return this.countdownSeconds > 0
      ? i18n("island_lottery.countdown_remaining", { time: this.countdownValue })
      : i18n("island_lottery.countdown_finished");
  }

  get closesAtText() {
    if (this.closesAtMs === null) {
      return "";
    }

    return new Date(this.closesAtMs).toLocaleString();
  }

  get participationCountLabel() {
    return this.isDrawn
      ? i18n("island_lottery.participant_count", {
          count: this.lottery.participant_count,
        })
      : i18n("island_lottery.participant_count_pending");
  }

  get canEdit() {
    return this.lottery?.can_manage;
  }

  @action editLottery() {
    this.modal.show(IslandLotteryComposer, {
      model: {
        lottery: this.lottery,
        onSaved: (lottery) => {
          this.post.topic.set("island_lottery", lottery);
        },
      },
    });
  }

  <template>
    {{#if this.lottery}}
      <section class="island-lottery-card" aria-label={{i18n "island_lottery.title"}}>
        <div class="island-lottery-card__header">
          <div class="island-lottery-card__identity">
            <span class="island-lottery-card__icon" aria-hidden="true">{{dIcon "gift"}}</span>
            <div>
              <span class="island-lottery-card__eyebrow">{{i18n "island_lottery.event_label"}}</span>
              <h3>{{i18n "island_lottery.title"}}</h3>
            </div>
          </div>
          <span class="island-lottery-card__status">{{this.statusLabel}}</span>
        </div>

        {{#if this.lottery.prize}}
          <div class="island-lottery-card__prize">
            <span class="island-lottery-card__label">{{i18n "island_lottery.prize_label"}}</span>
            <strong>{{this.lottery.prize}}</strong>
          </div>
        {{/if}}

        {{#if this.isOpen}}
          <div class="island-lottery-card__countdown">
            <div>
              <span class="island-lottery-card__label">{{i18n "island_lottery.countdown_label"}}</span>
              <strong>{{this.countdownLabel}}</strong>
            </div>
            <span class="island-lottery-card__countdown-value">{{this.countdownValue}}</span>
          </div>
        {{/if}}

        <div class="island-lottery-card__stats">
          <div class="island-lottery-card__stat">
            <span class="island-lottery-card__label">{{i18n "island_lottery.closes_at"}}</span>
            <strong><DRelativeDate @date={{this.lottery.closes_at}} /></strong>
            <small>{{this.closesAtText}}</small>
          </div>
          <div class="island-lottery-card__stat">
            <span class="island-lottery-card__label">{{i18n "island_lottery.winners_count"}}</span>
            <strong>{{this.lottery.winners_count}} {{i18n "island_lottery.people"}}</strong>
          </div>
          <div class="island-lottery-card__stat">
            <span class="island-lottery-card__label">{{i18n "island_lottery.participant_count_label"}}</span>
            <strong>{{this.participationCountLabel}}</strong>
          </div>
          <div class="island-lottery-card__stat">
            <span class="island-lottery-card__label">{{i18n "island_lottery.eligibility_label"}}</span>
            <strong>TL{{this.lottery.min_trust_level}}～TL{{this.lottery.max_trust_level}}</strong>
          </div>
        </div>

        {{#if this.isDrawn}}
          <div class="island-lottery-card__result">
            <div class="island-lottery-card__result-heading">
              <span class="island-lottery-card__label">{{i18n "island_lottery.winners"}}</span>
              <span>{{i18n "island_lottery.result_summary" count=this.lottery.participant_count}}</span>
            </div>
            {{#if this.lottery.winner_users.length}}
              <ol>
                {{#each this.lottery.winner_users as |winner|}}
                  <li><a href="/u/{{winner.username}}">@{{winner.username}}</a></li>
                {{/each}}
              </ol>
            {{else}}
              <p>{{i18n "island_lottery.no_winners"}}</p>
            {{/if}}
          </div>
        {{/if}}

        <div class="island-lottery-card__rules">
          <strong>{{i18n "island_lottery.rules_title"}}</strong>
          <ul>
            <li>{{i18n "island_lottery.rule_reply"}}</li>
            <li>{{i18n "island_lottery.rule_unique"}}</li>
            <li>{{i18n "island_lottery.rule_excluded"}}</li>
          </ul>
        </div>

        <div class="island-lottery-card__footer">
          {{#if this.isDrawn}}
            <span>{{i18n "island_lottery.drawn_at"}}：<DRelativeDate @date={{this.lottery.drawn_at}} /></span>
          {{else if this.isCancelled}}
            <span>{{i18n "island_lottery.cancelled"}}</span>
          {{else}}
            <span>{{i18n "island_lottery.reply_to_join"}}</span>
          {{/if}}

          {{#if this.canEdit}}
            <DButton
              @action={{this.editLottery}}
              @label="island_lottery.edit"
              @icon="pencil"
              class="btn-flat island-lottery-card__edit"
            />
          {{/if}}
        </div>
      </section>
    {{/if}}
  </template>
}
