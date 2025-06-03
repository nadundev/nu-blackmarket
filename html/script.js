// Nu-Blackmarket UI Script
// Handles all UI interactions, cart management, and FiveM communication

class BlackmarketUI {
    constructor() {
        this.config = null;
        this.categories = [];
        this.stockData = {};
        this.cart = [];
        this.currentCategory = null;
        this.isVisible = false;
        this.searchTerm = '';

        this.init();
    }

    init() {
        this.bindEvents();
        this.setupMessageListener();
    }

    bindEvents() {
        // Close button
        document.getElementById('close-btn').addEventListener('click', () => {
            this.closeUI();
        });

        // Purchase button
        document.getElementById('purchase-btn').addEventListener('click', () => {
            this.showPurchaseModal();
        });

        // Modal events
        document.getElementById('cancel-purchase').addEventListener('click', () => {
            this.hidePurchaseModal();
        });

        document.getElementById('confirm-purchase').addEventListener('click', () => {
            this.confirmPurchase();
        });

        // Search functionality
        const searchInput = document.getElementById('search-input');
        const clearSearchBtn = document.getElementById('clear-search');

        searchInput.addEventListener('input', (e) => {
            this.handleSearch(e.target.value);
        });

        clearSearchBtn.addEventListener('click', () => {
            this.clearSearch();
        });

        // ESC key to close
        document.addEventListener('keydown', (e) => {
            if (e.key === 'Escape' && this.isVisible) {
                this.closeUI();
            }
        });

        // Prevent context menu
        document.addEventListener('contextmenu', (e) => {
            e.preventDefault();
        });
    }

    setupMessageListener() {
        window.addEventListener('message', (event) => {
            const { action, data } = event.data;

            switch (action) {
                case 'openUI':
                    this.openUI(data);
                    break;
                case 'closeUI':
                    this.closeUI();
                    break;
                case 'updateStock':
                    this.updateStock(data);
                    break;
                case 'updatePlayerMoney':
                    this.updatePlayerMoney(data);
                    break;
                default:
                    break;
            }
        });
    }

    openUI(data) {
        if (this.isVisible) return;

        this.config = data.config;
        this.categories = data.categories;
        this.stockData = data.stock;
        this.cart = data.cart || [];

        this.render();
        this.showUI();
        
        // Set initial currency display to show loading state (with small delay to ensure DOM is ready)
        setTimeout(() => {
            this.updateInitialCurrencyDisplay();
        }, 100);
    }

    closeUI() {
        if (!this.isVisible) return;

        this.hideUI();
        this.sendCallback('closeUI');
    }

    showUI() {
        document.getElementById('app').classList.remove('hidden');
        document.body.style.overflow = 'hidden';
        this.isVisible = true;

        // Animation
        setTimeout(() => {
            document.querySelector('.container').style.opacity = '1';
            document.querySelector('.container').style.transform = 'scale(1)';
        }, 50);
    }

    hideUI() {
        const container = document.querySelector('.container');
        container.style.opacity = '0';
        container.style.transform = 'scale(0.95)';

        setTimeout(() => {
            document.getElementById('app').classList.add('hidden');
            document.body.style.overflow = 'auto';
            this.isVisible = false;
            this.hidePurchaseModal();
        }, 300);
    }

    render() {
        this.renderHeader();
        this.renderCategories();
        this.renderItems();
        this.renderCart();
    }

    renderHeader() {
        document.getElementById('app-title').textContent = this.config.title;
        document.getElementById('app-subtitle').textContent = this.config.subtitle;
    }

    renderCategories() {
        const container = document.getElementById('category-tabs');
        container.innerHTML = '';

        this.categories.forEach((category, index) => {
            const tab = document.createElement('div');
            tab.className = `category-tab ${index === 0 ? 'active' : ''}`;
            tab.innerHTML = `
                <i class="${category.categoryIcon}"></i>
                ${category.categoryLabel}
            `;

            tab.addEventListener('click', () => {
                this.selectCategory(category.category, tab);
            });

            container.appendChild(tab);
        });

        // Select first category by default
        if (this.categories.length > 0) {
            this.currentCategory = this.categories[0].category;
        }
    }

    selectCategory(categoryId, tabElement) {
        // Update active tab
        document.querySelectorAll('.category-tab').forEach(tab => {
            tab.classList.remove('active');
        });
        tabElement.classList.add('active');

        // Update current category
        this.currentCategory = categoryId;
        this.renderItems();

        // Play sound effect
        this.playSound('tab-switch');
    }

