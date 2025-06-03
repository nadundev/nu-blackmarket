-- Nu-Blackmarket Testing Configuration
-- This file provides testing utilities and validation for the black market script

TestConfig = {}

-- Test locations for easy ped placement
TestConfig.TestLocations = {
    {
        name = "Legion Square",
        coords = vector4(215.0, -810.0, 30.7, 160.0),
        description = "Popular downtown location with good visibility"
    },
    {
        name = "Sandy Shores Airfield",
        coords = vector4(1744.0, 3270.0, 41.1, 200.0),
        description = "Remote location perfect for illegal activities"
    },
    {
        name = "Paleto Bay Dock",
        coords = vector4(-1610.0, 5260.0, 2.0, 90.0),
        description = "Secluded dock area for discreet operations"
    },
    {
        name = "Los Santos Airport",
        coords = vector4(-1037.0, -2738.0, 20.1, 240.0),
        description = "Busy airport location with cover"
    },
    {
        name = "Mirror Park Lake",
        coords = vector4(1208.0, -1402.0, 35.2, 180.0),
        description = "Quiet lake area away from main roads"
    }
}

-- Test items for quick configuration
TestConfig.TestItems = {
    {
        category = "test",
        categoryLabel = "Test Items",
        categoryIcon = "fas fa-vial",
        items = {
            {
                name = "bread",
                label = "Test Bread",
                description = "Basic test item for validation",
                price = 1,
                image = "bread.png",
                stock = 100
            },
            {
                name = "water",
                label = "Test Water",
                description = "Another test item",
                price = 2,
                image = "water.png", 
                stock = 50
            }
        }
    }
}

-- Validation functions
TestConfig.Validation = {
    -- Check if all required dependencies are started
    dependencies = function()
        local deps = {
            "ox_target",
            "ox_inventory", 
            "qbx_core",
            "ox_lib"
        }
        
        local missing = {}
        for _, dep in ipairs(deps) do
            if GetResourceState(dep) ~= "started" then
                table.insert(missing, dep)
            end
        end
        
        return #missing == 0, missing
    end,

    -- Validate config structure
    config = function()
        local errors = {}
        
        -- Check required config sections
        if not Config then
            table.insert(errors, "Config table not found")
            return false, errors
        end
        
        if not Config.Ped then
            table.insert(errors, "Config.Ped not defined")
        end
        
        if not Config.Items or #Config.Items == 0 then
            table.insert(errors, "Config.Items is empty or not defined")
        end
        
        if not Config.Currency then
            table.insert(errors, "Config.Currency not defined")
        end
        
        -- Check ped coordinates
        if Config.Ped and Config.Ped.coords then
            local coords = Config.Ped.coords
            if type(coords) ~= "vector4" then
                table.insert(errors, "Config.Ped.coords must be a vector4")
            end
        end
        
        -- Validate items structure
        if Config.Items then
            for catIndex, category in ipairs(Config.Items) do
                if not category.category then
                    table.insert(errors, "Category " .. catIndex .. " missing 'category' field")
                end
                if not category.items or #category.items == 0 then
                    table.insert(errors, "Category " .. catIndex .. " has no items")
                end
                
                if category.items then
                    for itemIndex, item in ipairs(category.items) do
                        if not item.name then
                            table.insert(errors, "Item " .. itemIndex .. " in category " .. catIndex .. " missing 'name'")
                        end
                        if not item.price or item.price < 0 then
                            table.insert(errors, "Item " .. itemIndex .. " in category " .. catIndex .. " has invalid price")
                        end
                    end
                end
            end
        end
        
        return #errors == 0, errors
    end,

    -- Check if player has required items in inventory (for testing)
    playerInventory = function(source)
        if not source then return false, {"No player source provided"} end
        
        local testItems = {"bread", "water"}
        local missing = {}
        
        for _, item in ipairs(testItems) do
            local count = exports.ox_inventory:GetItemCount(source, item)
            if not count or count == 0 then
                table.insert(missing, item)
            end
        end
        
        return #missing == 0, missing
    end
}

