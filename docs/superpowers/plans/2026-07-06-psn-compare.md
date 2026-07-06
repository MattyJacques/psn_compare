# PSN Compare Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A Rails app that syncs trophies, entitlements, and transactions for multiple PSN accounts via the psn-client-ruby gem, compares them, and tracks re-earning every trophy ever earned on a designated current account.

**Architecture:** Sync-to-local-DB. Solid Queue jobs pull each account's data through the gem into normalized SQLite tables; all views are SQL over local data — no page ever calls the PSN API. One account is flagged `current` and drives the re-earn tracker.

**Tech Stack:** Rails 8.1, Ruby 3.4.9, SQLite, Hotwire + Tailwind, Solid Queue, RSpec + FactoryBot, `psn-client-ruby` (path dependency at `../psn-client-ruby`).

**Spec:** `docs/superpowers/specs/2026-07-06-psn-compare-design.md`

## Global Constraints

- Project root: `/home/matty/development/psn_compare` (git repo already exists with the spec committed). All paths below are relative to it.
- Ruby `3.4.9`, Rails `~> 8.1.3`, gem `psn-client-ruby` via `path: "../psn-client-ruby"`, required as `require "psn_client"`.
- Tests: RSpec + FactoryBot. **No live PSN calls in any test** — always stub `PSN::Client.new` and build gem `Data` objects (`PSN::TrophyTitle`, `PSN::Trophy`, `PSN::Entitlement`, `PSN::Transaction`, `PSN::Profile`, `PSN::TrophySummary`) as fixtures.
- Money is stored as integer minor units (`amount_minor`) + `currency` code. Never floats.
- Exactly one account may have `current = true`.
- `refresh_token` is encrypted with Active Record Encryption and re-persisted after every client use (the gem rotates it).
- Trophy identity is exact trophy set only: `(np_communication_id, trophyId)`. No cross-platform matching.
- Run tests with `bundle exec rspec <path>`; full suite must pass before each commit.

## Gem API cheat sheet (verified against ../psn-client-ruby source)

```ruby
client = PSN::Client.new(npsso: "...")            # or (refresh_token: "...") — exactly one
client.refresh_token                               # rotates; persist after use
client.access_token                                # forces authentication now

client.profiles.find                               # PSN::Profile(online_id, account_id, trophy_summary, ...)
client.trophies.titles                             # lazy enum of PSN::TrophyTitle(name, np_communication_id,
                                                   #   np_service_name, platform, progress,
                                                   #   earned_counts: {bronze:,silver:,gold:,platinum:},
                                                   #   defined_counts: {...}, raw)
client.trophies.summary                            # PSN::TrophySummary(level, progress, tier, earned_counts, raw)
client.trophies.earned(np_communication_id:, platform:)
                                                   # lazy enum of PSN::Trophy(id, name, detail, grade(:bronze..),
                                                   #   hidden, rarity, earned, earned_at, raw)
client.store.entitlements                          # lazy enum of PSN::Entitlement(id, name, type, platform,
                                                   #   acquired_at, raw)
client.store.transactions                          # lazy enum of PSN::Transaction(transaction_id, date,
                                                   #   description, amount, currency, payment_method, type, raw)
```

Errors (all subclass `PSN::Error`, `#response` available): `PSN::AuthenticationError`, `PSN::PrivacyError`, `PSN::NotFoundError`, `PSN::RateLimitError` (`#retry_after` seconds or nil), `PSN::APIError`. Useful raw keys: `TrophyTitle#raw["trophyTitleIconUrl"]`, `TrophyTitle#raw["lastUpdatedDateTime"]`, `Trophy#raw["trophyIconUrl"]`, `Entitlement#raw["product_id"]`.

---

### Task 1: Rails app scaffold, gems, RSpec, encryption keys

**Files:**
- Create: entire Rails skeleton via `rails new`
- Modify: `Gemfile`
- Create: `config/initializers/active_record_encryption.rb`
- Create: `spec/rails_helper.rb` (generated), `spec/support/factory_bot.rb`

**Interfaces:**
- Produces: bootable Rails app where `PSN::Client` is loadable and `bundle exec rspec` runs green.

- [ ] **Step 1: Generate the app into the existing repo**

```bash
cd /home/matty/development/psn_compare
rails _8.1.3_ new . --css=tailwind --skip-test --skip-kamal --skip-docker --skip-jbuilder
```

If `rails _8.1.3_` is unavailable, `gem install rails -v 8.1.3` first. Answer `n` to any overwrite prompt for existing files (only `docs/` exists; there should be no conflicts).

- [ ] **Step 2: Add gems**

In `Gemfile`, add at the bottom:

```ruby
gem "psn-client-ruby", path: "../psn-client-ruby"
```

and inside the existing `group :development, :test do` block:

```ruby
  gem "rspec-rails"
  gem "factory_bot_rails"
```

Run: `bundle install`

- [ ] **Step 3: Install RSpec and FactoryBot config**

```bash
bin/rails generate rspec:install
```

Create `spec/support/factory_bot.rb`:

```ruby
RSpec.configure do |config|
  config.include FactoryBot::Syntax::Methods
end
```

In `spec/rails_helper.rb`, uncomment the support-directory loader line:

```ruby
Rails.root.glob("spec/support/**/*.rb").sort_by(&:to_s).each { |f| require f }
```

- [ ] **Step 4: Configure Active Record Encryption keys**

Create `config/initializers/active_record_encryption.rb`:

```ruby
# Single-user local app: derive the encryption keys from secret_key_base
# instead of managing separate credentials.
Rails.application.config.active_record.encryption.tap do |enc|
  enc.primary_key = Rails.application.secret_key_base[0, 32]
  enc.deterministic_key = Rails.application.secret_key_base[32, 32]
  enc.key_derivation_salt = Rails.application.secret_key_base[64, 32]
end
```

- [ ] **Step 5: Verify boot, gem load, and test run**

```bash
bin/rails runner 'require "psn_client"; puts PSN::Client'
bundle exec rspec
```

Expected: first prints `PSN::Client`; second reports `0 examples, 0 failures`.

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "chore: scaffold Rails 8.1 app with psn-client-ruby, RSpec, AR encryption"
```

---

### Task 2: Core trophy schema and models

**Files:**
- Create: `db/migrate/<ts>_create_core_trophy_tables.rb`
- Create: `app/models/account.rb`, `app/models/game.rb`, `app/models/trophy.rb`, `app/models/account_game.rb`, `app/models/account_trophy.rb`
- Create: `spec/factories.rb`
- Test: `spec/models/account_spec.rb`

**Interfaces:**
- Produces: models `Account` (with `encrypts :refresh_token`, `Account.current` → the single `current: true` record or nil, `#make_current!`), `Game`, `Trophy`, `AccountGame`, `AccountTrophy` with the associations and unique indexes below. Factories `:account`, `:game`, `:trophy`, `:account_game`, `:account_trophy`.

- [ ] **Step 1: Write the failing model spec**

`spec/models/account_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe Account do
  it "requires a unique label" do
    create(:account, label: "main")
    expect(build(:account, label: "main")).not_to be_valid
  end

  it "encrypts the refresh token" do
    account = create(:account, refresh_token: "secret-token")
    raw = ActiveRecord::Base.connection.select_value(
      "SELECT refresh_token FROM accounts WHERE id = #{account.id}"
    )
    expect(raw).not_to include("secret-token")
    expect(account.reload.refresh_token).to eq("secret-token")
  end

  describe ".current / #make_current!" do
    it "moves the current flag atomically between accounts" do
      a = create(:account, current: true)
      b = create(:account)
      b.make_current!
      expect(Account.current).to eq(b)
      expect(a.reload.current).to be(false)
    end

    it "returns nil when no account is current" do
      expect(Account.current).to be_nil
    end
  end
end
```

- [ ] **Step 2: Run to verify failure**

Run: `bundle exec rspec spec/models/account_spec.rb`
Expected: FAIL (uninitialized constant Account / missing table).

- [ ] **Step 3: Write the migration**

`db/migrate/<ts>_create_core_trophy_tables.rb` (generate the timestamp with `bin/rails generate migration CreateCoreTrophyTables` and replace the body):

```ruby
class CreateCoreTrophyTables < ActiveRecord::Migration[8.1]
  def change
    create_table :accounts do |t|
      t.string :label, null: false, index: { unique: true }
      t.string :online_id
      t.string :psn_account_id, index: { unique: true }
      t.text :refresh_token
      t.boolean :current, null: false, default: false
      t.boolean :needs_reauth, null: false, default: false
      t.integer :trophy_level
      t.integer :earned_bronze, null: false, default: 0
      t.integer :earned_silver, null: false, default: 0
      t.integer :earned_gold, null: false, default: 0
      t.integer :earned_platinum, null: false, default: 0
      t.datetime :last_synced_at
      t.timestamps
    end

    create_table :games do |t|
      t.string :np_communication_id, null: false, index: { unique: true }
      t.string :name, null: false
      t.string :platform
      t.string :icon_url
      t.integer :total_bronze, null: false, default: 0
      t.integer :total_silver, null: false, default: 0
      t.integer :total_gold, null: false, default: 0
      t.integer :total_platinum, null: false, default: 0
      t.timestamps
    end

    create_table :trophies do |t|
      t.references :game, null: false, foreign_key: true
      t.integer :psn_trophy_id, null: false
      t.string :trophy_type, null: false
      t.string :name
      t.text :detail
      t.boolean :hidden, null: false, default: false
      t.string :icon_url
      t.timestamps
      t.index [:game_id, :psn_trophy_id], unique: true
    end

    create_table :account_games do |t|
      t.references :account, null: false, foreign_key: true
      t.references :game, null: false, foreign_key: true
      t.integer :progress, null: false, default: 0
      t.integer :earned_bronze, null: false, default: 0
      t.integer :earned_silver, null: false, default: 0
      t.integer :earned_gold, null: false, default: 0
      t.integer :earned_platinum, null: false, default: 0
      t.datetime :last_played_at
      t.timestamps
      t.index [:account_id, :game_id], unique: true
    end

    create_table :account_trophies do |t|
      t.references :account, null: false, foreign_key: true
      t.references :trophy, null: false, foreign_key: true
      t.boolean :earned, null: false, default: false
      t.datetime :earned_at
      t.timestamps
      t.index [:account_id, :trophy_id], unique: true
    end
  end
end
```

Run: `bin/rails db:migrate`

- [ ] **Step 4: Write the models**

`app/models/account.rb`:

```ruby
class Account < ApplicationRecord
  encrypts :refresh_token

  has_many :account_games, dependent: :destroy
  has_many :account_trophies, dependent: :destroy
  has_many :games, through: :account_games

  validates :label, presence: true, uniqueness: true

  def self.current = find_by(current: true)

  def make_current!
    transaction do
      Account.where.not(id:).update_all(current: false)
      update!(current: true)
    end
  end
end
```

`app/models/game.rb`:

```ruby
class Game < ApplicationRecord
  has_many :trophies, dependent: :destroy
  has_many :account_games, dependent: :destroy

  validates :np_communication_id, presence: true, uniqueness: true
  validates :name, presence: true
end
```

`app/models/trophy.rb`:

