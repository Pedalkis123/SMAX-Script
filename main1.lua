-- Add this at the very top of your script, before loading any libraries
local MemStorageService = game:GetService('MemStorageService')
local ReplicatedStorage = game:GetService('ReplicatedStorage')
local TeleportService = game:GetService('TeleportService')
local CorePackages = game:GetService('CorePackages')
local CoreGui = game:GetService("CoreGui")

-- Safe location CFrame
local SAFE_LOCATION = CFrame.new(-3130, 867, -171)

-- Load libraries and continue with the rest of the script only if we're in the main game
local repo = 'https://raw.githubusercontent.com/violin-suzutsuki/LinoriaLib/main/'

local Library = loadstring(game:HttpGet(repo .. 'Library.lua'))()
local ThemeManager = loadstring(game:HttpGet(repo .. 'addons/ThemeManager.lua'))()
local SaveManager = loadstring(game:HttpGet(repo .. 'addons/SaveManager.lua'))()

-- Services
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local CollectionService = game:GetService("CollectionService")
local NetworkClient = game:GetService("NetworkClient")
local CoreGui = game:GetService("CoreGui")

-- Variables
local LocalPlayer = Players.LocalPlayer
local Character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
local Mouse = LocalPlayer:GetMouse()
local Camera = workspace.CurrentCamera

local savedFogSettings = {
    Atmosphere = nil,
    FogEnd = nil,
    FogStart = nil,
    FogColor = nil
}

-- Create Window and Tabs
local Window = Library:CreateWindow({
    Title = 'SMAX hub',
    Center = true, 
    AutoShow = true, -- Changed from false to true
    TabPadding = 8,
    MenuFadeTime = 0.1
})

-- Set default toggle key to ALT
Library.ToggleKeybind = Options.MenuKeybind or 'LeftAlt'

local Tabs = {
    Main = Window:AddTab('Main'),
    Player = Window:AddTab('Player'),
    ESP = Window:AddTab('ESP'),
    Teleport = Window:AddTab('Teleport'),
    ['UI Settings'] = Window:AddTab('UI Settings'),
}

-- Create Main GroupBox
local MainBox = Tabs.Main:AddLeftGroupbox('Utilities')

-- Add Safe Location Teleport Button
MainBox:AddButton('Teleport to Safe Location', function()
    if LocalPlayer.Character then
        LocalPlayer.Character:PivotTo(SAFE_LOCATION)
    end
end)

MainBox:AddButton('Reset Character and TP back', function()
    if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild('Humanoid') then
        -- Store current position
        local currentPosition = LocalPlayer.Character:GetPivot()
        
        -- Kill character
        LocalPlayer.Character.Humanoid.Health = 0
        
        -- Wait for respawn and restore position
        task.spawn(function()
            LocalPlayer.CharacterAdded:Wait()
            task.wait(0.5) -- Wait for character to load
            if LocalPlayer.Character then
                LocalPlayer.Character:PivotTo(currentPosition)
            end
        end)
    end
end)

-- ESP Settings
local ESPSettings = Tabs.ESP:AddLeftGroupbox('ESP Settings')
local ESPCustomization = Tabs.ESP:AddRightGroupbox('ESP Customization')
local espRange = 50000
local rainbowConnection = nil

-- ESP Variables
local entityEspList = {}
local maid = {
    _tasks = {},
    
    GiveTask = function(self, task)
        table.insert(self._tasks, task)
        return task
    end,
    
    DoCleaning = function(self)
        for _, task in pairs(self._tasks) do
            if typeof(task) == "RBXScriptConnection" then
                task:Disconnect()
            elseif typeof(task) == "function" then
                task()
            elseif task.Destroy then
                task:Destroy()
            end
        end
        table.clear(self._tasks)
    end
}

-- Create GroupBoxes
local MovementBox = Tabs.Player:AddLeftGroupbox('Movement')
local StaminaBox = Tabs.Player:AddRightGroupbox('Stamina')
local ChestFarmBox = Tabs.Main:AddLeftGroupbox('Chest Farm')
local CombatBox = Tabs.Main:AddLeftGroupbox('Combat')

-- Default Values
local DEFAULT_SPEED = 22
local DEFAULT_FLY_SPEED = 50
local DEFAULT_JUMP_POWER = 50

-- Movement Variables
local flying = false
local flyBv = nil
local activeKeys = {}
local flyConnection = nil
local currentFlySpeed = DEFAULT_FLY_SPEED
local speedHackConnection = nil
local noclipping = false
local noclipConnection = nil

-- Combat Variables
local isAuraEnabled = false
local isSpamming = false
local isFarming = false
local radius = 100
local damageCount = 10
local hitDelay = 0.01
local spamCount = 10
local spamDelay = 0.001

-- Add these variables at the top with other variables
local isFarmingMobs = false
local isChestFarming = false
local mobFarmLoop = nil
local chestFarmLoop = nil
local selectedMobs = {} -- Add this to store selected mobs

-- Add list of mod UserIDs
local modUserIds = {
    32722169, 
    67868033, 
    2739355705, 
    76999375
}

-- Add with other functions
local function isModInGame()
    for _, player in ipairs(Players:GetPlayers()) do
        if table.find(modUserIds, player.UserId) then
            return true
        end
    end
    return false
end

-- Add server hop check function
local function checkForMods()
    task.spawn(function()
        while true do
            if isModInGame() then
                print('mod detected!')
                -- Wait for any effects to clear (like in DeepWoken)
                task.wait(0.1)
                LocalPlayer:Kick('')
                functions.serverHop(true)
                return
            elseif not NetworkClient:FindFirstChild('ClientReplicator') then
                functions.serverHop(true)
            end
            task.wait(1)
        end
    end)
