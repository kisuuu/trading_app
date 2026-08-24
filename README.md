# Trading App

A simulated trading terminal built on a mock market-data feed: multiple
watchlists, a live market overview, a Buy/Sell ticket and a portfolio view with
real-time P&L.

```bash
flutter pub get
flutter run
```

No backend, no code generation, no environment variables. Tested on Flutter
3.41 (stable).

```bash
flutter test      # 97 tests
flutter analyze   # clean under strict-casts + extra lints
```

---

## The ten stocks

`RELIANCE`, `TCS`, `INFY`, `HDFCBANK`, `ICICIBANK`, `SBIN`, `ITC`, `LT`,
`BHARTIARTL`, `AXISBANK` — defined once in
[`StockUniverse`](lib/src/features/market/domain/stock.dart) with a previous
close and a per-symbol volatility. Every screen, the feed and the stock picker
read from that one list, so they cannot drift apart.

---

## Architecture

Feature-first, with the same four layers inside each feature. Dependencies point
inward: presentation → application → domain, and data → domain.

```
lib/
├── main.dart                     opens storage, installs the provider overrides
└── src/
    ├── app/                      root widget, shell, theme, navigation
    ├── core/
    │   ├── money/                Money value type + Indian-format rendering
    │   ├── persistence/          KeyValueStore port + SharedPreferences adapter
    │   ├── scheduler/            FrameScheduler (per-frame coalescing)
    │   └── widgets/              shared empty state
    └── features/
        ├── market/               feed, quote distribution, market screen
        │   ├── domain/           Stock, Quote
        │   ├── data/             MarketFeed port, MockMarketFeed
        │   ├── application/      MarketDataService, providers
        │   └── presentation/     MarketScreen, QuoteBuilder, PriceFlash
        ├── watchlist/            Watchlist, repository, controller, screen
        ├── trading/              orders: executor, failures, controller, ticket
        └── portfolio/            holdings, summary, sorting, holdings screen
```

**State management: Riverpod** (`flutter_riverpod`, no codegen). Providers give
compile-checked dependency injection and make every collaborator overridable in
tests — the widget tests swap in a deterministic feed and an in-memory store
through the exact same wiring the app uses.

Riverpod is *not* used for the price stream. That is deliberate, and it is the
central design decision of this app.

---

## The realtime pipeline

### The problem

Under the stress setting the feed emits **250 ticks/sec** across ten symbols. A
60 Hz display can show at most 60 updates/sec. Routing every tick into the
widget tree would queue four times more work than the frame pipeline can retire,
and the app would fall behind and never catch up.

### The pipeline

```
MockMarketFeed  ──ticks──▶  MarketDataService  ──1 flush/frame──▶  widgets
  25 ms engine                 dirty-set buffer                    ValueListenable
  Poisson arrivals             last write wins                     per symbol
```

1. **Absorb.** Each tick overwrites a pending entry in a `Map<String, Quote>` and
   asks the [`FrameScheduler`](lib/src/core/scheduler/frame_scheduler.dart) for a
   flush. Ten ticks for one symbol inside a frame become one write.
2. **Flush once per frame.** The scheduler runs at most one callback per rendered
   frame. Intermediate prices nobody could have seen are dropped rather than
   rendered.
3. **Notify surgically.** Each symbol has its own `ValueNotifier<Quote>`, held
   for the life of the session. Only symbols that actually moved notify, and a
   `ValueListenableBuilder` rebuilds just the price cell — not the row, not the
   list, not the screen.

Raising the tick rate raises feed CPU and leaves UI work flat. The **Feed
settings** sheet (speedometer icon on the Market tab) shows both counters live:
*ticks in* climbs to 250/s while *UI flushes* stays pinned at the frame rate.

### One source of truth, structurally

`MarketDataService.quoteListenable(symbol)` returns the *same* notifier instance
to every caller. Two watchlists containing RELIANCE are not two subscriptions
that have to be kept in sync — they are two widgets listening to one object.
Identical prices are guaranteed by construction, not by discipline.

