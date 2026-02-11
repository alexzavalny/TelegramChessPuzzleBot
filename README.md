# Telegram Chess Puzzle Bot (Ruby)

Telegram bot for chess puzzles in DMs and group chats.

## Features

- Daily puzzle command via Lichess: `/api/puzzle/daily`
- Random puzzle command via Lichess: `/api/puzzle/next?difficulty=normal`
- Board image generation as PNG with piece sprites from `img/`
- Board coordinates rendered on all sides
- Board auto-flips when black is to move
- Caption includes puzzle id, rating, and `White to move` / `Black to move`
- Turn-by-turn solve flow (one UCI move at a time)
- Bot auto-plays opponent reply move from official solution
- Opponent move is sent as Telegram spoiler
- `answer` reveals full solution as Telegram spoiler
- Per-chat in-memory session state
- Per-puzzle scoreboard (correct move count per user)
- `Solved by` tracking
- Puzzle stays active after solve; line resets so others can continue
- Runtime console logs for startup and message handling

## Commands

- `start`, `/start`, `/start@YourBotName`: show help
- `puzzle`, `/puzzle`, `/puzzle@YourBotName`: start daily puzzle
- `random`, `/random`, `/random@YourBotName`: start random puzzle (`difficulty=normal`)
- `random-easy`, `/random-easy`, `/random-easy@YourBotName`: random puzzle (`difficulty=easy`)
- `random-hard`, `/random-hard`, `/random-hard@YourBotName`: random puzzle (`difficulty=hard`)
- `answer`, `/answer`, `/answer@YourBotName`: reveal current solution (spoiler)

## Solve Flow

1. Request puzzle (`puzzle` or `random`).
2. Bot sends board image + side to move.
3. User sends one UCI move, e.g. `e2e4`.
4. If correct, bot plays opponent move (spoiler) and asks for next move.
5. Wrong moves do not end the puzzle; users can retry.
6. On completion, bot announces solved state, shows scoreboard, and resets line progress.

## Input Format

- Expected format: UCI only (`e2e4`, promotion like `e7e8q`)
- One move per message in active turn mode
- SAN is not supported

## Setup

```bash
cd /Users/alex/Projects/TelegramChessPuzzleBot
bundle install
cp .env.example .env
# edit .env and set TELEGRAM_BOT_TOKEN=...
bundle exec ruby ./bin/bot
```

## Group Chat Setup

In BotFather for your bot:

- `/setprivacy` -> `Disable` (required for non-command move messages)
- `/setjoingroups` -> `Enable`

Then remove/re-add the bot to the group and use command form for best reliability:

- `/puzzle@YourBotName`
- `/random@YourBotName`
- `/answer@YourBotName`

## Environment

- Token is read from `.env` via `dotenv`
- Required key: `TELEGRAM_BOT_TOKEN`

## Notes

- Puzzle state is in memory and resets on process restart.
- API/network errors are sent back to chat as bot error messages.

## Tests

```bash
bundle exec rspec
```
