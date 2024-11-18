# GitHub Auto-Updater for ComputerCraft

This project provides a script to automatically update itself and a user's repository from GitHub using a configuration file.

## How to Include the Updater in Your Project

1. **Add the Script**: Copy the `autoupdater.lua` script into your project's directory.

2. **Ensure HTTP API is Enabled**: The script requires the HTTP API to be enabled in ComputerCraft. Make sure to set `"http_enable = true"` in the mod configuration.

## Initial Configuration

1. **Create Configuration File**: On the first run, the script will create a default configuration file named `autoupdater.cfg` if it doesn't exist. This file contains placeholders for your GitHub repo details.

2. **Edit Configuration**: Open `autoupdater.cfg` and replace the placeholder values with your actual GitHub repository details:
   - `githubUser`: Your GitHub username.
   - `githubRepo`: Your repository name.
   - `githubBranch`: (Optional) The branch to update from, defaults to 'main' if not specified.

3. **Best Practice**: It's recommended to include the `autoupdater.cfg` file in your repository with actual values. This way your repo will auto-update on a new computer deployment immediately.

## Usage

###  Integration Code
You can include the following code in your main script or startup file:

```lua
shell.run('autoupdater.lua')
```

### Handling Update outcome with your code

```lua
-- Function to check if an update occurred
local function wasUpdated()
    if fs.exists('.last_update_status') then
        local file = fs.open('.last_update_status', 'r')
        local status = file.readAll()
        file.close()
        return status == 'updated'
    end
    return false
end

if wasUpdated() then
    print('An update was performed. Restarting your script...')
    -- Handle the update, e.g., by rebooting
    os.reboot()
end
```
