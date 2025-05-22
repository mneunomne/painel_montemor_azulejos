PImage sourceImage;
int cols = 22;
int rows = 14;
int tileWidth;  // Will be calculated based on the image
int tileHeight; // Will be calculated based on the image
String outputFolder = "export/extracted_tiles/"; // Folder to save the tiles
PGraphics pg;
PImage outputImg; 
float scale = 3.5;
boolean isExporting = true; // Flag to control extraction

PImage gradient;

// 2D array to track tile types: 0 = empty/white, 1+ = fiducial marker ID
int[][] tileMap;
// Track which tiles get fiducial markers
ArrayList<TileInfo> fiducialTiles;

// Helper class to store tile information
class TileInfo {
  int x, y;           // Grid position
  int id;             // Fiducial marker ID
  boolean isEmpty;    // Whether tile is empty/white
  
  TileInfo(int x, int y, int id, boolean isEmpty) {
    this.x = x;
    this.y = y;
    this.id = id;
    this.isEmpty = isEmpty;
  }
}

void setup() {
  size(1100, 678); // Display size (can be adjusted)

  gradient = loadImage("gradient.png");
  
  // Load the source image
  sourceImage = loadImage("painel-montemor-HD-bright.png"); // Replace with your image filename
  outputImg = createImage(sourceImage.width, sourceImage.height, RGB);

  println("Loaded image: " + sourceImage.width + "x" + sourceImage.height);
  
  // Calculate tile dimensions based on the image size
  tileWidth = sourceImage.width / cols;
  tileHeight = tileWidth;

  pg = createGraphics(int(tileWidth * scale), int(tileHeight * scale));
  
  // Initialize tracking arrays
  tileMap = new int[rows][cols];
  fiducialTiles = new ArrayList<TileInfo>();
  
  // Phase 1: Analyze all tiles and build the map
  analyzeTiles();
  
  // Phase 2: Generate and save tiles with fiducial markers
  generateTiles();
  
  println("Extraction complete! " + (cols * rows) + " tiles processed.");
  println("Fiducial markers added to " + fiducialTiles.size() + " tiles.");

  // Save output image
  if (isExporting) {
    outputImg.save("output_image.png");
    println("Output image saved.");
  }
}

void draw() {
  // Display the source image
  image(outputImg, 0, 0, width, height);
  /*
  // Draw grid to visualize tiles
  //stroke(255, 0, 0);
  noFill();
  
  float scaleX = (float) width / sourceImage.width;
  float scaleY = (float) height / sourceImage.height;
  
  for (int y = 0; y < rows; y++) {
    for (int x = 0; x < cols; x++) {
      // Color code the grid based on tile type
      if (tileMap[y][x] == 0) {
        stroke(255, 0, 0); // Red for empty tiles
      } else {
        stroke(0, 255, 0); // Green for tiles with fiducial markers
      }
      
      rect(x * tileWidth * scaleX, y * tileHeight * scaleY, 
           tileWidth * scaleX, tileHeight * scaleY);
    }
  }
  */
}

// Phase 1: Analyze all tiles and determine which ones need fiducial markers
void analyzeTiles() {
  int fiducialId = 0;
  
  for (int y = 0; y < rows; y++) {
    for (int x = 0; x < cols; x++) {
      // Extract tile for analysis
      PImage tempTile = extractTileImage(x, y);
      
      // Convert to grayscale for analysis
      tempTile.filter(GRAY);
      
      // Check if tile is empty/border
      boolean isEmpty = isImageBorder(tempTile);
      
      if (isEmpty || random(1) > 0.3 || x < 2 || x > cols - 3 || y < 5 || y > rows - 3) {
        // Mark as empty tile
        tileMap[y][x] = 0;
      } else {
        // Mark as tile that will get fiducial marker
        fiducialId++;
        tileMap[y][x] = fiducialId;
        fiducialTiles.add(new TileInfo(x, y, fiducialId, false));
      }
    }
  }
  
  // Print the tile map for debugging
  printTileMap();
}

