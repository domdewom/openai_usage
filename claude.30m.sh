#!/bin/bash

# SwiftBar Plugin Metadata
# <swiftbar.title>Claude Usage & Costs</swiftbar.title>
# <swiftbar.version>1.0</swiftbar.version>
# <swiftbar.author>domdewom</swiftbar.author>
# <swiftbar.desc>Monitor Claude AI API usage and costs in your menu bar</swiftbar.desc>
# <swiftbar.dependencies>curl,jq,bc</swiftbar.dependencies>
# <swiftbar.abouturl>https://platform.claude.com/usage</swiftbar.abouturl>

# Load API key (tries multiple methods in order of security)
# Method 1: macOS Keychain (most secure)
ADMIN_KEY=$(security find-generic-password -a "$USER" -s "claude_admin_key" -w 2>/dev/null)

# Method 2: Environment variable (works in terminal)
if [ -z "$ADMIN_KEY" ] && [ -n "$CLAUDE_ADMIN_KEY" ]; then
    ADMIN_KEY="$CLAUDE_ADMIN_KEY"
fi

# Method 3: Config file (works for GUI apps like SwiftBar)
if [ -z "$ADMIN_KEY" ] && [ -f "$HOME/.claude_admin_key" ]; then
    ADMIN_KEY=$(cat "$HOME/.claude_admin_key" | tr -d '\n' | tr -d ' ')
fi

# Method 4: Alternative config location
if [ -z "$ADMIN_KEY" ] && [ -f "$HOME/.config/claude/admin_key" ]; then
    ADMIN_KEY=$(cat "$HOME/.config/claude/admin_key" | tr -d '\n' | tr -d ' ')
fi

# If still not found, show helpful error
if [ -z "$ADMIN_KEY" ]; then
    echo "⚠️ Claude | color=red"
    echo "---"
    echo "Error: API key not found | color=red"
    echo "---"
    echo "Option 1: macOS Keychain (Most Secure) | font=Menlo-Bold"
    echo "security add-generic-password -a \"\$USER\" -s \"claude_admin_key\" -w \"your-key\" | font=Menlo size=9 color=#888888"
    echo "---"
    echo "Option 2: Config File | font=Menlo-Bold"
    echo "echo 'your-key' > ~/.claude_admin_key | font=Menlo size=9 color=#888888"
    echo "chmod 600 ~/.claude_admin_key | font=Menlo size=9 color=#888888"
    echo "---"
    echo "Option 3: Environment Variable | font=Menlo-Bold"
    echo "export CLAUDE_ADMIN_KEY='your-key' | font=Menlo size=9 color=#888888"
    echo "---"
    echo "Then refresh this plugin"
    exit 1
fi

# Calculate billing period: start of current month to now
START_DATE=$(date +"%Y-%m-01")
END_DATE=$(date +"%Y-%m-%d")

# Convert to RFC 3339 timestamps (required by Anthropic API)
# Get first day of current month at 00:00:00 UTC (macOS date format)
START_TIME=$(date -u -j -f "%Y-%m-%d" "$START_DATE" "+%Y-%m-%dT00:00:00Z")
# Current time in UTC
END_TIME=$(date -u "+%Y-%m-%dT%H:%M:%SZ")

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

# Fetch usage data
USAGE_DATA=$(fetch_usage_data "https://api.anthropic.com/v1/organizations/usage_report/messages")

# Fetch costs data
COSTS_DATA=$(fetch_costs_data)

# Check for errors
if [ -z "$USAGE_DATA" ] || [ "$USAGE_DATA" = "[]" ]; then
    echo "⚠️ Claude | color=orange"
    echo "---"
    echo "No usage data available | color=orange"
    echo "Period: $START_DATE to $END_DATE"
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

# Format numbers for display
COST_FORMATTED=$(printf "%.2f" $TOTAL_COST)
TOKENS_FORMATTED=$(printf "%'d" $TOTAL_TOKENS)
INPUT_FORMATTED=$(printf "%'d" $TOTAL_INPUT_TOKENS)
OUTPUT_FORMATTED=$(printf "%'d" $TOTAL_OUTPUT_TOKENS)
UNCACHED_FORMATTED=$(printf "%'d" $TOTAL_UNCACHED_INPUT)
CACHE_READ_FORMATTED=$(printf "%'d" $TOTAL_CACHE_READ)

# Determine color based on cost (optional: you can adjust thresholds)
if (( $(echo "$TOTAL_COST > 25" | bc -l) )); then
    COST_COLOR="red"
elif (( $(echo "$TOTAL_COST > 10" | bc -l) )); then
    COST_COLOR="orange"
else
    COST_COLOR="green"
fi

# Menu bar title (first line before ---)
# Claude logo (simplified - you can replace with actual logo)
echo "\$$COST_FORMATTED | color=$COST_COLOR"

# Dropdown menu (after ---)
echo "---"
echo "Claude Usage & Costs | font=Monaco-Bold size=13 color=black"
echo "---"
echo "Period: $START_DATE to $END_DATE | font=Monaco size=12 color=black"
echo "---"
echo "Usage | font=Monaco-Bold size=13 color=black"
echo "Total Tokens: $TOKENS_FORMATTED | font=Monaco size=12 color=black"
echo "  Input:  $INPUT_FORMATTED | font=Monaco size=11 color=black"
echo "    Uncached: $UNCACHED_FORMATTED | font=Monaco size=10 color=#666666"
echo "    Cache Read: $CACHE_READ_FORMATTED | font=Monaco size=10 color=#666666"
echo "  Output: $OUTPUT_FORMATTED | font=Monaco size=11 color=black"
echo "---"
echo "Costs | font=Monaco-Bold size=13 color=black"
echo "\$$COST_FORMATTED | color=$COST_COLOR font=Monaco-Bold size=14"
echo "---"
echo "Open Dashboard | href=https://platform.claude.com/usage font=Monaco size=11 color=black"
echo "Refresh | refresh=true font=Monaco size=11 color=black"
