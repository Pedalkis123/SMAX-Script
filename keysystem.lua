-- Services
local MemStorageService = game:GetService('MemStorageService')
local ReplicatedStorage = game:GetService('ReplicatedStorage')
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local RbxAnalytics = game:GetService("RbxAnalyticsService")

-- Debug function
local function debugLog(...)
    local args = {...}
    local str = ""
    for i, v in ipairs(args) do
        str = str .. tostring(v) .. " "
    end
    print("[DEBUG]", str)
    -- Also write to a file for persistent logging
    if writefile then
        appendfile("smax_debug.txt", os.date("%Y-%m-%d %H:%M:%S") .. " " .. str .. "\n")
    end
end

-- Function to detect executor
local function getExecutorType()
    local executor = "Unknown"
    
    if syn then executor = "Synapse X"
    elseif KRNL_LOADED then executor = "Krnl"
    elseif getexecutorname then executor = getexecutorname()
    elseif identifyexecutor then executor = identifyexecutor()
    end
    
    debugLog("Detected executor:", executor)
    return executor
end

-- Get HWID based on executor
local function getHWID()
    debugLog("Getting HWID...")
    local hwid
    local executor = getExecutorType()
    
    if executor == "Synapse X" then
        debugLog("Using Synapse X HWID method")
        local response = syn.request({Url = "https://httpbin.org/get"})
        debugLog("Synapse response:", HttpService:JSONEncode(response))
        hwid = response.Headers["Syn-Fingerprint"]
    elseif executor == "Krnl" then
        debugLog("Using Krnl HWID method")
        local response = request({Url = "https://httpbin.org/get"})
        debugLog("Krnl response:", HttpService:JSONEncode(response))
        hwid = response.Headers["Fingerprint"]
    elseif executor:find("Xeno") then
        debugLog("Using Xeno HWID method")
        hwid = RbxAnalytics:GetClientId()
    else
        debugLog("Using fallback HWID method")
        hwid = RbxAnalytics:GetClientId()
    end
    
    if hwid then
        hwid = tostring(hwid):gsub("%s+", ""):upper()
        debugLog("Final HWID:", hwid)
    else
        debugLog("WARNING: Failed to get HWID!")
    end
    
    return hwid
end

-- Function to make HTTP requests
local function makeRequest(url, method, data)
    debugLog("Making request to:", url)
    debugLog("Method:", method)
    debugLog("Data:", HttpService:JSONEncode(data))
    
    local success, response = pcall(function()
        local jsonData = HttpService:JSONEncode(data)
        local executor = getExecutorType()
        
        if executor == "Synapse X" then
            debugLog("Using Synapse X request method")
            return syn.request({
                Url = url,
                Method = method,
                Headers = {["Content-Type"] = "application/json"},
                Body = jsonData
            })
        elseif executor == "Krnl" then
            debugLog("Using Krnl request method")
            return request({
                Url = url,
                Method = method,
                Headers = {["Content-Type"] = "application/json"},
                Body = jsonData
            })
        elseif executor:find("Xeno") then
            debugLog("Using Xeno request method")
            return http_request({
                Url = url,
                Method = method,
                Headers = {["Content-Type"] = "application/json"},
                Body = jsonData
            })
        else
            debugLog("Using fallback request method")
            return HttpService:RequestAsync({
                Url = url,
                Method = method,
                Headers = {["Content-Type"] = "application/json"},
                Body = jsonData
            })
        end
    end)
    
    if not success then
        debugLog("Request failed:", response)
        return nil
    end
    
    debugLog("Request successful. Response:", HttpService:JSONEncode(response))
    return response
end

-- Verify key function
local function verifyKey(key)
    debugLog("Verifying key:", key)
    local hwid = getHWID()
    if not hwid then
        debugLog("Failed to get HWID!")
        return "error"
    end
    
    local data = {
        key = key,
        hwid = hwid
    }
    
    local response = makeRequest(
        "https://smax-script.onrender.com/verify",
        "POST",
        data
    )
    
    if response and response.Body then
        debugLog("Verify response:", response.Body)
        return response.Body
    end
    
    debugLog("Verify failed!")
    return "error"
end

local function resetHWID(key)
    local response = makeRequest(
        "https://smax-script.onrender.com/reset-hwid",
        "POST",
        {["key"] = key}
    )
    
    if response then
        return response.Body
    end
    
    return "error"
end

-- Create key system UI
local KeySystem = loadstring(game:HttpGet("https://raw.githubusercontent.com/violin-suzutsuki/LinoriaLib/main/Library.lua"))()
local Window = KeySystem:CreateWindow({
    Title = "Key System",
    Center = true,
    AutoShow = true,
})

local Tab = Window:AddTab('Key')
local Box = Tab:AddLeftGroupbox('Verification')
local ResetBox = Tab:AddRightGroupbox('HWID Reset')

local keyInput = ""
Box:AddInput('Key', {
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
        print("Attempting to verify key:", keyInput)
        local result = verifyKey(keyInput)
        
        if result == "valid" then
            KeySystem:Unload()
            loadstring(game:HttpGet("https://raw.githubusercontent.com/Pedalkis123/SMAX-Script/main/main1.lua"))()
        elseif result == "invalid_hwid" then
            Box:AddLabel("HWID mismatch! Use reset option ->")
        elseif result == "invalid_key" then
            Box:AddLabel("Invalid key! Purchase at: your_store_url")
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

Box:AddLabel("Need a key? Purchase at: your_store_url")
