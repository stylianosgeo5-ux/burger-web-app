const express = require('express');
const cors = require('cors');
const fs = require('fs');
const path = require('path');
const XLSX = require('xlsx');

const app = express();
const PORT = process.env.PORT || 8000;
const ORDERS_FILE = path.join(__dirname, 'burger_orders.json');
const DISCOUNTS_FILE = path.join(__dirname, 'discount_codes.json');
const HISTORY_FILE = path.join(__dirname, 'fulfilled_orders_history.json');

// Middleware
app.use(cors());
app.use(express.json());
app.use(express.static(__dirname));

// Initialize orders file if it doesn't exist
if (!fs.existsSync(ORDERS_FILE)) {
  fs.writeFileSync(ORDERS_FILE, '[]');
}

// Initialize discounts file if it doesn't exist
if (!fs.existsSync(DISCOUNTS_FILE)) {
  fs.writeFileSync(DISCOUNTS_FILE, '[]');
}

// Initialize history file if it doesn't exist
if (!fs.existsSync(HISTORY_FILE)) {
  fs.writeFileSync(HISTORY_FILE, '[]');
}

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
app.post('/api/orders', (req, res) => {
  try {
    const newOrder = req.body;
    
    // Read existing orders
    let orders = [];
    if (fs.existsSync(ORDERS_FILE)) {
      const data = fs.readFileSync(ORDERS_FILE, 'utf8');
      orders = JSON.parse(data);
    }
    
    // Add new order
    orders.push(newOrder);
    
    // Save to file
    fs.writeFileSync(ORDERS_FILE, JSON.stringify(orders, null, 2));
    
    res.json({ success: true, message: 'Order saved successfully' });
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
    if (new Date(discount.expiryDate) < new Date()) {
      return res.json({ valid: false, message: 'Discount code expired' });
    }
    
    // Check usage limit
    if (discount.usageLimit > 0 && discount.usedCount >= discount.usageLimit) {
      return res.json({ valid: false, message: 'Discount code limit reached' });
    }
    
    // Increment usage count
    discount.usedCount = (discount.usedCount || 0) + 1;
    fs.writeFileSync(DISCOUNTS_FILE, JSON.stringify(discounts, null, 2));
    
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

app.listen(PORT, '0.0.0.0', () => {
  console.log(`Server running at http://localhost:${PORT}`);
  console.log(`Dashboard available at http://localhost:${PORT}/index.html`);
});
