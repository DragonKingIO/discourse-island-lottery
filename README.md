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

## CI

The repository contains the official reusable Discourse plugin workflow. Push it to GitHub and enable Actions; no standalone build server is required.

## Production installation

Add the repository URL to `hooks.after_code` in `containers/app.yml`, then rebuild the Discourse container. Do not install an untested working tree directly on production.
