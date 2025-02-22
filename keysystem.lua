-- Services
local MemStorageService = game:GetService('MemStorageService')
local ReplicatedStorage = game:GetService('ReplicatedStorage')
local Players = game:GetService("Players")

local function makeRequest(url, method, data)
    local HttpService = game:GetService("HttpService")
    
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

local function verifyKey(key)
    local response = makeRequest(
        "https://smax-script.onrender.com/verify",
        "POST",
        {["key"] = key}
    )
    
    if response then
        print("Response received:", response.Body)
        return response.Body == "valid"
    end
    
    return false
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
        if verifyKey(keyInput) then
            print("Key verified successfully!")
            KeySystem:Unload()
            loadstring(game:HttpGet("https://raw.githubusercontent.com/Pedalkis123/SMAX-Script/main/main1.lua"))()
        else
            print("Invalid key!")
            Box:AddLabel("Invalid key! Purchase at: your_store_url")
        end
    end
})

Box:AddLabel("Need a key? Purchase at: your_store_url")
