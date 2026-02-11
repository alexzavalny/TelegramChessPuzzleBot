# Telegram Chess Puzzle Bot (Ruby)

Telegram bot for groups or DMs.

When user sends `puzzle`, bot:
1. Fetches daily puzzle from Lichess (`/api/puzzle/daily`)
2. Reconstructs puzzle position from PGN + `initialPly`
3. Generates and sends a PNG chessboard image
4. Waits for user reply with UCI moves (`e2e4`, `f3g3 f2g3`)
5. Replies `correct` or `wrong`

## Setup

```bash
bundle install
cp .env.example .env
# edit .env and set TELEGRAM_BOT_TOKEN
bundle exec ruby ./bin/bot
```

## Notes

- Answers are checked as a prefix against official puzzle `solution`.
- One active puzzle session is stored per chat in memory.
- Input format expected: UCI moves (not SAN), one or multiple moves.

## Tests

```bash
bundle exec rspec
```
