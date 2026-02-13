# Weather for Nushell 🌦️

A feature-rich, highly customizable weather fetcher for [Nushell](https://www.nushell.sh/), powered by [wttr.in](https://wttr.in).

## Features

- **Rich Output**: Beautiful tables with ANSI gradients for temperature.
- **Icon Support**: Full support for **Nerd Fonts** (default), standard Emojis, or plain text.
- **Detailed Forecasts**: Current conditions, 3-day forecast, and hourly breakdowns.
- **Astronomy**: Sunrise, sunset, moon phase, and illumination data.
- **Smart Caching**: Caches results for 15 minutes to prevent API rate limiting.
- **Auto-Detection**: Detects location via IP, or accepts city/airport codes.
- **Unit Handling**: Auto-switches between Metric/Imperial based on location (or force with flags).

## Installation

1. Download `weather.nu`.
2. Place it in your Nushell scripts directory (e.g., `~/.config/nushell/scripts/` or `%APPDATA%\nushell\scripts\`).
3. Import it in your `config.nu`:

```nushell
   use scripts/weather.nu
```

## Usage

```nushell
--hourly     #Show hourly forecast
-3, --forecast #Show 3-day forecast
-a, --astro     #Show astronomy data
-m, --metric #Force metric units
-i, --imperial #Force imperial units
-e, --emoji     #Use standard emojis
--text         #Plain text output
-l, --lang     #Specify language (e.g., fr, de)
```
