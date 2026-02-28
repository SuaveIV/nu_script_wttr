# Fetches and displays weather information from wttr.in with rich formatting.
#
# This command retrieves current weather conditions, astronomy data, and forecasts
# for a specified location or auto-detected based on IP. It supports both
# Imperial (US) and Metric units based on the location's country.
#
# Data provided by wttr.in (https://github.com/chubin/wttr.in).
#
# Search terms: weather, forecast, meteorology, wttr, climate
#
# Examples:
#   > weather                     # Use default location
#   > weather "New York"          # Specific city
#   > weather "Paris, France"     # City and country
#   > weather "JFK"               # Airport code
#   > weather "~Eiffel Tower"     # Approximate location
#   > weather "@github.com"       # Domain location
#   > weather -3                  # 3-day forecast
#   > weather --hourly            # Hourly forecast
#   > weather --astro             # Astronomy data
#   > weather --lang fr           t # Weather in French
#   > weather --debug             # Run with diagnostic info

const COL_FULL_WIDTH = 100
const COL_COMPACT_WIDTH = 80
const COL_MINIMAL_WIDTH = 60
const COL_ONELINE_WIDTH = 0

# Helper Commands

# Formats a raw temperature value into a human-readable string with a unit label.
#
# Applies an ANSI colour gradient when not in plain-text mode:
#   - Hot  (>= hot_limit)  → yellow-to-red gradient
#   - Cold (<= cold_limit) → white-to-cyan gradient
#   - Mild (between)       → green-to-yellow gradient
#
# Examples:
#   > format-temp "72" {temp_label: "°F", hot_limit: 80, cold_limit: 40}
#   72°F
#   > format-temp "95" {temp_label: "°F", hot_limit: 80, cold_limit: 40} --text
#   95°F
def format-temp [
    val: string           # Raw temperature value from API
    units: record<        # Unit configuration record
        temp_label: string,
        hot_limit: int,
        cold_limit: int
    >
    --text                # Plain text mode (no ANSI color)
]: nothing -> string {
    let temp_int = ($val | into int)
    if $text {
        $"($val)($units.temp_label)"
    } else {
        let gradient = if $temp_int >= $units.hot_limit {
            { s: '0xffff00', e: '0xff0000' } # Yellow -> Red
        } else if $temp_int <= $units.cold_limit {
            { s: '0xffffff', e: '0x00ffff' } # White -> Cyan
        } else {
            { s: '0x00ff00', e: '0xffff00' } # Green -> Yellow
        }
        $"($val)($units.temp_label)" | ansi gradient --fgstart $gradient.s --fgend $gradient.e
    }
}

# Returns a weather condition icon for the given WorldWeatherOnline weather code.
#
# Defaults to Nerd Font glyphs. Pass --emoji to use Unicode emoji instead,
# or --text to suppress all icons (returns an empty string).
#
# Examples:
#   > weather-icon "113"           # Nerd Font sunny glyph
#   > weather-icon "389" --emoji   # ⛈️  (thunderstorm)
#   > weather-icon "113" --text    # (empty string)
def weather-icon [
    code: string          # WorldWeatherOnline weather code
    icon_mode: string     # Icon mode: "emoji", "nerd", or "text"
]: nothing -> string {
    if $icon_mode == 'text' { return "" }
    if $icon_mode == 'emoji' {
        match $code {
            '113' => "☀️",
            '116' => "⛅",
            '119' => "☁️",
            '122' => "☁️",
            '143' => "🌫️",
            '248' => "🌫️",
            '260' => "🌫️",
            '176' | '263' | '266' | '293' | '296' | '353' => "🌦️",
            '299' | '302' => "🌧️",
            '305' | '308' | '356' | '359' => "🌧️",
            '185' | '281' | '284' => "🌧️",
            '179' | '323' | '326' | '368' => "🌨️",
            '329' | '332' => "❄️",
            '335' | '338' | '371' => "❄️",
            '227' | '230' => "🌨️",
            '182' | '317' | '320' | '362' | '365' => "🌨️",
            '311' | '314' => "🌧️",
            '350' | '374' | '377' => "🧊",
            '200' | '386' => "⛈️",
            '389' => "⛈️",
            '392' | '395' => "⛈️",
            _ => "🌡️"
        }
    } else {
        match $code {
            '113' => "", # nf-weather-day_sunny
            '116' => "", # nf-weather-day_cloudy
            '119' | '122' => "", # nf-weather-cloudy
            '143' | '248' | '260' => "", # nf-weather-fog
            '176' | '263' | '266' | '293' | '296' | '353' => "", # nf-weather-day_rain
            '299' | '302' | '305' | '308' | '356' | '359' => "", # nf-weather-rain
            '185' | '281' | '284' | '311' | '314' => "", # nf-weather-rain_mix (Freezing Rain/Drizzle)
            '179' | '323' | '326' | '368' | '329' | '332' | '335' | '338' | '371' => "", # nf-weather-snow
            '227' | '230' => "", # nf-weather-snow_wind (Blizzard)
            '182' | '317' | '320' | '362' | '365' => "", # nf-weather-sleet
            '350' | '374' | '377' => "", # nf-weather-hail
            '200' => "", # nf-weather-lightning
            '386' | '389' | '392' | '395' => "", # nf-weather-thunderstorm
            _ => "" # nf-weather-thermometer (Fallback)
        }
    }
}

