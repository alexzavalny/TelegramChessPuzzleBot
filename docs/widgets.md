# Interactive puzzle widgets — current state

Status as of **10 November 2026**, Bot API **10.4** (production).

This document describes what is implemented today, how it works, and what is
deliberately left out. The widget path is an experiment wired into `/test`; the
existing PNG + UCI flow (`/daily`, `/random`, …) is unchanged and remains the
only option for groups.

## What works

- `/test` in a **private chat** sends the Lichess daily puzzle as an interactive
  HTML widget (`sendWidget`, 320×360).
- The whole puzzle is self-contained: FEN, the solution line and the puzzle id
  are baked into the HTML when the message is created. Moves are validated on
  the device, with no server round-trip per move.
- Wrong moves flash red and are rejected; correct moves are applied, and the
  opponent's reply from the official line is played automatically after ~0.3 s.
- Castling, en passant, captures and promotion are applied by the widget.
- The board is flipped when the solver plays Black.
- When the last move is made the widget sends **one** `TelegramWidget.request`
  (`{"t":"solved","p":"<id>","ms":<elapsed>}`, 36 bytes) from the tap handler.
- The bot answers the `widget_query`, records the solve per user in
  `data/widget_solves.json`, and posts a chat message:
  `✅ Решено #<id> (<rating>) за N.N с — всего K.`
- Re-tapping a solved puzzle does not double-count: the store dedupes by puzzle
  id, and the second query is answered without a new chat message.
- Groups are refused with
  `Widgets are only available in a private chat with the bot for now.`

## Data flow

```
/puzzle (test)                    bot                         widget (device)
──────────────────────────────────────────────────────────────────────────────
sendWidget(html, allow_queries)
   html ← PuzzleWidget.html(fen:, solution:, rating:, id:)
   registry: message_id → {id, rating, chat_id}   → data/widget_messages.json

                                        user taps the final move
                                        TelegramWidget.request("…") ────────►
widget_query update  ◄──────────────────────────────────────────────────────
   answerWidgetQuery(id, {ok, n, new}) ─────────────────────────────────────►
   sendMessage("✅ Решено …")              (widget shows "Solved! ✓")
   record solve → data/widget_solves.json
```

## Files

| File | Role |
| --- | --- |
| `lib/telegram_chess_puzzle_bot/bot.rb` | `/test` handler, raw long-poll loop, `handle_widget_query`, answer + chat reply |
| `lib/telegram_chess_puzzle_bot/puzzle_widget.rb` | reads the template and injects `{fen, solution, rating, id}` as JSON |
| `lib/telegram_chess_puzzle_bot/widgets/puzzle_board.html` | the widget itself: FEN parser, renderer, move validation, reporting |
| `lib/telegram_chess_puzzle_bot/widget_solve_store.rb` | per-user solved puzzles, elapsed time, rating, timestamp |
| `lib/telegram_chess_puzzle_bot/widget_message_store.rb` | `message_id → puzzle` mapping, persisted so a restart is harmless |
| `spec/test_widget_spec.rb` | widget payload, limits, group refusal |
| `spec/widget_query_spec.rb` | query handling: answer order, dedupe, unknown puzzle, malformed data |

## Widget internals

- Layout uses the conservative renderer subset: absolutely positioned cells,
  inline styles, an explicit JS-measured board height, inline SVG paths per
  piece. CSS grid, `aspect-ratio`, `<symbol>/<use>` and pseudo-element overlays
  are **not** used — a widget built on them rendered as a solid green block inside
  Telegram while working fine in Chrome.
- Cells carry *view* indices; on a flipped board the handler converts with
  `boardIndex = 63 - viewIndex`. Converting in drawing only makes every tap hit
  the 180°-mirrored square.
- Data is injected by replacing the `__PUZZLE_DATA__` placeholder in the
  template, so the file stays valid HTML/JS and can be previewed locally.

## Limits and rules that shaped the design

- HTML ≤ 32 768 bytes and ≤ 4096 bytes after zlib level 9 (current: ~7.7 KB raw,
  ~3.2 KB compressed; the spec asserts both).
- Sandbox: no network APIs, no external resources, QuickJS, ~2000 nodes.
- A request is 1–64 bytes, must be made **synchronously in the tap handler**,
  and the bot must answer within 15 s.
- Requests need `allow_queries: true` on `sendWidget`; without it the promise
  rejects with `NOT_ALLOWED`.
- Rate limit: 5 requests per 5 s per user per bot.
- The answer only carries `data`; it changes no state and shows no toast.
- In production, widgets are supported **only in the private chat with the
  bot**. Groups, inline mode and forwards still work on the test server alone.

## Bot side: why the polling loop is hand-written

`telegram-bot-ruby` (2.5.0) has no `WidgetQuery` type, and its typed `Update`
struct silently drops unknown fields. The bot therefore long-polls
`getUpdates` itself (`TelegramApi#get_updates`, raw hashes, explicit
`allowed_updates`), handles `widget_query` first, and only then builds
`Telegram::Bot::Types::Update` for ordinary messages.

Order inside a solve: `answerWidgetQuery` first, chat message second — the
widget's 15-second window must not depend on the speed of the Telegram send.

## Runtime data (not in git)

- `data/widget_messages.json` — `message_id → {id, rating, chat_id}`, pruned
  to the newest 200 entries.
- `data/widget_solves.json` — per user:
  `{ "solves": { "<puzzle id>": {seconds, rating, at} }, "count": N }`.

Both are written with a mutex inside one process; there is exactly one bot
process (systemd `lichess-puzzle-bot.service`).

## Testing

```bash
bundle exec rspec                     # 25 examples
```

Manual check without Telegram:

```ruby
# build a preview page with the real daily puzzle
html = TelegramChessPuzzleBot::PuzzleWidget.html(fen: fen, solution: pz['solution'],
                                                rating: pz['rating'], id: pz['id'])
File.write('/tmp/preview.html', html)
```

Open `/tmp/preview.html` at 320 px width; inject
`window.TelegramWidget = {request: d => (window.__req = d, Promise.resolve({result: '{"ok":true}'}))}`
to observe the solve request.

Deployment: Ruby changes require
`sudo systemctl restart lichess-puzzle-bot.service`. Edits to
`puzzle_board.html` are picked up by the next `sendWidget` (the template is read
per send); already-sent widgets are immutable.

## Known gaps / deliberate omissions

- No per-puzzle scoreboard for widget puzzles: the widget reports only the
  final state, so intermediate moves never reach the bot.
- The solution is inside the client's copy of the widget; it is not visible in
  the UI, but a determined user can extract it. Acceptable for a friends' bot,
  not for rated competition.
- Widget progress lives in the widget's own JS; leaving and returning to the
  message restarts the attempt (localStorage is not used yet).
- `/test` still fetches the daily puzzle directly instead of going through the
  shared `DailyPuzzleBuilder`.
- No `/stats` command yet — the data for it is already in
  `data/widget_solves.json`.
- Group support: blocked by Telegram, not by this code. The guard in
  `send_test_widget` and the private-chat assumption in the design are the only
  group-specific pieces.
