# Discourse Island Lottery

Reply-based, auditable lotteries for Discourse.

## MVP behavior

- One lottery per topic.
- The topic creator or staff can create it.
- A closing time, winner count, prize and TL0–TL4 eligibility range are configurable.
- All trust levels are eligible by default.
- Each eligible user gets one entry regardless of reply count.
- The topic creator, system account, staged, inactive and suspended users are excluded.
- Deleted, hidden and late replies are excluded.
- A committed server seed produces deterministic winners and is revealed after drawing.
- The scheduled draw is idempotent and posts the result in the original topic.
- The first post stores the configuration as an editable `[island-lottery]` block. It is
  rendered as a card in the post body, while the creator can edit it for one hour and
  staff can edit an open lottery at any time.

## Post marker

The composer inserts a readable block into the first post:

```text
[island-lottery]
prize: 一份小岛纪念品
closes_at: 2026-08-06T12:00:00Z
winners_count: 2
min_trust_level: 0
max_trust_level: 4
[/island-lottery]
```

It is parsed as Discourse BBCode and replaced by the lottery card when reading the
topic. The `修改抽奖信息` button updates both the lottery record and this block.

## CI

The repository contains the official reusable Discourse plugin workflow. Push it to GitHub and enable Actions; no standalone build server is required.

## Production installation

Add the repository URL to `hooks.after_code` in `containers/app.yml`, then rebuild the Discourse container. Do not install an untested working tree directly on production.