# Returns a moon-phase icon that best matches the given phase name and illumination.
#
# Phase name matching takes priority; illumination percentage is used as a fallback
# when the phase string is unrecognised. Supports Nerd Font glyphs (default) and
# Unicode emoji (--emoji). Pass --text to suppress all icons (returns an empty string).
#
# Examples:
#   > moon-icon "Full Moon" "100"           # Nerd Font full-moon glyph
#   > moon-icon "Waxing Crescent" "30" --emoji  # 🌒
#   > moon-icon "Unknown" "50" --text       # (empty string)
def moon-icon [
    phase: string         # Moon phase name from API
    illum: string         # Moon illumination percentage as API string
    icon_mode: string     # Icon mode: "emoji", "nerd", or "text"
]: nothing -> string {
    if $icon_mode == 'text' { return "" }
    let illum_int = ($illum | into int)
    let phase_lower = ($phase | str downcase)

    let fallback = if $icon_mode == 'emoji' {
        match $illum_int {
            $x if $x < 5 => "🌑",
            $x if $x < 45 => "🌒",
            $x if $x < 55 => "🌓",
            $x if $x < 95 => "🌔",
            _ => "🌕"
        }
    } else {
        match $illum_int {
            $x if $x < 5 => "", # nf-weather-moon_new
            $x if $x < 45 => "", # nf-weather-moon_waxing_crescent_1
            $x if $x < 55 => "", # nf-weather-moon_first_quarter
            $x if $x < 95 => "", # nf-weather-moon_waxing_gibbous_1
            _ => "" # nf-weather-moon_full
        }
    }

    if $icon_mode == 'emoji' {
        match $phase_lower {
            $s if ($s | str contains 'new moon') => "🌑",
            $s if ($s | str contains 'waxing crescent') => "🌒",
            $s if ($s | str contains 'first quarter') => "🌓",
            $s if ($s | str contains 'waxing gibbous') => "🌔",
            $s if ($s | str contains 'full moon') => "🌕",
            $s if ($s | str contains 'waning gibbous') => "🌖",
            $s if ($s | str contains 'last quarter') => "🌗",
            $s if ($s | str contains 'waning crescent') => "🌘",
            _ => $fallback
        }
    } else {
        match $phase_lower {
            $s if ($s | str contains 'new moon') => "",
            $s if ($s | str contains 'waxing crescent') => "",
            $s if ($s | str contains 'first quarter') => "",
            $s if ($s | str contains 'waxing gibbous') => "",
            $s if ($s | str contains 'full moon') => "",
            $s if ($s | str contains 'waning gibbous') => "",
            $s if ($s | str contains 'last quarter') => "",
            $s if ($s | str contains 'waning crescent') => "",
            _ => $fallback
        }
    }
}

# Converts a wind speed in km/h to its Beaufort scale number (0–12).
#
# Uses the standard Beaufort wind force scale thresholds as defined by the
# World Meteorological Organization.
#
# Examples:
#   > beaufort-scale "0"    # 0  (Calm)
#   > beaufort-scale "50"   # 6  (Strong Breeze)
#   > beaufort-scale "120"  # 12 (Hurricane)
def beaufort-scale [
    kmph: string          # Wind speed in km/h as API string
]: nothing -> int {
    let k = ($kmph | into int)
    match $k {
        $x if $x < 1 => 0,
        $x if $x <= 5 => 1,
        $x if $x <= 11 => 2,
        $x if $x <= 19 => 3,
        $x if $x <= 28 => 4,
        $x if $x <= 38 => 5,
        $x if $x <= 49 => 6,
        $x if $x <= 61 => 7,
        $x if $x <= 74 => 8,
        $x if $x <= 88 => 9,
        $x if $x <= 102 => 10,
        $x if $x <= 117 => 11,
        _ => 12
    }
}

# Returns an icon or bracketed label representing the given Beaufort scale number.
#
# In Nerd Font mode each Beaufort level maps to a distinct wind-strength glyph.
# In emoji or plain-text mode a bracketed label such as "[Bft 6]" is returned instead.
#
# Examples:
#   > beaufort-icon 0          # Nerd Font calm-wind glyph
#   > beaufort-icon 6 --emoji  # [Bft 6]
#   > beaufort-icon 6 --text   # [Bft 6]
def beaufort-icon [
    scale: int            # Beaufort scale number
    icon_mode: string     # Icon mode: "emoji", "nerd", or "text"
]: nothing -> string {
    if $icon_mode == 'emoji' or $icon_mode == 'text' {
        return $"[Bft ($scale)]"
    }
    match $scale {
        0 => "", 1 => "", 2 => "", 3 => "", 4 => "", 5 => "",
        6 => "", 7 => "", 8 => "", 9 => "", 10 => "", 11 => "", _ => ""
    }
}