```ruby
class Trophy < ApplicationRecord
  belongs_to :game
  has_many :account_trophies, dependent: :destroy

  validates :psn_trophy_id, presence: true, uniqueness: { scope: :game_id }
end
```

`app/models/account_game.rb`:

```ruby
class AccountGame < ApplicationRecord
  belongs_to :account
  belongs_to :game

  validates :game_id, uniqueness: { scope: :account_id }
end
```

`app/models/account_trophy.rb`:

```ruby
class AccountTrophy < ApplicationRecord
  belongs_to :account
  belongs_to :trophy

  validates :trophy_id, uniqueness: { scope: :account_id }
end
```

- [ ] **Step 5: Write the factories**

`spec/factories.rb`:

```ruby
FactoryBot.define do
  factory :account do
    sequence(:label) { |n| "account-#{n}" }
    sequence(:online_id) { |n| "player#{n}" }
    sequence(:psn_account_id) { |n| (1_000_000 + n).to_s }
    refresh_token { "refresh-token" }
  end

  factory :game do
    sequence(:np_communication_id) { |n| format("NPWR%05d_00", n) }
    sequence(:name) { |n| "Game #{n}" }
    platform { "PS5" }
    total_bronze { 10 }
    total_silver { 5 }
    total_gold { 2 }
    total_platinum { 1 }
  end

  factory :trophy do
    game
    sequence(:psn_trophy_id) { |n| n }
    trophy_type { "bronze" }
    sequence(:name) { |n| "Trophy #{n}" }
  end

  factory :account_game do
    account
    game
    progress { 50 }
  end

  factory :account_trophy do
    account
    trophy
    earned { true }
    earned_at { Time.zone.local(2020, 1, 1) }
  end
end
```

- [ ] **Step 6: Run to verify pass**

Run: `bundle exec rspec spec/models/account_spec.rb`
Expected: PASS (4 examples).

- [ ] **Step 7: Commit**

```bash
git add -A
git commit -m "feat: core trophy schema and models"
```

---

### Task 3: Purchases and sync-run schema and models

**Files:**
- Create: `db/migrate/<ts>_create_purchase_and_sync_tables.rb`
- Create: `app/models/entitlement.rb`, `app/models/psn_transaction.rb`, `app/models/sync_run.rb`
- Modify: `app/models/account.rb` (associations)
- Modify: `spec/factories.rb`
- Test: `spec/models/psn_transaction_spec.rb`

**Interfaces:**
- Produces: `Entitlement` (kinds: `game`/`dlc`/`other`), `PsnTransaction` (table `psn_transactions`, kinds: `purchase`/`refund`/`wallet`; scopes `.purchases`, `.refunds`, `.wallet_funding`), `SyncRun` (kinds `trophies`/`entitlements`/`transactions`; statuses `running`/`succeeded`/`failed`/`rate_limited`; scope `.latest_per_kind`). Factories `:entitlement`, `:psn_transaction`, `:sync_run`. The model is named `PsnTransaction` (not `Transaction`) to avoid clashing with the gem's `PSN::Transaction` in specs and with mental overload of AR's `transaction`.

- [ ] **Step 1: Write the failing spec**

`spec/models/psn_transaction_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe PsnTransaction do
  it "is unique per account and PSN transaction id" do
    account = create(:account)
    create(:psn_transaction, account:, psn_transaction_id: "T1")
    expect(build(:psn_transaction, account:, psn_transaction_id: "T1")).not_to be_valid
  end

  it "filters by kind scopes" do
    account = create(:account)
    purchase = create(:psn_transaction, account:, kind: "purchase")
    refund = create(:psn_transaction, account:, kind: "refund")
    wallet = create(:psn_transaction, account:, kind: "wallet")
    expect(described_class.purchases).to eq([purchase])
    expect(described_class.refunds).to eq([refund])
    expect(described_class.wallet_funding).to eq([wallet])
  end
end
```

- [ ] **Step 2: Run to verify failure**

Run: `bundle exec rspec spec/models/psn_transaction_spec.rb`
Expected: FAIL (uninitialized constant PsnTransaction).

- [ ] **Step 3: Write the migration**

`db/migrate/<ts>_create_purchase_and_sync_tables.rb`:

```ruby
class CreatePurchaseAndSyncTables < ActiveRecord::Migration[8.1]
  def change
    create_table :entitlements do |t|
      t.references :account, null: false, foreign_key: true
      t.string :entitlement_id, null: false
      t.string :product_id
      t.string :name
      t.string :kind, null: false, default: "other"
      t.string :raw_type
      t.string :platform
      t.datetime :acquired_at
      t.timestamps
      t.index [:account_id, :entitlement_id], unique: true
      t.index :product_id
    end

    create_table :psn_transactions do |t|
      t.references :account, null: false, foreign_key: true
      t.string :psn_transaction_id, null: false
      t.string :kind, null: false, default: "purchase"
      t.integer :amount_minor
      t.string :currency
      t.datetime :occurred_at
      t.text :description
      t.string :payment_method
      t.timestamps
      t.index [:account_id, :psn_transaction_id], unique: true
    end

    create_table :sync_runs do |t|
      t.references :account, null: false, foreign_key: true
      t.string :kind, null: false
      t.string :status, null: false, default: "running"
      t.integer :items_synced, null: false, default: 0
      t.text :error_message
      t.datetime :started_at
      t.datetime :completed_at
      t.timestamps
      t.index [:account_id, :kind, :created_at]
    end
  end
end
```

Run: `bin/rails db:migrate`

- [ ] **Step 4: Write the models and associations**

`app/models/entitlement.rb`:

```ruby
class Entitlement < ApplicationRecord
  KINDS = %w[game dlc other].freeze

  belongs_to :account

  validates :entitlement_id, presence: true, uniqueness: { scope: :account_id }
  validates :kind, inclusion: { in: KINDS }

  scope :games, -> { where(kind: "game") }

  # Ownership-matrix grouping key: product when Sony provides one, name otherwise.
  def product_key = product_id.presence || name.to_s.downcase
end
```

`app/models/psn_transaction.rb`:

```ruby
class PsnTransaction < ApplicationRecord
  KINDS = %w[purchase refund wallet].freeze

  belongs_to :account

  validates :psn_transaction_id, presence: true, uniqueness: { scope: :account_id }
  validates :kind, inclusion: { in: KINDS }

  scope :purchases, -> { where(kind: "purchase") }
  scope :refunds, -> { where(kind: "refund") }
  scope :wallet_funding, -> { where(kind: "wallet") }
end
```

`app/models/sync_run.rb`:

```ruby
class SyncRun < ApplicationRecord
  KINDS = %w[trophies entitlements transactions].freeze
  STATUSES = %w[running succeeded failed rate_limited].freeze

  belongs_to :account

  validates :kind, inclusion: { in: KINDS }
  validates :status, inclusion: { in: STATUSES }

  # Newest run per kind for one account's runs.
  def self.latest_per_kind
    order(created_at: :desc).group_by(&:kind).transform_values(&:first)
  end
end
```

In `app/models/account.rb`, add to the association block:

```ruby
  has_many :entitlements, dependent: :destroy
  has_many :psn_transactions, dependent: :destroy
  has_many :sync_runs, dependent: :destroy
```

- [ ] **Step 5: Add factories**

Append inside `FactoryBot.define do` in `spec/factories.rb`:

```ruby
  factory :entitlement do
    account
    sequence(:entitlement_id) { |n| "ENT-#{n}" }
    sequence(:product_id) { |n| "EP9000-CUSA%05d_00" % n }
    sequence(:name) { |n| "Product #{n}" }
    kind { "game" }
    platform { "PS5" }
    acquired_at { Time.zone.local(2021, 6, 1) }
  end

  factory :psn_transaction do
    account
    sequence(:psn_transaction_id) { |n| "TXN-#{n}" }
    kind { "purchase" }
    amount_minor { 6999 }
    currency { "GBP" }
    occurred_at { Time.zone.local(2021, 6, 1) }
    description { "A game" }
  end

  factory :sync_run do
    account
    kind { "trophies" }
    status { "succeeded" }
    started_at { 5.minutes.ago }
    completed_at { 1.minute.ago }
  end
```

- [ ] **Step 6: Run to verify pass**

Run: `bundle exec rspec spec/models/psn_transaction_spec.rb`
Expected: PASS (2 examples). Then `bundle exec rspec` — everything green.

- [ ] **Step 7: Commit**

```bash
git add -A
git commit -m "feat: entitlement, transaction, and sync-run schema and models"
```

---

### Task 4: Account credentials — register, client access, reauth

**Files:**
- Create: `app/services/accounts/register.rb`
- Modify: `app/models/account.rb`
- Create: `spec/support/psn_stubs.rb`
- Test: `spec/services/accounts/register_spec.rb`, `spec/models/account_client_spec.rb`

**Interfaces:**
- Consumes: `Account` from Task 2.
- Produces:
  - `Accounts::Register.call(label:, npsso:)` → persisted `Account` (raises `PSN::AuthenticationError` on a bad NPSSO, `ActiveRecord::RecordInvalid` on duplicate label). First registered account becomes `current`.
  - `Account#with_client { |client| ... }` → yields a `PSN::Client` built from the stored refresh token; afterwards persists the rotated `client.refresh_token`; on `PSN::AuthenticationError` sets `needs_reauth: true` and re-raises. Returns the block's value.
  - `Account#reauthenticate!(npsso)` → replaces the refresh token, clears `needs_reauth`.
  - Spec helper `stub_psn_client(refresh_token: "rotated-token")` → an `instance_double(PSN::Client)` already wired into `PSN::Client.new`.

- [ ] **Step 1: Write the spec support helper**

`spec/support/psn_stubs.rb`:

```ruby
module PsnStubs
  # Returns an instance_double(PSN::Client) that PSN::Client.new will return.
  # Stub resources on it per-test: allow(client).to receive_message_chain(...)
  # is banned — stub explicit doubles instead.
  def stub_psn_client(refresh_token: "rotated-token")
    client = instance_double(PSN::Client, refresh_token: refresh_token)
    allow(PSN::Client).to receive(:new).and_return(client)
    client
  end
end

RSpec.configure { |c| c.include PsnStubs }
```

- [ ] **Step 2: Write the failing specs**

`spec/services/accounts/register_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe Accounts::Register do
  let(:profile) do
    PSN::Profile.new(online_id: "matty", account_id: "123456789", avatar_url: nil,
                     plus: true, about_me: nil, languages: nil, verified: false,
                     trophy_summary: PSN::TrophySummary.new(level: 420, progress: 50, tier: nil,
                                                            earned_counts: { bronze: 100, silver: 50,
                                                                             gold: 20, platinum: 5 },
                                                            raw: {}),
                     online: false, platform: nil, last_online_at: nil, raw: {})
  end

  before do
    client = stub_psn_client(refresh_token: "fresh-refresh-token")
    profiles = instance_double(PSN::Resources::Profiles, find: profile)
    allow(client).to receive(:profiles).and_return(profiles)
  end

  it "creates an account from an NPSSO token" do
    account = described_class.call(label: "Main", npsso: "npsso-value")
    expect(PSN::Client).to have_received(:new).with(npsso: "npsso-value")
    expect(account).to have_attributes(label: "Main", online_id: "matty",
                                       psn_account_id: "123456789", trophy_level: 420,
                                       refresh_token: "fresh-refresh-token")
  end

  it "makes the first account current, but not later ones" do
    first = described_class.call(label: "One", npsso: "n")
    second = described_class.call(label: "Two", npsso: "n")
    expect(first.reload).to be_current
    expect(second).not_to be_current
  end
end
```