end

-- Add to your initialization code
checkForMods()

-- Modify your existing serverHop function
local function serverHop(instant)
    local PlaceId = game.PlaceId
    
    -- Get server list
    local success, servers = pcall(function()
        return game:GetService("HttpService"):JSONDecode(
            game:HttpGet(
                "https://games.roblox.com/v1/games/"..PlaceId.."/servers/Public?sortOrder=Desc&limit=50"
            )
        ).data
    end)
    
    if not success or not servers then 
        TeleportService:Teleport(PlaceId)
        return
    end
    
    -- Find a different server
    for _, server in ipairs(servers) do
        if server.playing < server.maxPlayers and server.id ~= game.JobId then
            -- Try to teleport to the server
            local success, result = pcall(function()
                return TeleportService:TeleportToPlaceInstance(PlaceId, server.id)
            end)
            
            if success then
                return
            end
        end
    end
    
    -- If no suitable server found, let Roblox handle it
    TeleportService:Teleport(PlaceId)
end

-- Chest Farm Logic
local function GetAllChests()
    local chestList = {}
    for _, chest in pairs(workspace.FX:GetChildren()) do
        if chest:IsA("Model") then
            table.insert(chestList, chest)
        end
    end
    return chestList
end

local function OpenChest(prompt)
    prompt:InputHoldBegin()
    wait(4)
    prompt:InputHoldEnd() 
end

-- Update the auto-farm for mobs function
local function stopMobFarm()
    isFarmingMobs = false
    if mobFarmLoop then
        mobFarmLoop:Disconnect()
        mobFarmLoop = nil
    end
end

local function autoFarmMobs()
    if isFarmingMobs then return end
    isFarmingMobs = true
    
    task.spawn(function()
        while isFarmingMobs do
            task.wait()
            if not LocalPlayer.Character or not LocalPlayer.Character:FindFirstChild("Humanoid") then continue end
            if LocalPlayer.Character.Humanoid.Health <= 0 then continue end

            local mobList = {}
            for mobName, isSelected in pairs(selectedMobs) do
                if isSelected then
                    table.insert(mobList, mobName)
                end
            end

            if #mobList > 0 then
                local spawnedEntities = workspace:FindFirstChild("SpawnedEntities")
                if spawnedEntities then
                    for _, obj in pairs(spawnedEntities:GetChildren()) do
                        if not isFarmingMobs then break end
                        if table.find(mobList, obj.Name) then
                            if obj:FindFirstChild("Humanoid") and obj:FindFirstChild("HumanoidRootPart") and obj.Humanoid.Health > 0 then
                                -- Farm logic here
                                task.wait(0.1)
                            end
                        end
                    end
                end
            end
        end
    end)
end

-- Update the chest farm function
local function stopChestFarm()
    isChestFarming = false
    if chestFarmLoop then
        chestFarmLoop:Disconnect()
        chestFarmLoop = nil
    end
end

local function TeleportAndFarmChests()
    stopChestFarm() -- Clear any existing loop
    
    isChestFarming = true
    chestFarmLoop = RunService.Heartbeat:Connect(function()
        if not isChestFarming then
            stopChestFarm()
            return
        end

        local chests = GetAllChests()
        if #chests > 0 then
            for _, chest in pairs(chests) do
                if not isChestFarming then return end
                if chest and chest:IsA("Model") then
                    local chestPos = chest:GetPivot().Position
                    Character.HumanoidRootPart.CFrame = CFrame.new(chestPos + Vector3.new(0, 3, 0))
                    wait(0.1)
                    local prompt = chest:FindFirstChildWhichIsA("ProximityPrompt", true)
                    if prompt then
                        OpenChest(prompt)
                        wait(0.5) 
                    end
                end
            end
        end
        wait(1)
    end)
end

-- Fly Logic
local function fly(toggle)
    local rootPart = Character:WaitForChild("HumanoidRootPart")
    local humanoid = Character:WaitForChild("Humanoid")

    local function enableFly()
        if not rootPart then return end
        
        if flyBv then
            flyBv:Destroy()
        end
        
        if flyConnection then
            flyConnection:Disconnect()
        end
        
        flyBv = Instance.new("BodyVelocity")
        flyBv.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
        
        if not CollectionService:HasTag(flyBv, "AllowedBM") then
            CollectionService:AddTag(flyBv, "AllowedBM")
        end
        
        flyBv.Parent = rootPart

        flyConnection = RunService.Heartbeat:Connect(function()
            if humanoid and rootPart then
                local moveDirection = Vector3.new(0, 0, 0)
                if activeKeys[Enum.KeyCode.W] then
                    moveDirection = moveDirection + Camera.CFrame.LookVector
                end
                if activeKeys[Enum.KeyCode.S] then
                    moveDirection = moveDirection - Camera.CFrame.LookVector
                end
                if activeKeys[Enum.KeyCode.A] then
                    moveDirection = moveDirection - Camera.CFrame.RightVector
                end
                if activeKeys[Enum.KeyCode.D] then
                    moveDirection = moveDirection + Camera.CFrame.RightVector
                end
                if activeKeys[Enum.KeyCode.Space] then
                    moveDirection = moveDirection + Vector3.new(0, 1, 0)
                end
                if activeKeys[Enum.KeyCode.LeftShift] then
                    moveDirection = moveDirection - Vector3.new(0, 1, 0)
                end
                
                if moveDirection.Magnitude > 0 then
                    moveDirection = moveDirection.Unit
                end
                
                flyBv.Velocity = moveDirection * currentFlySpeed
            end
        end)
    end

    local function disableFly()
        if flyConnection then
            flyConnection:Disconnect()
            flyConnection = nil
        end
        
        if flyBv then
            flyBv:Destroy()
            flyBv = nil
        end
        
        if humanoid then
            humanoid.PlatformStand = false
        end
    end

    if toggle then
        if not flying then
            flying = true
            enableFly()
        end
    else
        if flying then
            flying = false
            disableFly()
        end
    end
