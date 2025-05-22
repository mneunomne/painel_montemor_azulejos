PImage sourceImage;
int cols = 22;
int rows = 14;
int tileWidth;  // Will be calculated based on the image
int tileHeight; // Will be calculated based on the image
String outputFolder = "extracted_tiles/"; // Folder to save the tiles

PImage outputImg; 

void setup() {
  size(2200, 1356); // Display size (can be adjusted)

  outputImg = createImage(width, height, RGB);
  
  // Load the source image
  sourceImage = loadImage("painel-montemor-HD-contrast-inverted.png"); // Replace with your image filename

  println("Loaded image: " + sourceImage.width + "x" + sourceImage.height);
  
  // Calculate tile dimensions based on the image size
  tileWidth = sourceImage.width / cols;
  tileHeight = tileWidth;
  
  // Extract and save tiles
  extractTiles();
  
  println("Extraction complete! " + (cols * rows) + " tiles saved to " + outputFolder);
}

void draw() {
  // Display the source image
  image(outputImg, 0, 0, width, height);
  
  // Draw grid to visualize tiles
  stroke(255, 0, 0);
  noFill();
  
  float scaleX = (float) width / sourceImage.width;
  float scaleY = (float) height / sourceImage.height;
  
  for (int y = 0; y < rows; y++) {
    for (int x = 0; x < cols; x++) {
      rect(x * tileWidth * scaleX, y * tileHeight * scaleY, 
           tileWidth * scaleX, tileHeight * scaleY);
    }
  }
}

void extractTiles() {
  for (int y = 0; y < rows; y++) {
    for (int x = 0; x < cols; x++) {
      // Extract tile
      float scale = 3.5;

      int w = int(tileWidth * scale);
      int h = int(tileHeight * scale);

      PImage tile = createImage(w, h, RGB);
      
      tile.copy(sourceImage,
                x * tileWidth, y * tileHeight, tileWidth, tileHeight,
                0, 0, w, h);
      
      // Convert to grayscale and add noise grain
      float noiseAmount = 20.0; // Adjust this value to control the noise intensity
      PImage grayscaleNoisyTile = addGrayscaleNoiseGrain(tile, noiseAmount);

      PImage binaryTile = createBinaryHalftone(grayscaleNoisyTile);//createBinaryHalftone(grayscaleNoisyTile);

      // Convert to grayscale first
      PImage grayscaleTile = createImage(tile.width, tile.height, RGB);
      grayscaleTile.copy(tile, 0, 0, tile.width, tile.height, 0, 0, tile.width, tile.height);
      grayscaleTile.filter(GRAY);
      
      // Apply combined dithering
      int steps = 1; // For binary output
      float randomFactor = 30; // Adjust for more/less randomness
      
      // Choose one of these approaches:
      PImage ditheredTile = applyCombinedBinaryDither(grayscaleTile, randomFactor);

      int outputTileWidth = outputImg.width / cols;
      int outputTileHeight = outputTileWidth;

      outputImg.copy(ditheredTile, 0, 0, w, h, 
                x * outputTileWidth, y * outputTileHeight, outputTileWidth, outputTileHeight);
      
      // Save tile with row-column naming
      String fileName = outputFolder + "tile_" + nf(y+1, 2) + "_" + nf(x+1, 2) + ".png";
      ditheredTile.save(fileName);
    }
  }
}

// Function to convert image to grayscale and add grayscale noise (WITH WHITE AREA PROTECTION)
PImage addGrayscaleNoiseGrain(PImage img, float noiseAmount) {
  PImage result = createImage(img.width, img.height, RGB);
  img.loadPixels();
  result.loadPixels();
  
  float whiteThreshold = 240; // Pixels above this value are considered "pure white"
  
  for (int y = 0; y < img.height; y++) {
    for (int x = 0; x < img.width; x++) {
      int loc = x + y * img.width;
      
      // Get the original pixel color
      color pixelColor = img.pixels[loc];
      
      // Convert to grayscale (average method)
      float gray = (red(pixelColor) + green(pixelColor) + blue(pixelColor)) / 3;
      
      // Only add noise if the area is NOT pure white
      if (gray < whiteThreshold) {
        // Generate a random value for noise
        float noiseValue = random(-noiseAmount, noiseAmount);
        
        // Add noise to grayscale value
        gray += noiseValue;
      }
      
      // Constrain value to valid range
      gray = constrain(gray, 0, 255);
      
      // Set the result pixel with the grayscale value
      result.pixels[loc] = color(gray);
    }
  }
  
  result.updatePixels();
  return result;
}