### Reordering cannot mis-bind a row

Rows bind to prices **by symbol, never by list index**, and are keyed
`ValueKey(symbol)`. A drag changes indices; it does not change any row's symbol,
so a stale tick cannot land on the wrong row. There is a widget test that
reorders a list and asserts each price is still rendered on its own row's
baseline.

### Aggregates without ten rebuilds

Widgets that depend on *many* symbols at once — the portfolio total, the P&L sort
order — listen to a single `epoch` counter that is bumped **once per flush,
after every notifier has been written**. So:

* the summary rebuilds once per frame, not once per moving symbol; and
* the total is always computed from the same prices the rows are showing. There
  is no window where half the quotes are new and half are stale, which is why
  the summary reconciles to the visible rows at any instant.

### Live sorting without list-wide rebuilds

Sorting by P&L has to react to prices, but re-sorting is worthless if the
sequence did not change — and rebuilding the list would fight the per-row
notifiers. [`HoldingsOrderNotifier`](lib/src/features/portfolio/application/holdings_sort.dart)
recomputes the order on every flush (a handful of integer comparisons) and
publishes **only when the sequence actually differs**. Prices move constantly;
the ranking changes rarely. A position crossing from loss to gain reorders the
list; ordinary ticks only repaint numbers.

### The feed itself

A mean-reverting random walk in exact paise: a Gaussian shock scaled by the
symbol's volatility, plus a pull back toward the previous close, clamped to a
±20% circuit band. The engine wakes on a fixed 25 ms timer and gives each symbol
`rate × 0.025` ticks — whole part plus a Bernoulli draw for the remainder — so
arrivals are staggered rather than lockstep and timer pressure is constant as
the rate changes. Seedable, and covered by tests for determinism and for staying
inside the band over a simulated ten-hour session.

---

## Money

**Every monetary value in the app is an integer number of paise.**
[`Money`](lib/src/core/money/money.dart) wraps that integer; `double` appears
only for display and for percentages.

The subtler half is the cost basis. A holding stores **(quantity, total cost)**,
never an average price — an average is usually not a whole number of paise, so
storing it would round on every buy and compound the error across a session.
Average cost is derived on demand for display; the stored aggregate stays exactly
equal to the rupees spent, so P&L reconciles to the last paisa.

Tests cover the classic failure: `1010.10 × 100` is `101009.99999999999` in
binary floating point, and `₹1,01,010.00` here.

Rendering uses Indian digit grouping (`₹12,34,567.89`), hand-rolled rather than
pulling in `intl` — the rule is fifteen lines and it keeps locale-data
initialisation out of the launch path.

---

## Orders

[`OrderExecutor`](lib/src/features/trading/domain/order_executor.dart) is pure:
portfolio + draft + price in, `OrderFilled` or `OrderRejected` out. No Flutter,
no storage, no clock (the id and timestamp are passed in). It is the only place
trading rules live — the controller just commits its result.

* **Fill price is sampled at submission**, inside the controller, not read from
  the form. The displayed price is one frame old at best; sampling at submit is
  what makes "executes at the current LTP at the moment of submission" literally
  true. The ticket revalidates then too, so a stale UI cannot push an invalid
  order through.
* **Failures are a sealed hierarchy**, each carrying the numbers its message
  needs — `InsufficientFunds` knows the shortfall, `InsufficientQuantityHeld`
  knows what you hold. The UI must handle every case.
* **Quantity rejection is specific**: `2.5`, `-3`, `0`, `abc` and empty each
  produce a different message. The field is deliberately not digit-filtered —
  explaining why `2.5` is invalid beats silently swallowing the keystroke.
* **Selling out closes the position**; a partial sell reduces the cost basis
  proportionally so the average cost of the remainder is unchanged.

---

## Persistence