end

-- Speed Logic
local function speedHack(toggle)
    local rootPart = Character:WaitForChild("HumanoidRootPart")
    local humanoid = Character:WaitForChild("Humanoid")

    local function enableSpeedHack()
        if not humanoid or not rootPart then return end
        
        if speedHackConnection then
            speedHackConnection:Disconnect()
            speedHackConnection = nil
        end
        
        local speedHackBv = Instance.new("BodyVelocity")
        speedHackBv.MaxForce = Vector3.new(100000, 0, 100000)
        speedHackBv.Parent = rootPart

        speedHackConnection = RunService.Heartbeat:Connect(function()
            local currentSpeed = toggle and Options.SpeedSlider.Value or DEFAULT_SPEED
            
            if humanoid.MoveDirection.Magnitude ~= 0 then
                speedHackBv.Velocity = humanoid.MoveDirection * currentSpeed
            else
                speedHackBv.Velocity = Vector3.new(0, 0, 0)
            end
        end)
    end

    local function disableSpeedHack()
        if speedHackConnection then
            speedHackConnection:Disconnect()
            speedHackConnection = nil
        end
        
        for _, instance in ipairs(rootPart:GetChildren()) do
            if instance:IsA("BodyVelocity") then
                instance:Destroy()
            end
        end
        
        if humanoid then
            humanoid.WalkSpeed = DEFAULT_SPEED
        end
    end

    if toggle then
        enableSpeedHack()
    else
        disableSpeedHack()
    end
end

-- Jump Logic
local function jumpHack(toggle, jumpHeight)
    local humanoid = Character:WaitForChild("Humanoid")
    if toggle then
        humanoid.JumpPower = jumpHeight
    else
        humanoid.JumpPower = DEFAULT_JUMP_POWER
    end
end

-- Noclip Logic
local function noClip(toggle)
    -- Clean up existing connection
    if noclipConnection then
        noclipConnection:Disconnect()
        noclipConnection = nil
    end

    if not toggle then
        -- Restore default collision when turned off
        local character = LocalPlayer.Character
        if character then
            for _, part in ipairs(character:GetDescendants()) do
                if part:IsA("BasePart") then
                    part.CanCollide = true
                end
            end
        end
        return
    end

    -- Create new noclip connection
    noclipConnection = RunService.Heartbeat:Connect(function()
        local character = LocalPlayer.Character
        if not character then return end
        
        for _, part in ipairs(character:GetDescendants()) do
            if part:IsA("BasePart") then
                part.CanCollide = false
            end
        end
    end)
end

-- Infinite Stamina Logic
local staminaConnection = nil  -- Add this at the top with other variables

local function infiniteStamina(toggle)
    local Stamina = Character:WaitForChild("Values"):WaitForChild("Stamina")
    local defaultMaxStamina = Stamina:GetAttribute("Max")
    
    if toggle then
        -- Enable infinite stamina
        if staminaConnection then
            staminaConnection:Disconnect()
        end
        
        staminaConnection = RunService.Heartbeat:Connect(function()
            Stamina.Value = defaultMaxStamina
        end)
    else
        -- Disable infinite stamina and reset to normal
        if staminaConnection then
            staminaConnection:Disconnect()
            staminaConnection = nil
        end
        -- Let the game handle stamina naturally
        Stamina.Value = defaultMaxStamina
    end
end

-- Modify the Stamina toggle
StaminaBox:AddToggle('StaminaToggle', {
    Text = 'Infinite Stamina',
    Default = false,
    Tooltip = 'Never run out of stamina',
    Callback = function(Value)
        infiniteStamina(Value)
    end
})

-- Kill Aura Logic
local EntityHit = ReplicatedStorage:WaitForChild("PlayerEvents"):WaitForChild("EntityHit")

local function isValidMob(entity)
    return entity:IsA("Model") and entity:FindFirstChild("Humanoid") and entity:FindFirstChild("HumanoidRootPart")
end

local function applyKillAura()
    for _, entity in ipairs(workspace.SpawnedEntities:GetChildren()) do
        if isValidMob(entity) then
            local distance = (entity.HumanoidRootPart.Position - Character.HumanoidRootPart.Position).magnitude
            if distance <= radius then
                for i = 1, damageCount do
                    EntityHit:FireServer(entity)
                    wait(hitDelay)
                end
            end
        end
    end
end

-- Modified Fog Toggle Function
local function toggleFog(remove)
    local lighting = game:GetService("Lighting")
    
    if remove then
        -- Save current fog settings before removing
        savedFogSettings.FogEnd = lighting.FogEnd
        savedFogSettings.FogStart = lighting.FogStart
        savedFogSettings.FogColor = lighting.FogColor
        
        if lighting:FindFirstChild("Atmosphere") then
            savedFogSettings.Atmosphere = lighting.Atmosphere:Clone()
            lighting.Atmosphere:Destroy()
        end
        
        -- Remove fog
        lighting.FogEnd = 1000000
        lighting.FogStart = 1000000
    else
        -- Restore previous fog settings
        if savedFogSettings.FogEnd then
            lighting.FogEnd = savedFogSettings.FogEnd
        end
        if savedFogSettings.FogStart then
            lighting.FogStart = savedFogSettings.FogStart
        end
        if savedFogSettings.FogColor then
            lighting.FogColor = savedFogSettings.FogColor
        end
        if savedFogSettings.Atmosphere then
            savedFogSettings.Atmosphere.Parent = lighting
        end
    end
