-- Services
local MemStorageService = game:GetService('MemStorageService')
local ReplicatedStorage = game:GetService('ReplicatedStorage')
local Players = game:GetService("Players")

local function makeRequest(url, method, data)
    local HttpService = game:GetService("HttpService")
    
    -- Get HWID
    local hwid = nil
    if syn then
        hwid = syn.request({Url = "https://httpbin.org/get"}).Headers["Syn-Fingerprint"]
    elseif request then
        hwid = request({Url = "https://httpbin.org/get"}).Headers["Fingerprint"]
    elseif http and http.request then
        hwid = http.request({Url = "https://httpbin.org/get"}).Headers["Fingerprint"]
    end
    
    if not hwid then
        hwid = game:GetService("RbxAnalyticsService"):GetClientId()
    end
    
    -- Add HWID to data
    if data then
        data.hwid = hwid
    else
        data = {hwid = hwid}
    end
    
    -- Try different request methods based on executor
    local success, response = pcall(function()
        -- Method 1: Synapse X / Script-Ware
        if syn and syn.request then
            return syn.request({
                Url = url,
                Method = method,
                Headers = {
                    ["Content-Type"] = "application/json"
                },
                Body = HttpService:JSONEncode(data)
            })
        end
        
        -- Method 2: KRNL / Other
        if request then
            return request({
                Url = url,
                Method = method,
                Headers = {
                    ["Content-Type"] = "application/json"
                },
                Body = HttpService:JSONEncode(data)
            })
        end
        
        -- Method 3: Fluxus
        if http and http.request then
            return http.request({
                Url = url,
                Method = method,
                Headers = {
                    ["Content-Type"] = "application/json"
                },
                Body = HttpService:JSONEncode(data)
            })
        end
        
        -- Fallback: HttpService (if game allows HTTP requests)
        return HttpService:RequestAsync({
            Url = url,
            Method = method,
            Headers = {
                ["Content-Type"] = "application/json"
            },
            Body = HttpService:JSONEncode(data)
        })
    end)
    
    if not success then
        warn("Request failed:", response)
        return nil
    end
    
    return response
end

-- Add this function to standardize HWID across executors
local function getHWID()
    local hwid = nil
    
    -- Try different HWID methods
    if syn then
        hwid = syn.request({Url = "https://httpbin.org/get"}).Body:find("Syn%-Fingerprint: ([%w-]+)") 
    elseif http_request then
        hwid = http_request({Url = "https://httpbin.org/get"}).Body:find("Syn%-Fingerprint: ([%w-]+)")
    elseif identifyexecutor then
        hwid = game:GetService("RbxAnalyticsService"):GetClientId()
    end
    
    -- Fallback to basic HWID if none found
    if not hwid then
        hwid = game:GetService("RbxAnalyticsService"):GetClientId()
    end
    
    -- Clean and format HWID
    hwid = string.upper(string.gsub(hwid, "%s+", ""))
    
    return hwid
end

-- Update your verify request
local function verifyKey(key)
    local hwid = getHWID()
    
    local response = http_request({
        Url = "https://smax-script.onrender.com/verify",
        Method = "POST",
        Headers = {
            ["Content-Type"] = "application/json"
        },
        Body = game:GetService("HttpService"):JSONEncode({
            key = key,
            hwid = hwid
        })
    })
    
    if response.StatusCode == 200 then
        return response.Body
    else
        return "error"
    end
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