`SharedPreferences` behind a narrow [`KeyValueStore`](lib/src/core/persistence/key_value_store.dart)
port. Reads are synchronous (the store is warm before the widget tree exists), so
controllers hydrate in their constructor and screens never show a spinner for
data that is always available.

| Key | Contents |
| --- | --- |
| `watchlists.v1` | every watchlist, its name and its symbol order |
| `watchlists.selected.v1` | the active tab |
| `portfolio.v1` | cash **and** holdings, as one record |
| `orders.v1` | executed-order ledger, capped at 200 |

Cash and holdings are deliberately **one** record: an order moves both, and
writing them together makes a torn write — cash debited, holding lost —
impossible.

Failure handling, all covered by tests:

* a payload that will not parse is treated as absent, not as a crash on launch;
* a malformed row inside a good payload is skipped, the rest survives;
* a symbol no longer in the universe is dropped from a restored watchlist rather
  than rendering a row that can never receive a price;
* if platform storage cannot be opened at all, the app falls back to an in-memory
  store and runs — it just will not remember. Refusing to launch over a storage
  fault is the worse failure.

---

## UI notes

* **Tabular figures** everywhere numbers live. With proportional digits, every
  tick shifts the column and the eye can never settle.
* **Flash on tick**, keyed on a per-symbol sequence rather than the price, so a
  flat re-trade still flashes — a table that goes still reads as a dead feed.
  Only the tint repaints; the price text underneath is a cached subtree.
* **`IndexedStack` shell**, so tabs keep scroll position and their subscriptions.
  Returning to a tab shows current prices with no refetch and no stale frame.
* **Lifecycle-aware feed**: paused in the background, then rolled forward by the
  time spent away on resume — you come back to a market that moved, without
  burning CPU on prices nobody could see.
* Undo on watchlist removal restores the row at its original index.

---

## Tests

97 tests, no mocking framework — a hand-written [`FakeMarketFeed`](test/support/fake_market_feed.dart)
and a `ManualFrameScheduler` make the realtime pipeline fully deterministic.

| Area | What is pinned down |
| --- | --- |
| `core/money_test` | integer arithmetic, half-away-from-zero rounding, no float drift, Indian grouping |
| `domain/order_executor_test` | every validation branch, exact cash/cost math over 100 trades, sell-to-zero |
| `domain/portfolio_test` | P&L math, persistence round-trip, corrupt/partial payloads, summary equals rows |
| `market/market_data_service_test` | 50 ticks → 1 notification, per-symbol isolation, epoch ordering, shared-notifier identity, feed determinism and circuit band |
| `portfolio/holdings_sort_test` | live reordering, and that a stable ranking publishes **nothing** |
| `watchlist/watchlist_test` | `ReorderableListView` index semantics, dedupe, restore, corrupt data |
| `widget/*` | all four features end to end: live updates in place, a 250-tick burst, reorder binding, validation blocking submit, buy → holdings → restart |

The widget tests run on a 420 px-wide surface, which is how the layout overflows
on narrow phones were found and fixed.

---

## Trade-offs

* **`ValueNotifier` for prices, Riverpod for everything else.** Mixing two
  mechanisms needs justifying: Riverpod's rebuild granularity is the consuming
  widget, which is right for portfolio and watchlist state (changes on user
  action) and wrong for prices (changes 250×/sec). The split follows the update
  frequency.
* **One frame of latency.** The flush runs post-frame, so a tick is visible on
  the following frame — ~16 ms. Invisible to a person, and the price of never
  rendering more often than the display can show.
* **`SharedPreferences`, not a database.** The whole dataset is a few kilobytes
  and is written on user action, not on ticks. A database would be ceremony
  without benefit at this size.
* **No `intl`, no `uuid`, no mocking package.** Each replaced by a few lines of
  local code, keeping `pub get && run` as the entire setup story.
* **Order history is capped at 200** and is a convenience view, not an audit
  record. The cap is logged in code, not silent.