end

-- Staff Spam Logic
local StaffAttack = ReplicatedStorage.PlayerEvents.WeaponClassEvents.StaffAttack

local function spamStaffAttack()
    while isSpamming do
        for i = 1, spamCount do
            StaffAttack:FireServer(Character.HumanoidRootPart.CFrame, Mouse.Hit.Position)
            wait(spamDelay)
        end
        wait()
    end
end

-- Add this to the existing ESP core functions
local function updateESP(player, espData)
    if not player or not player.Character then return end
    local character = player.Character
    local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
    local humanoid = character:FindFirstChild("Humanoid")
    if not humanoidRootPart or not humanoid then return end

    -- Update highlight
    local highlight = character:FindFirstChild("ESPHighlight")
    if not highlight and Library.flags.ESPEnabled then
        highlight = Instance.new("Highlight")
        highlight.Name = "ESPHighlight"
        highlight.FillColor = Library.flags.enemyColor or Color3.fromRGB(255, 0, 0)
        highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
        highlight.FillTransparency = 0.5
        highlight.OutlineTransparency = 0
        highlight.Parent = character
    end

    if highlight then
        highlight.Enabled = Library.flags.ESPEnabled
        
        -- Update ESP features based on toggles
        if Library.flags.ESPTeamColor and player.Team then
            highlight.FillColor = player.Team.TeamColor.Color
        elseif Library.flags.rainbowESP then
            highlight.FillColor = Library.chromaColor
        else
            highlight.FillColor = Library.flags.enemyColor
        end
        
        -- Handle name ESP
        local nameLabel = character:FindFirstChild("ESPNameLabel")
        if Library.flags.ESPNames then
            if not nameLabel then
                nameLabel = Instance.new("BillboardGui")
                nameLabel.Name = "ESPNameLabel"
                nameLabel.Size = UDim2.new(0, 200, 0, 50)
                nameLabel.AlwaysOnTop = true
                nameLabel.Parent = character
                
                local textLabel = Instance.new("TextLabel")
                textLabel.BackgroundTransparency = 1
                textLabel.Size = UDim2.new(1, 0, 1, 0)
                textLabel.Text = player.Name
                textLabel.TextColor3 = Color3.new(1, 1, 1)
                textLabel.TextScaled = true
                textLabel.Parent = nameLabel
            end
            nameLabel.Enabled = true
        elseif nameLabel then
            nameLabel.Enabled = false
        end
    end
end

local function createPlayerESP(player)
    if player == LocalPlayer then return end
    
    local function updateESP()
        if not player or not player.Character or not LocalPlayer.Character then return end
        local character = player.Character
        local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
        local humanoid = character:FindFirstChild("Humanoid")
        local localRoot = LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        if not humanoidRootPart or not humanoid or not localRoot then return end

        -- Calculate distance
        local distance = (humanoidRootPart.Position - localRoot.Position).Magnitude
        if distance > espRange then
            local highlight = character:FindFirstChild("ESPHighlight")
            if highlight then highlight.Enabled = false end
            local nameLabel = character:FindFirstChild("ESPNameLabel")
            if nameLabel then nameLabel.Enabled = false end
            return
        end

        -- Update ESP objects
        local highlight = character:FindFirstChild("ESPHighlight")
        if not highlight and Toggles.ESPEnabled and Toggles.ESPEnabled.Value then
            highlight = Instance.new("Highlight")
            highlight.Name = "ESPHighlight"
            highlight.FillColor = Options.enemyColor and Options.enemyColor.Value or Color3.fromRGB(255, 0, 0)
            highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
            highlight.FillTransparency = 0.5
            highlight.OutlineTransparency = 0
            highlight.Parent = character
        end

        if highlight then
            highlight.Enabled = Toggles.ESPEnabled and Toggles.ESPEnabled.Value
            if Options.enemyColor then
                highlight.FillColor = Options.enemyColor.Value
            end

            -- Handle name and distance ESP
            if (Toggles.ESPNames and Toggles.ESPNames.Value) or (Toggles.ShowStuds and Toggles.ShowStuds.Value) then
                local nameLabel = character:FindFirstChild("ESPNameLabel")
                if not nameLabel then
                    nameLabel = Instance.new("BillboardGui")
                    nameLabel.Name = "ESPNameLabel"
                    nameLabel.Size = UDim2.new(0, 100, 0, 40) -- Increased height for distance
                    nameLabel.AlwaysOnTop = true
                    nameLabel.StudsOffset = Vector3.new(0, 2, 0)
                    nameLabel.Parent = character

                    -- Name label
                    local textLabel = Instance.new("TextLabel")
                    textLabel.Name = "NameLabel"
                    textLabel.BackgroundTransparency = 1
                    textLabel.Size = UDim2.new(1, 0, 0.5, 0)
                    textLabel.Position = UDim2.new(0, 0, 0, 0)
                    textLabel.Text = player.Name
                    textLabel.TextColor3 = Color3.new(1, 1, 1)
                    textLabel.TextStrokeTransparency = 0
                    textLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
                    textLabel.Font = Enum.Font.Gotham
                    textLabel.TextSize = 14
                    textLabel.Parent = nameLabel

                    -- Distance label
                    local distanceLabel = Instance.new("TextLabel")
                    distanceLabel.Name = "DistanceLabel"
                    distanceLabel.BackgroundTransparency = 1
                    distanceLabel.Size = UDim2.new(1, 0, 0.5, 0)
                    distanceLabel.Position = UDim2.new(0, 0, 0.5, 0)
                    distanceLabel.TextColor3 = Color3.new(1, 1, 1)
                    distanceLabel.TextStrokeTransparency = 0
                    distanceLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
                    textLabel.Font = Enum.Font.Gotham
                    distanceLabel.TextSize = 12
                    distanceLabel.Parent = nameLabel
                end

                nameLabel.Enabled = true
                local nameText = nameLabel:FindFirstChild("NameLabel")
                local distanceText = nameLabel:FindFirstChild("DistanceLabel")

                if nameText then
                    nameText.Visible = Toggles.ESPNames.Value
                    nameText.Text = player.Name
                end

                if distanceText then
                    distanceText.Visible = Toggles.ShowStuds.Value
                    if Toggles.ShowStuds.Value then
                        distanceText.Text = string.format("[%d studs]", math.floor(distance))
                    end
                end
            else
                local nameLabel = character:FindFirstChild("ESPNameLabel")
                if nameLabel then
                    nameLabel.Enabled = false
                end
            end
        end
    end

    -- Connect update function
    local connection = RunService.RenderStepped:Connect(updateESP)
    table.insert(entityEspList, {
        player = player,
        connection = connection,
        cleanup = function()
            if connection then connection:Disconnect() end
            local highlight = player.Character and player.Character:FindFirstChild("ESPHighlight")
            if highlight then highlight:Destroy() end
            local nameLabel = player.Character and player.Character:FindFirstChild("ESPNameLabel")
            if nameLabel then nameLabel:Destroy() end
        end
    })
