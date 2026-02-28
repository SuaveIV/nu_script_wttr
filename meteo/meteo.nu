# Fetches and displays weather information from Open-Meteo.
#
# Fast, no-API-key alternative to weather.nu. Uses Open-Meteo's free API for
# current conditions, hourly forecasts, and 3-day forecasts. Noticeably faster
# than wttr.in. Note: moon/astronomy data is not available from this source.
#
# Data: Open-Meteo (https://open-meteo.com)
# Geocoding: Open-Meteo Geocoding API
# Auto-detect: ipapi.co
#
# Search terms: weather, forecast, meteo, openmeteo, climate
#
# Examples:
#   > meteo                       # Current weather, auto-detected location
#   > meteo "New York"            # Named city
#   > meteo "Paris, France"       # City with country
#   > meteo -3                    # 3-day forecast
#   > meteo --hourly              # Hourly breakdown for today
#   > meteo --oneline             # Single-line summary for status bars
#   > meteo --air                 # Air quality data (AQI, PM2.5, Ozone, etc.)
#   > meteo --emoji               # Use emoji icons
#   > meteo --debug               # Show diagnostic info

const COL_FULL_WIDTH    = 100
const COL_COMPACT_WIDTH = 80
const COL_MINIMAL_WIDTH = 60

# --- Shared helpers (mirrors weather.nu conventions) ---

# Formats a temperature string with unit label and optional ANSI colour gradient.
def format-temp [
    val: string
    units: record<temp_label: string, hot_limit: int, cold_limit: int>
    --text
]: nothing -> string {
    let temp_int = ($val | into int)
    if $text {
        $"($val)($units.temp_label)"
    } else {
        let gradient = if $temp_int >= $units.hot_limit {
            {s: '0xffff00', e: '0xff0000'}
        } else if $temp_int <= $units.cold_limit {
            {s: '0xffffff', e: '0x00ffff'}
        } else {
            {s: '0x00ff00', e: '0xffff00'}
        }
        $"($val)($units.temp_label)" | ansi gradient --fgstart $gradient.s --fgend $gradient.e
    }
}

# Formats UV index with label and color.
def format-uv [
    uv: int
    icon_mode: string
]: nothing -> string {
    let label = if $uv >= 11 { "Extreme" } else if $uv >= 8 { "Very High" } else if $uv >= 6 { "High" } else if $uv >= 3 { "Moderate" } else { "Low" }
    let color = if $uv >= 8 { 'red' } else if $uv >= 6 { 'yellow' } else if $uv >= 3 { 'green' } else { 'grey' }

    if $icon_mode == 'text' {
        return $"($uv) ($label)"
    }

    let icon = if $icon_mode == 'emoji' { '☀ ' } else { "\u{e30d} " }
    $"($icon)(ansi $color)($uv) ($label)(ansi reset)"
}

# Formats AQI value with color gradient.
def format-aqi [val: int, --text]: nothing -> string {
    if $text { return ($val | into string) }
    let color = if $val <= 50 {
        '0x00ff00' # Green
    } else if $val <= 100 {
        '0xffff00' # Yellow
    } else if $val <= 150 {
        '0xffa500' # Orange
    } else if $val <= 200 {
        '0xff0000' # Red
    } else {
        '0x800080' # Purple
    }
    $"($val)" | ansi gradient --fgstart $color --fgend $color
}

# Maps a WMO weather interpretation code to a human-readable description.
def wmo-desc [code: int]: nothing -> string {
    match $code {
        0  => "Clear Sky",
        1  => "Mainly Clear",
        2  => "Partly Cloudy",
        3  => "Overcast",
        45 => "Fog",
        48 => "Icy Fog",
        51 => "Light Drizzle",
        53 => "Drizzle",
        55 => "Heavy Drizzle",
        56 => "Light Freezing Drizzle",
        57 => "Freezing Drizzle",
        61 => "Light Rain",
        63 => "Rain",
        65 => "Heavy Rain",
        66 => "Light Freezing Rain",
        67 => "Freezing Rain",
        71 => "Light Snow",
        73 => "Snow",
        75 => "Heavy Snow",
        77 => "Snow Grains",
        80 => "Light Showers",
        81 => "Showers",
        82 => "Heavy Showers",
        85 => "Snow Showers",
        86 => "Heavy Snow Showers",
        95 => "Thunderstorm",
        96 => "Thunderstorm with Hail",
        99 => "Thunderstorm with Heavy Hail",
        _  => "Unknown"
    }
}

