import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DButton from "discourse/ui-kit/d-button";
import DRelativeDate from "discourse/ui-kit/d-relative-date";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { eq } from "discourse/truth-helpers";
import { i18n } from "discourse-i18n";
import IslandLotteryComposer from "./modal/island-lottery-composer";

export default class IslandLotteryCard extends Component {
  @service modal;

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
        return i18n("island_lottery.open");
    }
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
        <div class="island-lottery-card__hero">
          <div class="island-lottery-card__identity">
            <span class="island-lottery-card__icon">{{dIcon "gift"}}</span>
            <div>
              <span class="island-lottery-card__eyebrow">{{i18n "island_lottery.eyebrow"}}</span>
              <h3>{{i18n "island_lottery.title"}}</h3>
            </div>
          </div>
          <span class="island-lottery-card__status">{{this.statusLabel}}</span>
        </div>

        {{#if this.lottery.prize}}
          <div class="island-lottery-card__prize">
            <span class="island-lottery-card__label">{{i18n "island_lottery.prize"}}</span>
            <strong>{{this.lottery.prize}}</strong>
          </div>
        {{/if}}

        <div class="island-lottery-card__stats">
          <div class="island-lottery-card__stat">
            <span class="island-lottery-card__label">{{i18n "island_lottery.closes_at"}}</span>
            <strong><DRelativeDate @date={{this.lottery.closes_at}} /></strong>
          </div>
          <div class="island-lottery-card__stat">
            <span class="island-lottery-card__label">{{i18n "island_lottery.winners_count"}}</span>
            <strong>{{this.lottery.winners_count}} {{i18n "island_lottery.people"}}</strong>
          </div>
          <div class="island-lottery-card__stat">
            <span class="island-lottery-card__label">{{i18n "island_lottery.eligibility_label"}}</span>
            <strong>TL{{this.lottery.min_trust_level}}～TL{{this.lottery.max_trust_level}}</strong>
          </div>
        </div>

        {{#if (eq this.lottery.status "drawn")}}
          <div class="island-lottery-card__result">
            <div class="island-lottery-card__result-heading">
              <span class="island-lottery-card__label">{{i18n "island_lottery.winners"}}</span>
              <span>{{i18n "island_lottery.participant_count" count=this.lottery.participant_count}}</span>
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

        <div class="island-lottery-card__footer">
          {{#if (eq this.lottery.status "open")}}
            <span class="island-lottery-card__commitment">
              {{i18n "island_lottery.commitment"}}：<code>{{this.lottery.seed_digest}}</code>
            </span>
          {{else if this.lottery.drawn_at}}
            <span class="island-lottery-card__commitment">{{i18n "island_lottery.drawn_at"}}：<DRelativeDate @date={{this.lottery.drawn_at}} /></span>
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
