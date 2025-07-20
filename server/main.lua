-- Nu-Blackmarket Server Script (Secure Version with Ticket System)
-- Handles server-side logic including secure UI gating, purchases, validation, inventory management, and optional ticket requirement

local currentStock = {}

-- Initialize stock levels from config
local function initializeStock()
    for _, category in pairs(Config.Items) do
        for _, item in pairs(category.items) do
            local stockKey = category.category .. "_" .. item.name
            currentStock[stockKey] = item.stock
        end
    end
    if Config.Debug then
        lib.print.info("[Nu-Blackmarket] Stock initialized")
    end
end

-- Refresh stock
local function refreshStock()
    if not Config.StockRefresh.enabled then return end
    for _, category in pairs(Config.Items) do
        for _, item in pairs(category.items) do
            if item.stock > 0 then
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

-- Stock utilities
local function getItemStock(category, itemName)
    return currentStock[category .. "_" .. itemName] or 0
end

local function updateItemStock(category, itemName, quantity)
    local stockKey = category .. "_" .. itemName
    if currentStock[stockKey] then
        currentStock[stockKey] = math.max(0, currentStock[stockKey] - quantity)
        return true
    end
    return false
end

-- Job/time check
local function checkJobRestrictions(source)
    if not Config.JobRestrictions or #Config.JobRestrictions == 0 then return true end
    local Player = exports.qbx_core:GetPlayer(source)
    if not Player then return false end
    local jobName = Player.PlayerData.job.name
    for _, restrictedJob in pairs(Config.JobRestrictions) do
        if jobName == restrictedJob then return false end
    end
    return true
end

local function checkTimeRestrictions()
    if not Config.TimeRestrictions.enabled then return true end
    local hour = tonumber(os.date("%H"))
    local startHour, endHour = Config.TimeRestrictions.startHour, Config.TimeRestrictions.endHour
    if startHour > endHour then
        return hour >= startHour or hour <= endHour
    else
        return hour >= startHour and hour <= endHour
    end
end

-- Money handling
local function getPlayerMoney(source, moneyType)
    if moneyType == "cash" or moneyType == "bank" or moneyType == "crypto" then
        return exports.qbx_core:GetMoney(source, moneyType) or 0
    else
        return exports.ox_inventory:GetItemCount(source, moneyType) or 0
    end
end

local function removePlayerMoney(source, moneyType, amount)
    if moneyType == "cash" or moneyType == "bank" or moneyType == "crypto" then
        return exports.qbx_core:RemoveMoney(source, moneyType, amount, "blackmarket-purchase")
    else
        return exports.ox_inventory:RemoveItem(source, moneyType, amount)
    end
end

-- Check if player has required ticket item (if enabled)
local function checkTicketItem(source)
    if not Config.Ticket.enabled then return true end
    local ticketItem = Config.Ticket.item or "blackmkticket"
    local count = exports.ox_inventory:GetItemCount(source, ticketItem) or 0
    return count > 0
end

-- Remove one ticket item after opening UI (if enabled)
local function consumeTicketItem(source)
    if Config.Ticket.enabled then
        local ticketItem = Config.Ticket.item or "blackmkticket"
        exports.ox_inventory:RemoveItem(source, ticketItem, 1)
    end
end

-- Item search
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

-- Webhook logging
local function sendWebhook(playerName, citizenid, items, totalCost)
    if not Config.Webhook.enabled or not Config.Webhook.url or Config.Webhook.url == "" then return end
    local itemsList = ""
    for _, item in pairs(items) do
        itemsList = itemsList .. "• " .. item.label .. " x" .. item.quantity .. " ($" .. (item.price * item.quantity) .. ")\n"
    end
    local embed = { {
        title = Config.Webhook.title,
        description = "**Player:** " .. playerName .. "\n**Citizen ID:** " .. citizenid .. "\n**Total Cost:** $" .. totalCost .. "\n\n**Items Purchased:**\n" .. itemsList,
        color = Config.Webhook.color,
        footer = { text = Config.Webhook.footer .. " • " .. os.date("%Y-%m-%d %H:%M:%S") }
    } }
    PerformHttpRequest(Config.Webhook.url, function() end, "POST", json.encode({ embeds = embed }), { ["Content-Type"] = "application/json" })
end

-- Server event to attempt opening blackmarket UI (checks job, time, and optional ticket)
RegisterNetEvent("nu-blackmarket:server:attemptOpen", function()
    local src = source
    if not checkJobRestrictions(src) then
        TriggerClientEvent("nu-blackmarket:client:purchaseResult", src, false, "Access denied (job restricted)")
        return
    end
    if not checkTimeRestrictions() then
        TriggerClientEvent("nu-blackmarket:client:purchaseResult", src, false, "Black market is closed")
        return
    end
    if not checkTicketItem(src) then
        TriggerClientEvent("nu-blackmarket:client:purchaseResult", src, false, "Required ticket not found")
        return
    end

    -- Remove one ticket if required
    consumeTicketItem(src)

    -- Send stock and money data after successful validation
    local stockData = {}
    for _, category in pairs(Config.Items) do
        stockData[category.category] = {}
        for _, item in pairs(category.items) do
            stockData[category.category][item.name] = getItemStock(category.category, item.name)
        end
    end
    local moneyAmount = getPlayerMoney(src, Config.Currency.type)
    TriggerClientEvent("nu-blackmarket:client:receiveStock", src, stockData)
    TriggerClientEvent("nu-blackmarket:client:receivePlayerMoney", src, moneyAmount, Config.Currency.type)
end)

