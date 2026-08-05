import Component from "@glimmer/component";
import { getOwner } from "@ember/owner";
import { registerDestructor } from "@ember/destroyable";
import { action } from "@ember/object";
import { later, cancel } from "@ember/runloop";
import { service } from "@ember/service";
import { tracked } from "@glimmer/tracking";
import Composer from "discourse/models/composer";
import DButton from "discourse/ui-kit/d-button";
import DRelativeDate from "discourse/ui-kit/d-relative-date";
import dAvatar from "discourse/ui-kit/helpers/d-avatar";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";
import IslandLotteryComposer from "./modal/island-lottery-composer";

export default class IslandLotteryCard extends Component {
  @service composer;
  @service currentUser;
  @service modal;
  @tracked now = Date.now();
  @tracked rulesExpanded = false;

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

  get hasCountdown() {
    return this.isOpen && this.countdownSeconds > 0;
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

  get closesAtText() {
    if (this.closesAtMs === null) {
      return "";
    }

    return new Intl.DateTimeFormat(undefined, {
      month: "numeric",
      day: "numeric",
      hour: "2-digit",
      minute: "2-digit",
    }).format(new Date(this.closesAtMs));
  }

  get participationCountLabel() {
    return this.isDrawn
      ? i18n("island_lottery.final_participant_count", {
          count: this.lottery.participant_count,
        })
      : i18n("island_lottery.current_participant_count", {
          count: this.lottery.participant_count,
        });
  }

  get currentUserParticipated() {
    return Boolean(this.lottery?.current_user_participated);
  }

  get canEdit() {
    return this.lottery?.can_manage;
  }

  @action joinLottery() {
    if (!this.currentUser) {
      getOwner(this).lookup("route:application").send("showLogin");
      return;
    }

    const topic = this.post?.topic;
    if (!topic || topic.details?.can_create_post === false) {
      return;
    }

    this.composer.open({
      action: Composer.REPLY,
      topic,
      draftKey: topic.draft_key,
      draftSequence: topic.draft_sequence,
    });
  }

  @action toggleRules() {
    this.rulesExpanded = !this.rulesExpanded;
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
            <span class="island-lottery-card__icon" aria-hidden="true">{{dIcon "ticket-simple"}}</span>
            <h3>{{i18n "island_lottery.title"}}</h3>
          </div>
          <div class="island-lottery-card__header-actions">
            <span class="island-lottery-card__status">
              <span class="island-lottery-card__status-dot" aria-hidden="true"></span>
              <span>{{this.statusLabel}}</span>
              {{#if this.hasCountdown}}
                <span aria-hidden="true">·</span>
                <time
                  datetime={{this.lottery.closes_at}}
                  aria-label={{i18n "island_lottery.countdown_remaining" time=this.countdownValue}}
                >{{this.countdownValue}}</time>
              {{/if}}
            </span>
            {{#if this.canEdit}}
              <DButton
                @action={{this.editLottery}}
                @label="island_lottery.edit"
                @icon="pencil"
                class="btn-flat island-lottery-card__edit"
              />
            {{/if}}
          </div>
        </div>

        {{#if this.lottery.prize}}
          <div class="island-lottery-card__prize">
            <span class="island-lottery-card__label">{{i18n "island_lottery.prize_label"}}</span>
            <strong>{{this.lottery.prize}}</strong>
            <span class="island-lottery-card__prize-note">
              {{i18n "island_lottery.draw_winners" count=this.lottery.winners_count}}
            </span>
          </div>
        {{/if}}

        <div class="island-lottery-card__details">
          <div class="island-lottery-card__detail">
            <span class="island-lottery-card__label">{{i18n "island_lottery.closes_at"}}</span>
            <strong>
              <time datetime={{this.lottery.closes_at}}>{{this.closesAtText}}</time>
              {{i18n "island_lottery.draw_at_suffix"}}
            </strong>
          </div>
          <div class="island-lottery-card__detail">
            <span class="island-lottery-card__label">{{i18n "island_lottery.participant_count_label"}}</span>
            <strong>{{this.participationCountLabel}}</strong>
          </div>
        </div>

        {{#if this.isDrawn}}
          <div class="island-lottery-card__result">
            <div class="island-lottery-card__result-heading">
              <span class="island-lottery-card__label">{{i18n "island_lottery.winners"}}</span>
              <span>{{this.participationCountLabel}}</span>
            </div>
            {{#if this.lottery.winner_users.length}}
              <div class="island-lottery-card__winner-list">
                {{#each this.lottery.winner_users as |winner|}}
                  <a class="island-lottery-card__winner" href="/u/{{winner.username}}">
                    {{dAvatar winner imageSize="small"}}
                    <span>@{{winner.username}}</span>
                  </a>
                {{/each}}
              </div>
            {{else}}
              <p>{{i18n "island_lottery.no_winners"}}</p>
            {{/if}}
          </div>
        {{/if}}

        {{#if this.isOpen}}
          <DButton
            @action={{this.joinLottery}}
            @label={{if this.currentUserParticipated "island_lottery.joined" "island_lottery.join"}}
            @icon={{if this.currentUserParticipated "check" "reply"}}
            @disabled={{this.currentUserParticipated}}
            class="btn-primary island-lottery-card__join"
          />
        {{else if this.isCancelled}}
          <div class="island-lottery-card__notice">{{i18n "island_lottery.cancelled"}}</div>
        {{else if this.isDrawn}}
          <div class="island-lottery-card__notice">
            {{i18n "island_lottery.drawn_at"}}：<DRelativeDate @date={{this.lottery.drawn_at}} />
          </div>
        {{/if}}

        <div class="island-lottery-card__rules">
          <div class="island-lottery-card__rules-summary">
            <span>
              {{i18n "island_lottery.participation_scope"}}
              <strong>TL{{this.lottery.min_trust_level}}–TL{{this.lottery.max_trust_level}}</strong>
            </span>
            <DButton
              @action={{this.toggleRules}}
              @label={{if this.rulesExpanded "island_lottery.hide_rules" "island_lottery.view_rules"}}
              @icon={{if this.rulesExpanded "chevron-down" "chevron-right"}}
              class="btn-flat island-lottery-card__rules-toggle"
            />
          </div>
          {{#if this.rulesExpanded}}
            <ul>
              <li>{{i18n "island_lottery.rule_reply"}}</li>
              <li>{{i18n "island_lottery.rule_unique"}}</li>
              <li>{{i18n "island_lottery.rule_excluded"}}</li>
            </ul>
          {{/if}}
        </div>
      </section>
    {{/if}}
  </template>
}
