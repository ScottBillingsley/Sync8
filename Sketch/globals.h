#pragma once

#include <Arduino.h>

/*
      Permission is hereby granted, free of charge, to any person obtaining a copy
     of this software and associated documentation files (the "Software"), to deal
     in the Software without restriction, including without limitation the rights
     to use, copy, modify, merge, publish, distribute, sublicense, and / or sell
     copies of the Software, and to permit persons to whom the Software is
     furnished to do so, subject to the following conditions:

     The above copyright notice and this permission
     notice shall be included in all copies or substantial portions of the Software.

     THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
     IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
     FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
     AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
     LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
     OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
     THE SOFTWARE.
*/

// =======================================================
//                Defines
// =======================================================

/* Tell the compiler we are going to use our own main.. */
#undef main

/* Optimize for speed over size */
#pragma GCC optimize("-Ofast")

#ifndef cbi
#define cbi(sfr, bit) (_SFR_BYTE(sfr) &= ~_BV(bit))
#endif
#ifndef sbi
#define sbi(sfr, bit) (_SFR_BYTE(sfr) |= _BV(bit))
#endif

#ifndef NOP
#define NOP __asm__ __volatile__("nop\n\t")
#endif

/*
      Video memory
*/
#define VIDEO_RAM 256
/*
      Size of the system memory
*/
#define MEMORY_SIZE 4096
/*
      Memory Offset to store the fonts
*/
#define FONT_OFFSET 0x050
/*
      The size of the font array
*/
#define FONT_ARRAY_SIZE 0x50
/*
      Memory Offset for progrm start
*/
#define PROGRAM_OFFSET 0x200

/*
      Define the keyboard LED
*/
#define KB_LED_BEGIN DDRB |= _BV (7)
#define KB_LED_ON  PORTB |= _BV (7)
#define KB_LED_OFF PORTB &= ~_BV (7)

/*
      The debounce time 15 = aprox 250 mS
*/
#define DEBOUNCE_TIME 15

/*
      Video ISR delays
*/
#define DELAY_A \
  "nop \n\t"\
  "nop \n\t"\
  "nop \n\t"\
  "nop \n\t"\
  "nop \n\t"

#define DELAY_B \
  "nop \n\t"\
  "nop \n\t"\
  "nop \n\t"\
  "nop \n\t"


// =========================================================
//                Memory
// =========================================================
/*
      The system video memory
*/
volatile uint8_t video_ram[VIDEO_RAM];

/*
      The main memory for the CHIP8 emulator..
      Fonts are stored from 0x050 to 0x09F
      Program start at 0x200.
*/
volatile uint8_t ram[MEMORY_SIZE] = {0x00};

/*
     The font array, each font is 8 pixels wide
     by 5 pixels tall.
*/
uint8_t _font[FONT_ARRAY_SIZE] = {
  0xF0, 0x90, 0x90, 0x90, 0xF0, // 0
  0x20, 0x60, 0x20, 0x20, 0x70, // 1
  0xF0, 0x10, 0xF0, 0x80, 0xF0, // 2
  0xF0, 0x10, 0xF0, 0x10, 0xF0, // 3
  0x90, 0x90, 0xF0, 0x10, 0x10, // 4
  0xF0, 0x80, 0xF0, 0x10, 0xF0, // 5
  0xF0, 0x80, 0xF0, 0x90, 0xF0, // 6
  0xF0, 0x10, 0x20, 0x40, 0x40, // 7
  0xF0, 0x90, 0xF0, 0x90, 0xF0, // 8
  0xF0, 0x90, 0xF0, 0x10, 0xF0, // 9
  0xF0, 0x90, 0xF0, 0x90, 0x90, // A
  0xE0, 0x90, 0xE0, 0x90, 0xE0, // B
  0xF0, 0x80, 0x80, 0x80, 0xF0, // C
  0xE0, 0x90, 0x90, 0x90, 0xE0, // D
  0xF0, 0x80, 0xF0, 0x80, 0xF0, // E
  0xF0, 0x80, 0xF0, 0x80, 0x80  // F
};

/*
      Font memory offsets
*/
const uint8_t font[16] =
{
  0X50, 0X55, 0X5A, 0X5F, 0X64, 0X69, 0X6E, 0X73, 0X78, 0X7D, 0X82, 0X87, 0X8C, 0X91, 0X96, 0x9B
};

// ==========================================================
//                Control
// ==========================================================
/*
      Indacate the blanking period
*/
volatile bool blanking = false;

/*
      Debounce the reset and step buttons
*/
volatile uint16_t debounce = 0;

// ==========================================================
//                System
// ==========================================================

enum speed {
  FAST = 0x0F,    //  1200 Hz
  NORMAL = 0x1F,  //  660 Hz
  SLOW = 0x3F,    //  360 Hz
};

enum Screen_Mode {
  WRAP,
  CLIP
};

const uint8_t cpu_speed[3] = {
  NORMAL, FAST, SLOW,
};

/*
      Variables for the system timer
      Declared as extern "C" to be accessible
      from assembly.
*/
extern "C" {
  volatile uint8_t sys_clock = 0;
  volatile uint8_t sys_speed = 0x1F ;
  volatile uint8_t sys_cpu_clock = 0; // Use uint8_t for bool to be safe in asm
}

/*
     The system control struct
*/
typedef struct {
  volatile uint8_t sound_count = 0;       /* Used by the sound generator  */
  volatile bool screen_mode = CLIP;       /* Hold the current screen mode */
  volatile bool sound_on = false;         /* Used by the sound timer      */
  volatile bool reset = false;            /* Reset the CHIP8 program      */
  volatile bool program = false;
  volatile uint16_t download_count = 0x00;
  volatile bool show_ready = false;
  volatile bool program_mode_setup = true;
  volatile bool debug = false;            /* Sets the debug mode          */
  volatile uint16_t bp = 0;               /* Holds the program break point */
  volatile bool bp_set = false;

} _system;

_system sys;

// ==============================================================
//                CHIP8 CPU
// ==============================================================

/*
      The CPU struct
*/
typedef struct {
  volatile uint8_t v[0x10];              /*   Registers                */
  volatile uint16_t i = 0x00;            /*   Index register           */
  volatile uint16_t pc = PROGRAM_OFFSET; /*   Program Counter register */
  volatile uint16_t stack[0x10];         /*   16 word stack            */
  volatile uint8_t sp = 0x00;            /*   Stack Pointer register   */
  volatile uint8_t dt = 0x00;            /*   Delay Timer register     */
  volatile uint8_t st = 0x00;            /*   Sound Timer register     */
  volatile uint16_t opcode = 0x00;       /*   The current operand      */
  volatile bool step = false;            /*   Step the cpu in debug    */
} chip8regset;

chip8regset chip8;

/*
      The keyboard struct
*/
typedef struct {
  volatile uint8_t value = 0x00;
  volatile uint8_t pressed[0x10];        /* Key pressed */
  volatile uint8_t released[0x10];       /* Key released */
  volatile bool new_key = false;

} KEYBOARD;

KEYBOARD key;

/*
      Wait for keypress if called
*/
volatile bool waiting_for_key = false;
volatile uint8_t target_v_reg = 0;
