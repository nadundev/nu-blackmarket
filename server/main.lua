-- Nu-Blackmarket Server Script
-- Handles all server-side logic including purchases, validation, and inventory management

local currentStock = {}

-- Initialize stock levels from config
local function initializeStock()
    for categoryIndex, category in pairs(Config.Items) do
        for itemIndex, item in pairs(category.items) do
            local stockKey = category.category .. "_" .. item.name
            currentStock[stockKey] = item.stock
        end
    end
    if Config.Debug then
        lib.print.info("[Nu-Blackmarket] Stock initialized")
    end
end

-- Refresh stock based on config settings
local function refreshStock()
    if not Config.StockRefresh.enabled then return end
    
    for categoryIndex, category in pairs(Config.Items) do
        for itemIndex, item in pairs(category.items) do
            if item.stock > 0 then -- Only refresh limited stock items
                local stockKey = category.category .. "_" .. item.name
                local currentLevel = currentStock[stockKey] or 0
                local maxStock = item.stock
                local refreshAmount = math.floor(maxStock * Config.StockRefresh.percentage)
                
                currentStock[stockKey] = math.min(currentLevel + refreshAmount, maxStock)
            end
        end
    end
    
    if Config.Debug then
        lib.print.info("[Nu-Blackmarket] Stock refreshed")
    end
end

-- Get current stock for an item
local function getItemStock(category, itemName)
    local stockKey = category .. "_" .. itemName
    return currentStock[stockKey] or 0
end

-- Update stock for an item
local function updateItemStock(category, itemName, quantity)
    local stockKey = category .. "_" .. itemName
    if currentStock[stockKey] then
        currentStock[stockKey] = math.max(0, currentStock[stockKey] - quantity)
        return true
    end
    return false
end

-- Check if player has required job restrictions
local function checkJobRestrictions(source)
    if not Config.JobRestrictions or #Config.JobRestrictions == 0 then
        return true
    end
    
    local Player = exports.qbx_core:GetPlayer(source)
    if not Player then return false end
    
    local playerJob = Player.PlayerData.job.name
    
    -- Check if player's job is in the restricted list (blocked jobs)
    for _, restrictedJob in pairs(Config.JobRestrictions) do
        if playerJob == restrictedJob then
            return false
        end
    end
    
    return true
end

-- Check time restrictions
local function checkTimeRestrictions()
    if not Config.TimeRestrictions.enabled then
        return true
    end
    
    local currentHour = tonumber(os.date("%H"))
    local startHour = Config.TimeRestrictions.startHour
    local endHour = Config.TimeRestrictions.endHour
    
    if startHour > endHour then
        -- Overnight hours (e.g., 22:00 to 06:00)
        return currentHour >= startHour or currentHour <= endHour
    else
        -- Same day hours (e.g., 10:00 to 18:00)
        return currentHour >= startHour and currentHour <= endHour
    end
end

-- Get player money amount
local function getPlayerMoney(source, moneyType)
    if moneyType == "cash" or moneyType == "bank" or moneyType == "crypto" then
        -- Use Qbox export for standard money types
        local amount = exports.qbx_core:GetMoney(source, moneyType)
        return amount or 0
    else
        -- Custom item (like crypto)
        local itemCount = exports.ox_inventory:GetItemCount(source, moneyType)
        return itemCount or 0
    end
end

-- Remove money/currency from player
local function removePlayerMoney(source, moneyType, amount)
    if moneyType == "cash" or moneyType == "bank" or moneyType == "crypto" then
        -- Use Qbox export for standard money types
        return exports.qbx_core:RemoveMoney(source, moneyType, amount, "blackmarket-purchase")
    else
        -- Custom item (like crypto)
        return exports.ox_inventory:RemoveItem(source, moneyType, amount)
    end
end

-- Find item in config
local function findItemInConfig(itemName)
    for _, category in pairs(Config.Items) do
        for _, item in pairs(category.items) do
            if item.name == itemName then
                return item, category.category
            end
        end
    end
    return nil, nil
