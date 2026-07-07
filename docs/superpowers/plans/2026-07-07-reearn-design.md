# RE:EARN Design Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Recreate the RE:EARN design handoff (dark multi-account PSN trophy/purchase tracker, 12 screens) in the existing Rails app, including the new "won't earn" skip mechanic, trophy rarity, and 2nd-copy detection.

**Architecture:** Server-rendered ERB + Tailwind v4 theme tokens + Turbo (morph refreshes) + minimal Stimulus. New `trophy_skips` table drives the skip mechanic; new query objects (`DashboardStats`, `ReearnBacklog`, `MainOwnership`, `SecondCopies`) compute derived data; existing `ReearnProgress` is reworked to be skip-aware. Existing controllers/routes are kept (labels change, not names) except new `TrophySkipsController` and `reearn#backlog`.

**Tech Stack:** Rails 8.1, SQLite, Tailwind v4 (tailwindcss-rails), Hotwire (turbo-rails, stimulus-rails), RSpec + FactoryBot, psn-client-ruby gem (local path `../psn-client-ruby`).

## Design Reference

The handoff bundle ships as `PSN Trophy Comparison Tool.zip` at the repo root. Before starting, extract it somewhere readable:

```bash
cd /tmp && mkdir -p reearn_design && cd reearn_design && python3 -m zipfile -e "/home/matty/development/psn_compare/PSN Trophy Comparison Tool.zip" .
```

- `design_handoff_psn_reearn/README.md` — full spec: tokens, screens, behavior. **Read it before any view task.**
- `design_handoff_psn_reearn/screenshots/*.png` — one per screen (2a–2i, 3a–3c). View the relevant PNG before building each screen.
- `design_handoff_psn_reearn/PSN Tracker.dc.html` — pixel-accurate source; grep it for exact values if the README is ambiguous.

## Global Constraints

- Fonts: **Archivo** (400–800) for UI text, **IBM Plex Mono** (400–600) for all numbers, dates, timestamps, sync/status strings (loaded from Google Fonts).
- Colors: use ONLY the theme tokens defined in Task 1 (they encode the handoff palette, e.g. page `#0B0E17`, accent `#4C82F0`, gold `#E9C464`). No ad-hoc hex in views.
- Dates render as `14 Mar 2024` (`%-d %b %Y`); times 24h `21:47` (`%H:%M`); relative sync times ("12 min ago").
- Numbers with thousands separators (`number_with_delimiter`).
- Nav labels: Dashboard, Trophies, Checklist, Library, Purchases, Accounts (route/controller names stay as-is: `trophy_comparison`, `reearn`, `ownership`, `spend`).
- Game/trophy artwork comes from stored PSN `icon_url`s; when nil, render the striped placeholder tile (Task 1 CSS class `.stripe-tile`). Never ask users to upload artwork.
- **Documented degradations** (no data source exists — do NOT invent data): no game prices, no delisted flags, no cost-to-complete card (2f footer), no PS Plus ◐ ownership state, no per-game sync progress bars in 3b, no live rate-limit countdown (static toast text instead). "Owned on main" prices in 2d render as plain `no`.
- All specs green after every task: `bundle exec rspec`. Rubocop clean: `bin/rubocop`.
- Skipped trophies leave every denominator: re-earn %, "N left", chip counts, backlog counts.

---

### Task 1: Theme tokens, fonts, app shell (sidebar + mobile tab bar)

**Files:**
- Modify: `app/assets/tailwind/application.css`
- Modify: `app/views/layouts/application.html.erb`
- Create: `app/views/layouts/_sidebar.html.erb`
- Create: `app/views/layouts/_tabbar.html.erb`
- Create: `app/helpers/design_helper.rb`
- Test: `spec/requests/layout_spec.rb`, `spec/helpers/design_helper_spec.rb`

**Interfaces:**
- Produces: Tailwind color tokens (`bg-page`, `bg-rail`, `bg-card`, `bg-card2`, `bg-raise`, `border-line`, `border-line2`, `border-line3`, `border-sel`, `text-ink`, `text-ink2`, `text-mute`, `text-faint`, `text-dash`, `bg-accent`, `text-accent`, `bg-navbg`, `text-navink`, `text-link`, `text-plat/gold-t/silver-t/bronze-t`, `text-ok`, `bg-okbg`, `border-okline`, `text-oktime`, `text-warn`, `bg-warnbg`, `border-warnline`, `text-warnink`, `text-err`, `bg-errbg`, `border-errline`, `bg-hilite`, `text-skip`, `border-skipline`), `font-sans` = Archivo, `font-mono` = IBM Plex Mono, CSS class `.stripe-tile`.
- Produces helpers: `mono_date(time)` → `"14 Mar 2024"`, `mono_time(time)` → `"21:47"`, `initials(label)` → `"MH"`, `grade_border(trophy_type)` → border-color class, `grade_text(trophy_type)` → text-color class, `chip_classes(active)` → String, `relative_sync(time_or_nil)` → `"12 min ago"` / `"never"`.
- Produces layout regions: `content_for :page` (main content), full-screen mode when `@bare = true` (no sidebar/tabbar, used by first-run 3a).

- [ ] **Step 1: Write failing specs**

```ruby
# spec/helpers/design_helper_spec.rb
require "rails_helper"

RSpec.describe DesignHelper do
  it "formats dates and times in handoff style" do
    t = Time.zone.parse("2024-03-14 21:47")
    expect(helper.mono_date(t)).to eq("14 Mar 2024")
    expect(helper.mono_time(t)).to eq("21:47")
    expect(helper.mono_date(nil)).to eq("—")
  end

  it "builds initials from account labels" do
    expect(helper.initials("Matty_Hunter")).to eq("MH")
    expect(helper.initials("CoOpCouch")).to eq("CO")
    expect(helper.initials("Solo")).to eq("SO")
  end

  it "maps trophy grades to token classes" do
    expect(helper.grade_border("platinum")).to eq("border-plat")
    expect(helper.grade_text("gold")).to eq("text-gold-t")
    expect(helper.grade_border("unknown")).to eq("border-line3")
  end

  it "reports relative sync times" do
    expect(helper.relative_sync(nil)).to eq("never")
    expect(helper.relative_sync(12.minutes.ago)).to eq("12 min ago")
  end
end
```

```ruby
# spec/requests/layout_spec.rb
require "rails_helper"

RSpec.describe "Application shell" do
  it "renders the RE:EARN sidebar nav with design labels" do
    create(:account)
    get root_path
    expect(response.body).to include("RE:EARN")
    %w[Dashboard Trophies Checklist Library Purchases Accounts].each do |label|
      expect(response.body).to include(label)
    end
  end
end
```

Add to `spec/factories.rb` if not present a minimal `:account` factory (check the existing file first — it likely exists; reuse it).

- [ ] **Step 2: Run specs, verify failure**

Run: `bundle exec rspec spec/helpers/design_helper_spec.rb spec/requests/layout_spec.rb`
Expected: FAIL (`DesignHelper` uninitialized / missing nav labels).

- [ ] **Step 3: Implement theme CSS**

Replace `app/assets/tailwind/application.css` with:

```css
@import "tailwindcss";

@theme {
  --font-sans: "Archivo", ui-sans-serif, system-ui, sans-serif;
  --font-mono: "IBM Plex Mono", ui-monospace, "SFMono-Regular", monospace;

  --color-page: #0B0E17;
  --color-rail: #070B16;
  --color-card: #0E1425;
  --color-card2: #0E1730;
  --color-raise: #10162A;
  --color-line: #1A2138;
  --color-line2: #141B30;
  --color-line3: #1D2A4E;
  --color-sel: #2C4488;
  --color-ink: #EDF0F7;
  --color-ink2: #C6D2EC;
  --color-mute: #7C87A3;
  --color-faint: #5B6B90;
  --color-dash: #39415C;
  --color-accent: #4C82F0;
  --color-accent2: #3D6DE0;
  --color-navbg: #14224A;
  --color-navink: #D6E3FF;
  --color-link: #6FA1FF;
  --color-linkh: #9DBEFF;
  --color-plat: #8FB6D9;
  --color-gold-t: #E9C464;
  --color-silver-t: #C3CBDA;
  --color-bronze-t: #CE9469;
  --color-ok: #5FBF7A;
  --color-okbg: #0F2418;
  --color-okline: #1E4A30;
  --color-oktime: #3E8F5C;
  --color-warn: #F0B45A;
  --color-warnbg: #211A0D;
  --color-warnline: #4A3A1E;
  --color-warnink: #FFE9BD;
  --color-btnwarn: #4A3A1E;
  --color-err: #E88888;
  --color-errbg: #1F1010;
  --color-errline: #4A2626;
  --color-hilite: #161327;
  --color-skip: #8A96B4;
  --color-skipline: #2A3352;
  --color-btn: #1B2E63;
  --color-btnh: #24398F;
}

/* Placeholder art tile: diagonal stripes, used when a PSN icon_url is missing */
.stripe-tile {
  background: repeating-linear-gradient(135deg, #141B30 0 4px, #0E1425 4px 8px);
}
```

- [ ] **Step 4: Implement DesignHelper**

```ruby
# app/helpers/design_helper.rb
module DesignHelper
  GRADE_BORDER = { "platinum" => "border-plat", "gold" => "border-gold-t",
                   "silver" => "border-silver-t", "bronze" => "border-bronze-t" }.freeze
  GRADE_TEXT = { "platinum" => "text-plat", "gold" => "text-gold-t",
                 "silver" => "text-silver-t", "bronze" => "text-bronze-t" }.freeze

  def mono_date(time) = time ? time.strftime("%-d %b %Y") : "—"
  def mono_time(time) = time ? time.strftime("%H:%M") : ""

  # "Matty_Hunter" -> "MH"; single-word labels use the first two letters.
  def initials(label)
    parts = label.to_s.split(/[_\s]+/)
    (parts.size > 1 ? parts.first(2).map { |p| p[0] } : [label.to_s[0], label.to_s[1]]).join.upcase
  end

  def grade_border(trophy_type) = GRADE_BORDER.fetch(trophy_type, "border-line3")
  def grade_text(trophy_type) = GRADE_TEXT.fetch(trophy_type, "text-mute")

  def chip_classes(active)
    base = "inline-flex items-center gap-1 rounded-[20px] px-3.5 py-[7px] text-[13px] border"
    active ? "#{base} bg-navbg border-sel text-navink font-semibold"
           : "#{base} border-line text-mute hover:text-ink2 hover:border-line3"
  end

  def relative_sync(time)
    return "never" unless time

    mins = ((Time.current - time) / 60).round
    mins < 60 ? "#{mins} min ago" : "#{(mins / 60)} h ago"
  end
end
```

- [ ] **Step 5: Implement layout + sidebar + tab bar**

Replace `app/views/layouts/application.html.erb`:

```erb
<!DOCTYPE html>
<html class="bg-page">
  <head>
    <title><%= content_for(:title) || "RE:EARN" %></title>
    <meta name="viewport" content="width=device-width,initial-scale=1">
    <%= csrf_meta_tags %>
    <%= csp_meta_tag %>
    <%= yield :head %>
    <link rel="preconnect" href="https://fonts.googleapis.com">
    <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
    <link href="https://fonts.googleapis.com/css2?family=Archivo:wght@400..800&family=IBM+Plex+Mono:wght@400;500;600&display=swap" rel="stylesheet">
    <link rel="icon" href="/icon.png" type="image/png">
    <%= stylesheet_link_tag :app, "data-turbo-track": "reload" %>
    <%= javascript_importmap_tags %>
    <meta name="turbo-refresh-method" content="morph">
    <meta name="turbo-refresh-scroll" content="preserve">
  </head>

  <body class="min-h-screen bg-page font-sans text-ink antialiased">
    <%= turbo_stream_from "sync_status" %>
    <% if @bare %>
      <main class="mx-auto flex min-h-screen max-w-[560px] flex-col justify-center px-6 py-16">
        <%= yield %>
      </main>
    <% else %>
      <div class="flex min-h-screen">
        <%= render "layouts/sidebar" %>
        <main class="min-w-0 flex-1 px-5 pb-24 pt-6 lg:px-[52px] lg:py-11">
          <%= render "layouts/alerts" %>
          <%= yield %>
        </main>
      </div>
      <%= render "layouts/tabbar" %>
    <% end %>
  </body>
</html>
```

Create `app/views/layouts/_sidebar.html.erb`:

```erb
<% nav = [["Dashboard", root_path, controller_name == "dashboard"],
          ["Trophies", trophy_comparison_index_path, controller_name == "trophy_comparison"],
          ["Checklist", reearn_path, controller_name == "reearn"],
          ["Library", ownership_index_path, controller_name == "ownership"],
          ["Purchases", spend_index_path, controller_name == "spend"],
          ["Accounts", accounts_path, controller_name == "accounts"]] %>
<% error_count = Account.where(needs_reauth: true).count %>
<aside class="sticky top-0 hidden h-screen w-56 shrink-0 flex-col border-r border-line2 bg-rail lg:flex">
  <div class="flex items-center gap-2.5 px-5 pb-8 pt-6">
    <span class="flex size-7 items-center justify-center rounded-lg bg-gradient-to-br from-accent2 to-[#7B4DE0] text-[13px] font-extrabold">R</span>
    <span class="text-[15px] font-extrabold tracking-tight">RE:EARN</span>
  </div>
  <nav class="flex flex-col gap-1 px-3">
    <% nav.each do |label, path, active| %>
      <%= link_to path,
            class: "flex items-center justify-between rounded-[7px] px-2.5 py-[9px] text-[13.5px] #{active ? 'bg-navbg font-bold text-navink' : 'text-mute hover:bg-card2 hover:text-ink2'}" do %>
        <span><%= label %></span>
        <% if label == "Accounts" && error_count.positive? %>
          <span class="font-mono text-xs text-warn">·<%= error_count %></span>
        <% end %>
      <% end %>
    <% end %>
  </nav>
  <div class="mt-auto border-t border-line2 px-5 py-4">
    <div class="text-[11px] uppercase tracking-[0.08em] text-faint">Last sync</div>
    <% total = Account.count %>
    <% healthy = total - error_count %>
    <div class="mt-1 font-mono text-xs <%= error_count.positive? ? 'text-warn' : 'text-oktime' %>">
      <% if error_count.positive? %>▲ <%= healthy %>/<%= total %> accounts · <%= error_count %> error<%= "s" if error_count > 1 %>
      <% else %>● <%= relative_sync(Account.maximum(:last_synced_at)) %> · <%= total %>/<%= total %><% end %>
    </div>
  </div>
</aside>
```

