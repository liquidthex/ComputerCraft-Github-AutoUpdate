-- autoupdater.lua
-- A script to auto-update itself and a user's repository from GitHub using a configuration file

-- Ensure HTTP API is enabled
if not http then
    error('HTTP API is not enabled in ComputerCraft. Enable it by setting "http_enable = true" in the mod config.')
end

-- Configuration for the autoupdater's own repo (hardcoded)
local updaterGithubUser = 'liquidthex'
local updaterGithubRepo = 'ComputerCraft-Github-AutoUpdate'
local updaterGithubBranch = 'main'

local updatedSelfFlag = false
if arg and arg[1] == '--updated-self' then
    updatedSelfFlag = true
    table.remove(arg, 1)
end

-- Function to read configuration from autoupdater.cfg
local function readUserConfig()
    if not fs.exists('autoupdater.cfg') then
        -- Create default configuration file
        local defaultConfig = {
            githubUser = 'your-github-username',
            githubRepo = 'your-repo-name',
            githubBranch = 'main'  -- Optional, defaults to 'main' if not specified
        }
        local file = fs.open('autoupdater.cfg', 'w')
        file.write(textutils.serialize(defaultConfig))
        file.close()
        print('Default configuration file autoupdater.cfg has been created.')
        print('Please edit autoupdater.cfg to include your GitHub repository details.')
        error('Please configure autoupdater.cfg and run the script again.')
    end

    local file = fs.open('autoupdater.cfg', 'r')
    local content = file.readAll()
    file.close()

    local config = textutils.unserialize(content)
    if not config or not config.githubUser or not config.githubRepo then
        error('Invalid configuration in autoupdater.cfg. Please provide githubUser and githubRepo.')
    end

    -- Check if default values are still set
    if config.githubUser == 'your-github-username' or config.githubRepo == 'your-repo-name' then
        print('You need to edit autoupdater.cfg and replace the placeholder values with your own GitHub repository details.')
        error('Please configure autoupdater.cfg and run the script again.')
    end

    -- Set defaults if not provided
    config.githubBranch = config.githubBranch or 'main'

    return config.githubUser, config.githubRepo, config.githubBranch
end

-- Function to get the latest commit hash from GitHub API
local function getLatestCommitHash(githubUser, githubRepo, githubBranch)
    local apiURL = 'https://api.github.com/repos/' .. githubUser .. '/' .. githubRepo .. '/commits/' .. githubBranch
    local headers = {
        ["Cache-Control"] = "no-cache",
        ["User-Agent"] = "ComputerCraft"
    }
    local response = http.get(apiURL, headers)
    if not response then
        error('Failed to retrieve the latest commit hash for ' .. githubUser .. '/' .. githubRepo)
    end
    local jsonResponse = response.readAll()
    response.close()

    -- Parse the JSON response
    local data = textutils.unserializeJSON(jsonResponse)
    if not data or not data.sha then
        error('Failed to parse the latest commit hash for ' .. githubUser .. '/' .. githubRepo)
    end
    return data.sha
end

-- Function to load stored commit hash
local function loadStoredCommitHash(filePath)
    if fs.exists(filePath) then
        local file = fs.open(filePath, 'r')
        local hash = file.readAll()
        file.close()
        return hash
    else
        return nil
    end
end

-- Function to save commit hash
local function saveCommitHash(filePath, hash)
    local file = fs.open(filePath, 'w')
    file.write(hash)
    file.close()
end