end

-- Send Discord webhook
local function sendWebhook(playerName, citizenid, items, totalCost)
    if not Config.Webhook.enabled or not Config.Webhook.url or Config.Webhook.url == "" then
        return
    end
    
    local itemsList = ""
    for _, item in pairs(items) do
        itemsList = itemsList .. "• " .. item.label .. " x" .. item.quantity .. " ($" .. (item.price * item.quantity) .. ")\n"
    end
    
    local embed = {
        {
            title = Config.Webhook.title,
            description = "**Player:** " .. playerName .. "\n**Citizen ID:** " .. citizenid .. "\n**Total Cost:** $" .. totalCost .. "\n\n**Items Purchased:**\n" .. itemsList,
            color = Config.Webhook.color,
            footer = {
                text = Config.Webhook.footer .. " • " .. os.date("%Y-%m-%d %H:%M:%S")
            }
        }
    }
    
    PerformHttpRequest(Config.Webhook.url, function(err, text, headers) end, "POST", json.encode({
        embeds = embed
    }), {
        ["Content-Type"] = "application/json"
    })
end


RegisterNetEvent("nu-blackmarket:server:requestOpenUI", function()
    local src = source
    local Player = exports.qbx_core:GetPlayer(src)
    if not Player then return end

    -- Check job restrictions
    if not checkJobRestrictions(src) then
        TriggerClientEvent("nu-blackmarket:client:openUIDenied", src, "Access denied due to job restrictions")
        return
    end

    -- Check time restrictions
    if not checkTimeRestrictions() then
        TriggerClientEvent("nu-blackmarket:client:openUIDenied", src, "Black market is closed at this time")
        return
    end

    -- Passed all checks, allow UI open
    TriggerClientEvent("nu-blackmarket:client:openUIAllowed", src)
end)

-- Register server events
RegisterNetEvent("nu-blackmarket:server:getStock", function()
    local source = source
    
    -- Send current stock levels and player money to client
    local stockData = {}
    for categoryIndex, category in pairs(Config.Items) do
        stockData[category.category] = {}
        for _, item in pairs(category.items) do
            stockData[category.category][item.name] = getItemStock(category.category, item.name)
        end
    end
    
    -- Get player money amount
    local moneyAmount = getPlayerMoney(source, Config.Currency.type)
    
    TriggerClientEvent("nu-blackmarket:client:receiveStock", source, stockData)
    TriggerClientEvent("nu-blackmarket:client:receivePlayerMoney", source, moneyAmount, Config.Currency.type)
end)

-- New event to get player money
RegisterNetEvent("nu-blackmarket:server:getPlayerMoney", function()
    local source = source
    local moneyAmount = getPlayerMoney(source, Config.Currency.type)
    
    TriggerClientEvent("nu-blackmarket:client:receivePlayerMoney", source, moneyAmount, Config.Currency.type)
end)

