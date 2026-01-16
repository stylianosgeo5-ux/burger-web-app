const fs = require('fs');
const { createCanvas } = require('canvas');

// Function to create an icon with emoji
function createEmojiIcon(size, emoji, filename) {
  const canvas = createCanvas(size, size);
  const ctx = canvas.getContext('2d');
  
  // Orange background
  ctx.fillStyle = '#FF6B35';
  ctx.fillRect(0, 0, size, size);
  
  // Draw emoji
  ctx.font = `${size * 0.7}px Arial`;
  ctx.textAlign = 'center';
  ctx.textBaseline = 'middle';
  ctx.fillText(emoji, size / 2, size / 2);
  
  // Save to file
  const buffer = canvas.toBuffer('image/png');
  fs.writeFileSync(filename, buffer);
  console.log(`Created ${filename}`);
}

// Create icons
try {
  const emoji = '🍔';
  
  createEmojiIcon(192, emoji, 'web/icons/Icon-192.png');
  createEmojiIcon(512, emoji, 'web/icons/Icon-512.png');
  createEmojiIcon(192, emoji, 'web/icons/Icon-maskable-192.png');
  createEmojiIcon(512, emoji, 'web/icons/Icon-maskable-512.png');
  createEmojiIcon(16, emoji, 'web/favicon.png');
  
  console.log('All icons created successfully!');
} catch (error) {
  console.error('Error:', error.message);
  console.log('\nPlease install canvas package: npm install canvas');
}