# Returns a weather icon for a WMO code. Supports nerd/emoji/text modes.
def wmo-icon [
    code: int
    is_day: bool
    icon_mode: string
]: nothing -> string {
    if $icon_mode == 'text' { return "" }
    if $icon_mode == 'emoji' {
        match $code {
            0             => (if $is_day { "☀️"  } else { "🌙" }),
            1             => (if $is_day { "🌤️" } else { "🌙" }),
            2             => "⛅",
            3             => "☁️",
            45 | 48       => "🌫️",
            51 | 53 | 55  => "🌦️",
            56 | 57       => "🌧️",
            61 | 63       => "🌧️",
            65 | 66 | 67  => "🌧️",
            71 | 73 | 75  => "❄️",
            77            => "🌨️",
            80 | 81 | 82  => "🌧️",
            85 | 86       => "🌨️",
            95 | 96 | 99  => "⛈️",
            _             => "🌡️"
        }
    } else {
        # Nerd Font (nf-weather glyphs)
        match $code {
            0             => (if $is_day { "\u{e30d}" } else { "\u{e32b}" }),
            1             => (if $is_day { "\u{e302}" } else { "\u{e37e}" }),
            2             => "\u{e302}",
            3             => "\u{e312}",
            45 | 48       => "\u{e313}",
            51 | 53 | 55  => "\u{e308}",
            56 | 57       => "\u{e321}",
            61 | 63       => "\u{e318}",
            65 | 66 | 67  => "\u{e318}",
            71 | 73 | 75 | 77 => "\u{e31a}",
            80 | 81 | 82  => "\u{e318}",
            85 | 86       => "\u{e31a}",
            95 | 96 | 99  => "\u{e31d}",
            _             => "\u{e374}"
        }
    }
}

# Converts wind degrees to a 16-point compass direction string.
def degrees-to-compass [degrees: number]: nothing -> string {
    let dirs = ["N" "NNE" "NE" "ENE" "E" "ESE" "SE" "SSE" "S" "SSW" "SW" "WSW" "W" "WNW" "NW" "NNW"]
    let idx = ((($degrees + 11.25) / 22.5) | math floor | into int) mod 16
    $dirs | get $idx
}

