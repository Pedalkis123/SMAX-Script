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
        
        print("Sending data:", HttpService:JSONEncode(data))
        
        local response = syn.request({
            Url = webhookUrl,
            Method = "POST",
            Headers = {
                ["Content-Type"] = "application/json"
            },
            Body = HttpService:JSONEncode(data)
        })
        
        if response then
            print("Response Status:", response.StatusCode)
            print("Response Headers:", HttpService:JSONEncode(response.Headers))
            print("Response Body:", response.Body)
            
            if response.StatusCode == 200 then
                return response.Body == "valid"
            end
        end
        
        return false
    end)
    
    if not success then
        print("Request failed:", response)
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
