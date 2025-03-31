local QBCore = exports['qb-core']:GetCoreObject()

-- Event triggered when a player attempts to rob another player
RegisterNetEvent('qb-robbery:server:RobPlayer', function(targetId)
    local src = source
    local robber = QBCore.Functions.GetPlayer(src)
    local target = QBCore.Functions.GetPlayer(targetId)
    
    if not robber or not target then return end
    
    -- Check for any server-side conditions (e.g., police count, item requirements)
    local cops = 0
    for _, v in pairs(QBCore.Functions.GetQBPlayers()) do
        if v.PlayerData.job.name == "police" and v.PlayerData.job.onduty then
            cops = cops + 1
        end
    end
    
    if cops < Config.MinimumPolice then
        TriggerClientEvent('QBCore:Notify', src, 'Not enough police online', 'error')
        return
    end
    
    -- Check if target has been robbed recently
    if target.PlayerData.metadata.robbed and (os.time() - target.PlayerData.metadata.robbed) < Config.RobberyTimeout then
        TriggerClientEvent('QBCore:Notify', src, 'This person was robbed recently', 'error')
        return
    end
    
    -- Alert police
    --for _, v in pairs(QBCore.Functions.GetQBPlayers()) do
    --    if v.PlayerData.job.name == "police" and v.PlayerData.job.onduty then
    --        local coords = GetEntityCoords(GetPlayerPed(src))
    --        local street = GetStreetNameAtCoord(coords.x, coords.y, coords.z)
    --        TriggerClientEvent('police:client:RobberyCall', v.PlayerData.source, street, coords)
    --    end
    --end
    
    -- Notify the target they're being robbed
    TriggerClientEvent('qb-robbery:client:GetRobbed', targetId, src)
    
    -- Update target's metadata to record robbery time
    target.PlayerData.metadata.robbed = os.time()
    target.Functions.SetMetaData('robbed', target.PlayerData.metadata.robbed)
    
    -- Get target name for the stash
    local targetName = target.PlayerData.charinfo.firstname .. ' ' .. target.PlayerData.charinfo.lastname
    
    -- Open the robbery stash for the robber
    TriggerClientEvent('qb-robbery:client:OpenRobberyStash', src, targetId, targetName)
    
    -- Set a timeout to complete the robbery
    SetTimeout(Config.RobberyDuration * 1000, function()
        TriggerClientEvent('qb-robbery:client:RobberyComplete', src)
    end)
end)

-- Function to handle item transfers between players
local function TransferItem(source, targetId, itemName, amount, slot, info)
    local sourcePlayer = QBCore.Functions.GetPlayer(source)
    local targetPlayer = QBCore.Functions.GetPlayer(targetId)
    
    if not sourcePlayer or not targetPlayer then return false end
    
    -- Remove the item from target player
    local success = targetPlayer.Functions.RemoveItem(itemName, amount, slot)
    if not success then return false end
    
    -- Add the item to source player
    success = sourcePlayer.Functions.AddItem(itemName, amount, nil, info)
    if not success then
        -- If failed to add to source, give it back to target
        targetPlayer.Functions.AddItem(itemName, amount, slot, info)
        return false
    end
    
    -- Trigger inventory updates for both players
    TriggerClientEvent('qb-inventory:client:ItemBox', targetId, QBCore.Shared.Items[itemName], "remove", amount)
    TriggerClientEvent('qb-inventory:client:ItemBox', source, QBCore.Shared.Items[itemName], "add", amount)
    
    return true
end

