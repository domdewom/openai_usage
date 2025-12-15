# OpenAI Usage & Costs Scripts

Bash scripts to fetch and display your OpenAI API usage statistics and costs. Available as both a standalone terminal script and a menu bar plugin compatible with both **xbar** and **SwiftBar**.

## What's Included

- **`openai_usage.sh`** - Standalone script for terminal use
- **`openai.30m.sh`** - Menu bar plugin for xbar/SwiftBar (auto-refreshes every 30 minutes)

Both scripts provide:
- **Usage Statistics:**
  - Total tokens (input and output breakdown)
  - Total API requests
  - Data from both completions and embeddings endpoints

- **Cost Information:**
  - Total spend for the current month-to-date period
  - Costs broken down by project and line items

## Prerequisites

- **macOS** (uses macOS-specific `date` commands)
- **curl** (for API requests, usually pre-installed)
- **jq** (for JSON parsing)
- **bc** (for calculations, usually pre-installed)
- **OpenAI Admin API Key** (not a regular API key)

### Installing jq

If you don't have `jq` installed:

```bash
# Using Homebrew
brew install jq
```

### Installing Menu Bar App (xbar or SwiftBar)

The plugin works with both **xbar** and **SwiftBar** (SwiftBar is a fork/evolution of xbar with additional features).

#### Option A: SwiftBar (Recommended)