end

-- ESP Toggle (Modified)
ESPSettings:AddToggle('ESPEnabled', {
    Text = 'Toggle ESP',
    Default = false,
    Callback = function(Value)
        if not Value then
            for _, esp in pairs(entityEspList) do
                esp.cleanup()
            end
            table.clear(entityEspList)
        else
            for _, player in pairs(Players:GetPlayers()) do
                if player ~= LocalPlayer then
                    createPlayerESP(player)
                end
            end
        end
    end
})
ESPSettings:AddSlider('ESPRangeSlider', {
    Text = 'ESP Range',
    Default = 10000, -- Changed default to 10k
    Min = 10,
    Max = 50000,    -- Keep max at 50k
    Rounding = 0,
    Tooltip = 'Maximum distance to show ESP'
})
Options.ESPRangeSlider:OnChanged(function(value)
    espRange = value
end)

ESPSettings:AddToggle('ESPNames', {
    Text = 'Show Names',
    Default = false,
    Tooltip = 'Display player names'
})

ESPSettings:AddToggle('ShowStuds', {
    Text = 'Show Distance',
    Default = false,
    Tooltip = 'Display distance in studs'
})

-- Update ESPCustomization section
ESPCustomization:AddToggle('rainbowESP', {
    Text = 'Rainbow ESP',
    Default = false,
    Tooltip = 'Cycle through colors',
    Callback = function(Value)
        updateRainbowESP()
    end
})

ESPCustomization:AddLabel('ESP Color'):AddColorPicker('enemyColor', {
    Default = Color3.fromRGB(255, 0, 0),
    Title = 'ESP Color'
})


-- Player Connections
Players.PlayerAdded:Connect(function(player)
    if Library.flags.ESPEnabled then
        createPlayerESP(player)
    end
end)

Players.PlayerRemoving:Connect(function(player)
    for i, esp in pairs(entityEspList) do
        if esp.player == player then
            esp.cleanup()
            table.remove(entityEspList, i)
            break
        end
    end
end

-- Create UI Elements for Movement
MovementBox:AddToggle('FlyToggle', {
    Text = 'Flight',
    Default = false,
    Tooltip = 'Enables flight',
    Callback = function(Value)
        fly(Value)
    end
})

MovementBox:AddSlider('FlySpeedSlider', {
    Text = 'Flight Speed',
    Default = DEFAULT_FLY_SPEED,
    Min = 0,
    Max = 500,
    Rounding = 0,
    Tooltip = 'Adjust your flight speed'
})

Options.FlySpeedSlider:OnChanged(function(value)
    currentFlySpeed = value
end)

MovementBox:AddToggle('SpeedToggle', {
    Text = 'Speed Hack',
    Default = false,
    Tooltip = 'Enables speed hack',
    Callback = function(Value)
        speedHack(Value)
    end
})

MovementBox:AddSlider('SpeedSlider', {
    Text = 'Speed Value',
    Default = DEFAULT_SPEED,
    Min = DEFAULT_SPEED,
    Max = 500,
    Rounding = 0,
    Tooltip = 'Adjust your speed'
})

MovementBox:AddToggle('JumpToggle', {
    Text = 'Jump Hack',
    Default = false,
    Tooltip = 'Enables jump hack'
})

MovementBox:AddSlider('JumpSlider', {
    Text = 'Jump Height',
    Default = DEFAULT_JUMP_POWER,
    Min = DEFAULT_JUMP_POWER,
    Max = 500,
    Rounding = 0,
    Tooltip = 'Adjust your jump height'
})

MovementBox:AddToggle('NoClip', {
    Text = 'NoClip',
    Default = false,
    Tooltip = 'Allows you to walk through walls',
    Callback = function(Value)
        noClip(Value)
    end
})

MovementBox:AddLabel('Note: If noclip bugs you after\ndisable, just reset')

-- Create UI Elements for Combat
CombatBox:AddToggle('KillAuraToggle', {
    Text = 'Kill Aura',
    Default = false,
    Tooltip = 'Automatically attacks nearby entities',
    Callback = function(Value)
        isAuraEnabled = Value
        if Value then
            task.spawn(function()
                while isAuraEnabled do
                    applyKillAura()
                    wait(0.5)
                end
            end)
        end
    end
})

local VisualsBox = Tabs.Player:AddRightGroupbox('Visuals')

VisualsBox:AddToggle('RemoveFogToggle', {
    Text = 'Remove Fog',
    Default = false,
    Tooltip = 'Removes fog from the game',
    Callback = function(Value)
        toggleFog(Value)
    end
})

CombatBox:AddToggle('StaffSpamToggle', {
    Text = 'Staff Spam',
    Default = false,
    Tooltip = 'Rapidly fires staff attacks',
    Callback = function(Value)
        isSpamming = Value
        if Value then
            task.spawn(spamStaffAttack)
        end
    end
})

-- Create UI Elements for Chest Farm
ChestFarmBox:AddToggle('ChestFarmToggle', {
    Text = 'Auto Chest Farm',
    Default = false,
    Tooltip = 'Automatically collects chests in the game',
    Callback = function(Value)
        isChestFarming = Value
        if Value then
            TeleportAndFarmChests()
        end
    end
})

-- Connect jump toggle and slider
Toggles.JumpToggle:OnChanged(function()
    jumpHack(Toggles.JumpToggle.Value, Options.JumpSlider.Value)
end)

Options.JumpSlider:OnChanged(function()
    if Toggles.JumpToggle.Value then
        jumpHack(true, Options.JumpSlider.Value)
    end
end)

-- Input Handling
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.UserInputType == Enum.UserInputType.Keyboard then
        activeKeys[input.KeyCode] = true
    end
end)

UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.Keyboard then
        activeKeys[input.KeyCode] = false
    end
end)

local function cleanupESP()
    for _, esp in pairs(entityEspList) do
        esp.cleanup()
    end
    table.clear(entityEspList)
end

local oldUnload = Library.Unload
Library.Unload = function(...)
    if rainbowConnection then
        rainbowConnection:Disconnect()
    end
    oldUnload(...)
end

-- Character Handling
LocalPlayer.CharacterAdded:Connect(function(newCharacter)
    Character = newCharacter
    
    -- Reset features if needed
    if Toggles.NoClip.Value then
        noClip(true)
    end
    if Toggles.SpeedToggle.Value then
        speedHack(true)
    end
    if Toggles.JumpToggle.Value then
        jumpHack(true, Options.JumpSlider.Value)
    end
    if Toggles.FlyToggle.Value then
        fly(true)
    end
end)

-- UI Settings
local MenuGroup = Tabs['UI Settings']:AddLeftGroupbox('Menu')

MenuGroup:AddButton('Unload', function() Library:Unload() end)
MenuGroup:AddLabel('Menu bind'):AddKeyPicker('MenuKeybind', { Default = 'LeftAlt', NoUI = true, Text = 'Menu keybind' })

Library.ToggleKeybind = Options.MenuKeybind

-- Theme and Save Manager Setup
ThemeManager:SetLibrary(Library)
SaveManager:SetLibrary(Library)

SaveManager:IgnoreThemeSettings()
SaveManager:SetIgnoreIndexes({ 'MenuKeybind' })

ThemeManager:SetFolder('MyScriptHub')
SaveManager:SetFolder('MyScriptHub/specific-game')

SaveManager:BuildConfigSection(Tabs['UI Settings'])
ThemeManager:ApplyToTab(Tabs['UI Settings'])

SaveManager:LoadAutoloadConfig()

-- Main tab groupboxes
local ServerHopBox = Tabs.Main:AddRightGroupbox('Server')

-- Server buttons remain the same
ServerHopBox:AddButton('Server Hop', function()
    serverHop()
end)

ServerHopBox:AddButton('Rejoin Server', function()
    if not game.PlaceId or not game.JobId then return end
    
    -- Simple rejoin attempt
    local success, error = pcall(function()
        TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId)
    end)
    
    if not success then
        warn("Failed to rejoin:", error)
        -- Fallback to regular teleport
        TeleportService:Teleport(game.PlaceId)
    end
end)

-- Add Mod Detection Toggle
local modDetectionConnection = nil
ServerHopBox:AddToggle('ModDetection', {
    Text = 'Auto Mod Detection',
    Default = false,
    Tooltip = 'Automatically server hops if a mod joins the game',
    Callback = function(Value)
        if Value then
            -- Start mod detection
            modDetectionConnection = task.spawn(function()
                while task.wait(1) do
                    if isModInGame() then
                        print('mod detected!')
                        task.wait(0.1)
                        LocalPlayer:Kick('')
                        serverHop(true)
                        return
                    elseif not NetworkClient:FindFirstChild('ClientReplicator') then
                        serverHop(true)
                    end
                end
            end)
        else
            -- Stop mod detection
            if modDetectionConnection then
                task.cancel(modDetectionConnection)
                modDetectionConnection = nil
            end
        end
    end
})

-- Add to cleanup
local oldUnload = Library.Unload
Library.Unload = function(...)
    if modDetectionConnection then
        task.cancel(modDetectionConnection)
        modDetectionConnection = nil
    end
    oldUnload(...)
end

-- Create the UI section
local MobFarmBox = Tabs.Main:AddLeftGroupbox('Mob Farming')

-- Function to get entity names
local function getEntityNames()
    local names = {}
    local entitySpawns = workspace:FindFirstChild("EntitySpawns")
    if entitySpawns then
        for _, folder in ipairs(entitySpawns:GetChildren()) do
            table.insert(names, folder.Name)
        end
    end
    table.sort(names)
    return #names > 0 and names or {"No entities found"}
end

-- Add the UI elements
MobFarmBox:AddDropdown('MobSelect', {
    Values = getEntityNames(),
    Default = 1,
    Multi = true,
    Text = 'Select Mobs',
    Tooltip = 'Choose mobs to farm'
})

-- Single variable to control farming
local isFarmingActive = false
local farmThread = nil

