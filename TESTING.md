# weather.nu v3 Test Checklist

## 1. Location Types

```nushell
weather                        # Auto-detect from IP
weather "New York"             # City name
weather "Paris, France"        # City and country
weather "JFK"                  # Airport code
weather "~Eiffel Tower"        # Approximate location
weather "@github.com"          # Domain location
```

- [ ] Auto-detect resolves to a plausible location
- [ ] City name returns correct location
- [ ] City + country returns correct location
- [ ] Airport code resolves correctly
- [ ] `~` landmark resolves to nearest location
- [ ] `@` domain resolves to a location
- [ ] Invalid location returns a helpful error message

---

## 2. View Modes

### Current (default)

```nushell
weather "New York"
```

- [ ] Location, Condition, Temperature, Feels, Clouds, Rain/Snow/Sleet/Hail, Humidity, Wind, Pressure, Visibility, UV, Astronomy, Updated all present
- [ ] Severe weather flag `[SEVERE]` or `⚠️` appears for thunderstorm/blizzard conditions

### Forecast

```nushell
weather -3 "New York"
```

- [ ] 3 days rendered
- [ ] Each day shows Date, Condition, High, Low, Rain, Wind, Moon, Sunrise, Sunset
- [ ] No `first?` error

### Hourly

```nushell
weather -H "New York"
```

- [ ] 8 time slots rendered (3-hour intervals)
- [ ] Each slot shows Time, Condition, Temp, Feels, Precip, Wind, Humidity
- [ ] Snow chance uses snow icon, rain chance uses rain icon

### Astronomy

```nushell
weather -a "New York"
```

- [ ] Sunrise, Sunset, Moonrise, Moonset, Moon Phase, Illumination all present

### Oneline

```nushell
weather -1 "New York"
```

- [ ] Single line output: `Location: icon temp - condition`
- [ ] Works cleanly in a pipeline: `weather -1 "New York" | str length`

---

## 3. Unit Modes

```nushell
weather "London"               # Auto metric (non-US)
weather "New York"             # Auto imperial (US)
weather -m "New York"          # Force metric
weather -i "London"            # Force imperial
```

- [ ] London auto-detects metric (°C, km/h, mm, km, hPa)
- [ ] New York auto-detects imperial (°F, mph, in, mi, inHg)
- [ ] `-m` forces metric on a US city
- [ ] `-i` forces imperial on a non-US city

---

## 4. Display Modes

```nushell
weather "New York"             # Nerd Font icons (default)
weather -e "New York"          # Emoji icons
weather -t "New York"          # Plain text, no icons or colors
```

- [ ] Nerd Font mode shows icon glyphs
- [ ] Emoji mode shows emoji characters
- [ ] Text mode shows no icons and no ANSI color codes
- [ ] All three modes work across current, forecast, hourly, and astro views

---

## 5. Output Modes

```nushell
weather -r "New York"          # Raw record
weather -j "New York"          # Full raw JSON
weather -r -t "New York"       # Raw + text (clean serialization)
weather -r -t "New York" | to json
weather -3 -r -t "New York" | to json
```

- [ ] `-r` returns a Nushell record
- [ ] `-j` returns the full API response as a record
- [ ] `-r -t` produces no ANSI control characters
- [ ] `| to json` succeeds without errors
- [ ] `-3 -r -t | to json` succeeds without errors

---

## 6. Cache Behavior

```nushell
weather "New York"             # Prime the cache
weather "New York"             # Should use cache (check no network call in --debug)
weather -f "New York"          # Force fresh fetch
weather --clear-cache          # Clear all cached data
weather "New York"             # Should recreate cache cleanly
```

- [ ] Second call uses cache (fast, no network)
- [ ] `-f` bypasses cache and fetches fresh data
- [ ] `--clear-cache` prints `Weather cache cleared.`
- [ ] Cache directory is gone after `--clear-cache`
- [ ] Cache directory recreates on next normal run
- [ ] Cache expires after 15 minutes (verify via `--debug`)

---

## 7. Language Support

```nushell
weather --lang fr "Paris"
weather --lang de "Berlin"
weather --lang zh "Tokyo"
```

- [ ] Condition descriptions appear in the specified language
- [ ] Cache key includes language suffix (separate cache per language)