`spec/models/account_client_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe Account, "#with_client" do
  let(:account) { create(:account, refresh_token: "old-token") }

  it "yields a client built from the stored refresh token and persists rotation" do
    client = stub_psn_client(refresh_token: "new-token")
    result = account.with_client { |c| expect(c).to be(client); :done }
    expect(PSN::Client).to have_received(:new).with(refresh_token: "old-token")
    expect(result).to eq(:done)
    expect(account.reload.refresh_token).to eq("new-token")
  end

  it "flags needs_reauth and re-raises on authentication failure" do
    stub_psn_client
    expect {
      account.with_client { raise PSN::AuthenticationError, "expired" }
    }.to raise_error(PSN::AuthenticationError)
    expect(account.reload.needs_reauth).to be(true)
  end

  it "reauthenticate! stores a new token and clears the flag" do
    account.update!(needs_reauth: true)
    client = stub_psn_client(refresh_token: "brand-new")
    allow(client).to receive(:access_token).and_return("jwt")
    account.reauthenticate!("fresh-npsso")
    expect(PSN::Client).to have_received(:new).with(npsso: "fresh-npsso")
    expect(account.reload).to have_attributes(refresh_token: "brand-new", needs_reauth: false)
  end
end
```

- [ ] **Step 3: Run to verify failure**

Run: `bundle exec rspec spec/services spec/models/account_client_spec.rb`
Expected: FAIL (uninitialized constant Accounts::Register; undefined method with_client).

- [ ] **Step 4: Implement**

`app/services/accounts/register.rb`:

```ruby
module Accounts
  class Register
    def self.call(label:, npsso:)
      client = PSN::Client.new(npsso: npsso)
      profile = client.profiles.find
      Account.create!(
        label: label,
        online_id: profile.online_id,
        psn_account_id: profile.account_id,
        trophy_level: profile.trophy_summary&.level,
        refresh_token: client.refresh_token,
        current: !Account.exists?(current: true)
      )
    end
  end
end
```

Add to `app/models/account.rb`:

```ruby
  # Yields an authenticated PSN client. The gem rotates the refresh token on
  # use, so persist whatever it ends up holding — even if the block raised.
  def with_client
    client = PSN::Client.new(refresh_token: refresh_token)
    yield client
  rescue PSN::AuthenticationError
    update!(needs_reauth: true)
    raise
  ensure
    if client&.refresh_token.present? && client.refresh_token != refresh_token
      update!(refresh_token: client.refresh_token)
    end
  end

  def reauthenticate!(npsso)
    client = PSN::Client.new(npsso: npsso)
    client.access_token # force the exchange now so bad tokens fail here
    update!(refresh_token: client.refresh_token, needs_reauth: false)
  end
```

- [ ] **Step 5: Run to verify pass**

Run: `bundle exec rspec spec/services spec/models`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "feat: account registration, client access with token rotation, reauth"
```

---

### Task 5: Trophy sync service

**Files:**
- Create: `app/services/sync/trophies.rb`
- Create: `spec/support/psn_fixtures.rb`
- Test: `spec/services/sync/trophies_spec.rb`

**Interfaces:**
- Consumes: `Account#with_client` (Task 4); models (Task 2); `stub_psn_client` (Task 4).
- Produces: `Sync::Trophies.call(account)` → Integer count of games synced. Upserts `games`, `trophies`, `account_games`, `account_trophies`; updates the account's `trophy_level`, earned-count caches, and `last_synced_at`. Skips the per-trophy fetch for a game when its `lastUpdatedDateTime` and progress are unchanged. Also produces fixture helpers `psn_trophy_title(...)`, `psn_trophy(...)` used by later tasks.

- [ ] **Step 1: Write fixture helpers**

`spec/support/psn_fixtures.rb`:

```ruby
# Builders for the gem's Data objects so service specs never touch the API.
module PsnFixtures
  def psn_trophy_title(np_communication_id: "NPWR11111_00", name: "Astro Bot", platform: "PS5",
                       progress: 40, earned: { bronze: 4, silver: 1, gold: 0, platinum: 0 },
                       defined: { bronze: 20, silver: 10, gold: 5, platinum: 1 },
                       last_updated: "2024-05-01T10:00:00Z")
    PSN::TrophyTitle.new(
      name:, np_communication_id:, np_service_name: "trophy2", platform:, progress:,
      earned_counts: earned, defined_counts: defined,
      raw: { "trophyTitleIconUrl" => "https://img.example/#{np_communication_id}.png",
             "lastUpdatedDateTime" => last_updated }
    )
  end

  def psn_trophy(id:, name: "Trophy #{id}", grade: :bronze, earned: false, earned_at: nil,
                 detail: "Do the thing", hidden: false)
    PSN::Trophy.new(id:, name:, detail:, grade:, hidden:, rarity: 12.5,
                    earned:, earned_at:,
                    raw: { "trophyIconUrl" => "https://img.example/t#{id}.png" })
  end

  def psn_trophy_summary(level: 300, counts: { bronze: 10, silver: 5, gold: 2, platinum: 1 })
    PSN::TrophySummary.new(level:, progress: 10, tier: 3, earned_counts: counts, raw: {})
  end
end

RSpec.configure { |c| c.include PsnFixtures }
```

- [ ] **Step 2: Write the failing spec**

`spec/services/sync/trophies_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe Sync::Trophies do
  let(:account) { create(:account) }
  let(:client) { stub_psn_client }
  let(:title) { psn_trophy_title }
  let(:trophies_resource) { instance_double(PSN::Resources::Trophies) }

  before do
    allow(client).to receive(:trophies).and_return(trophies_resource)
    allow(trophies_resource).to receive(:titles).and_return([title].lazy)
    allow(trophies_resource).to receive(:summary).and_return(psn_trophy_summary)
    allow(trophies_resource).to receive(:earned)
      .with(np_communication_id: "NPWR11111_00", platform: "PS5")
      .and_return([
        psn_trophy(id: 0, grade: :platinum),
        psn_trophy(id: 1, earned: true, earned_at: Time.utc(2024, 4, 30, 12))
      ].lazy)
  end

  it "creates the game, its trophies, and the account's earned state" do
    expect(described_class.call(account)).to eq(1)

    game = Game.find_by!(np_communication_id: "NPWR11111_00")
    expect(game).to have_attributes(name: "Astro Bot", platform: "PS5", total_bronze: 20)
    expect(game.trophies.count).to eq(2)

    account_game = account.account_games.find_by!(game:)
    expect(account_game).to have_attributes(progress: 40, earned_bronze: 4)

    earned = account.account_trophies.joins(:trophy).find_by!(trophies: { psn_trophy_id: 1 })
    expect(earned).to have_attributes(earned: true, earned_at: Time.utc(2024, 4, 30, 12))
    unearned = account.account_trophies.joins(:trophy).find_by!(trophies: { psn_trophy_id: 0 })
    expect(unearned.earned).to be(false)
  end

  it "updates the account summary caches" do
    described_class.call(account)
    expect(account.reload).to have_attributes(trophy_level: 300, earned_platinum: 1)
    expect(account.last_synced_at).to be_present
  end

  it "is idempotent and skips unchanged games on re-sync" do
    described_class.call(account)
    described_class.call(account)
    expect(trophies_resource).to have_received(:earned).once
    expect(Game.count).to eq(1)
    expect(account.account_trophies.count).to eq(2)
  end
end
```

- [ ] **Step 3: Run to verify failure**

Run: `bundle exec rspec spec/services/sync/trophies_spec.rb`
Expected: FAIL (uninitialized constant Sync::Trophies).

- [ ] **Step 4: Implement**

`app/services/sync/trophies.rb`:

```ruby
module Sync
  # Pulls every trophy title for the account, then the per-trophy earned
  # state for titles that changed since the last sync.
  class Trophies
    def self.call(account) = new(account).call

    def initialize(account)
      @account = account
    end

    def call
      count = 0
      @account.with_client do |client|
        client.trophies.titles.each do |title|
          sync_title(client, title)
          count += 1
        end
        update_account_summary(client)
      end
      count
    end

    private

    def sync_title(client, title)
      game = upsert_game(title)
      account_game = @account.account_games.find_or_initialize_by(game:)
      last_played = Time.iso8601(title.raw["lastUpdatedDateTime"]) if title.raw["lastUpdatedDateTime"]
      return if unchanged?(account_game, title, last_played)

      account_game.update!(progress: title.progress, last_played_at: last_played,
                           **counts(:earned, title.earned_counts))
      sync_trophies(client, game, title)
    end

    def unchanged?(account_game, title, last_played)
      account_game.persisted? && account_game.progress == title.progress &&
        account_game.last_played_at == last_played
    end

    def upsert_game(title)
      game = Game.find_or_initialize_by(np_communication_id: title.np_communication_id)
      game.update!(name: title.name, platform: title.platform,
                   icon_url: title.raw["trophyTitleIconUrl"],
                   **counts(:total, title.defined_counts))
      game
    end

    def sync_trophies(client, game, title)
      client.trophies.earned(np_communication_id: game.np_communication_id,
                             platform: title.platform).each do |psn_trophy|
        trophy = game.trophies.find_or_initialize_by(psn_trophy_id: psn_trophy.id)
        trophy.update!(trophy_type: psn_trophy.grade.to_s, name: psn_trophy.name,
                       detail: psn_trophy.detail, hidden: psn_trophy.hidden,
                       icon_url: psn_trophy.raw["trophyIconUrl"])
        @account.account_trophies.find_or_initialize_by(trophy:)
                .update!(earned: psn_trophy.earned?, earned_at: psn_trophy.earned_at)
      end
    end

    def update_account_summary(client)
      summary = client.trophies.summary
      @account.update!(trophy_level: summary.level, last_synced_at: Time.current,
                       **counts(:earned, summary.earned_counts))
    end

    # {bronze: 1, ...} -> {earned_bronze: 1, ...} / {total_bronze: 1, ...}
    def counts(prefix, grade_counts)
      (grade_counts || {}).transform_keys { |grade| :"#{prefix}_#{grade}" }
    end
  end
end
```

- [ ] **Step 5: Run to verify pass**

Run: `bundle exec rspec spec/services/sync/trophies_spec.rb`
Expected: PASS (3 examples).

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "feat: trophy sync service with change-detection and idempotent upserts"
```

---

### Task 6: Entitlement sync service

**Files:**
- Create: `app/services/sync/entitlements.rb`
- Modify: `spec/support/psn_fixtures.rb`
- Test: `spec/services/sync/entitlements_spec.rb`

**Interfaces:**
- Consumes: `Account#with_client`, `Entitlement` model, `stub_psn_client`.
- Produces: `Sync::Entitlements.call(account)` → Integer count synced. Maps the gem's raw `type` to `kind` best-effort (the endpoint is undocumented; the mapping may need adjusting after the first live sync).

