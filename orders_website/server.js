const express = require('express');
const cors = require('cors');
const cookieParser = require('cookie-parser');
const fs = require('fs');
const path = require('path');
const XLSX = require('xlsx');
const crypto = require('crypto');

const app = express();
const PORT = process.env.PORT || 8000;

// Test: Persistent disk should preserve data across deploys

// Use persistent disk if available, otherwise use current directory
const DATA_DIR = process.env.PERSISTENT_STORAGE_DIR || __dirname;
const ORDERS_FILE = path.join(DATA_DIR, 'burger_orders.json');
const DISCOUNTS_FILE = path.join(DATA_DIR, 'discount_codes.json');
const HISTORY_FILE = path.join(DATA_DIR, 'fulfilled_orders_history.json');
const USERS_FILE = path.join(DATA_DIR, 'users.json');
const OPENING_HOURS_FILE = path.join(DATA_DIR, 'opening_hours.json');
const CARTS_FILE = path.join(DATA_DIR, 'carts.json');
const RATE_LIMITS_FILE = path.join(DATA_DIR, 'rate_limits.json');

// Log data directory information
console.log('=== DATA DIRECTORY INFO ===');
console.log('PERSISTENT_STORAGE_DIR env:', process.env.PERSISTENT_STORAGE_DIR);
console.log('Using DATA_DIR:', DATA_DIR);
console.log('Current directory:', __dirname);

// Ensure data directory exists (for persistent storage)
if (!fs.existsSync(DATA_DIR)) {
  fs.mkdirSync(DATA_DIR, { recursive: true });
  console.log(`Created data directory: ${DATA_DIR}`);
} else {
  console.log(`Data directory exists: ${DATA_DIR}`);
  // List existing files in data directory
  try {
    const files = fs.readdirSync(DATA_DIR);
    console.log('Files in data directory:', files);
  } catch (e) {
    console.error('Error reading data directory:', e.message);
  }
}

// Helper function to initialize data files from repository defaults
function initializeDataFile(filePath, defaultSourcePath) {
  const fileName = path.basename(filePath);
  
  if (!fs.existsSync(filePath)) {
    console.log(`${fileName} does NOT exist at ${filePath} - initializing...`);
    // Check if we have a source file in the repository to copy from
    if (fs.existsSync(defaultSourcePath)) {
      fs.copyFileSync(defaultSourcePath, filePath);
      console.log(`✓ Initialized ${fileName} from repository defaults`);
    } else {
      // Fallback: create empty array if no default exists
      fs.writeFileSync(filePath, '[]');
      console.log(`✓ Created empty ${fileName}`);
    }
  } else {
    console.log(`✓ ${fileName} already exists at ${filePath} - preserving existing data`);
  }
}

// Middleware
app.use(cors({
  origin: ['http://localhost:3000', 'https://burgercy.com', 'https://www.burgercy.com'],
  credentials: true
}));
app.use(cookieParser());
app.use(express.json());
app.use(express.static(__dirname));

// Initialize all data files with repository defaults if they don't exist
console.log('\n=== INITIALIZING DATA FILES ===');
initializeDataFile(ORDERS_FILE, path.join(__dirname, 'burger_orders.json'));
initializeDataFile(DISCOUNTS_FILE, path.join(__dirname, 'discount_codes.json'));
initializeDataFile(HISTORY_FILE, path.join(__dirname, 'fulfilled_orders_history.json'));
initializeDataFile(USERS_FILE, path.join(__dirname, 'users.json'));
initializeDataFile(OPENING_HOURS_FILE, path.join(__dirname, 'opening_hours.json'));
initializeDataFile(CARTS_FILE, path.join(__dirname, 'carts.json'));
initializeDataFile(RATE_LIMITS_FILE, path.join(__dirname, 'rate_limits.json'));
console.log('=== INITIALIZATION COMPLETE ===\n');

// Helper function to hash passwords
function hashPassword(password) {
  return crypto.createHash('sha256').update(password).digest('hex');
}

// Helper function to generate session token
function generateToken() {
  return crypto.randomBytes(32).toString('hex');
}

// Helper function to generate UUID
function generateUUID() {
  return crypto.randomUUID();
}

// Helper function to validate phone number
function validatePhoneNumber(phone) {
  const cleaned = phone.replace(/\D/g, '');
  return cleaned.length >= 10 && cleaned.length <= 15;
}

// Helper function to sanitize input
function sanitizeInput(input) {
  if (typeof input !== 'string') return input;
  return input.trim().replace(/<script[^>]*>.*?<\/script>/gi, '').replace(/<[^>]+>/g, '');
}