# Returns a directional arrow icon for the given cardinal or intercardinal wind direction.
#
# In Nerd Font mode each compass point maps to a directional arrow glyph.
# In emoji or plain-text mode the raw direction string (e.g. "SW") is returned unchanged.
#
# Examples:
#   > wind-dir-icon "N"           # Nerd Font north-arrow glyph
#   > wind-dir-icon "SW" --emoji  # SW
#   > wind-dir-icon "E" --text    # E
def wind-dir-icon [
    dir: string           # Wind direction (e.g. N, SW)
    icon_mode: string     # Icon mode: "emoji", "nerd", or "text"
]: nothing -> string {
    if $icon_mode == 'emoji' or $icon_mode == 'text' {
        return $dir
    }
    match ($dir | str upcase) {
        'N' => "", # nf-weather-wind_north
        'NNE' | 'NE' | 'ENE' => "", # nf-weather-wind_north_east
        'E' => "", # nf-weather-wind_east
        'ESE' | 'SE' | 'SSE' => "", # nf-weather-wind_south_east
        'S' => "", # nf-weather-wind_south
        'SSW' | 'SW' | 'WSW' => "", # nf-weather-wind_south_west
        'W' => "", # nf-weather-wind_west
        'WNW' | 'NW' | 'NNW' => "", # nf-weather-wind_north_west
        _ => $dir
    }
}

# Resolves and creates the cache directory.
def resolve-cache-dir [
    subdir: string # Subdirectory name for the cache
]: nothing -> string {
    $nu.cache-dir? | default ($env.TEMP? | default $env.TMP? | default '/tmp') | let base_dir: string
    $base_dir | path join $subdir | let cache_dir: string
    if not ($cache_dir | path exists) { mkdir $cache_dir }
    $cache_dir
}

# Checks if a cache file is valid based on its modification time and TTL.
def is-cache-valid [
    cache_path: string # Path to the cache file
    ttl: duration      # Time-to-live for the cache
]: nothing -> bool {
    if ($cache_path | path exists) {
        let modified = (ls $cache_path | get modified | first)
        ((date now) - $modified) < $ttl
    } else { false }
}

# Performs an HTTP GET request with retry logic and backoff.
def http-get-with-retry [
    url: string
    max_retries: int = 3
    timeout: duration = 10sec
]: nothing -> any {
    mut attempt = 0
    loop {
        let error_record = try {
            return (http get $url -m $timeout)
        } catch {|e|
            $e
        }

        if $attempt >= $max_retries {
            error make { msg: $error_record.msg }
        }
        $attempt = $attempt + 1
        sleep (($attempt * 200) * 1ms)
    }
}

# Builds the astronomy display data.
def build-astro-display [astro: record, loc: string, mode: string, --raw]: nothing -> any {
    let moon_icon = (moon-icon $astro.moon_phase $astro.moon_illumination $mode)
    let s_icon = if $mode == 'emoji' { '🌅 ' } else if $mode == 'nerd' { " " } else { '' }
    let t_icon = if $mode == 'emoji' { '🌇 ' } else if $mode == 'nerd' { " " } else { '' }

    let output = {
        "Sunrise": $"($s_icon)($astro.sunrise)",
        "Sunset": $"($t_icon)($astro.sunset)",
        "Moon Phase": $"($moon_icon) ($astro.moon_phase)",
        "Illumination": $"($astro.moon_illumination)%"
    }

    if $raw { $astro } else {
        print $"(ansi cyan_bold)Astronomy for ($loc)(ansi reset)"
        $output | table -i false
    }
}

# Builds the hourly forecast display data.
def build-hourly-display [today: record, units: record, loc: string, mode: string, --raw, --debug]: nothing -> any {
    if $debug { print $"(ansi cyan)ℹ Processing Hourly Forecast...(ansi reset)" }
    let hourly_table = ($today.hourly | compact | each {|hour|
        let t_str = ($hour.time | fill -a r -w 4 -c '0')
        let is_us = ($units.temp_label == '°F')
        let temp = if $is_us { $hour.tempF } else { $hour.tempC }
        let desc = ($hour.weatherDesc | first | get value)

        {
            Time: $"($t_str | str substring 0..1):($t_str | str substring 2..3)",
            Condition: (if $mode == 'text' { $desc } else { $"((weather-icon $hour.weatherCode $mode)) ($desc)" }),
            Temp: (format-temp $temp $units --text=($mode == 'text')),
            Wind: $"((wind-dir-icon $hour.winddir16Point $mode)) ($hour | get $units.speed_key)($units.speed_label)",
            Humidity: $"($hour.humidity)%"
        }
    })

    if $raw { $hourly_table } else {
        print $"(ansi cyan_bold)Hourly Forecast for ($loc)(ansi reset)"
        $hourly_table | table -i false
    }
}