-- The actual farming function
local function farmMobs()
    local player = game.Players.LocalPlayer
    local character = player.Character
    
    -- Get selected mobs
    local selectedMobs = (Options.MobSelect and Options.MobSelect.Value) or {}
    local mobsList = {}
    for mobName, isSelected in pairs(selectedMobs) do
        if isSelected then
            table.insert(mobsList, mobName)
        end
    end
    
    -- Look for mobs
    local spawnedEntities = workspace:FindFirstChild("SpawnedEntities")
    if spawnedEntities then
        for _, mob in pairs(spawnedEntities:GetChildren()) do
            if table.find(mobsList, mob.Name) then
                if mob:FindFirstChild("HumanoidRootPart") and 
                   mob:FindFirstChild("Humanoid") and 
                   mob.Humanoid.Health > 0 then
                    
                    -- Keep teleporting to mob until it dies
                    repeat
                        character.HumanoidRootPart.CFrame = mob.HumanoidRootPart.CFrame * CFrame.new(0, 0, 3)
                        task.wait()
                    until not mob:FindFirstChild("Humanoid") or mob.Humanoid.Health <= 0
                end
            end
        end
    end
end

-- Add the toggle
MobFarmBox:AddToggle('AutoFarmMobs', {
    Text = 'Auto Farm Mobs',
    Default = false,
    Tooltip = 'Automatically farms selected mobs',
    Callback = function(Value)
        if Value then
            isFarmingActive = true
            farmThread = task.spawn(function()
                while isFarmingActive do
                    farmMobs()
                    task.wait()
                end
            end)
        else
            isFarmingActive = false
            if farmThread then
                task.cancel(farmThread)
                farmThread = nil
            end
        end
    end
})

-- Create Material Farm GroupBox
local MaterialFarmBox = Tabs.Main:AddRightGroupbox('Material Farm')

-- Variables for material farming
local isMaterialFarming = false
local farmThread = nil

-- Safe location CFrame
local SAFE_LOCATION = CFrame.new(-3130, 867, -171)

-- Function to get all available materials
local function getMaterialNames()
    local materials = {}
    local materialsFolder = workspace:FindFirstChild("Materials")
    
    if materialsFolder then
        for _, folder in pairs(materialsFolder:GetChildren()) do
            table.insert(materials, folder.Name)
        end
        table.sort(materials)
    end
    
    return materials
end