// Function to convert an image to binary using random halftone (WITH WHITE AREA PROTECTION)
PImage createBinaryHalftone(PImage sourceImg) {
  PImage result = createImage(sourceImg.width, sourceImg.height, RGB);
  sourceImg.loadPixels();
  result.loadPixels();
  
  float threshold = 127; // Middle gray threshold
  float whiteThreshold = 250; // Pixels above this are kept pure white
  int margin = 3;
  
  for (int y = 0; y < sourceImg.height; y++) {
    for (int x = 0; x < sourceImg.width; x++) {
      if (x < margin || x >= sourceImg.width - margin || y < margin || y >= sourceImg.height - margin) {
        result.pixels[x + y * sourceImg.width] = color(255); // Set border to white
        continue;
      }

      int loc = x + y * sourceImg.width;
      
      // Get the color
      color pixelColor = sourceImg.pixels[loc];
      
      // Convert to grayscale
      float brightness = brightness(pixelColor);
      
      // If the pixel is already very bright (near white), keep it white
      if (brightness > whiteThreshold) {
        result.pixels[loc] = color(255); // Pure white
      } else {
        // Apply random halftone only to non-white areas
        float randomOffset = random(-70, 70); // Random variation for the halftone effect
        
        // Set pixel to either black or white based on brightness and random variation
        if (brightness + randomOffset < threshold) {
          result.pixels[loc] = color(0); // Black
        } else {
          result.pixels[loc] = color(255); // White
        }
      }
    }
  }
  
  result.updatePixels();
  return result;
}

// Function to apply Shiffman's dithering to an image
PImage applyDither(PImage img, int steps) {
  // Create a copy of the image to work with
  PImage result = img.copy();
  result.loadPixels();
  
  for (int y = 0; y < result.height; y++) {
    for (int x = 0; x < result.width; x++) {
      // Get current pixel color
      color clr = getColorAtIndex(result, x, y);
      float oldR = red(clr);
      float oldG = green(clr);
      float oldB = blue(clr);
      
      // Find closest step for each color channel
      float newR = closestStep(255, steps, oldR);
      float newG = closestStep(255, steps, oldG);
      float newB = closestStep(255, steps, oldB);
      
      // Set new color
      color newClr = color(newR, newG, newB);
      setColorAtIndex(result, x, y, newClr);
      
      // Calculate error
      float errR = oldR - newR;
      float errG = oldG - newG;
      float errB = oldB - newB;
      
      // Distribute error to neighboring pixels
      distributeError(result, x, y, errR, errG, errB);
    }
  }
  
  result.updatePixels();
  return result;
}

// Helper function to get color at pixel coordinates
color getColorAtIndex(PImage img, int x, int y) {
  int idx = x + y * img.width;
  return img.pixels[idx];
}

// Helper function to set color at pixel coordinates
void setColorAtIndex(PImage img, int x, int y, color clr) {
  int idx = x + y * img.width;
  img.pixels[idx] = clr;
}

// Finds the closest step for a given value
float closestStep(float max, int steps, float value) {
  return round(steps * value / 255) * floor(255 / steps);
}

// Distribute error to neighboring pixels using Floyd-Steinberg dithering
void distributeError(PImage img, int x, int y, float errR, float errG, float errB) {
  addError(img, 7/16.0, x + 1, y, errR, errG, errB);
  addError(img, 3/16.0, x - 1, y + 1, errR, errG, errB);
  addError(img, 5/16.0, x, y + 1, errR, errG, errB);
  addError(img, 1/16.0, x + 1, y + 1, errR, errG, errB);
}

// Add weighted error to a pixel
void addError(PImage img, float factor, int x, int y, float errR, float errG, float errB) {
  // Skip pixels outside the image
  if (x < 0 || x >= img.width || y < 0 || y >= img.height) return;
  
  color clr = getColorAtIndex(img, x, y);
  float r = red(clr);
  float g = green(clr);
  float b = blue(clr);
  
  // Add error with given factor
  r = constrain(r + errR * factor, 0, 255);
  g = constrain(g + errG * factor, 0, 255);
  b = constrain(b + errB * factor, 0, 255);
  
  color newClr = color(r, g, b);
  setColorAtIndex(img, x, y, newClr);
}

// If you want to save with custom width and height
void saveResizedTile(PImage tile, String fileName, int saveWidth, int saveHeight) {
  PImage resized = createImage(saveWidth, saveHeight, RGB);
  resized.copy(tile, 0, 0, tile.width, tile.height, 0, 0, saveWidth, saveHeight);
  resized.save(fileName);
}

// FIXED: Function to apply binary dither WITH WHITE AREA PROTECTION
PImage applyCombinedBinaryDither(PImage img, float randomFactor) {
  // Create a copy of the image to work with
  PImage result = img.copy();
  result.loadPixels();
  
  float whiteThreshold = 240; // Pixels above this value are kept pure white
  
  for (int y = 0; y < result.height; y++) {
    for (int x = 0; x < result.width; x++) {
      // Get current pixel and convert to grayscale
      color clr = getColorAtIndex(result, x, y);
      float oldGray = brightness(clr);
      
      // If pixel is already very bright (near white), keep it white and skip processing
      if (oldGray > whiteThreshold) {
        setColorAtIndex(result, x, y, color(255)); // Pure white
        continue; // Skip dithering for this pixel
      }
      
      // Add random noise BEFORE thresholding (only for non-white areas)
      float randomNoise = random(-randomFactor, randomFactor);
      oldGray = constrain(oldGray + randomNoise, 0, 255);
      
      // Binary thresholding (0 or 255 only)
      float threshold = 127;
      float newGray = (oldGray < threshold) ? 0 : 255;
      
      // Set new color (pure black or white)
      color newClr = color(newGray);
      setColorAtIndex(result, x, y, newClr);
      
      // Calculate error for Floyd-Steinberg distribution
      float err = oldGray - newGray;
      
      // Distribute error to neighboring pixels (this adds the "structure" from Shiffman's method)
      distributeBinaryErrorProtected(result, x, y, err, whiteThreshold);
    }
  }
  
  result.updatePixels();
  return result;
}