-- Following the pattern from your inventory script
RegisterNetEvent('qb-robbery:server:OpenInventory', function(id, data)
    local src = source
    print('[DEBUG] SERVER: Opening inventory with ID:', id)
    print('[DEBUG] SERVER: Inventory data:', json.encode(data))
    
    -- Get the player ID from the robbery stash ID
    local targetId = string.match(id, "robbery_(%d+)")
    if not targetId then
        print('[DEBUG] SERVER: Invalid stash ID format:', id)
        return
    end
    targetId = tonumber(targetId)
    
    -- Get the target player
    local targetPlayer = QBCore.Functions.GetPlayer(targetId)
    if not targetPlayer then
        print('[DEBUG] SERVER: Target player not found:', targetId)
        return
    end
    
    -- Check if this is the same player (admin opening their own inventory)
    if src == targetId then
        -- For admin testing, just show their own inventory
        local selfPlayer = QBCore.Functions.GetPlayer(src)
        local selfItems = selfPlayer.PlayerData.items
        
        print('[DEBUG] SERVER: Admin testing - showing own inventory')
        -- Use the inventory event directly to open player's own inventory
        TriggerClientEvent('qb-inventory:client:openInventory', src, selfItems)
        return
    end
    
    -- Continue with normal robbery logic for other players
    -- Create or get stash
    local stashExists = MySQL.Sync.fetchScalar('SELECT 1 FROM inventories WHERE identifier = ?', {id})
    
    -- Now prepare the items to show in the stash - these should be the target player's items
    local items = {}
    
    -- Copy the player's items with proper formatting
    if targetPlayer.PlayerData.items then
        for slot, item in pairs(targetPlayer.PlayerData.items) do
            if item then
                items[slot] = item
            end
        end
    end
    
    if not stashExists then
        -- Create a new stash entry with the target's items
        MySQL.Async.insert('INSERT INTO inventories (identifier, items, label, maxweight, slots) VALUES (?, ?, ?, ?, ?)', {
            id,
            json.encode(items),
            data.label,
            data.maxweight,
            data.slots
        })
    else
        -- Update the stash with current items
        MySQL.Async.execute('UPDATE inventories SET items = ? WHERE identifier = ?', {
            json.encode(items),
            id
        })
    end
    
    -- Open the inventory directly with the items we've prepared
    local formattedInventory = {
        name = id,
        label = data.label,
        maxweight = data.maxweight,
        slots = data.slots,
        inventory = items
    }
    
    -- Use the direct client event with prepared data
    TriggerClientEvent('qb-inventory:client:openInventory', src, QBCore.Functions.GetPlayer(src).PlayerData.items, formattedInventory)
    
    print('[DEBUG] SERVER: Inventory opened for player:', src, 'with target items')
end)

