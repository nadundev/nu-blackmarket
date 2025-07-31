-- Nu-Blackmarket Client Script
-- Handles ped spawning, ox_target integration, and UI management

local blackmarketPed = nil
local isUIOpen = false
local currentStock = {}
local playerCart = {}

-- Spawn the black market ped
local function spawnBlackmarketPed()
    local pedModel = Config.Ped.model
    local pedCoords = Config.Ped.coords
    
    -- Request the model
    lib.requestModel(pedModel, 10000)
    
    -- Create the ped
    blackmarketPed = CreatePed(4, pedModel, pedCoords.x, pedCoords.y, pedCoords.z - 1.0, pedCoords.w, false, true)
    
    -- Configure ped properties
    SetPedFleeAttributes(blackmarketPed, 0, 0)
    SetPedDiesWhenInjured(blackmarketPed, false)
    SetPedKeepTask(blackmarketPed, true)
    SetBlockingOfNonTemporaryEvents(blackmarketPed, Config.Ped.blockevents)
    SetEntityInvincible(blackmarketPed, Config.Ped.invincible)
    FreezeEntityPosition(blackmarketPed, Config.Ped.freeze)
    
    -- Set ped scenario
    if Config.Ped.scenario and Config.Ped.scenario ~= "" then
        TaskStartScenarioInPlace(blackmarketPed, Config.Ped.scenario, 0, true)
    end
    
    -- Add ox_target interaction
   exports.ox_target:addLocalEntity(blackmarketPed, {
        {
        name = "nu_blackmarket_interact",
        icon = Config.Target.icon,
        label = Config.Target.label,
        distance = Config.Target.distance,
        onSelect = function()
            TriggerServerEvent("nu-blackmarket:server:requestOpenUI")
        end
        }
    })
    
    if Config.Debug then
        lib.print.info("[Nu-Blackmarket] Ped spawned successfully")
    end
end

-- Remove the black market ped
local function removeBlackmarketPed()
    if blackmarketPed and DoesEntityExist(blackmarketPed) then
        exports.ox_target:removeLocalEntity(blackmarketPed, "nu_blackmarket_interact")
        DeleteEntity(blackmarketPed)
        blackmarketPed = nil
        
        if Config.Debug then
            lib.print.info("[Nu-Blackmarket] Ped removed")
        end
    end
end

-- Open the blackmarket UI
function openBlackmarketUI()
    if isUIOpen then return end
    
    -- Request stock and player money from server
    TriggerServerEvent("nu-blackmarket:server:getStock")
    TriggerServerEvent("nu-blackmarket:server:getPlayerMoney")
    
    -- Wait a moment for server response
    CreateThread(function()
        local timeout = 0
        while not currentStock or (type(currentStock) == "table" and next(currentStock) == nil) do
            Wait(100)
            timeout = timeout + 100
            if timeout > 5000 then -- 5 second timeout
                lib.notify({
                    title = "Black Market",
                    description = "Failed to load stock data",
                    type = "error"
                })
                return
            end
        end
        
        isUIOpen = true
        playerCart = {} -- Reset cart when opening UI
        
        -- Prepare data for UI
        local uiData = {
            config = {
                title = Config.UI.title,
                subtitle = Config.UI.subtitle,
                maxCartItems = Config.UI.maxCartItems,
                showPrices = Config.UI.showPrices,
                enableSounds = Config.UI.enableSounds,
                currency = Config.Currency.type
            },
            categories = Config.Items,
            stock = currentStock,
            cart = playerCart
        }
        
        -- Open NUI
        SetNuiFocus(true, true)
        SendNUIMessage({
            action = "openUI",
            data = uiData
        })
        
        if Config.Debug then
            lib.print.info("[Nu-Blackmarket] UI opened")
        end
    end)
end

-- Close the blackmarket UI
local function closeBlackmarketUI()
    if not isUIOpen then return end
    
    isUIOpen = false
    SetNuiFocus(false, false)
    
    SendNUIMessage({
        action = "closeUI"
    })
    
    if Config.Debug then
        lib.print.info("[Nu-Blackmarket] UI closed")
    end
end

-- Handle purchase completion
local function processPurchase(cart)
    if not cart or #cart == 0 then
        lib.notify({
            title = "Black Market",
            description = "Your cart is empty",
            type = "error"
        })
        return
    end
    
    -- Close UI and show processing
    closeBlackmarketUI()
    
    lib.notify({
        title = "Black Market",
        description = "Processing your purchase...",
        type = "inform"
    })
    
    -- Send purchase to server
    TriggerServerEvent("nu-blackmarket:server:purchaseItems", cart)
end

-- Register NUI Callbacks
RegisterNUICallback("closeUI", function(data, cb)
    closeBlackmarketUI()
    cb("ok")
end)

RegisterNUICallback("addToCart", function(data, cb)
    local itemName = data.itemName
    local category = data.category
    local quantity = data.quantity or 1
    
    if not itemName or not category then
        cb({ success = false, message = "Invalid item data" })
        return
    end
    
    -- Check if cart is full
    if #playerCart >= Config.UI.maxCartItems then
        cb({ success = false, message = "Cart is full" })
        return
    end
    
    -- Find existing item in cart
    local existingIndex = nil
    for i, cartItem in ipairs(playerCart) do
        if cartItem.name == itemName then
            existingIndex = i
            break
        end
    end
    
    if existingIndex then
        -- Update existing item quantity
        playerCart[existingIndex].quantity = playerCart[existingIndex].quantity + quantity
    else
        -- Add new item to cart
        local configItem = nil
        for _, cat in pairs(Config.Items) do
            if cat.category == category then
                for _, item in pairs(cat.items) do
                    if item.name == itemName then
                        configItem = item
                        break
                    end
                end
                break
            end
        end
        
        if configItem then
            table.insert(playerCart, {
                name = itemName,
                label = configItem.label,
                price = configItem.price,
                quantity = quantity,
                category = category
            })
        end
    end
    
    cb({ success = true, cart = playerCart })
    
    if Config.Debug then
        lib.print.info("[Nu-Blackmarket] Item added to cart: " .. itemName .. " x" .. quantity)
    end
end)