// Rate limiting helper
function checkRateLimit(identifier, endpoint, maxAttempts = 5, windowMinutes = 15) {
  try {
    const rateLimits = JSON.parse(fs.readFileSync(RATE_LIMITS_FILE, 'utf8'));
    const now = new Date();
    const windowStart = new Date(now.getTime() - windowMinutes * 60000);
    
    const cleanedLimits = rateLimits.filter(rl => 
      new Date(rl.windowStart) > windowStart
    );
    
    const existing = cleanedLimits.find(rl => 
      rl.identifier === identifier && rl.endpoint === endpoint
    );
    
    if (!existing) {
      cleanedLimits.push({
        id: generateUUID(),
        identifier,
        endpoint,
        attempts: 1,
        windowStart: now.toISOString()
      });
      fs.writeFileSync(RATE_LIMITS_FILE, JSON.stringify(cleanedLimits, null, 2));
      return { allowed: true, remaining: maxAttempts - 1 };
    }
    
    if (existing.attempts >= maxAttempts) {
      return { 
        allowed: false, 
        remaining: 0,
        retryAfter: Math.ceil((windowMinutes * 60000 - (now - new Date(existing.windowStart))) / 1000)
      };
    }
    
    existing.attempts++;
    fs.writeFileSync(RATE_LIMITS_FILE, JSON.stringify(cleanedLimits, null, 2));
    return { allowed: true, remaining: maxAttempts - existing.attempts };
  } catch (error) {
    console.error('Rate limit check error:', error);
    return { allowed: true, remaining: maxAttempts };
  }
}

// Helper to get or create guest user
function getOrCreateGuestUser(req, res) {
  let userId = req.cookies?.guestUserId;
  const users = JSON.parse(fs.readFileSync(USERS_FILE, 'utf8'));
  
  let user = null;
  if (userId) {
    user = users.find(u => u.id === userId);
  }
  
  if (!user) {
    userId = generateUUID();
    user = {
      id: userId,
      isGuest: true,
      token: generateToken(),
      createdAt: new Date().toISOString(),
      phone: null,
      name: null,
      email: null
    };
    users.push(user);
    fs.writeFileSync(USERS_FILE, JSON.stringify(users, null, 2));
    
    res.cookie('guestUserId', userId, {
      httpOnly: true,
      secure: true,
      sameSite: 'none',
      maxAge: 30 * 24 * 60 * 60 * 1000
    });
    
    res.cookie('authToken', user.token, {
      httpOnly: true,
      secure: true,
      sameSite: 'none',
      maxAge: 30 * 24 * 60 * 60 * 1000
    });
  }
  
  return user;
}

// Middleware to verify authentication token
function authenticateToken(req, res, next) {
  let token = req.headers['authorization']?.replace('Bearer ', '');
  
  if (!token) {
    token = req.cookies?.authToken;
  }
  
  if (!token) {
    return res.status(401).json({ error: 'Authentication required' });
  }
  
  try {
    const users = JSON.parse(fs.readFileSync(USERS_FILE, 'utf8'));
    const user = users.find(u => u.token === token);
    
    if (!user) {
      return res.status(403).json({ error: 'Invalid or expired token' });
    }
    
    req.user = user;
    next();
  } catch (error) {
    console.error('Error verifying token:', error);
    res.status(500).json({ error: 'Authentication failed' });
  }
}

// Middleware for guest detection (auto-create guest user if no auth)
function guestOrAuthMiddleware(req, res, next) {
  let token = req.headers['authorization']?.replace('Bearer ', '');
  
  if (!token) {
    token = req.cookies?.authToken;
  }
  
  try {
    const users = JSON.parse(fs.readFileSync(USERS_FILE, 'utf8'));
    
    if (token) {
      const user = users.find(u => u.token === token);
      if (user) {
        req.user = user;
        return next();
      }
    }
    
    req.user = getOrCreateGuestUser(req, res);
    next();
  } catch (error) {
    console.error('Error in guest middleware:', error);
    req.user = getOrCreateGuestUser(req, res);
    next();
  }
}

// POST endpoint to register a new user
app.post('/api/auth/register', (req, res) => {
  try {
    const { name, email, phone, password } = req.body;
    
    // Validate input
    if (!name || !email || !phone || !password) {
      return res.status(400).json({ error: 'All fields are required' });
    }
    
    // Read existing users
    let users = [];
    if (fs.existsSync(USERS_FILE)) {
      const data = fs.readFileSync(USERS_FILE, 'utf8');
      users = JSON.parse(data);
    }
    
    // Check if user already exists
    const existingUser = users.find(u => u.email === email || u.phone === phone);
    if (existingUser) {
      return res.status(409).json({ error: 'User with this email or phone already exists' });
    }
    
    // Create new user
    const token = generateToken();
    const newUser = {
      id: crypto.randomUUID(),
      name,
      email,
      phone,
      password: hashPassword(password),
      token,
      createdAt: new Date().toISOString()
    };
    
    users.push(newUser);
    fs.writeFileSync(USERS_FILE, JSON.stringify(users, null, 2));
    
    // Return user data without password
    const { password: _, ...userWithoutPassword } = newUser;
    res.json({ success: true, user: userWithoutPassword, token });
  } catch (error) {
    console.error('Error registering user:', error);
    res.status(500).json({ error: 'Failed to register user' });
  }
});

