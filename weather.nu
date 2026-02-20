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

# Helper Commands

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

def weather-icon [
    code: string          # WorldWeatherOnline weather code
    --emoji               # Use emoji instead of Nerd Font icons
    --text                # Plain text mode (no icons)
]: nothing -> string {
    if $text { return "" }
    if $emoji {
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

def moon-icon [
    phase: string         # Moon phase name from API
    illum: string         # Moon illumination percentage as API string
    --emoji               # Use emoji instead of Nerd Font icons
    --text                # Plain text mode (no icons)
]: nothing -> string {
    if $text { return "" }
    let illum_int = ($illum | into int)
    let phase_lower = ($phase | str downcase)
    
    let fallback = if $emoji {
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

    if $emoji {
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

def beaufort-icon [
    scale: int            # Beaufort scale number
    --emoji               # Use emoji instead of Nerd Font icons
    --text                # Plain text mode (no icons)
]: nothing -> string {
    if $emoji or $text {
        return $"[Bft ($scale)]"
    }
    match $scale {
        0 => "", 1 => "", 2 => "", 3 => "", 4 => "", 5 => "",
        6 => "", 7 => "", 8 => "", 9 => "", 10 => "", 11 => "", _ => ""
    }
}

def wind-dir-icon [
    dir: string           # Wind direction (e.g. N, SW)
    --emoji               # Use emoji instead of Nerd Font icons
    --text                # Plain text mode (no icons)
]: nothing -> string {
    if $emoji or $text {
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

export def main [
    city: string = ""               # The location to fetch weather for. Leave empty to auto-detect.
    --raw (-r)                      # Return raw record data instead of a formatted table (useful for piping).
    --debug                         # Print detailed network and parsing diagnostics.
    --test                          # Use dummy data for testing purposes without making network requests.
    --metric (-m)                   # Force metric units (°C, km/h) regardless of location.
    --imperial (-i)                 # Force imperial units (°F, mph) regardless of location.
    --forecast (-3)                 # Show weather forecast for the next 3 days.
    --oneline (-1)                  # Show a single line summary (e.g. for status bars).
    --json (-j)                     # Return the full raw API response as data.
    --emoji (-e)                    # Use Emojis instead of Nerd Font icons (Default is Nerd Fonts).
    --text (-t)                     # Plain text output (no icons, no colors).
    --force (-f)                    # Bypass cache and force a network request.
    --astro (-a)                    # Show detailed astronomy data (Sunrise, Sunset, Moon phase, etc).
    --hourly (-h)                   # Show hourly forecast for today (3-hour intervals).
    --lang: string = ""             # Specify language code (e.g. 'fr', 'de', 'es', 'zh'). Empty = auto.
]: nothing -> any {
    # URL encode for API (handles all special chars including Unicode)
    $city | url encode | let url_encoded_city: string
    
    # Display name is just the original input
    let display_city: string = if ($city | is-empty) { 'Auto-detect' } else { $city }
    
    # Build the full URL
    let language_param: string = if ($lang | is-empty) { '' } else { $"&lang=($lang)" }
    $"https://wttr.in/($url_encoded_city)?format=j1($language_param)" | let url: string
    
    # Cache Configuration
    $nu.cache-dir? | default ($env.TEMP? | default $env.TMP? | default '/tmp') | let base_dir: string
    $base_dir | path join 'nu_weather_cache' | let cache_dir: string
    if not ($cache_dir | path exists) { mkdir $cache_dir }
    let language_suffix: string = if ($lang | is-empty) { '' } else { $"_($lang)" }
    let cache_file: string = if ($url_encoded_city | is-empty) { $"auto($language_suffix).json" } else { $"($url_encoded_city)($language_suffix).json" }
    $cache_dir | path join $cache_file | let cache_path: string
    let is_cache_valid: bool = if $force {
        false
    } else if ($cache_path | path exists) {
        let modified = (ls $cache_path | get modified | first)
        ((date now) - $modified) < 15min
    } else { false }

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
        print $"Display Mode:   (if $text { 'Text' } else if $emoji { 'Emoji' } else { 'Nerd Font' })"
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
            let res = (http get $url)
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

    # Handle Astronomy Mode
    if $astro {
        if $debug { print $"(ansi cyan)ℹ Processing Astronomy Data...(ansi reset)" }
        $data.weather | first | get astronomy | first | let current_astro
        
        let moon_phase = ($current_astro.moon_phase)
        let moon_illum = ($current_astro.moon_illumination)
        let moon_icon = moon-icon $moon_phase $moon_illum --emoji=$emoji --text=$text
        
        let sunrise_icon = if $text { '' } else if $emoji { '🌅 ' } else { " " } # nf-weather-sunrise
        let sunset_icon = if $text { '' } else if $emoji { '🌇 ' } else { " " } # nf-weather-sunset
        let moonrise_icon = if $text { '' } else if $emoji { "☾↑ " } else { " " } # nf-weather-moonrise
        let moonset_icon = if $text { '' } else if $emoji { "☾↓ " } else { " " } # nf-weather-moonset
        
        let output = {
            "Sunrise": $"($sunrise_icon)($current_astro.sunrise)",
            "Sunset": $"($sunset_icon)($current_astro.sunset)",
            "Moonrise": $"($moonrise_icon)($current_astro.moonrise)",
            "Moonset": $"($moonset_icon)($current_astro.moonset)",
            "Moon Phase": $"($moon_icon) ($moon_phase)",
            "Illumination": $"($moon_illum)%"
        }
        
        if $raw {
            return $current_astro
        } else {
            if not $text { print $"(ansi cyan_bold)Astronomy for ($actual_location)(ansi reset)" } else { print $"Astronomy for ($actual_location)" }
            return ($output | table -i false)
        }
    }

    # Handle Hourly Mode
    if $hourly {
        if $debug { print $"(ansi cyan)ℹ Processing Hourly Forecast...(ansi reset)" }
        $data.weather | first | let today
        
        # Define icons for hourly table
        let icon_snow = if $text { '' } else if $emoji { '❄ ' } else { " " }
        let icon_rain = if $text { '' } else if $emoji { '☔ ' } else { " " }
        let icon_humid = if $text { '' } else if $emoji { '💧 ' } else { " " }

        let hourly_table = ($today.hourly | each {|hour|
            # Format time (e.g., "1200" -> "12:00")
            let t_str = ($hour.time | into string | fill -a r -w 4 -c '0')
            let time_display = $"($t_str | str substring 0..1):($t_str | str substring 2..3)"
            
            # Extract Temp (Note: hourly uses tempF/tempC, not temp_F/temp_C)
            let temp = if $is_us { ($hour.tempF? | default '0') } else { ($hour.tempC? | default '0') }
            let feels = if $is_us { ($hour.FeelsLikeF? | default '0') } else { ($hour.FeelsLikeC? | default '0') }
            
            # Icons
            let weather_code = ($hour.weatherCode? | default '113')
            let weather_desc = ($hour.weatherDesc?.0?.value? | default 'Unknown')
            let weather_icon = weather-icon $weather_code --emoji=$emoji --text=$text
            
            # Wind
            let wind_speed = ($hour | get -o $units.speed_key | default '0')
            let wind_k = ($hour.windspeedKmph? | default '0')
            let beaufort_scale = beaufort-scale $wind_k
            let beaufort_icon = beaufort-icon $beaufort_scale --emoji=$emoji --text=$text
            let wind_dir_str = ($hour.winddir16Point? | default 'N')
            let wind_dir = wind-dir-icon $wind_dir_str --emoji=$emoji --text=$text
            
            let wind_display = $"($beaufort_icon) ($wind_speed)($units.speed_label) ($wind_dir)"
            
            # Precip / Chance
            let precip_val = ($hour | get -o $units.precip_key | default '0.0')
            let chance_rain = ($hour.chanceofrain? | default '0')
            let chance_snow = ($hour.chanceofsnow? | default '0')
            
            let precip_display = if ($chance_snow | into int) > 0 {
                $"($icon_snow)($chance_snow)% / ($precip_val)($units.precip_label)"
            } else {
                $"($icon_rain)($chance_rain)% / ($precip_val)($units.precip_label)"
            }

            let condition_str = if $text { $weather_desc } else { $"($weather_icon) ($weather_desc)" }

            {
                Time: $time_display,
                Condition: $condition_str,
                Temp: (format-temp $temp $units --text=$text),
                Feels: (format-temp $feels $units --text=$text),
                Precip: $precip_display,
                Wind: $wind_display,
                Humidity: $"($icon_humid)(($hour.humidity? | default '0'))%"
            }
        })

        if $raw { return $hourly_table }
        if not $text { print $"(ansi cyan_bold)Hourly Forecast for ($actual_location)(ansi reset)" } else { print $"Hourly Forecast for ($actual_location)" }
        return ($hourly_table | table -i false)
    }

    # Handle Forecast Mode
    if $forecast {
        if $debug { print $"(ansi cyan)ℹ Processing 3-Day Forecast...(ansi reset)" }
        let forecast_table = ($data.weather | each {|day|
            let date = ($day.date | into datetime | format date '%a, %b %d')
            let max_temp = ($day | get $units.forecast_max_key)
            let min_temp = ($day | get $units.forecast_min_key)
            
            # Get noon weather for icon (approximate daily condition)
            let noon = ($day.hourly | where time == '1200' | first | default ($day.hourly | first))
            
            # Extract Wind and Rain
            let wind_speed = ($noon | get -o $units.speed_key | default '0')
            let wind_k = ($noon.windspeedKmph? | default '0')
            let beaufort_scale = beaufort-scale $wind_k
            let beaufort_icon = beaufort-icon $beaufort_scale --emoji=$emoji --text=$text
            
            let wind_dir_str = ($noon.winddir16Point? | default 'N')
            let wind_dir = wind-dir-icon $wind_dir_str --emoji=$emoji --text=$text
            let precip_val = ($noon | get -o $units.precip_key | default '0.0')
            
            let weather_code = ($noon.weatherCode? | default '113')
            let weather_desc = ($noon.weatherDesc?.0?.value? | default 'Unknown')
            let weather_icon = weather-icon $weather_code --emoji=$emoji --text=$text
            
            # Moon for forecast
            let moon_phase = ($day.astronomy.0.moon_phase)
            let moon_illum = ($day.astronomy.0.moon_illumination)
            let moon_icon = moon-icon $moon_phase $moon_illum --emoji=$emoji --text=$text
            
            let condition_str = if $text { $weather_desc } else { $"($weather_icon) ($weather_desc)" }
            
            let wind_display = $"($beaufort_icon) ($wind_speed)($units.speed_label) ($wind_dir)"
            
            {
                Date: $date,
                Condition: $condition_str,
                High: (format-temp $max_temp $units --text=$text),
                Low: (format-temp $min_temp $units --text=$text),
                Rain: $"($precip_val)($units.precip_label)",
                Wind: $wind_display,
                Moon: $"($moon_icon) ($moon_phase)",
                Sunrise: ($day.astronomy.0.sunrise),
                Sunset: ($day.astronomy.0.sunset)
            }
        })
        
        if $raw {
            return $forecast_table
        } else {
            if $text {
                print $"Forecast for ($actual_location)"
            } else {
                print $"(ansi cyan_bold)Forecast for ($actual_location)(ansi reset)"
            }
            return ($forecast_table | table -i false)
        }
    }
    
    # Safe data extraction for Current Weather
    $data.current_condition | first | let current: record
    $data.weather | first | let weather_data: record
    $weather_data.astronomy | first | let astro: record
    unlet $data
    
    # Dynamic extraction using the units schema
    $current | get -o $units.temp_key | default '0' | let temp_val: string
    $current | get -o $units.feels_key | default '0' | let feels_val: string

    # Calculate Beaufort
    $current.windspeedKmph? | default '0' | let wind_k: string
    beaufort-scale $wind_k | let beaufort_scale: int
    beaufort-icon $beaufort_scale --emoji=$emoji --text=$text | let beaufort_icon: string

    # Define icons for metrics
    let icon_wind: string = if $text { $"($beaufort_icon) " } else if $emoji { $"💨 ($beaufort_icon) " } else { $"($beaufort_icon) " }
    let icon_rain: string = if $text { '' } else if $emoji { '☔ ' } else { " " }
    let icon_vis: string = if $text { '' } else if $emoji { '👁 ' } else { " " }
    let icon_press: string = if $text { '' } else if $emoji { '⏲ ' } else { " " }
    let icon_cloud: string = if $text { '' } else if $emoji { '☁ ' } else { " " }
    let icon_humid: string = if $text { '' } else if $emoji { '💧 ' } else { " " }
    let icon_uv: string = if $text { '' } else if $emoji { '☀ ' } else { " " }

    # Wind, precipitation, visibility, pressure
    $current | get -o $units.speed_key | default '0' | let wind_speed: string
    $current.winddir16Point? | default 'N' | let wind_dir_str: string
    wind-dir-icon $wind_dir_str --emoji=$emoji --text=$text | let wind_dir: string
    
    $"($icon_wind)($wind_speed)($units.speed_label) ($wind_dir)" | let wind: string
    $"($icon_rain)(($current | get -o $units.precip_key | default '0.0'))($units.precip_label)" | let precip: string
    $"($icon_vis)(($current | get -o $units.vis_key | default '0'))($units.vis_label)" | let vis: string
    $"($icon_press)(($current | get -o $units.press_key | default '0'))($units.press_label)" | let pressure: string

    # UV Index & Sky Styling
    $current.uvIndex? | default '0' | into int | let uv: int
    
    # UV color based on exposure level
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
    weather-icon $weather_code --emoji=$emoji --text=$text | let weather_icon: string
    
    # SEVERE WEATHER DETECTION
    # wttr.in doesn't provide NWS alerts, but we can flag severe codes:
    # 227 (Blowing snow), 230 (Blizzard), 386/389/392/395 (Thunderstorms)
    let severe_codes: list<string> = ['227' '230' '386' '389' '392' '395']
    let is_severe: bool = ($weather_code in $severe_codes)
    
    let alert_icon: string = if $is_severe {
        if $text { ' [SEVERE]' } else if $emoji { ' ⚠️' } else { ' ' } # nf-weather-storm_warning
    } else { '' }

    # Get weather description for additional context
    $current.weatherDesc?.0?.value? | default 'Unknown' | let weather_desc: string
    
    # ENHANCED MOON PHASE EMOJI
    # More precise matching with moon illumination
    $astro.moon_phase? | default 'Unknown' | str downcase | let moon_phase: string
    $astro.moon_illumination? | default '0' | let moon_illum: string
    
    moon-icon $moon_phase $moon_illum --emoji=$emoji --text=$text | let moon_icon: string
    
    let moon_display: string = if $text { 'Moon: ' } else { $"($moon_icon) " }
    let sunrise_display: string = if $text { 'Sunrise: ' } else if $emoji { '🌅 ' } else { " " } # nf-weather-sunrise
    let sunset_display: string = if $text { 'Sunset: ' } else if $emoji { '🌇 ' } else { " " } # nf-weather-sunset

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
    let ansi_reset: string = if $text { '' } else { (ansi reset) }
    let ansi_grey: string = if $text { '' } else { (ansi grey) }
    let ansi_uv: string = if $text { '' } else { (ansi $uv_color) }

    format-temp $temp_val $units --text=$text | let temp_display: string

    let condition_display: string = if $text { $"($weather_desc)($alert_icon)" } else { $"($weather_icon) ($weather_desc)($alert_icon)" }

    let location_display: string = if $text or $raw {
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
        Rain: $precip,
        Humidity: $"($icon_humid)(($current.humidity? | default '0'))%",
        Wind: $wind,
        Pressure: $pressure,
        Visibility: $vis,
        UV: $"($icon_uv)($ansi_uv)($uv)($ansi_reset)",
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
    
    if $oneline {
        let oneline_emoji: string = if $text { '' } else { $"($weather_icon) " }
        return $"($actual_location): ($oneline_emoji)($temp_val)($units.temp_label) - ($weather_desc)"
    }
    
    if $raw {
        $output
    } else {
        $output | table -i false
    }
}