-- Get stock with server-side access control (for refresh or other)
RegisterNetEvent("nu-blackmarket:server:getStock", function()
    local src = source
    if not checkJobRestrictions(src) then
        TriggerClientEvent("nu-blackmarket:client:purchaseResult", src, false, "Access denied (job restricted)")
        return
    end
    if not checkTimeRestrictions() then
        TriggerClientEvent("nu-blackmarket:client:purchaseResult", src, false, "Black market is closed")
        return
    end

    local stockData = {}
    for _, category in pairs(Config.Items) do
        stockData[category.category] = {}
        for _, item in pairs(category.items) do
            stockData[category.category][item.name] = getItemStock(category.category, item.name)
        end
    end
    local moneyAmount = getPlayerMoney(src, Config.Currency.type)
    TriggerClientEvent("nu-blackmarket:client:receiveStock", src, stockData)
    TriggerClientEvent("nu-blackmarket:client:receivePlayerMoney", src, moneyAmount, Config.Currency.type)
end)

-- Process purchase
RegisterNetEvent("nu-blackmarket:server:purchaseItems", function(cartItems)
    local src = source
    local Player = exports.qbx_core:GetPlayer(src)
    if not Player then
        TriggerClientEvent("nu-blackmarket:client:purchaseResult", src, false, "Player not found")
        return
    end
    if not checkJobRestrictions(src) then
        TriggerClientEvent("nu-blackmarket:client:purchaseResult", src, false, "Access denied (job restricted)")
        return
    end
    if not checkTimeRestrictions() then
        TriggerClientEvent("nu-blackmarket:client:purchaseResult", src, false, "Black market is closed")
        return
    end
    if not cartItems or type(cartItems) ~= "table" or #cartItems == 0 then
        TriggerClientEvent("nu-blackmarket:client:purchaseResult", src, false, "Invalid cart")
        return
    end

    local validatedItems, totalCost = {}, 0
    for _, cartItem in pairs(cartItems) do
        local itemCfg, category = findItemInConfig(cartItem.name)
        if not itemCfg then
            TriggerClientEvent("nu-blackmarket:client:purchaseResult", src, false, "Invalid item: " .. cartItem.name)
            return
        end
        local available = getItemStock(category, cartItem.name)
        if itemCfg.stock > 0 and available < cartItem.quantity then
            TriggerClientEvent("nu-blackmarket:client:purchaseResult", src, false, "Out of stock: " .. itemCfg.label)
            return
        end
        if itemCfg.maxQuantity and cartItem.quantity > itemCfg.maxQuantity then
            TriggerClientEvent("nu-blackmarket:client:purchaseResult", src, false, "Too many: " .. itemCfg.label)
            return
        end
        table.insert(validatedItems, {
            name = cartItem.name,
            label = itemCfg.label,
            quantity = cartItem.quantity,
            price = itemCfg.price,
            metadata = itemCfg.metadata or {}
        })
        totalCost = totalCost + (itemCfg.price * cartItem.quantity)
    end

    if getPlayerMoney(src, Config.Currency.type) < totalCost then
        TriggerClientEvent("nu-blackmarket:client:purchaseResult", src, false, "Not enough funds")
        return
    end

    if not removePlayerMoney(src, Config.Currency.type, totalCost) then
        TriggerClientEvent("nu-blackmarket:client:purchaseResult", src, false, "Payment failed")
        return
    end

    local success, addedItems = true, {}
    for _, item in pairs(validatedItems) do
        local itemCfg, category = findItemInConfig(item.name)
        if exports.ox_inventory:AddItem(src, item.name, item.quantity, item.metadata) then
            if itemCfg.stock > 0 then
                updateItemStock(category, item.name, item.quantity)
            end
            table.insert(addedItems, item)
        else
            success = false
            lib.print.error("[Nu-Blackmarket] Failed to add: " .. item.name)
        end
    end

    if success and #addedItems > 0 then
        TriggerClientEvent("nu-blackmarket:client:purchaseResult", src, true, "Purchase successful!")
        sendWebhook(Player.PlayerData.charinfo.firstname .. " " .. Player.PlayerData.charinfo.lastname, Player.PlayerData.citizenid, addedItems, totalCost)
    else
        -- Refund
        if Config.Currency.type == "cash" or Config.Currency.type == "bank" or Config.Currency.type == "crypto" then
            exports.qbx_core:AddMoney(src, Config.Currency.type, totalCost, "blackmarket-refund")
        else
            exports.ox_inventory:AddItem(src, Config.Currency.type, totalCost)
        end
        TriggerClientEvent("nu-blackmarket:client:purchaseResult", src, false, "Failed to add items. Refunded.")
    end
end)

-- Initialization
CreateThread(function()
    initializeStock()
    if Config.StockRefresh.enabled then
        while true do
            Wait(Config.StockRefresh.interval * 60000)
            refreshStock()
        end
    end
end)

-- Exports
exports("getItemStock", getItemStock)
exports("updateItemStock", updateItemStock)
exports("getCurrentStock", function() return currentStock end)

lib.print.info("^2[Nu-Blackmarket]^7 Secure server script with ticket system loaded!")
