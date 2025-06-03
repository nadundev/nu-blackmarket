# Nu-Blackmarket

A modern, standalone black market script for FiveM servers running the Qbox framework. Features a beautiful dark-themed UI, comprehensive item management, and seamless integration with ox_target and ox_inventory.

![Nu-Blackmarket Preview](screenshot.jpg)

## ✨ Features

### 🎨 Modern User Interface
- **Dark Theme Design** with red accents and glassmorphism effects
- **Responsive Layout** that works on all screen sizes
- **Smooth Animations** and hover effects for excellent UX
- **Category-based Navigation** with tabbed interface
- **Real-time Shopping Cart** with quantity management
- **Search Functionality** to find items quickly
- **Purchase Confirmation Modal** with detailed breakdown

### 🛡️ Security & Validation
- **Server-side Validation** of all purchases and stock
- **Job Restrictions** to block certain jobs from accessing
- **Time-based Access Control** (optional night-only operation)
- **Anti-cheat Protection** with proper input sanitization
- **Stock Management** to prevent item flooding

### 🔧 Integration
- **ox_target** for ped interaction
- **ox_inventory** for item management with metadata support
- **Qbox Framework** native integration
- **Discord Webhooks** for purchase logging (optional)
- **Multi-currency Support** (cash, bank, or custom items)

### 📊 Management Features
- **Dynamic Stock System** with auto-refresh capabilities
- **Configurable Items** with prices, descriptions, and stock limits
- **Purchase Limits** per item and transaction
- **Real-time Stock Updates** across all clients
- **Admin Logging** via Discord webhooks

## 📋 Requirements

- **FiveM Server** with latest artifacts
- **Qbox Framework** (qbx_core)
- **ox_target** for interaction system
- **ox_inventory** for inventory management
- **ox_lib** for utility functions

## 🚀 Installation

1. **Download and Extract**
   ```bash
   cd resources/[standalone]
   git clone https://github.com/yourusername/nu-blackmarket.git
   ```

2. **Add to Server Config**
   ```cfg
   ensure nu-blackmarket
   ```

3. **Configure the Script**
   - Edit `shared/config.lua` to customize settings
   - Set ped location, items, prices, and restrictions
   - Configure webhook URLs for logging (optional)

4. **Start the Resource**
   ```
   start nu-blackmarket
   ```

## ⚙️ Configuration

### Basic Setup

Edit `shared/config.lua` to customize your black market:

```lua
-- Ped Location (change to your desired location)
Config.Ped = {
    model = `g_m_m_chigoon_01`,
    coords = vector4(-1187.5, -1500.2, 4.4, 125.0), -- Change this!
    scenario = "WORLD_HUMAN_SMOKING",
    freeze = true,
    invincible = true,
    blockevents = true
}

-- Currency Type
Config.Currency = {
    type = "cash", -- "cash", "bank", or custom item name
    removeType = "remove"
}
```

### Adding Items

Add items to the `Config.Items` table:

```lua
{
    category = "weapons",
    categoryLabel = "Weapons",
    categoryIcon = "fas fa-gun",
    items = {
        {
            name = "weapon_pistol",
            label = "Pistol",
            description = "A standard 9mm pistol",
            price = 2500,
            image = "pistol.png",
            stock = 5, -- -1 for unlimited
            metadata = {
                durability = 100,
                ammo = 0
            }
        }
    }
}
```

### Job Restrictions

Block specific jobs from accessing the black market:

```lua
Config.JobRestrictions = {
    "police",
    "ambulance",
    "mechanic"
}
```

### Time Restrictions

Limit access to specific hours:

```lua
Config.TimeRestrictions = {
    enabled = true,
    startHour = 22, -- 10 PM
    endHour = 6     -- 6 AM
}
```

### Discord Logging

Enable purchase logging to Discord:

```lua
Config.Webhook = {
    enabled = true,
    url = "YOUR_DISCORD_WEBHOOK_URL",
    color = 16711680,
    title = "Black Market Purchase",
    footer = "Nu-Blackmarket System"
}
```

## 🎮 Usage

### For Players

1. **Find the Black Market Ped** at the configured location
2. **Use ox_target** to interact with the ped (default: shopping cart icon)
3. **Browse Categories** by clicking the tabs at the top
4. **Search Items** using the search bar
5. **Add Items to Cart** by clicking "Add to Cart" buttons
6. **Manage Cart** using quantity controls and remove buttons
7. **Purchase Items** by clicking "Purchase Items" and confirming

### For Administrators

- **Monitor Purchases** via Discord webhooks (if enabled)
- **Adjust Stock** manually using exports (see API section)
- **Change Location** by updating `Config.Ped.coords`
- **Modify Items** by editing the config and restarting

## 🔌 API / Exports

### Client Exports

```lua
-- Open the black market UI
exports['nu-blackmarket']:openBlackmarket()

-- Close the black market UI
exports['nu-blackmarket']:closeBlackmarket()

-- Check if UI is open
local isOpen = exports['nu-blackmarket']:isBlackmarketOpen()
```

### Server Exports

```lua
-- Get current stock for an item
local stock = exports['nu-blackmarket']:getItemStock('weapons', 'weapon_pistol')

-- Update stock for an item
exports['nu-blackmarket']:updateItemStock('weapons', 'weapon_pistol', 10)

-- Get all current stock data
local allStock = exports['nu-blackmarket']:getCurrentStock()
```

### Events

#### Client Events
```lua
-- Triggered when stock data is received
RegisterNetEvent('nu-blackmarket:client:receiveStock')

-- Triggered when purchase is completed
RegisterNetEvent('nu-blackmarket:client:purchaseResult')
```

#### Server Events
```lua
-- Request current stock levels
TriggerServerEvent('nu-blackmarket:server:getStock')

-- Process a purchase
TriggerServerEvent('nu-blackmarket:server:purchaseItems', cartItems)
```

## 🛠️ Troubleshooting

### Common Issues

**Ped not spawning:**
- Check console for errors
- Verify ox_lib is installed and started
- Ensure ped model exists
- Check coordinates are valid

**UI not opening:**
- Verify ox_target is installed and working
- Check client console for JavaScript errors
- Ensure all dependencies are started

**Items not being added:**
- Check ox_inventory is working properly
- Verify item names exist in ox_inventory
- Check server console for errors
- Ensure player has inventory space

**Purchase failing:**
- Check player has sufficient money
- Verify item is in stock
- Check server console for detailed error messages
- Ensure database is accessible

### Debug Mode

Enable debug mode in config:

```lua
Config.Debug = true
```

This will show detailed logging in both client and server consoles.

## 📝 Changelog

### Version 1.0.0
- Initial release
- Modern dark-themed UI
- Complete shopping cart system
- ox_target and ox_inventory integration
- Qbox framework compatibility
- Stock management system
- Purchase validation and security
- Discord webhook logging
- Multi-currency support
- Job and time restrictions

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Credits

- **Qbox Framework** for the excellent FiveM framework
- **Overextended** for ox_target, ox_inventory, and ox_lib
- **Font Awesome** for icons
- **Inter Font** for typography

## 📞 Support

For support, please:
1. Check the troubleshooting section above
2. Search existing issues on GitHub
3. Create a new issue with detailed information
4. Join our Discord server (if available)

---

**Made with ❤️ for the FiveM community** 