- [ ] **Step 1: Add fixture helper**

Append inside `module PsnFixtures` in `spec/support/psn_fixtures.rb`:

```ruby
  def psn_entitlement(id: "ENT-1", name: "Astro Bot", type: "ps5_native_game",
                      platform: "PS5", acquired_at: Time.utc(2024, 1, 5),
                      product_id: "EP9000-PPSA01325_00-ASTROBOT0000000")
    PSN::Entitlement.new(id:, name:, type:, platform:, acquired_at:,
                         raw: { "product_id" => product_id })
  end
```

- [ ] **Step 2: Write the failing spec**

`spec/services/sync/entitlements_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe Sync::Entitlements do
  let(:account) { create(:account) }
  let(:client) { stub_psn_client }
  let(:store) { instance_double(PSN::Resources::Store) }

  before { allow(client).to receive(:store).and_return(store) }

  it "upserts entitlements with a best-effort kind" do
    allow(store).to receive(:entitlements).and_return([
      psn_entitlement(id: "E1", type: "ps5_native_game"),
      psn_entitlement(id: "E2", name: "Astro Bot DLC", type: "unified_addon", product_id: nil),
      psn_entitlement(id: "E3", name: "Some Avatar", type: "mystery_thing", product_id: nil)
    ].lazy)

    expect(described_class.call(account)).to eq(3)
    expect(account.entitlements.find_by!(entitlement_id: "E1"))
      .to have_attributes(kind: "game", name: "Astro Bot", platform: "PS5",
                          product_id: "EP9000-PPSA01325_00-ASTROBOT0000000",
                          raw_type: "ps5_native_game")
    expect(account.entitlements.find_by!(entitlement_id: "E2").kind).to eq("dlc")
    expect(account.entitlements.find_by!(entitlement_id: "E3").kind).to eq("other")
  end

  it "is idempotent" do
    allow(store).to receive(:entitlements).and_return([psn_entitlement].lazy, [psn_entitlement].lazy)
    described_class.call(account)
    described_class.call(account)
    expect(account.entitlements.count).to eq(1)
  end
end
```

- [ ] **Step 3: Run to verify failure**

Run: `bundle exec rspec spec/services/sync/entitlements_spec.rb`
Expected: FAIL (uninitialized constant Sync::Entitlements).

- [ ] **Step 4: Implement**

`app/services/sync/entitlements.rb`:

```ruby
module Sync
  class Entitlements
    # The entitlements endpoint is undocumented; classify types defensively
    # and keep the raw type so misclassifications are diagnosable.
    GAME_TYPES = /game|full_game|title/i
    DLC_TYPES = /addon|add_on|dlc|expansion|season_pass/i

    def self.call(account) = new(account).call

    def initialize(account)
      @account = account
    end

    def call
      count = 0
      @account.with_client do |client|
        client.store.entitlements.each do |ent|
          @account.entitlements.find_or_initialize_by(entitlement_id: ent.id)
                  .update!(name: ent.name, kind: kind_for(ent.type), raw_type: ent.type,
                           platform: ent.platform, acquired_at: ent.acquired_at,
                           product_id: ent.raw["product_id"])
          count += 1
        end
      end
      count
    end

    private

    def kind_for(type)
      case type
      when GAME_TYPES then "game"
      when DLC_TYPES then "dlc"
      else "other"
      end
    end
  end
end
```

- [ ] **Step 5: Run to verify pass**

Run: `bundle exec rspec spec/services/sync/entitlements_spec.rb`
Expected: PASS (2 examples).

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "feat: entitlement sync service"
```

---

### Task 7: Transaction sync service

**Files:**
- Create: `app/services/sync/transactions.rb`
- Modify: `spec/support/psn_fixtures.rb`
- Test: `spec/services/sync/transactions_spec.rb`

**Interfaces:**
- Consumes: `Account#with_client`, `PsnTransaction` model, `stub_psn_client`.
- Produces: `Sync::Transactions.call(account)` → Integer count synced. Maps the gem's raw `type` to `kind`: refund-ish → `refund`, wallet/funding/deposit-ish → `wallet`, everything else → `purchase`.

- [ ] **Step 1: Add fixture helper**

Append inside `module PsnFixtures`:

```ruby
  def psn_transaction(transaction_id: "TXN-1", type: "PURCHASE", amount: 6999, currency: "GBP",
                      date: Time.utc(2024, 2, 1), description: "Astro Bot")
    PSN::Transaction.new(transaction_id:, date:, description:, amount:, currency:,
                         payment_method: "Visa", type:, raw: {})
  end
```

- [ ] **Step 2: Write the failing spec**

`spec/services/sync/transactions_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe Sync::Transactions do
  let(:account) { create(:account) }
  let(:client) { stub_psn_client }
  let(:store) { instance_double(PSN::Resources::Store) }

  before { allow(client).to receive(:store).and_return(store) }

  it "upserts transactions with mapped kinds" do
    allow(store).to receive(:transactions).and_return([
      psn_transaction(transaction_id: "T1", type: "PURCHASE"),
      psn_transaction(transaction_id: "T2", type: "REFUND", amount: -6999),
      psn_transaction(transaction_id: "T3", type: "WALLET_FUNDING", amount: 2500)
    ].lazy)

    expect(described_class.call(account)).to eq(3)
    expect(account.psn_transactions.find_by!(psn_transaction_id: "T1"))
      .to have_attributes(kind: "purchase", amount_minor: 6999, currency: "GBP",
                          description: "Astro Bot", occurred_at: Time.utc(2024, 2, 1))
    expect(account.psn_transactions.find_by!(psn_transaction_id: "T2").kind).to eq("refund")
    expect(account.psn_transactions.find_by!(psn_transaction_id: "T3").kind).to eq("wallet")
  end

  it "is idempotent" do
    allow(store).to receive(:transactions).and_return([psn_transaction].lazy, [psn_transaction].lazy)
    described_class.call(account)
    described_class.call(account)
    expect(account.psn_transactions.count).to eq(1)
  end
end
```

- [ ] **Step 3: Run to verify failure**

Run: `bundle exec rspec spec/services/sync/transactions_spec.rb`
Expected: FAIL (uninitialized constant Sync::Transactions).

- [ ] **Step 4: Implement**

`app/services/sync/transactions.rb`:

```ruby
module Sync
  class Transactions
    REFUND_TYPES = /refund|chargeback/i
    WALLET_TYPES = /wallet|fund|deposit|top.?up/i

    def self.call(account) = new(account).call

    def initialize(account)
      @account = account
    end

    def call
      count = 0
      @account.with_client do |client|
        client.store.transactions.each do |txn|
          next if txn.transaction_id.blank?

          @account.psn_transactions.find_or_initialize_by(psn_transaction_id: txn.transaction_id)
                  .update!(kind: kind_for(txn.type), amount_minor: txn.amount,
                           currency: txn.currency, occurred_at: txn.date,
                           description: txn.description, payment_method: txn.payment_method)
          count += 1
        end
      end
      count
    end

    private

    def kind_for(type)
      case type
      when REFUND_TYPES then "refund"
      when WALLET_TYPES then "wallet"
      else "purchase"
      end
    end
  end
end
```

- [ ] **Step 5: Run to verify pass**

Run: `bundle exec rspec spec/services/sync/transactions_spec.rb`
Expected: PASS (2 examples). Then `bundle exec rspec` — everything green.

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "feat: transaction sync service"
```

---

### Task 8: Sync jobs with rate-limit retry and recurring schedule

**Files:**
- Create: `app/jobs/sync_job.rb`, `app/jobs/sync_account_job.rb`, `app/jobs/sync_all_accounts_job.rb`
- Modify: `config/recurring.yml`
- Test: `spec/jobs/sync_job_spec.rb`

**Interfaces:**
- Consumes: `Sync::Trophies` / `Sync::Entitlements` / `Sync::Transactions` (`.call(account)` → Integer), `SyncRun`.
- Produces:
  - `SyncJob.perform_later(account, kind)` where kind ∈ `SyncRun::KINDS` — records a `SyncRun`, marks it `succeeded`/`failed`/`rate_limited`; on `PSN::RateLimitError` re-enqueues itself after `retry_after` (default 60s); never lets a `PSN::Error` bubble (the run record is the failure surface).
  - `SyncAccountJob.perform_later(account)` — fans out one `SyncJob` per kind.
  - `SyncAllAccountsJob` — enqueues `SyncAccountJob` for every account without `needs_reauth`; scheduled daily via Solid Queue recurring tasks.

- [ ] **Step 1: Write the failing spec**

`spec/jobs/sync_job_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe SyncJob do
  include ActiveJob::TestHelper

  let(:account) { create(:account) }

  it "records a succeeded run with the item count" do
    allow(Sync::Trophies).to receive(:call).with(account).and_return(42)
    described_class.perform_now(account, "trophies")
    run = account.sync_runs.sole
    expect(run).to have_attributes(kind: "trophies", status: "succeeded", items_synced: 42)
    expect(run.completed_at).to be_present
  end

  it "marks the run rate_limited and re-enqueues itself with the retry delay" do
    allow(Sync::Entitlements).to receive(:call)
      .and_raise(PSN::RateLimitError.new("slow down", retry_after: 120))
    expect {
      described_class.perform_now(account, "entitlements")
    }.to have_enqueued_job(described_class).with(account, "entitlements")
    expect(account.sync_runs.sole.status).to eq("rate_limited")
  end

  it "records failures without raising" do
    allow(Sync::Transactions).to receive(:call).and_raise(PSN::APIError, "boom")
    expect { described_class.perform_now(account, "transactions") }.not_to raise_error
    expect(account.sync_runs.sole).to have_attributes(status: "failed", error_message: "boom")
  end

  it "SyncAccountJob fans out one SyncJob per kind" do
    expect {
      SyncAccountJob.perform_now(account)
    }.to have_enqueued_job(described_class).exactly(3).times
  end

  it "SyncAllAccountsJob skips accounts needing reauth" do
    stale = create(:account, needs_reauth: true)
    expect {
      SyncAllAccountsJob.perform_now
    }.to have_enqueued_job(SyncAccountJob).with(account).exactly(:once)
    expect(SyncAccountJob).not_to have_been_enqueued.with(stale)
  end
end
```

- [ ] **Step 2: Run to verify failure**

Run: `bundle exec rspec spec/jobs/sync_job_spec.rb`
Expected: FAIL (uninitialized constant SyncJob).

- [ ] **Step 3: Implement the jobs**

`app/jobs/sync_job.rb`:

```ruby
class SyncJob < ApplicationJob
  queue_as :default

  SERVICES = {
    "trophies" => Sync::Trophies,
    "entitlements" => Sync::Entitlements,
    "transactions" => Sync::Transactions
  }.freeze

  # PSN failures land in the sync_run record (the dashboard renders them);
  # raising would just make Solid Queue retry blindly.
  def perform(account, kind)
    run = account.sync_runs.create!(kind:, status: "running", started_at: Time.current)
    count = SERVICES.fetch(kind).call(account)
    run.update!(status: "succeeded", items_synced: count, completed_at: Time.current)
  rescue PSN::RateLimitError => e
    run.update!(status: "rate_limited", error_message: e.message, completed_at: Time.current)
    self.class.set(wait: e.retry_after || 60).perform_later(account, kind)
  rescue PSN::Error => e
    run.update!(status: "failed", error_message: e.message, completed_at: Time.current)
  end
