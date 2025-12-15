# OpenAI Usage & Costs Script

A bash script to fetch and display your OpenAI API usage statistics and costs for the current billing period.

## What It Does

This script queries the OpenAI Usage API and Costs API to provide you with:

- **Usage Statistics:**
  - Total tokens (input and output breakdown)
  - Total API requests
  - Data from both completions and embeddings endpoints

- **Cost Information:**
  - Total spend for the current month-to-date period
  - Costs broken down by project and line items

The script automatically calculates the billing period from the first day of the current month to today, matching OpenAI's calendar month billing cycle.

## Prerequisites

- **macOS** (uses macOS-specific `date` commands)
- **curl** (for API requests)
- **jq** (for JSON parsing)
- **OpenAI Admin API Key** (not a regular API key)

### Installing jq

If you don't have `jq` installed:

```bash
# Using Homebrew
brew install jq
```

## Setup

### 1. Get Your Admin API Key

You need an **Admin API Key**, not a regular API key. Admin keys have the `api.usage.read` scope required to access usage and cost data.

1. Go to [OpenAI Platform Settings](https://platform.openai.com/settings/organization/admin-keys)
2. Click "Create new key"
3. Name it (e.g., "Usage Script")
4. Copy the key (it starts with `sk-admin-...`)

⚠️ **Important:** Admin keys have broader permissions than regular API keys. Keep them secure and never commit them to version control.

### 2. Set the API Key

The script supports multiple methods to load your admin key, tried in this order:

1. **macOS Keychain** (most secure)
2. **Environment Variable** (works in terminal)
3. **Config File** (works for GUI apps)

#### Option A: macOS Keychain (Most Secure - Recommended)

Store your key in macOS Keychain:

```bash
security add-generic-password -a "$USER" -s "openai_admin_key" -w "sk-admin-..."
```

**Why this method?**
- ✅ Most secure - encrypted by macOS Keychain
- ✅ No files to manage
- ✅ System-managed security

#### Option B: Environment Variable

Add your admin key to your shell configuration file:

**For zsh (default on macOS):**
```bash
echo 'export OPENAI_ADMIN_KEY="sk-admin-..."' >> ~/.zshrc
source ~/.zshrc
```

**For bash:**
```bash
echo 'export OPENAI_ADMIN_KEY="sk-admin-..."' >> ~/.bash_profile
source ~/.bash_profile
```

**For a single session (temporary):**
```bash
export OPENAI_ADMIN_KEY="sk-admin-..."
```

#### Option C: Config File

Create a secure config file:

```bash
echo 'sk-admin-...' > ~/.openai_admin_key
chmod 600 ~/.openai_admin_key
```

### 3. Make the Script Executable

```bash
chmod +x openai_usage.sh
```

## Usage

Simply run the script:

```bash
./openai_usage.sh
```

### Example Output

```
Fetching usage data...
  Fetching completions.. done
  Fetching embeddings.. done
Fetching costs data...
  Fetching costs.. done

OpenAI Usage & Costs
Period: 2025-12-01 to 2025-12-14

Usage:
  Total Tokens: 2,112,737
    Input:  2,067,286
    Output: 45,451
  Total Requests: 961

Costs:
  Total: $7.41
```

## How It Works

1. **Calculates Billing Period:** Automatically determines the start (first day of current month) and end (today) dates
2. **Fetches Usage Data:** 
   - Calls `/v1/organization/usage/completions` for chat completions usage
   - Calls `/v1/organization/usage/embeddings` for embeddings usage
   - Handles pagination automatically
3. **Fetches Cost Data:**
   - Calls `/v1/organization/costs` for cost breakdown
   - Aggregates costs across all projects and line items
4. **Displays Results:** Formats and displays the aggregated statistics

## Notes

- **Billing Period:** OpenAI bills by calendar month. Enterprise customers are billed at month-end, while pay-as-you-go customers are invoiced for the previous month's usage.
- **Data Accuracy:** Small discrepancies (usually <$1) between the script and dashboard are normal due to:
  - Timing differences in data aggregation
  - Additional services not yet included (images, audio, etc.)
  - Rounding differences
- **Credit Balance:** Credit balance is not available via the Admin API. Check your dashboard at [platform.openai.com/usage](https://platform.openai.com/usage) for credit information.
- **Performance:** The script fetches data sequentially with progress indicators. Execution time depends on the number of pages returned by the API.

## Troubleshooting

### "OPENAI_ADMIN_KEY environment variable not set"

Make sure you've:
1. Exported the environment variable in your shell config file
2. Reloaded your shell (`source ~/.zshrc`) or opened a new terminal
3. Verified the variable is set: `echo $OPENAI_ADMIN_KEY`

### "Unavailable" or empty results

- Verify your admin key is valid and has the `api.usage.read` scope
- Check that you have usage data for the current month
- Ensure you have an active OpenAI account with API usage

### Script is slow

The script makes multiple API calls and handles pagination. Progress dots indicate it's working. If it's consistently slow, check your network connection.

## Security

- **Never commit your admin key to version control**
- **Use environment variables** (as shown in setup) rather than hardcoding keys
- **Rotate your admin keys** periodically for security
- **Limit key scope** - only grant the minimum permissions needed

## API Reference

This script uses the OpenAI Usage API:
- [Usage API Documentation](https://platform.openai.com/docs/api-reference/usage)
- [Usage API Cookbook Example](https://cookbook.openai.com/examples/completions_usage_api)