Create `app/views/layouts/_tabbar.html.erb`:

```erb
<% tabs = [["Home", root_path, controller_name == "dashboard"],
           ["Trophies", trophy_comparison_index_path, controller_name == "trophy_comparison"],
           ["Checklist", reearn_path, controller_name == "reearn"],
           ["Library", ownership_index_path, controller_name == "ownership"],
           ["Accounts", accounts_path, controller_name == "accounts"]] %>
<nav class="fixed inset-x-0 bottom-0 z-40 flex border-t border-line2 bg-rail lg:hidden">
  <% tabs.each do |label, path, active| %>
    <%= link_to path, class: "flex min-h-11 flex-1 flex-col items-center justify-center gap-1 py-2" do %>
      <span class="size-5 rounded-md <%= active ? 'bg-accent' : 'bg-card' %>"></span>
      <span class="text-[10px] <%= active ? 'font-bold text-navink' : 'text-mute' %>"><%= label %></span>
    <% end %>
  <% end %>
</nav>
```

Create an empty alerts partial for now (Task 14 fills it): `app/views/layouts/_alerts.html.erb` containing only a comment `<%# Filled by error-states task %>` plus flash rendering:

```erb
<% if flash[:notice] %>
  <p class="mb-4 rounded-lg border border-okline bg-okbg px-4 py-3 text-sm text-ok"><%= flash[:notice] %></p>
<% end %>
<% if flash[:alert] %>
  <p class="mb-4 rounded-lg border border-errline bg-errbg px-4 py-3 text-sm text-err"><%= flash[:alert] %></p>
<% end %>
```

Remove the flash blocks from `app/views/accounts/index.html.erb` and `app/views/accounts/new.html.erb` (now handled by the layout partial).

- [ ] **Step 6: Run specs**

Run: `bundle exec rspec`
Expected: PASS (existing request specs assert content, not styling; if any asserted the old nav text, update them to the new labels).

- [ ] **Step 7: Visual smoke check**

Run: `bin/rails tailwindcss:build && bundle exec rspec spec/requests/layout_spec.rb`
Expected: build succeeds, spec passes.

- [ ] **Step 8: Commit**

```bash
git add -A && git commit -m "feat: RE:EARN theme tokens, fonts, sidebar + mobile tab bar shell"
```

---

### Task 2: Data model — trophy skips, rarity, avatars

**Files:**
- Create: `db/migrate/*_create_trophy_skips.rb`, `db/migrate/*_add_rarity_to_trophies.rb`, `db/migrate/*_add_avatar_url_to_accounts.rb`
- Create: `app/models/trophy_skip.rb`
- Modify: `app/models/trophy.rb`, `app/services/sync/trophies.rb`, `app/services/accounts/register.rb`, `spec/factories.rb`
- Test: `spec/models/trophy_skip_spec.rb`, `spec/services/sync_trophies_spec.rb` (modify if exists, else create coverage in `spec/jobs/sync_job_spec.rb` style)

**Interfaces:**
- Produces: `TrophySkip(trophy_id unique, note:text nil)`; `Trophy#skip` (has_one), `Trophy#skipped?`; `trophies.rarity_percent :decimal(5,2)`; `accounts.avatar_url :string`. Sync stores `psn_trophy.rarity` into `rarity_percent`; `Accounts::Register` stores `profile.avatar_url`.

- [ ] **Step 1: Write failing model spec**

```ruby
# spec/models/trophy_skip_spec.rb
require "rails_helper"

RSpec.describe TrophySkip do
  it "is unique per trophy and marks the trophy skipped" do
    trophy = create(:trophy)
    described_class.create!(trophy:)
    expect(trophy.reload).to be_skipped
    expect { described_class.create!(trophy:) }.to raise_error(ActiveRecord::RecordInvalid)
  end
end
```

- [ ] **Step 2: Run, verify failure**

Run: `bundle exec rspec spec/models/trophy_skip_spec.rb`
Expected: FAIL (table/model missing).

- [ ] **Step 3: Migrations + model**

```bash
bin/rails g migration CreateTrophySkips trophy:references{null_false} note:text
bin/rails g migration AddRarityToTrophies rarity_percent:decimal
bin/rails g migration AddAvatarUrlToAccounts avatar_url:string
```

Edit the CreateTrophySkips migration to add `index: { unique: true }` on `trophy_id` and the rarity migration to use `precision: 5, scale: 2`. Then `bin/rails db:migrate`.

```ruby
# app/models/trophy_skip.rb
class TrophySkip < ApplicationRecord
  belongs_to :trophy
  validates :trophy_id, uniqueness: true
end
```

In `app/models/trophy.rb` add:

```ruby
has_one :skip, class_name: "TrophySkip", dependent: :destroy

def skipped? = skip.present?
```

In `app/services/sync/trophies.rb#sync_trophies`, add `rarity_percent: psn_trophy.rarity` to the `trophy.update!` call. In `#update_account_summary`, also persist the avatar: fetch `profile = client.profiles.find` and add `avatar_url: profile.avatar_url` to the `@account.update!`. In `Accounts::Register.call`, add `avatar_url: profile.avatar_url` to `Account.create!`.

Add a `:trophy_skip` factory and ensure the `:trophy` factory exists in `spec/factories.rb` (reuse existing definitions).

- [ ] **Step 4: Run all specs**

Run: `bundle exec rspec`
Expected: PASS. If a sync-service spec stubs the client, extend the stub with `rarity` and `profiles.find` returning a Data with `avatar_url`.

- [ ] **Step 5: Commit**

```bash
git add -A && git commit -m "feat: trophy skips table, trophy rarity, account avatars"
```

---

### Task 3: Skip-aware ReearnProgress with per-game detail

**Files:**
- Modify: `app/queries/reearn_progress.rb`, `spec/queries/reearn_progress_spec.rb`

**Interfaces:**
- Produces:
  - `ReearnProgress.call(main_account)` → `Result(total:, reearned:, skipped:, games:)`
    - `Result#percent` → Float rounded to 1 decimal (63.7), denominator excludes skipped; `Result#to_go` = total − reearned; `Result#games_left` = games where `left > 0`.
  - `GameProgress(game:, total:, reearned:, skipped:, first_earned_labels:, missing:)` with `#left` = total − reearned, `#percent` (0-decimals Integer, skip-aware), `#complete?`.
    - `first_earned_labels` — Array of account labels (non-main first, ordered by earliest `earned_at`) that earned this game's trophies.
    - `missing` — Array of `MissingTrophy(trophy:, first_earned_at:, first_earned_label:, skipped:)`, ordered skipped-last then by trophy id; includes skipped trophies (`skipped: true`). Non-skipped missing = re-earn candidates.
  - `Result#games` sorted: incomplete games by fewest `left` first, complete games last.

- [ ] **Step 1: Rewrite the query spec (failing)**

Replace `spec/queries/reearn_progress_spec.rb` content with (adapt factory names to `spec/factories.rb`):

```ruby
require "rails_helper"

RSpec.describe ReearnProgress do
  let(:main) { create(:account, current: true) }
  let(:alt) { create(:account) }
  let(:game) { create(:game) }
  let!(:t1) { create(:trophy, game:) }
  let!(:t2) { create(:trophy, game:) }
  let!(:t3) { create(:trophy, game:) }

  before do
    # alt earned all three; main re-earned t1; t3 is skipped
    [t1, t2, t3].each { |t| create(:account_trophy, account: alt, trophy: t, earned: true, earned_at: Time.zone.parse("2022-05-01 10:00")) }
    create(:account_trophy, account: main, trophy: t1, earned: true, earned_at: Time.zone.parse("2024-03-14 21:47"))
    create(:trophy_skip, trophy: t3)
  end

  it "excludes skipped trophies from every denominator" do
    result = described_class.call(main)
    expect(result.total).to eq(2)          # t3 skipped
    expect(result.reearned).to eq(1)
    expect(result.skipped).to eq(1)
    expect(result.percent).to eq(50.0)
    expect(result.to_go).to eq(1)
  end

  it "builds per-game missing lists including skipped rows" do
    gp = described_class.call(main).games.first
    expect(gp.left).to eq(1)
    expect(gp.skipped).to eq(1)
    expect(gp.first_earned_labels).to include(alt.label)
    expect(gp.missing.map { |m| [m.trophy, m.skipped] }).to eq([[t2, false], [t3, true]])
    expect(gp.missing.first.first_earned_label).to eq(alt.label)
  end
end
```

- [ ] **Step 2: Run, verify failure**

Run: `bundle exec rspec spec/queries/reearn_progress_spec.rb`
Expected: FAIL (no `skipped` on Result, etc.).

- [ ] **Step 3: Rewrite ReearnProgress**

```ruby
# app/queries/reearn_progress.rb
# Baseline = every trophy ANY account has earned, minus skipped ("won't
# earn") trophies. Progress = the subset the main account has earned.
class ReearnProgress
  MissingTrophy = Data.define(:trophy, :first_earned_at, :first_earned_label, :skipped)

  GameProgress = Data.define(:game, :total, :reearned, :skipped, :first_earned_labels, :missing) do
    def left = total - reearned
    def complete? = left <= 0
    def percent = total.zero? ? 0 : (reearned * 100.0 / total).round
  end

  Result = Data.define(:total, :reearned, :skipped, :games) do
    def percent = total.zero? ? 0.0 : (reearned * 100.0 / total).round(1)
    def to_go = total - reearned
    def games_left = games.count { |gp| !gp.complete? }
  end

  def self.call(main) = new(main).call

  def initialize(main)
    @main = main
  end

  def call
    games = earned_rows.group_by { |at| at.trophy.game }.map { |game, rows| game_progress(game, rows) }
    games = games.sort_by { |gp| [gp.complete? ? 1 : 0, gp.left, gp.game.name.to_s.downcase] }
    Result.new(total: games.sum(&:total), reearned: games.sum(&:reearned),
               skipped: games.sum(&:skipped), games:)
  end

  private

  def earned_rows
    @earned_rows ||= AccountTrophy.where(earned: true).includes(:account, trophy: %i[game skip])
  end

  def game_progress(game, rows)
    by_trophy = rows.group_by(&:trophy)
    skipped_trophies, live = by_trophy.keys.partition(&:skipped?)
    reearned = live.count { |t| by_trophy[t].any? { |at| at.account_id == @main.id } }
    GameProgress.new(game:, total: live.size, reearned:, skipped: skipped_trophies.size,
                     first_earned_labels: first_earned_labels(rows),
                     missing: missing_list(by_trophy))
  end

  def first_earned_labels(rows)
    rows.reject { |at| at.account_id == @main.id }
        .sort_by { |at| at.earned_at || Time.current }
        .map { |at| at.account.label }.uniq
  end

  def missing_list(by_trophy)
    by_trophy.filter_map { |trophy, earners|
      next if !trophy.skipped? && earners.any? { |at| at.account_id == @main.id }

      first = earners.reject { |at| at.account_id == @main.id }.min_by { |at| at.earned_at || Time.current } || earners.first
      MissingTrophy.new(trophy:, first_earned_at: first&.earned_at,
                        first_earned_label: first&.account&.label, skipped: trophy.skipped?)
    }.sort_by { |m| [m.skipped ? 1 : 0, m.trophy.id] }
  end
end
```

- [ ] **Step 4: Run full suite**

Run: `bundle exec rspec`
Expected: PASS. `app/views/reearn/show.html.erb` still references `gp.total/reearned/percent` — those survive; if it references removed members, patch minimally (view is rebuilt in Task 9).

- [ ] **Step 5: Commit**

```bash
git add -A && git commit -m "feat: skip-aware ReearnProgress with per-game missing detail"
```

---

### Task 4: MainOwnership + DashboardStats queries

**Files:**
- Create: `app/queries/main_ownership.rb`, `app/queries/dashboard_stats.rb`
- Test: `spec/queries/main_ownership_spec.rb`, `spec/queries/dashboard_stats_spec.rb`

**Interfaces:**
- Consumes: `ReearnProgress.call(main)` (Task 3).
- Produces:
  - `MainOwnership.call(main)` → object with `#owned?(game)` (Boolean). Owned = main has an `account_games` row for the game OR a main `game`-kind entitlement whose normalized name starts with the game's normalized name. `MainOwnership.normalize(name)` → String (downcase, strip non-alphanumerics, squeeze spaces).
  - `DashboardStats.call(main)` → `Stats(unique_counts:, closest:, biggest_gap:, not_owned_count:, progress:)` where `unique_counts` is `{account_id => Integer}` (earned by exactly that one account), `closest`/`biggest_gap` are `ReearnProgress::GameProgress` or nil (incomplete games only; closest = fewest left, biggest_gap = most left), `not_owned_count` = incomplete games not owned on main, `progress` = the `ReearnProgress::Result`.