// POST endpoint to login
app.post('/api/auth/login', (req, res) => {
  try {
    const { email, password } = req.body;
    
    // Validate input
    if (!email || !password) {
      return res.status(400).json({ error: 'Email and password are required' });
    }
    
    // Read users
    const users = JSON.parse(fs.readFileSync(USERS_FILE, 'utf8'));
    
    // Find user and verify password
    const user = users.find(u => u.email === email && u.password === hashPassword(password));
    
    if (!user) {
      return res.status(401).json({ error: 'Invalid email or password' });
    }
    
    // Generate new token
    const token = generateToken();
    user.token = token;
    user.lastLogin = new Date().toISOString();
    
    // Save updated users
    fs.writeFileSync(USERS_FILE, JSON.stringify(users, null, 2));
    
    // Return user data without password
    const { password: _, ...userWithoutPassword } = user;
    res.json({ success: true, user: userWithoutPassword, token });
  } catch (error) {
    console.error('Error logging in:', error);
    res.status(500).json({ error: 'Failed to login' });
  }
});

// ==================== CART ENDPOINTS ====================

// GET current user (auto-creates guest if needed)
app.get('/api/auth/me', guestOrAuthMiddleware, (req, res) => {
  try {
    const { password, ...userWithToken } = req.user;
    res.json({ user: userWithToken });
  } catch (error) {
    console.error('Error getting current user:', error);
    res.status(500).json({ error: 'Failed to get user data' });
  }
});

// GET cart for current user
app.get('/api/cart', guestOrAuthMiddleware, (req, res) => {
  try {
    const carts = JSON.parse(fs.readFileSync(CARTS_FILE, 'utf8'));
    let cart = carts.find(c => c.userId === req.user.id);
    
    if (!cart) {
      cart = {
        id: generateUUID(),
        userId: req.user.id,
        items: [],
        discountCode: null,
        discountAmount: 0,
        subtotal: 0,
        total: 0,
        createdAt: new Date().toISOString(),
        updatedAt: new Date().toISOString(),
        expiresAt: new Date(Date.now() + 7 * 24 * 60 * 60 * 1000).toISOString()
      };
      carts.push(cart);
      fs.writeFileSync(CARTS_FILE, JSON.stringify(carts, null, 2));
    }
    
    res.json(cart);
  } catch (error) {
    console.error('Error getting cart:', error);
    res.status(500).json({ error: 'Failed to get cart' });
  }
});

// PUT update cart
app.put('/api/cart', guestOrAuthMiddleware, (req, res) => {
  try {
    const { items, discountCode } = req.body;
    
    if (!Array.isArray(items)) {
      return res.status(400).json({ error: 'Items must be an array' });
    }
    
    const carts = JSON.parse(fs.readFileSync(CARTS_FILE, 'utf8'));
    let cartIndex = carts.findIndex(c => c.userId === req.user.id);
    
    if (cartIndex === -1) {
      const newCart = {
        id: generateUUID(),
        userId: req.user.id,
        items: items,
        discountCode: discountCode || null,
        discountAmount: 0,
        subtotal: 0,
        total: 0,
        createdAt: new Date().toISOString(),
        updatedAt: new Date().toISOString(),
        expiresAt: new Date(Date.now() + 7 * 24 * 60 * 60 * 1000).toISOString()
      };
      carts.push(newCart);
      cartIndex = carts.length - 1;
    } else {
      carts[cartIndex].items = items;
      carts[cartIndex].updatedAt = new Date().toISOString();
      if (discountCode !== undefined) {
        carts[cartIndex].discountCode = discountCode;
      }
    }
    
    const subtotal = items.reduce((sum, item) => sum + (item.price * item.quantity), 0);
    carts[cartIndex].subtotal = subtotal;
    
    let discountAmount = 0;
    if (carts[cartIndex].discountCode) {
      const discounts = JSON.parse(fs.readFileSync(DISCOUNTS_FILE, 'utf8'));
      const discount = discounts.find(d => d.code === carts[cartIndex].discountCode && d.active);
      if (discount) {
        if (discount.type === 'percentage') {
          discountAmount = subtotal * (discount.value / 100);
        } else {
          discountAmount = discount.value;
        }
      }
    }
    carts[cartIndex].discountAmount = discountAmount;
    carts[cartIndex].total = subtotal - discountAmount;
    
    fs.writeFileSync(CARTS_FILE, JSON.stringify(carts, null, 2));
    res.json(carts[cartIndex]);
  } catch (error) {
    console.error('Error updating cart:', error);
    res.status(500).json({ error: 'Failed to update cart' });
  }
});

// DELETE cart
app.delete('/api/cart', guestOrAuthMiddleware, (req, res) => {
  try {
    const carts = JSON.parse(fs.readFileSync(CARTS_FILE, 'utf8'));
    const filtered = carts.filter(c => c.userId !== req.user.id);
    fs.writeFileSync(CARTS_FILE, JSON.stringify(filtered, null, 2));
    res.json({ success: true });
  } catch (error) {
    console.error('Error deleting cart:', error);
    res.status(500).json({ error: 'Failed to delete cart' });
  }
});

