# active-r2ui

[r2ui](../README.md) dashboards for Rails apps. Add the gem and `bin/rails tui` browses every ActiveRecord model in your terminal, with no configuration. `ActiveR2UI.register` customises a model with r2ui's resource DSL, with Rails defaults filled in.

Rails 7.1+ (railties and activerecord); r2ui itself stays Rails-free.

```ruby
# Gemfile (path or git until it is released)
gem "active-r2ui", git: "https://github.com/satoramoto/r2ui", glob: "active-r2ui/*.gemspec"
```

## bin/rails tui

```sh
bin/rails tui                          # the model list; enter opens a model, esc goes back, q quits
bin/rails tui orders                   # one model full screen (also: Order, order, the table name)
bin/rails tui --snapshot               # print one frame as plain text and exit
bin/rails tui orders --snapshot --width 140 --height 45
bin/rails tui -e production --allow-writes   # actions are refused in production without it
```

The model list shows each model, its screen name (what `bin/rails tui NAME` takes), its table and its row count (refreshed every 30 s). The command eager-loads the app and lists every concrete model whose table exists. It skips abstract classes, STI subclasses (they share their parent's table), `ActiveRecord::` internals and HABTM join classes. All of r2ui's keys work: `/` search (free text, or `total>50`, `status~pend`), `s`/`S` sort, `[` `]` scopes, `z` zoom. See the r2ui README.

## Customising a model

Put registrations in `app/tui/*.rb`. The command loads them, and Zeitwerk is told to ignore the directory:

```ruby
# app/tui/orders.rb
ActiveR2UI.register Order do
  limit 1000                          # rows per fetch, newest first (default 500)
  refresh every: 2                    # seconds (default 5)

  scope :all
  scope :pending, default: true       # no block: Order.pending (see Limitations)
  scope(:big) { |o| o.total > 100 }   # a block: r2ui's in-memory filter, as usual

  index do                            # declaring columns replaces the inferred ones
    column :id
    column :status
    column :total                     # no format given: the inferred one (decimal, 2 places)
    column(:customer) { |o| o.customer&.name }
    column :created_at
  end

  action :ship, key: "x", confirm: true   # no block: calls order.ship on each selected record
  action(:refund, key: "R") { |o| Refunds.issue(o) }
end
```

Everything `R2UI.resource` takes works in the block (`source`, `key`, `group_by`, `filter`, extension keywords). `ActiveR2UI.register Order, as: :sales` names the screen. Plain `R2UI.dashboard :ops do ... end` in `app/tui/` defines a screen made of several panels; open it with `bin/rails tui ops`.

### Defaults

| Declaration | Default |
|---|---|
| `source` | `Model.reorder(id: :desc).limit(limit).to_a`: newest first by an integer primary key, else by `created_at`. Default scopes apply. |
| `key` | the primary key (`:id` for composite keys; none without one) |
| `title` | the pluralised human model name |
| `index` | one column per database column. Integer primary and foreign keys use `:id`; integers `:integer`; decimals and floats `:number` (decimals keep their scale, e.g. `12.50`); strings and text are squished to one line; booleans show `yes`/`no`; datetimes and dates show relative times (`3m ago`, `in 2h`, the date past 30 days) and still sort by time. JSON, binary and hstore columns are skipped. Names and titles have the highest priority, so narrow terminals drop `updated_at`, foreign keys and long text first. |
| `filter` | string and text columns (what `/` free text matches) |
| `refresh` | every 5 seconds |

### Connections and errors

Each fetch runs on r2ui's feed thread inside `Rails.application.executor.wrap` and `connection_pool.with_connection`, so the connection goes back to the pool afterwards. A failing fetch (a broken scope, a lost database) shows its error in the panel; the app keeps running. Actions run the same way on the main thread. An error in an action is flashed on the status bar.

### Production

When `Rails.env.production?`, every action (the blockless ones and yours) is refused with "read-only in production" unless the command was started with `--allow-writes`. Fetches only read. `ActiveR2UI.read_only = true` turns this on anywhere.

## Limitations (phase 1)

- **Named scopes filter the fetched window.** `scope :pending` with no block keeps the rows among the newest `limit` that `Order.pending` matches (one `WHERE id IN (...)` query per fetch). It does not fetch older pending orders. Server-side scoped fetches come with r2ui's core fetch support (phase 2).
- Search, sort and grouping also work on the fetched window, as everywhere in r2ui.
- Row counts on the model list run `Model.count` for every model every 30 seconds; on very large tables that is a slow query.
- Associations aren't shown or followed yet (a column block like `{ |o| o.customer&.name }` queries per row); `includes` needs a custom `source`.
- q quits from a model's screen too; esc goes back to the list.

## Tests

```sh
cd active-r2ui && bundle exec rake test
```

They boot a minimal Rails app on a temporary sqlite file and drive screens with r2ui's `App#frame` / `App#press` and the `tui` command.
