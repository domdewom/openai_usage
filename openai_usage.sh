#!/bin/bash

# Load API key (tries multiple methods in order of security)
# Method 1: macOS Keychain (most secure)
ADMIN_KEY=$(security find-generic-password -a "$USER" -s "openai_admin_key" -w 2>/dev/null)

# Method 2: Environment variable (works in terminal)
if [ -z "$ADMIN_KEY" ] && [ -n "$OPENAI_ADMIN_KEY" ]; then
    ADMIN_KEY="$OPENAI_ADMIN_KEY"
fi

# Method 3: Config file (works for GUI apps)
if [ -z "$ADMIN_KEY" ] && [ -f "$HOME/.openai_admin_key" ]; then
    ADMIN_KEY=$(cat "$HOME/.openai_admin_key" | tr -d '\n' | tr -d ' ')
fi

# Method 4: Alternative config location
if [ -z "$ADMIN_KEY" ] && [ -f "$HOME/.config/openai/admin_key" ]; then
    ADMIN_KEY=$(cat "$HOME/.config/openai/admin_key" | tr -d '\n' | tr -d ' ')
fi

# If still not found, show helpful error
if [ -z "$ADMIN_KEY" ]; then
    echo "Error: API key not found" >&2
    echo "" >&2
    echo "Option 1: macOS Keychain (Most Secure)" >&2
    echo "  security add-generic-password -a \"\$USER\" -s \"openai_admin_key\" -w \"your-key\"" >&2
    echo "" >&2
    echo "Option 2: Environment Variable" >&2
    echo "  export OPENAI_ADMIN_KEY='your-key'" >&2
    echo "  (Add to ~/.zshrc or ~/.bash_profile to make it permanent)" >&2
    echo "" >&2
    echo "Option 3: Config File" >&2
    echo "  echo 'your-key' > ~/.openai_admin_key" >&2
    echo "  chmod 600 ~/.openai_admin_key" >&2
    exit 1
fi

# Calculate billing period: start of current month to now
# Note: OpenAI bills monthly by calendar month. For Enterprise customers, 
# invoices are issued at the end of each calendar month. For pay-as-you-go,
# invoices cover the previous calendar month. This script shows current month-to-date.
START_DATE=$(date +"%Y-%m-01")
END_DATE=$(date +"%Y-%m-%d")

# Convert to Unix timestamps (macOS date format)
# Get first day of current month at 00:00:00
START_TIME=$(date -j -f "%Y-%m-%d" "$START_DATE" "+%s")
END_TIME=$(date +%s)

# Function to show a progress spinner
spinner() {
    local spinner="⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏"
    local i=0
    while [ -f "/tmp/openai_spinner_$$" ]; do
        i=$(((i + 1) % 10))
        printf "\r  %s Fetching data..." "${spinner:$i:1}" >&2
        sleep 0.1
    done
    printf "\r  ✓ Done                    \n" >&2
}

# Cleanup function
cleanup() {
    rm -f "/tmp/openai_spinner_$$"
}

# Trap to ensure cleanup on exit
trap cleanup EXIT

# Start spinner in background
start_spinner() {
    touch "/tmp/openai_spinner_$$"
    spinner &
    SPINNER_PID=$!
}

# Stop spinner
stop_spinner() {
    rm -f "/tmp/openai_spinner_$$"
    wait $SPINNER_PID 2>/dev/null
}

# Function to fetch all paginated data from Usage API
fetch_usage_data() {
    local url="$1"
    local api_name="$2"
    local all_data="[]"
    local page_cursor=""
    
    while true; do
        local params="start_time=$START_TIME&end_time=$END_TIME&bucket_width=1d"
        if [ -n "$page_cursor" ]; then
            params="$params&page=$page_cursor"
        fi
        
        local response=$(curl -s \
            "$url?$params" \
            -H "Authorization: Bearer $ADMIN_KEY")
        
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
    local url="https://api.openai.com/v1/organization/costs"
    local all_data="[]"
    local page_cursor=""
    
    while true; do
        local params="start_time=$START_TIME&end_time=$END_TIME"
        if [ -n "$page_cursor" ]; then
            params="$params&page=$page_cursor"
        fi
        
        local response=$(curl -s \
            "$url?$params" \
            -H "Authorization: Bearer $ADMIN_KEY")
        
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

# Fetch completions usage data
COMPLETIONS_DATA=$(fetch_usage_data "https://api.openai.com/v1/organization/usage/completions" "completions")

# Fetch embeddings usage data (to match dashboard totals)
EMBEDDINGS_DATA=$(fetch_usage_data "https://api.openai.com/v1/organization/usage/embeddings" "embeddings")

# Combine usage data
USAGE_DATA=$(echo "$COMPLETIONS_DATA $EMBEDDINGS_DATA" | jq -s 'add')

# Fetch costs data
COSTS_DATA=$(fetch_costs_data)

# Stop spinner
stop_spinner

if [ -z "$USAGE_DATA" ] || [ "$USAGE_DATA" = "[]" ]; then
    echo "OpenAI Usage & Costs"
    echo "Unavailable"
    exit 0
fi

# Aggregate usage statistics (completions + embeddings)
TOTAL_INPUT_TOKENS=$(echo "$USAGE_DATA" | jq '[.[].results[]?.input_tokens // 0] | add // 0')
TOTAL_OUTPUT_TOKENS=$(echo "$USAGE_DATA" | jq '[.[].results[]?.output_tokens // 0] | add // 0')
TOTAL_TOKENS=$(echo "$TOTAL_INPUT_TOKENS $TOTAL_OUTPUT_TOKENS" | awk '{print $1 + $2}')
TOTAL_REQUESTS=$(echo "$USAGE_DATA" | jq '[.[].results[]?.num_model_requests // 0] | add // 0')

# Aggregate costs (convert strings to numbers if needed)
TOTAL_COST=$(echo "$COSTS_DATA" | jq '[.[].results[]?.amount.value // 0 | tonumber] | add // 0')

# Format output
echo "OpenAI Usage & Costs"
echo "Period: $START_DATE to $END_DATE"
echo ""
echo "Usage:"
echo "  Total Tokens: $(printf "%'d" $TOTAL_TOKENS)"
echo "    Input:  $(printf "%'d" $TOTAL_INPUT_TOKENS)"
echo "    Output: $(printf "%'d" $TOTAL_OUTPUT_TOKENS)"
echo "  Total Requests: $(printf "%'d" $TOTAL_REQUESTS)"
echo ""
echo "Costs:"
echo "  Total: \$$(printf "%.2f" $TOTAL_COST)"
echo ""