    renderItems() {
        const container = document.getElementById('items-grid');
        const loadingElement = document.getElementById('loading');
        const noResultsElement = document.getElementById('no-results');

        if (!this.currentCategory) {
            loadingElement.style.display = 'flex';
            container.innerHTML = '';
            noResultsElement.classList.add('hidden');
            return;
        }

        loadingElement.style.display = 'none';
        container.innerHTML = '';

        const category = this.categories.find(cat => cat.category === this.currentCategory);
        if (!category) {
            noResultsElement.classList.add('hidden');
            return;
        }

        // Filter items based on search term
        let filteredItems = category.items;
        if (this.searchTerm) {
            filteredItems = category.items.filter(item => {
                return item.label.toLowerCase().includes(this.searchTerm) ||
                       item.description.toLowerCase().includes(this.searchTerm) ||
                       item.name.toLowerCase().includes(this.searchTerm);
            });
        }

        // Show no results message if no items match
        if (filteredItems.length === 0) {
            noResultsElement.classList.remove('hidden');
            return;
        } else {
            noResultsElement.classList.add('hidden');
        }

        filteredItems.forEach(item => {
            const currentStock = this.stockData[this.currentCategory]?.[item.name] || 0;
            const isOutOfStock = item.stock > 0 && currentStock <= 0;
            const isLowStock = item.stock > 0 && currentStock <= 5 && currentStock > 0;

            const itemCard = document.createElement('div');
            itemCard.className = `item-card ${isOutOfStock ? 'out-of-stock' : ''}`;
            
            // Highlight search terms in item name and description
            const highlightedLabel = this.highlightSearchTerm(item.label, this.searchTerm);
            const highlightedDescription = this.highlightSearchTerm(item.description, this.searchTerm);
            
            // Determine item image - check for item image first, then fallback to icon
            let itemImageHtml = '';
            const itemImagePath = this.getItemImagePath(item.name);
            
            if (itemImagePath) {
                itemImageHtml = `<img src="${itemImagePath}" alt="${item.label}" onerror="this.style.display='none'; this.nextElementSibling.style.display='flex';">
                                <i class="fas fa-box" style="display: none;"></i>`;
            } else {
                // Use category-specific icons
                const categoryIcon = this.getCategoryIcon(this.currentCategory, item.name);
                itemImageHtml = `<i class="${categoryIcon}"></i>`;
            }
            
            itemCard.innerHTML = `
                <div class="item-image">
                    ${itemImageHtml}
                </div>
                <div class="item-header">
                    <div>
                        <div class="item-name">${highlightedLabel}</div>
                        <div class="item-price">$${this.formatNumber(item.price)}</div>
                    </div>
                </div>
                <div class="item-description">${highlightedDescription}</div>
                <div class="item-footer">
                    <div class="item-stock ${isLowStock ? 'low-stock' : ''} ${isOutOfStock ? 'out-of-stock' : ''}">
                        ${item.stock === -1 ? 'Unlimited' : `Stock: ${currentStock}`}
                    </div>
                    <button class="add-btn" ${isOutOfStock ? 'disabled' : ''}>
                        <i class="fas fa-plus"></i>
                        Add to Cart
                    </button>
                </div>
            `;

            const addBtn = itemCard.querySelector('.add-btn');
            if (!isOutOfStock) {
                addBtn.addEventListener('click', (e) => {
                    e.stopPropagation();
                    this.addToCart(item, this.currentCategory);
                });
            }

            container.appendChild(itemCard);
        });
    }

    highlightSearchTerm(text, searchTerm) {
        if (!searchTerm || !text) return text;
        
        const regex = new RegExp(`(${searchTerm.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')})`, 'gi');
        return text.replace(regex, '<mark>$1</mark>');
    }

    addToCart(item, category) {
        // Check cart limits
        if (this.cart.length >= this.config.maxCartItems) {
            this.sendCallback('showNotification', {
                message: 'Cart is full',
                type: 'error'
            });
            return;
        }

        // Check stock
        const currentStock = this.stockData[category]?.[item.name] || 0;
        if (item.stock > 0 && currentStock <= 0) {
            this.sendCallback('showNotification', {
                message: 'Item is out of stock',
                type: 'error'
            });
            return;
        }

        // Find existing item in cart
        const existingIndex = this.cart.findIndex(cartItem => cartItem.name === item.name);

        if (existingIndex !== -1) {
            // Update existing item quantity
            this.cart[existingIndex].quantity += 1;
        } else {
            // Add new item to cart
            this.cart.push({
                name: item.name,
                label: item.label,
                price: item.price,
                quantity: 1,
                category: category
            });
        }

        this.renderCart();
        this.playSound('add-to-cart');

        // Send to FiveM
        this.sendCallback('addToCart', {
            itemName: item.name,
            category: category,
            quantity: 1
        });
    }

    removeFromCart(itemName) {
        const index = this.cart.findIndex(item => item.name === itemName);
        if (index !== -1) {
            this.cart.splice(index, 1);
            this.renderCart();
            this.playSound('remove-from-cart');

            // Send to FiveM
            this.sendCallback('removeFromCart', {
                itemName: itemName
            });
        }
    }

    updateCartQuantity(itemName, newQuantity) {
        const item = this.cart.find(cartItem => cartItem.name === itemName);
        if (!item) return;

        if (newQuantity <= 0) {
            this.removeFromCart(itemName);
            return;
        }

        item.quantity = newQuantity;
        this.renderCart();

        // Send to FiveM
        this.sendCallback('updateCartQuantity', {
            itemName: itemName,
            quantity: newQuantity
        });
    }

    renderCart() {
        const cartCount = document.getElementById('cart-count');
        const emptyCart = document.getElementById('empty-cart');
        const cartItems = document.getElementById('cart-items');
        const totalAmount = document.getElementById('total-amount');
        const purchaseBtn = document.getElementById('purchase-btn');

        cartCount.textContent = this.cart.length;

        if (this.cart.length === 0) {
            emptyCart.style.display = 'flex';
            cartItems.style.display = 'none';
            totalAmount.textContent = '$0';
            purchaseBtn.classList.add('disabled');
            purchaseBtn.disabled = true;
            return;
        }

        emptyCart.style.display = 'none';
        cartItems.style.display = 'block';
        purchaseBtn.classList.remove('disabled');
        purchaseBtn.disabled = false;

        // Calculate total
        const total = this.cart.reduce((sum, item) => sum + (item.price * item.quantity), 0);
        totalAmount.textContent = `$${this.formatNumber(total)}`;

        // Render cart items
        cartItems.innerHTML = '';
        this.cart.forEach(item => {
            const cartItem = document.createElement('div');
            cartItem.className = 'cart-item';
            
            cartItem.innerHTML = `
                <div class="cart-item-header">
                    <div class="cart-item-name">${item.label}</div>
                    <div class="cart-item-price">$${this.formatNumber(item.price * item.quantity)}</div>
                </div>
                <div class="cart-item-controls">
                    <div class="quantity-controls">
                        <button class="quantity-btn" data-action="decrease">
                            <i class="fas fa-minus"></i>
                        </button>
                        <input type="number" class="quantity-input" value="${item.quantity}" min="1" readonly>
                        <button class="quantity-btn" data-action="increase">
                            <i class="fas fa-plus"></i>
                        </button>
                    </div>
                    <button class="remove-btn" data-item="${item.name}">
                        <i class="fas fa-trash"></i>
                    </button>
                </div>
            `;

            // Bind quantity controls
            const decreaseBtn = cartItem.querySelector('[data-action="decrease"]');
            const increaseBtn = cartItem.querySelector('[data-action="increase"]');
            const removeBtn = cartItem.querySelector('.remove-btn');

            decreaseBtn.addEventListener('click', () => {
                this.updateCartQuantity(item.name, item.quantity - 1);
            });

            increaseBtn.addEventListener('click', () => {
                this.updateCartQuantity(item.name, item.quantity + 1);
            });

            removeBtn.addEventListener('click', () => {
                this.removeFromCart(item.name);
            });

            cartItems.appendChild(cartItem);
        });
    }

