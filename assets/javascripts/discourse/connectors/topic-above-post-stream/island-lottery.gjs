import Component from "@glimmer/component";
import DRelativeDate from "discourse/ui-kit/d-relative-date";
import { eq } from "discourse/truth-helpers";
import { i18n } from "discourse-i18n";

export default class IslandLotteryConnector extends Component {
  get topic() {
    return this.args.outletArgs.model;
  }

  get lottery() {
    return this.topic.island_lottery;
  }

  <template>
    {{#if this.lottery}}
      <section class="island-lottery-card">
        <div class="island-lottery-card__header">
          <h3>🎁 {{i18n "island_lottery.title"}}</h3>
          <span class="island-lottery-card__status">
            {{#if (eq this.lottery.status "open")}}{{i18n "island_lottery.open"}}
            {{else if (eq this.lottery.status "drawn")}}{{i18n "island_lottery.drawn"}}
            {{else if (eq this.lottery.status "cancelled")}}{{i18n "island_lottery.cancelled"}}
            {{else}}{{i18n "island_lottery.drawing"}}{{/if}}
          </span>
        </div>

        {{#if this.lottery.prize}}<p>{{this.lottery.prize}}</p>{{/if}}
        <p>
          {{i18n "island_lottery.closes_relative"}}：
          <DRelativeDate @date={{this.lottery.closes_at}} />
          · {{i18n
            "island_lottery.eligibility"
            min=this.lottery.min_trust_level
            max=this.lottery.max_trust_level
          }}
          · {{this.lottery.winners_count}} 人中奖
        </p>

        {{#if (eq this.lottery.status "drawn")}}
          <p>{{i18n "island_lottery.participant_count" count=this.lottery.participant_count}}</p>
          <h4>{{i18n "island_lottery.winners"}}</h4>
          {{#if this.lottery.winner_users.length}}
            <ol>
              {{#each this.lottery.winner_users as |winner|}}
                <li><a href="/u/{{winner.username}}">@{{winner.username}}</a></li>
              {{/each}}
            </ol>
          {{else}}
            <p>{{i18n "island_lottery.no_winners"}}</p>
          {{/if}}
        {{else}}
          <small>{{i18n "island_lottery.commitment"}}：{{this.lottery.seed_digest}}</small>
        {{/if}}
      </section>
    {{/if}}
  </template>
}