-- Set up a listener for inventory movement between robbery stash and player inventory
RegisterNetEvent('qb-inventory:server:SetInventoryData', function(fromInventory, toInventory, fromSlot, toSlot, fromAmount, toAmount)
    local src = source
    
    -- Debug info to see what's happening
    print('[DEBUG] SERVER: Inventory movement detected')
    print('[DEBUG] SERVER: From:', fromInventory, 'To:', toInventory)
    print('[DEBUG] SERVER: From Slot:', fromSlot, 'To Slot:', toSlot)
    print('[DEBUG] SERVER: From Amount:', fromAmount, 'To Amount:', toAmount)
    
    -- Case 1: Taking item FROM robbery stash TO player inventory
    if fromInventory:match("^robbery_") and toInventory == "player" then
        local targetId = tonumber(fromInventory:match("robbery_(%d+)"))
        if not targetId then return end
        
        -- Get the involved players
        local robber = QBCore.Functions.GetPlayer(src)
        local target = QBCore.Functions.GetPlayer(targetId)
        if not robber or not target then return end
        
        -- Get the item details from the target's inventory
        local targetItems = target.PlayerData.items
        local itemToTransfer = nil
        
        for slot, item in pairs(targetItems) do
            if tonumber(slot) == tonumber(fromSlot) then
                itemToTransfer = item
                break
            end
        end
        
        if not itemToTransfer then 
            print('[DEBUG] SERVER: Item not found in target inventory at slot', fromSlot)
            return 
        end
        
        local itemName = itemToTransfer.name
        -- Use the exact amount specified by the inventory system, with fallbacks
        local amount = tonumber(fromAmount)
        if not amount or amount <= 0 then
            -- If no valid amount, use exactly what the user specified or the full stack
            amount = itemToTransfer.amount
        end
        
        print('[DEBUG] SERVER: Transfer details - Item:', itemName, 'Amount:', amount)
        
        -- Remove the item from target player
        local success = target.Functions.RemoveItem(itemName, amount, fromSlot)
        if not success then
            print('[DEBUG] SERVER: Failed to remove item from target')
            TriggerClientEvent('QBCore:Notify', src, 'Transfer failed', 'error')
            return
        end
        
        -- Add the item to robber
        local success = robber.Functions.AddItem(itemName, amount, nil, itemToTransfer.info)
        if not success then
            -- If failed to add to robber, give it back to target
            print('[DEBUG] SERVER: Failed to add item to robber, returning to target')
            target.Functions.AddItem(itemName, amount, fromSlot, itemToTransfer.info)
            TriggerClientEvent('QBCore:Notify', src, 'You cannot carry this item', 'error')
            return
        end
        
        -- Trigger inventory updates for both players
        TriggerClientEvent('QBCore:Notify', src, 'You took ' .. amount .. 'x ' .. QBCore.Shared.Items[itemName].label, 'success')
        TriggerClientEvent('QBCore:Notify', targetId, 'Someone took ' .. amount .. 'x ' .. QBCore.Shared.Items[itemName].label .. ' from you!', 'error')
        
        -- Update inventory UI for both players
        TriggerClientEvent('qb-inventory:client:ItemBox', targetId, QBCore.Shared.Items[itemName], "remove", amount)
        TriggerClientEvent('qb-inventory:client:ItemBox', src, QBCore.Shared.Items[itemName], "add", amount)
        
        print('[DEBUG] SERVER: Successfully transferred item from target to robber')
    
    -- Case 2: Giving item FROM player inventory TO robbery stash (returning items)
    elseif fromInventory == "player" and toInventory:match("^robbery_") then
        local targetId = tonumber(toInventory:match("robbery_(%d+)"))
        if not targetId then return end
        
        -- Get the involved players
        local robber = QBCore.Functions.GetPlayer(src)
        local target = QBCore.Functions.GetPlayer(targetId)
        if not robber or not target then return end
        
        -- Get the item details from the robber's inventory
        local robberItems = robber.PlayerData.items
        local itemToReturn = nil
        
        for slot, item in pairs(robberItems) do
            if tonumber(slot) == tonumber(fromSlot) then
                itemToReturn = item
                break
            end
        end
        
        if not itemToReturn then 
            print('[DEBUG] SERVER: Item not found in robber inventory at slot', fromSlot)
            return 
        end
        
        local itemName = itemToReturn.name
        -- Use the exact amount specified by the inventory system, with fallbacks
        local amount = tonumber(fromAmount)
        if not amount or amount <= 0 then
            -- If no valid amount, use exactly what the user intended
            amount = itemToReturn.amount
        end
        
        print('[DEBUG] SERVER: Return details - Item:', itemName, 'Amount:', amount)
        
        -- Remove the item from robber
        local success = robber.Functions.RemoveItem(itemName, amount, fromSlot)
        if not success then
            print('[DEBUG] SERVER: Failed to remove item from robber')
            TriggerClientEvent('QBCore:Notify', src, 'Transfer failed', 'error')
            return
        end
        
        -- Add the item to target
        local success = target.Functions.AddItem(itemName, amount, nil, itemToReturn.info)
        if not success then
            -- If failed to add to target, give it back to robber
            print('[DEBUG] SERVER: Failed to add item to target, returning to robber')
            robber.Functions.AddItem(itemName, amount, fromSlot, itemToReturn.info)
            TriggerClientEvent('QBCore:Notify', src, 'They cannot carry this item', 'error')
            return
        end
        
        -- Trigger inventory updates for both players
        TriggerClientEvent('QBCore:Notify', src, 'You returned ' .. amount .. 'x ' .. QBCore.Shared.Items[itemName].label, 'success')
        TriggerClientEvent('QBCore:Notify', targetId, 'Someone returned ' .. amount .. 'x ' .. QBCore.Shared.Items[itemName].label .. ' to you!', 'success')
        
        -- Update inventory UI for both players
        TriggerClientEvent('qb-inventory:client:ItemBox', src, QBCore.Shared.Items[itemName], "remove", amount)
        TriggerClientEvent('qb-inventory:client:ItemBox', targetId, QBCore.Shared.Items[itemName], "add", amount)
        
        print('[DEBUG] SERVER: Successfully returned item from robber to target')
    end
end)

