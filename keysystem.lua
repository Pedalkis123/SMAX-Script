-- Services
local HttpService = game:GetService("HttpService")
local RbxAnalytics = game:GetService("RbxAnalyticsService")

-- Simple debug
local function debug(...)
    print("[SMAX]", ...)
end

-- Get executor's request function
local function getRequestFunction()
    if syn and syn.request then
        return syn.request
    elseif http_request then
        return http_request
    elseif request then
        return request
    elseif HttpService.RequestAsync then
        return function(req)
            local res = HttpService:RequestAsync({
                Url = req.Url,
                Method = req.Method,
                Headers = req.Headers,
                Body = req.Body
            })
            return {
                StatusCode = res.StatusCode,
                Body = res.Body
            }
        end
    end
end

-- Get HWID
local function getHWID()
    return RbxAnalytics:GetClientId()
end

-- Make request
local function makeRequest(url, method, data)
    local requestFunc = getRequestFunction()
    if not requestFunc then
        debug("No compatible request function found")
        return "error"
    end

    local jsonData = HttpService:JSONEncode(data)
    local success, response = pcall(function()
        return requestFunc({
            Url = url,
            Method = method,
            Headers = {
                ["Content-Type"] = "application/json"
            },
            Body = jsonData
        })
    end)

    if not success then
        debug("Request failed:", response)
        return "error"
    end

    if response.StatusCode == 200 then
        return response.Body
    end

    return "error"
end

-- Verify key function
local function verifyKey(key)
    return makeRequest(
        "https://smax-script.onrender.com/verify",
        "POST",
        {
            key = key,
            hwid = getHWID()
        }
    )
end

-- Reset HWID function
local function resetHWID(key)
    return makeRequest(
        "https://smax-script.onrender.com/reset-hwid",
        "POST",
        {
            key = key
        }
    )
end

-- Create UI
local KeySystem = loadstring(game:HttpGet("https://raw.githubusercontent.com/violin-suzutsuki/LinoriaLib/main/Library.lua"))()
local Window = KeySystem:CreateWindow({
    Title = "SMAX Key System",
    Center = true,
    AutoShow = true,
})

local Tab = Window:AddTab('Verification')
local Box = Tab:AddLeftGroupbox('Enter Key')
local ResetBox = Tab:AddRightGroupbox('HWID Reset')

local keyInput = ""
Box:AddInput('KeyInput', {
    Default = "",
    Numeric = false,
    Finished = false,
    Text = 'Enter your key',
    Placeholder = 'Paste key here...',
    Callback = function(Value)
        keyInput = Value
    end
})

Box:AddButton({
    Text = 'Verify Key',
    Func = function()
        debug("Verifying key:", keyInput)
        local result = verifyKey(keyInput)
        
        if result == "valid" then
            KeySystem:Unload()
            loadstring(game:HttpGet("https://raw.githubusercontent.com/Pedalkis123/SMAX-Script/main/main1.lua"))()
        elseif result == "invalid_hwid" then
            Box:AddLabel("HWID mismatch! Use reset option ->")
        elseif result == "invalid_key" then
            Box:AddLabel("Invalid key! Buy at discord.gg/ebwwsfzKyh")
        else
            Box:AddLabel("Error! Try again or contact support")
        end
    end
})

ResetBox:AddButton({
    Text = 'Reset HWID',
    Func = function()
        if keyInput == "" then
            ResetBox:AddLabel("Please enter your key first!")
            return
        end
        
        local result = resetHWID(keyInput)
        if result == "success" then
            ResetBox:AddLabel("HWID reset successful!")
        elseif result == "no_hwid_set" then
            ResetBox:AddLabel("No HWID set for this key!")
        elseif result:match("^wait_") then
            local hours = result:match("wait_(%d+)")
            ResetBox:AddLabel("Wait " .. hours .. " hours before reset!")
        else
            ResetBox:AddLabel("Error resetting HWID!")
        end
    end
})

Box:AddLabel("Need a key? Join discord.gg/ebwwsfzKyh")