RegisterNetEvent("nu-blackmarket:server:purchaseItems", function(cartItems)
    local source = source
    local Player = exports.qbx_core:GetPlayer(source)
    
    if not Player then
        TriggerClientEvent("nu-blackmarket:client:purchaseResult", source, false, "Player data not found")
        return
    end
    
    -- Validate cart items
    if not cartItems or type(cartItems) ~= "table" or #cartItems == 0 then
        TriggerClientEvent("nu-blackmarket:client:purchaseResult", source, false, "Invalid cart data")
        return
    end
    
    -- Check job restrictions
    if not checkJobRestrictions(source) then
        TriggerClientEvent("nu-blackmarket:client:purchaseResult", source, false, "Access denied due to job restrictions")
        return
    end
    
    -- Check time restrictions
    if not checkTimeRestrictions() then
        TriggerClientEvent("nu-blackmarket:client:purchaseResult", source, false, "Black market is closed at this time")
        return
    end
    
    -- Validate cart items and calculate total cost
    local validatedItems = {}
    local totalCost = 0
    
    for _, cartItem in pairs(cartItems) do
        local configItem, category = findItemInConfig(cartItem.name)
        if not configItem then
            TriggerClientEvent("nu-blackmarket:client:purchaseResult", source, false, "Invalid item: " .. cartItem.name)
            return
        end
        
        -- Check stock availability
        local availableStock = getItemStock(category, cartItem.name)
        if configItem.stock > 0 and availableStock < cartItem.quantity then
            TriggerClientEvent("nu-blackmarket:client:purchaseResult", source, false, "Insufficient stock for " .. configItem.label)
            return
        end
        
        -- Check max quantity limits
        if configItem.maxQuantity and cartItem.quantity > configItem.maxQuantity then
            TriggerClientEvent("nu-blackmarket:client:purchaseResult", source, false, "Maximum quantity exceeded for " .. configItem.label)
            return
        end
        
        -- Add to validated items
        table.insert(validatedItems, {
            name = cartItem.name,
            label = configItem.label,
            quantity = cartItem.quantity,
            price = configItem.price,
            metadata = configItem.metadata or {}
        })
        
        totalCost = totalCost + (configItem.price * cartItem.quantity)
    end
    
    -- Check if player has enough money
    local playerMoney = getPlayerMoney(source, Config.Currency.type)
    if playerMoney < totalCost then
        TriggerClientEvent("nu-blackmarket:client:purchaseResult", source, false, "Insufficient funds")
        return
    end
    
    -- Process the purchase
    local success = true
    local addedItems = {}
    
    -- Remove money first
    if not removePlayerMoney(source, Config.Currency.type, totalCost) then
        TriggerClientEvent("nu-blackmarket:client:purchaseResult", source, false, "Failed to process payment")
        return
    end
    
    -- Add items to inventory
    for _, item in pairs(validatedItems) do
        local configItem, category = findItemInConfig(item.name)
        
        -- Add item to inventory
        local itemAdded = exports.ox_inventory:AddItem(source, item.name, item.quantity, item.metadata)
        
        if itemAdded then
            -- Update stock
            if configItem.stock > 0 then
                updateItemStock(category, item.name, item.quantity)
            end
            table.insert(addedItems, item)
        else
            success = false
            lib.print.error("[Nu-Blackmarket] Failed to add item: " .. item.name .. " for player: " .. source)
        end
    end
    
    if success and #addedItems > 0 then
        -- Send success response
        TriggerClientEvent("nu-blackmarket:client:purchaseResult", source, true, "Purchase successful!")
        
        -- Send webhook log
        sendWebhook(Player.PlayerData.charinfo.firstname .. " " .. Player.PlayerData.charinfo.lastname, 
                   Player.PlayerData.citizenid, addedItems, totalCost)
        
        -- Log for debug
        if Config.Debug then
            lib.print.info("[Nu-Blackmarket] Purchase completed for player: " .. source .. " | Items: " .. #addedItems .. " | Cost: $" .. totalCost)
        end
    else
        -- Refund money if items couldn't be added
        if Config.Currency.type == "cash" or Config.Currency.type == "bank" or Config.Currency.type == "crypto" then
            exports.qbx_core:AddMoney(source, Config.Currency.type, totalCost, "blackmarket-refund")
        else
            exports.ox_inventory:AddItem(source, Config.Currency.type, totalCost)
        end
        
        TriggerClientEvent("nu-blackmarket:client:purchaseResult", source, false, "Failed to process some items. Money refunded.")
    end
end)

-- Initialize when resource starts
CreateThread(function()
    initializeStock()
    
    -- Set up stock refresh timer if enabled
    if Config.StockRefresh.enabled then
        while true do
            Wait(Config.StockRefresh.interval * 60000) -- Convert minutes to milliseconds
            refreshStock()
        end
    end
end)

-- Export functions for other resources
exports("getItemStock", getItemStock)
exports("updateItemStock", updateItemStock)
exports("getCurrentStock", function()
    return currentStock
end)

lib.print.info("^2[Nu-Blackmarket]^7 Server script loaded successfully!") 
