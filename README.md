# Telegram Chess Puzzle Bot (Ruby)

Telegram bot for chess puzzles in DMs and group chats.

## Features

- Daily puzzle command via Lichess: `/api/puzzle/daily`
- Random puzzle command via Lichess: `/api/puzzle/next?difficulty=normal`
- Board image generation as PNG with piece sprites from `img/`
- Board coordinates rendered on all sides
- Board auto-flips when black is to move
- Caption includes puzzle id, rating, and `White to move` / `Black to move`
- Turn-by-turn solve flow (supports one or multiple UCI moves per message)
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
- `help`, `/help`, `/help@YourBotName`: show help
- `daily`, `/daily`, `/daily@YourBotName`: start daily puzzle
- `random`, `/random`, `/random@YourBotName`: start random puzzle (`difficulty=normal`)
- `random-easy`, `/random-easy`, `/random-easy@YourBotName`: random puzzle (`difficulty=easier`)
- `random-hard`, `/random-hard`, `/random-hard@YourBotName`: random puzzle (`difficulty=harder`)
- `random-hardest`, `/random-hardest`, `/random-hardest@YourBotName`: random puzzle (`difficulty=hardest`)
- `answer`, `/answer`, `/answer@YourBotName`: reveal current solution (spoiler)

## Solve Flow

1. Request puzzle (`daily` or `random`).
2. Bot sends board image + side to move.
3. User sends one or more UCI moves, e.g. `e2e4` or `e2e4 g1f3`.
4. If correct, bot plays opponent move (spoiler) and asks for next move.
5. In groups, each user has independent progress through the same puzzle line.
6. Wrong moves do not end the puzzle; users can retry.
7. On completion, bot announces solved state and updates scoreboard/solver stats.

## Input Format

- Expected format: UCI only (`e2e4`, promotion like `e7e8q`)
- One or multiple moves per message in active turn mode
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

- `/daily@YourBotName`
- `/random@YourBotName`
- `/answer@YourBotName`

## Environment

- Token is read from `.env` via `dotenv`
- Required key: `TELEGRAM_BOT_TOKEN`

## Notes

- Puzzle state is in memory and resets on process restart.
- API/network errors are sent back to chat as bot error messages.

## Deploy On Raspberry Pi (systemd)

This runs the bot as a background service that survives SSH disconnects and restarts on reboot.

1. Ensure token exists in `.env`:

```bash
cd /home/alex/Projects/TelegramChessPuzzleBot
cp .env.example .env
# edit .env and set TELEGRAM_BOT_TOKEN=...
```

2. Enable unbuffered Ruby logs in `/home/alex/Projects/TelegramChessPuzzleBot/bin/bot`:

```ruby
#!/usr/bin/env ruby
# frozen_string_literal: true

$stdout.sync = true
$stderr.sync = true
```

3. Create service file:

```bash
sudo tee /etc/systemd/system/lichess-puzzle-bot.service >/dev/null <<'EOF'
[Unit]
Description=Telegram Lichess Puzzle Bot
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=alex
WorkingDirectory=/home/alex/Projects/TelegramChessPuzzleBot
Environment=BUNDLE_GEMFILE=/home/alex/Projects/TelegramChessPuzzleBot/Gemfile
ExecStart=/bin/bash -lc 'source /home/alex/.rvm/scripts/rvm && rvm use 3.1.0 && bundle exec ruby -u ./bin/bot'
StandardOutput=journal
StandardError=journal
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
```

4. Reload, enable, and start:

```bash
sudo systemctl daemon-reload
sudo systemctl enable lichess-puzzle-bot
sudo systemctl start lichess-puzzle-bot
```

5. Manage service:

```bash
# start
sudo systemctl start lichess-puzzle-bot

# stop
sudo systemctl stop lichess-puzzle-bot

# restart
sudo systemctl restart lichess-puzzle-bot

# status
sudo systemctl status lichess-puzzle-bot
```

6. View logs:

```bash
journalctl -u lichess-puzzle-bot -f
```

## Tests

```bash
bundle exec rspec
```
