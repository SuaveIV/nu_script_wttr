# weather.nu development tasks

# List available commands
default:
    @just --list

# Lint all .nu files with nu-lint (replaces fmt for this project)
lint:
    nu-lint --fix weather.nu
    nu-lint --fix meteo/meteo.nu

# Run linting with auto-fixes enabled
fix: lint

# Run lint check without modifying files
check:
    -nu-lint --format compact weather.nu
    -nu-lint --format compact meteo/meteo.nu

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