end
```

`app/jobs/sync_account_job.rb`:

```ruby
class SyncAccountJob < ApplicationJob
  queue_as :default

  def perform(account)
    SyncJob::SERVICES.each_key { |kind| SyncJob.perform_later(account, kind) }
  end
end
```

`app/jobs/sync_all_accounts_job.rb`:

```ruby
class SyncAllAccountsJob < ApplicationJob
  queue_as :default

  def perform
    Account.where(needs_reauth: false).find_each { |account| SyncAccountJob.perform_later(account) }
  end
end
```

- [ ] **Step 4: Add the recurring schedule**

In `config/recurring.yml`, add:

```yaml
production:
  sync_all_accounts:
    class: SyncAllAccountsJob
    schedule: every day at 6am

development:
  sync_all_accounts:
    class: SyncAllAccountsJob
    schedule: every day at 6am
```

- [ ] **Step 5: Run to verify pass**

Run: `bundle exec rspec spec/jobs/sync_job_spec.rb`
Expected: PASS (5 examples).

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "feat: sync jobs with rate-limit retry, per-account fan-out, daily schedule"
```

---

### Task 9: Accounts UI — add, reauth, make current, sync now

**Files:**
- Create: `app/controllers/accounts_controller.rb`
- Create: `app/views/accounts/index.html.erb`, `app/views/accounts/new.html.erb`
- Modify: `config/routes.rb`
- Test: `spec/requests/accounts_spec.rb`

**Interfaces:**
- Consumes: `Accounts::Register`, `Account#reauthenticate!`, `Account#make_current!`, `SyncAccountJob`.
- Produces: routes `accounts` (index/new/create/destroy) plus member actions `POST /accounts/:id/sync`, `PATCH /accounts/:id/make_current`, `PATCH /accounts/:id/reauth`. Later tasks link to `accounts_path`.

- [ ] **Step 1: Write the failing request spec**

`spec/requests/accounts_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe "Accounts" do
  include ActiveJob::TestHelper

  describe "POST /accounts" do
    it "registers an account from an NPSSO and redirects" do
      account = build_stubbed(:account, label: "Main")
      allow(Accounts::Register).to receive(:call)
        .with(label: "Main", npsso: "np-token").and_return(account)
      post accounts_path, params: { account: { label: "Main", npsso: "np-token" } }
      expect(response).to redirect_to(accounts_path)
    end

    it "re-renders the form when the NPSSO is rejected" do
      allow(Accounts::Register).to receive(:call).and_raise(PSN::AuthenticationError, "rejected")
      post accounts_path, params: { account: { label: "Main", npsso: "bad" } }
      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.body).to include("rejected")
    end
  end

  it "lists accounts with sync status and a reauth warning" do
    account = create(:account, label: "Main", online_id: "matty", needs_reauth: true)
    create(:sync_run, account:, kind: "trophies", status: "failed", error_message: "boom")
    get accounts_path
    expect(response.body).to include("Main", "matty", "Needs re-authentication", "boom")
  end

  it "queues a sync" do
    account = create(:account)
    expect { post sync_account_path(account) }.to have_enqueued_job(SyncAccountJob).with(account)
    expect(response).to redirect_to(accounts_path)
  end

  it "switches the current account" do
    create(:account, current: true)
    account = create(:account)
    patch make_current_account_path(account)
    expect(Account.current).to eq(account)
  end

  it "reauthenticates with a fresh NPSSO" do
    account = create(:account, needs_reauth: true)
    allow(Account).to receive(:find).and_return(account)
    allow(account).to receive(:reauthenticate!)
    patch reauth_account_path(account), params: { npsso: "fresh" }
    expect(account).to have_received(:reauthenticate!).with("fresh")
    expect(response).to redirect_to(accounts_path)
  end
end
```

- [ ] **Step 2: Run to verify failure**

Run: `bundle exec rspec spec/requests/accounts_spec.rb`
Expected: FAIL (undefined method accounts_path / routing error).

- [ ] **Step 3: Add routes**

In `config/routes.rb`, inside the `Rails.application.routes.draw do` block:

```ruby
  resources :accounts, only: %i[index new create destroy] do
    member do
      post :sync
      patch :make_current
      patch :reauth
    end
  end
```

- [ ] **Step 4: Implement the controller**

`app/controllers/accounts_controller.rb`:

```ruby
class AccountsController < ApplicationController
  def index
    @accounts = Account.order(current: :desc, label: :asc).includes(:sync_runs)
  end

  def new
    @label = nil
  end

  def create
    Accounts::Register.call(label: params.dig(:account, :label),
                            npsso: params.dig(:account, :npsso))
    redirect_to accounts_path, notice: "Account added. Use Sync now to pull its data."
  rescue PSN::AuthenticationError => e
    flash.now[:alert] = "PSN rejected the NPSSO token: #{e.message}"
    @label = params.dig(:account, :label)
    render :new, status: :unprocessable_entity
  rescue ActiveRecord::RecordInvalid => e
    flash.now[:alert] = e.message
    @label = params.dig(:account, :label)
    render :new, status: :unprocessable_entity
  end

  def destroy
    Account.find(params[:id]).destroy!
    redirect_to accounts_path, notice: "Account removed."
  end

  def sync
    SyncAccountJob.perform_later(Account.find(params[:id]))
    redirect_to accounts_path, notice: "Sync queued."
  end

  def make_current
    Account.find(params[:id]).make_current!
    redirect_to accounts_path, notice: "Current account updated."
  end

  def reauth
    Account.find(params[:id]).reauthenticate!(params[:npsso])
    redirect_to accounts_path, notice: "Re-authenticated."
  rescue PSN::AuthenticationError => e
    redirect_to accounts_path, alert: "PSN rejected the NPSSO token: #{e.message}"
  end
end
```

- [ ] **Step 5: Write the views**

`app/views/accounts/new.html.erb`:

```erb
<h1 class="text-2xl font-bold mb-4">Add PSN account</h1>

<% if flash[:alert] %>
  <p class="mb-4 rounded bg-red-100 p-3 text-red-800"><%= flash[:alert] %></p>
<% end %>

<%= form_with url: accounts_path, scope: :account, class: "max-w-md space-y-4" do |f| %>
  <div>
    <%= f.label :label, "Label (e.g. Main, Old EU account)", class: "block font-medium" %>
    <%= f.text_field :label, value: @label, required: true, class: "mt-1 w-full rounded border p-2" %>
  </div>
  <div>
    <%= f.label :npsso, "NPSSO token", class: "block font-medium" %>
    <%= f.password_field :npsso, required: true, class: "mt-1 w-full rounded border p-2" %>
    <p class="mt-1 text-sm text-gray-500">
      Sign in at playstation.com, then visit
      https://ca.account.sony.com/api/v1/ssocookie to get it. Used once, never stored.
    </p>
  </div>
  <%= f.submit "Add account", class: "rounded bg-blue-600 px-4 py-2 text-white" %>
<% end %>
```

`app/views/accounts/index.html.erb`:

```erb
<div class="mb-6 flex items-center justify-between">
  <h1 class="text-2xl font-bold">Accounts</h1>
  <%= link_to "Add account", new_account_path, class: "rounded bg-blue-600 px-4 py-2 text-white" %>
</div>

<% if flash[:notice] %>
  <p class="mb-4 rounded bg-green-100 p-3 text-green-800"><%= flash[:notice] %></p>
<% end %>
<% if flash[:alert] %>
  <p class="mb-4 rounded bg-red-100 p-3 text-red-800"><%= flash[:alert] %></p>
<% end %>

<div class="space-y-4">
  <% @accounts.each do |account| %>
    <div class="rounded border p-4">
      <div class="flex items-center justify-between">
        <div>
          <span class="text-lg font-semibold"><%= account.label %></span>
          <span class="text-gray-500"><%= account.online_id %></span>
          <% if account.current? %>
            <span class="ml-2 rounded bg-blue-100 px-2 py-0.5 text-sm text-blue-800">Current</span>
          <% end %>
          <% if account.needs_reauth? %>
            <span class="ml-2 rounded bg-red-100 px-2 py-0.5 text-sm text-red-800">Needs re-authentication</span>
          <% end %>
        </div>
        <div class="flex gap-2">
          <%= button_to "Sync now", sync_account_path(account), class: "rounded bg-gray-200 px-3 py-1" %>
          <% unless account.current? %>
            <%= button_to "Make current", make_current_account_path(account), method: :patch,
                          class: "rounded bg-gray-200 px-3 py-1" %>
          <% end %>
          <%= button_to "Remove", account_path(account), method: :delete,
                        data: { turbo_confirm: "Remove #{account.label} and all its synced data?" },
                        class: "rounded bg-red-100 px-3 py-1 text-red-800" %>
        </div>
      </div>

      <% if account.needs_reauth? %>
        <%= form_with url: reauth_account_path(account), method: :patch, class: "mt-3 flex gap-2" do |f| %>
          <%= f.password_field :npsso, placeholder: "Fresh NPSSO token", required: true,
                               class: "w-96 rounded border p-2" %>
          <%= f.submit "Re-authenticate", class: "rounded bg-blue-600 px-4 py-2 text-white" %>
        <% end %>
      <% end %>

      <dl class="mt-3 grid grid-cols-4 gap-2 text-sm text-gray-600">
        <div>Level <%= account.trophy_level || "—" %></div>
        <div>Last synced <%= account.last_synced_at ? time_ago_in_words(account.last_synced_at) + " ago" : "never" %></div>
      </dl>

      <div class="mt-2 text-sm">
        <% account.sync_runs.latest_per_kind.each do |kind, run| %>
          <span class="mr-4">
            <%= kind %>: <span class="font-medium"><%= run.status %></span>
            <% if run.error_message.present? %>
              <span class="text-red-700">(<%= run.error_message %>)</span>
            <% end %>
          </span>
        <% end %>
      </div>
    </div>
  <% end %>
</div>
```

- [ ] **Step 6: Live sync status via Turbo page refreshes**

The spec calls for sync status updating live. Use Turbo 8 refresh broadcasts —
no custom streams or partial targeting needed.

Add to `app/models/sync_run.rb` (below the validations):

```ruby
  # Any sync-run change refreshes pages subscribed to the sync_status stream.
  broadcasts_refreshes_to ->(_run) { "sync_status" }
```

Add as the first line of `app/views/accounts/index.html.erb`:

```erb
<%= turbo_stream_from "sync_status" %>
```

(The dashboard view gets the same line when it is created in Task 10 — Task 10's
view code below already assumes it; add it there as its first line too.)

- [ ] **Step 7: Run to verify pass**

Run: `bundle exec rspec spec/requests/accounts_spec.rb`
Expected: PASS (6 examples). Broadcasts fire through the model callback; the
request specs still pass because `turbo_stream_from` renders inertly in tests.

- [ ] **Step 8: Commit**

```bash
git add -A
git commit -m "feat: accounts UI with NPSSO registration, reauth, sync-now, make-current"
```

---

### Task 10: Dashboard (root page) and money formatting

