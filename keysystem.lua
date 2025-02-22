-- Services
local MemStorageService = game:GetService('MemStorageService')
local ReplicatedStorage = game:GetService('ReplicatedStorage')
local Players = game:GetService("Players")

local function verifyKey(key)
    local HttpService = game:GetService("HttpService")
    
    local success, response = pcall(function()
        local webhookUrl = "https://smax-script.onrender.com/verify"
        
        local data = {
            ["key"] = key
        }
        
        local jsonData = HttpService:JSONEncode(data)
        print("Sending request with data:", jsonData)
        
        local response = HttpService:RequestAsync({
            Url = webhookUrl,
            Method = "POST",
            Headers = {
                ["Content-Type"] = "application/json"
            },
            Body = jsonData
        })
        
        print("Response received:", response.Body)
        return response.Body == "valid"
    end)
    
    if not success then
        warn("Failed to verify key:", response)
        return false
    end
    
    return response
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