// POST checkout - converts guest to permanent user
app.post('/api/cart/checkout', guestOrAuthMiddleware, (req, res) => {
  try {
    const { name, phone } = req.body;
    
    const identifier = req.ip || req.connection.remoteAddress;
    const rateLimit = checkRateLimit(identifier, '/api/cart/checkout', 10, 15);
    
    if (!rateLimit.allowed) {
      return res.status(429).json({ 
        error: 'Too many checkout attempts. Please try again later.',
        retryAfter: rateLimit.retryAfter
      });
    }
    
    if (!name || !phone) {
      return res.status(400).json({ error: 'Name and phone are required' });
    }
    
    const sanitizedName = sanitizeInput(name);
    const sanitizedPhone = sanitizeInput(phone);
    
    if (!validatePhoneNumber(sanitizedPhone)) {
      return res.status(400).json({ error: 'Invalid phone number format' });
    }
    
    const users = JSON.parse(fs.readFileSync(USERS_FILE, 'utf8'));
    const existingUser = users.find(u => u.phone === sanitizedPhone && u.id !== req.user.id);
    
    if (existingUser) {
      return res.status(409).json({ error: 'An account with this phone number already exists' });
    }
    
    const userIndex = users.findIndex(u => u.id === req.user.id);
    if (userIndex !== -1) {
      users[userIndex].name = sanitizedName;
      users[userIndex].phone = sanitizedPhone;
      users[userIndex].isGuest = false;
      users[userIndex].updatedAt = new Date().toISOString();
      
      fs.writeFileSync(USERS_FILE, JSON.stringify(users, null, 2));
      
      const { password, ...userWithoutPassword } = users[userIndex];
      res.json({ 
        success: true, 
        user: userWithoutPassword,
        message: 'Account created successfully'
      });
    } else {
      res.status(404).json({ error: 'User not found' });
    }
  } catch (error) {
    console.error('Error during checkout:', error);
    res.status(500).json({ error: 'Checkout failed' });
  }
});

// GET endpoint to fetch current user's orders
app.get('/api/user/orders', authenticateToken, (req, res) => {
  try {
    const data = fs.readFileSync(ORDERS_FILE, 'utf8');
    const orders = JSON.parse(data);
    
    // Filter orders by user ID
    const userOrders = orders.filter(order => order.userId === req.user.id);
    
    res.json(userOrders);
  } catch (error) {
    console.error('Error reading user orders:', error);
    res.status(500).json({ error: 'Failed to read orders' });
  }
});

// GET endpoint to fetch orders by user identifier (email, phone, or userId)
app.get('/api/orders/by-user', (req, res) => {
  try {
    const { userId, email, phone } = req.query;
    
    if (!userId && !email && !phone) {
      return res.status(400).json({ error: 'userId, email, or phone required' });
    }
    
    const data = fs.readFileSync(ORDERS_FILE, 'utf8');
    const orders = JSON.parse(data);
    
    // Filter orders by any matching identifier
    const userOrders = orders.filter(order => 
      (userId && order.userId === userId) ||
      (email && order.userEmail === email) ||
      (phone && order.userPhone === phone)
    );
    
    res.json(userOrders);
  } catch (error) {
    console.error('Error reading orders by user:', error);
    res.status(500).json({ error: 'Failed to read orders' });
  }
});

// GET endpoint to fetch all orders
app.get('/api/orders', (req, res) => {
  try {
    const data = fs.readFileSync(ORDERS_FILE, 'utf8');
    const orders = JSON.parse(data);
    res.json(orders);
  } catch (error) {
    console.error('Error reading orders:', error);
    res.status(500).json({ error: 'Failed to read orders' });
  }
});

