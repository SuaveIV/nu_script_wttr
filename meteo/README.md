# nu_script_meteo

A fast weather script for [Nushell](https://www.nushell.sh/) that pulls data from [Open-Meteo](https://open-meteo.com) — no API keys needed.

If you use `weather.nu`, this fits alongside it for when you just want current conditions or a quick forecast without waiting. Open-Meteo doesn't have moon or astronomy data, but the script covers current conditions (including gusts), hourly breakdowns, and 3-day forecasts with UV index, air quality, and snowfall. When air quality data isn't available, it shows "N/A" instead of zeros.

Cache entries expire after 15 minutes. Units default to metric or imperial based on your country, but you can force either with a flag.

## Installation

1. Put `meteo.nu` in your Nushell scripts folder:
   - Linux/Mac: `~/.config/nushell/scripts/`
   - Windows: `%APPDATA%\nushell\scripts\`

2. Add this to your `config.nu`:

```nushell
use scripts/meteo.nu
```

Nerd Font icons are off by default. To enable them, set `$env.NERD_FONTS = "1"` in your config. You can also use `-e` for emojis or `-t` for plain text.

## Screenshots

### Normal

<img width="439" height="418" alt="image" src="https://github.com/user-attachments/assets/a968e1b9-30da-467d-8290-5399cbe882f7" />

### Hourly

<img width="991" height="328" alt="image" src="https://github.com/user-attachments/assets/e168efec-703b-43d6-abd7-676e9cc4ab4f" />

### 3-day forecast

<img width="1470" height="333" alt="image" src="https://github.com/user-attachments/assets/4a539bc0-000c-4465-88bb-134fcaf40f2b" />

### Air quality

<img width="420" height="261" alt="image" src="https://github.com/user-attachments/assets/157dcb5d-6e07-4a0a-9c99-c75d1d79e27e" />

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

# Display options
meteo -C                   # Compact output (drops Pressure, Visibility, Clouds) - current weather only
meteo -M                   # Minimal output (also drops UV, Humidity, Feels) - current weather only
meteo --lang fr            # Language for geocoding place names (e.g., 'fr', 'de') - forecast descriptions always in English

# Management
meteo --clear-cache        # Wipe the cache
meteo --debug "London"     # Show diagnostic info
```

## Differences from weather.nu

The flags mostly match `weather.nu`, with a few exceptions:

- **No moon data:** Open-Meteo doesn't include moon phases in the free tier. Sunrise and sunset are still shown.
- **No `~` or `@` syntax:** Use city names. Open-Meteo's geocoder won't resolve landmarks or domains.
- **Extra data:** Includes UV index (color-coded), AQI, and snowfall in the forecast views.
- **Language support:** `--lang` only affects how place names appear in geocoding results. Weather descriptions stay in English since they come from a local lookup table.

## Compact and minimal views

`-C` (compact) and `-M` (minimal) only apply to the current weather view. Hourly and forecast displays have their own fixed layouts and aren't affected.

## Piping

```nushell
meteo -r "New York" | get Temperature
meteo -3 -r -t "London" | where High =~ "2"
meteo -1 "Seoul" | str upcase
meteo -r -t "Berlin" | to json
```

## Cache

Data is saved to `nu_meteo_cache` in your Nushell cache directory, separate from `weather.nu` to avoid conflicts.

## Data sources

- Weather & geocoding: [Open-Meteo](https://open-meteo.com)
- IP location: [ipapi.co](https://ipapi.co)