- [ ] **Step 1: Write failing specs**

```ruby
# spec/queries/main_ownership_spec.rb
require "rails_helper"

RSpec.describe MainOwnership do
  let(:main) { create(:account, current: true) }

  it "owns games the main account has played" do
    game = create(:game)
    create(:account_game, account: main, game:)
    expect(described_class.call(main).owned?(game)).to be true
  end

  it "owns games matching a main entitlement name, ignoring punctuation and editions" do
    game = create(:game, name: "Elden Ring")
    create(:entitlement, account: main, kind: "game", name: "ELDEN RING: Deluxe Edition")
    expect(described_class.call(main).owned?(game)).to be true
  end

  it "does not own games only alts have" do
    game = create(:game)
    create(:account_game, account: create(:account), game:)
    expect(described_class.call(main).owned?(game)).to be false
  end
end
```

```ruby
# spec/queries/dashboard_stats_spec.rb
require "rails_helper"

RSpec.describe DashboardStats do
  let(:main) { create(:account, current: true) }
  let(:alt) { create(:account) }

  it "counts trophies unique to a single account" do
    t_shared = create(:trophy)
    t_solo = create(:trophy)
    create(:account_trophy, account: main, trophy: t_shared, earned: true)
    create(:account_trophy, account: alt, trophy: t_shared, earned: true)
    create(:account_trophy, account: alt, trophy: t_solo, earned: true)

    stats = described_class.call(main)
    expect(stats.unique_counts[alt.id]).to eq(1)
    expect(stats.unique_counts[main.id]).to be_nil
  end

  it "picks closest-to-done and biggest-gap incomplete games" do
    near = create(:game, name: "Near")
    far = create(:game, name: "Far")
    create(:account_game, account: main, game: near)
    create(:account_game, account: main, game: far)
    2.times { create(:account_trophy, account: alt, trophy: create(:trophy, game: near), earned: true) }
    create(:account_trophy, account: main, trophy: near.trophies.first, earned: true)
    5.times { create(:account_trophy, account: alt, trophy: create(:trophy, game: far), earned: true) }

    stats = described_class.call(main)
    expect(stats.closest.game).to eq(near)
    expect(stats.biggest_gap.game).to eq(far)
    expect(stats.not_owned_count).to eq(0)
  end
end
```

- [ ] **Step 2: Run, verify failure**

Run: `bundle exec rspec spec/queries/main_ownership_spec.rb spec/queries/dashboard_stats_spec.rb`
Expected: FAIL (classes missing). Note: `main.account_trophies` for `near.trophies.first` — the spec creates the main earn on an alt-earned trophy; keep factories consistent with existing `spec/factories.rb`.

- [ ] **Step 3: Implement**

```ruby
# app/queries/main_ownership.rb
# "Owned on main" heuristic: the game is on the main account's trophy list,
# or a main game entitlement's name matches the game name (normalized
# prefix match — entitlements carry edition suffixes).
class MainOwnership
  def self.call(main) = new(main)

  def self.normalize(name)
    name.to_s.downcase.gsub(/[^a-z0-9 ]/, " ").squeeze(" ").strip
  end

  def initialize(main)
    @main = main
    @played_game_ids = main ? main.account_games.pluck(:game_id).to_set : Set.new
    @entitlement_names = main ? main.entitlements.games.pluck(:name).map { |n| self.class.normalize(n) } : []
  end

  def owned?(game)
    return true if @played_game_ids.include?(game.id)

    key = self.class.normalize(game.name)
    key.present? && @entitlement_names.any? { |n| n.start_with?(key) }
  end
end
```

```ruby
# app/queries/dashboard_stats.rb
class DashboardStats
  Stats = Data.define(:unique_counts, :closest, :biggest_gap, :not_owned_count, :progress)

  def self.call(main)
    progress = ReearnProgress.call(main)
    ownership = MainOwnership.call(main)
    incomplete = progress.games.reject(&:complete?)
    not_owned = incomplete.reject { |gp| ownership.owned?(gp.game) }

    Stats.new(unique_counts:, closest: incomplete.min_by(&:left),
              biggest_gap: incomplete.max_by(&:left),
              not_owned_count: not_owned.size, progress:)
  end

  # Trophies earned by exactly one account, counted per account.
  def self.unique_counts
    solo = AccountTrophy.where(earned: true).group(:trophy_id)
                        .having("COUNT(*) = 1").select(:trophy_id)
    AccountTrophy.where(earned: true, trophy_id: solo).group(:account_id).count
  end
end
```

- [ ] **Step 4: Run suite**

Run: `bundle exec rspec`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add -A && git commit -m "feat: MainOwnership heuristic and DashboardStats query"
```

---

### Task 5: ReearnBacklog query

**Files:**
- Create: `app/queries/reearn_backlog.rb`
- Test: `spec/queries/reearn_backlog_spec.rb`

**Interfaces:**
- Consumes: `MainOwnership` (Task 4).
- Produces: `ReearnBacklog.call(main, sort: "common", filter: nil)` → Array of `Row(trophy:, game:, first_earned_at:, first_earned_label:, rarity:, owned_on_main:)`.
  - Rows = re-earn candidates (earned by ≥1 non-main account, not earned by main, not skipped) — unless `filter == "skipped"`, which returns ONLY skipped trophies (any earner).
  - `sort`: `"common"` (rarity desc, nils last — default), `"rare"` (rarity asc, nils last).
  - `filter`: `nil`, `"platinum"` (platinum grade only), `"owned"` (owned on main only), `"skipped"`.

- [ ] **Step 1: Write failing spec**

```ruby
# spec/queries/reearn_backlog_spec.rb
require "rails_helper"

RSpec.describe ReearnBacklog do
  let(:main) { create(:account, current: true) }
  let(:alt) { create(:account, label: "Matty_JPN") }
  let(:game) { create(:game) }

  def earn(trophy, account, at: Time.zone.parse("2022-01-01"))
    create(:account_trophy, account:, trophy:, earned: true, earned_at: at)
  end

  it "lists candidates sorted most-common-first with first-earned info" do
    common = create(:trophy, game:, rarity_percent: 92.1)
    rare = create(:trophy, game:, rarity_percent: 4.1)
    earned_on_main = create(:trophy, game:, rarity_percent: 50)
    skipped = create(:trophy, game:, rarity_percent: 60)
    [common, rare, earned_on_main, skipped].each { |t| earn(t, alt) }
    earn(earned_on_main, main)
    create(:trophy_skip, trophy: skipped)

    rows = described_class.call(main)
    expect(rows.map(&:trophy)).to eq([common, rare])
    expect(rows.first.first_earned_label).to eq("Matty_JPN")
    expect(described_class.call(main, sort: "rare").map(&:trophy)).to eq([rare, common])
  end

  it "filters platinums, ownership, and skipped" do
    plat = create(:trophy, game:, trophy_type: "platinum")
    bronze = create(:trophy, game:, trophy_type: "bronze")
    skipped = create(:trophy, game:)
    [plat, bronze, skipped].each { |t| earn(t, alt) }
    create(:trophy_skip, trophy: skipped)
    create(:account_game, account: main, game:)

    expect(described_class.call(main, filter: "platinum").map(&:trophy)).to eq([plat])
    expect(described_class.call(main, filter: "owned").size).to eq(2)
    expect(described_class.call(main, filter: "skipped").map(&:trophy)).to eq([skipped])
  end
end
```

- [ ] **Step 2: Run, verify failure**

Run: `bundle exec rspec spec/queries/reearn_backlog_spec.rb` — Expected: FAIL.

- [ ] **Step 3: Implement**

```ruby
# app/queries/reearn_backlog.rb
# One flat ranked list of every re-earn candidate across all games.
class ReearnBacklog
  Row = Data.define(:trophy, :game, :first_earned_at, :first_earned_label, :rarity, :owned_on_main)

  def self.call(main, sort: "common", filter: nil) = new(main, sort:, filter:).call

  def initialize(main, sort:, filter:)
    @main, @sort, @filter = main, sort, filter
  end

  def call
    rows = candidate_trophies.map { |trophy, earners| build_row(trophy, earners) }
    rows = apply_filter(rows)
    sorted(rows)
  end

  private

  def candidate_trophies
    earned = AccountTrophy.where(earned: true).includes(:account, trophy: %i[game skip])
    by_trophy = earned.group_by(&:trophy)
    if @filter == "skipped"
      by_trophy.select { |t, _| t.skipped? }
    else
      by_trophy.reject { |t, earners| t.skipped? || earners.any? { |at| at.account_id == @main.id } }
    end
  end

  def build_row(trophy, earners)
    first = earners.reject { |at| at.account_id == @main.id }.min_by { |at| at.earned_at || Time.current } || earners.first
    Row.new(trophy:, game: trophy.game, first_earned_at: first&.earned_at,
            first_earned_label: first&.account&.label,
            rarity: trophy.rarity_percent&.to_f,
            owned_on_main: ownership.owned?(trophy.game))
  end

  def ownership = @ownership ||= MainOwnership.call(@main)

  def apply_filter(rows)
    case @filter
    when "platinum" then rows.select { |r| r.trophy.trophy_type == "platinum" }
    when "owned" then rows.select(&:owned_on_main)
    else rows
    end
  end

  def sorted(rows)
    if @sort == "rare"
      rows.sort_by { |r| [r.rarity ? 0 : 1, r.rarity || 0] }
    else
      rows.sort_by { |r| [r.rarity ? 0 : 1, -(r.rarity || 0)] }
    end
  end
end
```

- [ ] **Step 4: Run suite** — `bundle exec rspec` — Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add -A && git commit -m "feat: ReearnBacklog query with sorts and filters"
```

---

### Task 6: Transaction kinds (addon/subscription) + SecondCopies

**Files:**
- Modify: `app/models/psn_transaction.rb`, `app/services/sync/transactions.rb`
- Create: `app/queries/second_copies.rb`
- Test: `spec/models/psn_transaction_spec.rb` (extend), `spec/queries/second_copies_spec.rb`, existing transactions sync spec (extend)

**Interfaces:**
- Produces: `PsnTransaction::KINDS` = `%w[purchase addon subscription refund wallet]`; scopes `.addons`, `.subscriptions`, `.spend_kinds` (purchase+addon+subscription); `Sync::Transactions` classifies `add-on|dlc|addon` → `addon`, `subscription|ps.?plus|recurring` → `subscription` (checked before the purchase fallback).
- Produces: `SecondCopies.transaction_ids` → `Set<Integer>` of purchase transaction ids whose normalized description matches a normalized `game`-kind entitlement name on a *different* account (uses `MainOwnership.normalize`).

- [ ] **Step 1: Failing specs**

Append to `spec/models/psn_transaction_spec.rb`:

```ruby
it "supports addon and subscription kinds and a spend scope" do
  account = create(:account)
  %w[purchase addon subscription refund wallet].each_with_index do |kind, i|
    create(:psn_transaction, account:, kind:, psn_transaction_id: "k#{i}", amount_minor: 100)
  end
  expect(described_class.spend_kinds.count).to eq(3)
  expect(described_class.addons.count).to eq(1)
  expect(described_class.subscriptions.count).to eq(1)
end
```

```ruby
# spec/queries/second_copies_spec.rb
require "rails_helper"

RSpec.describe SecondCopies do
  it "flags purchases of games already owned on another account" do
    owner = create(:account)
    buyer = create(:account, label: "Main")
    create(:entitlement, account: owner, kind: "game", name: "Persona 5 Royal")
    dup = create(:psn_transaction, account: buyer, kind: "purchase", description: "Persona 5 Royal")
    fresh = create(:psn_transaction, account: buyer, kind: "purchase", description: "Stellar Blade",
                   psn_transaction_id: "other")
    own_repurchase = create(:psn_transaction, account: owner, kind: "purchase",
                            description: "Persona 5 Royal", psn_transaction_id: "own")

    ids = described_class.transaction_ids
    expect(ids).to include(dup.id)
    expect(ids).not_to include(fresh.id, own_repurchase.id)
  end
end
```

- [ ] **Step 2: Run, verify failure** — `bundle exec rspec spec/models/psn_transaction_spec.rb spec/queries/second_copies_spec.rb` — FAIL.

- [ ] **Step 3: Implement**

`app/models/psn_transaction.rb`: set `KINDS = %w[purchase addon subscription refund wallet].freeze`, add scopes:

```ruby
scope :addons, -> { where(kind: "addon") }
scope :subscriptions, -> { where(kind: "subscription") }
scope :spend_kinds, -> { where(kind: %w[purchase addon subscription]) }
```

`app/services/sync/transactions.rb`: add constants and extend `kind_for`:

```ruby
SUBSCRIPTION_TYPES = /subscription|ps.?plus|recurring/i
ADDON_TYPES = /add.?on|addon|dlc|iap|consumable/i

def kind_for(type)
  case type
  when REFUND_TYPES then "refund"
  when WALLET_TYPES then "wallet"
  when SUBSCRIPTION_TYPES then "subscription"
  when ADDON_TYPES then "addon"
  else "purchase"
  end
end
```

```ruby
# app/queries/second_copies.rb
# A purchase is a "2nd copy" when its item name matches a game entitlement
# that lives on a different account — i.e. the game was bought again for
# the re-earn run. Name matching is normalized-exact; personal-library
# scale, so in-memory is fine.
class SecondCopies
  def self.transaction_ids
    owners = Entitlement.games.pluck(:name, :account_id)
                        .group_by { |name, _| MainOwnership.normalize(name) }
                        .transform_values { |pairs| pairs.map(&:last).to_set }
    PsnTransaction.purchases.pluck(:id, :description, :account_id).filter_map { |id, desc, account_id|
      other = owners[MainOwnership.normalize(desc)]
      id if other && (other - [account_id]).any?
    }.to_set
  end
end
```