**Files:**
- Create: `app/controllers/dashboard_controller.rb`, `app/views/dashboard/show.html.erb`
- Modify: `app/helpers/application_helper.rb`, `config/routes.rb`
- Test: `spec/requests/dashboard_spec.rb`, `spec/helpers/application_helper_spec.rb`

**Interfaces:**
- Consumes: `Account` (+ counts caches), `PsnTransaction` scopes, `SyncRun.latest_per_kind`.
- Produces: root route → dashboard; helper `format_money(amount_minor, currency)` → `"£69.99"` / `"$12.50"` / `"12.50 SEK"` (assumes 2 minor-unit digits; fine for GBP/USD/EUR). Reused by Tasks 12–13.

- [ ] **Step 1: Write the failing specs**

`spec/helpers/application_helper_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe ApplicationHelper do
  describe "#format_money" do
    it { expect(helper.format_money(6999, "GBP")).to eq("£69.99") }
    it { expect(helper.format_money(1250, "USD")).to eq("$12.50") }
    it { expect(helper.format_money(1250, "SEK")).to eq("12.50 SEK") }
    it { expect(helper.format_money(nil, "GBP")).to eq("—") }
  end
end
```

`spec/requests/dashboard_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe "Dashboard" do
  it "shows each account's level, counts, spend, and sync state" do
    account = create(:account, label: "Main", current: true, trophy_level: 420,
                     earned_platinum: 5, last_synced_at: 2.hours.ago)
    create(:psn_transaction, account:, kind: "purchase", amount_minor: 5000, currency: "GBP")
    create(:psn_transaction, account:, kind: "refund", amount_minor: 1000, currency: "GBP")
    create(:sync_run, account:, kind: "trophies", status: "failed", error_message: "boom")

    get root_path
    expect(response.body).to include("Main", "420", "£40.00", "boom")
  end

  it "renders an empty state with a link to add an account" do
    get root_path
    expect(response.body).to include("Add account")
  end
end
```

- [ ] **Step 2: Run to verify failure**

Run: `bundle exec rspec spec/requests/dashboard_spec.rb spec/helpers`
Expected: FAIL (no root route / undefined format_money).

- [ ] **Step 3: Implement**

In `config/routes.rb`:

```ruby
  root "dashboard#show"
```

`app/helpers/application_helper.rb`:

```ruby
module ApplicationHelper
  CURRENCY_SYMBOLS = { "GBP" => "£", "USD" => "$", "EUR" => "€" }.freeze

  # Minor units in, human string out. Assumes 2 minor-unit digits, which
  # holds for the currencies PSN bills in around here.
  def format_money(amount_minor, currency)
    return "—" if amount_minor.nil?

    value = format("%.2f", amount_minor / 100.0)
    symbol = CURRENCY_SYMBOLS[currency]
    symbol ? "#{symbol}#{value}" : "#{value} #{currency}"
  end
end
```

`app/controllers/dashboard_controller.rb`:

```ruby
class DashboardController < ApplicationController
  def show
    @accounts = Account.order(current: :desc, label: :asc).includes(:sync_runs)
    @spend_by_account = PsnTransaction.purchases.group(:account_id, :currency).sum(:amount_minor)
    @refunds_by_account = PsnTransaction.refunds.group(:account_id, :currency).sum(:amount_minor)
  end
end
```

`app/views/dashboard/show.html.erb`:

```erb
<%= turbo_stream_from "sync_status" %>
<h1 class="mb-6 text-2xl font-bold">Dashboard</h1>

<% if @accounts.empty? %>
  <p class="text-gray-600">No accounts yet.
    <%= link_to "Add account", new_account_path, class: "text-blue-600 underline" %>
  </p>
<% else %>
  <div class="grid gap-4 md:grid-cols-2">
    <% @accounts.each do |account| %>
      <div class="rounded border p-4">
        <div class="flex items-center justify-between">
          <span class="text-lg font-semibold"><%= account.label %></span>
          <% if account.current? %>
            <span class="rounded bg-blue-100 px-2 py-0.5 text-sm text-blue-800">Current</span>
          <% end %>
        </div>
        <dl class="mt-2 space-y-1 text-sm text-gray-700">
          <div>Trophy level: <span class="font-medium"><%= account.trophy_level || "—" %></span></div>
          <div>
            <%= account.earned_platinum %> platinum ·
            <%= account.earned_gold %> gold ·
            <%= account.earned_silver %> silver ·
            <%= account.earned_bronze %> bronze
          </div>
          <div>
            Net spend:
            <% spends = @spend_by_account.select { |(id, _), _| id == account.id } %>
            <% if spends.empty? %>—<% end %>
            <% spends.each do |(_, currency), total| %>
              <span class="font-medium">
                <%= format_money(total - (@refunds_by_account[[account.id, currency]] || 0), currency) %>
              </span>
            <% end %>
          </div>
          <div>Last synced: <%= account.last_synced_at ? time_ago_in_words(account.last_synced_at) + " ago" : "never" %></div>
        </dl>
        <% if account.needs_reauth? %>
          <p class="mt-2 rounded bg-red-100 p-2 text-sm text-red-800">
            Needs re-authentication — <%= link_to "fix on the accounts page", accounts_path, class: "underline" %>
          </p>
        <% end %>
        <div class="mt-2 text-sm text-gray-600">
          <% account.sync_runs.latest_per_kind.each do |kind, run| %>
            <span class="mr-3"><%= kind %>: <%= run.status %><% if run.error_message.present? %> (<%= run.error_message %>)<% end %></span>
          <% end %>
        </div>
      </div>
    <% end %>
  </div>
<% end %>
```

- [ ] **Step 4: Run to verify pass**

Run: `bundle exec rspec spec/requests/dashboard_spec.rb spec/helpers`
Expected: PASS (6 examples).

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "feat: dashboard with account cards, net spend, sync status"
```

---

### Task 11: Ownership matrix

**Files:**
- Create: `app/queries/ownership_matrix.rb`
- Create: `app/controllers/ownership_controller.rb`, `app/views/ownership/index.html.erb`
- Modify: `config/routes.rb`
- Test: `spec/queries/ownership_matrix_spec.rb`, `spec/requests/ownership_spec.rb`

**Interfaces:**
- Consumes: `Entitlement` (`#product_key`, scope `.games`).
- Produces: `OwnershipMatrix.call(include_dlc: false)` → `Array<OwnershipMatrix::Row>` sorted by name, where `Row = Data.define(:name, :platform, :by_account_id)` and `by_account_id` maps account id → `Entitlement`; `Row#duplicate?` is true when owned by 2+ accounts. Route: `GET /ownership`.

- [ ] **Step 1: Write the failing query spec**

`spec/queries/ownership_matrix_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe OwnershipMatrix do
  let(:a) { create(:account) }
  let(:b) { create(:account) }

  it "groups entitlements by product across accounts and flags duplicates" do
    create(:entitlement, account: a, name: "Astro Bot", product_id: "EP-ASTRO")
    create(:entitlement, account: b, name: "ASTRO BOT", product_id: "EP-ASTRO")
    create(:entitlement, account: b, name: "Bloodborne", product_id: nil)

    rows = described_class.call
    expect(rows.map(&:name)).to eq(["Astro Bot", "Bloodborne"])

    astro = rows.first
    expect(astro.by_account_id.keys).to contain_exactly(a.id, b.id)
    expect(astro).to be_duplicate
    expect(rows.last).not_to be_duplicate
  end

  it "groups by case-insensitive name when there is no product id" do
    create(:entitlement, account: a, name: "Bloodborne", product_id: nil)
    create(:entitlement, account: b, name: "BLOODBORNE", product_id: nil)
    expect(described_class.call.size).to eq(1)
  end

  it "excludes DLC unless asked for it" do
    create(:entitlement, account: a, name: "Base Game", kind: "game")
    create(:entitlement, account: a, name: "Season Pass", kind: "dlc")
    expect(described_class.call.map(&:name)).to eq(["Base Game"])
    expect(described_class.call(include_dlc: true).map(&:name)).to eq(["Base Game", "Season Pass"])
  end
end
```

- [ ] **Step 2: Run to verify failure**

Run: `bundle exec rspec spec/queries/ownership_matrix_spec.rb`
Expected: FAIL (uninitialized constant OwnershipMatrix).

- [ ] **Step 3: Implement the query**

`app/queries/ownership_matrix.rb`:

```ruby
# Titles × accounts grid built from entitlements. In-memory grouping is fine
# at personal-library scale (a few thousand rows).
class OwnershipMatrix
  Row = Data.define(:name, :platform, :by_account_id) do
    def duplicate? = by_account_id.size > 1
  end

  def self.call(include_dlc: false)
    scope = include_dlc ? Entitlement.where(kind: %w[game dlc]) : Entitlement.games
    scope.group_by(&:product_key).map { |_, ents|
      Row.new(name: ents.first.name, platform: ents.first.platform,
              by_account_id: ents.index_by(&:account_id))
    }.sort_by { |row| row.name.to_s.downcase }
  end
end
```

(`app/queries` is autoloaded automatically — everything under `app/` is.)

- [ ] **Step 4: Write the failing request spec**

`spec/requests/ownership_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe "Ownership" do
  it "renders the matrix with duplicate highlighting" do
    a = create(:account, label: "Main")
    b = create(:account, label: "Alt")
    create(:entitlement, account: a, name: "Astro Bot", product_id: "EP-ASTRO")
    create(:entitlement, account: b, name: "Astro Bot", product_id: "EP-ASTRO")

    get ownership_index_path
    expect(response.body).to include("Astro Bot", "Main", "Alt", "Duplicate")
  end
end
```

Run: `bundle exec rspec spec/requests/ownership_spec.rb` — expected FAIL (routing error).

- [ ] **Step 5: Implement controller, route, view**

In `config/routes.rb`:

```ruby
  resources :ownership, only: :index
```

`app/controllers/ownership_controller.rb`:

```ruby
class OwnershipController < ApplicationController
  def index
    @accounts = Account.order(:label)
    @rows = OwnershipMatrix.call(include_dlc: params[:include_dlc].present?)
  end
end
```

`app/views/ownership/index.html.erb`:

```erb
<div class="mb-6 flex items-center justify-between">
  <h1 class="text-2xl font-bold">Ownership matrix</h1>
  <% if params[:include_dlc].present? %>
    <%= link_to "Games only", ownership_index_path, class: "text-blue-600 underline" %>
  <% else %>
    <%= link_to "Include DLC", ownership_index_path(include_dlc: 1), class: "text-blue-600 underline" %>
  <% end %>
</div>

<div class="overflow-x-auto">
  <table class="min-w-full border text-sm">
    <thead>
      <tr class="bg-gray-100 text-left">
        <th class="border p-2">Title</th>
        <th class="border p-2">Platform</th>
        <% @accounts.each do |account| %>
          <th class="border p-2"><%= account.label %></th>
        <% end %>
        <th class="border p-2"></th>
      </tr>
    </thead>
    <tbody>
      <% @rows.each do |row| %>
        <tr class="<%= "bg-amber-50" if row.duplicate? %>">
          <td class="border p-2"><%= row.name %></td>
          <td class="border p-2"><%= row.platform %></td>
          <% @accounts.each do |account| %>
            <td class="border p-2">
              <% if (ent = row.by_account_id[account.id]) %>
                ✓ <span class="text-gray-500"><%= ent.acquired_at&.to_date %></span>
              <% end %>
            </td>
          <% end %>
          <td class="border p-2">
            <% if row.duplicate? %><span class="rounded bg-amber-200 px-2 py-0.5">Duplicate</span><% end %>
          </td>
        </tr>
      <% end %>
    </tbody>
  </table>
</div>
```