-- Material farming function
local function farmMaterials()
    while isMaterialFarming do
        local foundAnyMaterial = false
        
        for materialName, isSelected in pairs(Options.MaterialSelect.Value) do
            if not isMaterialFarming then break end
            if not isSelected then continue end
            
            local materialFolder = workspace.Materials:FindFirstChild(materialName)
            if materialFolder and #materialFolder:GetChildren() > 0 then
                local materials = materialFolder:GetChildren()
                
                -- Get random material
                local material = materials[math.random(1, #materials)]
                if material then
                    foundAnyMaterial = true
                    -- Get the model's CFrame
                    local modelCFrame = material:GetPivot()
                    
                    -- Teleport to material with offset
                    LocalPlayer.Character:PivotTo(modelCFrame * CFrame.new(0, 3, 0))
                    
                    -- Wait 0.7 seconds before pressing E
                    task.wait(0.7)
                    
                    -- Press E
                    game:GetService("VirtualInputManager"):SendKeyEvent(true, Enum.KeyCode.E, false, game)
                    task.wait(2.5)
                    game:GetService("VirtualInputManager"):SendKeyEvent(false, Enum.KeyCode.E, false, game)
                    
                    task.wait(Options.TeleportDelay.Value)
                end
            end
        end
    end
end

-- Add Material Select Dropdown
MaterialFarmBox:AddDropdown('MaterialSelect', {
    Values = getMaterialNames(),
    Default = 1,
    Multi = true,
    Text = 'Select Materials',
    Tooltip = 'Choose materials to farm'
})

-- Add Toggle for Material Farm
MaterialFarmBox:AddToggle('MaterialFarm', {
    Text = 'Auto Farm Materials',
    Default = false,
    Tooltip = 'Automatically farms selected materials',
    Callback = function(Value)
        isMaterialFarming = Value
        
        if Value then
            farmThread = task.spawn(farmMaterials)
        else
            if farmThread then
                task.cancel(farmThread)
                farmThread = nil
            end
        end
    end
})
-- Add to cleanup
local oldUnload = Library.Unload
Library.Unload = function(...)
    isMaterialFarming = false
    if farmThread then
        task.cancel(farmThread)
        farmThread = nil
    end
    oldUnload(...)
end

-- Proper cleanup
Library:OnUnload(function()
    Library.Unloaded = true
end)

-- Create Teleport GroupBox
local TeleportBox = Tabs.Teleport:AddLeftGroupbox('Regions')
local NPCBox = Tabs.Teleport:AddRightGroupbox('NPCs')
local LoadBox = Tabs.Teleport:AddLeftGroupbox('Load Regions')

-- Keep track of existing region names globally
local existingRegions = {}

-- Function to get all regions and create teleport buttons
local function setupTeleportButtons()
    print("Setting up region buttons...")
    
    local regionsFolder = workspace:FindFirstChild("Regions")
    if not regionsFolder then return end
    
    -- Check for new regions only
    for _, region in ipairs(regionsFolder:GetChildren()) do
        if region:IsA("BasePart") and not existingRegions[region.Name] then
            existingRegions[region.Name] = region.Position
            
            -- Add button for new region
            TeleportBox:AddButton({
                Text = region.Name,
                Func = function()
                    if LocalPlayer.Character then
                        -- Raycast to find ground
                        local raycastParams = RaycastParams.new()
                        raycastParams.FilterType = Enum.RaycastFilterType.Blacklist
                        raycastParams.FilterDescendantsInstances = {LocalPlayer.Character}
                        
                        local rayOrigin = region.Position + Vector3.new(0, 50, 0)
                        local rayResult = workspace:Raycast(rayOrigin, Vector3.new(0, -100, 0), raycastParams)
                        
                        local targetPosition
                        if rayResult then
                            -- If we hit ground, teleport slightly above it
                            targetPosition = rayResult.Position + Vector3.new(0, 2, 0)
                        else
                            -- If no ground found, use default offset
                            targetPosition = region.Position + Vector3.new(0, 2, 0)
                        end
                        
                        LocalPlayer.Character:PivotTo(CFrame.new(targetPosition))
                    end
                end
            })
        end
    end
end

-- Add Scan Regions button in a separate group
LoadBox:AddButton({
    Text = 'Scan for Regions',
    Func = function()
        print("Scanning for regions...")
        -- Store original position
        local originalCFrame = LocalPlayer.Character and LocalPlayer.Character:GetPivot()
        
        -- Generate 20 random positions
        local randomPositions = {}
        for i = 1, 20 do
            local randomDist = math.random(1000, 15000)
            local randomAngle = math.rad(math.random(1, 360))
            local randomHeight = math.random(300, 1500)
            
            -- Convert polar coordinates to Cartesian
            local x = randomDist * math.cos(randomAngle)
            local z = randomDist * math.sin(randomAngle)
            
            table.insert(randomPositions, Vector3.new(x, randomHeight, z))
        end
        
        -- First pass: Quick teleport to load all regions
        for _, position in ipairs(randomPositions) do
            if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
                LocalPlayer.Character:PivotTo(CFrame.new(position))
                task.wait(0.1)
            end
        end
        
        -- Return to original position
        if originalCFrame and LocalPlayer.Character then
            LocalPlayer.Character:PivotTo(originalCFrame)
        end
        
        task.wait(0.5)
        setupTeleportButtons()
    end
})

-- Function to setup NPC buttons
local function setupNPCButtons()
    print("Setting up NPC buttons...")
    
    -- Create a table to track unique NPC names
    local uniqueNPCs = {}
    local npcFolder = workspace:FindFirstChild("NPCs")
    
    if npcFolder then
        for _, npc in ipairs(npcFolder:GetChildren()) do
            if npc:IsA("Model") and not uniqueNPCs[npc.Name] then
                uniqueNPCs[npc.Name] = npc
                
                NPCBox:AddButton({
                    Text = npc.Name,
                    Func = function()
                        if LocalPlayer.Character then
                            local npcPart = npc:FindFirstChild("HumanoidRootPart") or npc:FindFirstChild("Torso") or npc:FindFirstChildWhichIsA("BasePart")
                            if npcPart then
                                LocalPlayer.Character:PivotTo(CFrame.new(npcPart.Position + Vector3.new(0, 3, 0)))
                            end
                        end
                    end
                })
            end
        end
    end
end

-- Only initialize NPC buttons
setupNPCButtons()

-- Add with other function declarations at the top
local noFallDamageConnection = nil  -- Store the connection globally

local function noFallDamage(toggle)
    -- Clean up existing connection if it exists
    if noFallDamageConnection then
        noFallDamageConnection:Disconnect()
        noFallDamageConnection = nil
    end
    
    -- Restore default states when turned off
    local character = LocalPlayer.Character
    if character then
        local humanoid = character:FindFirstChildWhichIsA('Humanoid')
        if humanoid then
            humanoid:SetStateEnabled(Enum.HumanoidStateType.FallingDown, true)
            humanoid:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, true)
        end
    end

    if not toggle then return end

    -- Create new connection when toggled on
    noFallDamageConnection = RunService.Heartbeat:Connect(function()
        local character = LocalPlayer.Character
        if not character then return end

        local humanoid = character:FindFirstChildWhichIsA('Humanoid')
        if not humanoid then return end

        -- Prevent fall damage states
        humanoid:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
        humanoid:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)

        -- Additional fall protection with faster fall
        local rootPart = character:FindFirstChild('HumanoidRootPart')
        if not rootPart then return end

        -- Allow faster falling but prevent lethal velocity
        if rootPart.Velocity.Y < -100 then
            rootPart.Velocity = Vector3.new(
                rootPart.Velocity.X,
                math.clamp(rootPart.Velocity.Y, -100, 0), -- Increased fall speed range
                rootPart.Velocity.Z
            )
        end

        -- Remove fall damage effects
        for _, effect in ipairs(character:GetChildren()) do
            if effect.Name:match("Fall") or effect.Name:match("Ragdoll") then
                effect:Destroy()
            end
        end
    end)
end

-- Add in the Stamina groupbox section
StaminaBox:AddToggle('NoFallDamage', {
    Text = 'No Fall Damage',
    Default = false,
    Tooltip = 'Prevents fall damage while maintaining realistic fall speed',
    Callback = noFallDamage
})

-- Cleanup on script unload
local oldUnload = Library.Unload
Library.Unload = function(...)
    if noFallDamageConnection then
        noFallDamageConnection:Disconnect()
        noFallDamageConnection = nil
    end
    oldUnload(...)
end

-- Add with other variables at the top
local FLYWOOD_FOREST_PLACE_ID = 16992122108

-- Add in the Server GroupBox
ServerHopBox:AddButton('Teleport to Flywood Forest', function()
    local success, error = pcall(function()
        TeleportService:Teleport(FLYWOOD_FOREST_PLACE_ID)
    end)
    
    if not success then
        warn("Failed to teleport:", error)
        -- Fallback to queue on teleport if direct teleport fails
        TeleportService:TeleportToPlaceInstance(FLYWOOD_FOREST_PLACE_ID, game.JobId)
    end
end)
