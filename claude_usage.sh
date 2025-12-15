#!/bin/bash

# Load API key (tries multiple methods in order of security)
# Method 1: macOS Keychain (most secure)
ADMIN_KEY=$(security find-generic-password -a "$USER" -s "claude_admin_key" -w 2>/dev/null)

# Method 2: Environment variable (works in terminal)
if [ -z "$ADMIN_KEY" ] && [ -n "$CLAUDE_ADMIN_KEY" ]; then
    ADMIN_KEY="$CLAUDE_ADMIN_KEY"
fi

# Method 3: Config file (works for GUI apps)
if [ -z "$ADMIN_KEY" ] && [ -f "$HOME/.claude_admin_key" ]; then
    ADMIN_KEY=$(cat "$HOME/.claude_admin_key" | tr -d '\n' | tr -d ' ')
fi

# Method 4: Alternative config location
if [ -z "$ADMIN_KEY" ] && [ -f "$HOME/.config/claude/admin_key" ]; then
    ADMIN_KEY=$(cat "$HOME/.config/claude/admin_key" | tr -d '\n' | tr -d ' ')
fi

# If still not found, show helpful error
if [ -z "$ADMIN_KEY" ]; then
    echo "Error: API key not found" >&2
    echo "" >&2
    echo "Option 1: macOS Keychain (Most Secure)" >&2
    echo "  security add-generic-password -a \"\$USER\" -s \"claude_admin_key\" -w \"your-key\"" >&2
    echo "" >&2
    echo "Option 2: Environment Variable" >&2
    echo "  export CLAUDE_ADMIN_KEY='your-key'" >&2
    echo "  (Add to ~/.zshrc or ~/.bash_profile to make it permanent)" >&2
    echo "" >&2
    echo "Option 3: Config File" >&2
    echo "  echo 'your-key' > ~/.claude_admin_key" >&2
    echo "  chmod 600 ~/.claude_admin_key" >&2
    exit 1
fi

# Calculate billing period: start of current month to now
# Note: Anthropic bills monthly by calendar month. This script shows current month-to-date.
START_DATE=$(date +"%Y-%m-01")
END_DATE=$(date +"%Y-%m-%d")

# Convert to RFC 3339 timestamps (required by Anthropic API)
# Get first day of current month at 00:00:00 UTC (macOS date format)
START_TIME=$(date -u -j -f "%Y-%m-%d" "$START_DATE" "+%Y-%m-%dT00:00:00Z")
# Current time in UTC
END_TIME=$(date -u "+%Y-%m-%dT%H:%M:%SZ")

# Function to show a progress spinner
spinner() {
    local spinner="⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏"
    local i=0
    while [ -f "/tmp/claude_spinner_$$" ]; do
        i=$(((i + 1) % 10))
        printf "\r  %s Fetching data..." "${spinner:$i:1}" >&2
        sleep 0.1
    done
    printf "\r  ✓ Done                    \n" >&2
}

# Cleanup function
cleanup() {
    rm -f "/tmp/claude_spinner_$$"
}

# Trap to ensure cleanup on exit
trap cleanup EXIT

# Start spinner in background
start_spinner() {
    touch "/tmp/claude_spinner_$$"
    spinner &
    SPINNER_PID=$!
}

# Stop spinner
stop_spinner() {
    rm -f "/tmp/claude_spinner_$$"
    wait $SPINNER_PID 2>/dev/null
}

# Function to fetch all paginated data from Usage API
fetch_usage_data() {
    local url="$1"
    local all_data="[]"
    local page_cursor=""
    
    while true; do
        local params="starting_at=$START_TIME&ending_at=$END_TIME&bucket_width=1d"
        if [ -n "$page_cursor" ]; then
            params="$params&page=$page_cursor"
        fi
        
        local response=$(curl -s \
            "$url?$params" \
            -H "x-api-key: $ADMIN_KEY" \
            -H "anthropic-version: 2023-06-01")
        
        # Check if response is valid JSON
        if ! echo "$response" | jq . >/dev/null 2>&1; then
            echo "[]"
            return 1
        fi
        
        # Extract data array and merge with existing data
        local page_data=$(echo "$response" | jq '.data // []')
        all_data=$(echo "$all_data $page_data" | jq -s 'add')
        
        # Check for next page
        page_cursor=$(echo "$response" | jq -r '.next_page // empty')
        if [ -z "$page_cursor" ] || [ "$page_cursor" = "null" ]; then
            break
        fi
    done
    
    echo "$all_data"
}