// POST endpoint to add a new order
app.post('/api/orders', guestOrAuthMiddleware, (req, res) => {
  try {
    const orderData = req.body;
    
    const rateLimit = checkRateLimit(req.user.id, '/api/orders', 10, 15);
    
    if (!rateLimit.allowed) {
      return res.status(429).json({ 
        error: 'Too many order attempts. Please try again later.',
        retryAfter: rateLimit.retryAfter
      });
    }
    
    // Check if store is currently open
    const openingHours = JSON.parse(fs.readFileSync(OPENING_HOURS_FILE, 'utf8'));
    
    // Use Greece timezone (UTC+2/+3)
    const now = new Date();
    const greeceTime = new Date(now.toLocaleString('en-US', { timeZone: 'Europe/Athens' }));
    
    const dayNames = ['sunday', 'monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday'];
    const currentDay = dayNames[greeceTime.getDay()];
    const dayHours = openingHours[currentDay];
    
    // Check if today is closed or if current time is outside opening hours
    if (dayHours === 'Closed' || !dayHours) {
      return res.status(400).json({ 
        error: 'Store is currently closed',
        closed: true 
      });
    }
    
    if (dayHours.open && dayHours.close) {
      const currentTime = greeceTime.getHours() * 60 + greeceTime.getMinutes(); // Convert to minutes
      const [openHour, openMin] = dayHours.open.split(':').map(Number);
      const [closeHour, closeMin] = dayHours.close.split(':').map(Number);
      const openTime = openHour * 60 + openMin;
      const closeTime = closeHour * 60 + closeMin;
      
      const isOpen = currentTime >= openTime && currentTime < closeTime;
      
      if (!isOpen) {
        return res.status(400).json({ 
          error: `Store is currently closed. Opening hours: ${dayHours.open} - ${dayHours.close}`,
          closed: true,
          hours: dayHours
        });
      }
    }
    
    // Read existing orders
    let orders = [];
    if (fs.existsSync(ORDERS_FILE)) {
      const data = fs.readFileSync(ORDERS_FILE, 'utf8');
      orders = JSON.parse(data);
    }
    
    const newOrder = {
      id: generateUUID(),
      userId: req.user.id,
      ...orderData,
      createdAt: new Date().toISOString(),
      status: orderData.status || 'pending'
    };
    
    // Add new order
    orders.push(newOrder);
    
    // Save to file
    fs.writeFileSync(ORDERS_FILE, JSON.stringify(orders, null, 2));
    
    // Clear user's cart after successful order
    try {
      const carts = JSON.parse(fs.readFileSync(CARTS_FILE, 'utf8'));
      const filtered = carts.filter(c => c.userId !== req.user.id);
      fs.writeFileSync(CARTS_FILE, JSON.stringify(filtered, null, 2));
    } catch (e) {
      console.error('Error clearing cart:', e);
    }
    
    res.json({ success: true, message: 'Order saved successfully', order: newOrder });
  } catch (error) {
    console.error('Error saving order:', error);
    res.status(500).json({ error: 'Failed to save order' });
  }
});

// DELETE endpoint to clear all orders (must be before /:index route)
app.delete('/api/orders/all', (req, res) => {
  try {
    // Clear all orders
    fs.writeFileSync(ORDERS_FILE, '[]');
    
    res.json({ success: true, message: 'All orders cleared successfully' });
  } catch (error) {
    console.error('Error clearing orders:', error);
    res.status(500).json({ error: 'Failed to clear orders' });
  }
});

// PATCH endpoint to update order status (mark as fulfilled)
app.patch('/api/orders/:index', (req, res) => {
  try {
    const index = parseInt(req.params.index);
    const { fulfilled } = req.body;
    
    // Read existing orders
    const data = fs.readFileSync(ORDERS_FILE, 'utf8');
    let orders = JSON.parse(data);
    
    // Validate index
    if (index < 0 || index >= orders.length) {
      console.log(`Invalid index ${index}, orders length: ${orders.length}`);
      return res.status(400).json({ error: 'Invalid order index' });
    }
    
    // Update order status
    orders[index].fulfilled = fulfilled;
    
    // Save to file
    fs.writeFileSync(ORDERS_FILE, JSON.stringify(orders, null, 2));
    
    console.log(`Order at index ${index} marked as ${fulfilled ? 'fulfilled' : 'pending'}`);
    res.json({ success: true, message: 'Order updated successfully' });
  } catch (error) {
    console.error('Error updating order:', error);
    res.status(500).json({ error: 'Failed to update order' });
  }
});

// PATCH endpoint to confirm order
app.patch('/api/orders/:index/confirm', (req, res) => {
  try {
    const index = parseInt(req.params.index);
    const { confirmed } = req.body;
    
    // Read existing orders
    const data = fs.readFileSync(ORDERS_FILE, 'utf8');
    let orders = JSON.parse(data);
    
    // Validate index
    if (index < 0 || index >= orders.length) {
      console.log(`Invalid index ${index}, orders length: ${orders.length}`);
      return res.status(400).json({ error: 'Invalid order index' });
    }
    
    // Update order confirmation status
    orders[index].confirmed = confirmed;
    orders[index].confirmedAt = new Date().toISOString();
    
    // Increment discount code usage count when order is confirmed
    if (confirmed && orders[index].discountCode) {
      try {
        const discountData = fs.readFileSync(DISCOUNTS_FILE, 'utf8');
        const discounts = JSON.parse(discountData);
        const discount = discounts.find(d => d.code.toUpperCase() === orders[index].discountCode.toUpperCase());
        
        if (discount) {
          discount.usedCount = (discount.usedCount || 0) + 1;
          fs.writeFileSync(DISCOUNTS_FILE, JSON.stringify(discounts, null, 2));
          console.log(`Discount code ${discount.code} used count incremented to ${discount.usedCount}`);
        }
      } catch (error) {
        console.error('Error updating discount usage:', error);
      }
    }
    
    // Save to file
    fs.writeFileSync(ORDERS_FILE, JSON.stringify(orders, null, 2));
    
    console.log(`Order at index ${index} confirmed`);
    
    // Auto-set preparing status after 5 minutes
    if (confirmed) {
      setTimeout(() => {
        try {
          const data = fs.readFileSync(ORDERS_FILE, 'utf8');
          let orders = JSON.parse(data);
          
          if (index < orders.length && orders[index].confirmed) {
            orders[index].preparing = true;
            orders[index].preparingAt = new Date().toISOString();
            fs.writeFileSync(ORDERS_FILE, JSON.stringify(orders, null, 2));
            console.log(`Order at index ${index} automatically set to preparing`);
          }
        } catch (error) {
          console.error('Error auto-setting preparing status:', error);
        }
      }, 5 * 60 * 1000); // 5 minutes
    }
    
    res.json({ success: true, message: 'Order confirmed successfully' });
  } catch (error) {
    console.error('Error confirming order:', error);
    res.status(500).json({ error: 'Failed to confirm order' });
  }
});

