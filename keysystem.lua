-- Services
local MemStorageService = game:GetService('MemStorageService')
local ReplicatedStorage = game:GetService('ReplicatedStorage')
local Players = game:GetService("Players")

local function verifyKey(key)
    local success, response = pcall(function()
        -- Update this URL with your Replit URL
        local webhookUrl = "https://projectname.yourusername.repl.co/verify"
        
        local data = {
            ["key"] = key,
            ["hwid"] = game:GetService("RbxAnalyticsService"):GetClientId(),
            ["username"] = game.Players.LocalPlayer.Name,
            ["userid"] = game.Players.LocalPlayer.UserId,
        }
        
        print("Sending verification request with data:", game:GetService("HttpService"):JSONEncode(data))
        
        local response = syn.request({
            Url = webhookUrl,
            Method = "POST",
            Headers = {
                ["Content-Type"] = "application/json"
            },
            Body = game:GetService("HttpService"):JSONEncode(data)
        })
        
        print("Server response:", response.Body)
        
        return response.Body == "valid"
    end)
    
    return success and response
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
        if verifyKey(keyInput) then
            KeySystem:Unload()
            -- Load your main script directly here
            loadstring(game:HttpGet("https://raw.githubusercontent.com/Pedalkis123/SMAX-Script/main/main1.lua"))()
        else
            Box:AddLabel("Invalid key! Purchase at: your_store_url")
        end
    end
})

Box:AddLabel("Need a key? Purchase at: your_store_url")