// Phase 2: Generate and save tiles with fiducial markers
void generateTiles() {
  int outputTileWidth = outputImg.width / cols;
  int outputTileHeight = outputTileWidth;
  
  for (int y = 0; y < rows; y++) {
    for (int x = 0; x < cols; x++) {
      // Extract and scale tile
      PImage tile = extractTileImage(x, y);
      int w = int(tileWidth * scale);
      int h = int(tileHeight * scale);
      tile.resize(w, h);
      
      // Convert to grayscale
      tile.filter(GRAY);
      
      if (tileMap[y][x] == 0) {
        // Empty tile - check if it should have diagonal lines passing through
        tile = addDiagonalLinesToEmptyTile(tile, x, y);
        
        // Copy to output image
        outputImg.copy(tile, 0, 0, w, h, 
                      x * outputTileWidth, y * outputTileHeight, 
                      outputTileWidth, outputTileHeight);
      } else {
        // Tile with fiducial marker
        int markerId = tileMap[y][x] - 1; // Convert to 0-based index
        
        // Draw fiducial marker with knowledge of surrounding tiles
        tile = drawFiducialMarkerWithContext(tile, markerId, x, y);
        
        // Copy to output image
        outputImg.copy(tile, 0, 0, w, h, 
                      x * outputTileWidth, y * outputTileHeight, 
                      outputTileWidth, outputTileHeight);
        
        // Save individual tile
        String fileName = outputFolder + "tile_" + nf(y+1, 2) + "_" + nf(x+1, 2) + ".png";
        if (isExporting) tile.save(fileName);
      }
    }
  }
}

// Helper function to extract a tile image
PImage extractTileImage(int gridX, int gridY) {
  PImage tile = createImage(tileWidth, tileHeight, RGB);
  tile.copy(sourceImage,
            gridX * tileWidth, gridY * tileHeight, tileWidth, tileHeight,
            0, 0, tileWidth, tileHeight);
  return tile;
}

// Add diagonal lines to empty tiles that have markers on their diagonals
PImage addDiagonalLinesToEmptyTile(PImage tile, int gridX, int gridY) {
  pg.beginDraw();
  pg.background(255);
  pg.imageMode(CENTER);
  pg.translate(tile.width / 2, tile.height / 2);
  pg.image(tile, 0, 0, tile.width, tile.height);
  
  // Draw diagonal lines if there are markers on the diagonals
  //drawDiagonalLinesToNeighbors(gridX, gridY, tile.width, tile.height);
  
  pg.translate(-tile.width / 2, -tile.height / 2);
  pg.endDraw();

  return pg.get();
}

// Enhanced fiducial marker drawing with context awareness
PImage drawFiducialMarkerWithContext(PImage tile, int id, int gridX, int gridY) {
  // Load fiducial marker
  PImage marker = loadImage("aruco_markers/aruco_marker_" + nf(id, 3) + ".png");

  int strokeWeight = int(tile.width * 0.25);
  
  // Resize the marker
  int markerWidth = strokeWeight;
  int markerHeight = strokeWeight;
  marker.resize(markerWidth, markerHeight);
  
  pg.beginDraw();
  pg.background(255);
  pg.imageMode(CENTER);
  pg.translate(tile.width / 2, tile.height / 2);
  pg.image(tile, 0, 0, tile.width, tile.height);
  
  // Draw white border around the marker
  pg.fill(255);
  pg.noStroke();
  pg.rect(-markerWidth/2 - 2, -markerHeight/2 - 2, markerWidth + 4, markerHeight + 4);
  
  // Draw diagonal lines to neighboring fiducial markers
  //drawDiagonalLinesToNeighbors(gridX, gridY, tile.width, tile.height);
    
  int[][] neighbors = {
    {-1, -1},  {1, -1},  // Top row
    {-1,  1},  {1,  1}   // Bottom row
  };
  pg.stroke(255);
  pg.strokeWeight(markerWidth + 2);
  for (int[] neighbor : neighbors) {
    int nx = gridX + neighbor[0];
    int ny = gridY + neighbor[1];
    
    // Check if neighbor is within bounds and has a fiducial marker
    // Calculate line direction
    float startX = 0;
    float startY = 0;
    float endX = neighbor[0] * tile.height * 0.5;
    float endY = neighbor[1] * tile.width * 0.5;

    // 45 degres if diagonal goes from topright to bottomleft
    float angle;
    if (neighbor[0] == -1 && neighbor[1] == -1) {
      angle = 135;
    } else if (neighbor[0] == 1 && neighbor[1] == -1) {
      angle = 225;
    } else if (neighbor[0] == -1 && neighbor[1] == 1) {
      angle = 45;
    } else {
      angle = 315;
    }
    // Draw the line
    pg.pushMatrix();
    pg.translate(startX, startY);
    pg.rotate(radians(angle));
    pg.popMatrix();

    pg.line(startX, startY, endX, endY);

      // draw squares in N intervals at this line segment
      int n = 5;
      float stepX = (endX - startX) / n;
      float stepY = (endY - startY) / n;
      for (int i = 0; i < n; i++) {
        float x = startX + stepX * (i+1);
        float y = startY + stepY * (i+1);
        pg.pushStyle();
        pg.pushMatrix();
        pg.rectMode(CENTER);
        pg.noStroke();
        pg.fill((255 / (5-i)) + 50);
        pg.translate(x, y);
        pg.rotate(radians(angle));
        pg.rect(0, 0, strokeWeight/2, strokeWeight);
        pg.translate(-x, -y);
        pg.popMatrix();
        pg.popStyle();
      }
    
   
  }
  
  // Draw the fiducial marker
  pg.rotate(radians(45));
  pg.image(marker, 0, 0, markerWidth, markerHeight);
  pg.rotate(-radians(45));
  
  pg.translate(-tile.width / 2, -tile.height / 2);
  pg.endDraw();

  return pg.get();
}