- [ ] **Step 4: Run suite** — `bundle exec rspec` — PASS (fix factory defaults if `:psn_transaction` lacks a description field default).

- [ ] **Step 5: Commit**

```bash
git add -A && git commit -m "feat: addon/subscription transaction kinds and 2nd-copy detection"
```

---

### Task 7: TrophySkipsController ("won't earn" toggle)

**Files:**
- Modify: `config/routes.rb`
- Create: `app/controllers/trophy_skips_controller.rb`, `app/views/reearn/_skip_button.html.erb`
- Test: `spec/requests/trophy_skips_spec.rb`

**Interfaces:**
- Produces routes: `POST /trophies/:trophy_id/skip` (`trophy_skip_path(trophy)`), `DELETE /trophies/:trophy_id/skip`.
- Produces partial `reearn/_skip_button` (local: `trophy`): renders a "won't earn" ghost button when not skipped, an underlined "undo" button when skipped. Both are `button_to` forms that redirect back; Turbo morph refresh (layout meta from Task 1) recomputes the page in place.

- [ ] **Step 1: Failing request spec**

```ruby
# spec/requests/trophy_skips_spec.rb
require "rails_helper"

RSpec.describe "Trophy skips" do
  it "creates and removes a skip, redirecting back" do
    trophy = create(:trophy)
    post trophy_skip_path(trophy), headers: { "HTTP_REFERER" => reearn_path }
    expect(response).to redirect_to(reearn_path)
    expect(trophy.reload).to be_skipped

    delete trophy_skip_path(trophy), headers: { "HTTP_REFERER" => reearn_path }
    expect(trophy.reload).not_to be_skipped
  end
end
```

- [ ] **Step 2: Run, verify failure** — FAIL (no route).

- [ ] **Step 3: Implement**

Routes — inside `Rails.application.routes.draw`:

```ruby
post "trophies/:trophy_id/skip", to: "trophy_skips#create", as: :trophy_skip
delete "trophies/:trophy_id/skip", to: "trophy_skips#destroy"
```

```ruby
# app/controllers/trophy_skips_controller.rb
class TrophySkipsController < ApplicationController
  def create
    trophy = Trophy.find(params[:trophy_id])
    TrophySkip.find_or_create_by!(trophy:)
    redirect_back fallback_location: reearn_path
  end

  def destroy
    TrophySkip.find_by(trophy_id: params[:trophy_id])&.destroy!
    redirect_back fallback_location: reearn_path
  end
end
```

```erb
<%# app/views/reearn/_skip_button.html.erb — locals: trophy %>
<% if trophy.skipped? %>
  <%= button_to "undo", trophy_skip_path(trophy), method: :delete,
        class: "font-mono text-xs text-skip underline hover:text-ink2" %>
<% else %>
  <%= button_to "won't earn", trophy_skip_path(trophy),
        class: "rounded-md border border-skipline px-2 py-1 text-xs text-skip hover:border-line3 hover:text-ink2" %>
<% end %>
```

- [ ] **Step 4: Run suite** — `bundle exec rspec` — PASS.

- [ ] **Step 5: Commit**

```bash
git add -A && git commit -m "feat: won't-earn skip toggle endpoints and button partial"
```

---

### Task 8: Dashboard screen (2a + mobile 2h)

Look at `screenshots/2a-dashboard.png` and `2h-mobile-dashboard.png` before writing markup.

**Files:**
- Modify: `app/controllers/dashboard_controller.rb`, `app/views/dashboard/show.html.erb`, `spec/requests/dashboard_spec.rb`

**Interfaces:**
- Consumes: `DashboardStats.call(main)` (Task 4), helpers (Task 1).
- Controller sets `@main = Account.current`, `@accounts` (main first), `@stats = DashboardStats.call(@main)` when `@main`.

- [ ] **Step 1: Failing request spec**

Replace `spec/requests/dashboard_spec.rb` expectations with (keep any setup helpers it has):

```ruby
require "rails_helper"

RSpec.describe "Dashboard" do
  it "shows the re-earn hero and account table" do
    main = create(:account, current: true, label: "Matty_Hunter", trophy_level: 512)
    alt = create(:account, label: "Matty_Legacy")
    game = create(:game)
    t = create(:trophy, game:)
    create(:account_trophy, account: alt, trophy: t, earned: true)

    get root_path
    expect(response.body).to include("Re-earned on Matty_Hunter")
    expect(response.body).to include("0.0") # hero percent
    expect(response.body).to include("Open checklist")
    expect(response.body).to include("UNIQUE TO ACCOUNT")
    expect(response.body).to include("Matty_Legacy")
  end

  it "redirects to first-run when no accounts exist" do
    get root_path
    expect(response).to redirect_to(new_account_path)
  end
end
```

- [ ] **Step 2: Run, verify failure** — FAIL.

- [ ] **Step 3: Controller**

```ruby
# app/controllers/dashboard_controller.rb
class DashboardController < ApplicationController
  def show
    redirect_to new_account_path and return if Account.none?

    @main = Account.current
    @accounts = Account.order(current: :desc, label: :asc)
    @stats = DashboardStats.call(@main) if @main
  end
end
```

- [ ] **Step 4: View**

Replace `app/views/dashboard/show.html.erb`. Structure (all tokens from Task 1; consult the PNG for proportions):

```erb
<% if @main.nil? %>
  <p class="text-mute">No main account set — <%= link_to "choose one in Accounts", accounts_path, class: "text-link underline hover:text-linkh" %>.</p>
<% else %>
  <% progress = @stats.progress %>
  <div class="text-xs uppercase tracking-[0.08em] text-mute">Re-earned on <%= @main.label %></div>

  <div class="mt-2 flex flex-wrap items-end justify-between gap-6">
    <div class="flex flex-wrap items-end gap-8">
      <div class="font-mono text-[56px] font-extrabold leading-none tracking-[-0.04em] lg:text-[72px]">
        <%= progress.percent %><span class="text-[28px] text-mute lg:text-[34px]">%</span>
      </div>
      <div class="hidden gap-8 pb-2 lg:flex">
        <div>
          <div class="font-mono text-xl font-semibold"><%= number_with_delimiter(progress.reearned) %></div>
          <div class="text-xs text-mute">of <%= number_with_delimiter(progress.total) %> trophies</div>
        </div>
        <div>
          <div class="font-mono text-xl font-semibold text-warn"><%= number_with_delimiter(progress.to_go) %></div>
          <div class="text-xs text-mute">to go</div>
        </div>
        <div>
          <div class="font-mono text-xl font-semibold"><%= number_with_delimiter(progress.games_left) %></div>
          <div class="text-xs text-mute">games left</div>
        </div>
      </div>
    </div>
    <%= link_to "Open checklist →", reearn_path, class: "pb-2 text-sm font-semibold text-link hover:text-linkh" %>
  </div>

  <div class="mt-5 h-2 w-full rounded-[4px] bg-raise">
    <div class="h-2 rounded-[4px] bg-gradient-to-r from-accent2 to-accent" style="width: <%= progress.percent %>%"></div>
  </div>

  <%# Mobile stat row %>
  <div class="mt-4 flex gap-6 lg:hidden">
    <div><span class="font-mono font-semibold"><%= number_with_delimiter(progress.reearned) %></span> <span class="text-xs text-mute">re-earned</span></div>
    <div><span class="font-mono font-semibold text-warn"><%= number_with_delimiter(progress.to_go) %></span> <span class="text-xs text-mute">to go</span></div>
    <div><span class="font-mono font-semibold"><%= number_with_delimiter(progress.games_left) %></span> <span class="text-xs text-mute">games</span></div>
  </div>

  <%# Account table %>
  <div class="mt-10 overflow-x-auto">
    <table class="w-full min-w-[640px] text-left text-sm">
      <thead>
        <tr class="text-[11px] uppercase tracking-[0.08em] text-faint">
          <th class="px-5 py-3 font-medium">Account</th>
          <th class="px-5 py-3 font-medium">Level</th>
          <th class="px-5 py-3 font-medium text-plat">Platinum</th>
          <th class="px-5 py-3 font-medium text-gold-t">Gold</th>
          <th class="px-5 py-3 font-medium text-silver-t">Silver</th>
          <th class="px-5 py-3 font-medium text-bronze-t">Bronze</th>
          <th class="px-5 py-3 text-right font-medium">Unique to account</th>
        </tr>
      </thead>
      <tbody>
        <% @accounts.each do |account| %>
          <tr class="<%= account.current? ? "rounded-lg border border-sel bg-card2" : "border-t border-line2" %>">
            <td class="px-5 py-4 font-bold <%= "text-navink" if account.current? %>">
              <% if account.current? %><span class="mr-1 text-accent">●</span><% end %>
              <%= account.label %>
              <% if account.current? %><span class="ml-1 rounded bg-navbg px-1.5 py-0.5 text-[10px] font-bold tracking-wide text-link">MAIN</span><% end %>
            </td>
            <td class="px-5 py-4 font-mono"><%= account.trophy_level || "—" %></td>
            <td class="px-5 py-4 font-mono"><%= number_with_delimiter(account.earned_platinum) %></td>
            <td class="px-5 py-4 font-mono"><%= number_with_delimiter(account.earned_gold) %></td>
            <td class="px-5 py-4 font-mono"><%= number_with_delimiter(account.earned_silver) %></td>
            <td class="px-5 py-4 font-mono"><%= number_with_delimiter(account.earned_bronze) %></td>
            <td class="px-5 py-4 text-right font-mono <%= account.current? ? "text-dash" : "text-warn" %>">
              <%= account.current? ? "—" : number_with_delimiter(@stats.unique_counts[account.id] || 0) %>
            </td>
          </tr>
        <% end %>
      </tbody>
    </table>
  </div>

  <%# Summary cards %>
  <div class="mt-8 grid gap-4 md:grid-cols-3">
    <div class="rounded-xl border border-line bg-card p-5">
      <div class="text-[11px] uppercase tracking-[0.08em] text-faint">Closest to done</div>
      <% if @stats.closest %>
        <div class="mt-1 font-bold"><%= @stats.closest.game.name %></div>
        <div class="mt-1 font-mono text-xs text-mute"><%= @stats.closest.reearned %> / <%= @stats.closest.total %> re-earned · <%= @stats.closest.left %> left</div>
      <% else %><div class="mt-1 text-mute">—</div><% end %>
    </div>
    <div class="rounded-xl border border-line bg-card p-5">
      <div class="text-[11px] uppercase tracking-[0.08em] text-faint">Biggest gap</div>
      <% if @stats.biggest_gap %>
        <div class="mt-1 font-bold"><%= @stats.biggest_gap.game.name %></div>
        <div class="mt-1 font-mono text-xs text-mute"><%= @stats.biggest_gap.reearned %> / <%= @stats.biggest_gap.total %> re-earned · from <%= @stats.biggest_gap.first_earned_labels.first %></div>
      <% else %><div class="mt-1 text-mute">—</div><% end %>
    </div>
    <div class="rounded-xl border border-line bg-card p-5">
      <div class="text-[11px] uppercase tracking-[0.08em] text-faint">Not owned on main</div>
      <div class="mt-1 font-bold"><%= @stats.not_owned_count %> games</div>
      <div class="mt-1 font-mono text-xs text-mute">need repurchase · <%= link_to "see Library", ownership_index_path, class: "text-link hover:text-linkh" %></div>
    </div>
  </div>
<% end %>
```

- [ ] **Step 5: Run suite** — `bundle exec rspec` — PASS (update any old dashboard spec assertions that referenced removed content).

- [ ] **Step 6: Visual check against PNG**

Run `bin/dev` briefly (or `bin/rails s`) with seeded/dev data if available; compare with `screenshots/2a-dashboard.png`. At minimum: `bin/rails tailwindcss:build` succeeds and page renders.

- [ ] **Step 7: Commit**

```bash
git add -A && git commit -m "feat: RE:EARN dashboard — hero, account table, summary cards"
```

---

### Task 9: Trophy comparison screen (2b)

Look at `screenshots/2b-trophy-comparison.png` first.

**Files:**
- Modify: `app/controllers/trophy_comparison_controller.rb`, `app/views/trophy_comparison/index.html.erb`, `spec/requests/trophy_comparison_spec.rb`
- Create: `app/javascript/controllers/autosubmit_controller.js`

**Interfaces:**
- Consumes: `_skip_button` partial (Task 7), helpers (Task 1).
- Controller: `index` picks `@game` from `params[:game_id]` (default: first game by name having trophies), `@accounts` main-first, `@filter` from `params[:filter]` in `%w[missing skipped everywhere]`, `@q` search string. Builds `@rows` = trophies of the game (matching `@q` in name) with per-account `AccountTrophy` lookup, plus counts for the chips.
- Stimulus `autosubmit` controller: `data-controller="autosubmit"` on a form; `data-action="change->autosubmit#submit"` submits it (used by the Change-game select and search field).

- [ ] **Step 1: Failing request spec**