-- Debug commands (only available when Config.Debug = true)
TestConfig.Commands = {
    -- Teleport to test location
    teleportToTest = function(source, locationIndex)
        if not Config.Debug then return end
        
        local location = TestConfig.TestLocations[locationIndex or 1]
        if not location then return end
        
        local ped = GetPlayerPed(source)
        SetEntityCoords(ped, location.coords.x, location.coords.y, location.coords.z)
        SetEntityHeading(ped, location.coords.w)
        
        TriggerClientEvent('chat:addMessage', source, {
            color = {0, 255, 0},
            multiline = true,
            args = {"[Nu-Blackmarket]", "Teleported to " .. location.name}
        })
    end,

    -- Give test items
    giveTestItems = function(source)
        if not Config.Debug then return end
        
        for _, category in ipairs(TestConfig.TestItems) do
            for _, item in ipairs(category.items) do
                exports.ox_inventory:AddItem(source, item.name, 5)
            end
        end
        
        TriggerClientEvent('chat:addMessage', source, {
            color = {0, 255, 0},
            multiline = true,
            args = {"[Nu-Blackmarket]", "Test items added to inventory"}
        })
    end,

    -- Give money for testing
    giveMoney = function(source, amount)
        if not Config.Debug then return end
        
        local success = exports.qbx_core:AddMoney(source, 'cash', amount or 10000, 'blackmarket-test')
        if success then
            TriggerClientEvent('chat:addMessage', source, {
                color = {0, 255, 0},
                multiline = true,
                args = {"[Nu-Blackmarket]", "Added $" .. (amount or 10000) .. " cash"}
            })
        else
            TriggerClientEvent('chat:addMessage', source, {
                color = {255, 0, 0},
                multiline = true,
                args = {"[Nu-Blackmarket]", "Failed to add money"}
            })
        end
    end,

    -- Reset stock to full
    resetStock = function()
        if not Config.Debug then return end
        
        if exports['nu-blackmarket'] then
            -- Reset all stock to maximum
            for _, category in ipairs(Config.Items) do
                for _, item in ipairs(category.items) do
                    if item.stock > 0 then
                        exports['nu-blackmarket']:updateItemStock(category.category, item.name, item.stock)
                    end
                end
            end
            
            print("^2[Nu-Blackmarket Test]^7 Stock reset to full")
        end
    end
}

-- Performance monitoring
TestConfig.Performance = {
    startTime = GetGameTimer(),
    
    -- Monitor resource performance
    monitor = function()
        local memUsage = collectgarbage("count")
        local uptime = GetGameTimer() - TestConfig.Performance.startTime
        
        return {
            memory = math.floor(memUsage * 100) / 100, -- KB
            uptime = math.floor(uptime / 1000), -- seconds
            resourceState = GetResourceState(GetCurrentResourceName())
        }
    end
}

-- Export test functions for external access
if IsDuplicityVersion() then -- Server-side
    -- Debug commands registration
    if Config and Config.Debug then
        -- Teleport command
        RegisterCommand('bmtest_tp', function(source, args)
            local locationIndex = tonumber(args[1]) or 1
            TestConfig.Commands.teleportToTest(source, locationIndex)
        end, true)

        -- Give test items command
        RegisterCommand('bmtest_items', function(source, args)
            TestConfig.Commands.giveTestItems(source)
        end, true)

        -- Give money command
        RegisterCommand('bmtest_money', function(source, args)
            local amount = tonumber(args[1]) or 10000
            TestConfig.Commands.giveMoney(source, amount)
        end, true)

        -- Reset stock command
        RegisterCommand('bmtest_reset', function(source, args)
            TestConfig.Commands.resetStock()
        end, true)

        -- Validation command
        RegisterCommand('bmtest_validate', function(source, args)
            local depsOk, missingDeps = TestConfig.Validation.dependencies()
            local configOk, configErrors = TestConfig.Validation.config()
            
            if depsOk and configOk then
                TriggerClientEvent('chat:addMessage', source, {
                    color = {0, 255, 0},
                    args = {"[Nu-Blackmarket]", "All validation checks passed!"}
                })
            else
                if not depsOk then
                    TriggerClientEvent('chat:addMessage', source, {
                        color = {255, 0, 0},
                        args = {"[Nu-Blackmarket]", "Missing dependencies: " .. table.concat(missingDeps, ", ")}
                    })
                end
                if not configOk then
                    TriggerClientEvent('chat:addMessage', source, {
                        color = {255, 0, 0},
                        args = {"[Nu-Blackmarket]", "Config errors: " .. table.concat(configErrors, ", ")}
                    })
                end
            end
        end, true)

        print("^3[Nu-Blackmarket Test]^7 Debug commands registered:")
        print("^3[Nu-Blackmarket Test]^7 /bmtest_tp [location] - Teleport to test location")
        print("^3[Nu-Blackmarket Test]^7 /bmtest_items - Give test items")
        print("^3[Nu-Blackmarket Test]^7 /bmtest_money [amount] - Give money")
        print("^3[Nu-Blackmarket Test]^7 /bmtest_reset - Reset stock")
        print("^3[Nu-Blackmarket Test]^7 /bmtest_validate - Validate configuration")
    end
else -- Client-side
    -- Client-side testing utilities can be added here
end

return TestConfig 