RegisterNUICallback("removeFromCart", function(data, cb)
    local itemName = data.itemName
    
    for i, cartItem in ipairs(playerCart) do
        if cartItem.name == itemName then
            table.remove(playerCart, i)
            break
        end
    end
    
    cb({ success = true, cart = playerCart })
    
    if Config.Debug then
        lib.print.info("[Nu-Blackmarket] Item removed from cart: " .. itemName)
    end
end)

RegisterNUICallback("updateCartQuantity", function(data, cb)
    local itemName = data.itemName
    local newQuantity = data.quantity
    
    if newQuantity <= 0 then
        -- Remove item if quantity is 0 or less
        for i, cartItem in ipairs(playerCart) do
            if cartItem.name == itemName then
                table.remove(playerCart, i)
                break
            end
        end
    else
        -- Update quantity
        for i, cartItem in ipairs(playerCart) do
            if cartItem.name == itemName then
                playerCart[i].quantity = newQuantity
                break
            end
        end
    end
    
    cb({ success = true, cart = playerCart })
end)

RegisterNUICallback("purchase", function(data, cb)
    local cart = data.cart or playerCart
    
    if not cart or #cart == 0 then
        cb({ success = false, message = "Cart is empty" })
        return
    end
    
    cb({ success = true })
    processPurchase(cart)
end)

RegisterNUICallback("requestStock", function(data, cb)
    TriggerServerEvent("nu-blackmarket:server:getStock")
    cb("ok")
end)



RegisterNetEvent("nu-blackmarket:client:openUIAllowed", function()
    openBlackmarketUI()
end)

RegisterNetEvent("nu-blackmarket:client:openUIDenied", function(reason)
    lib.notify({
        title = "Black Market",
        description = reason or "Access denied",
        type = "error"
    })
end)

-- Register client events
RegisterNetEvent("nu-blackmarket:client:receiveStock", function(stockData)
    currentStock = stockData
    
    if isUIOpen then
        -- Update UI with new stock data
        SendNUIMessage({
            action = "updateStock",
            data = stockData
        })
    end
    
    if Config.Debug then
        lib.print.info("[Nu-Blackmarket] Stock data received")
    end
end)

RegisterNetEvent("nu-blackmarket:client:receivePlayerMoney", function(amount, currencyType)
    -- Always send money update to UI if it exists, regardless of isUIOpen state
    -- because the UI might open before this event is received
    SendNUIMessage({
        action = "updatePlayerMoney",
        data = {
            amount = amount,
            currencyType = currencyType
        }
    })
    
    if Config.Debug then
        lib.print.info("[Nu-Blackmarket] Player money received: $" .. amount .. " (" .. currencyType .. ")")
    end
end)

RegisterNetEvent("nu-blackmarket:client:purchaseResult", function(success, message)
    if success then
        lib.notify({
            title = "Black Market",
            description = message or "Purchase completed successfully!",
            type = "success"
        })
        
        -- Clear cart after successful purchase
        playerCart = {}
        
        -- Request updated stock and player money
        TriggerServerEvent("nu-blackmarket:server:getStock")
        TriggerServerEvent("nu-blackmarket:server:getPlayerMoney")
    else
        lib.notify({
            title = "Black Market",
            description = message or "Purchase failed",
            type = "error"
        })
    end
end)

-- Handle resource start/stop
AddEventHandler("onResourceStart", function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    
    -- Wait for game to be ready
    CreateThread(function()
        while not NetworkIsPlayerActive(PlayerId()) do
            Wait(100)
        end
        
        Wait(2000) -- Additional wait for stability
        spawnBlackmarketPed()
    end)
end)

AddEventHandler("onResourceStop", function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    
    removeBlackmarketPed()
    
    if isUIOpen then
        closeBlackmarketUI()
    end
end)

-- Handle player spawning (for server restarts while player is online)
RegisterNetEvent("QBCore:Client:OnPlayerLoaded", function()
    CreateThread(function()
        Wait(2000)
        if not blackmarketPed or not DoesEntityExist(blackmarketPed) then
            spawnBlackmarketPed()
        end
    end)
end)

-- Qbox equivalent for player loaded
RegisterNetEvent("qbx_core:client:playerLoaded", function()
    CreateThread(function()
        Wait(2000)
        if not blackmarketPed or not DoesEntityExist(blackmarketPed) then
            spawnBlackmarketPed()
        end
    end)
end)

-- Handle ESC key to close UI
CreateThread(function()
    while true do
        if isUIOpen then
            DisableControlAction(0, 322, true) -- ESC key
            DisableControlAction(0, 288, true) -- F1 key
            DisableControlAction(0, 289, true) -- F2 key
            DisableControlAction(0, 170, true) -- F3 key
            
            if IsDisabledControlJustPressed(0, 322) then -- ESC pressed
                closeBlackmarketUI()
            end
        end
        Wait(0)
    end
end)

-- Export functions for other resources
exports("openBlackmarket", openBlackmarketUI)
exports("closeBlackmarket", closeBlackmarketUI)
exports("isBlackmarketOpen", function()
    return isUIOpen
end)

lib.print.info("^2[Nu-Blackmarket]^7 Client script loaded successfully!") 