# Function to fetch all paginated data from Costs API
fetch_costs_data() {
    local url="https://api.anthropic.com/v1/organizations/cost_report"
    local all_data="[]"
    local page_cursor=""
    
    while true; do
        local params="starting_at=$START_TIME&ending_at=$END_TIME&bucket_width=1d"
        if [ -n "$page_cursor" ]; then
            params="$params&page=$page_cursor"
        fi
        
        local response=$(curl -s \
            "$url?$params" \
            -H "x-api-key: $ADMIN_KEY" \
            -H "anthropic-version: 2023-06-01")
        
        # Check if response is valid JSON
        if ! echo "$response" | jq . >/dev/null 2>&1; then
            echo "[]"
            return 1
        fi
        
        # Extract data array and merge with existing data
        local page_data=$(echo "$response" | jq '.data // []')
        all_data=$(echo "$all_data $page_data" | jq -s 'add')
        
        # Check for next page
        page_cursor=$(echo "$response" | jq -r '.next_page // empty')
        if [ -z "$page_cursor" ] || [ "$page_cursor" = "null" ]; then
            break
        fi
    done
    
    echo "$all_data"
}

# Start spinner
start_spinner

# Fetch usage data
USAGE_DATA=$(fetch_usage_data "https://api.anthropic.com/v1/organizations/usage_report/messages")

# Fetch costs data
COSTS_DATA=$(fetch_costs_data)

# Stop spinner
stop_spinner

if [ -z "$USAGE_DATA" ] || [ "$USAGE_DATA" = "[]" ]; then
    echo "Claude Usage & Costs"
    echo "Unavailable"
    exit 0
fi

# Aggregate usage statistics
# Anthropic tracks: uncached_input_tokens, cache_read_input_tokens, output_tokens
TOTAL_UNCACHED_INPUT=$(echo "$USAGE_DATA" | jq '[.[].results[]?.uncached_input_tokens // 0] | add // 0')
TOTAL_CACHE_READ=$(echo "$USAGE_DATA" | jq '[.[].results[]?.cache_read_input_tokens // 0] | add // 0')
TOTAL_INPUT_TOKENS=$(echo "$TOTAL_UNCACHED_INPUT $TOTAL_CACHE_READ" | awk '{print $1 + $2}')
TOTAL_OUTPUT_TOKENS=$(echo "$USAGE_DATA" | jq '[.[].results[]?.output_tokens // 0] | add // 0')
TOTAL_TOKENS=$(echo "$TOTAL_INPUT_TOKENS $TOTAL_OUTPUT_TOKENS" | awk '{print $1 + $2}')

# Aggregate costs
# Anthropic returns costs as decimal strings in cents (e.g., "123.45" = $1.2345)
# We need to sum all amounts and convert from cents to dollars
TOTAL_COST_CENTS=$(echo "$COSTS_DATA" | jq '[.[].results[]?.amount // "0" | tonumber] | add // 0')
TOTAL_COST=$(echo "scale=2; $TOTAL_COST_CENTS / 100" | bc)

# Format output
echo "Claude Usage & Costs"
echo "Period: $START_DATE to $END_DATE"
echo ""
echo "Usage:"
echo "  Total Tokens: $(printf "%'d" $TOTAL_TOKENS)"
echo "    Input:  $(printf "%'d" $TOTAL_INPUT_TOKENS)"
echo "      Uncached: $(printf "%'d" $TOTAL_UNCACHED_INPUT)"
echo "      Cache Read: $(printf "%'d" $TOTAL_CACHE_READ)"
echo "    Output: $(printf "%'d" $TOTAL_OUTPUT_TOKENS)"
echo ""
echo "Costs:"
echo "  Total: \$$(printf "%.2f" $TOTAL_COST)"
echo ""
