# nu_script_meteo

A fast weather script for [Nushell](https://www.nushell.sh/) that pulls from [Open-Meteo](https://open-meteo.com) — no API key, no account, noticeably quicker than wttr.in.

If you already use `weather.nu`, this is a drop-in companion rather than a replacement. It's missing moon/astronomy data (Open-Meteo doesn't provide it), but for current conditions (including wind gusts), hourly, and 3-day forecasts (now with UV index, AQI, and snowfall) it's considerably snappier — which matters when you're putting it in a status bar or just don't want to wait.

Responses are cached for 15 minutes. Units switch automatically between metric and imperial based on country, or you can force either with a flag. Condition text is always in English — `--lang` only affects geocoded place names.

## Installation

1. Download `meteo.nu` and drop it in your Nushell scripts directory
   (`~/.config/nushell/scripts/` on Linux/Mac, `%APPDATA%\nushell\scripts\` on Windows)
2. Add to your `config.nu`:

```nushell
use scripts/meteo.nu
```

Nerd Font icons are off by default. Either set `$env.NERD_FONTS = "1"` in your config, or use `-e` for emojis, or `-t` for plain text.

## Usage

```nushell
# Basic
meteo                      # Auto-detect from IP
meteo "Tokyo"              # City name
meteo "Paris, France"      # City with country

# Views
meteo -3                   # 3-day forecast
meteo -H                   # Hourly breakdown (3-hour intervals)
meteo -1                   # One-line summary for status bars
meteo -q                   # Air quality (AQI, PM2.5, Ozone, NO2)

# Units
meteo -m                   # Force metric (°C, km/h)
meteo -i                   # Force imperial (°F, mph)

# Icons
meteo -e "Berlin"          # Emoji instead of Nerd Fonts
meteo -t "Berlin"          # Plain text, no icons or colors

# Output
meteo -r                   # Return a raw record (pipeable)
meteo -j                   # Return the full API response
meteo -f                   # Bypass cache, fetch fresh

# Housekeeping
meteo --clear-cache        # Wipe all cached data
meteo --debug "London"     # Show what's happening under the hood
```

## Differences from weather.nu

The flag names and behavior are intentionally the same, with two exceptions:

**No `--astro` flag.** Open-Meteo doesn't include moon phase or illumination data in its free tier. Sunrise and sunset are still shown in the current weather view.

**No `~` or `@` location syntax.** wttr.in accepts landmark names (`~Eiffel Tower`) and domain lookups (`@github.com`). Open-Meteo's geocoder only handles city names and will return an error for those formats — just use the nearest city name instead.

**UV in Forecast.** The 3-day forecast view includes the daily maximum UV index (with color-coded risk labels), which `weather.nu` does not currently show.

**Snow in Forecast.** The 3-day forecast view conditionally adds a "Snow" column if any snowfall is predicted for the period.

**Air Quality.** The main view now includes the current Air Quality Index (AQI). The `--air` (or `-q`) flag provides a detailed breakdown (PM2.5, PM10, Ozone, NO2).

Everything else (`--raw`, `--json`, `--text`, `--compact`, `--minimal`, responsive terminal tiers, cache behavior) works the same way.

## Piping

```nushell
meteo -r "New York" | get Temperature
meteo -3 -r -t "London" | where High =~ "2"
meteo -1 "Seoul" | str upcase
meteo -r -t "Berlin" | to json
```

## Cache location

Cached responses go to `nu_meteo_cache` inside Nushell's cache directory — separate from `weather.nu`'s `nu_weather_cache`, so the two scripts don't interfere with each other.

## Data sources

- Weather: [Open-Meteo](https://open-meteo.com) (free, no key required)
- Geocoding: [Open-Meteo Geocoding API](https://open-meteo.com/en/docs/geocoding-api)
- IP auto-detect: [ipapi.co](https://ipapi.co)