# Converts a wind speed in km/h to its Beaufort scale number (0–12).
def beaufort-scale [kmph: string]: nothing -> int {
    let k = ($kmph | into int)
    match $k {
        $x if $x < 1   => 0,
        $x if $x <= 5  => 1,
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

# Returns a Beaufort glyph (Nerd Font) or bracketed label (emoji/text).
def beaufort-icon [scale: int, icon_mode: string]: nothing -> string {
    if $icon_mode != 'nerd' { return $"[Bft ($scale)]" }
    match $scale {
        0 => "\u{e3af}", 1 => "\u{e3b0}", 2 => "\u{e3b1}", 3 => "\u{e3b2}",
        4 => "\u{e3b3}", 5 => "\u{e3b4}", 6 => "\u{e3b5}", 7 => "\u{e3b6}",
        8 => "\u{e3b7}", 9 => "\u{e3b8}", 10 => "\u{e3b9}", 11 => "\u{e3ba}", _ => "\u{e3bb}"
    }
}

# Returns a directional arrow glyph (Nerd Font) or raw direction string (emoji/text).
def wind-dir-icon [dir: string, icon_mode: string]: nothing -> string {
    if $icon_mode != 'nerd' { return $dir }
    match ($dir | str upcase) {
        'N'                   => "\u{e31a}",
        'NNE' | 'NE' | 'ENE' => "\u{e319}",
        'E'                   => "\u{e31b}",
        'ESE' | 'SE' | 'SSE' => "\u{e316}",
        'S'                   => "\u{e317}",
        'SSW' | 'SW' | 'WSW' => "\u{e315}",
        'W'                   => "\u{e314}",
        'WNW' | 'NW' | 'NNW' => "\u{e318}",
        _                     => $dir
    }
}

# Resolves (and creates if needed) the weather cache directory.
def resolve-cache-dir [subdir: string]: nothing -> string {
    $nu.cache-dir? | default ($env.TEMP? | default $env.TMP? | default '/tmp') | let base: string
    $base | path join $subdir | let cache_dir: string
    if not ($cache_dir | path exists) { mkdir $cache_dir }
    $cache_dir
}

# Returns true if a cache file exists and was modified within the given TTL.
def is-cache-valid [cache_path: string, ttl: duration]: nothing -> bool {
    if ($cache_path | path exists) {
        ((date now) - (ls $cache_path | get modified | first)) < $ttl
    } else { false }
}

# --- API helpers ---

# Geocodes a city name to coordinates + metadata via Open-Meteo Geocoding API.
def geocode-city [city: string, lang: string]: nothing -> record {
    let lang_param = if ($lang | is-empty) { "en" } else { $lang }
    let url = $"https://geocoding-api.open-meteo.com/v1/search?name=($city | url encode)&count=1&language=($lang_param)&format=json"
    let res = (http get $url -m 10sec)
    if ($res.results? | is-empty) {
        error make {
            msg: $"Location not found: '($city)'"
            help: "Try a different spelling or a nearby major city."
        }
    }
    let r = ($res.results | first)
    {
        name: ($r.name? | default $city),
        admin1: ($r.admin1? | default ""),
        country_name: ($r.country? | default "Unknown"),
        country_code: ($r.country_code? | default ""),
        latitude: ($r.latitude? | default 0.0),
        longitude: ($r.longitude? | default 0.0)
    }
}

# Detects the current location from IP address via ipapi.co.
def detect-location []: nothing -> record {
    let res = (http get 'https://ipapi.co/json/' -m 10sec)
    {
        name: ($res.city? | default "Unknown"),
        admin1: ($res.region? | default ""),
        country_name: ($res.country_name? | default "Unknown"),
        country_code: ($res.country_code? | default "US"),
        latitude: ($res.latitude? | default 0.0),
        longitude: ($res.longitude? | default 0.0)
    }
}

# Fetches the full forecast payload from Open-Meteo for given coordinates.
# Always fetches in metric + km/h; display layer handles unit conversion.
def fetch-open-meteo [lat: float, lon: float]: nothing -> record {
    let vars_current = "temperature_2m,relative_humidity_2m,apparent_temperature,is_day,precipitation,weather_code,cloud_cover,wind_speed_10m,wind_direction_10m,wind_gusts_10m,pressure_msl,visibility,uv_index"
    let vars_hourly = "temperature_2m,relative_humidity_2m,apparent_temperature,precipitation_probability,weather_code,wind_speed_10m,wind_direction_10m,wind_gusts_10m"
    let vars_daily = "weather_code,temperature_2m_max,temperature_2m_min,sunrise,sunset,precipitation_sum,precipitation_probability_max,wind_speed_10m_max,wind_direction_10m_dominant,uv_index_max,snowfall_sum,snow_depth"
    let url = $"https://api.open-meteo.com/v1/forecast?latitude=($lat)&longitude=($lon)&current=($vars_current)&hourly=($vars_hourly)&daily=($vars_daily)&timezone=auto&forecast_days=3"
    http get $url -m 10sec
}

# Fetches air quality data from Open-Meteo.
def fetch-air-quality [lat: float, lon: float]: nothing -> record {
    let url = $"https://air-quality-api.open-meteo.com/v1/air-quality?latitude=($lat)&longitude=($lon)&current=pm2_5,pm10,ozone,nitrogen_dioxide,us_aqi,european_aqi&timezone=auto"
    http get $url -m 10sec
}

# --- Display builders ---

# Builds the current weather output record.
def build-current [
    data: record
    loc: record
    units: record
    icon_mode: string
]: nothing -> record {
    let cur = ($data.current? | default {})
    let is_day = ($cur.is_day? | default 1 | into bool)
    let code = ($cur.weather_code? | default 0 | into int)
    let icon = (wmo-icon $code $is_day $icon_mode)
    let desc = (wmo-desc $code)

    # Temps (API is always °C; convert to °F if imperial)
    let tc = ($cur.temperature_2m? | default 0.0)
    let fc = ($cur.apparent_temperature? | default 0.0)
    let temp_display = (format-temp (to-display-temp $tc $units) $units --text=($icon_mode == 'text'))
    let feels_display = (format-temp (to-display-temp $fc $units) $units --text=($icon_mode == 'text'))

    # Wind (API is always km/h)
    let wind_kmh = ($cur.wind_speed_10m? | default 0.0)
    let wind_deg = ($cur.wind_direction_10m? | default 0.0)
    let wind_dir = (degrees-to-compass $wind_deg)
    let bft = (beaufort-scale ($wind_kmh | math round | into string))
    let bft_icon = (beaufort-icon $bft $icon_mode)
    let wind_speed = (to-display-speed $wind_kmh $units)
    let wind_icon = if $icon_mode == 'emoji' { $"💨 ($bft_icon) " } else { $"($bft_icon) " }
    let wind = $"($wind_icon)($wind_speed)($units.speed_label) (wind-dir-icon $wind_dir $icon_mode)"

    # Precipitation (API is always mm)
    let precip_mm = ($cur.precipitation? | default 0.0)
    let precip_val = if $units.is_imperial {
        $"($precip_mm * 0.0393701 | math round --precision 2)"
    } else { $"($precip_mm)" }
    let icon_rain = if $icon_mode == 'text' { '' } else if $icon_mode == 'emoji' { '☔ ' } else { "\u{e319} " }
    let precip = $"($icon_rain)($precip_val)($units.precip_label)"

    # Visibility (API is always metres)
    let vis_m = ($cur.visibility? | default 0.0)
    let vis_val = if $units.is_imperial {
        $"($vis_m / 1609.34 | math round --precision 1)"
    } else {
        $"($vis_m / 1000 | math round --precision 1)"
    }
    let icon_vis = if $icon_mode == 'text' { '' } else if $icon_mode == 'emoji' { '👁 ' } else { "\u{e3ae} " }
    let vis = $"($icon_vis)($vis_val)($units.vis_label)"

    # Pressure (API is always hPa)
    let press_hpa = ($cur.pressure_msl? | default 1013.0)
    let press_val = if $units.is_imperial {
        $"($press_hpa * 0.02953 | math round --precision 2)"
    } else {
        $"($press_hpa | math round)"
    }
    let icon_press = if $icon_mode == 'text' { '' } else if $icon_mode == 'emoji' { '⏲ ' } else { "\u{e372} " }
    let pressure = $"($icon_press)($press_val)($units.press_label)"

    # Clouds & humidity
    let clouds = ($cur.cloud_cover? | default 0 | into int)
    let humidity = ($cur.relative_humidity_2m? | default 0 | into int)
    let icon_cloud = if $icon_mode == 'text' { '' } else if $icon_mode == 'emoji' { '☁ ' } else { "\u{e312} " }
    let icon_humid = if $icon_mode == 'text' { '' } else if $icon_mode == 'emoji' { '💧 ' } else { "\u{e373} " }

    # UV
    let uv = ($cur.uv_index? | default 0.0 | math round | into int)

    # AQI
    let us_aqi = ($cur.us_aqi? | default 0 | into int)
    let eu_aqi = ($cur.european_aqi? | default 0 | into int)
    let aqi_val = if $units.is_imperial { $us_aqi } else { $eu_aqi }
    let aqi_label = if $units.is_imperial { "AQI (US)" } else { "AQI (EU)" }
    let aqi_display = (format-aqi $aqi_val --text=($icon_mode == 'text'))
    let icon_aqi = if $icon_mode == 'text' { '' } else if $icon_mode == 'emoji' { '🍃 ' } else { "\u{f06c} " }

    # Severe weather flag
    let is_severe = ($code in [95 96 99])
    let alert = if $is_severe {
        if $icon_mode == 'text' { ' [SEVERE]' } else if $icon_mode == 'emoji' { ' ⚠️' } else { ' ' }
    } else { '' }

    # Sunrise / Sunset from today's daily slot
    let sunrise_raw = ($data.daily?.sunrise? | default [] | try { first } catch { "" })
    let sunset_raw = ($data.daily?.sunset? | default [] | try { first } catch { "" })
    let sr = try { $sunrise_raw | into datetime | format date '%H:%M' } catch { $sunrise_raw }
    let ss = try { $sunset_raw | into datetime | format date '%H:%M' } catch { $sunset_raw }
    let icon_sr = if $icon_mode == 'text' { 'Sunrise: ' } else if $icon_mode == 'emoji' { '🌅 ' } else { "\u{e34c} " }
    let icon_ss = if $icon_mode == 'text' { 'Sunset: ' } else if $icon_mode == 'emoji' { '🌇 ' } else { "\u{e34d} " }

    # Condition string
    let condition = if $icon_mode == 'text' {
        $"($desc)($alert)"
    } else {
        $"($icon) ($desc)($alert)"
    }

    let output = {
        Location:    ($loc | format-loc $units.is_imperial),
        Condition:   $condition,
        Temperature: $temp_display,
        Feels:       $feels_display,
        Clouds:      $"($icon_cloud)($clouds)%",
        Rain:        $precip,
        Humidity:    $"($icon_humid)($humidity)%",
        Wind:        $wind,
        Pressure:    $pressure,
        Visibility:  $vis,
        UV:          (format-uv $uv $icon_mode),
        AQI:         $"($icon_aqi)($aqi_display) ($aqi_label)",
        Astronomy:   $"($icon_sr)($sr) | ($icon_ss)($ss)"
    }

    let gust_kmh = ($cur.wind_gusts_10m? | default 0.0)
    if $gust_kmh > 0 {
        let gust_val = (to-display-speed $gust_kmh $units)
        $output | insert Gusts $"($gust_val)($units.speed_label)"
    } else {
        $output
    }
}

# Builds hourly forecast rows for today (3-hour intervals).
def build-hourly [
    data: record
    units: record
    loc_str: string
    icon_mode: string
    --raw
]: nothing -> any {
    let hourly = ($data.hourly? | default {time: []})
    let times = ($hourly.time? | default [])
    let today = (date now | format date '%Y-%m-%d')

    let rows = ($times | enumerate | each {|item|
        let t = $item.item
        let i = $item.index
        if not ($t | str starts-with $today) { return null }
        let hour_num = try { $t | str substring 11..12 | into int } catch { return null }
        if ($hour_num mod 3) != 0 { return null }

        let tc       = try { $hourly.temperature_2m         | get $i } catch { 0.0 }
        let code     = try { $hourly.weather_code            | get $i | into int } catch { 0 }
        let wind_kmh = try { $hourly.wind_speed_10m          | get $i } catch { 0.0 }
        let wind_deg = try { $hourly.wind_direction_10m      | get $i } catch { 0.0 }
        let gust_kmh = try { $hourly.wind_gusts_10m          | get $i } catch { 0.0 }
        let prob     = try { $hourly.precipitation_probability | get $i | into int } catch { 0 }
        let hum      = try { $hourly.relative_humidity_2m    | get $i | into int } catch { 0 }

        let wind_dir = (degrees-to-compass $wind_deg)
        let bft = (beaufort-scale ($wind_kmh | math round | into string))
        let speed = (to-display-speed $wind_kmh $units)

        let row = {
            Time:      ($t | str substring 11..15),
            Condition: (if $icon_mode == 'text' { wmo-desc $code } else { $"(wmo-icon $code true $icon_mode) (wmo-desc $code)" }),
            Temp:      (format-temp (to-display-temp $tc $units) $units --text=($icon_mode == 'text')),
            Wind:      $"(wind-dir-icon $wind_dir $icon_mode) ($speed)($units.speed_label) (beaufort-icon $bft $icon_mode)",
            Precip:    $"($prob)%",
            Humidity:  $"($hum)%"
        }

        if $gust_kmh > 0 {
            let gust_val = (to-display-speed $gust_kmh $units)
            $row | insert Gusts $"($gust_val)($units.speed_label)"
        } else {
            $row
        }
    } | compact)

    if $raw { return $rows }
    print $"(ansi cyan_bold)Hourly Forecast for ($loc_str)(ansi reset)"
    $rows | table -i false
}

# Builds the 3-day forecast table.
def build-forecast [
    data: record
    units: record
    loc_str: string
    icon_mode: string
    --raw
]: nothing -> any {
    let daily = ($data.daily? | default {time: []})
    let times = ($daily.time? | default [])
    let has_snow = ($daily.snowfall_sum? | default [] | any {|x| $x > 0})

    let rows = ($times | enumerate | each {|item|
        let t = $item.item
        let i = $item.index
        let code      = try { $daily.weather_code                    | get $i | into int } catch { 0 }
        let max_c     = try { $daily.temperature_2m_max              | get $i } catch { 0.0 }
        let min_c     = try { $daily.temperature_2m_min              | get $i } catch { 0.0 }
        let precip_mm = try { $daily.precipitation_sum               | get $i } catch { 0.0 }
        let snow_mm   = try { $daily.snowfall_sum                    | get $i } catch { 0.0 }
        let prob      = try { $daily.precipitation_probability_max   | get $i | into int } catch { 0 }
        let wind_kmh  = try { $daily.wind_speed_10m_max              | get $i } catch { 0.0 }
        let wind_deg  = try { $daily.wind_direction_10m_dominant     | get $i } catch { 0.0 }
        let uv_max    = try { $daily.uv_index_max                    | get $i | math round | into int } catch { 0 }
        let sr_raw    = try { $daily.sunrise                         | get $i } catch { "" }
        let ss_raw    = try { $daily.sunset                          | get $i } catch { "" }

        let precip_val = if $units.is_imperial {
            $"($precip_mm * 0.0393701 | math round --precision 2)($units.precip_label)"
        } else {
            $"($precip_mm)($units.precip_label)"
        }
        let snow_val = if $units.is_imperial {
            $"($snow_mm * 0.0393701 | math round --precision 2)($units.precip_label)"
        } else {
            $"($snow_mm)($units.precip_label)"
        }
        let wind_dir = (degrees-to-compass $wind_deg)
        let speed = (to-display-speed $wind_kmh $units)
        let sr = try { $sr_raw | into datetime | format date '%H:%M' } catch { $sr_raw }
        let ss = try { $ss_raw | into datetime | format date '%H:%M' } catch { $ss_raw }
        let icon_sr = if $icon_mode == 'text' { '' } else if $icon_mode == 'emoji' { '🌅 ' } else { "\u{e34c} " }
        let icon_ss = if $icon_mode == 'text' { '' } else if $icon_mode == 'emoji' { '🌇 ' } else { "\u{e34d} " }

        let row = {
            Date:      ($t | into datetime | format date '%a, %b %d'),
            Condition: (if $icon_mode == 'text' { wmo-desc $code } else { $"(wmo-icon $code true $icon_mode) (wmo-desc $code)" }),
            High:      (format-temp (to-display-temp $max_c $units) $units --text=($icon_mode == 'text')),
            Low:       (format-temp (to-display-temp $min_c $units) $units --text=($icon_mode == 'text')),
            Rain:      $"($precip_val) ($prob)%",
            Snow:      $snow_val,
            Wind:      $"(wind-dir-icon $wind_dir $icon_mode) ($speed)($units.speed_label)",
            UV:        (format-uv $uv_max $icon_mode),
            Sunrise:   $"($icon_sr)($sr)",
            Sunset:    $"($icon_ss)($ss)"
        }

        if $has_snow { $row } else { $row | reject Snow }
    })

    if $raw { return $rows }
    print $"(ansi cyan_bold)3-Day Forecast for ($loc_str)(ansi reset)"
    $rows | table -i false
}

# Builds the air quality display record.
def build-air-quality [
    data: record
    loc: record
    is_imperial: bool
    icon_mode: string
]: nothing -> record {
    let cur = ($data.current? | default {})
    let pm25 = ($cur.pm2_5? | default 0)
    let pm10 = ($cur.pm10? | default 0)
    let o3 = ($cur.ozone? | default 0)
    let no2 = ($cur.nitrogen_dioxide? | default 0)
    let us_aqi = ($cur.us_aqi? | default 0)
    let eu_aqi = ($cur.european_aqi? | default 0)

    {
        Location: ($loc | format-loc $is_imperial),
        "PM2.5":  $"($pm25) µg/m³",
        "PM10":   $"($pm10) µg/m³",
        "Ozone":  $"($o3) µg/m³",
        "NO2":    $"($no2) µg/m³",
        "US AQI": (format-aqi $us_aqi --text=($icon_mode == 'text')),
        "EU AQI": (format-aqi $eu_aqi --text=($icon_mode == 'text'))
    }
}

# --- Unit conversion helpers ---

# Converts °C to a rounded display string, in °F if units.is_imperial is true.
def to-display-temp [c: float, units: record]: nothing -> string {
    if $units.is_imperial {
        (($c * 9 / 5) + 32) | math round | into string
    } else {
        $c | math round | into string
    }
}

# Converts km/h to a rounded display string, in mph if units.is_imperial is true.
def to-display-speed [kmh: float, units: record]: nothing -> string {
    if $units.is_imperial {
        ($kmh * 0.621371) | math round | into string
    } else {
        $kmh | math round | into string
    }
}

# Formats a location record to a display string.
def format-loc [is_imperial: bool]: record -> string {
    let loc = $in
    let name = ($loc.name? | default "Unknown")
    let admin1 = ($loc.admin1? | default "")
    let country = ($loc.country_name? | default "Unknown")
    if $is_imperial and not ($admin1 | is-empty) {
        $"($name), ($admin1)"
    } else {
        $"($name), ($country)"
    }
}

# --- Main command ---

# Fetches and displays weather from Open-Meteo. Fast, no API key required.
#
# Responses are cached for 15 minutes. Units are auto-selected by country
# (imperial for US/Liberia/Myanmar, metric elsewhere) unless overridden.
# Condition text is always in English (unlike wttr.in, Open-Meteo does not
# localise weather descriptions).
#
# Examples:
#   > meteo                      # Current weather, auto-detected location
#   > meteo "Tokyo"              # Named city
#   > meteo -3                   # 3-day forecast
#   > meteo -H                   # Hourly breakdown for today
#   > meteo -1                   # One-line summary
#   > meteo -e "London"          # Emoji icons
#   > meteo -q "Paris"           # Air quality
#   > meteo -t -r "Berlin" | to json  # Pipe-friendly serialisation
export def main [
    city: string = ""            # Location to fetch weather for. Leave empty to auto-detect.
    --raw (-r)                   # Return raw record instead of a formatted table.
    --debug                      # Print network and parsing diagnostics.
    --metric (-m)                # Force metric units (°C, km/h).
    --imperial (-i)              # Force imperial units (°F, mph).
    --forecast (-3)              # Show 3-day forecast.
    --oneline (-1)               # Show a single-line summary (e.g. for status bars).
    --compact (-c)               # Compact output (drops Pressure, Visibility, Clouds).
    --minimal (-M)               # Minimal output (also drops UV, Humidity, Feels).
    --json (-j)                  # Return the full raw API response as data.
    --emoji (-e)                 # Use emoji icons instead of Nerd Font glyphs.
    --text (-t)                  # Plain text output — no icons, no colours.
    --force (-f)                 # Bypass cache and force a fresh network request.
    --hourly (-H)                # Show hourly forecast for today (3-hour intervals).
    --clear-cache                # Delete all cached data and exit.
    --lang: string = ""          # Language code for geocoding place names (e.g. 'fr', 'de').
    --air (-q)                   # Show air quality data (PM2.5, PM10, Ozone, NO2, AQI).
]: nothing -> any {
    let icon_mode: string = if $emoji {
        'emoji'
    } else if $text {
        'text'
    } else if ($env.NERD_FONTS? == '1') {
        'nerd'
    } else {
        'text'
    }

    resolve-cache-dir 'nu_meteo_cache' | let cache_dir: string

    if $clear_cache {
        rm -rf $cache_dir
        print 'Meteo cache cleared.'
        return
    }

    let lang_suffix = if ($lang | is-empty) { '' } else { $"_($lang)" }
    let type_suffix = if $air { "_aqi" } else { "" }
    let cache_file = if ($city | is-empty) {
        $"auto($lang_suffix)($type_suffix).json"
    } else {
        $"($city | url encode)($lang_suffix)($type_suffix).json"
    }
    $cache_dir | path join $cache_file | let cache_path: string
    let ttl = if $air { 30min } else { 15min }
    let use_cache = if $force { false } else { is-cache-valid $cache_path $ttl }

    if $debug {
        print $"(ansi cyan)🔍 DEBUG MODE(ansi reset)"
        print $"(ansi grey)────────────────────────────────────────(ansi reset)"
        print $"City:          '($city)'"
        print $"Cache Path:    ($cache_path)"
        print $"Cache Valid:   ($use_cache)"
        print $"Icon Mode:     ($icon_mode)"
        print $"Lang:          (if ($lang | is-empty) { 'auto' } else { $lang })"
        print $"Unit Override: (if $metric { 'Metric' } else if $imperial { 'Imperial' } else { 'Auto' })"
        print $"View:          (if $air { 'Air Quality' } else if $hourly { 'Hourly' } else if $forecast { 'Forecast' } else { 'Current' })"
        print $"(ansi grey)────────────────────────────────────────(ansi reset)"
        print ""
    }

    let cached: record = if $use_cache {
        if $debug { print $"(ansi green)✓ Using cached data(ansi reset)\n" }
        open $cache_path
    } else {
        if ($cache_path | path exists) { rm $cache_path }
        try {
            let geo = if ($city | is-empty) {
                if $debug { print "Auto-detecting location via IP (ipapi.co)..." }
                detect-location
            } else {
                if $debug { print $"Geocoding '($city)' via Open-Meteo..." }
                geocode-city $city $lang
            }

            if $debug {
                print $"(ansi green)✓ Location: ($geo.name), ($geo.country_name)(ansi reset)"
                print $"  Coordinates: ($geo.latitude), ($geo.longitude)"
            }

            let weather = if $air {
                if $debug { print "Fetching air quality from Open-Meteo..." }
                fetch-air-quality $geo.latitude $geo.longitude
            } else {
                if $debug { print "Fetching forecast from Open-Meteo..." }
                let w = (fetch-open-meteo $geo.latitude $geo.longitude)

                if $debug { print "Fetching AQI from Open-Meteo..." }
                let a = try {
                    fetch-air-quality $geo.latitude $geo.longitude
                } catch {
                    if $debug { print "(ansi yellow)AQI fetch failed, skipping...(ansi reset)" }
                    { current: {} }
                }

                let merged_cur = (($w.current? | default {}) | merge ($a.current? | default {}))
                $w | update current $merged_cur
            }

            if $debug { print $"(ansi green)✓ Data received(ansi reset)\n" }

            let combined = ($weather | insert location $geo)
            $combined | save -f $cache_path
            $combined
        } catch {|err|
            let location_clause = if ($city | is-empty) { "" } else { $" for '($city)'" }
            error make {
                msg: $"Could not fetch weather($location_clause)"
                help: $err.msg
            }
        }
    }

    if $json { return $cached }

    let loc = ($cached.location? | default {name: "Unknown", admin1: "", country_name: "Unknown", country_code: "US", latitude: 0.0, longitude: 0.0})

    # Determine units — imperial only for US, Liberia (LR), Myanmar (MM)
    let country_code = ($loc.country_code? | default "" | str upcase)
    let is_imperial = if $imperial { true } else if $metric { false } else {
        $country_code in ["US" "LR" "MM"]
    }

    if $debug {
        print $"Country code: ($country_code)"
        print $"Using units:  (if $is_imperial { 'Imperial (°F, mph)' } else { 'Metric (°C, km/h)' })"
        print ""
    }

    let units = if $is_imperial {
        {is_imperial: true,  temp_label: "°F", speed_label: "mph", precip_label: "in",  vis_label: "mi",  press_label: "inHg", hot_limit: 80, cold_limit: 40}
    } else {
        {is_imperial: false, temp_label: "°C", speed_label: "km/h", precip_label: "mm", vis_label: "km",  press_label: "hPa",  hot_limit: 27, cold_limit: 4}
    }

    let loc_str = ($loc | format-loc $is_imperial)

    if $air     { return (build-air-quality $cached $loc $is_imperial $icon_mode) }
    if $hourly  { return (build-hourly  $cached $units $loc_str $icon_mode --raw=$raw) }
    if $forecast { return (build-forecast $cached $units $loc_str $icon_mode --raw=$raw) }

    # Current weather
    let output = (build-current $cached $loc $units $icon_mode)

    if $raw { return $output }

    let term_width = (term size).columns
    let tier = if $oneline { "oneline"
    } else if $minimal { "minimal"
    } else if $compact { "compact"
    } else if $term_width >= $COL_FULL_WIDTH { "full"
    } else if $term_width >= $COL_COMPACT_WIDTH { "compact"
    } else { "minimal" }

    if $tier == "oneline" {
        let code = ($cached.current?.weather_code? | default 0 | into int)
        let is_day = ($cached.current?.is_day? | default 1 | into bool)
        let tc = ($cached.current?.temperature_2m? | default 0.0)
        let temp_val = (to-display-temp $tc $units)
        let icon = if $icon_mode == 'text' { '' } else { $"(wmo-icon $code $is_day $icon_mode) " }
        return $"($loc_str): ($icon)($temp_val)($units.temp_label) - (wmo-desc $code)"
    }

    match $tier {
        "full"    => $output,
        "compact" => ($output | reject Pressure Visibility Clouds),
        "minimal" => ($output | reject Pressure Visibility Clouds UV Humidity Feels AQI),
        _         => $output
    } | table -i false
}