# Builds the 3-day forecast display data.
def build-forecast-display [weather: list<any>, units: record, loc: string, mode: string, --raw]: nothing -> any {
    let forecast_table = ($weather | compact | each {|day|
        let noon = ($day.hourly | where time == '1200' | append ($day.hourly | first) | first)
        let desc = ($noon.weatherDesc | first | get value)
        {
            Date: ($day.date | into datetime | format date '%a, %b %d'),
            High: (format-temp ($day | get $units.forecast_max_key) $units --text=($mode == 'text')),
            Low: (format-temp ($day | get $units.forecast_min_key) $units --text=($mode == 'text')),
            Condition: (if $mode == 'text' { $desc } else { $"((weather-icon $noon.weatherCode $mode)) ($desc)" }),
            Rain: $"($noon | get $units.precip_key)($units.precip_label)"
        }
    })

    if $raw { $forecast_table } else {
        print $"(ansi cyan_bold)3-Day Forecast for ($loc)(ansi reset)"
        $forecast_table | table -i false
    }
}

# Returns dummy weather data for testing purposes.
def test-data [use_imperial: bool]: nothing -> record {
    let test_country = if $use_imperial { 'United States' } else { 'Testland' }

    {
        current_condition: [{
            temp_F: '72', temp_C: '22',
            FeelsLikeF: '70', FeelsLikeC: '21',
            windspeedMiles: '15', windspeedKmph: '24',
            precipInches: '0.1', precipMM: '2.5',
            visibilityMiles: '5', visibility: '8',
            pressureInches: '29.9', pressure: '1012',
            uvIndex: '6',
            weatherCode: '389', # Severe Thunderstorm code
            weatherDesc: [{value: 'Thunderstorm (Test)'}],
            localObsDateTime: '2023-10-27 12:00 PM',
            observation_time: '04:00 PM',
            cloudcover: '75',
            humidity: '80',
            winddir16Point: 'SE'
        }],
        weather: [{
            astronomy: [{
                sunrise: '06:30 AM',
                sunset: '07:45 PM',
                moonrise: '07:00 PM',
                moonset: '05:00 AM',
                moon_illumination: '10',
                moon_phase: 'Waxing Crescent'
            }],
            date: '2023-10-27',
            maxtempC: '25', maxtempF: '77',
            mintempC: '15', mintempF: '59',
            hourly: [{
                weatherCode: '113', weatherDesc: [{value: 'Sunny'}], time: '1200',
                windspeedMiles: '5', windspeedKmph: '8', winddir16Point: 'NW',
                precipInches: '0.0', precipMM: '0.0',
                tempC: '25', tempF: '77', FeelsLikeC: '26', FeelsLikeF: '79',
                chanceofrain: '0', chanceofsnow: '0', humidity: '40'
            }]
        },
        {
            astronomy: [{
                sunrise: '06:31 AM',
                sunset: '07:44 PM',
                moonrise: '07:45 PM',
                moonset: '06:00 AM',
                moon_illumination: '50',
                moon_phase: 'First Quarter'
            }],
            date: '2023-10-28',
            maxtempC: '2', maxtempF: '35',
            mintempC: '-2', mintempF: '28',
            hourly: [{
                weatherCode: '338', weatherDesc: [{value: 'Heavy Snow'}], time: '1200',
                windspeedMiles: '20', windspeedKmph: '32', winddir16Point: 'N',
                precipInches: '0.5', precipMM: '12.0',
                tempC: '0', tempF: '32', FeelsLikeC: '-5', FeelsLikeF: '23',
                chanceofrain: '0', chanceofsnow: '90', humidity: '85'
            }]
        },
        {
            astronomy: [{
                sunrise: '06:32 AM',
                sunset: '07:43 PM',
                moonrise: '08:30 PM',
                moonset: '07:00 AM',
                moon_illumination: '100',
                moon_phase: 'Full Moon'
            }],
            date: '2023-10-29',
            maxtempC: '10', maxtempF: '50',
            mintempC: '5', mintempF: '41',
            hourly: [{
                weatherCode: '248', weatherDesc: [{value: 'Fog'}], time: '1200',
                windspeedMiles: '0', windspeedKmph: '0', winddir16Point: 'E',
                precipInches: '0.0', precipMM: '0.0',
                tempC: '10', tempF: '50', FeelsLikeC: '10', FeelsLikeF: '50',
                chanceofrain: '10', chanceofsnow: '0', humidity: '95'
            }]
        }],
        nearest_area: [{
            areaName: [{value: 'Test City'}],
            region: [{value: 'Test Region'}],
            country: [{value: $test_country}]
        }]
    }
}

