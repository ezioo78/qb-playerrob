local QBCore = exports['qb-core']:GetCoreObject()
local isRobbing = false

-- Debug command to check if script is loaded
RegisterCommand('checkrobbery', function()
    print('[DEBUG] qb-robbery: Client script is loaded!')
    QBCore.Functions.Notify('Robbery script client-side is loaded!', 'success')
    -- Check if server script is loaded
    TriggerServerEvent('qb-robbery:server:CheckLoaded')
end)

-- Debug info on resource start
AddEventHandler('onClientResourceStart', function(resourceName)
    if (GetCurrentResourceName() ~= resourceName) then return end
    print('[DEBUG] qb-robbery: Client resource started')
end)

-- Function to check if player meets the required conditions to rob someone
local function CanRobPlayer(targetId)
    local player = QBCore.Functions.GetPlayerData()
    local targetPlayer = GetPlayerFromServerId(targetId)
    
    -- Check if target exists and is within range
    if not targetPlayer then return false end
    
    local targetPed = GetPlayerPed(targetPlayer)
    local playerPed = PlayerPedId()
    local dist = #(GetEntityCoords(playerPed) - GetEntityCoords(targetPed))
    
    -- Distance check (2.0 units)
    if dist > 2.0 then
        QBCore.Functions.Notify('You are too far away from the target', 'error')
        return false
    end
    
    -- Check if target is handcuffed or surrendered
    local targetState = Entity(targetPed).state
    if not targetState.isHandcuffed and not targetState.handsup then
        QBCore.Functions.Notify('Target must be handcuffed or have their hands up', 'error')
        return false
    end
    
    -- Check if player has a weapon
    QBCore.Functions.TriggerCallback('qb-robbery:server:HasWeapon', function(hasWeapon, weaponName)
        if not hasWeapon then
            QBCore.Functions.Notify('You need a weapon to rob someone', 'error')
            return false
        else
            -- If we got here, all checks passed
            -- Continue with the robbery process
            isRobbing = true
            
            -- Animation for robbing
            TaskPlayAnim(PlayerPedId(), "mp_common", "givetake1_a", 8.0, -8.0, 2000, 0, 0, false, false, false)
            
            -- Trigger server event to start the robbery process
            TriggerServerEvent('qb-robbery:server:RobPlayer', targetId)
            
            -- Show what weapon was used
            QBCore.Functions.Notify('Robbing with: ' .. QBCore.Shared.Items[weaponName].label, 'primary')
        end
    end)
    
    return true
end

-- Command to rob a player
RegisterCommand('robplayer', function()
    if isRobbing then return end
    
    local closestPlayer, closestDistance = QBCore.Functions.GetClosestPlayer()
    if closestPlayer == -1 or closestDistance > 2.0 then
        QBCore.Functions.Notify('No one nearby to rob', 'error')
        return
    end
    
    local targetId = GetPlayerServerId(closestPlayer)
    CanRobPlayer(targetId)
end)

-- Event for checking hands up state
RegisterNetEvent('qb-robbery:client:SetHandsUp')
AddEventHandler('qb-robbery:client:SetHandsUp', function(state)
    local ped = PlayerPedId()
    Entity(ped).state:set('handsup', state, true)
end)

-- Key binding for hands up
RegisterCommand('+handsup', function()
    local ped = PlayerPedId()
    local prevState = Entity(ped).state.handsup or false
    
    if not prevState then
        Entity(ped).state:set('handsup', true, true)
        TriggerEvent('qb-robbery:client:SetHandsUp', true)
        
        -- Play hands up animation
        if not IsPedInAnyVehicle(ped, false) then
            TaskPlayAnim(ped, "missminuteman_1ig_2", "handsup_enter", 8.0, 8.0, -1, 50, 0, false, false, false)
        end
    end
end, false)

RegisterCommand('-handsup', function()
    local ped = PlayerPedId()
    Entity(ped).state:set('handsup', false, true)
    TriggerEvent('qb-robbery:client:SetHandsUp', false)
    
    -- Stop animation
    if not IsPedInAnyVehicle(ped, false) then
        ClearPedTasks(ped)
    end
end, false)

RegisterKeyMapping('+handsup', 'Put your hands up', 'keyboard', 'X')

RegisterNetEvent('qb-robbery:client:GetRobbed')
AddEventHandler('qb-robbery:client:GetRobbed', function(robberId)
    -- Animation for being robbed
    TaskPlayAnim(PlayerPedId(), "mp_common", "givetake1_a", 8.0, -8.0, 2000, 0, 0, false, false, false)
    
    -- Notify the player they're being robbed
    QBCore.Functions.Notify('You are being robbed!', 'error')
end)