1. Download SwiftBar from the [releases page](https://github.com/swiftbar/SwiftBar/releases)
2. Move SwiftBar.app to your Applications folder
3. Launch SwiftBar and grant necessary permissions:
   - **Accessibility Permission:** SwiftBar needs "Control the computer using accessibility features" permission
   - Go to **System Settings → Privacy & Security → Accessibility**
   - Enable SwiftBar in the list
   - Restart SwiftBar after granting permission

#### Option B: xbar

1. Download xbar from [xbarapp.com](https://xbarapp.com)
2. Install and launch xbar
3. The plugin will work with xbar's standard plugin format

## Setup

### 1. Get Your Admin API Key

You need an **Admin API Key**, not a regular API key. Admin keys have the `api.usage.read` scope required to access usage and cost data.

1. Go to [OpenAI Platform Settings](https://platform.openai.com/settings/organization/admin-keys)
2. Click "Create new key"
3. Name it (e.g., "Usage Script" or "SwiftBar Plugin")
4. Copy the key (it starts with `sk-admin-...`)

⚠️ **Important:** Admin keys have broader permissions than regular API keys. Keep them secure and never commit them to version control.

### 2. Set the API Key

The scripts support multiple methods to load your admin key, tried in this order:

1. **macOS Keychain** (most secure, recommended)
2. **Environment Variable** (works in terminal)
3. **Config File** (works for GUI apps like SwiftBar)

#### Option A: macOS Keychain (Most Secure - Recommended)

Store your key in macOS Keychain:

```bash
security add-generic-password -a "$USER" -s "openai_admin_key" -w "sk-admin-..."
```

**Why this method?**
- ✅ Most secure - encrypted by macOS Keychain
- ✅ Works with GUI apps like SwiftBar
- ✅ No files to manage
- ✅ System-managed security

**To update or remove the key:**
```bash
# Update the key
security add-generic-password -a "$USER" -s "openai_admin_key" -w "new-key" -U

# Remove the key
security delete-generic-password -a "$USER" -s "openai_admin_key"
```

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

**Note for SwiftBar:** After setting the environment variable, you'll need to restart SwiftBar completely (quit and relaunch) or restart your Mac to ensure the variable is available system-wide.

#### Option C: Config File

Create a secure config file:

```bash
echo 'sk-admin-...' > ~/.openai_admin_key
chmod 600 ~/.openai_admin_key
```

**Why this method?** GUI apps on macOS don't inherit environment variables from shell config files. Using a config file ensures SwiftBar can always access your key.

### 3. Make Scripts Executable

```bash
chmod +x openai_usage.sh
chmod +x openai.30m.sh
```

## Usage

### Standalone Script (`openai_usage.sh`)

Simply run the script:

```bash
./openai_usage.sh
```

#### Example Output

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

### Menu Bar Plugin (`openai.30m.sh`)

The plugin is compatible with both **xbar** and **SwiftBar**. It includes metadata for both platforms.

#### Installation

**For SwiftBar:**
1. **Find SwiftBar's Plugin Directory:**
   - Open SwiftBar
   - Go to Preferences → General
   - Note the "Plugin Directory" path (usually `~/SwiftBarPlugins/`)

2. **Copy the Plugin:**
   ```bash
   # Create plugin directory if it doesn't exist
   mkdir -p ~/SwiftBarPlugins
   
   # Copy the plugin file
   cp openai.30m.sh ~/SwiftBarPlugins/
   
   # Make sure it's executable
   chmod +x ~/SwiftBarPlugins/openai.30m.sh
   ```

3. **Refresh SwiftBar:**
   - SwiftBar should automatically detect the new plugin
   - If not, click the SwiftBar icon in your menu bar and select "Refresh All"

**For xbar:**
1. **Find xbar's Plugin Directory:**
   - Open xbar
   - Go to Preferences → Plugins
   - Note the plugin directory path (usually `~/Library/Application Support/xbar/plugins/`)

2. **Copy the Plugin:**
   ```bash
   # Copy the plugin file
   cp openai.30m.sh ~/Library/Application\ Support/xbar/plugins/
   
   # Make sure it's executable
   chmod +x ~/Library/Application\ Support/xbar/plugins/openai.30m.sh
   ```

3. **Refresh xbar:**
   - xbar should automatically detect the new plugin
   - If not, click the xbar icon and select "Refresh All"

#### Usage

Once installed, the plugin will:

- **Display in Menu Bar:** Shows 🤑 emoji followed by your current month-to-date cost
- **Color Coding:** 
  - Green: Cost < $10
  - Orange: Cost $10-$25
  - Red: Cost > $25
- **Click to View Details:** Click the menu bar item to see:
  - Billing period
  - Detailed cost breakdown
  - Token usage statistics
  - Total requests
  - Quick actions (open dashboard, refresh)

#### Menu Bar Display

```
🤑 $7.55
```

#### Dropdown Menu

```
OpenAI API Usage & Costs
---
Period: 2025-12-01 to 2025-12-14
---
Usage
Total Tokens: 2,112,737
  Input:  2,067,286
  Output: 45,451
Total Requests: 961
---
Costs
$7.55
---
Open Dashboard
Refresh
```

#### Refresh Schedule

The plugin refreshes automatically every **30 minutes** (as indicated by the `.30m` in the filename). You can:

- **Change Refresh Interval:** Rename the file to change the interval:
  - `openai.5m.sh` = every 5 minutes
  - `openai.1h.sh` = every hour
  - `openai.1d.sh` = once per day
- **Manual Refresh:** Click "Refresh" in the dropdown menu
- **Custom Schedule:** Edit the plugin file and add a cron schedule in metadata:
  ```bash
  # <swiftbar.schedule>*/30 * * * *</swiftbar.schedule>
  ```

## Claude Scripts

This repository also includes Claude usage scripts (`claude_usage.sh` and `claude.30m.sh`) that work similarly to the OpenAI scripts.

⚠️ **Note:** Claude Admin API keys are only available to enterprise/organization accounts, not individual users. If you're an individual user, you won't be able to access the Admin API and these scripts won't work for you.

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

## Troubleshooting

### "API key not found"

**If using Keychain method (recommended):**
1. Verify the key exists: `security find-generic-password -a "$USER" -s "openai_admin_key"`
2. If it doesn't exist, add it: `security add-generic-password -a "$USER" -s "openai_admin_key" -w "your-key"`
3. Check for typos in the service name: `openai_admin_key` (must match exactly)

**If using config file method:**
1. Verify the file exists: `ls -la ~/.openai_admin_key`
2. Check file permissions: `chmod 600 ~/.openai_admin_key`
3. Verify the key is in the file: `cat ~/.openai_admin_key`
4. Make sure there are no extra spaces or newlines

**If using environment variable method:**
1. Verify the variable is set: `echo $OPENAI_ADMIN_KEY`
2. Make sure you've added it to your shell config (`~/.zshrc` or `~/.bash_profile`)
3. For SwiftBar: Restart SwiftBar completely (quit and relaunch)
4. Some users may need to add it to `~/.zprofile` instead
5. As a last resort, restart your Mac

### Plugin Not Appearing in Menu Bar

**For SwiftBar:**
1. **Check Plugin Directory:** Make sure the file is in SwiftBar's plugin directory
2. **Check Permissions:** Ensure the file is executable: `chmod +x openai.30m.sh`
3. **Check SwiftBar Logs:** 
   - Open SwiftBar Preferences
   - Check the "Logs" tab for error messages
4. **Grant Accessibility Permission:** SwiftBar requires accessibility permission to function
   - Go to **System Settings → Privacy & Security → Accessibility**
   - Enable SwiftBar in the list
   - Restart SwiftBar

**For xbar:**
1. **Check Plugin Directory:** Make sure the file is in xbar's plugin directory
2. **Check Permissions:** Ensure the file is executable: `chmod +x openai.30m.sh`
3. **Check xbar Logs:** 
   - Open xbar Preferences
   - Check for error messages
4. **Verify Plugin Format:** The plugin uses standard xbar format and should work out of the box

### Showing "⚠️ OpenAI" or Error Messages

- **Red "⚠️ OpenAI":** API key not set or invalid
- **Orange "⚠️ OpenAI":** No usage data available (normal if you haven't used the API this month)
- **Check Logs:** For SwiftBar, open Preferences → Logs to see detailed error messages

### "Unavailable" or empty results

- Verify your admin key is valid and has the `api.usage.read` scope
- Check that you have usage data for the current month
- Ensure you have an active OpenAI account with API usage

### Script is slow

The scripts make multiple API calls and handle pagination. Progress dots/spinner indicate it's working. If it's consistently slow, check your network connection.

### Plugin Shows Old Data

- The plugin refreshes every 30 minutes automatically
- Click "Refresh" in the dropdown to force an immediate update
- Check SwiftBar logs if refresh isn't working

### Colors Not Showing (SwiftBar)

- SwiftBar supports color parameters, but some themes may override them
- Check SwiftBar's appearance settings
- Colors are optional - the plugin works without them

## Notes

- **Billing Period:** OpenAI bills by calendar month. Enterprise customers are billed at month-end, while pay-as-you-go customers are invoiced for the previous month's usage.
- **Data Accuracy:** Small discrepancies (usually <$1) between the script and dashboard are normal due to:
  - Timing differences in data aggregation
  - Additional services not yet included (images, audio, etc.)
  - Rounding differences
- **Credit Balance:** Credit balance is not available via the Admin API. Check your dashboard at [platform.openai.com/usage](https://platform.openai.com/usage) for credit information.
- **Performance:** The scripts fetch data sequentially with progress indicators. Execution time depends on the number of pages returned by the API.

## Security

- **Never commit your admin key to version control**
- **Use environment variables or Keychain** (as shown in setup) rather than hardcoding keys
- **Rotate your admin keys** periodically for security
- **Limit key scope** - only grant the minimum permissions needed

## API Reference

This script uses the OpenAI Usage API:
- [Usage API Documentation](https://platform.openai.com/docs/api-reference/usage)
- [Usage API Cookbook Example](https://cookbook.openai.com/examples/completions_usage_api)

## Menu Bar App Resources

### SwiftBar
- [SwiftBar GitHub](https://github.com/swiftbar/SwiftBar)
- [SwiftBar Plugin Documentation](https://github.com/swiftbar/SwiftBar#plugins)
- [SwiftBar Plugin Examples](https://github.com/swiftbar/SwiftBar#examples)

### xbar
- [xbar Website](https://xbarapp.com)
- [xbar GitHub](https://github.com/matryer/xbar)
- [xbar Plugin Documentation](https://github.com/matryer/xbar-plugins/blob/main/CONTRIBUTING.md)
