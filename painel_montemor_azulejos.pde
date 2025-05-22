PImage sourceImage;
int cols = 22;
int rows = 14;
int tileWidth;  // Will be calculated based on the image
int tileHeight; // Will be calculated based on the image
String outputFolder = "/export/extracted_tiles/"; // Folder to save the tiles
  PGraphics pg;
PImage outputImg; 
      // Extract tile
      float scale = 3.5;

boolean isExporting = true; // Flag to control extraction

void setup() {
  size(1100, 678); // Display size (can be adjusted)
  
  // Load the source image
  sourceImage = loadImage("painel-montemor-HD-bright.png"); // Replace with your image filename

  outputImg = createImage(sourceImage.width, sourceImage.height, RGB);

  println("Loaded image: " + sourceImage.width + "x" + sourceImage.height);
  
  // Calculate tile dimensions based on the image size
  tileWidth = sourceImage.width / cols;
  tileHeight = tileWidth;

  pg = createGraphics(int(tileWidth * scale), int(tileHeight * scale));
  
  // Extract and save tiles
  extractTiles();
  
  println("Extraction complete! " + (cols * rows) + " tiles saved to " + outputFolder);

  // save output image
  if (isExporting) {
    outputImg.save("output_image.png");
    println("Output image saved to " + outputFolder);
  }
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
  int id = 0;
  for (int y = 0; y < rows; y++) {
    for (int x = 0; x < cols; x++) {
      int w = int(tileWidth * scale);
      int h = int(tileHeight * scale);

      PImage tile = createImage(w, h, RGB);
      
      tile.copy(sourceImage,
                x * tileWidth, y * tileHeight, tileWidth, tileHeight,
                0, 0, w, h);
      
      // Convert to grayscale first
      PImage grayscaleTile = createImage(tile.width, tile.height, RGB);
      grayscaleTile.copy(tile, 0, 0, tile.width, tile.height, 0, 0, tile.width, tile.height);
      grayscaleTile.filter(GRAY);
      
      // Apply combined dithering
      int steps = 1; // For binary output
      float randomFactor = 30; // Adjust for more/less randomness
      
      // Choose one of these approaches:
      PImage binaryTile = createBinaryHalftone(grayscaleTile, randomFactor);

      int outputTileWidth = outputImg.width / cols;
      int outputTileHeight = outputTileWidth;

      // check if image is all white
      boolean isAllWhite = true;
      for (int i = 0; i < binaryTile.pixels.length; i++) {
        if (red(binaryTile.pixels[i]) < 255) {
          isAllWhite = false;
          break;
        }
      }
      if (isAllWhite) {
        println("Tile " + (y * cols + x) + " is all white, skipping.");
        outputImg.copy(binaryTile, 0, 0, w, h,  x * outputTileWidth, y * outputTileHeight, outputTileWidth, outputTileHeight);
        continue; // Skip this tile
      }
      // Draw fiducial marker
      binaryTile = drawFiducialMarker(binaryTile, id);

      outputImg.copy(binaryTile, 0, 0, w, h,  x * outputTileWidth, y * outputTileHeight, outputTileWidth, outputTileHeight);
      
      // Save tile with row-column naming
      String fileName = outputFolder + "tile_" + nf(y+1, 2) + "_" + nf(x+1, 2) + ".png";
      if (isExporting) binaryTile.save(fileName);
      id++;
    }
  }
}

PImage drawFiducialMarker (PImage tile, int id) {
  // load fiducial marker from the folder aruco_markers with filename "aruco_marker_XXX.png"
  PImage marker = loadImage("aruco_markers/aruco_marker_" + nf(id, 3) + ".png");
  // resize the marker to 20% of the tile size
  int markerWidth = int(tile.width * 0.2);
  int markerHeight = int(tile.height * 0.2);
  marker.resize(markerWidth, markerHeight);
  // calculate the position to place the marker in the tile
  int x = int(tile.width * 0.5 - markerWidth * 0.5);
  int y = int(tile.height * 0.5 - markerHeight * 0.5);
  pg.beginDraw();
  pg.background(255);
  //pg.imageMode(CENTER);
  pg.image(tile, 0, 0, tile.width, tile.height);
  // draw white border around the marker
  pg.fill(255);
  pg.noStroke();
  pg.rect(x - 2, y - 2, markerWidth + 4, markerHeight + 4);
  pg.image(marker, x, y, markerWidth, markerHeight);
  pg.endDraw();

  return pg.get();
}

// Function to convert an image to binary using random halftone (WITH WHITE AREA PROTECTION)
PImage createBinaryHalftone(PImage sourceImg, float noiseAmount) {
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

// If you want to save with custom width and height
void saveResizedTile(PImage tile, String fileName, int saveWidth, int saveHeight) {
  PImage resized = createImage(saveWidth, saveHeight, RGB);
  resized.copy(tile, 0, 0, tile.width, tile.height, 0, 0, saveWidth, saveHeight);
  resized.save(fileName);
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