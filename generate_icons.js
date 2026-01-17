const fs = require('fs');
const { createCanvas, loadImage } = require('canvas');

// Function to create icons from source image
async function createIconFromImage(sourceImage, size, filename) {
  const canvas = createCanvas(size, size);
  const ctx = canvas.getContext('2d');
  
  // Load and draw the image
  const img = await loadImage(sourceImage);
  
  // Calculate dimensions to maintain aspect ratio
  let drawWidth = size;
  let drawHeight = size;
  let offsetX = 0;
  let offsetY = 0;
  
  // Draw image centered and scaled
  ctx.drawImage(img, offsetX, offsetY, drawWidth, drawHeight);
  
  // Save to file
  const buffer = canvas.toBuffer('image/png');
  fs.writeFileSync(filename, buffer);
  console.log(`Created ${filename} (${size}x${size})`);
}

// Main function
async function generateIcons() {
  try {
    console.log('Generating icons from source image...');
    
    const sourceImage = 'web/icons/burger_logo.png.png'; // Source image location
    
    // Check if source image exists
    if (!fs.existsSync(sourceImage)) {
      console.error(`Error: Source image "${sourceImage}" not found!`);
      console.log('Please save your burger logo as "burger_logo.png" in the project root folder.');
      return;
    }
    
    // Generate all required icon sizes
    await createIconFromImage(sourceImage, 512, 'web/icons/Icon-512.png');
    await createIconFromImage(sourceImage, 192, 'web/icons/Icon-192.png');
    await createIconFromImage(sourceImage, 512, 'web/icons/Icon-maskable-512.png');
    await createIconFromImage(sourceImage, 192, 'web/icons/Icon-maskable-192.png');
    await createIconFromImage(sourceImage, 48, 'web/favicon.png');
    
    console.log('\n✓ All icons created successfully!');
    console.log('Ready to build and deploy!');
  } catch (error) {
    console.error('Error:', error.message);
    console.log('\nMake sure the canvas package is installed: npm install canvas');
  }
}

// Run the generator
generateIcons();
