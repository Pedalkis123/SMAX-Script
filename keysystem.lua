-- Services
local MemStorageService = game:GetService('MemStorageService')
local ReplicatedStorage = game:GetService('ReplicatedStorage')
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local RbxAnalytics = game:GetService("RbxAnalyticsService")

-- Function to make HTTP requests that works across executors
local function makeRequest(url, method, data)
    local success, response = pcall(function()
        -- Convert data to JSON
        local jsonData = HttpService:JSONEncode(data)
        
        -- Synapse X
        if syn and syn.request then
            return syn.request({
                Url = url,
                Method = method,
                Headers = {["Content-Type"] = "application/json"},
                Body = jsonData
            })
        end
        
        -- Krnl
        if request then
            return request({
                Url = url,
                Method = method,
                Headers = {["Content-Type"] = "application/json"},
                Body = jsonData
            })
        end
        
        -- Fluxus
        if http and http.request then
            return http.request({
                Url = url,
                Method = method,
                Headers = {["Content-Type"] = "application/json"},
                Body = jsonData
            })
        end

        -- Xeno
        if http_request then
            return http_request({
                Url = url,
                Method = method,
                Headers = {["Content-Type"] = "application/json"},
                Body = jsonData
            })
        end
        
        -- Generic fallback
        return HttpService:RequestAsync({
            Url = url,
            Method = method,
            Headers = {["Content-Type"] = "application/json"},
            Body = jsonData
        })
    end)
    
    if not success then
        warn("Request failed:", response)
        return nil
    end
    
    return response
end

-- Get HWID based on executor
local function getHWID()
    local hwid
    local executor = identifyexecutor and identifyexecutor() or ""
    
    if syn then -- Synapse X
        hwid = syn.request({Url = "https://httpbin.org/get"}).Headers["Syn-Fingerprint"]
    elseif executor:find("Krnl") then -- Krnl
        hwid = request({Url = "https://httpbin.org/get"}).Headers["Fingerprint"]
    elseif executor:find("Xeno") then -- Xeno
        hwid = RbxAnalytics:GetClientId()
    else -- Fallback
        hwid = RbxAnalytics:GetClientId()
    end
    
    -- Clean and standardize HWID
    hwid = tostring(hwid):gsub("%s+", ""):upper()
    return hwid
end

-- Verify key function
local function verifyKey(key)
    local data = {
        key = key,
        hwid = getHWID()
    }
    
    local response = makeRequest(
        "https://smax-script.onrender.com/verify",
        "POST",
        data
    )
    
    if response and response.Body then
        return response.Body
    end
    
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
