# PSN Compare — Design

**Date:** 2026-07-06
**Status:** Approved

## Purpose

A Rails app that gathers trophy and purchase data from multiple PSN accounts
via the [psn-client-ruby](https://github.com/MattyJacques/psn-client-ruby) gem,
compares the accounts, and tracks progress toward re-earning every trophy ever
earned on any account using one designated "current" account.

Replaces both `psn_trophy_dashboard` and `psn_purchases`, which remain as
reference material.

## Stack

- Rails 8.1, Ruby 3.4.9, SQLite
- Hotwire (Turbo + Stimulus), Tailwind CSS, Propshaft, importmap
- Solid Queue (jobs), Solid Cache, Solid Cable
- RSpec + FactoryBot, RuboCop
- `psn-client-ruby` as a path/git dependency until published to rubygems

## Architecture

Sync-to-local-DB. Background jobs pull each account's trophies, entitlements,
and transactions through the gem into normalized tables; every view queries
the local database only. No page ever calls the PSN API.

Chosen over live-API-with-caching because the core views are cross-account
joins that need all data in SQL, PSN rate-limits aggressively, and full
library fetches are too slow for page loads.

### Authentication

Every account is fully authenticated (purchases/entitlements are only
available to the logged-in account). Adding an account takes an NPSSO token
once; the gem exchanges it and the app persists the resulting **refresh
token** (~2-month lifetime, rotates on use) with Active Record Encryption.
After every sync the stored token is updated with the rotated value. When a
token expires, the account is flagged `needs_reauth` and the UI prompts for a
fresh NPSSO.

## Data Model

| Table | Purpose | Key columns |
|---|---|---|
| `accounts` | One per PSN account | `label`, `online_id`, `psn_account_id`, `refresh_token` (encrypted), `current` (exactly one true), `trophy_level`, earned-count caches, `last_synced_at`, `needs_reauth` |
| `games` | One per trophy set | `np_communication_id` (unique), `name`, `platform`, `icon_url`, total counts per trophy type |
| `trophies` | Trophy definitions | `game_id`, `psn_trophy_id` (index within set), `trophy_type`, `name`, `detail`, `hidden`, `icon_url`; unique on (`game_id`, `psn_trophy_id`) |
| `account_games` | Account × game progress | `progress`, earned counts per type, `last_played_at`; unique on (`account_id`, `game_id`) |
| `account_trophies` | Account × trophy earned state | `earned`, `earned_at`; unique on (`account_id`, `trophy_id`) |
| `entitlements` | Ownership ledger per account | `entitlement_id`, `product_id`, `name`, `kind` (game/DLC/other), `acquired_at`, `platform`; unique on (`account_id`, `entitlement_id`) |
| `transactions` | Monetary history per account | `psn_transaction_id`, `kind` (purchase/refund/wallet), `amount_minor`, `currency`, `occurred_at`, `description`; unique on (`account_id`, `psn_transaction_id`) |
| `sync_runs` | Sync audit trail | `account_id`, `kind` (trophies/entitlements/transactions), `status`, item counts, `error_message`, timestamps |

Amounts are stored as integer minor units plus a currency code, exactly as
the gem returns them.

## Sync Pipeline

- `SyncAccountJob` fans out one job per data kind (trophies, entitlements,
  transactions), each recorded as a `sync_run`.
- Trophy sync: `trophies.titles` upserts `games` + `account_games`; for each
  title, `trophies.earned` upserts `trophies` + `account_trophies`.
- Entitlement/transaction syncs drain the gem's lazy enumerators and upsert
  on the natural keys above, so re-syncs are idempotent.
- `PSN::RateLimitError` → job reschedules itself after `retry_after`.
- `PSN::AuthenticationError` → set `needs_reauth`, mark the sync run failed,
  surface in the UI. Never fail silently.
- Recurring Solid Queue schedule re-syncs all accounts daily; each account
  also has a manual "Sync now" button.

## Views

All server-rendered; Turbo Streams update sync status live.

- **Dashboard** — account cards: trophy level, counts, total spend, last
  sync, sync/reauth warnings.
- **Ownership matrix** — titles × accounts grid from `entitlements`, grouped
  by `product_id` when present and by case-insensitive name otherwise;
  games-only / include-DLC filter; titles owned by 2+
  accounts highlighted as duplicate purchases with acquisition dates.
- **Spend analysis** — per-account totals and per-year breakdown (purchases
  minus refunds), wallet-funding vs spend split, biggest single purchases.
  No currency conversion: totals group by currency if more than one appears.
- **Trophy comparison** — per-game table across accounts (progress %, earned
  counts by type, last played) plus an overall side-by-side summary. Only
  games at least one account has played appear.
- **Re-earn tracker** — headline feature. **Baseline** = every
  (game, trophy) pair where *any* account has `earned = true`. **Progress** =
  the subset the `current` account has earned. Matching is by exact trophy
  set (`np_communication_id`) only — a PS5 remaster does not count against a
  PS3 original. Shows overall completion %, per-game progress bars, and a
  per-trophy checklist with who originally earned each trophy and when the
  current account re-earned it. Fully re-earned games are badged and sorted
  separately.

All comparison logic is SQL over `account_trophies` / `entitlements` /
`transactions`.

## Error Handling

- Sync failures land in `sync_runs.error_message` and render on the
  dashboard.
- `needs_reauth` accounts show a "re-enter NPSSO" prompt.
- Rate limits retry automatically via `retry_after`.
- Pages never block on PSN availability.

## Testing

- RSpec + FactoryBot; no live PSN calls in tests.
- Unit specs for sync/upsert services with the gem client stubbed using
  fixtures shaped like the gem's model objects.
- Model specs for the re-earn and spend queries.
- Request specs for controllers; one system spec for the add-account flow.

## Out of Scope (v1)

- Cross-platform trophy matching (PS3 ↔ PS5 versions of the same game) —
  possible later via manual trophy-set linking.
- Cross-currency conversion in spend analysis.
- Multi-user support; this is a single-user local app.
