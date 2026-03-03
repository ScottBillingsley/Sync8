#pragma once

#include <Arduino.h>

// ============================================================
//        The display routines
// ============================================================
/*
    Clear the video ram
*/
void clear_screen()
{
  while (blanking == false) {}

  for (uint16_t i = 0; i < sizeof(video_ram); i ++)
  {
    video_ram[i] = 0x00;
  }
}

/*
      Draw a sprite pointed to by start address to
      location x, y
*/
uint8_t draw_sprite(uint8_t x, uint8_t y, uint16_t start_addr, uint8_t n) {
  uint8_t collision = 0;

  // ALWAYS wrap the starting coordinates (CHIP-8 Standard)
  // This ensures x=64 starts at 0, and y=32 starts at 0
  uint8_t startX = x % 64;
  uint8_t startY = y % 32;

  for (uint8_t row = 0; row < n; row++) {
    uint8_t currentY = startY + row;

    // Vertical Logic for the "tail" of the sprite
    if (currentY >= 32) {
      if (sys.screen_mode == WRAP) currentY %= 32;
      else break; // Original VIP behavior: Clip/Stop drawing the rest of the rows
    }

    uint8_t spriteByte = ram[start_addr + row];
    uint8_t shift = startX & 7;
    uint8_t byteX = startX >> 3; // Horizontal byte position (0-7)
    uint16_t index = ((uint16_t)currentY << 3) + byteX;

    // --- Part 1: Primary Byte ---
    if ((video_ram[index] & (spriteByte >> shift)) != 0) collision = 1;
    video_ram[index] ^= (spriteByte >> shift);

    // --- Part 2: Overflow Byte ---
    if (shift > 0) {
      uint16_t index2;
      bool drawPart2 = true;

      if (byteX < 7) {
        index2 = index + 1;
      } else {
        // We are at the last byte of the line
        if (sys.screen_mode == WRAP) index2 = (uint16_t)currentY << 3; // Wrap tail to start of line
        else drawPart2 = false; // Clip tail
      }

      if (drawPart2) {
        uint8_t part2 = spriteByte << (8 - shift);
        if ((video_ram[index2] & part2) != 0) collision = 1;
        video_ram[index2] ^= part2;
      }
    }
  }
  return collision;
}