// PATCH endpoint to mark order as cooked (out for delivery)
app.patch('/api/orders/:index/cooked', (req, res) => {
  try {
    const index = parseInt(req.params.index);
    const { cooked } = req.body;
    
    // Read existing orders
    const data = fs.readFileSync(ORDERS_FILE, 'utf8');
    let orders = JSON.parse(data);
    
    // Validate index
    if (index < 0 || index >= orders.length) {
      console.log(`Invalid index ${index}, orders length: ${orders.length}`);
      return res.status(400).json({ error: 'Invalid order index' });
    }
    
    // Update order cooked status
    orders[index].cooked = cooked;
    orders[index].cookedAt = new Date().toISOString();
    
    // Save to file
    fs.writeFileSync(ORDERS_FILE, JSON.stringify(orders, null, 2));
    
    console.log(`Order at index ${index} marked as cooked`);
    res.json({ success: true, message: 'Order marked as cooked successfully' });
  } catch (error) {
    console.error('Error marking order as cooked:', error);
    res.status(500).json({ error: 'Failed to mark order as cooked' });
  }
});

// DELETE endpoint to remove an order by index
app.delete('/api/orders/:index', (req, res) => {
  try {
    const index = parseInt(req.params.index);
    
    // Read existing orders
    const data = fs.readFileSync(ORDERS_FILE, 'utf8');
    let orders = JSON.parse(data);
    
    // Validate index
    if (index < 0 || index >= orders.length) {
      return res.status(400).json({ error: 'Invalid order index' });
    }
    
    // Get the order to be deleted
    const deletedOrder = orders[index];
    
    // If order is fulfilled, save to history
    if (deletedOrder.fulfilled) {
      const historyData = fs.readFileSync(HISTORY_FILE, 'utf8');
      let history = JSON.parse(historyData);
      
      // Add deletion timestamp
      deletedOrder.deletedAt = new Date().toISOString();
      
      history.unshift(deletedOrder); // Add to beginning of array
      fs.writeFileSync(HISTORY_FILE, JSON.stringify(history, null, 2));
    }
    
    // Remove order
    orders.splice(index, 1);
    
    // Save to file
    fs.writeFileSync(ORDERS_FILE, JSON.stringify(orders, null, 2));
    
    res.json({ success: true, message: 'Order deleted successfully' });
  } catch (error) {
    console.error('Error deleting order:', error);
    res.status(500).json({ error: 'Failed to delete order' });
  }
});

// DELETE endpoint to cancel an order by timestamp (for users)
app.delete('/api/orders/cancel/:timestamp', (req, res) => {
  try {
    const timestamp = req.params.timestamp;
    
    // Read existing orders
    const data = fs.readFileSync(ORDERS_FILE, 'utf8');
    let orders = JSON.parse(data);
    
    // Find order by timestamp
    const orderIndex = orders.findIndex(o => o.timestamp === timestamp);
    
    if (orderIndex === -1) {
      return res.status(404).json({ error: 'Order not found' });
    }
    
    const order = orders[orderIndex];
    
    // Check if order is already confirmed
    if (order.confirmed) {
      return res.status(400).json({ error: 'Cannot cancel confirmed order' });
    }
    
    // Remove order
    orders.splice(orderIndex, 1);
    
    // Save to file
    fs.writeFileSync(ORDERS_FILE, JSON.stringify(orders, null, 2));
    
    res.json({ success: true, message: 'Order cancelled successfully' });
  } catch (error) {
    console.error('Error cancelling order:', error);
    res.status(500).json({ error: 'Failed to cancel order' });
  }
});

// DISCOUNT CODE ENDPOINTS

// POST endpoint to validate discount code
app.post('/api/validate-discount', (req, res) => {
  try {
    const { code } = req.body;
    
    if (!code) {
      return res.json({ valid: false, message: 'Please enter a code' });
    }
    
    // Read discount codes
    const data = fs.readFileSync(DISCOUNTS_FILE, 'utf8');
    const discounts = JSON.parse(data);
    
    // Find the discount code
    const discount = discounts.find(d => d.code.toUpperCase() === code.toUpperCase());
    
    if (!discount) {
      return res.json({ valid: false, message: 'Invalid discount code' });
    }
    
    // Check if expired
    const expiryDate = new Date(discount.expiryDate);
    const today = new Date();
    // Set expiry to end of day (23:59:59)
    expiryDate.setHours(23, 59, 59, 999);
    // Set today to start of day for comparison
    today.setHours(0, 0, 0, 0);
    
    if (expiryDate < today) {
      return res.json({ valid: false, message: 'Discount code expired' });
    }
    
    // Check usage limit
    if (discount.usageLimit > 0 && discount.usedCount >= discount.usageLimit) {
      return res.json({ valid: false, message: 'Discount code limit reached' });
    }
    
    // Don't increment usage count here - only increment when order is confirmed
    
    res.json({ 
      valid: true, 
      discountPercent: discount.discountPercent,
      message: `${discount.discountPercent}% discount applied!`
    });
  } catch (error) {
    console.error('Error validating discount:', error);
    res.status(500).json({ valid: false, message: 'Error validating code' });
  }
});

