# PSN Compare

Compares trophies and purchases across multiple PSN accounts and tracks
re-earning every trophy ever earned on a designated current account.
Built on [psn-client-ruby](https://github.com/MattyJacques/psn-client-ruby).

## Setup

    bundle install
    bin/rails db:prepare

## Running

    bin/dev          # web + tailwind; background jobs run asynchronously in dev

Add each PSN account on the Accounts page with an NPSSO token (sign in at
playstation.com, then visit https://ca.account.sony.com/api/v1/ssocookie).
The token is used once; the app stores an encrypted rotating refresh token.
Then hit "Sync now" — trophies, entitlements, and transactions sync in the
background, and re-sync daily.

## Tests

    bundle exec rspec

Spec: docs/superpowers/specs/2026-07-06-psn-compare-design.md