-- Modified robbery stash approach - compatible with your qb-inventory
RegisterNetEvent('qb-robbery:client:OpenRobberyStash')
AddEventHandler('qb-robbery:client:OpenRobberyStash', function(targetId, targetName)
    local stashId = "robbery_" .. targetId
    
    -- Check if we're trying to open our own inventory
    local playerData = QBCore.Functions.GetPlayerData()
    if playerData.source == targetId then
        print('[DEBUG] Opening my own inventory - special handling')
    end
    
    -- Format data for the stash
    local data = {
        label = "Robbing " .. targetName,
        maxweight = Config.StashWeight,
        slots = Config.StashSlots,
    }
    
    print('[DEBUG] Opening robbery stash with ID:', stashId)
    -- Send to server to handle the inventory opening
    TriggerServerEvent('qb-robbery:server:OpenInventory', stashId, data)
end)

RegisterNetEvent('qb-robbery:client:RobberyComplete')
AddEventHandler('qb-robbery:client:RobberyComplete', function()
    isRobbing = false
    QBCore.Functions.Notify('Robbery complete', 'success')
end)

-- Key binding for the rob command (F5 by default, can be changed in settings)
RegisterKeyMapping('robplayer', 'Rob Closest Player', 'keyboard', 'F5')

-- ADMIN MENU INTEGRATION

-- This event will be called by the ps-adminmenu
RegisterNetEvent('qb-robbery:client:OpenTargetInventory')
AddEventHandler('qb-robbery:client:OpenTargetInventory', function(data)
    -- Extract the player ID from the admin menu dropdown
    local targetId = tonumber(data.Player)
    
    -- DEBUG: Log the received data
    print('[DEBUG] qb-robbery: Admin Menu triggered with data:', json.encode(data))
    print('[DEBUG] qb-robbery: Target player ID:', targetId)
    
    if not targetId then
        QBCore.Functions.Notify('Invalid player ID', 'error')
        print('[DEBUG] qb-robbery: Invalid player ID received')
        return
    end
    
    -- For admin purposes, we'll open the stash directly
    print('[DEBUG] qb-robbery: Requesting player name for ID:', targetId)
    QBCore.Functions.TriggerCallback('qb-robbery:server:GetPlayerName', function(targetName)
        if targetName then
            print('[DEBUG] qb-robbery: Got player name:', targetName)
            -- Use the stash approach for admin menu
            TriggerEvent('qb-robbery:client:OpenRobberyStash', targetId, targetName)
        else
            QBCore.Functions.Notify('Player not found', 'error')
            print('[DEBUG] qb-robbery: Player not found for ID:', targetId)
        end
    end, targetId)
end)

-- Command to test opening a specific player's inventory directly
-- Usage: /testinv [playerID]
RegisterCommand('testinv', function(source, args)
    if not args[1] then
        QBCore.Functions.Notify('Please specify a player ID', 'error')
        return
    end
    
    local targetId = tonumber(args[1])
    print('[DEBUG] qb-robbery: Testing inventory open for player ID:', targetId)
    
    -- Use the stash method
    QBCore.Functions.TriggerCallback('qb-robbery:server:GetPlayerName', function(targetName)
        if targetName then
            TriggerEvent('qb-robbery:client:OpenRobberyStash', targetId, targetName)
        else
            QBCore.Functions.Notify('Player not found', 'error')
        end
    end, targetId)
end)

-- Command to print all online players (for testing purposes)
RegisterCommand('listplayers', function()
    local players = GetActivePlayers()
    print('[DEBUG] qb-robbery: Online players:')
    
    for _, player in ipairs(players) do
        local serverId = GetPlayerServerId(player)
        local playerName = GetPlayerName(player)
        print('[DEBUG] qb-robbery: ID:', serverId, 'Name:', playerName)
        QBCore.Functions.Notify('ID: ' .. serverId .. ' Name: ' .. playerName, 'primary')
    end
end)

-- Test command for direct stash opening
RegisterCommand('teststash', function(source, args)
    if not args[1] then
        QBCore.Functions.Notify('Please specify a player ID', 'error')
        return
    end
    
    local targetId = tonumber(args[1])
    local stashName = "robbery_" .. targetId
    
    print('[DEBUG] Testing stash:', stashName)
    
    -- This follows your inventory's approach based on the script snippets
    local otherData = {
        maxweight = Config.StashWeight,
        slots = Config.StashSlots,
    }
    
    -- This method follows your provided stash script approach
    TriggerServerEvent('qb-robbery:server:OpenInventory', stashName, otherData)
end)

-- Event for radial menu integration
-- Event for radial menu integration - uses existing robplayer command
RegisterNetEvent('qb-robbery:client:AttemptRob')
AddEventHandler('qb-robbery:client:AttemptRob', function()
    -- Simply execute the existing rob command
    ExecuteCommand('robplayer')
end)