- [ ] **Step 6: Run to verify pass**

Run: `bundle exec rspec spec/queries/ownership_matrix_spec.rb spec/requests/ownership_spec.rb`
Expected: PASS (4 examples).

- [ ] **Step 7: Commit**

```bash
git add -A
git commit -m "feat: ownership matrix with duplicate-purchase highlighting"
```

---

### Task 12: Spend analysis

**Files:**
- Create: `app/queries/spend_summary.rb`
- Create: `app/controllers/spend_controller.rb`, `app/views/spend/index.html.erb`
- Modify: `config/routes.rb`
- Test: `spec/queries/spend_summary_spec.rb`, `spec/requests/spend_spec.rb`

**Interfaces:**
- Consumes: `PsnTransaction` scopes, `format_money` helper (Task 10).
- Produces: `SpendSummary.call` → `Hash{Account => Array<SpendSummary::CurrencyTotals>}` where `CurrencyTotals = Data.define(:currency, :purchases, :refunds, :wallet, :net, :by_year)` (`by_year`: `Hash{Integer year => Integer net minor units}`, newest first). `SpendSummary.biggest_purchases(limit: 10)` → `Array<PsnTransaction>`. Route: `GET /spend`.

- [ ] **Step 1: Write the failing query spec**

`spec/queries/spend_summary_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe SpendSummary do
  it "totals purchases minus refunds per account and currency, split by year" do
    account = create(:account)
    create(:psn_transaction, account:, kind: "purchase", amount_minor: 5000, currency: "GBP",
           occurred_at: Time.zone.local(2023, 3, 1))
    create(:psn_transaction, account:, kind: "purchase", amount_minor: 3000, currency: "GBP",
           occurred_at: Time.zone.local(2024, 3, 1))
    create(:psn_transaction, account:, kind: "refund", amount_minor: 1000, currency: "GBP",
           occurred_at: Time.zone.local(2024, 4, 1))
    create(:psn_transaction, account:, kind: "wallet", amount_minor: 2000, currency: "GBP",
           occurred_at: Time.zone.local(2024, 4, 1))
    create(:psn_transaction, account:, kind: "purchase", amount_minor: 900, currency: "USD",
           occurred_at: Time.zone.local(2024, 5, 1))

    totals = described_class.call.fetch(account)
    gbp = totals.find { |t| t.currency == "GBP" }
    expect(gbp).to have_attributes(purchases: 8000, refunds: 1000, wallet: 2000, net: 7000)
    expect(gbp.by_year).to eq({ 2024 => 2000, 2023 => 5000 })
    expect(totals.find { |t| t.currency == "USD" }.net).to eq(900)
  end

  it "lists the biggest purchases" do
    account = create(:account)
    small = create(:psn_transaction, account:, amount_minor: 100)
    big = create(:psn_transaction, account:, amount_minor: 9999)
    expect(described_class.biggest_purchases(limit: 1)).to eq([big])
  end
end
```

- [ ] **Step 2: Run to verify failure**

Run: `bundle exec rspec spec/queries/spend_summary_spec.rb`
Expected: FAIL (uninitialized constant SpendSummary).

- [ ] **Step 3: Implement**

`app/queries/spend_summary.rb`:

```ruby
# Per-account, per-currency money math from synced transactions. No currency
# conversion: mixed currencies are reported side by side.
class SpendSummary
  CurrencyTotals = Data.define(:currency, :purchases, :refunds, :wallet, :net, :by_year)

  def self.call
    Account.order(:label).index_with { |account| new(account).totals }
             .reject { |_, totals| totals.empty? }
  end

  def self.biggest_purchases(limit: 10)
    PsnTransaction.purchases.order(amount_minor: :desc).limit(limit).includes(:account)
  end

  def initialize(account)
    @account = account
  end

  def totals
    currencies.map do |currency|
      scope = @account.psn_transactions.where(currency:)
      purchases = scope.purchases.sum(:amount_minor)
      refunds = scope.refunds.sum(:amount_minor)
      CurrencyTotals.new(currency:, purchases:, refunds:,
                         wallet: scope.wallet_funding.sum(:amount_minor),
                         net: purchases - refunds, by_year: by_year(scope))
    end
  end

  private

  def currencies
    @account.psn_transactions.where.not(currency: nil).distinct.pluck(:currency).sort
  end

  def by_year(scope)
    purchases = scope.purchases.group("CAST(strftime('%Y', occurred_at) AS INTEGER)").sum(:amount_minor)
    refunds = scope.refunds.group("CAST(strftime('%Y', occurred_at) AS INTEGER)").sum(:amount_minor)
    purchases.merge(refunds.transform_values(&:-@)) { |_, p, r| p + r }
             .sort_by { |year, _| -year }.to_h
  end
end
```

- [ ] **Step 4: Route, controller, view, request spec**

`spec/requests/spend_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe "Spend" do
  it "shows per-account totals and biggest purchases" do
    account = create(:account, label: "Main")
    create(:psn_transaction, account:, amount_minor: 6999, currency: "GBP",
           description: "Astro Bot", occurred_at: Time.zone.local(2024, 2, 1))
    get spend_index_path
    expect(response.body).to include("Main", "£69.99", "Astro Bot")
  end
end
```

In `config/routes.rb`:

```ruby
  resources :spend, only: :index
```

`app/controllers/spend_controller.rb`:

```ruby
class SpendController < ApplicationController
  def index
    @summaries = SpendSummary.call
    @biggest = SpendSummary.biggest_purchases
  end
end
```

`app/views/spend/index.html.erb`:

```erb
<h1 class="mb-6 text-2xl font-bold">Spend analysis</h1>

<div class="grid gap-4 md:grid-cols-2">
  <% @summaries.each do |account, totals| %>
    <div class="rounded border p-4">
      <h2 class="text-lg font-semibold"><%= account.label %></h2>
      <% totals.each do |t| %>
        <dl class="mt-2 text-sm text-gray-700">
          <div>Net spend (<%= t.currency %>): <span class="font-medium"><%= format_money(t.net, t.currency) %></span></div>
          <div>Purchases <%= format_money(t.purchases, t.currency) %> ·
               Refunds <%= format_money(t.refunds, t.currency) %> ·
               Wallet funding <%= format_money(t.wallet, t.currency) %></div>
        </dl>
        <table class="mt-2 text-sm">
          <% t.by_year.each do |year, net| %>
            <tr><td class="pr-4"><%= year %></td><td><%= format_money(net, t.currency) %></td></tr>
          <% end %>
        </table>
      <% end %>
    </div>
  <% end %>
</div>

<h2 class="mb-2 mt-8 text-lg font-semibold">Biggest purchases</h2>
<table class="min-w-full border text-sm">
  <thead>
    <tr class="bg-gray-100 text-left">
      <th class="border p-2">Account</th><th class="border p-2">Date</th>
      <th class="border p-2">Description</th><th class="border p-2">Amount</th>
    </tr>
  </thead>
  <tbody>
    <% @biggest.each do |txn| %>
      <tr>
        <td class="border p-2"><%= txn.account.label %></td>
        <td class="border p-2"><%= txn.occurred_at&.to_date %></td>
        <td class="border p-2"><%= txn.description %></td>
        <td class="border p-2"><%= format_money(txn.amount_minor, txn.currency) %></td>
      </tr>
    <% end %>
  </tbody>
</table>
```

- [ ] **Step 5: Run to verify pass**

Run: `bundle exec rspec spec/queries/spend_summary_spec.rb spec/requests/spend_spec.rb`
Expected: PASS (3 examples).

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "feat: spend analysis with per-currency totals, yearly breakdown, biggest purchases"
```

---

### Task 13: Trophy comparison

**Files:**
- Create: `app/controllers/trophy_comparison_controller.rb`, `app/views/trophy_comparison/index.html.erb`
- Modify: `config/routes.rb`
- Test: `spec/requests/trophy_comparison_spec.rb`

**Interfaces:**
- Consumes: `Game`, `AccountGame`, `Account`.
- Produces: route `GET /trophy_comparison` — per-game rows with each account's progress side by side, plus a header row of overall per-account totals. Simple enough that the controller queries directly; no query object.

- [ ] **Step 1: Write the failing request spec**

`spec/requests/trophy_comparison_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe "Trophy comparison" do
  it "shows each game once with per-account progress" do
    a = create(:account, label: "Main")
    b = create(:account, label: "Alt")
    game = create(:game, name: "Astro Bot")
    create(:account_game, account: a, game:, progress: 100, earned_platinum: 1)
    create(:account_game, account: b, game:, progress: 40)

    get trophy_comparison_index_path
    expect(response.body).to include("Astro Bot", "Main", "Alt", "100%", "40%")
    expect(response.body.scan("Astro Bot").size).to eq(1)
  end
end
```

- [ ] **Step 2: Run to verify failure**

Run: `bundle exec rspec spec/requests/trophy_comparison_spec.rb`
Expected: FAIL (routing error).

- [ ] **Step 3: Implement**

In `config/routes.rb`:

```ruby
  resources :trophy_comparison, only: :index
```

`app/controllers/trophy_comparison_controller.rb`:

```ruby
class TrophyComparisonController < ApplicationController
  def index
    @accounts = Account.order(current: :desc, label: :asc)
    @games = Game.joins(:account_games).distinct.order(:name).includes(:account_games)
  end
end
```

`app/views/trophy_comparison/index.html.erb`:

```erb
<h1 class="mb-6 text-2xl font-bold">Trophy comparison</h1>

<div class="mb-6 grid gap-4 md:grid-cols-<%= [@accounts.size, 4].min %>">
  <% @accounts.each do |account| %>
    <div class="rounded border p-3 text-sm">
      <div class="font-semibold"><%= account.label %></div>
      <div>Level <%= account.trophy_level || "—" %></div>
      <div><%= account.earned_platinum %>P · <%= account.earned_gold %>G ·
           <%= account.earned_silver %>S · <%= account.earned_bronze %>B</div>
    </div>
  <% end %>
</div>

<div class="overflow-x-auto">
  <table class="min-w-full border text-sm">
    <thead>
      <tr class="bg-gray-100 text-left">
        <th class="border p-2">Game</th>
        <th class="border p-2">Platform</th>
        <% @accounts.each do |account| %>
          <th class="border p-2"><%= account.label %></th>
        <% end %>
      </tr>
    </thead>
    <tbody>
      <% @games.each do |game| %>
        <% by_account = game.account_games.index_by(&:account_id) %>
        <tr>
          <td class="border p-2"><%= game.name %></td>
          <td class="border p-2"><%= game.platform %></td>
          <% @accounts.each do |account| %>
            <td class="border p-2">
              <% if (ag = by_account[account.id]) %>
                <span class="font-medium"><%= ag.progress %>%</span>
                <span class="text-gray-500"><%= ag.earned_platinum %>P/<%= ag.earned_gold %>G/<%= ag.earned_silver %>S/<%= ag.earned_bronze %>B</span>
              <% end %>
            </td>
          <% end %>
        </tr>
      <% end %>
    </tbody>
  </table>
