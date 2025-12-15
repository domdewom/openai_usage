# OpenAI Usage SwiftBar Plugin

A SwiftBar plugin that displays your OpenAI API usage and costs directly in your macOS menu bar.

## What It Does

This SwiftBar plugin shows your OpenAI usage and costs in your macOS menu bar:

- **Menu Bar Display:** Shows current month-to-date cost (e.g., 💰 $7.41)
- **Dropdown Menu:** Detailed breakdown including:
  - Billing period
  - Total costs
  - Token usage (input/output breakdown)
  - Total API requests
  - Quick links to dashboard and refresh action

The plugin automatically refreshes every 30 minutes to keep your usage data up to date.

## Prerequisites

- **macOS** (SwiftBar is macOS-only)
- **SwiftBar** app installed ([Download from GitHub](https://github.com/swiftbar/SwiftBar/releases))
- **curl** (usually pre-installed on macOS)
- **jq** (for JSON parsing)
- **bc** (for calculations, usually pre-installed on macOS)
- **OpenAI Admin API Key** (not a regular API key)

### Installing SwiftBar

1. Download SwiftBar from the [releases page](https://github.com/swiftbar/SwiftBar/releases)
2. Move SwiftBar.app to your Applications folder
3. Launch SwiftBar and grant necessary permissions:
   - **Accessibility Permission:** SwiftBar needs "Control the computer using accessibility features" permission to function properly
   - When prompted, go to **System Settings → Privacy & Security → Accessibility**
   - Enable SwiftBar in the list
   - You may need to restart SwiftBar after granting permission

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
3. Name it (e.g., "SwiftBar Plugin")
4. Copy the key (it starts with `sk-admin-...`)

⚠️ **Important:** Admin keys have broader permissions than regular API keys. Keep them secure and never commit them to version control.

### 2. Set the API Key

The plugin supports multiple methods to load your admin key, tried in this order:

1. **macOS Keychain** (most secure)
2. **Environment Variable** (works in terminal)
3. **Config File** (works for GUI apps)

#### Option A: macOS Keychain (Most Secure - Recommended)

Store your key in macOS Keychain for maximum security:

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

#### Option B: Config File

Create a secure config file in your home directory:

```bash
# Create the config file with your admin key
echo 'sk-admin-...' > ~/.openai_admin_key

# Secure it (only you can read it)
chmod 600 ~/.openai_admin_key
```

**Why this method?** GUI apps on macOS don't inherit environment variables from shell config files. Using a config file ensures SwiftBar can always access your key.

#### Option C: Environment Variable

If you prefer using environment variables, add it to your shell configuration:

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

**Important:** After setting the environment variable, you'll need to:
- Restart SwiftBar completely (quit and relaunch)
- Or restart your Mac to ensure the variable is available system-wide

**Note:** The plugin tries methods in order: Keychain → Environment Variable → Config File. Use whichever method you prefer!

### 3. Grant Accessibility Permission

SwiftBar requires accessibility permission to control your computer:

1. Open **System Settings** (or System Preferences on older macOS)
2. Go to **Privacy & Security → Accessibility**
3. Enable **SwiftBar** in the list
4. If SwiftBar isn't in the list, click the **+** button and add it manually
5. Restart SwiftBar after granting permission

**Note:** This permission is required for SwiftBar to function. Without it, plugins may not work correctly.

### 4. Install the Plugin

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

### 5. (Optional) Use Local OpenAI Logo

The plugin uses the OpenAI logo from their CDN by default. For better performance or offline use, you can download the logo locally:

1. Visit [OpenAI Brand Assets](https://openai.com/brand/)
2. Download the OpenAI logo (PNG format recommended)
3. Save it as `~/.openai_logo.png`:
   ```bash
   # After downloading, move it to your home directory
   mv ~/Downloads/openai-logo.png ~/.openai_logo.png
   ```

The plugin will automatically detect and use the local logo if available.

## Usage

Once installed, the plugin will:

- **Display in Menu Bar:** Shows the OpenAI logo followed by your current month-to-date cost
- **Color Coding:** 
  - Green: Cost < $20
  - Orange: Cost $20-$50
  - Red: Cost > $50
- **Click to View Details:** Click the menu bar item to see:
  - Billing period
  - Detailed cost breakdown
  - Token usage statistics
  - Total requests
  - Quick actions (open dashboard, refresh)

### Menu Bar Display

```
💰 $7.41
```

### Dropdown Menu

```
OpenAI Usage & Costs
---
Period: 2025-12-01 to 2025-12-14
---
💰 Costs
$7.41
---
📊 Usage
Total Tokens: 2,112,737
  Input:  2,067,286
  Output: 45,451
Total Requests: 961
---
🔗 Open Dashboard
🔄 Refresh
```

## Refresh Schedule

The plugin refreshes automatically every **30 minutes** (as indicated by the `.30m` in the filename). You can:

- **Change Refresh Interval:** Rename the file to change the interval:
  - `openai.5m.sh` = every 5 minutes
  - `openai.1h.sh` = every hour
  - `openai.1d.sh` = once per day
- **Manual Refresh:** Click "🔄 Refresh" in the dropdown menu
- **Custom Schedule:** Edit the plugin file and add a cron schedule in metadata:
  ```bash
  # <swiftbar.schedule>*/30 * * * *</swiftbar.schedule>
  ```

## Troubleshooting

### Plugin Not Appearing in Menu Bar

1. **Check Plugin Directory:** Make sure the file is in SwiftBar's plugin directory
2. **Check Permissions:** Ensure the file is executable: `chmod +x openai.30m.sh`
3. **Check SwiftBar Logs:** 
   - Open SwiftBar Preferences
   - Check the "Logs" tab for error messages
4. **Verify Environment Variable:** SwiftBar needs access to `OPENAI_ADMIN_KEY`
   - Try restarting SwiftBar
   - Or restart your Mac to ensure environment variables are loaded

### "API key not found"

**If using Keychain method (recommended):**
1. Verify the key exists: `security find-generic-password -a "$USER" -s "openai_admin_key"`
2. If it doesn't exist, add it: `security add-generic-password -a "$USER" -s "openai_admin_key" -w "your-key"`
3. Check for typos in the service name: `openai_admin_key` (must match exactly)
4. Try refreshing the plugin after adding the key

**If using config file method:**
1. Verify the file exists: `ls -la ~/.openai_admin_key`
2. Check file permissions: `chmod 600 ~/.openai_admin_key`
3. Verify the key is in the file: `cat ~/.openai_admin_key`
4. Make sure there are no extra spaces or newlines

**If using environment variable method:**
1. Verify the variable is set: `echo $OPENAI_ADMIN_KEY`
2. Make sure you've added it to your shell config (`~/.zshrc` or `~/.bash_profile`)
3. Restart SwiftBar completely (quit and relaunch)
4. Some users may need to add it to `~/.zprofile` instead
5. As a last resort, restart your Mac

**Recommended:** Use the Keychain method (Option A) for the most secure and reliable setup.

### Showing "⚠️ OpenAI" or Error Messages

- **Red "⚠️ OpenAI":** API key not set or invalid
- **Orange "⚠️ OpenAI":** No usage data available (normal if you haven't used the API this month)
- **Check Logs:** Open SwiftBar Preferences → Logs to see detailed error messages

### Plugin Shows Old Data

- The plugin refreshes every 30 minutes automatically
- Click "🔄 Refresh" in the dropdown to force an immediate update
- Check SwiftBar logs if refresh isn't working

### Colors Not Showing

- SwiftBar supports color parameters, but some themes may override them
- Check SwiftBar's appearance settings
- Colors are optional - the plugin works without them

## Customization

### Change Cost Thresholds

Edit the color thresholds in the plugin file:

```bash
# Around line 100-105
if (( $(echo "$TOTAL_COST > 50" | bc -l) )); then
    COST_COLOR="red"
elif (( $(echo "$TOTAL_COST > 20" | bc -l) )); then
    COST_COLOR="orange"
else
    COST_COLOR="green"
fi
```

### Change Display Format

Modify the menu bar title (around line 110):

```bash
# Current: Shows cost with emoji
echo "💰 \$$COST_FORMATTED | color=$COST_COLOR"

# Alternative: Show tokens instead
echo "📊 $TOKENS_FORMATTED | color=blue"
```

### Add More Details

Add additional menu items in the dropdown section (after line 115):

```bash
echo "---"
echo "📈 Daily Average: \$$(printf "%.2f" $(echo "$TOTAL_COST / $(date +%d)" | bc -l))"
```

## Security

- **Never commit your admin key to version control**
- **Use environment variables** (as shown in setup) rather than hardcoding keys
- **Rotate your admin keys** periodically for security
- **Limit key scope** - only grant the minimum permissions needed
- The plugin reads the key from environment variables, not from the script file

## How It Works

1. **Calculates Billing Period:** Automatically determines the start (first day of current month) and end (today) dates
2. **Fetches Usage Data:** 
   - Calls `/v1/organization/usage/completions` for chat completions usage
   - Calls `/v1/organization/usage/embeddings` for embeddings usage
   - Handles pagination automatically
3. **Fetches Cost Data:**
   - Calls `/v1/organization/costs` for cost breakdown
   - Aggregates costs across all projects and line items
4. **Formats Output:** Formats data for SwiftBar's menu bar display format
5. **Displays Results:** SwiftBar renders the output in your menu bar

## Notes

- **Billing Period:** OpenAI bills by calendar month. The plugin shows current month-to-date usage.
- **Data Accuracy:** Small discrepancies between the plugin and dashboard are normal due to timing differences in data aggregation.
- **Refresh Interval:** 30 minutes is a good balance between freshness and API rate limits. Adjust as needed.
- **Performance:** The plugin fetches data in the background. SwiftBar handles execution and display.

## Related Files

- `openai_usage.sh` - Standalone script version (see main README.md)
- `README.md` - Documentation for the standalone script

## API Reference

This plugin uses the OpenAI Usage API:
- [Usage API Documentation](https://platform.openai.com/docs/api-reference/usage)
- [Usage API Cookbook Example](https://cookbook.openai.com/examples/completions_usage_api)

## SwiftBar Resources

- [SwiftBar GitHub](https://github.com/swiftbar/SwiftBar)
- [SwiftBar Plugin Documentation](https://github.com/swiftbar/SwiftBar#plugins)
- [SwiftBar Plugin Examples](https://github.com/swiftbar/SwiftBar#examples)