// FIXED: Distribute error for binary dithering WITH WHITE AREA PROTECTION
void distributeBinaryErrorProtected(PImage img, int x, int y, float err, float whiteThreshold) {
  addBinaryErrorProtected(img, 7/16.0, x + 1, y, err, whiteThreshold);
  addBinaryErrorProtected(img, 3/16.0, x - 1, y + 1, err, whiteThreshold);
  addBinaryErrorProtected(img, 5/16.0, x, y + 1, err, whiteThreshold);
  addBinaryErrorProtected(img, 1/16.0, x + 1, y + 1, err, whiteThreshold);
}

// FIXED: Add weighted error to a pixel (WITH WHITE AREA PROTECTION)
void addBinaryErrorProtected(PImage img, float factor, int x, int y, float err, float whiteThreshold) {
  // Skip pixels outside the image
  if (x < 0 || x >= img.width || y < 0 || y >= img.height) return;
  
  color clr = getColorAtIndex(img, x, y);
  float gray = brightness(clr);
  
  // Don't add error to pixels that are already very bright (pure white areas)
  if (gray > whiteThreshold) return;
  
  // Add error with given factor
  gray = constrain(gray + err * factor, 0, 255);
  
  color newClr = color(gray);
  setColorAtIndex(img, x, y, newClr);
}

// Alternative approach: Add randomness to the error distribution
PImage applyCombinedDitherV2(PImage img, int steps, float randomFactor) {
  // Create a copy of the image to work with
  PImage result = img.copy();
  result.loadPixels();
  
  for (int y = 0; y < result.height; y++) {
    for (int x = 0; x < result.width; x++) {
      // Get current pixel color
      color clr = getColorAtIndex(result, x, y);
      float oldR = red(clr);
      float oldG = green(clr);
      float oldB = blue(clr);
      
      // Find closest step for each color channel (Shiffman's method)
      float newR = closestStep(255, steps, oldR);
      float newG = closestStep(255, steps, oldG);
      float newB = closestStep(255, steps, oldB);
      
      // Set new color
      color newClr = color(newR, newG, newB);
      setColorAtIndex(result, x, y, newClr);
      
      // Calculate error
      float errR = oldR - newR;
      float errG = oldG - newG;
      float errB = oldB - newB;
      
      // Distribute error with random variation
      distributeErrorWithRandom(result, x, y, errR, errG, errB, randomFactor);
    }
  }
  
  result.updatePixels();
  return result;
}

// Modified error distribution with randomness
void distributeErrorWithRandom(PImage img, int x, int y, float errR, float errG, float errB, float randomFactor) {
  // Add random variation to the Floyd-Steinberg coefficients
  float r1 = 7/16.0 + random(-randomFactor, randomFactor) * 0.1;
  float r2 = 3/16.0 + random(-randomFactor, randomFactor) * 0.1;
  float r3 = 5/16.0 + random(-randomFactor, randomFactor) * 0.1;
  float r4 = 1/16.0 + random(-randomFactor, randomFactor) * 0.1;
  
  // Normalize to maintain total of 1.0
  float total = r1 + r2 + r3 + r4;
  r1 /= total; r2 /= total; r3 /= total; r4 /= total;
  
  addError(img, r1, x + 1, y, errR, errG, errB);
  addError(img, r2, x - 1, y + 1, errR, errG, errB);
  addError(img, r3, x, y + 1, errR, errG, errB);
  addError(img, r4, x + 1, y + 1, errR, errG, errB);
}

// You can use this key press to save with a custom size
void keyPressed() {
  if (key == 'r') {
    // Define your desired width and height for saving
    int saveWidth = 200;  // Change to your desired width
    int saveHeight = 200; // Change to your desired height
    
    for (int y = 0; y < rows; y++) {
      for (int x = 0; x < cols; x++) {
        // Extract tile
        PImage tile = createImage(tileWidth, tileHeight, RGB);
        tile.copy(sourceImage,
                  x * tileWidth, y * tileHeight, tileWidth, tileHeight,
                  0, 0, tileWidth, tileHeight);
        
        // Save resized tile
        String fileName = outputFolder + "resized_tile_" + nf(y+1, 2) + "_" + nf(x+1, 2) + ".png";
        saveResizedTile(tile, fileName, saveWidth, saveHeight);
      }
    }
    println("Resized tiles saved with dimensions: " + saveWidth + "x" + saveHeight);
  }
}