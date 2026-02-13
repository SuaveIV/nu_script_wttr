# wttr.in for Nushell

A weather fetcher for [Nushell](https://www.nushell.sh/) that pulls data from [wttr.in](https://wttr.in).

## What it does

Shows current weather, forecasts, and astronomy data in your terminal. Temperature gradients use ANSI colors. Works with Nerd Fonts by default, but you can switch to emojis or plain text if that's not your thing.

Caches results for 15 minutes so you don't hammer the API. Auto-detects your location from IP, or you can specify cities, airport codes, landmarks (with `~`), or domains (with `@`). Units switch between metric and imperial based on where you are, unless you override it.

Has a one-line mode for status bars, raw output for piping to other commands, and a debug mode when things aren't working.

## Screenshots

**Current weather:**

<img width="578" alt="Current weather with Nerd Fonts" src="https://github.com/user-attachments/assets/4f4dde64-3322-4dad-babc-59985b32e8b2" />

**3-day forecast:**

<img width="1053" alt="3-day forecast" src="https://github.com/user-attachments/assets/b70be374-b433-4282-bd59-8979c1c7ea4f" />

**Hourly breakdown:**

<img width="897" alt="Hourly forecast" src="https://github.com/user-attachments/assets/b2333da8-c9a5-4c68-bdcf-a27acd0d71df" />

**Astronomy data:**

<img width="375" alt="Astronomy information" src="https://github.com/user-attachments/assets/d9fda475-90b2-47c7-b44d-62594ad5bae9" />

**Emoji mode:**

<img width="566" alt="Emoji icons instead of Nerd Fonts" src="https://github.com/user-attachments/assets/bda9aee8-6e2d-4b73-985d-06b004c79e92" />

**Plain text mode:**

<img width="1208" alt="Plain text output" src="https://github.com/user-attachments/assets/52400ce5-978e-4746-97a3-bde522af94a5" />

## Installation

1. Download `weather.nu`
2. Put it in your Nushell scripts directory (`~/.config/nushell/scripts/` on Linux/Mac, `%APPDATA%\nushell\scripts\` on Windows)
3. Add this to your `config.nu`:

```nushell
use scripts/weather.nu
```

## Usage

```nushell
# Basic usage
weather                    # Current weather at your location
weather "New York"         # Specific city
weather "Paris, France"    # City and country
weather "JFK"              # Airport code
weather "~Eiffel Tower"    # Approximate location
weather "@github.com"      # Domain location

# Display modes
weather -3, --forecast     # 3-day forecast
weather -h, --hourly       # Hourly breakdown (3-hour intervals)
weather -a, --astro        # Sunrise, sunset, moon phase
weather -1, --oneline      # One-line summary (for status bars)

# Unit and display options
weather -m, --metric       # Force metric units (°C, km/h)
weather -i, --imperial     # Force imperial units (°F, mph)
weather -e, --emoji        # Use emojis instead of Nerd Fonts
weather -t, --text         # Plain text, no icons or colors
weather --lang fr          # Weather in French (or de, es, zh, etc.)

# Data output
weather -j, --json         # Return full raw API response
weather -r, --raw          # Return raw record data (for piping)

# Utility
weather -f, --force        # Bypass cache and fetch fresh data
weather --debug            # Show diagnostic info
weather --test             # Use dummy data (no network request)
```