// GET endpoint to fetch all discount codes
app.get('/api/discounts', (req, res) => {
  try {
    const data = fs.readFileSync(DISCOUNTS_FILE, 'utf8');
    const discounts = JSON.parse(data);
    res.json(discounts);
  } catch (error) {
    console.error('Error reading discounts:', error);
    res.status(500).json({ error: 'Failed to read discounts' });
  }
});

// POST endpoint to create a new discount code
app.post('/api/discounts', (req, res) => {
  try {
    const { code, discountPercent, expiryDate, usageLimit } = req.body;
    
    // Read existing discounts
    const data = fs.readFileSync(DISCOUNTS_FILE, 'utf8');
    let discounts = JSON.parse(data);
    
    // Check if code already exists
    if (discounts.find(d => d.code.toUpperCase() === code.toUpperCase())) {
      return res.status(400).json({ error: 'Discount code already exists' });
    }
    
    // Create new discount
    const newDiscount = {
      code: code.toUpperCase(),
      discountPercent: parseInt(discountPercent),
      expiryDate,
      usageLimit: parseInt(usageLimit),
      usedCount: 0,
      createdAt: new Date().toISOString()
    };
    
    discounts.push(newDiscount);
    
    // Save to file
    fs.writeFileSync(DISCOUNTS_FILE, JSON.stringify(discounts, null, 2));
    
    res.json({ success: true, discount: newDiscount });
  } catch (error) {
    console.error('Error creating discount:', error);
    res.status(500).json({ error: 'Failed to create discount' });
  }
});

// DELETE endpoint to delete a discount code
app.delete('/api/discounts/:index', (req, res) => {
  try {
    const index = parseInt(req.params.index);
    
    // Read existing discounts
    const data = fs.readFileSync(DISCOUNTS_FILE, 'utf8');
    let discounts = JSON.parse(data);
    
    // Validate index
    if (index < 0 || index >= discounts.length) {
      return res.status(400).json({ error: 'Invalid discount index' });
    }
    
    // Remove discount
    discounts.splice(index, 1);
    
    // Save to file
    fs.writeFileSync(DISCOUNTS_FILE, JSON.stringify(discounts, null, 2));
    
    res.json({ success: true, message: 'Discount deleted successfully' });
  } catch (error) {
    console.error('Error deleting discount:', error);
    res.status(500).json({ error: 'Failed to delete discount' });
  }
});

// HISTORY ENDPOINTS

// GET endpoint to fetch fulfilled orders history
app.get('/api/history', (req, res) => {
  try {
    const data = fs.readFileSync(HISTORY_FILE, 'utf8');
    const history = JSON.parse(data);
    res.json(history);
  } catch (error) {
    console.error('Error reading history:', error);
    res.status(500).json({ error: 'Failed to read history' });
  }
});

// DELETE endpoint to clear history
app.delete('/api/history/all', (req, res) => {
  try {
    fs.writeFileSync(HISTORY_FILE, '[]');
    res.json({ success: true, message: 'History cleared successfully' });
  } catch (error) {
    console.error('Error clearing history:', error);
    res.status(500).json({ error: 'Failed to clear history' });
  }
});

// DELETE endpoint to remove single item from history
app.delete('/api/history/:index', (req, res) => {
  try {
    const index = parseInt(req.params.index);
    
    const data = fs.readFileSync(HISTORY_FILE, 'utf8');
    let history = JSON.parse(data);
    
    if (index < 0 || index >= history.length) {
      return res.status(400).json({ error: 'Invalid history index' });
    }
    
    history.splice(index, 1);
    fs.writeFileSync(HISTORY_FILE, JSON.stringify(history, null, 2));
    
    res.json({ success: true, message: 'History item deleted successfully' });
  } catch (error) {
    console.error('Error deleting history item:', error);
    res.status(500).json({ error: 'Failed to delete history item' });
  }
});

