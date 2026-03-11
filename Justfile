# weather.nu development tasks

# List available commands
default:
    @just --list

# Format all .nu files with nufmt
fmt:
    nu -c "nufmt weather.nu"
    nu -c "nufmt meteo/meteo.nu"

# Lint all .nu files with nulint
lint:
    nu -c "nulint weather.nu"
    nu -c "nulint meteo/meteo.nu"

# Format and lint (fix what can be fixed, report the rest)
fix: fmt lint

# Run lint and format check without modifying files
check:
    -nu -c "nufmt --dry-run weather.nu"
    -nu -c "nufmt --dry-run meteo/meteo.nu"
    -nu -c "nulint weather.nu"
    -nu -c "nulint meteo/meteo.nu"

# Run built-in test mode for both scripts
test:
    nu -c "use weather.nu; weather --test"
    nu -c "use meteo/meteo.nu; meteo --test"

# Run test mode in plain text for clean output
test-text:
    nu -c "use weather.nu; weather --test --text"
    nu -c "use meteo/meteo.nu; meteo --test --text"

# Clear all weather caches
clear-cache:
    nu -c "use weather.nu; weather --clear-cache"
    nu -c "use meteo/meteo.nu; meteo --clear-cache"

# Run both scripts against a real location to sanity-check live data
smoke city="London":
    nu -c "use weather.nu; weather '{{city}}'"
    nu -c "use meteo/meteo.nu; meteo '{{city}}'"