# Fetches and displays weather information from wttr.in with rich formatting.
#
# Retrieves current conditions, hourly forecasts, 3-day forecasts, and astronomy
# data for any location. Units (Imperial/Metric) are selected automatically based
# on the location's country, or can be forced with --imperial / --metric.
# Results are cached for 15 minutes; use --force to bypass the cache.
#
# Data provided by wttr.in (https://github.com/chubin/wttr.in).
#
# Examples:
#   > weather                      # Current weather, auto-detected location
#   > weather "New York"           # Current weather for a specific city
#   > weather "Paris, France"      # City and country
#   > weather "JFK"                # Airport code
#   > weather "~Eiffel Tower"      # Approximate / landmark location
#   > weather "@github.com"        # Domain-based location lookup
#   > weather --forecast           # 3-day forecast
#   > weather --hourly             # Hourly breakdown for today
#   > weather --astro              # Sunrise, sunset, moon phase
#   > weather --lang fr            # Output in French
#   > weather --emoji              # Use emoji icons instead of Nerd Fonts
#   > weather --text               # Plain text, no icons or colours
#   > weather --raw                # Return a record (pipeable)
#   > weather --json               # Return the raw wttr.in API response
#   > weather --debug              # Print network and parsing diagnostics
export def main [
    city: string = ""               # The location to fetch weather for. Leave empty to auto-detect.
    --raw (-r)                      # Return raw record data instead of a formatted table (useful for piping).
    --debug                         # Print detailed network and parsing diagnostics.
    --test                          # Use dummy data for testing purposes without making network requests.
    --metric (-m)                   # Force metric units (°C, km/h) regardless of location.
    --imperial (-i)                 # Force imperial units (°F, mph) regardless of location.
    --forecast (-3)                 # Show weather forecast for the next 3 days.
    --oneline (-1)                  # Show a single line summary (e.g. for status bars).
    --compact (-c)                  # Force compact output (drops Pressure, Visibility, Clouds, Updated).
    --minimal (-M)                  # Force minimal output (also drops UV, Humidity, Feels).
    --json (-j)                     # Return the full raw API response as data.
    --emoji (-e)                    # Use Emojis instead of Nerd Font icons (Default is Nerd Fonts).
    --text (-t)                     # Plain text output (no icons, no colors).
    --force (-f)                    # Bypass cache and force a network request.
    --astro (-a)                    # Show detailed astronomy data (Sunrise, Sunset, Moon phase, etc).
    --hourly (-H)                   # Show hourly forecast for today (3-hour intervals).
    --clear-cache                   # Clear all cached weather data and exit.
    --lang: string = ""             # Specify language code (e.g. 'fr', 'de', 'es', 'zh'). Empty = auto.
]: nothing -> any {
    # Resolve icon mode based on flags and environment
    let icon_mode: string = if $emoji {
        'emoji'
    } else if $text {
        'text'
    } else if ($env.NERD_FONTS? == '1') {
        'nerd'
    } else {
        'text'
    }

    # URL encode for API (handles all special chars including Unicode)
    $city | url encode | let url_encoded_city: string

    # Display name is just the original input
    let display_city: string = if ($city | is-empty) { 'Auto-detect' } else { $city }

    # Build the full URL
    let language_param: string = if ($lang | is-empty) { '' } else { $"&lang=($lang)" }
    $"https://wttr.in/($url_encoded_city)?format=j1($language_param)" | let url: string

    # Cache Configuration
    resolve-cache-dir 'nu_weather_cache' | let cache_dir: string

    if $clear_cache {
        rm -rf $cache_dir
        print 'Weather cache cleared.'
        return
    }

    let language_suffix: string = if ($lang | is-empty) { '' } else { $"_($lang)" }
    let cache_file: string = if ($url_encoded_city | is-empty) { $"auto($language_suffix).json" } else { $"($url_encoded_city)($language_suffix).json" }
    $cache_dir | path join $cache_file | let cache_path: string
    let is_cache_valid: bool = if $force {
        false
    } else {
        is-cache-valid $cache_path 15min
    }

    if $debug {
        print $"(ansi cyan)🔍 DEBUG MODE ENABLED(ansi reset)"
        print $"(ansi grey)━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━(ansi reset)"
        print $"Original input: '($city)'"
        print $"URL encoded:    '($url_encoded_city)'"
        print $"Request URL:    ($url)"
        print $"(ansi grey)━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━(ansi reset)"
        print $"Cache Path:     ($cache_path)"
        print $"Cache Valid:    ($is_cache_valid)"
        print $"Language:       (if ($lang | is-empty) { 'Auto' } else { $lang })"
        print $"Display Mode:   (if $icon_mode == 'text' { 'Text' } else if $icon_mode == 'emoji' { 'Emoji' } else { 'Nerd Font' })"
        print $"Unit Override:  (if $metric { 'Metric' } else if $imperial { 'Imperial' } else { 'Auto' })"
        print $"View Mode:      (if $hourly { 'Hourly' } else if $astro { 'Astronomy' } else if $forecast { 'Forecast' } else { 'Current' })"
        print ""

        if not $test {
            # Test basic connectivity first
            print 'Testing basic connectivity...'
            let connectivity_test = try {
                http get 'https://wttr.in' -m 5sec
                print $"(ansi green)✓ wttr.in is reachable(ansi reset)"
                true
            } catch {|err|
                print $"(ansi red)✗ Cannot reach wttr.in(ansi reset)"
                print $"  Error: ($err.msg)"
                false
            }

            if not $connectivity_test {
                print ""
                print $"(ansi yellow)Connectivity test failed. Possible causes:(ansi reset)"
                print '  1. Network/internet connection down'
                print '  2. Firewall blocking HTTPS requests'
                print '  3. DNS resolution failing'
                print '  4. wttr.in service temporarily down'
                print ""
                print 'Try: curl wttr.in (in regular terminal to test)'
                error make {
                    msg: "Connectivity test failed"
                    help: "Check your internet connection or firewall settings"
                }
            }
        }

        print ""
        print 'Attempting weather data fetch...'
    }

    # Fetch weather data with proper error handling
    let response: record = if $test {
        if $debug {
            print $"(ansi yellow)⚠ USING DUMMY TEST DATA(ansi reset)"
            print 'Skipping network request...'
        }

        # Toggle between Metric/Imperial based on input for testing
        let use_imperial = if $imperial {
            true
        } else if $metric {
            false
        } else {
            ($city | str downcase | str contains 'imperial') or ($city | str downcase | str contains 'united states') or ($city | str downcase | str contains 'carrollton')
        }
        test-data $use_imperial
    } else if $is_cache_valid {
        if $debug { print $"(ansi green)✓ Using cached data(ansi reset)" }
        open $cache_path
    } else {
        # Clear old cache if it exists before fetching new data
        if ($cache_path | path exists) {
            rm $cache_path
        }

        try {
            if $debug {
                print $"(ansi grey)Sending request...(ansi reset)"
            }
            let res = (http-get-with-retry $url)
            $res | save -f $cache_path
            $res
        } catch {|err|
            if $debug {
                print ""
                print $"(ansi red_bold)━━━ REQUEST FAILED ━━━(ansi reset)"
                print $"Error type: ($err | describe)"
                print $"Error message: ($err.msg)"

                if ($err.msg | str contains 'json') {
                    print ""
                    print $"(ansi yellow)Debug: Response might not be valid JSON(ansi reset)"
                    print 'This could mean:'
                    print '  1. wttr.in returned HTML error page instead of JSON'
                    print '  2. Location not found (404)'
                    print '  3. Service is down or rate limiting'
                }

                if ($err.msg | str contains 'timeout') or ($err.msg | str contains 'time') {
                    print ""
                    print $"(ansi yellow)Debug: Request timed out(ansi reset)"
                    print 'This could mean:'
                    print '  1. Slow network connection'
                    print '  2. wttr.in service is slow/overloaded'
                    print '  3. Connection being throttled'
                }

                print $"(ansi red_bold)━━━━━━━━━━━━━━━━━━━━━━(ansi reset)"
                print ""
            }

            # Check if it's a 404 (location not found) vs actual network error
            let error_msg = $err.msg

            if ($error_msg | str contains '404') or ($error_msg | str contains 'Not Found') {
                error make {
                    msg: $"Location not found: '($display_city)'"
                    help: "Try an airport code (e.g. JFK) or a landmark with ~ (e.g. ~Eiffel Tower)"
                }
            } else {
                error make {
                    msg: $"Could not fetch weather for '($display_city)'"
                    help: $error_msg
                }
            }
        }
    }

    if $debug {
        print $"(ansi green)✓ Request successful(ansi reset)"
        print $"Response type: ($response | describe)"
        print ""
    }

    let data: record = $response

    # Validate response structure
    if ($data.current_condition? | is-empty) {
        if $debug {
            print $"(ansi red_bold)━━━ DATA VALIDATION FAILED ━━━(ansi reset)"
            print 'Response structure check:'
            print $"  Has current_condition: (not ($data.current_condition? | is-empty))"
            print ""
            print 'Available fields in response:'
            $data | columns | each {|col| print $"  - ($col)" }
            print $"(ansi red_bold)━━━━━━━━━━━━━━━━━━━━━━━━━━━━━(ansi reset)"
            print ""
        }

        error make {
            msg: $"No weather data found for '($display_city)'"
            help: "The location may not be recognized by wttr.in"
        }
    }

    if $debug {
        print $"(ansi green)✓ Data validation passed(ansi reset)"
        print 'Response contains valid weather data'
        print ""
    }

    if $json {
        if $debug { print $"(ansi cyan)ℹ Returning raw JSON data...(ansi reset)" }
        return $data
    }

    # Common data extraction
    $data.nearest_area | first | let nearest: record

    # Get location info (wttr.in provides this in nearest_area)
    $nearest.areaName?.0?.value? | default $display_city | let area_name: string
    $nearest.region?.0?.value? | default '' | let region: string
    $nearest.country?.0?.value? | default 'Unknown' | let country_val: string
    $country_val | str downcase | let country: string

    # Determine units based on country
    # Priority: Force Imperial > Force Metric > Country detection
    let is_us: bool = if $imperial {
        true
    } else if $metric {
        false
    } else {
        ($country | str contains 'united states')
    }

    # Define unit-specific configuration (Nushell Idiom: Data over Control Flow)
    # This eliminates repetitive if/else checks during data extraction
    let units: record = if $is_us {
        {
            temp_label: '°F', speed_label: 'mph', precip_label: 'in', vis_label: 'mi', press_label: 'inHg',
            temp_key: 'temp_F', feels_key: 'FeelsLikeF',
            speed_key: 'windspeedMiles', precip_key: 'precipInches', vis_key: 'visibilityMiles', press_key: 'pressureInches',
            forecast_max_key: 'maxtempF', forecast_min_key: 'mintempF',
            hot_limit: 80, cold_limit: 40
        }
    } else {
        {
            temp_label: '°C', speed_label: 'km/h', precip_label: 'mm', vis_label: 'km', press_label: 'hPa',
            temp_key: 'temp_C', feels_key: 'FeelsLikeC',
            speed_key: 'windspeedKmph', precip_key: 'precipMM', vis_key: 'visibility', press_key: 'pressure',
            forecast_max_key: 'maxtempC', forecast_min_key: 'mintempC',
            hot_limit: 27, cold_limit: 4
        }
    }

    # Format location string (City, Region for US; City, Country for others)
    let actual_location: string = if $is_us and not ($region | is-empty) {
        $"($area_name), ($region)"
    } else {
        $"($area_name), ($country_val)"
    }

    # Astronomy View
    if $astro {
        let current_astro = ($data.weather | first | get astronomy | first)
        return (build-astro-display $current_astro $actual_location $icon_mode --raw=$raw)
    }

    # Hourly View
    if $hourly {
        return (build-hourly-display ($data.weather | first) $units $actual_location $icon_mode --raw=$raw --debug=$debug)
    }

    # Forecast View
    if $forecast {
        return (build-forecast-display $data.weather $units $actual_location $icon_mode --raw=$raw)
    }

    # Safe data extraction for Current Weather
    $data.current_condition | first | let current: record
    $data.weather | first | let weather_data: record
    $weather_data.astronomy | first | let astro: record

    # Dynamic extraction using the units schema
    $current | get -o $units.temp_key | default '0' | let temp_val: string
    $current | get -o $units.feels_key | default '0' | let feels_val: string

    # Calculate Beaufort
    $current.windspeedKmph? | default '0' | let wind_k: string
    beaufort-scale $wind_k | let beaufort_scale: int
    beaufort-icon $beaufort_scale $icon_mode | let beaufort_icon: string

    # Define icons for metrics
    let icon_wind: string = if $icon_mode == 'text' { $"($beaufort_icon) " } else if $icon_mode == 'emoji' { $"💨 ($beaufort_icon) " } else { $"($beaufort_icon) " }
    let icon_rain: string = if $icon_mode == 'text' { '' } else if $icon_mode == 'emoji' { '☔ ' } else { " " }
    let icon_vis: string = if $icon_mode == 'text' { '' } else if $icon_mode == 'emoji' { '👁 ' } else { " " }
    let icon_press: string = if $icon_mode == 'text' { '' } else if $icon_mode == 'emoji' { '⏲ ' } else { " " }
    let icon_cloud: string = if $icon_mode == 'text' { '' } else if $icon_mode == 'emoji' { '☁ ' } else { " " }
    let icon_humid: string = if $icon_mode == 'text' { '' } else if $icon_mode == 'emoji' { '💧 ' } else { " " }
    let icon_uv: string = if $icon_mode == 'text' { '' } else if $icon_mode == 'emoji' { '☀ ' } else { " " }

    # Wind, precipitation, visibility, pressure
    $current | get -o $units.speed_key | default '0' | let wind_speed: string
    $current.winddir16Point? | default 'N' | let wind_dir_str: string
    wind-dir-icon $wind_dir_str $icon_mode | let wind_dir: string

    $"($icon_wind)($wind_speed)($units.speed_label) ($wind_dir)" | let wind: string
    $"($icon_rain)(($current | get -o $units.precip_key | default '0.0'))($units.precip_label)" | let precip: string
    $"($icon_vis)(($current | get -o $units.vis_key | default '0'))($units.vis_label)" | let vis: string
    $"($icon_press)(($current | get -o $units.press_key | default '0'))($units.press_label)" | let pressure: string

    # UV Index & Sky Styling
    $current.uvIndex? | default '0' | into int | let uv: int

    let uv_label: string = if $uv >= 11 {
        'Extreme'
    } else if $uv >= 8 {
        'Very High'
    } else if $uv >= 6 {
        'High'
    } else if $uv >= 3 {
        'Moderate'
    } else {
        'Low'
    }

    let uv_color: string = if $uv >= 8 {
        'red'
    } else if $uv >= 6 {
        'yellow'
    } else if $uv >= 3 {
        'green'
    } else {
        'grey'
    }

    # COMPREHENSIVE WEATHER EMOJI MAPPING
    # Based on WorldWeatherOnline weather codes
    $current.weatherCode? | default '113' | let weather_code: string
    weather-icon $weather_code $icon_mode | let weather_icon: string

    # Determine precipitation type from weather code
    let precip_label: string = match $weather_code {
        '179' | '323' | '326' | '329' | '332' | '335' | '338' | '368' | '371' => 'Snow',
        '227' | '230' => 'Snow',
        '182' | '317' | '320' | '362' | '365' => 'Sleet',
        '350' | '374' | '377' => 'Hail',
        _ => 'Rain'
    }
    # SEVERE WEATHER DETECTION
    # wttr.in doesn't provide NWS alerts, but we can flag severe codes:
    # 227 (Blowing snow), 230 (Blizzard), 386/389/392/395 (Thunderstorms)
    let severe_codes: list<string> = ['227' '230' '386' '389' '392' '395']
    let is_severe: bool = ($weather_code in $severe_codes)

    let alert_icon: string = if $is_severe {
        if $icon_mode == 'text' { ' [SEVERE]' } else if $icon_mode == 'emoji' { ' ⚠️' } else { ' ' } # nf-weather-storm_warning
    } else { '' }

    # Get weather description for additional context
    $current.weatherDesc?.0?.value? | default 'Unknown' | let weather_desc: string

    # ENHANCED MOON PHASE EMOJI
    # More precise matching with moon illumination
    $astro.moon_phase? | default 'Unknown' | str downcase | let moon_phase: string
    $astro.moon_illumination? | default '0' | let moon_illum: string

    moon-icon $moon_phase $moon_illum $icon_mode | let moon_icon: string

    let moon_display: string = if $icon_mode == 'text' { 'Moon: ' } else { $"($moon_icon) " }
    let sunrise_display: string = if $icon_mode == 'text' { 'Sunrise: ' } else if $icon_mode == 'emoji' { '🌅 ' } else { " " } # nf-weather-sunrise
    let sunset_display: string = if $icon_mode == 'text' { 'Sunset: ' } else if $icon_mode == 'emoji' { '🌇 ' } else { " " } # nf-weather-sunset

    # Format the update time safely
    let update_str: string = try {
        $current.localObsDateTime? | into datetime | format date '%Y-%m-%d %H:%M'
    } catch {
        'Unknown'
    }

    # Format UTC time safely (for consistency)
    let utc_str: string = try {
        $current.observation_time? | into datetime | format date '%H:%M'
    } catch {
        'Unknown'
    }

    # Prepare ANSI colors (empty if text mode)
    let ansi_reset: string = if $icon_mode == 'text' { '' } else { (ansi reset) }
    let ansi_grey: string = if $icon_mode == 'text' { '' } else { (ansi grey) }
    let ansi_uv: string = if $icon_mode == 'text' { '' } else { (ansi $uv_color) }

    format-temp $temp_val $units --text=($icon_mode == 'text') | let temp_display: string

    let condition_display: string = if $icon_mode == 'text' { $"($weather_desc)($alert_icon)" } else { $"($weather_icon) ($weather_desc)($alert_icon)" }

    let location_display: string = if ($icon_mode == 'text') or $raw {
        $actual_location
    } else {
        $"https://wttr.in/($url_encoded_city)" | let link_url: string
        $link_url | ansi link --text $actual_location
    }

    # Build output with weather description
    let output: record = {
        Location: $location_display,
        Condition: $condition_display,
        Temperature: $temp_display,
        Feels: (format-temp $feels_val $units --text=$text),
        Clouds: $"($icon_cloud)(($current.cloudcover? | default '0'))%",
        ($precip_label): $precip,
        Humidity: $"($icon_humid)(($current.humidity? | default '0'))%",
        Wind: $wind,
        Pressure: $pressure,
        Visibility: $vis,
        UV: $"($icon_uv)($ansi_uv)($uv) ($uv_label)($ansi_reset)",
        Astronomy: $"($sunrise_display)(($astro.sunrise? | default 'N/A')) | ($sunset_display)(($astro.sunset? | default 'N/A')) | ($moon_display)(($astro.moon_illumination? | default '0'))%",
        Updated: $"($ansi_grey)($update_str) \(Local\) / ($utc_str) \(UTC\)($ansi_reset)"
    }

    if $debug {
        print $"(ansi green)✓ All data extracted successfully(ansi reset)"
        print $"  Location: ($actual_location)"
        print $"  Country: ($country)"
        print $"  Units: (if $is_us { 'US' } else { 'Metric' }) ($units.temp_label), ($units.speed_label)"
        print $"  Weather code: ($weather_code) → ($weather_desc)"
        print $"  Temperature: ($temp_val)($units.temp_label) [feels: ($feels_val)($units.temp_label)]"
        print $"  UV Index: ($uv)"
        print $"  Moon phase: ($moon_phase) [($moon_illum)%]"
        print $"(ansi grey)━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━(ansi reset)"
        print ""
    }

    if $raw {
        return $output
    }

    let term_width = (term size).columns

    let width_tier = if $term_width >= $COL_FULL_WIDTH {
        "full"
    } else if $term_width >= $COL_COMPACT_WIDTH {
        "compact"
    } else if $term_width >= $COL_MINIMAL_WIDTH {
        "minimal"
    } else {
        "oneline"
    }

    let tier = if $oneline {
        "oneline"
    } else if $minimal {
        "minimal"
    } else if $compact {
        "compact"
    } else {
        $width_tier
    }

    if $tier == "oneline" {
        let oneline_emoji: string = if $icon_mode == 'text' { '' } else { $"($weather_icon) " }
        return $"($actual_location): ($oneline_emoji)($temp_val)($units.temp_label) - ($weather_desc)"
    }

    let final_output = match $tier {
        "full" => $output,
        "compact" => ($output | reject Pressure Visibility Clouds Updated),
        "minimal" => ($output | reject Pressure Visibility Clouds Updated UV Humidity Feels),
        _ => $output
    }

    $final_output | table -i false
}