---

## 8. UV Label

| UV Value | Expected Label |
|----------|---------------|
| 0–2      | Low           |
| 3–5      | Moderate      |
| 6–7      | High          |
| 8–10     | Very High     |
| 11+      | Extreme       |

```nushell
weather --test                 # UV 6 → should show High
```

- [ ] UV `6` (test data) shows `High`
- [ ] Label color matches: grey=Low, green=Moderate, yellow=High, red=Very High/Extreme
- [ ] Label appears in text mode too (no ANSI, just the word)

---

## 9. Dynamic Precip Label

Applies to **current weather only**. To test Snow/Sleet/Hail, temporarily change `weatherCode` in `current_condition` in the test data block.

| Weather Code       | Expected Label |
|--------------------|---------------|
| 389 (Thunderstorm) | Rain          |
| 338 (Heavy Snow)   | Snow          |
| 317 (Sleet)        | Sleet         |
| 350 (Hail)         | Hail          |

```nushell
weather --test                 # code 389 → Rain:
```

- [ ] Code `389` → `Rain:`
- [ ] Code `338` → `Snow:` (edit test data to verify)
- [ ] Code `317` → `Sleet:` (edit test data to verify)
- [ ] Code `350` → `Hail:` (edit test data to verify)

---

## 10. Debug and Test Modes

```nushell
weather --debug "New York"     # Full diagnostic output
weather --test                 # Dummy data, no network
weather --test --debug         # Both together
weather --test "imperial"      # Imperial dummy data
```

- [ ] `--debug` prints URL, cache path, cache validity, unit mode, view mode
- [ ] `--debug` shows connectivity test result
- [ ] `--test` skips network request entirely
- [ ] `--test "imperial"` or `--test "carrollton"` triggers imperial dummy data
- [ ] `--test --debug` shows `⚠ USING DUMMY TEST DATA`

---

## 11. Error Handling

```nushell
weather "asdfjkl;"             # Invalid location
weather --debug "asdfjkl;"    # Invalid location with debug
```

- [ ] Invalid location returns a helpful error with suggestion to try airport code or `~` landmark
- [ ] Network failure returns a readable error (disconnect and test if possible)
- [ ] Debug mode shows extended failure diagnostics

---

## 12. Pipeline Integration

```nushell
weather -r "New York" | get Temperature
weather -3 -r -t "New York" | where High =~ "7"
weather -1 "New York" | str upcase
weather -r -t "New York" | to json | clipboard copy
weather -3 -r -t "New York" | to toon
```

- [ ] `get` extracts a single field cleanly
- [ ] `where` filters forecast rows
- [ ] Oneline output pipes as a plain string
- [ ] `to json | clipboard copy` works without control character errors
- [ ] `to toon` produces compact TOON output (requires nu_plugin_toon)

---

## 13. Edge Cases

### 13.1 Temperature gradient boundaries (`format-temp`)

The colour gradient switches at exact thresholds:
- Imperial: hot ≥ 80°F (yellow→red), cold ≤ 40°F (white→cyan), mild between (green→yellow)
- Metric: hot ≥ 27°C, cold ≤ 4°C

```nushell
# Verify gradient boundaries using test data + raw output
weather --test -r -t | get Temperature       # should be 72°F (mild range → green→yellow)
weather --test -i -r -t | get Temperature    # 72°F (mild)

# Negative temperature — from day 2 of test forecast (mintempF = 28, mintempC = -2)
weather --test -3 -r -t | get Low | first    # 59°F / 15°C (day 1, mild)
weather --test -3 -r -t | get Low | last     # 41°F / 5°C (day 3, near cold limit)
```

- [ ] Temperature at exactly the hot limit renders with hot gradient (or hot colour in text mode)
- [ ] Temperature at exactly the cold limit renders with cold gradient
- [ ] Negative temperature string (`"-5"`) parses correctly without error
- [ ] `--text` mode never emits ANSI codes regardless of temperature value

---

### 13.2 Beaufort scale boundaries (`beaufort-scale`)

| km/h input | Expected Bft |
|-----------|-------------|
| 0         | 0 (Calm)    |
| 1         | 1           |
| 5         | 1           |
| 6         | 2           |
| 11        | 2           |
| 12        | 3           |
| 117       | 11          |
| 118       | 12 (Hurricane) |