    showPurchaseModal() {
        if (this.cart.length === 0) return;

        const modal = document.getElementById('purchase-modal');
        const summary = document.getElementById('purchase-summary');
        const modalTotal = document.getElementById('modal-total');

        // Calculate total
        const total = this.cart.reduce((sum, item) => sum + (item.price * item.quantity), 0);
        modalTotal.textContent = `$${this.formatNumber(total)}`;

        // Render summary
        summary.innerHTML = '';
        this.cart.forEach(item => {
            const summaryItem = document.createElement('div');
            summaryItem.className = 'summary-item';
            
            summaryItem.innerHTML = `
                <div>
                    <div class="summary-item-name">${item.label}</div>
                    <div class="summary-item-details">Quantity: ${item.quantity} × $${this.formatNumber(item.price)}</div>
                </div>
                <div class="summary-item-price">$${this.formatNumber(item.price * item.quantity)}</div>
            `;

            summary.appendChild(summaryItem);
        });

        modal.classList.remove('hidden');
        this.playSound('modal-open');
    }

    hidePurchaseModal() {
        const modal = document.getElementById('purchase-modal');
        modal.classList.add('hidden');
    }

    confirmPurchase() {
        this.hidePurchaseModal();
        
        // Send purchase to FiveM
        this.sendCallback('purchase', {
            cart: this.cart
        });

        // Show processing notification via server
        this.sendCallback('showNotification', {
            message: 'Processing your purchase...',
            type: 'info'
        });
    }

    updateStock(stockData) {
        this.stockData = stockData;
        this.renderItems();
    }

    updatePlayerMoney(data) {
        // Add a small delay to ensure DOM elements are available
        setTimeout(() => {
            const currencyTypeElement = document.getElementById('currency-type');
            const currencyAmountElement = document.getElementById('currency-amount');
            
            if (currencyTypeElement && currencyAmountElement) {
                // Format currency type for display
                let displayType = data.currencyType;
                if (data.currencyType === 'cash') {
                    displayType = 'Cash';
                } else if (data.currencyType === 'bank') {
                    displayType = 'Bank';
                } else {
                    // For custom currencies, capitalize first letter
                    displayType = data.currencyType.charAt(0).toUpperCase() + data.currencyType.slice(1);
                }
                
                currencyTypeElement.textContent = displayType;
                currencyAmountElement.textContent = this.formatNumber(data.amount);
                
                console.log('Updated player money:', displayType, '$' + this.formatNumber(data.amount));
            } else {
                console.log('Currency elements not found, retrying in 200ms...');
                // Retry if elements not found
                setTimeout(() => this.updatePlayerMoney(data), 200);
            }
        }, 50);
    }

    updateInitialCurrencyDisplay() {
        const currencyTypeElement = document.getElementById('currency-type');
        const currencyAmountElement = document.getElementById('currency-amount');
        
        if (currencyTypeElement && currencyAmountElement) {
            // Format currency type based on config
            let displayType = this.config.currency;
            if (this.config.currency === 'cash') {
                displayType = 'Cash';
            } else if (this.config.currency === 'bank') {
                displayType = 'Bank';
            } else {
                // For custom currencies, capitalize first letter
                displayType = this.config.currency.charAt(0).toUpperCase() + this.config.currency.slice(1);
            }
            
            currencyTypeElement.textContent = displayType;
            currencyAmountElement.textContent = '...'; // Loading indicator
        }
    }

    playSound(soundType) {
        if (!this.config?.enableSounds) return;

        // Create audio context for UI sounds
        try {
            const audioContext = new (window.AudioContext || window.webkitAudioContext)();
            const oscillator = audioContext.createOscillator();
            const gainNode = audioContext.createGain();

            oscillator.connect(gainNode);
            gainNode.connect(audioContext.destination);

            // Different frequencies for different actions
            switch (soundType) {
                case 'add-to-cart':
                    oscillator.frequency.setValueAtTime(800, audioContext.currentTime);
                    break;
                case 'remove-from-cart':
                    oscillator.frequency.setValueAtTime(400, audioContext.currentTime);
                    break;
                case 'tab-switch':
                    oscillator.frequency.setValueAtTime(600, audioContext.currentTime);
                    break;
                case 'modal-open':
                    oscillator.frequency.setValueAtTime(1000, audioContext.currentTime);
                    break;
                default:
                    oscillator.frequency.setValueAtTime(500, audioContext.currentTime);
            }

            gainNode.gain.setValueAtTime(0.1, audioContext.currentTime);
            gainNode.gain.exponentialRampToValueAtTime(0.01, audioContext.currentTime + 0.1);

            oscillator.start(audioContext.currentTime);
            oscillator.stop(audioContext.currentTime + 0.1);
        } catch (error) {
            // Ignore audio errors
        }
    }

    formatNumber(num) {
        return new Intl.NumberFormat('en-US').format(num);
    }