// GET endpoint to export customer contacts to Excel
app.get('/api/export-contacts', (req, res) => {
  try {
    // Read orders and history
    const ordersData = fs.readFileSync(ORDERS_FILE, 'utf8');
    const orders = JSON.parse(ordersData);
    
    const historyData = fs.readFileSync(HISTORY_FILE, 'utf8');
    const history = JSON.parse(historyData);
    
    // Combine all orders
    const allOrders = [...orders, ...history];
    
    // Extract unique contacts
    const contactsMap = new Map();
    allOrders.forEach((order, index) => {
      if (order.userName || order.userEmail || order.userPhone) {
        const key = `${order.userName || ''}_${order.userEmail || ''}_${order.userPhone || ''}`;
        if (!contactsMap.has(key)) {
          contactsMap.set(key, {
            'Name': order.userName || 'N/A',
            'Email': order.userEmail || 'N/A',
            'Phone': order.userPhone || 'N/A',
            'Last Order Date': order.timestamp ? new Date(order.timestamp).toLocaleDateString() : 'N/A',
            'Total Orders': 1
          });
        } else {
          const contact = contactsMap.get(key);
          contact['Total Orders']++;
          // Update last order date if newer
          if (order.timestamp) {
            const orderDate = new Date(order.timestamp);
            const currentDate = new Date(contact['Last Order Date']);
            if (orderDate > currentDate) {
              contact['Last Order Date'] = orderDate.toLocaleDateString();
            }
          }
        }
      }
    });
    
    // Convert to array
    const contactsArray = Array.from(contactsMap.values());
    
    if (contactsArray.length === 0) {
      return res.status(404).json({ error: 'No contacts found' });
    }
    
    // Create workbook and worksheet
    const wb = XLSX.utils.book_new();
    const ws = XLSX.utils.json_to_sheet(contactsArray);
    
    // Set column widths
    ws['!cols'] = [
      { wch: 20 }, // Name
      { wch: 30 }, // Email
      { wch: 15 }, // Phone
      { wch: 15 }, // Last Order Date
      { wch: 12 }  // Total Orders
    ];
    
    XLSX.utils.book_append_sheet(wb, ws, 'Customer Contacts');
    
    // Generate buffer
    const buffer = XLSX.write(wb, { type: 'buffer', bookType: 'xlsx' });
    
    // Send file
    res.setHeader('Content-Disposition', 'attachment; filename=customer_contacts.xlsx');
    res.setHeader('Content-Type', 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
    res.send(buffer);
    
  } catch (error) {
    console.error('Error exporting contacts:', error);
    res.status(500).json({ error: 'Failed to export contacts' });
  }
});

// GET endpoint to retrieve opening hours
app.get('/api/opening-hours', (req, res) => {
  try {
    const data = fs.readFileSync(OPENING_HOURS_FILE, 'utf8');
    const hours = JSON.parse(data);
    res.json(hours);
  } catch (error) {
    console.error('Error reading opening hours:', error);
    res.status(500).json({ error: 'Failed to load opening hours' });
  }
});

// GET endpoint to check if store is currently open
app.get('/api/is-open', (req, res) => {
  try {
    const openingHours = JSON.parse(fs.readFileSync(OPENING_HOURS_FILE, 'utf8'));
    
    // Use Greece timezone (UTC+2/+3)
    const now = new Date();
    const greeceTime = new Date(now.toLocaleString('en-US', { timeZone: 'Europe/Athens' }));
    
    const dayNames = ['sunday', 'monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday'];
    const currentDay = dayNames[greeceTime.getDay()];
    const dayHours = openingHours[currentDay];
    
    if (dayHours === 'Closed' || !dayHours) {
      return res.json({ 
        isOpen: false, 
        message: 'Store is currently closed',
        currentDay: currentDay
      });
    }
    
    if (dayHours.open && dayHours.close) {
      const currentTime = greeceTime.getHours() * 60 + greeceTime.getMinutes();
      const [openHour, openMin] = dayHours.open.split(':').map(Number);
      const [closeHour, closeMin] = dayHours.close.split(':').map(Number);
      const openTime = openHour * 60 + openMin;
      const closeTime = closeHour * 60 + closeMin;
      
      const isOpen = currentTime >= openTime && currentTime < closeTime;
      
      return res.json({
        isOpen,
        message: isOpen ? 'Store is open' : `Store is currently closed. Opening hours: ${dayHours.open} - ${dayHours.close}`,
        currentDay,
        hours: dayHours
      });
    }
    
    res.json({ isOpen: false, message: 'Opening hours not configured' });
  } catch (error) {
    console.error('Error checking store status:', error);
    res.status(500).json({ error: 'Failed to check store status' });
  }
});

// PUT endpoint to update opening hours
app.put('/api/opening-hours', (req, res) => {
  try {
    const hours = req.body;
    
    // Validate input
    const days = ['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday'];
    for (const day of days) {
      if (!hours[day]) {
        return res.status(400).json({ error: `Missing hours for ${day}` });
      }
    }
    
    fs.writeFileSync(OPENING_HOURS_FILE, JSON.stringify(hours, null, 2));
    res.json({ success: true, hours });
  } catch (error) {
    console.error('Error updating opening hours:', error);
    res.status(500).json({ error: 'Failed to update opening hours' });
  }
});

app.listen(PORT, '0.0.0.0', () => {
  console.log(`Server running at http://localhost:${PORT}`);
  console.log(`Dashboard available at http://localhost:${PORT}/index.html`);
});