```ruby
# spec/requests/trophy_comparison_spec.rb  (replace body)
require "rails_helper"

RSpec.describe "Trophy comparison" do
  let(:main) { create(:account, current: true, label: "Matty_Hunter") }
  let(:alt) { create(:account, label: "Matty_JPN") }
  let(:game) { create(:game, name: "Elden Ring") }

  before do
    earned = create(:trophy, game:, name: "Elden Lord")
    candidate = create(:trophy, game:, name: "Age of the Stars")
    [earned, candidate].each { |t| create(:account_trophy, account: alt, trophy: t, earned: true, earned_at: Time.zone.parse("2022-06-09 15:03")) }
    create(:account_trophy, account: main, trophy: earned, earned: true, earned_at: Time.zone.parse("2024-03-14 21:47"))
  end

  it "renders the per-trophy matrix with re-earn highlighting" do
    get trophy_comparison_index_path(game_id: game.id)
    expect(response.body).to include("Elden Ring")
    expect(response.body).to include("Matty_Hunter · main")
    expect(response.body).to include("RE-EARN")
    expect(response.body).to include("14 Mar 2024")
    expect(response.body).to include("21:47")
  end

  it "filters to missing-on-main" do
    get trophy_comparison_index_path(game_id: game.id, filter: "missing")
    expect(response.body).to include("Age of the Stars")
    expect(response.body).not_to include("Elden Lord")
  end
end
```

- [ ] **Step 2: Run, verify failure** — FAIL.

- [ ] **Step 3: Controller + Stimulus**

```ruby
# app/controllers/trophy_comparison_controller.rb
class TrophyComparisonController < ApplicationController
  FILTERS = %w[missing skipped everywhere].freeze

  def index
    @accounts = Account.order(current: :desc, label: :asc)
    @main = Account.current
    @games = Game.joins(:trophies).distinct.order(:name)
    @game = @games.find_by(id: params[:game_id]) || @games.first
    @filter = params[:filter].presence_in(FILTERS)
    @q = params[:q].to_s.strip
    return unless @game

    trophies = @game.trophies.includes(:skip).order(:psn_trophy_id)
    trophies = trophies.where("name LIKE ?", "%#{Trophy.sanitize_sql_like(@q)}%") if @q.present?
    earned = AccountTrophy.where(trophy: trophies, earned: true).index_by { |at| [at.trophy_id, at.account_id] }
    @rows = trophies.map { |trophy| row_for(trophy, earned) }
    @counts = counts
    @rows = @rows.select { |r| visible?(r) }
  end

  private

  Row = Data.define(:trophy, :earned_by, :candidate) # earned_by: {account_id => AccountTrophy}

  def row_for(trophy, earned)
    earned_by = @accounts.filter_map { |a| [a.id, earned[[trophy.id, a.id]]] if earned[[trophy.id, a.id]] }.to_h
    candidate = @main && !trophy.skipped? && earned_by.any? && !earned_by.key?(@main.id)
    Row.new(trophy:, earned_by:, candidate:)
  end

  def counts
    all = @game.trophies.includes(:skip).count
    { all:, missing: @rows.count(&:candidate),
      skipped: @rows.count { |r| r.trophy.skipped? },
      everywhere: @rows.count { |r| r.earned_by.size == @accounts.size && @accounts.any? } }
  end

  def visible?(row)
    case @filter
    when "missing" then row.candidate
    when "skipped" then row.trophy.skipped?
    when "everywhere" then row.earned_by.size == @accounts.size
    else true
    end
  end
end
```

```javascript
// app/javascript/controllers/autosubmit_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  submit() {
    this.element.requestSubmit()
  }
}
```

- [ ] **Step 4: View**

Replace `app/views/trophy_comparison/index.html.erb`:

```erb
<% if @game.nil? %>
  <p class="text-mute">No synced games yet.</p>
<% else %>
  <div class="flex flex-wrap items-start justify-between gap-4">
    <div>
      <div class="text-xs uppercase tracking-[0.08em] text-mute">Trophy comparison</div>
      <h1 class="mt-1 text-3xl font-extrabold tracking-[-0.03em] lg:text-[40px]"><%= @game.name %></h1>
    </div>
    <div class="flex gap-2">
      <%= form_with url: trophy_comparison_index_path, method: :get, data: { controller: "autosubmit" } do %>
        <%= select_tag :game_id, options_from_collection_for_select(@games, :id, :name, @game.id),
              class: "rounded-lg border border-line bg-card px-3 py-2 text-sm text-ink2",
              data: { action: "change->autosubmit#submit" } %>
      <% end %>
      <%= form_with url: trophy_comparison_index_path, method: :get do %>
        <%= hidden_field_tag :game_id, @game.id %>
        <%= text_field_tag :q, @q, placeholder: "Search trophies…",
              class: "w-40 rounded-lg border border-line bg-card px-3 py-2 text-sm text-ink2 placeholder:text-faint" %>
      <% end %>
    </div>
  </div>

  <% chips = [["All #{@counts[:all]}", nil], ["Missing on main · #{@counts[:missing]}", "missing"],
              ["Skipped · #{@counts[:skipped]}", "skipped"], ["Earned everywhere · #{@counts[:everywhere]}", "everywhere"]] %>
  <div class="mt-6 flex flex-wrap gap-2">
    <% chips.each do |label, value| %>
      <%= link_to label, trophy_comparison_index_path(game_id: @game.id, filter: value, q: @q.presence),
            class: chip_classes(@filter == value) %>
    <% end %>
  </div>

  <div class="mt-6 overflow-x-auto rounded-lg border border-line">
    <table class="w-full min-w-[900px] text-left text-sm">
      <thead class="bg-raise text-[11px] uppercase tracking-[0.08em] text-faint">
        <tr>
          <th class="px-5 py-3 font-medium">Trophy</th>
          <% @accounts.each do |account| %>
            <th class="px-5 py-3 font-medium <%= "font-bold text-ink2" if account.current? %>">
              <%= account.label %><%= " · main" if account.current? %>
            </th>
          <% end %>
        </tr>
      </thead>
      <tbody>
        <% @rows.each do |row| %>
          <% trophy = row.trophy %>
          <tr class="border-t border-line2 <%= "bg-hilite" if row.candidate %>">
            <td class="px-5 py-4">
              <div class="flex items-center gap-3">
                <span class="size-[26px] shrink-0 rounded-md border-2 <%= grade_border(trophy.trophy_type) %> <%= trophy.skipped? ? "opacity-45" : "" %> overflow-hidden">
                  <% if trophy.icon_url %><%= image_tag trophy.icon_url, class: "size-full object-cover", alt: "" %>
                  <% else %><span class="stripe-tile block size-full"></span><% end %>
                </span>
                <span class="font-semibold <%= "text-faint line-through" if trophy.skipped? %>"><%= trophy.name %></span>
                <% if trophy.skipped? %>
                  <span class="rounded border border-skipline px-1.5 py-0.5 text-[10px] font-bold tracking-wide text-skip">WON'T EARN</span>
                  <%= render "reearn/skip_button", trophy: %>
                <% elsif row.candidate %>
                  <span class="rounded bg-warnline px-1.5 py-0.5 text-[10px] font-bold tracking-wide text-warn">RE-EARN</span>
                  <%= render "reearn/skip_button", trophy: %>
                <% end %>
              </div>
            </td>
            <% @accounts.each do |account| %>
              <% at = row.earned_by[account.id] %>
              <td class="px-5 py-4 font-mono text-[13px]">
                <% if at.nil? %>
                  <span class="text-dash">—</span>
                <% elsif account.current? %>
                  <span class="inline-block rounded-md border border-okline bg-okbg px-2 py-1 text-ok">✓ <%= mono_date(at.earned_at) %></span>
                  <div class="mt-0.5 text-xs text-oktime"><%= mono_time(at.earned_at) %></div>
                <% else %>
                  <span class="text-ok"><%= mono_date(at.earned_at) %></span>
                  <div class="text-xs text-mute"><%= mono_time(at.earned_at) %></div>
                <% end %>
              </td>
            <% end %>
          </tr>
        <% end %>
      </tbody>
    </table>
  </div>
  <p class="mt-4 text-xs text-faint">Highlighted rows are re-earn candidates: earned on another account, still missing on <%= @main&.label || "the main account" %>.</p>
<% end %>
```

- [ ] **Step 5: Run suite** — `bundle exec rspec` — PASS.

- [ ] **Step 6: Commit**

```bash
git add -A && git commit -m "feat: per-trophy comparison matrix with filters and re-earn chips"
```

---

### Task 10: Checklist — by game (2c) and backlog (2d)

Look at `screenshots/2c-checklist-by-game.png`, `2d-checklist-backlog.png`, `2i-mobile-checklist.png` first.

**Files:**
- Modify: `app/controllers/reearn_controller.rb`, `config/routes.rb`, `app/views/reearn/show.html.erb`, `spec/requests/reearn_spec.rb`
- Create: `app/views/reearn/backlog.html.erb`, `app/views/reearn/_segmented.html.erb`

**Interfaces:**
- Consumes: `ReearnProgress` (Task 3), `ReearnBacklog` (Task 5), `MainOwnership` (Task 4), `_skip_button` (Task 7).
- Routes: `get "reearn", to: "reearn#show"` (existing) + `get "reearn/backlog", to: "reearn#backlog", as: :reearn_backlog`.
- `reearn#show`: `@result`, `@ownership`; supports `params[:filter]` in `%w[owned platinum skipped]` (owned-on-main-only / platinum-missing / skipped-only games) and default sort closest-to-done (already the `Result#games` order).
- `reearn#backlog`: `@rows = ReearnBacklog.call(main, sort:, filter:)`, `@skipped_count`.

- [ ] **Step 1: Failing request specs**

Replace `spec/requests/reearn_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe "Re-earn checklist" do
  let(:main) { create(:account, current: true) }
  let(:alt) { create(:account, label: "Matty_JPN") }
  let(:game) { create(:game, name: "Elden Ring") }

  before do
    done = create(:trophy, game:)
    missing = create(:trophy, game:, name: "Age of the Stars", rarity_percent: 14.2)
    [done, missing].each { |t| create(:account_trophy, account: alt, trophy: t, earned: true, earned_at: Time.zone.parse("2022-08-02")) }
    create(:account_trophy, account: main, trophy: done, earned: true, earned_at: Time.zone.parse("2024-01-11"))
  end

  it "renders the by-game checklist with progress and missing trophies" do
    get reearn_path
    expect(response.body).to include("games to finish")
    expect(response.body).to include("Elden Ring")
    expect(response.body).to include("1 / 2")
    expect(response.body).to include("1 left")
    expect(response.body).to include("Age of the Stars")
    expect(response.body).to include("won&#39;t earn")
  end

  it "renders the backlog ranked list" do
    get reearn_backlog_path
    expect(response.body).to include("trophies to go")
    expect(response.body).to include("Age of the Stars")
    expect(response.body).to include("14.2%")
    expect(response.body).to include("Matty_JPN")
  end
end
```

- [ ] **Step 2: Run, verify failure** — FAIL (`reearn_backlog_path` undefined).

- [ ] **Step 3: Routes + controller**

Routes: add `get "reearn/backlog", to: "reearn#backlog", as: :reearn_backlog` above the existing `get "reearn"` line.

```ruby
# app/controllers/reearn_controller.rb
class ReearnController < ApplicationController
  GAME_FILTERS = %w[owned platinum skipped].freeze
  BACKLOG_SORTS = %w[common rare].freeze
  BACKLOG_FILTERS = %w[platinum owned skipped].freeze

  def show
    return unless (@main = Account.current)

    @result = ReearnProgress.call(@main)
    @ownership = MainOwnership.call(@main)
    @filter = params[:filter].presence_in(GAME_FILTERS)
    @skipped_total = @result.games.sum(&:skipped)
    @games = filtered_games
  end

  def backlog
    return unless (@main = Account.current)

    @sort = params[:sort].presence_in(BACKLOG_SORTS) || "common"
    @filter = params[:filter].presence_in(BACKLOG_FILTERS)
    @rows = ReearnBacklog.call(@main, sort: @sort, filter: @filter)
    @to_go = ReearnBacklog.call(@main).size
    @skipped_count = TrophySkip.count
  end

  private

  def filtered_games
    games = @result.games.reject(&:complete?)
    case @filter
    when "owned" then games.select { |gp| @ownership.owned?(gp.game) }
    when "platinum" then games.select { |gp| gp.missing.any? { |m| !m.skipped && m.trophy.trophy_type == "platinum" } }
    when "skipped" then @result.games.select { |gp| gp.skipped.positive? }
    else games
    end
  end
end
```

- [ ] **Step 4: Segmented control partial + views**

```erb
<%# app/views/reearn/_segmented.html.erb — locals: active (:by_game | :backlog) %>
<div class="flex rounded-lg border border-line bg-card p-0.5 text-[13px]">
  <%= link_to "By game", reearn_path,
        class: "rounded-md px-3 py-1.5 #{active == :by_game ? 'bg-navbg font-bold text-navink' : 'text-mute hover:text-ink2'}" %>
  <%= link_to "Backlog", reearn_backlog_path,
        class: "rounded-md px-3 py-1.5 #{active == :backlog ? 'bg-navbg font-bold text-navink' : 'text-mute hover:text-ink2'}" %>
</div>
```

Replace `app/views/reearn/show.html.erb`:

```erb
<% if @main.nil? %>
  <p class="text-mute">No main account set — <%= link_to "choose one in Accounts", accounts_path, class: "text-link underline hover:text-linkh" %>.</p>
<% else %>
  <div class="flex flex-wrap items-end justify-between gap-4">
    <div>
      <div class="text-xs uppercase tracking-[0.08em] text-mute">Re-earn checklist</div>
      <h1 class="mt-1 text-3xl font-extrabold tracking-[-0.03em] lg:text-[40px]"><%= number_with_delimiter(@result.games_left) %> games to finish</h1>
    </div>
    <%= render "segmented", active: :by_game %>
  </div>

  <div class="mt-6 flex flex-wrap gap-2">
    <%= link_to "Sort: closest to done", reearn_path, class: chip_classes(@filter.nil?) %>
    <%= link_to "Owned on main only", reearn_path(filter: "owned"), class: chip_classes(@filter == "owned") %>
    <%= link_to "Platinum missing", reearn_path(filter: "platinum"), class: chip_classes(@filter == "platinum") %>
    <%= link_to "Skipped · #{@skipped_total}", reearn_path(filter: "skipped"), class: chip_classes(@filter == "skipped") %>
  </div>

  <div class="mt-6 space-y-3">
    <% @games.each do |gp| %>
      <details class="group rounded-xl border border-line bg-card open:border-line3 open:bg-card2">
        <summary class="flex cursor-pointer list-none flex-wrap items-center gap-4 px-5 py-4 [&::-webkit-details-marker]:hidden">
          <span class="size-11 shrink-0 overflow-hidden rounded-lg">
            <% if gp.game.icon_url %><%= image_tag gp.game.icon_url, class: "size-full object-cover", alt: "" %>
            <% else %><span class="stripe-tile block size-full"></span><% end %>
          </span>
          <span class="min-w-0 flex-1">
            <span class="flex items-center gap-2 font-bold">
              <%= gp.game.name %>
              <span class="text-xs font-medium text-faint"><%= gp.game.platform %></span>
              <% unless @ownership.owned?(gp.game) %>
                <span class="rounded border border-errline bg-errbg px-1.5 py-0.5 text-[10px] font-bold tracking-wide text-err">NOT OWNED ON MAIN</span>
              <% end %>
            </span>
            <span class="mt-0.5 block truncate text-xs text-mute">first earned on <%= gp.first_earned_labels.first(2).join(" · ") %></span>
          </span>
          <span class="hidden w-[280px] shrink-0 md:block">
            <span class="flex justify-between font-mono text-xs text-mute">
              <span><%= gp.reearned %> / <%= gp.total %><%= " · #{gp.skipped} skipped" if gp.skipped.positive? %></span>
              <span class="text-accent"><%= gp.percent %>%</span>
            </span>
            <span class="mt-1.5 block h-[5px] rounded-[3px] bg-raise">
              <span class="block h-[5px] rounded-[3px] bg-accent" style="width: <%= gp.percent %>%"></span>
            </span>
          </span>
          <span class="shrink-0 font-mono text-sm font-semibold text-warn"><%= gp.left %> left</span>
          <span class="shrink-0 text-faint group-open:rotate-180">▾</span>
        </summary>
        <div class="border-t border-line2 px-5 py-2">
          <% gp.missing.each do |m| %>
            <div class="flex flex-wrap items-center gap-3 border-b border-line2 py-3 last:border-b-0">
              <% if m.skipped %>
                <span class="w-[18px] text-center text-faint">⊘</span>
              <% else %>
                <span class="size-[18px] rounded border border-line3"></span>
              <% end %>
              <span class="size-[26px] shrink-0 overflow-hidden rounded-md border-2 <%= grade_border(m.trophy.trophy_type) %> <%= "opacity-45" if m.skipped %>">
                <% if m.trophy.icon_url %><%= image_tag m.trophy.icon_url, class: "size-full object-cover", alt: "" %>
                <% else %><span class="stripe-tile block size-full"></span><% end %>
              </span>
              <span class="min-w-0 flex-1 text-sm">
                <span class="font-semibold <%= "text-faint line-through" if m.skipped %>"><%= m.trophy.name %></span>
                <% if m.trophy.detail.present? %><span class="text-mute"> — <%= m.trophy.detail %></span><% end %>
              </span>
              <% if m.skipped %>
                <span class="rounded border border-skipline px-1.5 py-0.5 text-[10px] font-bold tracking-wide text-skip">WON'T EARN</span>
              <% end %>
              <span class="font-mono text-xs text-mute"><%= m.first_earned_at&.strftime("%b %Y") %> · <%= m.first_earned_label %></span>
              <%= render "skip_button", trophy: m.trophy %>
            </div>
          <% end %>
        </div>
      </details>
    <% end %>
  </div>
<% end %>
```

Create `app/views/reearn/backlog.html.erb`:

```erb
<% if @main.nil? %>
  <p class="text-mute">No main account set — <%= link_to "choose one in Accounts", accounts_path, class: "text-link underline hover:text-linkh" %>.</p>
<% else %>
  <div class="flex flex-wrap items-end justify-between gap-4">
    <div>
      <div class="text-xs uppercase tracking-[0.08em] text-mute">Re-earn checklist</div>
      <h1 class="mt-1 text-3xl font-extrabold tracking-[-0.03em] lg:text-[40px]"><%= number_with_delimiter(@to_go) %> trophies to go</h1>
    </div>
    <%= render "segmented", active: :backlog %>
  </div>

  <div class="mt-6 flex flex-wrap gap-2">
    <%= link_to "Sort: most common first", reearn_backlog_path, class: chip_classes(@sort == "common" && @filter.nil?) %>
    <%= link_to "Rarest first", reearn_backlog_path(sort: "rare"), class: chip_classes(@sort == "rare" && @filter.nil?) %>
    <%= link_to "Platinums only", reearn_backlog_path(filter: "platinum"), class: chip_classes(@filter == "platinum") %>
    <%= link_to "Owned on main", reearn_backlog_path(filter: "owned"), class: chip_classes(@filter == "owned") %>
    <%= link_to "Skipped · #{@skipped_count}", reearn_backlog_path(filter: "skipped"), class: chip_classes(@filter == "skipped") %>
  </div>

  <div class="mt-6 overflow-x-auto rounded-lg border border-line">
    <table class="w-full min-w-[820px] text-left text-sm">
      <thead class="bg-raise text-[11px] uppercase tracking-[0.08em] text-faint">
        <tr>
          <th class="px-5 py-3 font-medium">#</th>
          <th class="px-5 py-3 font-medium">Trophy</th>
          <th class="px-5 py-3 font-medium">Game</th>
          <th class="px-5 py-3 font-medium">First earned</th>
          <th class="px-5 py-3 font-medium">Rarity</th>
          <th class="px-5 py-3 text-right font-medium">Owned on main</th>
        </tr>
      </thead>
      <tbody>
        <% @rows.each_with_index do |row, i| %>
          <tr class="border-t border-line2">
            <td class="px-5 py-3.5 font-mono text-xs text-faint"><%= format("%03d", i + 1) %></td>
            <td class="px-5 py-3.5">
              <div class="flex items-center gap-3">
                <span class="size-[26px] shrink-0 overflow-hidden rounded-md border-2 <%= grade_border(row.trophy.trophy_type) %>">
                  <% if row.trophy.icon_url %><%= image_tag row.trophy.icon_url, class: "size-full object-cover", alt: "" %>
                  <% else %><span class="stripe-tile block size-full"></span><% end %>
                </span>
                <span class="font-semibold"><%= row.trophy.name %></span>
              </div>
            </td>
            <td class="px-5 py-3.5 text-mute"><%= row.game.name %></td>
            <td class="px-5 py-3.5 font-mono text-xs text-mute"><%= row.first_earned_at&.year %> · <%= row.first_earned_label %></td>
            <td class="px-5 py-3.5 font-mono text-xs <%= row.rarity.nil? ? "text-dash" : row.rarity < 5 ? "text-err" : row.rarity < 35 ? "text-warn" : "text-ok" %>">
              <%= row.rarity ? "#{row.rarity}%" : "—" %>
            </td>
            <td class="px-5 py-3.5 text-right font-mono text-xs <%= row.owned_on_main ? "text-ok" : "text-err" %>">
              <%= row.owned_on_main ? "yes" : "no" %>
            </td>
          </tr>
        <% end %>
      </tbody>
    </table>
  </div>
<% end %>
```

- [ ] **Step 5: Run suite** — `bundle exec rspec` — PASS.

- [ ] **Step 6: Commit**

```bash
git add -A && git commit -m "feat: re-earn checklist by-game and backlog screens with skip integration"
```

---

### Task 11: Purchases screen (2e)

Look at `screenshots/2e-purchases.png` first.

**Files:**
- Modify: `app/controllers/spend_controller.rb`, `app/views/spend/index.html.erb`, `spec/requests/spend_spec.rb`

**Interfaces:**
- Consumes: `SecondCopies.transaction_ids`, `PsnTransaction.spend_kinds` (Task 6), `format_money` (existing helper), helpers (Task 1).
- Controller sets: `@lifetime` = `{currency => net_minor}` (spend_kinds − refunds), `@by_account` = `[[account, {currency => net_minor}], …]` main first, `@transactions` (filtered, newest first, limit 200), `@second_copy_ids`, `@filter` in `%w[games twice refunds]`.

- [ ] **Step 1: Failing request spec**

Replace `spec/requests/spend_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe "Purchases" do
  let(:main) { create(:account, current: true, label: "Matty_Hunter") }
  let(:alt) { create(:account, label: "CoOpCouch") }

  before do
    create(:entitlement, account: alt, kind: "game", name: "Persona 5 Royal")
    create(:psn_transaction, account: main, kind: "purchase", description: "Persona 5 Royal",
           amount_minor: 1999, currency: "GBP", occurred_at: Time.zone.parse("2026-04-22"))
    create(:psn_transaction, account: main, kind: "refund", description: "Stellar Blade",
           amount_minor: 5999, currency: "GBP", occurred_at: Time.zone.parse("2026-04-30"),
           psn_transaction_id: "r1")
  end

  it "shows lifetime spend, the ledger, and 2nd-copy highlighting" do
    get spend_index_path
    expect(response.body).to include("Lifetime spend")
    expect(response.body).to include("£19.99")
    expect(response.body).to include("2ND COPY")
    expect(response.body).to include("refund")
    expect(response.body).to include("−£59.99")
  end

  it "filters to bought-twice rows" do
    get spend_index_path(filter: "twice")
    expect(response.body).to include("Persona 5 Royal")
    expect(response.body).not_to include("Stellar Blade")
  end
end
```

- [ ] **Step 2: Run, verify failure** — FAIL.

- [ ] **Step 3: Controller**

```ruby
# app/controllers/spend_controller.rb
class SpendController < ApplicationController
  FILTERS = %w[games twice refunds].freeze

  def index
    @filter = params[:filter].presence_in(FILTERS)
    @second_copy_ids = SecondCopies.transaction_ids
    @lifetime = net_by_currency(PsnTransaction.all)
    @by_account = Account.order(current: :desc, label: :asc)
                         .map { |a| [a, net_by_currency(a.psn_transactions)] }
    @transactions = filtered.order(occurred_at: :desc).includes(:account).limit(200)
  end

  private

  def net_by_currency(scope)
    spend = scope.spend_kinds.group(:currency).sum(:amount_minor)
    refunds = scope.refunds.group(:currency).sum(:amount_minor)
    spend.merge(refunds.transform_values(&:-@)) { |_, s, r| s + r }.compact
  end

  def filtered
    case @filter
    when "games" then PsnTransaction.purchases
    when "twice" then PsnTransaction.where(id: @second_copy_ids.to_a)
    when "refunds" then PsnTransaction.refunds
    else PsnTransaction.all
    end
  end
end
```

- [ ] **Step 4: View**

Replace `app/views/spend/index.html.erb`:

```erb
<div class="text-xs uppercase tracking-[0.08em] text-mute">Lifetime spend · All accounts</div>
<div class="mt-2 flex flex-wrap items-end gap-10">
  <div class="font-mono text-[56px] font-extrabold leading-none tracking-[-0.04em] lg:text-[72px]">
    <% if @lifetime.any? %>
      <% currency, amount = @lifetime.max_by { |_, v| v } %>
      <%= format_money(amount, currency) %>
    <% else %>—<% end %>
  </div>
  <div class="flex flex-wrap gap-8 pb-2">
    <% @by_account.each do |account, totals| %>
      <div>
        <div class="font-mono text-lg font-semibold">
          <%= totals.any? ? totals.map { |cur, amt| format_money(amt, cur) }.join(" · ") : "—" %>
        </div>
        <div class="text-xs text-mute"><%= account.label %></div>
      </div>
    <% end %>
  </div>
</div>

<div class="mt-8 flex flex-wrap gap-2">
  <%= link_to "All accounts", spend_index_path, class: chip_classes(@filter.nil?) %>
  <%= link_to "Games only", spend_index_path(filter: "games"), class: chip_classes(@filter == "games") %>
  <%= link_to "Bought twice · #{@second_copy_ids.size}", spend_index_path(filter: "twice"), class: chip_classes(@filter == "twice") %>
  <%= link_to "Refunds", spend_index_path(filter: "refunds"), class: chip_classes(@filter == "refunds") %>
</div>

<div class="mt-6 overflow-x-auto rounded-lg border border-line">
  <table class="w-full min-w-[760px] text-left text-sm">
    <thead class="bg-raise text-[11px] uppercase tracking-[0.08em] text-faint">
      <tr>
        <th class="px-5 py-3 font-medium">Date</th>
        <th class="px-5 py-3 font-medium">Item</th>
        <th class="px-5 py-3 font-medium">Account</th>
        <th class="px-5 py-3 font-medium">Type</th>
        <th class="px-5 py-3 text-right font-medium">Amount</th>
      </tr>
    </thead>
    <tbody>
      <% @transactions.each do |txn| %>
        <% second_copy = @second_copy_ids.include?(txn.id) %>
        <tr class="border-t border-line2 <%= "bg-hilite" if second_copy %>">
          <td class="px-5 py-3.5 font-mono text-xs text-mute"><%= mono_date(txn.occurred_at) %></td>
          <td class="px-5 py-3.5 font-semibold">
            <%= txn.description %>
            <% if second_copy %>
              <span class="ml-1 rounded bg-warnline px-1.5 py-0.5 text-[10px] font-bold tracking-wide text-warn">2ND COPY</span>
            <% end %>
          </td>
          <td class="px-5 py-3.5 font-mono text-xs text-mute"><%= txn.account.label %></td>
          <td class="px-5 py-3.5 font-mono text-xs <%= { "wallet" => "text-link", "refund" => "text-err" }.fetch(txn.kind, "text-mute") %>">
            <%= txn.kind == "addon" ? "add-on" : txn.kind %>
          </td>
          <td class="px-5 py-3.5 text-right font-mono text-[15px] <%= txn.kind == "wallet" ? "text-ok" : txn.kind == "refund" ? "text-err" : "" %>">
            <% if txn.kind == "wallet" %>+<%= format_money(txn.amount_minor, txn.currency) %>
            <% elsif txn.kind == "refund" %>−<%= format_money(txn.amount_minor, txn.currency) %>
            <% else %><%= format_money(txn.amount_minor, txn.currency) %><% end %>
          </td>
        </tr>
      <% end %>
    </tbody>
  </table>
</div>
<p class="mt-4 text-xs text-faint">Highlighted rows are re-purchases — games bought again on the main account for the re-earn run.</p>
```