// Draw diagonal lines to neighboring tiles that have fiducial markers
void drawDiagonalLinesToNeighbors(int gridX, int gridY, int tileW, int tileH) {
  pg.stroke(255);
  pg.strokeWeight(tileW * 0.1);
  
  // Check all 8 neighboring positions
  int[][] neighbors = {
    {-1, -1},  {1, -1},  // Top row
    //{-1,  0},          {1,  0},  // Middle row (excluding self)
    {-1,  1},  {1,  1}   // Bottom row
  };
  
  for (int[] neighbor : neighbors) {
    int nx = gridX + neighbor[0];
    int ny = gridY + neighbor[1];
    
    // Check if neighbor is within bounds and has a fiducial marker
    if (nx >= 0 && nx < cols && ny >= 0 && ny < rows && tileMap[ny][nx] > 0) {
      // Calculate line direction
      float startX = 0;
      float startY = 0;
      float endX = neighbor[0] * tileW * 0.4;
      float endY = neighbor[1] * tileH * 0.4;

      
      // pg.line(startX, startY, endX, endY);
    }
  }
}

// Print the tile map for debugging
void printTileMap() {
  println("\nTile Map (0 = empty, 1+ = fiducial marker ID):");
  for (int y = 0; y < rows; y++) {
    String row = "";
    for (int x = 0; x < cols; x++) {
      row += String.format("%3d", tileMap[y][x]) + " ";
    }
    println("Row " + nf(y+1, 2) + ": " + row);
  }
  println();
}

// Get information about a specific tile
TileInfo getTileInfo(int gridX, int gridY) {
  for (TileInfo tile : fiducialTiles) {
    if (tile.x == gridX && tile.y == gridY) {
      return tile;
    }
  }
  return null;
}

// Check if a tile has a fiducial marker
boolean hasFiducialMarker(int gridX, int gridY) {
  if (gridX < 0 || gridX >= cols || gridY < 0 || gridY >= rows) {
    return false;
  }
  return tileMap[gridY][gridX] > 0;
}

// Get fiducial marker ID for a tile
int getFiducialId(int gridX, int gridY) {
  if (hasFiducialMarker(gridX, gridY)) {
    return tileMap[gridY][gridX];
  }
  return -1;
}

// Original helper functions (unchanged)
boolean isImageBorder(PImage img) {
  img.loadPixels();
  int w = img.width;
  int h = img.height;
  for (int y = 0; y < 10; y++) {
    for (int x = 0; x < 10; x++) {
      int loc = (w / 2 - 5 + x) + (h / 2 - 5 + y) * w;
      color pixelColor = img.pixels[loc];
      float brightness = brightness(pixelColor);
      if (brightness < 255) {
        return false;
      }
    }
  }
  return true;
}

// Key press handler for additional functionality
void keyPressed() {
  if (key == 'p') {
    printTileMap();
  } else if (key == 'i') {
    // Print fiducial tile information
    println("\nFiducial Tiles:");
    for (TileInfo tile : fiducialTiles) {
      println("Grid(" + tile.x + "," + tile.y + ") -> ID: " + tile.id);
    }
  }
}