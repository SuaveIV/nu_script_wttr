# Get weather information from Open-Meteo.
#
# A fast alternative to weather.nu with no API keys. Uses Open-Meteo's free
# API for current conditions, hourly breakdowns, and 3-day forecasts.
# Note: Moon data is not available.
#
# Examples:
#   > meteo                       # Auto-detect location via IP
#   > meteo "New York"            # By city name
#   > meteo -3                    # 3-day forecast
#   > meteo --hourly              # Hourly breakdown (today)
#   > meteo --oneline             # Status bar summary
#   > meteo --air                 # Air quality (AQI, PM2.5, Ozone)
#   > meteo --emoji               # Emoji icons
#   > meteo --debug               # Diagnostics

const COL_FULL_WIDTH    = 100
const COL_COMPACT_WIDTH = 80
const COL_MINIMAL_WIDTH = 60

# Unit configuration records
const METRIC_UNITS = {
    is_imperial: false,
    temp_label: "°C",
    speed_label: "km/h",
    precip_label: "mm",
    vis_label: "km",
    press_label: "hPa",
    hot_limit: 27,
    cold_limit: 4,
    gradients: {
        hot:  {s: '0xffff00', e: '0xff0000'},
        cold: {s: '0xffffff', e: '0x00ffff'},
        mild: {s: '0x00ff00', e: '0xffff00'}
    }
}

const IMPERIAL_UNITS = {
    is_imperial: true,
    temp_label: "°F",
    speed_label: "mph",
    precip_label: "in",
    vis_label: "mi",
    press_label: "inHg",
    hot_limit: 80,
    cold_limit: 40,
    gradients: {
        hot:  {s: '0xffff00', e: '0xff0000'},
        cold: {s: '0xffffff', e: '0x00ffff'},
        mild: {s: '0x00ff00', e: '0xffff00'}
    }
}

# --- Shared helpers (mirrors weather.nu conventions) ---

# Formats a temperature string with unit label and optional ANSI colour gradient.
def format-temp [
    val: string
    units: record
    --text
]: nothing -> string {
    let temp_int: int = ($val | into int)
    if $text {
        $"($val)($units.temp_label)"
    } else {
        let gradient: record = if $temp_int >= $units.hot_limit {
            $units.gradients.hot
        } else if $temp_int <= $units.cold_limit {
            $units.gradients.cold
        } else {
            $units.gradients.mild
        }
        $"($val)($units.temp_label)" | ansi gradient --fgstart $gradient.s --fgend $gradient.e
    }
}

# Formats UV index with label and color.
def format-uv [
    uv: int
    icon_mode: string
]: nothing -> string {
    let label: string = if $uv >= 11 { "Extreme" } else if $uv >= 8 { "Very High" } else if $uv >= 6 { "High" } else if $uv >= 3 { "Moderate" } else { "Low" }
    let color: string = if $uv >= 8 { 'red' } else if $uv >= 6 { 'yellow' } else if $uv >= 3 { 'green' } else { 'grey' }

    if $icon_mode == 'text' {
        $"($uv) ($label)"
    } else {
        let icon: string = if $icon_mode == 'emoji' { '☀ ' } else { "\u{e30d} " }
        $"($icon)(ansi $color)($uv) ($label)(ansi reset)"
    }
}