    sendCallback(action, data = {}) {
        if (window.invokeNative) {
            fetch(`https://${GetParentResourceName()}/${action}`, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json; charset=UTF-8',
                },
                body: JSON.stringify(data)
            }).catch(error => {
                console.error('Callback error:', error);
            });
        }
    }

    handleSearch(searchTerm) {
        this.searchTerm = searchTerm.toLowerCase().trim();
        const clearSearchBtn = document.getElementById('clear-search');
        
        // Show/hide clear button
        if (this.searchTerm) {
            clearSearchBtn.classList.remove('hidden');
        } else {
            clearSearchBtn.classList.add('hidden');
        }

        // Re-render items with search filter
        this.renderItems();
    }

    clearSearch() {
        const searchInput = document.getElementById('search-input');
        const clearSearchBtn = document.getElementById('clear-search');
        
        searchInput.value = '';
        this.searchTerm = '';
        clearSearchBtn.classList.add('hidden');
        
        // Re-render items without filter
        this.renderItems();
    }

    getWeaponImagePath(weaponName) {
        // Ox_inventory weapon image paths - these are the standard paths used by ox_inventory
        const weaponImages = {
            // Pistols
            'weapon_pistol': 'nui://ox_inventory/web/images/weapon_pistol.png',
            'weapon_pistol_mk2': 'nui://ox_inventory/web/images/weapon_pistol_mk2.png',
            'weapon_combatpistol': 'nui://ox_inventory/web/images/weapon_combatpistol.png',
            'weapon_appistol': 'nui://ox_inventory/web/images/weapon_appistol.png',
            'weapon_stungun': 'nui://ox_inventory/web/images/weapon_stungun.png',
            'weapon_pistol50': 'nui://ox_inventory/web/images/weapon_pistol50.png',
            'weapon_snspistol': 'nui://ox_inventory/web/images/weapon_snspistol.png',
            'weapon_snspistol_mk2': 'nui://ox_inventory/web/images/weapon_snspistol_mk2.png',
            'weapon_heavypistol': 'nui://ox_inventory/web/images/weapon_heavypistol.png',
            'weapon_vintagepistol': 'nui://ox_inventory/web/images/weapon_vintagepistol.png',
            'weapon_flaregun': 'nui://ox_inventory/web/images/weapon_flaregun.png',
            'weapon_marksmanpistol': 'nui://ox_inventory/web/images/weapon_marksmanpistol.png',
            'weapon_revolver': 'nui://ox_inventory/web/images/weapon_revolver.png',
            'weapon_revolver_mk2': 'nui://ox_inventory/web/images/weapon_revolver_mk2.png',
            'weapon_doubleaction': 'nui://ox_inventory/web/images/weapon_doubleaction.png',
            'weapon_ceramicpistol': 'nui://ox_inventory/web/images/weapon_ceramicpistol.png',
            'weapon_navyrevolver': 'nui://ox_inventory/web/images/weapon_navyrevolver.png',
            
            // SMGs
            'weapon_microsmg': 'nui://ox_inventory/web/images/weapon_microsmg.png',
            'weapon_smg': 'nui://ox_inventory/web/images/weapon_smg.png',
            'weapon_smg_mk2': 'nui://ox_inventory/web/images/weapon_smg_mk2.png',
            'weapon_assaultsmg': 'nui://ox_inventory/web/images/weapon_assaultsmg.png',
            'weapon_combatpdw': 'nui://ox_inventory/web/images/weapon_combatpdw.png',
            'weapon_machinepistol': 'nui://ox_inventory/web/images/weapon_machinepistol.png',
            'weapon_minismg': 'nui://ox_inventory/web/images/weapon_minismg.png',
            
            // Assault Rifles
            'weapon_assaultrifle': 'nui://ox_inventory/web/images/weapon_assaultrifle.png',
            'weapon_assaultrifle_mk2': 'nui://ox_inventory/web/images/weapon_assaultrifle_mk2.png',
            'weapon_carbinerifle': 'nui://ox_inventory/web/images/weapon_carbinerifle.png',
            'weapon_carbinerifle_mk2': 'nui://ox_inventory/web/images/weapon_carbinerifle_mk2.png',
            'weapon_advancedrifle': 'nui://ox_inventory/web/images/weapon_advancedrifle.png',
            'weapon_specialcarbine': 'nui://ox_inventory/web/images/weapon_specialcarbine.png',
            'weapon_specialcarbine_mk2': 'nui://ox_inventory/web/images/weapon_specialcarbine_mk2.png',
            'weapon_bullpuprifle': 'nui://ox_inventory/web/images/weapon_bullpuprifle.png',
            'weapon_bullpuprifle_mk2': 'nui://ox_inventory/web/images/weapon_bullpuprifle_mk2.png',
            'weapon_compactrifle': 'nui://ox_inventory/web/images/weapon_compactrifle.png',
            'weapon_militaryrifle': 'nui://ox_inventory/web/images/weapon_militaryrifle.png',
            'weapon_heavyrifle': 'nui://ox_inventory/web/images/weapon_heavyrifle.png',
            
            // Shotguns
            'weapon_pumpshotgun': 'nui://ox_inventory/web/images/weapon_pumpshotgun.png',
            'weapon_pumpshotgun_mk2': 'nui://ox_inventory/web/images/weapon_pumpshotgun_mk2.png',
            'weapon_sawnoffshotgun': 'nui://ox_inventory/web/images/weapon_sawnoffshotgun.png',
            'weapon_assaultshotgun': 'nui://ox_inventory/web/images/weapon_assaultshotgun.png',
            'weapon_bullpupshotgun': 'nui://ox_inventory/web/images/weapon_bullpupshotgun.png',
            'weapon_musket': 'nui://ox_inventory/web/images/weapon_musket.png',
            'weapon_heavyshotgun': 'nui://ox_inventory/web/images/weapon_heavyshotgun.png',
            'weapon_dbshotgun': 'nui://ox_inventory/web/images/weapon_dbshotgun.png',
            'weapon_autoshotgun': 'nui://ox_inventory/web/images/weapon_autoshotgun.png',
            'weapon_combatshotgun': 'nui://ox_inventory/web/images/weapon_combatshotgun.png',
            
            // Sniper Rifles
            'weapon_sniperrifle': 'nui://ox_inventory/web/images/weapon_sniperrifle.png',
            'weapon_heavysniper': 'nui://ox_inventory/web/images/weapon_heavysniper.png',
            'weapon_heavysniper_mk2': 'nui://ox_inventory/web/images/weapon_heavysniper_mk2.png',
            'weapon_marksmanrifle': 'nui://ox_inventory/web/images/weapon_marksmanrifle.png',
            'weapon_marksmanrifle_mk2': 'nui://ox_inventory/web/images/weapon_marksmanrifle_mk2.png',
            'weapon_precisionrifle': 'nui://ox_inventory/web/images/weapon_precisionrifle.png',
            
            // Machine Guns
            'weapon_mg': 'nui://ox_inventory/web/images/weapon_mg.png',
            'weapon_combatmg': 'nui://ox_inventory/web/images/weapon_combatmg.png',
            'weapon_combatmg_mk2': 'nui://ox_inventory/web/images/weapon_combatmg_mk2.png',
            'weapon_gusenberg': 'nui://ox_inventory/web/images/weapon_gusenberg.png',
            
            // Melee Weapons
            'weapon_dagger': 'nui://ox_inventory/web/images/weapon_dagger.png',
            'weapon_bat': 'nui://ox_inventory/web/images/weapon_bat.png',
            'weapon_bottle': 'nui://ox_inventory/web/images/weapon_bottle.png',
            'weapon_crowbar': 'nui://ox_inventory/web/images/weapon_crowbar.png',
            'weapon_flashlight': 'nui://ox_inventory/web/images/weapon_flashlight.png',
            'weapon_golfclub': 'nui://ox_inventory/web/images/weapon_golfclub.png',
            'weapon_hammer': 'nui://ox_inventory/web/images/weapon_hammer.png',
            'weapon_hatchet': 'nui://ox_inventory/web/images/weapon_hatchet.png',
            'weapon_knuckle': 'nui://ox_inventory/web/images/weapon_knuckle.png',
            'weapon_knife': 'nui://ox_inventory/web/images/weapon_knife.png',
            'weapon_machete': 'nui://ox_inventory/web/images/weapon_machete.png',
            'weapon_switchblade': 'nui://ox_inventory/web/images/weapon_switchblade.png',
            'weapon_nightstick': 'nui://ox_inventory/web/images/weapon_nightstick.png',
            'weapon_wrench': 'nui://ox_inventory/web/images/weapon_wrench.png',
            'weapon_battleaxe': 'nui://ox_inventory/web/images/weapon_battleaxe.png',
            'weapon_poolcue': 'nui://ox_inventory/web/images/weapon_poolcue.png',
            'weapon_stone_hatchet': 'nui://ox_inventory/web/images/weapon_stone_hatchet.png',
            
            // Thrown Weapons
            'weapon_grenade': 'nui://ox_inventory/web/images/weapon_grenade.png',
            'weapon_bzgas': 'nui://ox_inventory/web/images/weapon_bzgas.png',
            'weapon_molotov': 'nui://ox_inventory/web/images/weapon_molotov.png',
            'weapon_stickybomb': 'nui://ox_inventory/web/images/weapon_stickybomb.png',
            'weapon_proxmine': 'nui://ox_inventory/web/images/weapon_proxmine.png',
            'weapon_snowball': 'nui://ox_inventory/web/images/weapon_snowball.png',
            'weapon_pipebomb': 'nui://ox_inventory/web/images/weapon_pipebomb.png',
            'weapon_ball': 'nui://ox_inventory/web/images/weapon_ball.png',
            'weapon_smokegrenade': 'nui://ox_inventory/web/images/weapon_smokegrenade.png',
            'weapon_flare': 'nui://ox_inventory/web/images/weapon_flare.png',
            
            // Heavy Weapons
            'weapon_rpg': 'nui://ox_inventory/web/images/weapon_rpg.png',
            'weapon_grenadelauncher': 'nui://ox_inventory/web/images/weapon_grenadelauncher.png',
            'weapon_grenadelauncher_smoke': 'nui://ox_inventory/web/images/weapon_grenadelauncher_smoke.png',
            'weapon_minigun': 'nui://ox_inventory/web/images/weapon_minigun.png',
            'weapon_firework': 'nui://ox_inventory/web/images/weapon_firework.png',
            'weapon_railgun': 'nui://ox_inventory/web/images/weapon_railgun.png',
            'weapon_hominglauncher': 'nui://ox_inventory/web/images/weapon_hominglauncher.png',
            'weapon_compactlauncher': 'nui://ox_inventory/web/images/weapon_compactlauncher.png',
            'weapon_rayminigun': 'nui://ox_inventory/web/images/weapon_rayminigun.png',
            
            // Special Weapons
            'weapon_petrolcan': 'nui://ox_inventory/web/images/weapon_petrolcan.png',
            'weapon_parachute': 'nui://ox_inventory/web/images/weapon_parachute.png',
            'weapon_fireextinguisher': 'nui://ox_inventory/web/images/weapon_fireextinguisher.png',
        };

        return weaponImages[weaponName.toLowerCase()] || null;
    }

    getCategoryIcon(category, itemName) {
        // Category-specific icons
        const categoryIcons = {
            'weapons': this.getWeaponIcon(itemName),
            'drugs': 'fas fa-pills',
            'materials': 'fas fa-wrench',
            'electronics': 'fas fa-microchip',
            'documents': 'fas fa-file-alt',
            'services': 'fas fa-handshake',
            'vehicles': 'fas fa-car',
            'misc': 'fas fa-box'
        };

        return categoryIcons[category.toLowerCase()] || 'fas fa-box';
    }

    getWeaponIcon(weaponName) {
        const weaponName_lower = weaponName.toLowerCase();
        
        // Pistol icons
        if (weaponName_lower.includes('pistol') || weaponName_lower.includes('revolver')) {
            return 'fas fa-gun';
        }
        // Rifle/SMG icons
        else if (weaponName_lower.includes('rifle') || weaponName_lower.includes('smg') || weaponName_lower.includes('carbine')) {
            return 'fas fa-rifle';
        }
        // Shotgun icons
        else if (weaponName_lower.includes('shotgun')) {
            return 'fas fa-shotgun';
        }
        // Sniper icons
        else if (weaponName_lower.includes('sniper') || weaponName_lower.includes('marksman')) {
            return 'fas fa-crosshairs';
        }
        // Machine gun icons
        else if (weaponName_lower.includes('mg') || weaponName_lower.includes('gusenberg')) {
            return 'fas fa-gun';
        }
        // Melee weapons
        else if (weaponName_lower.includes('knife') || weaponName_lower.includes('bat') || weaponName_lower.includes('machete')) {
            return 'fas fa-knife';
        }
        // Explosives
        else if (weaponName_lower.includes('grenade') || weaponName_lower.includes('bomb') || weaponName_lower.includes('explosive')) {
            return 'fas fa-bomb';
        }
        // Default weapon icon
        else {
            return 'fas fa-gun';
        }
    }

    getItemImagePath(itemName) {
        // Check for weapon images first
        const weaponImage = this.getWeaponImagePath(itemName);
        if (weaponImage) return weaponImage;

        // Comprehensive item image mapping for ox_inventory and common FiveM items
        const itemImages = {
            // Drugs & Narcotics (Expanded)
            'weed': 'nui://ox_inventory/web/images/weed.png',
            'weed_seed': 'nui://ox_inventory/web/images/weed_seed.png',
            'weed_skunk': 'nui://ox_inventory/web/images/weed_skunk.png',
            'weed_ak47': 'nui://ox_inventory/web/images/weed_ak47.png',
            'weed_amnesia': 'nui://ox_inventory/web/images/weed_amnesia.png',
            'weed_og_kush': 'nui://ox_inventory/web/images/weed_og_kush.png',
            'weed_purple_haze': 'nui://ox_inventory/web/images/weed_purple_haze.png',
            'weed_white_widow': 'nui://ox_inventory/web/images/weed_white_widow.png',
            'cocaine': 'nui://ox_inventory/web/images/cocaine.png',
            'cocaine_bag': 'nui://ox_inventory/web/images/cocaine_bag.png',
            'cocaine_brick': 'nui://ox_inventory/web/images/cocaine_brick.png',
            'coke': 'nui://ox_inventory/web/images/cocaine.png',
            'coke_bag': 'nui://ox_inventory/web/images/cocaine_bag.png',
            'heroin': 'nui://ox_inventory/web/images/heroin.png',
            'heroin_bag': 'nui://ox_inventory/web/images/heroin.png',
            'meth': 'nui://ox_inventory/web/images/meth.png',
            'meth_bag': 'nui://ox_inventory/web/images/meth.png',
            'methlab': 'nui://ox_inventory/web/images/meth.png',
            'crack': 'nui://ox_inventory/web/images/crack.png',
            'crack_bag': 'nui://ox_inventory/web/images/crack.png',
            'ecstasy': 'nui://ox_inventory/web/images/ecstasy.png',
            'xtc': 'nui://ox_inventory/web/images/xtc.png',
            'mdma': 'nui://ox_inventory/web/images/ecstasy.png',
            'lsd': 'nui://ox_inventory/web/images/lsd.png',
            'acid': 'nui://ox_inventory/web/images/lsd.png',
            'opium': 'nui://ox_inventory/web/images/opium.png',
            'mushrooms': 'nui://ox_inventory/web/images/mushrooms.png',
            'shrooms': 'nui://ox_inventory/web/images/mushrooms.png',
            'lean': 'nui://ox_inventory/web/images/lean.png',
            'codeine': 'nui://ox_inventory/web/images/codeine.png',
            'fentanyl': 'nui://ox_inventory/web/images/fentanyl.png',
            'adderall': 'nui://ox_inventory/web/images/adderall.png',
            'xanax': 'nui://ox_inventory/web/images/xanax.png',
            'vicodin': 'nui://ox_inventory/web/images/vicodin.png',
            'oxycontin': 'nui://ox_inventory/web/images/oxycontin.png',
            'percocet': 'nui://ox_inventory/web/images/percocet.png',
            'molly': 'nui://ox_inventory/web/images/molly.png',
            'ketamine': 'nui://ox_inventory/web/images/ketamine.png',
            'pcp': 'nui://ox_inventory/web/images/pcp.png',
            'cannabis': 'nui://ox_inventory/web/images/weed.png',
            'marijuana': 'nui://ox_inventory/web/images/weed.png',
            'hash': 'nui://ox_inventory/web/images/hash.png',
            'hashish': 'nui://ox_inventory/web/images/hash.png',
            
            // Ammunition & Weapon Accessories
            'pistol_ammo': 'nui://ox_inventory/web/images/pistol_ammo.png',
            'ammo-9': 'nui://ox_inventory/web/images/pistol_ammo.png',
            'ammo_9mm': 'nui://ox_inventory/web/images/pistol_ammo.png',
            'ammo-45': 'nui://ox_inventory/web/images/pistol_ammo.png',
            'ammo_45acp': 'nui://ox_inventory/web/images/pistol_ammo.png',
            'ammo-50': 'nui://ox_inventory/web/images/pistol_ammo.png',
            'ammo_50cal': 'nui://ox_inventory/web/images/pistol_ammo.png',
            'rifle_ammo': 'nui://ox_inventory/web/images/rifle_ammo.png',
            'ammo-rifle': 'nui://ox_inventory/web/images/rifle_ammo.png',
            'ammo_rifle': 'nui://ox_inventory/web/images/rifle_ammo.png',
            'ammo-rifle2': 'nui://ox_inventory/web/images/rifle_ammo.png',
            'ammo_556': 'nui://ox_inventory/web/images/rifle_ammo.png',
            'ammo_762': 'nui://ox_inventory/web/images/rifle_ammo.png',
            'smg_ammo': 'nui://ox_inventory/web/images/smg_ammo.png',
            'ammo-smg': 'nui://ox_inventory/web/images/smg_ammo.png',
            'ammo_smg': 'nui://ox_inventory/web/images/smg_ammo.png',
            'shotgun_ammo': 'nui://ox_inventory/web/images/shotgun_ammo.png',
            'ammo-shotgun': 'nui://ox_inventory/web/images/shotgun_ammo.png',
            'ammo_shotgun': 'nui://ox_inventory/web/images/shotgun_ammo.png',
            'ammo_12gauge': 'nui://ox_inventory/web/images/shotgun_ammo.png',
            'sniper_ammo': 'nui://ox_inventory/web/images/sniper_ammo.png',
            'ammo-sniper': 'nui://ox_inventory/web/images/sniper_ammo.png',
            'ammo_sniper': 'nui://ox_inventory/web/images/sniper_ammo.png',
            'ammo_338': 'nui://ox_inventory/web/images/sniper_ammo.png',
            'mg_ammo': 'nui://ox_inventory/web/images/mg_ammo.png',
            'ammo-mg': 'nui://ox_inventory/web/images/mg_ammo.png',
            'ammo_mg': 'nui://ox_inventory/web/images/mg_ammo.png',
            'heavy_ammo': 'nui://ox_inventory/web/images/mg_ammo.png',
            'musket_ammo': 'nui://ox_inventory/web/images/musket_ammo.png',
            'ammo-musket': 'nui://ox_inventory/web/images/musket_ammo.png',
            'flare_ammo': 'nui://ox_inventory/web/images/flare_ammo.png',
            'ammo-flare': 'nui://ox_inventory/web/images/flare_ammo.png',
            'firework_ammo': 'nui://ox_inventory/web/images/firework_ammo.png',
            'ammo-firework': 'nui://ox_inventory/web/images/firework_ammo.png',
            'railgun_ammo': 'nui://ox_inventory/web/images/railgun_ammo.png',
            'ammo-railgun': 'nui://ox_inventory/web/images/railgun_ammo.png',
            'grenade_ammo': 'nui://ox_inventory/web/images/grenade_ammo.png',
            'ammo-grenade': 'nui://ox_inventory/web/images/grenade_ammo.png',
            'emp_ammo': 'nui://ox_inventory/web/images/emp_ammo.png',
            'ammo-emp': 'nui://ox_inventory/web/images/emp_ammo.png',
            
            // Extended Weapon Accessories
            'weapon_scope': 'nui://ox_inventory/web/images/weapon_scope.png',
            'scope': 'nui://ox_inventory/web/images/weapon_scope.png',
            'weapon_suppressor': 'nui://ox_inventory/web/images/weapon_suppressor.png',
            'suppressor': 'nui://ox_inventory/web/images/weapon_suppressor.png',
            'silencer': 'nui://ox_inventory/web/images/weapon_suppressor.png',
            'weapon_grip': 'nui://ox_inventory/web/images/weapon_grip.png',
            'grip': 'nui://ox_inventory/web/images/weapon_grip.png',
            'weapon_flashlight': 'nui://ox_inventory/web/images/weapon_flashlight.png',
            'weapon_light': 'nui://ox_inventory/web/images/weapon_flashlight.png',
            'weapon_skin': 'nui://ox_inventory/web/images/weapon_skin.png',
            'weapon_tint': 'nui://ox_inventory/web/images/weapon_skin.png',
            'weapon_magazine': 'nui://ox_inventory/web/images/weapon_magazine.png',
            'magazine': 'nui://ox_inventory/web/images/weapon_magazine.png',
            'extended_mag': 'nui://ox_inventory/web/images/weapon_magazine.png',
            'drum_mag': 'nui://ox_inventory/web/images/weapon_magazine.png',
            'weapon_stock': 'nui://ox_inventory/web/images/weapon_stock.png',
            'stock': 'nui://ox_inventory/web/images/weapon_stock.png',
            'weapon_barrel': 'nui://ox_inventory/web/images/weapon_barrel.png',
            'barrel': 'nui://ox_inventory/web/images/weapon_barrel.png',
            'weapon_muzzle': 'nui://ox_inventory/web/images/weapon_muzzle.png',
            'muzzle': 'nui://ox_inventory/web/images/weapon_muzzle.png',
            'compensator': 'nui://ox_inventory/web/images/weapon_muzzle.png',
            'muzzle_brake': 'nui://ox_inventory/web/images/weapon_muzzle.png',
            
            // Materials & Components
            'metalscrap': 'nui://ox_inventory/web/images/metalscrap.png',
            'plastic': 'nui://ox_inventory/web/images/plastic.png',
            'copper': 'nui://ox_inventory/web/images/copper.png',
            'aluminum': 'nui://ox_inventory/web/images/aluminum.png',
            'steel': 'nui://ox_inventory/web/images/steel.png',
            'iron': 'nui://ox_inventory/web/images/iron.png',
            'rubber': 'nui://ox_inventory/web/images/rubber.png',
            'glass': 'nui://ox_inventory/web/images/glass.png',
            'electronics': 'nui://ox_inventory/web/images/electronics.png',
            'advancedlockpick': 'nui://ox_inventory/web/images/advancedlockpick.png',
            'lockpick': 'nui://ox_inventory/web/images/lockpick.png',
            'screwdriverset': 'nui://ox_inventory/web/images/screwdriverset.png',
            'trojan_usb': 'nui://ox_inventory/web/images/trojan_usb.png',
            
            // Electronics & Tech
            'phone': 'nui://ox_inventory/web/images/phone.png',
            'radio': 'nui://ox_inventory/web/images/radio.png',
            'laptop': 'nui://ox_inventory/web/images/laptop.png',
            'tablet': 'nui://ox_inventory/web/images/tablet.png',
            'gps': 'nui://ox_inventory/web/images/gps.png',
            'camera': 'nui://ox_inventory/web/images/camera.png',
            'usb': 'nui://ox_inventory/web/images/usb.png',
            'chip': 'nui://ox_inventory/web/images/chip.png',
            'vpn': 'nui://ox_inventory/web/images/vpn.png',
            'cryptostick': 'nui://ox_inventory/web/images/cryptostick.png',
            
            // Food & Drinks
            'bread': 'nui://ox_inventory/web/images/bread.png',
            'water': 'nui://ox_inventory/web/images/water_bottle.png',
            'water_bottle': 'nui://ox_inventory/web/images/water_bottle.png',
            'burger': 'nui://ox_inventory/web/images/burger.png',
            'cola': 'nui://ox_inventory/web/images/cola.png',
            'coffee': 'nui://ox_inventory/web/images/coffee.png',
            'beer': 'nui://ox_inventory/web/images/beer.png',
            'whiskey': 'nui://ox_inventory/web/images/whiskey.png',
            'vodka': 'nui://ox_inventory/web/images/vodka.png',
            'tequila': 'nui://ox_inventory/web/images/tequila.png',
            'sandwich': 'nui://ox_inventory/web/images/sandwich.png',
            'taco': 'nui://ox_inventory/web/images/taco.png',
            'donut': 'nui://ox_inventory/web/images/donut.png',
            'pizza': 'nui://ox_inventory/web/images/pizza.png',
            
            // Medical & Health
            'bandage': 'nui://ox_inventory/web/images/bandage.png',
            'medkit': 'nui://ox_inventory/web/images/medkit.png',
            'painkillers': 'nui://ox_inventory/web/images/painkillers.png',
            'firstaid': 'nui://ox_inventory/web/images/firstaid.png',
            'morphine': 'nui://ox_inventory/web/images/morphine.png',
            'adrenaline': 'nui://ox_inventory/web/images/adrenaline.png',
            'syringe': 'nui://ox_inventory/web/images/syringe.png',
            'pills': 'nui://ox_inventory/web/images/pills.png',
            
            // Clothing & Accessories
            'bag': 'nui://ox_inventory/web/images/bag.png',
            'backpack': 'nui://ox_inventory/web/images/backpack.png',
            'vest': 'nui://ox_inventory/web/images/vest.png',
            'armor': 'nui://ox_inventory/web/images/armor.png',
            'helmet': 'nui://ox_inventory/web/images/helmet.png',
            'mask': 'nui://ox_inventory/web/images/mask.png',
            'gloves': 'nui://ox_inventory/web/images/gloves.png',
            'shoes': 'nui://ox_inventory/web/images/shoes.png',
            
            // Vehicle Items
            'car_key': 'nui://ox_inventory/web/images/car_key.png',
            'vehicle_key': 'nui://ox_inventory/web/images/vehicle_key.png',
            'lockpick_car': 'nui://ox_inventory/web/images/lockpick_car.png',
            'nitrous': 'nui://ox_inventory/web/images/nitrous.png',
            'engine_oil': 'nui://ox_inventory/web/images/engine_oil.png',
            'car_battery': 'nui://ox_inventory/web/images/car_battery.png',
            'tire': 'nui://ox_inventory/web/images/tire.png',
            'repairkit': 'nui://ox_inventory/web/images/repairkit.png',
            
            // Money & Valuables
            'cash': 'nui://ox_inventory/web/images/cash.png',
            'money': 'nui://ox_inventory/web/images/cash.png',
            'black_money': 'nui://ox_inventory/web/images/black_money.png',
            'gold': 'nui://ox_inventory/web/images/gold.png',
            'diamond': 'nui://ox_inventory/web/images/diamond.png',
            'emerald': 'nui://ox_inventory/web/images/emerald.png',
            'ruby': 'nui://ox_inventory/web/images/ruby.png',
            'sapphire': 'nui://ox_inventory/web/images/sapphire.png',
            'goldbar': 'nui://ox_inventory/web/images/goldbar.png',
            'rolex': 'nui://ox_inventory/web/images/rolex.png',
            'goldchain': 'nui://ox_inventory/web/images/goldchain.png',
            
            // Documents & IDs
            'id_card': 'nui://ox_inventory/web/images/id_card.png',
            'driver_license': 'nui://ox_inventory/web/images/driver_license.png',
            'passport': 'nui://ox_inventory/web/images/passport.png',
            'visa': 'nui://ox_inventory/web/images/visa.png',
            'mastercard': 'nui://ox_inventory/web/images/mastercard.png',
            'certificate': 'nui://ox_inventory/web/images/certificate.png',
            'diploma': 'nui://ox_inventory/web/images/diploma.png',
            'contract': 'nui://ox_inventory/web/images/contract.png',
            
            // Tools & Equipment
            'wrench': 'nui://ox_inventory/web/images/wrench.png',
            'hammer': 'nui://ox_inventory/web/images/hammer.png',
            'drill': 'nui://ox_inventory/web/images/drill.png',
            'saw': 'nui://ox_inventory/web/images/saw.png',
            'crowbar': 'nui://ox_inventory/web/images/crowbar.png',
            'thermite': 'nui://ox_inventory/web/images/thermite.png',
            'c4': 'nui://ox_inventory/web/images/c4.png',
            'explosive': 'nui://ox_inventory/web/images/explosive.png',
            'rope': 'nui://ox_inventory/web/images/rope.png',
            'handcuffs': 'nui://ox_inventory/web/images/handcuffs.png',
            'zipties': 'nui://ox_inventory/web/images/zipties.png',
            
            // Miscellaneous
            'cigarette': 'nui://ox_inventory/web/images/cigarette.png',
            'lighter': 'nui://ox_inventory/web/images/lighter.png',
            'joint': 'nui://ox_inventory/web/images/joint.png',
            'rolling_paper': 'nui://ox_inventory/web/images/rolling_paper.png',
            'security_card': 'nui://ox_inventory/web/images/security_card.png',
            'keycard': 'nui://ox_inventory/web/images/keycard.png',
            'painting': 'nui://ox_inventory/web/images/painting.png',
            'sculpture': 'nui://ox_inventory/web/images/sculpture.png',
            'antiquevase': 'nui://ox_inventory/web/images/antiquevase.png',
            'binoculars': 'nui://ox_inventory/web/images/binoculars.png',
            'parachute': 'nui://ox_inventory/web/images/parachute.png',
            'jerry_can': 'nui://ox_inventory/web/images/jerry_can.png',
            'petrol_can': 'nui://ox_inventory/web/images/jerry_can.png',
        };

        return itemImages[itemName.toLowerCase()] || null;
    }
}

// Initialize the UI when DOM is ready
document.addEventListener('DOMContentLoaded', () => {
    window.blackmarketUI = new BlackmarketUI();
});

// Initialize container styles for animations
document.addEventListener('DOMContentLoaded', () => {
    const container = document.querySelector('.container');
    if (container) {
        container.style.opacity = '0';
        container.style.transform = 'scale(0.95)';
        container.style.transition = 'all 0.3s ease';
    }
});

console.log('Nu-Blackmarket UI loaded successfully!'); 