-- Function to update the autoupdater script
local function updateSelf()
    print('Checking for updates to the autoupdater script...')
    local latestHash = getLatestCommitHash(updaterGithubUser, updaterGithubRepo, updaterGithubBranch)
    local storedHash = loadStoredCommitHash('.autoupdater_commit_hash')

    if storedHash == latestHash then
        print('Autoupdater is up to date.')
        return false
    else
        -- Download the latest version of autoupdater.lua
        local downloadURL = 'https://raw.githubusercontent.com/' .. updaterGithubUser .. '/' .. updaterGithubRepo .. '/' .. latestHash .. '/autoupdater.lua'
        local headers = {
            ["Cache-Control"] = "no-cache",
            ["User-Agent"] = "ComputerCraft"
        }
        local response = http.get(downloadURL, headers)
        if not response then
            error('Failed to download the latest autoupdater script.')
        end
        local content = response.readAll()
        response.close()

        -- Save the new version to a temporary file
        local tempFile = 'autoupdater_new.lua'
        local file = fs.open(tempFile, 'w')
        file.write(content)
        file.close()

        -- Save the new commit hash
        saveCommitHash('.autoupdater_commit_hash', latestHash)

        -- Run the new version of autoupdater with a flag indicating it has updated itself
        print('Running the updated autoupdater script...')
        shell.run(tempFile, '--updated-self')

        -- Exit the current script
        return true
    end
end

-- Function to update the user's repository
local function updateUserRepo()
    print('Checking for updates in user repository...')

    local userGithubUser, userGithubRepo, userGithubBranch = readUserConfig()

    local latestHash = getLatestCommitHash(userGithubUser, userGithubRepo, userGithubBranch)
    local storedHash = loadStoredCommitHash('.userrepo_commit_hash')

    if storedHash == latestHash then
        print('User repository is up to date.')
        return false
    else
        print('Updating user repository...')
        -- Get the repository tree
        local apiURL = 'https://api.github.com/repos/' .. userGithubUser .. '/' .. userGithubRepo .. '/git/trees/' .. latestHash .. '?recursive=1'
        local headers = {
            ["Cache-Control"] = "no-cache",
            ["User-Agent"] = "ComputerCraft"
        }
        local response = http.get(apiURL, headers)
        if not response then
            error('Failed to retrieve the repository tree for ' .. userGithubUser .. '/' .. userGithubRepo)
        end
        local jsonResponse = response.readAll()
        response.close()

        -- Parse the JSON response
        local data = textutils.unserializeJSON(jsonResponse)
        if not data or not data.tree then
            error('Failed to parse the repository tree.')
        end
        local tree = data.tree

        -- Download files from the tree
        for _, item in ipairs(tree) do
            if item.type == "blob" then
                local filePath = item.path
                -- Exclude hidden files and autoupdater.lua
                if not filePath:match('^%.') and filePath ~= 'autoupdater.lua' then
                    -- Construct the download URL
                    local downloadURL = 'https://raw.githubusercontent.com/' .. userGithubUser .. '/' .. userGithubRepo .. '/' .. latestHash .. '/' .. filePath

                    -- Download the file
                    print('Downloading ' .. filePath)
                    local headers = {
                        ["Cache-Control"] = "no-cache",
                        ["User-Agent"] = "ComputerCraft"
                    }
                    local response = http.get(downloadURL, headers)
                    if not response then
                        error('Failed to download ' .. filePath)
                    end
                    local content = response.readAll()
                    response.close()

                    -- Ensure the directory exists
                    local dir = fs.getDir(filePath)
                    if dir ~= "" and not fs.exists(dir) then
                        fs.makeDir(dir)
                    end

                    -- Save the content to the specified path
                    local file = fs.open(filePath, 'w')
                    file.write(content)
                    file.close()
                end
            end
        end

        -- Save the new commit hash
        saveCommitHash('.userrepo_commit_hash', latestHash)

        print('User repository update complete.')
        return true
    end
end

-- Main function
local function main()
    if not updatedSelfFlag then
        local updatedSelf = updateSelf()
        if updatedSelf then
            -- The updated script has already been run
            return
        end
    else
        -- Since we are running the updated script, we can replace the old autoupdater.lua
        fs.delete('autoupdater.lua')
        fs.move('autoupdater_new.lua', 'autoupdater.lua')
    end

    -- Proceed to update the user's repository
    local updatedUserRepo = updateUserRepo()
    if updatedUserRepo then
        -- An update was performed
        print('An update was performed on the user repository.')
        -- Write update status to a file (optional)
        saveCommitHash('.last_update_status', 'updated')
    else
        print('No updates were needed.')
        -- Write update status to a file (optional)
        saveCommitHash('.last_update_status', 'no_update')
    end
end

-- Run the main function
main()