```nushell
# Fog test slot has windspeedKmph = 0 (Calm)
weather --test -H -r -t | last | get Wind   # should contain [Bft 0] in emoji/text mode
```

- [ ] Wind speed `"0"` → Bft 0
- [ ] Wind speed `"1"` → Bft 1
- [ ] Wind speed `"118"` → Bft 12
- [ ] `beaufort-icon` in Nerd Font mode emits a non-empty glyph for every scale 0–12
- [ ] `beaufort-icon` in `--emoji` and `--text` modes emits `[Bft N]` for every scale 0–12

---

### 13.3 All wind directions + unknown fallback (`wind-dir-icon`)

All 16 compass points and the unknown fallback should resolve without error.

```nushell
# Spot-check a few in text mode (returns the raw string)
weather --test -H -r -t | get Wind   # NW slot
weather --test -3 -r -t | get Wind   # N, E slots across days
```

| Input | Expected (Nerd Font) | Expected (emoji/text) |
|-------|---------------------|----------------------|
| N     | glyph               | N                    |
| NNE   | glyph               | NNE                  |
| SSW   | glyph               | SSW                  |
| WNW   | glyph               | WNW                  |
| (unknown, e.g. "VAR") | fallback → raw string | VAR |

- [ ] All 16 standard compass points return a non-empty glyph in Nerd Font mode
- [ ] All 16 points return the raw direction string in `--emoji` / `--text` modes
- [ ] Unrecognised direction string (e.g. `"VAR"`) is returned unchanged

---

### 13.4 Moon phase edge cases (`moon-icon`)

#### Illumination boundary values

| Illumination | Expected fallback icon |
|-------------|----------------------|
| 0           | New Moon             |
| 4           | New Moon (< 5)       |
| 5           | Waxing Crescent (< 45) |
| 44          | Waxing Crescent      |
| 45          | First Quarter (< 55) |
| 54          | First Quarter        |
| 55          | Waxing Gibbous (< 95) |
| 94          | Waxing Gibbous       |
| 95          | Full Moon (≥ 95)     |
| 100         | Full Moon            |

Test data covers Waxing Crescent (10%), First Quarter (50%), and Full Moon (100%) — the **waning** phases are not exercised by test data and must be checked against live data or by temporarily editing the test block.

```nushell
# Full Moon is day 3 of test forecast — illumination 100%
weather --test -a -r -t | get "Moon Phase"        # should show Full Moon glyph/emoji
weather --test -a -r -t --emoji | get "Moon Phase" # should show 🌕
```

- [ ] Illumination `"0"` → New Moon icon
- [ ] Illumination `"100"` → Full Moon icon
- [ ] Phase string `"Waning Gibbous"` → correct waning icon (live data test)
- [ ] Phase string `"Last Quarter"` → correct last-quarter icon (live data test)
- [ ] Phase string `"Waning Crescent"` → correct icon (live data test)
- [ ] Completely unrecognised phase string falls back to illumination-based icon

---

### 13.5 Unknown weather code fallback (`weather-icon`)

An unrecognised code (e.g. `"999"`) should return the thermometer fallback glyph in Nerd Font mode and `🌡️` in emoji mode.

```nushell
# No direct test command — verify by reading source match arms cover all listed codes
# and that the _ arm is present.
```

- [ ] Nerd Font mode `_` arm returns a non-empty fallback glyph
- [ ] Emoji mode `_` arm returns `🌡️`
- [ ] `--text` mode always returns empty string regardless of code

---

### 13.6 Unicode / special-character city names

URL encoding must handle non-ASCII input without corrupting the API URL or the cache filename.

```nushell
weather "Zürich"           # umlaut
weather "São Paulo"        # tilde + cedilla
weather "東京"             # full CJK
weather "Montréal"         # accent
```

- [ ] `Zürich` resolves to Zurich, Switzerland
- [ ] `São Paulo` resolves correctly
- [ ] `東京` resolves to Tokyo
- [ ] Cache file is created with a URL-encoded filename (no raw Unicode in the path)
- [ ] `--debug` shows the URL-encoded form in `URL encoded:` line

---

### 13.7 `--clear-cache` when cache does not exist

