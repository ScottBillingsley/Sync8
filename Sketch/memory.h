#pragma once

#include <Arduino.h>

// ========================================================
//              CHIP8 Memory Functions
// ========================================================

/*
       Clear the system memory
*/
void clear_system_memory()
{
  for (uint16_t i = 0; i < MEMORY_SIZE; i ++)
  {
    ram[i] = 0x00;
  }
}

/*
      Store the fonts in memory
*/
void store_fonts()
{
  for (uint8_t i = 0; i < FONT_ARRAY_SIZE; i ++)
  {
    ram[FONT_OFFSET + i] = _font[i];
  }

}