</div>
```

- [ ] **Step 4: Run to verify pass**

Run: `bundle exec rspec spec/requests/trophy_comparison_spec.rb`
Expected: PASS (1 example).

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "feat: side-by-side trophy comparison across accounts"
```

---

### Task 14: Re-earn tracker, navigation, README

**Files:**
- Create: `app/queries/reearn_progress.rb`
- Create: `app/controllers/reearn_controller.rb`, `app/views/reearn/show.html.erb`
- Modify: `config/routes.rb`, `app/views/layouts/application.html.erb`, `README.md`
- Test: `spec/queries/reearn_progress_spec.rb`, `spec/requests/reearn_spec.rb`

**Interfaces:**
- Consumes: `Account.current`, `AccountTrophy`, `Trophy`, `Game`.
- Produces: `ReearnProgress.call(current_account)` → `ReearnProgress::Result` with `total` (baseline size), `reearned` (count), `percent`, and `games` → `Array<GameProgress>` where `GameProgress = Data.define(:game, :total, :reearned)` (`#complete?`, complete games sorted after incomplete ones). Route: `GET /reearn`. Baseline = trophies any account has earned (including the current account); matching is exact trophy set only.

- [ ] **Step 1: Write the failing query spec**

`spec/queries/reearn_progress_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe ReearnProgress do
  let(:current) { create(:account, current: true) }
  let(:old) { create(:account) }

  it "computes the baseline as trophies earned by anyone, progress by the current account" do
    game = create(:game)
    t1, t2, t3, t4 = create_list(:trophy, 4, game:)

    create(:account_trophy, account: old, trophy: t1)                  # old only -> to re-earn
    create(:account_trophy, account: old, trophy: t2)                  # earned by both
    create(:account_trophy, account: current, trophy: t2)
    create(:account_trophy, account: current, trophy: t3)              # current only -> still counts
    create(:account_trophy, account: current, trophy: t4, earned: false) # unearned -> not in baseline

    result = described_class.call(current)
    expect(result.total).to eq(3)
    expect(result.reearned).to eq(2)
    expect(result.percent).to eq(67)
  end

  it "reports per-game progress with complete games sorted last" do
    done = create(:game, name: "Done Game")
    pending = create(:game, name: "Pending Game")
    done_trophy = create(:trophy, game: done)
    pending_trophy = create(:trophy, game: pending)
    create(:account_trophy, account: old, trophy: done_trophy)
    create(:account_trophy, account: current, trophy: done_trophy)
    create(:account_trophy, account: old, trophy: pending_trophy)

    games = described_class.call(current).games
    expect(games.map { |g| g.game.name }).to eq(["Pending Game", "Done Game"])
    expect(games.last).to be_complete
  end

  it "handles an empty baseline" do
    result = described_class.call(current)
    expect(result.total).to eq(0)
    expect(result.percent).to eq(0)
  end
end
```

- [ ] **Step 2: Run to verify failure**

Run: `bundle exec rspec spec/queries/reearn_progress_spec.rb`
Expected: FAIL (uninitialized constant ReearnProgress).

- [ ] **Step 3: Implement the query**

`app/queries/reearn_progress.rb`:

```ruby
# The headline feature: baseline = every trophy ANY account has earned
# (exact trophy set only); progress = the subset the current account has
# earned. The current account's own history counts toward the baseline.
class ReearnProgress
  GameProgress = Data.define(:game, :total, :reearned) do
    def complete? = reearned >= total
    def percent = total.zero? ? 0 : (reearned * 100.0 / total).round
  end

  Result = Data.define(:total, :reearned, :games) do
    def percent = total.zero? ? 0 : (reearned * 100.0 / total).round
  end

  def self.call(current_account)
    baseline = AccountTrophy.where(earned: true).select(:trophy_id)
    current = AccountTrophy.where(account: current_account, earned: true).select(:trophy_id)

    per_game_total = Trophy.where(id: baseline).group(:game_id).count
    per_game_done = Trophy.where(id: baseline).where(id: current).group(:game_id).count

    games = Game.where(id: per_game_total.keys).order(:name).map do |game|
      GameProgress.new(game:, total: per_game_total.fetch(game.id),
                       reearned: per_game_done.fetch(game.id, 0))
    end.sort_by { |gp| [gp.complete? ? 1 : 0, gp.game.name.to_s.downcase] }

    Result.new(total: per_game_total.values.sum, reearned: per_game_done.values.sum, games:)
  end
end
```

- [ ] **Step 4: Route, controller, view, request spec**

`spec/requests/reearn_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe "Re-earn tracker" do
  it "asks you to pick a current account when none is set" do
    get reearn_path
    expect(response.body).to include("No current account")
  end

  it "shows overall and per-game progress with the trophy checklist" do
    current = create(:account, current: true, label: "Main")
    old = create(:account, label: "Old")
    game = create(:game, name: "Astro Bot")
    trophy = create(:trophy, game:, name: "First Step")
    create(:account_trophy, account: old, trophy:, earned_at: Time.zone.local(2015, 1, 1))

    get reearn_path
    expect(response.body).to include("Astro Bot", "First Step", "0%", "Old")
  end
end
```

In `config/routes.rb`:

```ruby
  get "reearn", to: "reearn#show"
```

`app/controllers/reearn_controller.rb`:

```ruby
class ReearnController < ApplicationController
  def show
    @current_account = Account.current
    return unless @current_account

    @result = ReearnProgress.call(@current_account)
    @earned_by_game = AccountTrophy.where(earned: true)
                                   .includes(:account, trophy: :game)
                                   .group_by { |at| at.trophy.game_id }
  end
end
```

`app/views/reearn/show.html.erb`:

```erb
<h1 class="mb-2 text-2xl font-bold">Re-earn tracker</h1>

<% if @current_account.nil? %>
  <p class="text-gray-600">No current account set —
    <%= link_to "choose one on the accounts page", accounts_path, class: "text-blue-600 underline" %>.
  </p>
<% else %>
  <p class="mb-4 text-gray-600">
    Re-earning every trophy ever earned on any account, as <span class="font-medium"><%= @current_account.label %></span>.
  </p>

  <div class="mb-8 rounded border p-4">
    <div class="text-3xl font-bold"><%= @result.percent %>%</div>
    <div class="text-gray-600"><%= @result.reearned %> of <%= @result.total %> trophies re-earned</div>
    <div class="mt-2 h-3 w-full rounded bg-gray-200">
      <div class="h-3 rounded bg-blue-600" style="width: <%= @result.percent %>%"></div>
    </div>
  </div>

  <div class="space-y-4">
    <% @result.games.each do |gp| %>
      <details class="rounded border p-4 <%= "opacity-60" if gp.complete? %>">
        <summary class="cursor-pointer">
          <span class="font-semibold"><%= gp.game.name %></span>
          <span class="text-gray-500"><%= gp.game.platform %></span>
          <span class="ml-2"><%= gp.reearned %>/<%= gp.total %> (<%= gp.percent %>%)</span>
          <% if gp.complete? %><span class="ml-2 rounded bg-green-100 px-2 py-0.5 text-sm text-green-800">Complete</span><% end %>
        </summary>
        <table class="mt-3 min-w-full text-sm">
          <% earned_rows = (@earned_by_game[gp.game.id] || []).group_by(&:trophy_id) %>
          <% gp.game.trophies.order(:psn_trophy_id).each do |trophy| %>
            <% rows = earned_rows[trophy.id] || [] %>
            <% next if rows.empty? %>
            <% mine = rows.find { |at| at.account_id == @current_account.id } %>
            <tr class="border-t">
              <td class="p-2"><%= mine ? "✅" : "⬜" %></td>
              <td class="p-2">
                <div class="font-medium"><%= trophy.name %></div>
                <div class="text-gray-500"><%= trophy.detail %></div>
              </td>
              <td class="p-2 text-gray-600"><%= trophy.trophy_type %></td>
              <td class="p-2 text-gray-500">
                first earned by <%= rows.min_by { |at| at.earned_at || Time.current }&.account&.label %>
                <% if mine&.earned_at %> · re-earned <%= mine.earned_at.to_date %><% end %>
              </td>
            </tr>
          <% end %>
        </table>
      </details>
    <% end %>
  </div>
<% end %>
```

- [ ] **Step 5: Add navigation to the layout**

In `app/views/layouts/application.html.erb`, insert at the top of `<body>` (keep everything the generator put there; wrap the existing yield in a main tag if not already):

```erb
<nav class="mb-8 border-b bg-gray-50">
  <div class="mx-auto flex max-w-6xl gap-6 p-4 font-medium">
    <%= link_to "Dashboard", root_path %>
    <%= link_to "Re-earn", reearn_path %>
    <%= link_to "Trophies", trophy_comparison_index_path %>
    <%= link_to "Ownership", ownership_index_path %>
    <%= link_to "Spend", spend_index_path %>
    <%= link_to "Accounts", accounts_path %>
  </div>
</nav>
<main class="mx-auto max-w-6xl px-4">
  <%= yield %>
</main>
```

- [ ] **Step 6: Rewrite README.md**

```markdown
# PSN Compare

Compares trophies and purchases across multiple PSN accounts and tracks
re-earning every trophy ever earned on a designated current account.
Built on [psn-client-ruby](https://github.com/MattyJacques/psn-client-ruby).

## Setup

    bundle install
    bin/rails db:prepare

## Running

    bin/dev          # web + tailwind; Solid Queue runs jobs in-process in dev

Add each PSN account on the Accounts page with an NPSSO token (sign in at
playstation.com, then visit https://ca.account.sony.com/api/v1/ssocookie).
The token is used once; the app stores an encrypted rotating refresh token.
Then hit "Sync now" — trophies, entitlements, and transactions sync in the
background, and re-sync daily.

## Tests

    bundle exec rspec

Spec: docs/superpowers/specs/2026-07-06-psn-compare-design.md
```

Check `config/environments/development.rb` — if `config.active_job.queue_adapter` is not set to `:solid_queue` in development, jobs run with the default `:async` adapter, which is fine for local use; adjust the README wording to match what you find.

- [ ] **Step 7: Run the full suite and boot check**

```bash
bundle exec rspec
bin/rails runner 'puts Rails.application.routes.url_helpers.reearn_path'
```

Expected: all green; prints `/reearn`.

- [ ] **Step 8: Commit**

```bash
git add -A
git commit -m "feat: re-earn tracker, site navigation, README"
```

---

## Post-plan verification (manual, live PSN)

Not part of the automated suite — after all tasks, verify against the real API with the user's NPSSO:

1. `bin/dev`, add a real account, press Sync now.
2. Watch `sync_runs` complete on the dashboard; spot-check a few games' trophy counts against the PS App.
3. Check the entitlement `kind` mapping — the endpoint is undocumented; if kinds look wrong, adjust `Sync::Entitlements::GAME_TYPES`/`DLC_TYPES` against the observed `raw_type` values (they're stored on every row for exactly this purpose).