```nushell
weather --clear-cache      # prime removal
weather --clear-cache      # run again when directory is already gone
```

- [ ] Second `--clear-cache` prints `Weather cache cleared.` without error (or exits cleanly even if the dir is missing)

---

### 13.8 Invalid language code

```nushell
weather --lang "zzz" "London"
```

- [ ] Command does not crash (wttr.in likely ignores the unknown lang and returns English)
- [ ] Cache key contains `_zzz` suffix, isolating it from the default cache

---

### 13.9 Conflicting unit flags (`--metric` + `--imperial`)

When both flags are passed, imperial takes priority (code checks `$imperial` first).

```nushell
weather --metric --imperial "London"
```

- [ ] Output shows imperial units (°F, mph) — imperial wins
- [ ] `--debug` reports `Unit Override: Imperial`

---

### 13.10 `--json` short-circuits all other view flags

`--json` returns the raw API record immediately, before any view-mode branching.

```nushell
weather -j "New York" | describe          # should be "record"
weather -j -3 "New York" | describe      # still returns full record, not a table
weather -j -H "New York" | describe      # same
weather --test -j | get current_condition | length  # should be 1
```

- [ ] `-j` always returns a record regardless of `-3`, `-H`, `-a`, or `-1`
- [ ] The record contains `current_condition`, `weather`, and `nearest_area` keys

---

### 13.11 `--test` combined with every view mode and unit override

```nushell
weather --test                        # Current, metric (Testland)
weather --test "imperial"             # Current, imperial (United States)
weather --test --metric "imperial"    # Force metric even though city triggers imperial
weather --test --imperial             # Force imperial on metric test data
weather --test --forecast             # 3-day forecast, metric
weather --test --forecast --imperial  # 3-day forecast, imperial
weather --test --hourly               # Hourly, metric
weather --test --hourly --imperial    # Hourly, imperial
weather --test --astro                # Astronomy
weather --test --oneline              # Single line
weather --test --json                 # Raw API record
weather --test --raw                  # Raw record output
weather --test --emoji                # Emoji icons
weather --test --text                 # Plain text
```

- [ ] All combinations above complete without error
- [ ] `--test --metric "imperial"` forces °C even though the city keyword contains "imperial"
- [ ] `--test --imperial` forces °F on the metric (Testland) test data
- [ ] `--test --forecast` shows 3 rows (Fri Oct 27, Sat Oct 28, Sun Oct 29)
- [ ] `--test --hourly` shows exactly 1 row per day (test data only has one `hourly` slot per day)

---

### 13.12 Hourly midnight time slot (`"0"` → `"00:00"`)

The time formatting pads `"0"` to `"0000"` and then slices to `"00:00"`.

```nushell
# There is no midnight slot in the current test data.
# To test, temporarily add an hourly entry with time: '0' to the first day's hourly list.
# Expected display: "00:00"
```

- [ ] Time `"0"` renders as `"00:00"` (not `"0:"` or `":0"`)
- [ ] Time `"300"` renders as `"03:00"`
- [ ] Time `"1200"` renders as `"12:00"` *(already covered by test data)*

---

### 13.13 Auto-detect + `--lang` cache key

When no city is provided (auto-detect) and `--lang` is set, the cache file should be `auto_<lang>.json`, not `auto.json`.

```nushell
weather --lang fr --debug    # look for "Cache Path: .../auto_fr.json"
weather --lang fr            # second call should hit cache
weather --debug              # English auto-detect — separate "auto.json" cache
```

- [ ] `--debug` shows `Cache Path: …/auto_fr.json` when `--lang fr` with no city
- [ ] English auto-detect uses `auto.json` (no suffix)
- [ ] French and English auto-detect caches are independent

---

### 13.14 `--raw` with each non-default view mode

```nushell
weather --test --astro --raw        # returns raw current_astro record
weather --test --hourly --raw       # returns list<record>
weather --test --forecast --raw     # returns list<record>
weather --test --raw                # returns output record (current weather)
```

- [ ] `--astro --raw` returns the astronomy sub-record (not a table)
- [ ] `--hourly --raw` returns a list of records
- [ ] `--forecast --raw` returns a list of records
- [ ] All `--raw` variants produce no printed header line
