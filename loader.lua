-- Simple loader that starts the key system
local success, error = pcall(function()
    loadstring(game:HttpGet("https://raw.githubusercontent.com/Pedalkis123/SMAX-Script/main/keysystem.lua"))()
end)

if not success then
    warn("Failed to load script:", error)
end
