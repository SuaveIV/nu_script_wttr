# meteo

A fast weather script for [Nushell](https://www.nushell.sh/). It pulls data from [Open-Meteo](https://open-meteo.com) — no API keys or accounts needed. It's built to be faster than `wttr.in`.

If you use `weather.nu`, this is a good companion for when you just want current conditions or a quick forecast without waiting. Open-Meteo doesn't provide moon or astronomy data, but the script handles current conditions (including gusts), hourly breakdowns, and 3-day forecasts with UV index, air quality, and snowfall.

Responses stay in the cache for 15 minutes. Units switch between metric and imperial based on your country, but you can force either with a flag.

## Installation

1. Put `meteo.nu` in your Nushell scripts folder:
   - Linux/Mac: `~/.config/nushell/scripts/`
   - Windows: `%APPDATA%\nushell\scripts\`

2. Add this to your `config.nu`:

```nushell
use scripts/meteo.nu
```

Nerd Font icons are off by default. To enable them, set `$env.NERD_FONTS = "1"` in your config. You can also use `-e` for emojis or `-t` for plain text.

## Usage

```nushell
# Basic
meteo                      # Auto-detect location from IP
meteo "Tokyo"              # By city
meteo "Paris, France"      # City and country

# Views
meteo -3                   # 3-day forecast
meteo -H                   # Hourly breakdown (3-hour intervals)
meteo -1                   # One-line summary
meteo -Q                   # Air quality details

# Units
meteo -m                   # Force metric (°C, km/h)
meteo -i                   # Force imperial (°F, mph)

# Icons
meteo -e "Berlin"          # Use emojis
meteo -t "Berlin"          # Plain text only

# Output
meteo -r                   # Return a raw record (for scripts)
meteo -j                   # Full API response
meteo -f                   # Skip cache and fetch fresh data

# Management
meteo --clear-cache        # Wipe the cache
meteo --debug "London"     # Show diagnostic info
```

## Differences from weather.nu

The flags mostly match `weather.nu`, with a few exceptions:

- **No moon data:** Open-Meteo doesn't include moon phases in the free tier. Sunrise and sunset are still shown.
- **No `~` or `@` syntax:** Use city names. Open-Meteo's geocoder won't resolve landmarks or domains.
- **Extra data:** Includes UV index (color-coded), AQI, and snowfall in the forecast views.

## Piping

```nushell
meteo -r "New York" | get Temperature
meteo -3 -r -t "London" | where High =~ "2"
meteo -1 "Seoul" | str upcase
meteo -r -t "Berlin" | to json
```

## Cache

Data is saved to `nu_meteo_cache` in your Nushell cache directory. This is separate from `weather.nu` to avoid conflicts.

## Data sources

- Weather & Geocoding: [Open-Meteo](https://open-meteo.com)
- IP Location: [ipapi.co](https://ipapi.co)
