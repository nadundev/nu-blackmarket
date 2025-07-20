-- Nu-Blackmarket Configuration
Config = {}

-- Debug mode (set to false for production)
Config.Debug = true

-- Ped Configuration
Config.Ped = {
    model = `g_m_m_chigoon_01`, -- Black market dealer ped model
    coords = vector4(-1187.5, -1500.2, 4.4, 125.0), -- Default location (can be changed)
    scenario = "WORLD_HUMAN_SMOKING", -- Ped animation/scenario
    freeze = true, -- Should the ped be frozen in place
    invincible = true, -- Should the ped be invincible
    blockevents = true -- Should the ped ignore events
}

-- ox_target Configuration
Config.Target = {
    icon = "fas fa-shopping-cart",
    label = "Browse Black Market",
    distance = 2.5, -- Interaction distance
    debug = false -- ox_target debug mode
}

Config.Ticket = {
    enabled = true,           -- Set to true to require a ticket item to access the black market
    item = "blackmkticket"    -- The inventory item name required as a ticket
}

-- Currency Configuration
Config.Currency = {
    type = "cash", -- "cash" or "bank" or custom item name like "crypto"
    removeType = "remove" -- "remove" for cash/bank, "removeItem" for items
}

-- UI Configuration
Config.UI = {
    title = "Black Market",
    subtitle = "Illegal goods and services",
    maxCartItems = 10, -- Maximum items in cart
    showPrices = true,
    enableSounds = true
}

-- Black Market Items Configuration
Config.Items = {
    -- Weapons Category
    {
        category = "weapons",
        categoryLabel = "Weapons",
        categoryIcon = "fas fa-gun",
        items = {
            {
                name = "weapon_pistol",
                label = "Pistol",
                description = "A standard 9mm pistol",
                price = 10,
                image = "pistol.png", -- Image should be in ox_inventory/web/images/
                stock = 5, -- Available stock (-1 for unlimited)
                metadata = {
                    durability = 100,
                    ammo = 0
                }
            },
            {
                name = "weapon_switchblade",
                label = "Switchblade",
                description = "A sharp folding knife",
                price = 5,
                image = "switchblade.png",
                stock = 10,
                metadata = {
                    durability = 100
                }
            },
            {
                name = "weapon_knuckle",
                label = "Brass Knuckles",
                description = "Metal knuckle dusters",
                price = 2,
                image = "knuckle.png",
                stock = 8,
                metadata = {
                    durability = 100
                }
            }
        }
    },
    
    -- Ammunition Category
    {
        category = "ammo",
        categoryLabel = "Ammunition",
        categoryIcon = "fas fa-bullets",
        items = {
            {
                name = "pistol_ammo",
                label = "Pistol Ammo",
                description = "9mm ammunition",
                price = 5,
                image = "pistol_ammo.png",
                stock = 100,
                maxQuantity = 50 -- Max quantity per purchase
            },
            {
                name = "rifle_ammo",
                label = "Rifle Ammo",
                description = "High caliber rifle ammunition",
                price = 10,
                image = "rifle_ammo.png",
                stock = 50,
                maxQuantity = 30
            }
        }
    },
    
    -- Drugs Category
    {
        category = "drugs",
        categoryLabel = "Narcotics",
        categoryIcon = "fas fa-pills",
        items = {
            {
                name = "weed_brick",
                label = "Weed Brick",
                description = "Compressed cannabis brick",
                price = 500,
                image = "weed_brick.png",
                stock = 20,
                maxQuantity = 5
            },
            {
                name = "coke_brick",
                label = "Cocaine Brick",
                description = "Pure cocaine brick",
                price = 1500,
                image = "coke_brick.png",
                stock = 10,
                maxQuantity = 3
            },
            {
                name = "meth_bag",
                label = "Meth Bag",
                description = "Crystal methamphetamine",
                price = 800,
                image = "meth_bag.png",
                stock = 15,
                maxQuantity = 5
            }
        }
    },
    
    -- Tools Category
    {
        category = "tools",
        categoryLabel = "Tools",
        categoryIcon = "fas fa-tools",
        items = {
            {
                name = "lockpick",
                label = "Lockpick",
                description = "For bypassing simple locks",
                price = 50,
                image = "lockpick.png",
                stock = 50,
                maxQuantity = 10
            },
            {
                name = "thermite",
                label = "Thermite",
                description = "Explosive compound for cutting",
                price = 1000,
                image = "thermite.png",
                stock = 5,
                maxQuantity = 2
            },
            {
                name = "drill",
                label = "Drill",
                description = "Heavy duty drill",
                price = 750,
                image = "drill.png",
                stock = 8,
                maxQuantity = 1
            },
            {
                name = "vpn",
                label = "VPN",
                description = "Virtual private network access",
                price = 200,
                image = "vpn.png",
                stock = 20,
                maxQuantity = 5
            }
        }
    },
    
    -- Electronics Category
    {
        category = "electronics",
        categoryLabel = "Electronics",
        categoryIcon = "fas fa-microchip",
        items = {
            {
                name = "phone",
                label = "Burner Phone",
                description = "Untraceable mobile phone",
                price = 300,
                image = "phone.png",
                stock = 25,
                maxQuantity = 2
            },
            {
                name = "radio",
                label = "Encrypted Radio",
                description = "Secure communication device",
                price = 400,
                image = "radio.png",
                stock = 15,
                maxQuantity = 2
            },
            {
                name = "laptop",
                label = "Hacking Laptop",
                description = "Modified laptop for hacking",
                price = 2000,
                image = "laptop.png",
                stock = 3,
                maxQuantity = 1
            }
        }
    }
}

-- Job Restrictions (optional - leave empty table {} to allow all players)
Config.JobRestrictions = {
    -- Example: only allow certain jobs to access the black market
    -- "police", -- This would BLOCK police from accessing
    -- Add job names to block them from accessing the black market
}

-- Time Restrictions (optional)
Config.TimeRestrictions = {
    enabled = false, -- Set to true to enable time restrictions
    startHour = 22, -- 10 PM
    endHour = 6 -- 6 AM
}

-- Webhook Configuration (for logging purchases)
Config.Webhook = {
    enabled = false, -- Set to true to enable Discord logging
    url = "", -- Your Discord webhook URL
    color = 16711680, -- Red color
    title = "Black Market Purchase",
    footer = "Nu-Blackmarket System"
}

-- Stock Refresh Configuration
Config.StockRefresh = {
    enabled = true, -- Should stock refresh automatically
    interval = 60, -- Minutes between stock refresh
    percentage = 0.5 -- Percentage of max stock to restore (0.5 = 50%)
} 