Note: `SpendSummary` remains for anything else that uses it; if nothing does after this task (check with `grep -rn "SpendSummary" app spec`), delete `app/queries/spend_summary.rb` + its spec.

- [ ] **Step 5: Run suite** — `bundle exec rspec` — PASS.

- [ ] **Step 6: Commit**

```bash
git add -A && git commit -m "feat: purchases ledger with lifetime hero, kind styling, 2nd-copy chips"
```

---

### Task 12: Library screen (2f)

Look at `screenshots/2f-library.png` first.

**Files:**
- Modify: `app/controllers/ownership_controller.rb`, `app/queries/ownership_matrix.rb`, `app/views/ownership/index.html.erb`, `spec/queries/ownership_matrix_spec.rb`, `spec/requests/ownership_spec.rb`

**Interfaces:**
- Consumes: `MainOwnership.normalize`, `ReearnProgress` (per-game candidate counts).
- `OwnershipMatrix.call(include_dlc: false)` unchanged shape (`Row(name, platform, by_account_id)`), plus new member `reearn_count` (Integer or nil): candidates (missing-on-main, unskipped) for the game whose normalized name prefix-matches this row's normalized name. Extend `call` to accept `main:` keyword (nil-safe).
- Controller: `@filter` in `%w[not_owned twice]`, `@q` search, `@main`.

- [ ] **Step 1: Failing specs**

Append to `spec/queries/ownership_matrix_spec.rb`:

```ruby
it "annotates rows with re-earn candidate counts for the main account" do
  main = create(:account, current: true)
  alt = create(:account)
  game = create(:game, name: "Yakuza 0")
  create(:account_trophy, account: alt, trophy: create(:trophy, game:), earned: true)
  create(:entitlement, account: alt, kind: "game", name: "Yakuza 0")

  row = described_class.call(main: main).find { |r| r.name == "Yakuza 0" }
  expect(row.reearn_count).to eq(1)
end
```

Replace `spec/requests/ownership_spec.rb` body:

```ruby
require "rails_helper"

RSpec.describe "Library" do
  it "renders the ownership matrix with legend and re-earn column" do
    main = create(:account, current: true, label: "Hunter")
    create(:entitlement, account: main, kind: "game", name: "Journey")
    get ownership_index_path
    expect(response.body).to include("across")
    expect(response.body).to include("To re-earn here")
    expect(response.body).to include("Journey")
    expect(response.body).to include("owned")
  end
end
```

- [ ] **Step 2: Run, verify failure** — FAIL.

- [ ] **Step 3: Extend OwnershipMatrix**

```ruby
# app/queries/ownership_matrix.rb
# Titles × accounts grid built from entitlements. In-memory grouping is fine
# at personal-library scale (a few thousand rows).
class OwnershipMatrix
  Row = Data.define(:name, :platform, :by_account_id, :reearn_count) do
    def duplicate? = by_account_id.size > 1
  end

  def self.call(include_dlc: false, main: nil)
    counts = main ? candidate_counts(main) : {}
    scope = include_dlc ? Entitlement.where(kind: %w[game dlc]) : Entitlement.games
    scope.group_by(&:product_key).map { |_, ents|
      name = ents.first.name
      Row.new(name:, platform: ents.first.platform,
              by_account_id: ents.index_by(&:account_id),
              reearn_count: counts[MainOwnership.normalize(name)])
    }.sort_by { |row| row.name.to_s.downcase }
  end

  # {normalized game name => number of unskipped missing-on-main trophies}
  def self.candidate_counts(main)
    ReearnProgress.call(main).games.each_with_object({}) do |gp, acc|
      count = gp.missing.count { |m| !m.skipped }
      acc[MainOwnership.normalize(gp.game.name)] = count if count.positive?
    end
  end
end
```

The row's `reearn_count` lookup key is the entitlement name normalized — a game named "Yakuza 0" matches entitlement "Yakuza 0"; for edition-suffixed entitlements fall back: when no exact hit, try prefix match in the view? No — keep it in the query: after building `counts`, resolve `counts[norm] || counts.find { |k, _| norm.start_with?(k) }&.last`. Implement exactly that in a small private helper `count_for(counts, norm)` used in `call`.

- [ ] **Step 4: Controller + view**

```ruby
# app/controllers/ownership_controller.rb
class OwnershipController < ApplicationController
  FILTERS = %w[not_owned twice].freeze

  def index
    @main = Account.current
    @accounts = Account.order(current: :desc, label: :asc)
    @filter = params[:filter].presence_in(FILTERS)
    @q = params[:q].to_s.strip
    rows = OwnershipMatrix.call(include_dlc: params[:include_dlc].present?, main: @main)
    rows = rows.select { |r| r.name.to_s.downcase.include?(@q.downcase) } if @q.present?
    @rows = filtered(rows)
  end

  private

  def filtered(rows)
    case @filter
    when "not_owned" then rows.reject { |r| @main && r.by_account_id.key?(@main.id) }
    when "twice" then rows.select(&:duplicate?)
    else rows
    end
  end
end
```

Replace `app/views/ownership/index.html.erb`:

```erb
<div class="flex flex-wrap items-start justify-between gap-4">
  <div>
    <div class="text-xs uppercase tracking-[0.08em] text-mute">Library comparison</div>
    <h1 class="mt-1 text-3xl font-extrabold tracking-[-0.03em] lg:text-[40px]">
      <%= number_with_delimiter(@rows.size) %> games across <%= @accounts.size %> accounts
    </h1>
  </div>
  <%= form_with url: ownership_index_path, method: :get do %>
    <%= text_field_tag :q, @q, placeholder: "Search library…",
          class: "w-44 rounded-lg border border-line bg-card px-3 py-2 text-sm text-ink2 placeholder:text-faint" %>
  <% end %>
</div>

<div class="mt-6 flex flex-wrap items-center justify-between gap-3">
  <div class="flex flex-wrap gap-2">
    <%= link_to "All", ownership_index_path, class: chip_classes(@filter.nil?) %>
    <%= link_to "Not owned on main", ownership_index_path(filter: "not_owned"), class: chip_classes(@filter == "not_owned") %>
    <%= link_to "Owned twice", ownership_index_path(filter: "twice"), class: chip_classes(@filter == "twice") %>
  </div>
  <div class="flex gap-4 text-xs text-mute">
    <span><span class="text-ok">●</span> owned</span>
    <span><span class="text-dash">○</span> not owned</span>
  </div>
</div>

<div class="mt-6 overflow-x-auto rounded-lg border border-line">
  <table class="w-full min-w-[820px] text-left text-sm">
    <thead class="bg-raise text-[11px] uppercase tracking-[0.08em] text-faint">
      <tr>
        <th class="px-5 py-3 font-medium">Game</th>
        <% @accounts.each do |account| %>
          <th class="px-5 py-3 text-center font-medium"><%= account.label.sub(/\AMatty_/, "") %></th>
        <% end %>
        <th class="px-5 py-3 text-right font-medium">To re-earn here</th>
      </tr>
    </thead>
    <tbody>
      <% @rows.each do |row| %>
        <tr class="border-t border-line2">
          <td class="px-5 py-3.5 font-semibold"><%= row.name %></td>
          <% @accounts.each do |account| %>
            <td class="px-5 py-3.5 text-center">
              <% if row.by_account_id.key?(account.id) %><span class="text-ok">●</span>
              <% else %><span class="text-dash">○</span><% end %>
            </td>
          <% end %>
          <td class="px-5 py-3.5 text-right font-mono text-xs <%= row.reearn_count ? "text-warn" : "text-dash" %>">
            <%= row.reearn_count ? "#{row.reearn_count} #{"trophy".pluralize(row.reearn_count)}" : "—" %>
          </td>
        </tr>
      <% end %>
    </tbody>
  </table>
</div>
```

(Degradation per Global Constraints: no PS Plus ◐ state, no prices, no delisted chips, no cost-to-complete footer.)

- [ ] **Step 5: Run suite** — `bundle exec rspec` — PASS.

- [ ] **Step 6: Commit**

```bash
git add -A && git commit -m "feat: library matrix with ownership dots and to-re-earn-here column"
```

---

### Task 13: Accounts screen (2g) + first-run (3a)

Look at `screenshots/2g-accounts.png` and `3a-first-run.png` first.

**Files:**
- Modify: `app/controllers/accounts_controller.rb`, `app/views/accounts/index.html.erb`, `app/views/accounts/new.html.erb`, `spec/requests/accounts_spec.rb`
- Create: `app/views/accounts/_link_panel.html.erb`

**Interfaces:**
- `accounts#new` sets `@bare = true` when `Account.none?` (full-screen first-run, 3a); otherwise redirects to `accounts_path` (the link panel lives on index).
- `_link_panel` partial: NPSSO explainer + label + token form posting to `accounts_path` (reuses existing create action).

- [ ] **Step 1: Failing request specs**

Append to `spec/requests/accounts_spec.rb` (keep existing create/destroy specs — they still apply):

```ruby
describe "redesigned index" do
  it "shows account cards with roles and the link panel" do
    create(:account, current: true, label: "Matty_Hunter")
    create(:account, label: "Matty_JPN", needs_reauth: true)
    get accounts_path
    expect(response.body).to include("2 linked")
    expect(response.body).to include("MAIN — re-earn target")
    expect(response.body).to include("Re-link now")
    expect(response.body).to include("Link a new account")
    expect(response.body).to include("Sync schedule")
  end
end

describe "first run" do
  it "renders the bare first-run page when no accounts exist" do
    get new_account_path
    expect(response.body).to include("Link your first PSN account")
    expect(response.body).not_to include("Dashboard") # no sidebar
  end

  it "redirects new to index once accounts exist" do
    create(:account)
    get new_account_path
    expect(response).to redirect_to(accounts_path)
  end
end
```

- [ ] **Step 2: Run, verify failure** — FAIL.

- [ ] **Step 3: Controller tweak**

In `AccountsController#new`:

```ruby
def new
  redirect_to accounts_path and return if Account.exists?

  @bare = true
  @label = nil
end
```

In `#create`, when re-rendering `:new` after an error set `@bare = Account.none?`.

- [ ] **Step 4: Views**

Create `app/views/accounts/_link_panel.html.erb`:

```erb
<div class="rounded-xl border border-line3 bg-card2 p-6">
  <h2 class="text-[17px] font-bold">Link a new account</h2>
  <p class="mt-2 text-[13px] leading-relaxed text-mute">
    Sign in to playstation.com with the account you want to add, then paste your NPSSO token below.
    Tokens last about two months; we store only the rotating refresh token.
  </p>
  <%= form_with url: accounts_path, scope: :account, class: "mt-4 space-y-3" do |f| %>
    <div>
      <label class="text-[11px] uppercase tracking-[0.08em] text-faint">Label</label>
      <%= f.text_field :label, value: @label, required: true, placeholder: "e.g. Matty_Vita",
            class: "mt-1 w-full rounded-lg border border-line bg-card px-3 py-2 font-mono text-sm text-ink2 placeholder:text-faint" %>
    </div>
    <div>
      <label class="text-[11px] uppercase tracking-[0.08em] text-faint">NPSSO token</label>
      <%= f.password_field :npsso, required: true, placeholder: "paste token…",
            class: "mt-1 w-full rounded-lg border border-line bg-card px-3 py-2 font-mono text-sm text-ink2 placeholder:text-faint" %>
    </div>
    <%= f.submit "Link account", class: "w-full cursor-pointer rounded-lg border border-sel bg-btn px-4 py-2.5 text-sm font-bold text-navink hover:bg-btnh" %>
  <% end %>
  <a href="https://ca.account.sony.com/api/v1/ssocookie" target="_blank" rel="noopener"
     class="mt-3 inline-block text-[13px] text-link hover:text-linkh">How do I get my NPSSO token? →</a>
</div>
```

Replace `app/views/accounts/index.html.erb`:

```erb
<div class="text-xs uppercase tracking-[0.08em] text-mute">Accounts</div>
<h1 class="mt-1 text-3xl font-extrabold tracking-[-0.03em] lg:text-[40px]"><%= @accounts.size %> linked</h1>

<div class="mt-8 grid gap-8 lg:grid-cols-[1fr_360px]">
  <div class="space-y-3">
    <% @accounts.each do |account| %>
      <% card = account.needs_reauth? ? "border-warnline bg-warnbg" : account.current? ? "border-sel bg-card2" : "border-line bg-card" %>
      <div class="rounded-xl border <%= card %> p-5">
        <div class="flex flex-wrap items-center gap-4">
          <span class="flex size-10 items-center justify-center overflow-hidden rounded-full bg-navbg font-mono text-sm font-semibold text-navink">
            <% if account.avatar_url %><%= image_tag account.avatar_url, class: "size-full object-cover", alt: "" %>
            <% else %><%= initials(account.label) %><% end %>
          </span>
          <div class="min-w-0 flex-1">
            <div class="flex items-center gap-2 font-bold">
              <%= account.label %>
              <% if account.current? %>
                <span class="text-[10px] font-bold tracking-wide text-link">MAIN — re-earn target</span>
              <% end %>
            </div>
            <div class="mt-1 font-mono text-xs <%= account.needs_reauth? ? "text-warn" : "text-oktime" %>">
              <% if account.needs_reauth? %>▲ NPSSO token expired — re-link to keep syncing
              <% else %>● token healthy · refreshes automatically<% end %>
            </div>
          </div>
          <div class="flex items-center gap-3 text-[13px]">
            <% if account.needs_reauth? %>
              <span class="rounded-lg border border-warnline bg-btnwarn px-3 py-1.5 font-bold text-warnink">Re-link below</span>
            <% else %>
              <span class="font-mono text-xs text-faint">synced <%= relative_sync(account.last_synced_at) %></span>
              <%= button_to "Sync now", sync_account_path(account), class: "text-link hover:text-linkh" %>
              <% unless account.current? %>
                <%= button_to "Set as main", make_current_account_path(account), method: :patch, class: "text-link hover:text-linkh" %>
              <% end %>
            <% end %>
            <%= button_to "Unlink", account_path(account), method: :delete,
                  data: { turbo_confirm: "Remove #{account.label} and all its synced data?" },
                  class: "text-mute hover:text-err" %>
          </div>
        </div>
        <% if account.needs_reauth? %>
          <%= form_with url: reauth_account_path(account), method: :patch, class: "mt-4 flex gap-2" do |f| %>
            <%= f.password_field :npsso, placeholder: "fresh NPSSO token…", required: true,
                  class: "flex-1 rounded-lg border border-warnline bg-card px-3 py-2 font-mono text-sm text-ink2 placeholder:text-faint" %>
            <%= f.submit "Re-link now", class: "cursor-pointer rounded-lg border border-warnline bg-btnwarn px-4 py-2 text-sm font-bold text-warnink" %>
          <% end %>
        <% end %>
        <div class="mt-3 flex flex-wrap gap-4 font-mono text-xs text-faint">
          <% account.sync_runs.latest_per_kind.each do |kind, run| %>
            <span><%= kind %>: <%= run.status %><%= " — #{run.error_message}" if run.error_message.present? %></span>
          <% end %>
        </div>
      </div>
    <% end %>
  </div>

  <div class="space-y-4">
    <%= render "link_panel" %>
    <div class="rounded-xl border border-line bg-card p-5">
      <h3 class="text-sm font-bold">Sync schedule</h3>
      <div class="mt-2 font-mono text-xs leading-relaxed text-mute">
        every 30 min · trophies + purchases<br>
        rate-limit aware · retries after 429
      </div>
    </div>
  </div>
</div>
```

Replace `app/views/accounts/new.html.erb` (bare first-run, 3a):

```erb
<span class="flex size-11 items-center justify-center rounded-xl bg-gradient-to-br from-accent2 to-[#7B4DE0] text-lg font-extrabold">R</span>
<h1 class="mt-6 text-3xl font-extrabold tracking-[-0.03em] lg:text-[40px]">Link your first PSN account</h1>
<p class="mt-3 text-sm leading-relaxed text-mute">
  RE:EARN pulls trophies, purchases and libraries from every account you link, then builds one
  checklist: every trophy you've ever earned, re-earned on the account you choose.
</p>
<ol class="mt-6 space-y-2 text-sm">
  <li><span class="mr-3 font-mono text-link">1</span>Sign in at playstation.com with the account to add</li>
  <li><span class="mr-3 font-mono text-link">2</span>Open the ssocookie page and copy your NPSSO token</li>
  <li><span class="mr-3 font-mono text-link">3</span>Paste it below — we keep only the rotating refresh token</li>
</ol>
<%= form_with url: accounts_path, scope: :account, class: "mt-6" do |f| %>
  <%= f.text_field :label, value: @label, required: true, placeholder: "label (e.g. Matty_Hunter)",
        class: "mb-2 w-full rounded-lg border border-line bg-card px-3 py-2.5 font-mono text-sm text-ink2 placeholder:text-faint" %>
  <div class="flex gap-2">
    <%= f.password_field :npsso, required: true, placeholder: "paste NPSSO token…",
          class: "flex-1 rounded-lg border border-line bg-card px-3 py-2.5 font-mono text-sm text-ink2 placeholder:text-faint" %>
    <%= f.submit "Link account", class: "cursor-pointer rounded-lg border border-sel bg-btn px-5 py-2.5 text-sm font-bold text-navink hover:bg-btnh" %>
  </div>
<% end %>
<p class="mt-4 text-xs text-faint">
  Tokens last about two months.
  <a href="https://ca.account.sony.com/api/v1/ssocookie" target="_blank" rel="noopener" class="text-link hover:text-linkh">Where do I find my NPSSO token?</a>
</p>
```

- [ ] **Step 5: Run suite** — `bundle exec rspec` — PASS (existing accounts request specs may reference removed copy — update assertions, keep behavior coverage).

- [ ] **Step 6: Commit**

```bash
git add -A && git commit -m "feat: accounts management screen and first-run onboarding"
```

---

### Task 14: Error states (3c) + first-sync status (3b, degraded)

Look at `screenshots/3c-error-states.png` and `3b-first-sync.png` first.

**Files:**
- Modify: `app/views/layouts/_alerts.html.erb`, `app/views/dashboard/show.html.erb`, `spec/requests/dashboard_spec.rb`
- Create: `app/javascript/controllers/dismiss_controller.js`

**Interfaces:**
- `_alerts` renders (on every non-bare page): amber banner per `needs_reauth` account with "Re-link now" link to `accounts_path` and a dismiss ✕ (Stimulus `dismiss#hide` removes the element client-side); a fixed bottom-right toast when the most recent `SyncRun` overall has `status == "rate_limited"` and `completed_at > 10.minutes.ago`.
- Dashboard: when any `SyncRun` is `running` for an account with no `last_synced_at` (first sync), show a "Pulling your history…" section with per-account status cards (complete / syncing / waiting) above the hero. Sidebar badge already done in Task 1.

- [ ] **Step 1: Failing spec**

Append to `spec/requests/dashboard_spec.rb`:

```ruby
it "shows the expired-token banner and rate-limit toast" do
  account = create(:account, current: true, label: "Matty_JPN", needs_reauth: true)
  create(:sync_run, account:, kind: "trophies", status: "rate_limited",
         error_message: "429", completed_at: 1.minute.ago)
  get root_path
  expect(response.body).to include("stopped syncing")
  expect(response.body).to include("Re-link now")
  expect(response.body).to include("Rate limited by PSN")
end

it "shows first-sync progress cards while an initial sync runs" do
  account = create(:account, current: true, label: "Fresh", last_synced_at: nil)
  create(:sync_run, account:, kind: "trophies", status: "running", started_at: Time.current)
  get root_path
  expect(response.body).to include("Pulling your history")
  expect(response.body).to include("syncing")
end
```

Ensure a `:sync_run` factory exists (add to `spec/factories.rb` if missing: `factory :sync_run { account; kind { "trophies" }; status { "running" } }`).

- [ ] **Step 2: Run, verify failure** — FAIL.

- [ ] **Step 3: Implement**

```javascript
// app/javascript/controllers/dismiss_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  hide() {
    this.element.remove()
  }
}
```

Append to `app/views/layouts/_alerts.html.erb`:

```erb
<% Account.where(needs_reauth: true).find_each do |account| %>
  <div class="mb-4 flex items-center gap-4 rounded-lg border border-warnline bg-warnbg px-4 py-3 text-sm"
       data-controller="dismiss">
    <span class="text-warn">▲</span>
    <span class="flex-1 text-warnink">
      <strong><%= account.label %> stopped syncing</strong> — its NPSSO token expired.
      Trophy and purchase data is frozen at <%= mono_date(account.last_synced_at) %>.
    </span>
    <%= link_to "Re-link now", accounts_path, class: "rounded-lg border border-warnline bg-btnwarn px-3 py-1.5 font-bold text-warnink" %>
    <button type="button" data-action="dismiss#hide" class="text-mute hover:text-ink2">✕</button>
  </div>
<% end %>

<% latest_run = SyncRun.order(created_at: :desc).first %>
<% if latest_run&.status == "rate_limited" && latest_run.completed_at && latest_run.completed_at > 10.minutes.ago %>
  <div class="fixed bottom-5 right-5 z-50 flex items-center gap-4 rounded-xl border border-line3 bg-card2 px-4 py-3 text-sm shadow-lg"
       data-controller="dismiss">
    <span class="text-warn">●</span>
    <span>
      <strong>Rate limited by PSN</strong>
      <span class="block font-mono text-xs text-mute">429 · sync resumes automatically</span>
    </span>
    <button type="button" data-action="dismiss#hide" class="text-mute hover:text-ink2">Dismiss</button>
  </div>
<% end %>
```

In `app/views/dashboard/show.html.erb`, insert at the top of the `@main` branch:

```erb
<% first_syncing = @accounts.select { |a| a.last_synced_at.nil? && a.sync_runs.any? } %>
<% if first_syncing.any? %>
  <div class="mb-10">
    <h2 class="text-2xl font-extrabold tracking-[-0.03em]">Pulling your history…</h2>
    <p class="mt-1 text-sm text-mute">PSN rate-limits bulk reads, so the first sync can take a while. Progress is saved as it goes.</p>
    <div class="mt-4 space-y-2">
      <% @accounts.each do |account| %>
        <% run = account.sync_runs.order(created_at: :desc).first %>
        <% state = account.last_synced_at ? "complete" : run&.status == "running" ? "syncing" : "waiting" %>
        <div class="flex items-center gap-3 rounded-lg border p-4 text-sm
                    <%= state == "syncing" ? "border-line3 bg-card2" : "border-line bg-card" %>
                    <%= "opacity-60" if state == "waiting" %>">
          <span class="<%= state == "complete" ? "text-ok" : state == "syncing" ? "text-accent" : "text-faint" %>">●</span>
          <span class="font-bold"><%= account.label %></span>
          <span class="font-mono text-xs text-mute">
            <%= state == "complete" ? "done" : state == "syncing" ? "syncing #{run.kind} — #{run.items_synced} items" : "waiting" %>
          </span>
        </div>
      <% end %>
    </div>
  </div>
<% end %>
```

(Degradation: no per-game progress bars or skeleton blocks — no data source; the `turbo_stream_from "sync_status"` subscription in the layout plus `SyncRun.broadcasts_refreshes_to` already makes these cards live-update via morph refresh.)

- [ ] **Step 4: Run suite** — `bundle exec rspec` — PASS.

- [ ] **Step 5: Commit**

```bash
git add -A && git commit -m "feat: expired-token banner, rate-limit toast, first-sync status cards"
```

---

### Task 15: Final verification pass

**Files:** none new — fixes only.

- [ ] **Step 1: Full suite + lint**

Run: `bundle exec rspec && bin/rubocop`
Expected: all green. Fix anything that isn't.

- [ ] **Step 2: Build assets + boot every page**

```bash
bin/rails tailwindcss:build
bin/rails db:prepare
(bin/rails s -p 3057 &) && sleep 4
for p in / /reearn /reearn/backlog /trophy_comparison /ownership /spend /accounts; do
  curl -sf -o /dev/null -w "%{http_code} $p\n" "http://localhost:3057$p" || echo "FAIL $p"
done
kill %1 2>/dev/null || pkill -f "rails s -p 3057"
```

Expected: `200` (or `302` for `/` with zero accounts) on every path, no 500s. If dev DB has synced data, eyeball each page against its screenshot (2a–2g); check mobile at 390px via browser devtools if available.

- [ ] **Step 3: Screenshot comparison (if a browser tool is available)**

Compare rendered pages to `screenshots/*.png` for: hero typography (mono numerals), chip states, green earned pills with time-under-date (2b), amber RE-EARN chips + row tint, struck-through skipped rows, account card variants (2g). Fix visual gaps.

- [ ] **Step 4: Commit any fixes**

```bash
git add -A && git commit -m "fix: verification-pass corrections for RE:EARN design"
```

---

## Self-Review Notes

- **Spec coverage:** 2a (T8), 2b (T9), 2c/2d (T10), 2e (T11), 2f (T12), 2g/3a (T13), 3b/3c (T14), 2h/2i responsive behavior folded into T1 shell + responsive classes in each screen task. Skip mechanic: T2 (data), T3/T5 (math), T7 (endpoints), T9/T10 (UI). Rarity: T2 + T10. 2nd copy: T6 + T11. Unique-to-account: T4 + T8.
- **Known degradations** are listed in Global Constraints and repeated at the point of use — do not silently add fake data for prices/delisted/PS Plus.
- **Type consistency:** `ReearnProgress::Result(total, reearned, skipped, games)`, `GameProgress#left/#percent/#complete?`, `MissingTrophy(trophy, first_earned_at, first_earned_label, skipped)` are consumed by T4, T5, T8, T10, T12 exactly as defined in T3. `MainOwnership.call(main)#owned?(game)` consumed by T5, T8 (via DashboardStats), T10, T12. `SecondCopies.transaction_ids` (Set) consumed by T11. `chip_classes/mono_date/mono_time/initials/grade_border/relative_sync` defined in T1, used everywhere.
- Factories: specs assume `:account, :game, :trophy, :account_trophy, :account_game, :entitlement, :psn_transaction, :trophy_skip, :sync_run` — check `spec/factories.rb` in Task 2 and add any that are missing with minimal attributes.