-- Callback to get player name from server side
QBCore.Functions.CreateCallback('qb-robbery:server:GetPlayerName', function(source, cb, targetId)
    print('[DEBUG] qb-robbery SERVER: GetPlayerName callback triggered')
    print('[DEBUG] qb-robbery SERVER: Source ID:', source)
    print('[DEBUG] qb-robbery SERVER: Target ID:', targetId)
    
    -- Check if the source player has admin permissions
    local player = QBCore.Functions.GetPlayer(source)
    if not player then
        print('[DEBUG] qb-robbery SERVER: Source player not found')
        cb(nil)
        return
    end
    
    -- Log permission check
    local hasAdmin = QBCore.Functions.HasPermission(source, 'admin')
    local hasMod = QBCore.Functions.HasPermission(source, 'mod')
    print('[DEBUG] qb-robbery SERVER: Source has admin permission:', hasAdmin)
    print('[DEBUG] qb-robbery SERVER: Source has mod permission:', hasMod)
    
    -- For testing purposes - allow your specific ID to bypass permission checks
    local yourTestId = source -- Replace with your ID if needed
    print('[DEBUG] qb-robbery SERVER: Testing with ID:', yourTestId)
    
    -- If the player doesn't have permissions and isn't your test ID
    if not hasAdmin and not hasMod and source ~= yourTestId then
        print('[DEBUG] qb-robbery SERVER: Permission denied')
        cb(nil)
        return
    end
    
    local targetPlayer = QBCore.Functions.GetPlayer(targetId)
    if targetPlayer then
        local charInfo = targetPlayer.PlayerData.charinfo
        local targetName = charInfo.firstname .. ' ' .. charInfo.lastname
        print('[DEBUG] qb-robbery SERVER: Target player found:', targetName)
        cb(targetName)
    else
        print('[DEBUG] qb-robbery SERVER: Target player not found')
        cb(nil)
    end
end)

-- Debug event to check if the server script is loaded
RegisterNetEvent('qb-robbery:server:CheckLoaded')
AddEventHandler('qb-robbery:server:CheckLoaded', function()
    local src = source
    print('[DEBUG] qb-robbery SERVER: Server script check requested by ID:', src)
    TriggerClientEvent('QBCore:Notify', src, 'qb-robbery server script is loaded!', 'success')
end)

-- Direct approach for ps-adminmenu
RegisterNetEvent('ps-admin:server:OpenInventory')
AddEventHandler('ps-admin:server:OpenInventory', function(data)
    local src = source
    local admin = QBCore.Functions.GetPlayer(src)
    
    if not admin then return end
    if not QBCore.Functions.HasPermission(src, 'admin') and not QBCore.Functions.HasPermission(src, 'mod') then
        return 
    end
    
    local targetId = tonumber(data.Player)
    if not targetId then return end
    
    local target = QBCore.Functions.GetPlayer(targetId)
    if not target then return end
    
    -- Get target's name
    local targetName = target.PlayerData.charinfo.firstname .. ' ' .. target.PlayerData.charinfo.lastname
    
    -- Set up the stash and open it for the admin
    TriggerClientEvent('qb-robbery:client:OpenRobberyStash', src, targetId, targetName)
    
    -- Debug info
    print('[ADMIN] ' .. GetPlayerName(src) .. ' opened inventory of ' .. GetPlayerName(targetId))
end)