# Formats AQI value with color gradient.
def format-aqi [val: int, --text]: nothing -> string {
    if $text {
        ($val | into string)
    } else {
        let color: string = if $val <= 50 {
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
    if $icon_mode == 'text' {
        ""
    } else if $icon_mode == 'emoji' {
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
    let dirs: list<string> = ["N" "NNE" "NE" "ENE" "E" "ESE" "SE" "SSE" "S" "SSW" "SW" "WSW" "W" "WNW" "NW" "NNW"]
    let idx: int = ((($degrees + 11.25) / 22.5) | math floor | into int) mod 16
    $dirs | get $idx
}

# Converts a wind speed in km/h to its Beaufort scale number (0–12).
def beaufort-scale [kmph: string]: nothing -> int {
    let k: int = ($kmph | into int)
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
    if $icon_mode != 'nerd' {
        $"[Bft ($scale)]"
    } else {
        match $scale {
            0 => "\u{e3af}", 1 => "\u{e3b0}", 2 => "\u{e3b1}", 3 => "\u{e3b2}",
            4 => "\u{e3b3}", 5 => "\u{e3b4}", 6 => "\u{e3b5}", 7 => "\u{e3b6}",
            8 => "\u{e3b7}", 9 => "\u{e3b8}", 10 => "\u{e3b9}", 11 => "\u{e3ba}", _ => "\u{e3bb}"
        }
    }
}

# Returns a directional arrow glyph (Nerd Font) or raw direction string (emoji/text).
def wind-dir-icon [dir: string, icon_mode: string]: nothing -> string {
    if $icon_mode != 'nerd' {
        $dir
    } else {
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

# Performs an HTTP GET request with retry logic and backoff.
def http-get-with-retry [
    url: string
    max_retries: int = 3
    timeout: duration = 10sec
]: nothing -> any {
    mut last_err: any = null
    for attempt in 1..$max_retries {
        let err: any = try {
            return (http get --max-time $timeout $url)
            null
        } catch {|e| $e }

        $last_err = $err
        if $attempt < $max_retries {
            sleep (($attempt * 200) * 1ms)
        }
    }
    error make {
        msg: $"Failed to fetch ($url) after ($max_retries) attempts"
        help: ($last_err | get msg? | default "unknown error")
    }
}

# --- API helpers ---

# Geocodes a city name to coordinates + metadata via Open-Meteo Geocoding API.
def geocode-city [city: string, lang: string]: nothing -> record {
    let lang_param: string = if ($lang | is-empty) { "en" } else { $lang }
    let url: string = $"https://geocoding-api.open-meteo.com/v1/search?name=($city | url encode)&count=1&language=($lang_param)&format=json"
    let response: any = (http-get-with-retry $url)
    if ($response.results? | is-empty) {
        error make {
            msg: $"Location not found: '($city)'"
            help: "Try a different spelling or a nearby major city."
        }
    }
    let result: record = ($response.results | first)
    {
        name: ($result.name? | default $city),
        admin1: ($result.admin1? | default ""),
        country_name: ($result.country? | default "Unknown"),
        country_code: ($result.country_code? | default ""),
        latitude: ($result.latitude? | default 0.0),
        longitude: ($result.longitude? | default 0.0)
    }
}

# Detects the current location from IP address via ipapi.co.
def detect-location []: nothing -> record {
    let response: any = (http-get-with-retry 'https://ipapi.co/json/')
    {
        name: ($response.city? | default "Unknown"),
        admin1: ($response.region? | default ""),
        country_name: ($response.country_name? | default "Unknown"),
        country_code: ($response.country_code? | default "US"),
        latitude: ($response.latitude? | default 0.0),
        longitude: ($response.longitude? | default 0.0)
    }
}

# Fetches the full forecast payload from Open-Meteo for given coordinates.
# Always fetches in metric + km/h; display layer handles unit conversion.
def fetch-open-meteo [lat: float, lon: float]: nothing -> record {
    let vars_current: string = "temperature_2m,relative_humidity_2m,apparent_temperature,is_day,precipitation,weather_code,cloud_cover,wind_speed_10m,wind_direction_10m,wind_gusts_10m,pressure_msl,visibility,uv_index"
    let vars_hourly: string = "temperature_2m,relative_humidity_2m,apparent_temperature,precipitation_probability,weather_code,wind_speed_10m,wind_direction_10m,wind_gusts_10m"
    let vars_daily: string = "weather_code,temperature_2m_max,temperature_2m_min,sunrise,sunset,precipitation_sum,precipitation_probability_max,wind_speed_10m_max,wind_direction_10m_dominant,uv_index_max,snowfall_sum"
    let url: string = $"https://api.open-meteo.com/v1/forecast?latitude=($lat)&longitude=($lon)&current=($vars_current)&hourly=($vars_hourly)&daily=($vars_daily)&timezone=auto&forecast_days=3"
    http-get-with-retry $url
}

# Fetches air quality data from Open-Meteo.
def fetch-air-quality [lat: float, lon: float]: nothing -> record {
    let url: string = $"https://air-quality-api.open-meteo.com/v1/air-quality?latitude=($lat)&longitude=($lon)&current=pm2_5,pm10,ozone,nitrogen_dioxide,us_aqi,european_aqi&timezone=auto"
    http-get-with-retry $url
}

# --- Display builders ---

# Builds the current weather output record.
def build-current [
    data: record
    loc: record
    units: record
    icon_mode: string
    --raw
]: nothing -> record {
    let cur: record = ($data.current? | default {})
    let is_day: bool = ($cur.is_day? | default 1 | into bool)
    let code: int = ($cur.weather_code? | default 0 | into int)
    let desc: string = (wmo-desc $code)

    # Temps (API is always °C; convert to °F if imperial)
    let temp_celsius: float = ($cur.temperature_2m? | default 0.0)
    let feels_celsius: float = ($cur.apparent_temperature? | default 0.0)

    # Wind (API is always km/h)
    let wind_kmh: float = ($cur.wind_speed_10m? | default 0.0)
    let wind_deg: float = ($cur.wind_direction_10m? | default 0.0)
    let wind_dir: string = (degrees-to-compass $wind_deg)
    let gust_kmh: float = ($cur.wind_gusts_10m? | default 0.0)

    # Precipitation (API is always mm)
    let precip_mm: float = ($cur.precipitation? | default 0.0)

    # Visibility (API is always metres)
    let visibility_metres: float = ($cur.visibility? | default 0.0)

    # Pressure (API is always hPa)
    let press_hpa: float = ($cur.pressure_msl? | default 1013.0)

    # Clouds & humidity
    let clouds: int = ($cur.cloud_cover? | default 0 | into int)
    let humidity: int = ($cur.relative_humidity_2m? | default 0 | into int)

    # UV
    let uv: int = ($cur.uv_index? | default 0.0 | math round | into int)

    # AQI
    let us_aqi: int = ($cur.us_aqi? | default 0 | into int)
    let eu_aqi: int = ($cur.european_aqi? | default 0 | into int)

    # Sunrise / Sunset from today's daily slot
    let sunrise_raw: any = ($data.daily?.sunrise? | default [] | try { first } catch { "" })
    let sunset_raw: any = ($data.daily?.sunset? | default [] | try { first } catch { "" })
    let sunrise: string = try { $sunrise_raw | into datetime | format date '%H:%M' } catch { $sunrise_raw }
    let sunset: string = try { $sunset_raw | into datetime | format date '%H:%M' } catch { $sunset_raw }

    if $raw {
        let temp_val = if $units.is_imperial { (($temp_celsius * 9 / 5) + 32) } else { $temp_celsius } | math round
        let feels_val = if $units.is_imperial { (($feels_celsius * 9 / 5) + 32) } else { $feels_celsius } | math round
        let wind_val = if $units.is_imperial { ($wind_kmh * 0.621371) } else { $wind_kmh } | math round
        let gust_val = if $units.is_imperial { ($gust_kmh * 0.621371) } else { $gust_kmh } | math round
        let precip_val = if $units.is_imperial { ($precip_mm * 0.0393701 | math round --precision 2) } else { $precip_mm }
        let vis_val = if $units.is_imperial { ($visibility_metres / 1609.34 | math round --precision 1) } else { ($visibility_metres / 1000 | math round --precision 1) }
        let press_val = if $units.is_imperial { ($press_hpa * 0.02953 | math round --precision 2) } else { ($press_hpa | math round) }
        let aqi_val = if $units.is_imperial { $us_aqi } else { $eu_aqi }

        let base = {
            Location: ($loc | format-loc $units.is_imperial),
            Condition: $desc,
            Temperature: $temp_val,
            Feels: $feels_val,
            WindSpeed: $wind_val,
            WindDirection: $wind_dir,
            Clouds: $clouds,
            Precipitation: $precip_val,
            Humidity: $humidity,
            Pressure: $press_val,
            Visibility: $vis_val,
            UV: $uv,
            AQI: $aqi_val,
            Sunrise: $sunrise,
            Sunset: $sunset
        }
        if $gust_val > 0 { $base | insert WindGusts $gust_val } else { $base }
    } else {
        let icon: string = (wmo-icon $code $is_day $icon_mode)
        let temp_display: string = (format-temp (to-display-temp $temp_celsius $units) $units --text=($icon_mode == 'text'))
        let feels_display: string = (format-temp (to-display-temp $feels_celsius $units) $units --text=($icon_mode == 'text'))

        let beaufort: int = (beaufort-scale ($wind_kmh | math round | into string))
        let beaufort_icon: string = (beaufort-icon $beaufort $icon_mode)
        let wind_speed: string = (to-display-speed $wind_kmh $units)
        let wind_icon: string = if $icon_mode == 'emoji' { $"💨 ($beaufort_icon) " } else { $"($beaufort_icon) " }
        let wind: string = $"($wind_icon)($wind_speed)($units.speed_label) (wind-dir-icon $wind_dir $icon_mode)"

        let precip_val: string = if $units.is_imperial {
            $"($precip_mm * 0.0393701 | math round --precision 2)"
        } else { $"($precip_mm)" }
        let icon_rain: string = if $icon_mode == 'text' { '' } else if $icon_mode == 'emoji' { '☔ ' } else { "\u{e319} " }
        let precip: string = $"($icon_rain)($precip_val)($units.precip_label)"

        let visibility_val: string = if $units.is_imperial {
            $"($visibility_metres / 1609.34 | math round --precision 1)"
        } else {
            $"($visibility_metres / 1000 | math round --precision 1)"
        }
        let icon_vis: string = if $icon_mode == 'text' { '' } else if $icon_mode == 'emoji' { '👁 ' } else { "\u{e3ae} " }
        let visibility: string = $"($icon_vis)($visibility_val)($units.vis_label)"

        let press_val: string = if $units.is_imperial {
            $"($press_hpa * 0.02953 | math round --precision 2)"
        } else {
            $"($press_hpa | math round)"
        }
        let icon_press: string = if $icon_mode == 'text' { '' } else if $icon_mode == 'emoji' { '⏲ ' } else { "\u{e372} " }
        let pressure: string = $"($icon_press)($press_val)($units.press_label)"

        let icon_cloud: string = if $icon_mode == 'text' { '' } else if $icon_mode == 'emoji' { '☁ ' } else { "\u{e312} " }
        let icon_humid: string = if $icon_mode == 'text' { '' } else if $icon_mode == 'emoji' { '💧 ' } else { "\u{e373} " }

        let aqi_val: int = if $units.is_imperial { $us_aqi } else { $eu_aqi }
        let aqi_label: string = if $units.is_imperial { "AQI (US)" } else { "AQI (EU)" }
        let aqi_display: string = (format-aqi $aqi_val --text=($icon_mode == 'text'))
        let icon_aqi: string = if $icon_mode == 'text' { '' } else if $icon_mode == 'emoji' { '🍃 ' } else { "\u{f06c} " }

        let is_severe: bool = ($code in [95 96 99])
        let alert: string = if $is_severe {
            if $icon_mode == 'text' { ' [SEVERE]' } else if $icon_mode == 'emoji' { ' ⚠️' } else { ' ' }
        } else { '' }

        let icon_sr: string = if $icon_mode == 'text' { 'Sunrise: ' } else if $icon_mode == 'emoji' { '🌅 ' } else { "\u{e34c} " }
        let icon_ss: string = if $icon_mode == 'text' { 'Sunset: ' } else if $icon_mode == 'emoji' { '🌇 ' } else { "\u{e34d} " }

        let condition: string = if $icon_mode == 'text' {
            $"($desc)($alert)"
        } else {
            $"($icon) ($desc)($alert)"
        }

        let gusts_part: record = if $gust_kmh > 0 {
            let gust_val: string = (to-display-speed $gust_kmh $units)
            { Gusts: $"($gust_val)($units.speed_label)" }
        } else { {} }

        {
            Location:    ($loc | format-loc $units.is_imperial),
            Condition:   $condition,
            Temperature: $temp_display,
            Feels:       $feels_display,
            Wind:        $wind
        }
        | merge $gusts_part
        | merge {
            Clouds:      $"($icon_cloud)($clouds)%",
            Rain:        $precip,
            Humidity:    $"($icon_humid)($humidity)%",
            Pressure:    $pressure,
            Visibility:  $visibility,
            UV:          (format-uv $uv $icon_mode),
            AQI:         $"($icon_aqi)($aqi_display) ($aqi_label)",
            Astronomy:   $"($icon_sr)($sunrise) | ($icon_ss)($sunset)"
        }
    }
}

# Builds hourly forecast rows for today (3-hour intervals).
def build-hourly [
    data: record
    units: record
    icon_mode: string
    --raw
]: nothing -> list<any> {
    let hourly: record = ($data.hourly? | default {time: []})
    let times: list<string> = ($hourly.time? | default [])
    let today: string = (date now | format date '%Y-%m-%d')

    let rows: list<record> = ($times | enumerate | where {|item|
        let t = $item.item
        if not ($t | str starts-with $today) {
            false
        } else {
            let h = ($t | into datetime | format date '%H' | into int)
            ($h mod 3) == 0
        }
    } | each {|item|
        let t: string = $item.item
        let i: int = $item.index

        let temp_celsius: float = try { $hourly.temperature_2m         | get $i | default 0.0 } catch { 0.0 }
        let code: int     = try { $hourly.weather_code            | get $i | into int } catch { 0 }
        let wind_kmh: float = try { $hourly.wind_speed_10m          | get $i | default 0.0 } catch { 0.0 }
        let wind_deg: float = try { $hourly.wind_direction_10m      | get $i | default 0.0 } catch { 0.0 }
        let gust_kmh: float = try { $hourly.wind_gusts_10m          | get $i | default 0.0 } catch { 0.0 }
        let precip_probability: int = try { $hourly.precipitation_probability | get $i | into int } catch { 0 }
        let humidity: int = try { $hourly.relative_humidity_2m    | get $i | into int } catch { 0 }

        let wind_dir: string = (degrees-to-compass $wind_deg)

        if $raw {
            let temp_val = if $units.is_imperial { (($temp_celsius * 9 / 5) + 32) } else { $temp_celsius } | math round
            let wind_val = if $units.is_imperial { ($wind_kmh * 0.621371) } else { $wind_kmh } | math round
            let gust_val = if $units.is_imperial { ($gust_kmh * 0.621371) } else { $gust_kmh } | math round

            let row = {
                Time: ($t | str substring 11..15),
                Condition: (wmo-desc $code),
                Temperature: $temp_val,
                WindSpeed: $wind_val,
                WindDirection: $wind_dir,
                PrecipitationProbability: $precip_probability,
                Humidity: $humidity
            }
            if $gust_val > 0 { $row | insert WindGusts $gust_val } else { $row }
        } else {
            let beaufort: int = (beaufort-scale ($wind_kmh | math round | into string))
            let speed: string = (to-display-speed $wind_kmh $units)

            let row: record = {
                Time:      ($t | str substring 11..15),
                Condition: (if $icon_mode == 'text' { wmo-desc $code } else { $"(wmo-icon $code true $icon_mode) (wmo-desc $code)" }),
                Temp:      (format-temp (to-display-temp $temp_celsius $units) $units --text=($icon_mode == 'text')),
                Wind:      $"(wind-dir-icon $wind_dir $icon_mode) ($speed)($units.speed_label) (beaufort-icon $beaufort $icon_mode)",
                Precip:    $"($precip_probability)%",
                Humidity:  $"($humidity)%"
            }

            if $gust_kmh > 0 {
                let gust_val: string = (to-display-speed $gust_kmh $units)
                $row | insert Gusts $"($gust_val)($units.speed_label)"
            } else {
                $row
            }
        }
    })

    $rows
}

# Builds the 3-day forecast table.
def build-forecast [
    data: record
    units: record
    icon_mode: string
    --raw
]: nothing -> list<any> {
    let daily: record = ($data.daily? | default {time: []})
    let times: list<string> = ($daily.time? | default [])
    let has_snow: bool = ($daily.snowfall_sum? | default [] | any {|x| $x > 0})

    let rows: list<record> = ($times | enumerate | each {|item|
        let t: string = $item.item
        let i: int = $item.index
        let code: int      = try { $daily.weather_code                    | get $i | into int } catch { 0 }
        let temp_max_celsius: float = try { $daily.temperature_2m_max              | get $i | default 0.0 } catch { 0.0 }
        let temp_min_celsius: float = try { $daily.temperature_2m_min              | get $i | default 0.0 } catch { 0.0 }
        let precip_mm: float = try { $daily.precipitation_sum               | get $i | default 0.0 } catch { 0.0 }
        let snow_mm: float   = try { $daily.snowfall_sum                    | get $i | default 0.0 } catch { 0.0 }
        let precip_probability: int = try { $daily.precipitation_probability_max   | get $i | into int } catch { 0 }
        let wind_kmh: float  = try { $daily.wind_speed_10m_max              | get $i | default 0.0 } catch { 0.0 }
        let wind_deg: float  = try { $daily.wind_direction_10m_dominant     | get $i | default 0.0 } catch { 0.0 }
        let uv_max: int    = try { $daily.uv_index_max                    | get $i | math round | into int } catch { 0 }
        let sunrise_raw: any = try { $daily.sunrise                         | get $i } catch { "" }
        let sunset_raw: any = try { $daily.sunset                          | get $i } catch { "" }

        let wind_dir: string = (degrees-to-compass $wind_deg)
        let sunrise: string = try { $sunrise_raw | into datetime | format date '%H:%M' } catch { $sunrise_raw }
        let sunset: string = try { $sunset_raw | into datetime | format date '%H:%M' } catch { $sunset_raw }

        if $raw {
            let high_val = if $units.is_imperial { (($temp_max_celsius * 9 / 5) + 32) } else { $temp_max_celsius } | math round
            let low_val = if $units.is_imperial { (($temp_min_celsius * 9 / 5) + 32) } else { $temp_min_celsius } | math round
            let precip_val = if $units.is_imperial { ($precip_mm * 0.0393701 | math round --precision 2) } else { $precip_mm }
            let snow_val = if $units.is_imperial { ($snow_mm * 0.0393701 | math round --precision 2) } else { $snow_mm }
            let wind_val = if $units.is_imperial { ($wind_kmh * 0.621371) } else { $wind_kmh } | math round

            let row = {
                Date: ($t | into datetime | format date '%Y-%m-%d'),
                Condition: (wmo-desc $code),
                High: $high_val,
                Low: $low_val,
                Precipitation: $precip_val,
                PrecipitationProbability: $precip_probability,
                Snow: $snow_val,
                WindSpeed: $wind_val,
                WindDirection: $wind_dir,
                UV: $uv_max,
                Sunrise: $sunrise,
                Sunset: $sunset
            }
            if $has_snow { $row } else { $row | reject Snow }
        } else {
            let precip_val: string = if $units.is_imperial { $"($precip_mm * 0.0393701 | math round --precision 2)($units.precip_label)" } else { $"($precip_mm)($units.precip_label)" }
            let snow_val: string = if $units.is_imperial { $"($snow_mm * 0.0393701 | math round --precision 2)($units.precip_label)" } else { $"($snow_mm)($units.precip_label)" }
            let speed: string = (to-display-speed $wind_kmh $units)
            let icon_sr: string = if $icon_mode == 'text' { '' } else if $icon_mode == 'emoji' { '🌅 ' } else { "\u{e34c} " }
            let icon_ss: string = if $icon_mode == 'text' { '' } else if $icon_mode == 'emoji' { '🌇 ' } else { "\u{e34d} " }

            let row: record = {
                Date:      ($t | into datetime | format date '%a, %b %d'),
                Condition: (if $icon_mode == 'text' { wmo-desc $code } else { $"(wmo-icon $code true $icon_mode) (wmo-desc $code)" }),
                High:      (format-temp (to-display-temp $temp_max_celsius $units) $units --text=($icon_mode == 'text')),
                Low:       (format-temp (to-display-temp $temp_min_celsius $units) $units --text=($icon_mode == 'text')),
                Rain:      $"($precip_val) ($precip_probability)%",
                Snow:      $snow_val,
                Wind:      $"(wind-dir-icon $wind_dir $icon_mode) ($speed)($units.speed_label)",
                UV:        (format-uv $uv_max $icon_mode),
                Sunrise:   $"($icon_sr)($sunrise)",
                Sunset:    $"($icon_ss)($sunset)"
            }
            if $has_snow { $row } else { $row | reject Snow }
        }
    })

    $rows
}

# Builds the air quality display record.
def build-air-quality [
    data: record
    loc: record
    is_imperial: bool
    icon_mode: string
    --raw
]: nothing -> record {
    let current: record = ($data.current? | default {})
    let pm2_5: float = ($current.pm2_5? | default 0)
    let pm10_val: float = ($current.pm10? | default 0)
    let ozone: float = ($current.ozone? | default 0)
    let nitrogen_dioxide: float = ($current.nitrogen_dioxide? | default 0)
    let us_aqi: int = ($current.us_aqi? | default 0)
    let eu_aqi: int = ($current.european_aqi? | default 0)

    if $raw {
        {
            Location: ($loc | format-loc $is_imperial),
            PM2_5: $pm2_5,
            PM10: $pm10_val,
            Ozone: $ozone,
            NitrogenDioxide: $nitrogen_dioxide,
            USAQI: $us_aqi,
            EUAQI: $eu_aqi
        }
    } else {
        {
            Location: ($loc | format-loc $is_imperial),
            "PM2.5":  $"($pm2_5) µg/m³",
            "PM10":   $"($pm10_val) µg/m³",
            "Ozone":  $"($ozone) µg/m³",
            "NO2":    $"($nitrogen_dioxide) µg/m³",
            "US AQI": (format-aqi $us_aqi --text=($icon_mode == 'text')),
            "EU AQI": (format-aqi $eu_aqi --text=($icon_mode == 'text'))
        }
    }
}

# Builds the one-line summary string.
def build-oneline-display [
    data: record
    loc_str: string
    units: record
    icon_mode: string
]: nothing -> string {
    let code: int = ($data.current?.weather_code? | default 0 | into int)
    let is_day: bool = ($data.current?.is_day? | default 1 | into bool)
    let tc: float = ($data.current?.temperature_2m? | default 0.0)
    let temp_val: string = (to-display-temp $tc $units)
    let icon: string = if $icon_mode == 'text' { '' } else { $"(wmo-icon $code $is_day $icon_mode) " }
    $"($loc_str): ($icon)($temp_val)($units.temp_label) - (wmo-desc $code)"
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
    let loc: record = $in
    let name: string = ($loc.name? | default "Unknown")
    let admin1: string = ($loc.admin1? | default "")
    let country: string = ($loc.country_name? | default "Unknown")
    if $is_imperial and not ($admin1 | is-empty) {
        $"($name), ($admin1)"
    } else {
        $"($name), ($country)"
    }
}

# Returns the unit configuration record based on the system (Imperial vs Metric).
def build-config [is_imperial: bool]: nothing -> record {
    if $is_imperial {
        $IMPERIAL_UNITS
    } else {
        $METRIC_UNITS
    }
}

# --- Mock Data Generators ---

# Returns a minimal location fixture for testing.
def test-location []: nothing -> record {
    {
        name: "Null Island"
        admin1: ""
        country_name: "Testland"
        country_code: "XX"
        latitude: 0.0
        longitude: 0.0
    }
}

# Returns a minimal two-item fixture mirroring the API response.
# Intentionally includes nulls and missing keys to test defensive extraction.
def test-data []: nothing -> record {
    let today: string = (date now | format date '%Y-%m-%d')
    let tomorrow: string = ((date now) + 1day | format date '%Y-%m-%d')
    {
        current: {
            is_day: null
            temperature_2m: null
            weather_code: null
            pm2_5: null
            pm10: null
            us_aqi: null
            european_aqi: null
        }
        hourly: {
            time: [$"($today)T00:00" $"($today)T03:00"]
            temperature_2m: [10.0]
            weather_code: [null 3]
        }
        daily: {
            time: [$today $tomorrow]
            weather_code: [null 0]
            temperature_2m_max: [null 20.0]
            temperature_2m_min: [null 10.0]
            precipitation_sum: [null null]
        }
    }
}

# Returns a location fixture for demo mode.
def demo-location []: nothing -> record {
    {
        name: "Demo City"
        admin1: "Demo State"
        country_name: "United States"
        country_code: "US"
        latitude: 33.5
        longitude: -85.0
    }
}

# Returns 8 varied records to exercise every colour threshold, column, and icon state.
def demo-data []: nothing -> record {
    let now = (date now)
    let today_str = ($now | format date '%Y-%m-%d')
    let dates = (0..7 | each {|i| $now + ($i * 1day) | format date '%Y-%m-%d'})
    let sunrises = ($dates | enumerate | each {|d|
        let min = 10 - $d.index
        let min_str = if $min < 10 { $"0($min)" } else { $min }
        $"($d.item)T07:($min_str)"
    })
    let sunsets = ($dates | enumerate | each {|d|
        let min = 35 + $d.index
        $"($d.item)T18:($min)"
    })

    {
        current: {
            time: $"($today_str)T12:00"
            interval: 3600
            temperature_2m: 30.0
            relative_humidity_2m: 85
            apparent_temperature: 35.0
            is_day: 1
            precipitation: 10.0
            weather_code: 95
            cloud_cover: 100
            wind_speed_10m: 110.0
            wind_direction_10m: 180
            wind_gusts_10m: 130.0
            pressure_msl: 980.0
            visibility: 500.0
            uv_index: 12.0
            pm2_5: 250.0
            pm10: 300.0
            ozone: 150.0
            nitrogen_dioxide: 100.0
            us_aqi: 250
            european_aqi: 250
        }
        hourly: {
            time: [
                $"($today_str)T00:00" $"($today_str)T03:00" $"($today_str)T06:00" $"($today_str)T09:00"
                $"($today_str)T12:00" $"($today_str)T15:00" $"($today_str)T18:00" $"($today_str)T21:00"
            ]
            temperature_2m: [-10.0 0.0 10.0 15.0 20.0 25.0 30.0 40.0]
            relative_humidity_2m: [20 30 40 50 60 70 80 99]
            apparent_temperature: [-15.0 -5.0 8.0 15.0 22.0 28.0 35.0 45.0]
            precipitation_probability: [0 10 20 50 80 100 10 0]
            weather_code: [0 1 2 3 45 63 73 99]
            wind_speed_10m: [0.0 5.0 15.0 25.0 40.0 60.0 80.0 110.0]
            wind_direction_10m: [0 45 90 135 180 225 270 315]
            wind_gusts_10m: [0.0 10.0 25.0 40.0 60.0 80.0 100.0 130.0]
        }
        daily: {
            time: $dates
            weather_code: [0 2 45 63 73 95 99 1]
            temperature_2m_max: [-5.0 10.0 15.0 20.0 25.0 30.0 35.0 40.0]
            temperature_2m_min: [-15.0 0.0 5.0 10.0 15.0 20.0 25.0 30.0]
            sunrise: $sunrises
            sunset: $sunsets
            precipitation_sum: [0.0 0.0 2.0 25.0 10.0 50.0 80.0 0.0]
            precipitation_probability_max: [0 10 30 90 100 100 100 5]
            wind_speed_10m_max: [5.0 15.0 10.0 40.0 60.0 80.0 120.0 20.0]
            wind_direction_10m_dominant: [0 90 180 270 360 45 135 225]
            uv_index_max: [1.0 3.0 4.0 2.0 1.0 8.0 11.0 6.0]
            snowfall_sum: [0.0 0.0 0.0 0.0 15.0 0.0 5.0 0.0]
        }
    }
}

# --- Main command ---

# Get weather information from Open-Meteo. No API keys required.
#
# Responses are cached for 15 minutes. Units are auto-selected by country
# unless forced with a flag. Descriptions are always in English.
#
# Examples:
#   > meteo                      # Current weather (auto-detect)
#   > meteo "Tokyo"              # By city
#   > meteo -3                   # 3-day forecast
#   > meteo -H                   # Hourly breakdown
#   > meteo -1                   # Single line
#   > meteo -E "London"          # Emojis
#   > meteo -Q "Paris"           # Air quality
#   > meteo -T -r "Berlin" | to json  # For scripts
export def main [
    city: string = ""            # Location to fetch weather for. Leave empty to auto-detect.
    --raw (-r)                   # Return raw record instead of a formatted table.
    --debug                      # Print network and parsing diagnostics.
    --metric (-m)                # Force metric units (°C, km/h).
    --imperial (-i)              # Force imperial units (°F, mph).
    --forecast (-3)              # Show 3-day forecast.
    --oneline (-1)               # Show a single-line summary (e.g. for status bars).
    --compact (-C)               # Compact output (drops Pressure, Visibility, Clouds).
    --minimal (-M)               # Minimal output (also drops UV, Humidity, Feels).
    --json (-j)                  # Return the full raw API response as data.
    --emoji (-E)                 # Use emoji icons instead of Nerd Font glyphs.
    --text (-T)                  # Plain text output — no icons, no colours.
    --force (-f)                 # Bypass cache and force a fresh network request.
    --hourly (-H)                # Show hourly forecast for today (3-hour intervals).
    --clear-cache                # Delete all cached data and exit.
    --lang: string = ""          # Language code for geocoding place names (e.g. 'fr', 'de').
    --air (-Q)                   # Show air quality data (PM2.5, PM10, Ozone, NO2, AQI).
    --test                       # Use a minimal mock payload to test defensive parsing and edge cases.
    --demo                       # Use a varied mock payload to demonstrate color thresholds and states.
]: nothing -> any {
    let start_time: datetime = (date now)
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

    let lang_suffix: string = if ($lang | is-empty) { '' } else { $"_($lang)" }
    let type_suffix: string = if $air { "_aqi" } else { "" }
    let cache_file: string = if ($city | is-empty) {
        $"auto($lang_suffix)($type_suffix).json"
    } else {
        $"($city | url encode)($lang_suffix)($type_suffix).json"
    }
    $cache_dir | path join $cache_file | let cache_path: string
    let ttl: duration = if $air { 30min } else { 15min }

    # Bypass cache completely if forcing fetch, testing, or running demo mode
    let use_cache: bool = if $force or $test or $demo { false } else { is-cache-valid $cache_path $ttl }

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

        let geo: record = if $test {
            test-location
        } else if $demo {
            demo-location
        } else {
            try {
                if ($city | is-empty) {
                    if $debug { print "Auto-detecting location via IP (ipapi.co)..." }
                    detect-location
                } else {
                    if $debug { print $"Geocoding '($city)' via Open-Meteo..." }
                    geocode-city $city $lang
                }
            } catch {|err|
                error make { msg: "Could not resolve location", help: $err.msg }
            }
        }

        if $debug and not ($test or $demo) {
            print $"(ansi green)✓ Location: ($geo.name), ($geo.country_name)(ansi reset)"
            print $"  Coordinates: ($geo.latitude), ($geo.longitude)"
        }

        let weather: record = if $test {
            test-data
        } else if $demo {
            demo-data
        } else {
            try {
                if $air {
                    if $debug { print "Fetching air quality from Open-Meteo..." }
                    fetch-air-quality $geo.latitude $geo.longitude
                } else {
                    if $debug { print "Fetching forecast from Open-Meteo..." }
                    let w: record = (fetch-open-meteo $geo.latitude $geo.longitude)

                    if $debug { print "Fetching AQI from Open-Meteo..." }
                    let a: record = try {
                        fetch-air-quality $geo.latitude $geo.longitude
                    } catch {
                        if $debug { print "(ansi yellow)AQI fetch failed, skipping...(ansi reset)" }
                        { current: {} }
                    }

                    let merged_cur: record = (($w.current? | default {}) | merge ($a.current? | default {}))
                    $w | update current $merged_cur
                }
            } catch {|err|
                let location_clause: string = if ($city | is-empty) { "" } else { $" for '($city)'" }
                error make {
                    msg: $"Could not fetch weather($location_clause)"
                    help: $err.msg
                }
            }
        }

        if $debug and not ($test or $demo) { print $"(ansi green)✓ Data received(ansi reset)\n" }

        let combined: record = ($weather | insert location $geo)

        if not ($test or $demo) {
            $combined | save -f $cache_path
        }
        $combined
    }

    if $json { return $cached }

    let loc: record = ($cached.location? | default {name: "Unknown", admin1: "", country_name: "Unknown", country_code: "US", latitude: 0.0, longitude: 0.0})

    # Determine units — imperial only for US, Liberia (LR), Myanmar (MM)
    let country_code: string = ($loc.country_code? | default "" | str upcase)
    let is_imperial: bool = if $imperial { true } else if $metric { false } else {
        $country_code in ["US" "LR" "MM"]
    }

    if $debug {
        print $"Country code: ($country_code)"
        print $"Using units:  (if $is_imperial { 'Imperial (°F, mph)' } else { 'Metric (°C, km/h)' })"
        print ""
    }

    let units: record = (build-config $is_imperial)

    let loc_str: string = ($loc | format-loc $is_imperial)

    # If testing, sequentially run and print all display modes to verify defensive logic
    if $test {
        print $"(ansi cyan_bold)--- Testing: Oneline ---(ansi reset)"
        print (build-oneline-display $cached $loc_str $units $icon_mode)
        print ""
        print $"(ansi cyan_bold)--- Testing: Air Quality ---(ansi reset)"
        print (build-air-quality $cached $loc $is_imperial $icon_mode --raw=$raw | table -i false)
        print $"(ansi cyan_bold)--- Testing: Hourly ---(ansi reset)"
        print (build-hourly $cached $units $icon_mode --raw=$raw | table -i false)
        print $"(ansi cyan_bold)--- Testing: Forecast ---(ansi reset)"
        print (build-forecast $cached $units $icon_mode --raw=$raw | table -i false)
        print $"(ansi cyan_bold)--- Testing: Current [Full] ---(ansi reset)"
        print (build-current $cached $loc $units $icon_mode --raw=$raw | table -i false)
        return
    }

    if $air {
        let out: record = (build-air-quality $cached $loc $is_imperial $icon_mode --raw=$raw)
        if $raw { return $out }
        print ($out | table -i false)
    } else if $hourly {
        let data: list<any> = (build-hourly $cached $units $icon_mode --raw=$raw)
        if $raw { return $data }
        print $"(ansi cyan_bold)Hourly Forecast for ($loc_str)(ansi reset)"
        print ($data | table -i false)
    } else if $forecast {
        let data: list<any> = (build-forecast $cached $units $icon_mode --raw=$raw)
        if $raw { return $data }
        print $"(ansi cyan_bold)3-Day Forecast for ($loc_str)(ansi reset)"
        print ($data | table -i false)
    } else {
        # Current weather
        if $raw {
            return (build-current $cached $loc $units $icon_mode --raw)
        }

        let term_width: int = (term size).columns
        let tier: string = if $oneline { "oneline"
        } else if $minimal { "minimal"
        } else if $compact { "compact"
        } else if $term_width >= $COL_FULL_WIDTH { "full"
        } else if $term_width >= $COL_COMPACT_WIDTH { "compact"
        } else { "minimal" }

        if $tier == "oneline" {
            print (build-oneline-display $cached $loc_str $units $icon_mode)
        } else {
            let output: record = (build-current $cached $loc $units $icon_mode)
            print (match $tier {
                "full"    => $output,
                "compact" => ($output | reject Pressure Visibility Clouds),
                "minimal" => ($output | reject Pressure Visibility Clouds UV Humidity Feels AQI),
                _         => $output
            } | table -i false)
        }
    }

    # --- Timing Footer ---
    if not ($test or $raw or $json) {
        if $demo {
            print $"(ansi light_gray)Fetched in 241ms(ansi reset)"
        } else {
            let fetch_duration: duration = ((date now) - $start_time)
            if $use_cache {
                let cache_age: duration = ((date now) - (ls $cache_path | get modified | first))
                print $"(ansi light_gray)Loaded from cache [($cache_age) old](ansi reset)"
            } else {
                print $"(ansi light_gray)Fetched in ($fetch_duration)(ansi reset)"
            }
        }
    }
}
