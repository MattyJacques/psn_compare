# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

```sh
bundle install && bin/rails db:prepare   # setup
bin/dev                                  # run: web + tailwind watch (jobs run async in-process in dev)
bundle exec rspec                        # all tests
bundle exec rspec spec/queries/reearn_backlog_spec.rb        # one file
bundle exec rspec spec/queries/reearn_backlog_spec.rb:12     # one example
bin/rubocop                              # lint (rubocop-rails-omakase)
bin/brakeman --no-pager && bin/bundler-audit && bin/importmap audit   # security scans (run in CI)
```

The `psn-client-ruby` gem is a **path dependency at `../psn-client-ruby`** — that sibling checkout must exist or bundler fails.

## What this app is

Compares trophies and purchases across multiple PSN accounts, and tracks re-earning every trophy ever earned on a designated **current account** (exactly one `Account` has `current: true`; see `Account.current` / `#make_current!`).

Design spec: `docs/superpowers/specs/2026-07-06-psn-compare-design.md` (data model, sync pipeline, views). Plans live in `docs/superpowers/plans/`.

## Architecture

Rails 8.1 / Ruby 3.4.9 / SQLite / Hotwire / Tailwind v4 / Solid Queue-Cache-Cable. Server-rendered views only.

**Sync-to-local-DB is the core rule: no page ever calls the PSN API.** Background jobs pull each account's data through the gem into normalized tables; every view queries SQLite only. This is deliberate (cross-account SQL joins, aggressive PSN rate limits) — don't add live API calls to request paths.

Layers, from write side to read side:

- **`app/services/sync/`** — `Trophies`, `Entitlements`, `Transactions`; one class per data kind, `.call(account)` returns an item count. Each upserts on natural keys (`np_communication_id`, `(account_id, entitlement_id)`, etc.) so re-syncs are idempotent.
- **`app/jobs/`** — `SyncAllAccountsJob` (daily 6am via `config/recurring.yml`) → `SyncAccountJob` fans out → `SyncJob.perform(account, kind)` runs the matching service and records a `SyncRun` row. Errors land in the `sync_runs` record, not raised: `PSN::RateLimitError` reschedules itself after `retry_after`; `PSN::Error` marks the run failed; the dashboard renders run status.
- **`app/queries/`** — read-model objects (`ReearnBacklog`, `OwnershipMatrix`, `DashboardStats`, …) with a `.call` class method returning `Data.define` row structs. Controllers are thin: they call one query object and render.
- **`app/models/`** — `games`/`trophies` are shared definitions; `account_games`/`account_trophies` hold per-account state; money is integer minor units + currency code on `psn_transactions`.

**PSN auth**: adding an account takes an NPSSO token once; the app persists only an encrypted rotating refresh token. `Account#with_client` is the single gateway to the gem — it persists the rotated token even when the block raises, and flags `needs_reauth: true` on `PSN::AuthenticationError`. Always go through it; never construct `PSN::Client` elsewhere in app code.

## Testing conventions

- All factories live in the single `spec/factories.rb`.
- Stub the PSN client with `stub_psn_client` from `spec/support/psn_stubs.rb`, then stub explicit `instance_double`s on it — `receive_message_chain` is banned.
- Canned PSN API payloads live in `spec/support/psn_fixtures.rb`.

## UI conventions

Dark-theme design tokens are defined in `@theme` in `app/assets/tailwind/application.css` (`--color-page`, `--color-ink`, `--color-mute`, trophy-grade colors `plat`/`gold-t`/`silver-t`/`bronze-t`, etc.). Use these token classes (`text-mute`, `border-line`, …), never raw hex values. Shared formatting/class helpers (dates, initials, grade borders, filter chips) are in `app/helpers/design_helper.rb`.
