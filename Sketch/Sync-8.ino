/*
                    Sync-8
            Vernon Billingsley c2026

            Arduino IDE 1.8.19

            A CHIP8 interrupter running on an arduino Mega 2560
            with composite video out.


    Pin   Mega Function           Sketch Function
    0     PE0   RXO
    1     PE1   TX0
    2     PE4   OC3B  INT4        CPU Reset, FALLING  10k to Vcc
    3     PE5   OC3C  INT6        Debug Step, FALLING 10k to Vcc
    4     PG5   OC0B
    5     PE3   OC3A  AIN(1)
    6     PH3   OC4A
    7     PH4   OC4B              Sound Out
    8     PH5   OC4C              Low Speed Clock   |
    9     PH6   OC2B              High Speed Clock  | Both off Normal Speed
    10    PB4   OC2A
    11    PB5   OC1A              H_Sync
    12    PB6   OC1B
    13    PB7   OC0A  OC1A        Keyboard LED
    14    PJ1   TX3
    15    PJ0   RX3
    16    PH1   TX1
    17    PH0   RX2
    18    PD3   TX1
    19    PD3   RX1
    20    PD1   SDA
    21    PD0   SCL
    22    PA0
    23    PA1
    24    PA2
    25    PA3
    26    PA4
    27    PA5
    28    PA6
    29    PA7                     Pixel Data Out
    30    PC7                     R4
    31    PC6                     R3
    32    PC5                     R2
    33    PC4                     R1    4x4 Matrix Keypad
    34    PC3                     C1
    35    PC2                     C2
    36    PC1                     C3
    37    PC0                     C4
    38    PD7                     Run/Program Switch
    39    PG2   BLE
    40    PG1   RD
    41    PG0   WR
    42    PL7
    43    PL6
    44    PL5
    45    PL4
    46    PL3                     Run LED
    47    PL2                     Program LED
    48    PL1                     Speed LED
    49    PL0                     Speed LED
    50    PB3   MISO              Debug LED
    51    PB2   MOSI              Run/Debug Switch
    52    PB1   SCK               Wrap/Clip Switch
    53    PB0   SS
    A0    PF0
    A1    PF1
    A2    PF2
    A3    PF3
    A4    PF4
    A5    PF5
    A6    PF6
    A7    PF7
    A8    PK0
    A9    PK1
    A10   PK2
    A11   PK3
    A12   PK4
    A13   PK5
    A14   PK6
    A14   PK7

    Sources :
    https://craigthomas.ca/blog/2014/06/21/writing-a-chip-8-emulator-part-1/

    https://austinmorlan.com/posts/chip8_emulator/

    http://devernay.free.fr/hacks/chip8/C8TECH10.HTM

    https://tobiasvl.github.io/blog/write-a-chip-8-emulator/

    https://johnearnest.github.io/Octo/

    https://jborza.com/post/2020-12-07-chip-8/

    https://github.com/mattmikolay/chip-8/wiki/Mastering-CHIP%E2%80%908

    https://github.com/kripod/chip8-roms

    https://github.com/Timendus/chip8-test-suite?tab=readme-ov-file

    https://chip-8.github.io/extensions/


    VIPER newsletters:
    https://github.com/mattmikolay/viper?tab=readme-ov-file

    RCA VIP VP580 Instruction Manual:
    https://www.manualslib.com/manual/3616940/Rca-Vip-Vp580.html?page=3#manual


    Convert hex dump text file to CSV file Linux:
    sed 's/ \+/,/g' filename.txt > file_name.csv


*/
// =================================================================
//                          Includes
// =================================================================
#include "globals.h"
#include "Timer1.h"
#include "Timer4.h"
#include "isr.h"
#include <avr/sleep.h>
#include "display.h"
#include "memory.h"
#include "tables.h"
#include "cpu.h"


// =================================================================
//                           Variables
// =================================================================



// =================================================================
//                           Functions
// =================================================================
/*
      The main system timer
      I use a naked isr and assembly to incremnt the
      system timer and the cpu clock to fit it all in
      the 4.5 uS sync pulse.
*/
ISR(PCINT0_vect, ISR_NAKED)
{
  asm volatile(
    "push r16               \n\t"
    "in   r16, %[sreg_reg]  \n\t"
    "push r16               \n\t"
    "push r17               \n\t"

    "sbic %[pin_reg], 5     \n\t"   // Skip if Pin 11 (PB5) is High (we want falling)
    "rjmp  exit_%=          \n\t"

    "lds  r16, (sys_clock)  \n\t"
    "inc  r16               \n\t"
    "sts  (sys_clock), r16  \n\t"

    "lds  r17, (sys_speed)  \n\t"
    "and  r16, r17          \n\t"
    "brne exit_%=           \n\t"

    "ldi  r16, 1            \n\t"
    "sts  (sys_cpu_clock), r16 \n\t"

    "exit_%=:               \n\t"
    "pop  r17               \n\t"
    "pop  r16               \n\t"
    "out  %[sreg_reg], r16  \n\t"
    "pop  r16               \n\t"
    "reti                   \n\t"   // REQUIRED: NAKED ISRs must end with reti
    :
    : [pin_reg]  "i" (_SFR_IO_ADDR(PINB)),
    [port_reg] "i" (_SFR_IO_ADDR(PORTE)),
    [sreg_reg] "i" (_SFR_IO_ADDR(SREG))
    : "r16" , "r17", "memory"
  );

}


// =========================================================
//                Display
// =========================================================
/*
    Clear the video ram
*/
void clear_screen();

/*
    Draw a sprite to the screen
*/
uint8_t draw_sprite(uint8_t x, uint8_t y, uint16_t start_addr, uint8_t n);

// =========================================================
//                Memory
// =========================================================
/*
       Clear the system memory
*/
void clear_system_memory();

/*
      Store the fonts in memory
*/
void store_fonts();

// =================================================
//          The CPU Core
// =================================================

/*
      The main cpu core where the
      opcodes are decoded
*/
uint8_t execute_opcode();

/*
      Reset the cpu
*/
void cpu_reset()
{
  if (debounce > DEBOUNCE_TIME)
  {
    sys.reset = true;
    debounce = 0;
  }
}

/*
      Trigger the next debug step
*/
void debug_step()
{
  if (debounce > DEBOUNCE_TIME)
  {
    chip8.step = true;
    debounce = 0;
  }
}


// =================================================
//          Stabilize the video
// =================================================

/*
      Put the cpu to sleep to stabilize the
      video output
*/
void sleep()
{
  // --- STABILIZE VIDEO ---
  // We want the CPU to be ASLEEP when the next Timer1 interrupt hits.
  set_sleep_mode(SLEEP_MODE_IDLE);
  sleep_enable();
  sleep_cpu();
  // The CPU stops here and wakes up perfectly synced when Timer1 fires.
  sleep_disable();
}

/*
      A 250 mS delay to allow the monitor to sync
*/
void sync_delay()
{
  asm volatile (
    "    ldi  r18, 41   \n\t" // Outer loop
    "3:  ldi  r19, 255  \n\t" // Middle loop
    "2:  ldi  r20, 255  \n\t" // Inner loop
    "1:  dec  r20       \n\t" // 1 cycle
    "    brne 1b        \n\t" // 2 cycles (until zero)
    "    dec  r19       \n\t" // 1 cycle
    "    brne 2b        \n\t" // 2 cycles
    "    dec  r18       \n\t" // 1 cycle
    "    brne 3b        \n\t" // 2 cycles
    :
    :
    : "r18", "r19", "r20"
  );
}


// =================================================================
//                            Main
// =================================================================
int main() {

  //init();
  Serial.begin(115200);

  /*
        Get a random seed
  */
  randomSeed(analogRead(0));

  /*
      Setup the timer for H_Sync
  */
  Timer1::begin();

  /*
      Setup the sound timer
  */
  Timer4::begin();

  /*
      Set pin D29 as OUTPUT for pixle clock..
  */
  DDRA |= _BV (7);

  /*
      Set pin D7 as OUTPUT for sound generation
  */
  DDRE |= _BV (4);

  /*
      Setup PORTC for the matrix keyboard
      PC0 to PC3 as OUTPUT for columns
      PC4 to PC7 as INPUT for rows
  */
  DDRC = 0x0F;

  /*
      Add pullups for the rows and
      set the columns HIGH
  */
  PORTC = 0xFF;

  /*
      Set PD2 as INPUT for reset interrupt pin
  */
  DDRE &= ~_BV (4);

  /*
      Attach an interrupt function
  */
  attachInterrupt(digitalPinToInterrupt(2), cpu_reset, FALLING);

  /*
      Set PD3 as INPUT for debug step interrupt pin
  */
  DDRE &= ~_BV (5);

  /*
      Attach an interrupt function
  */
  attachInterrupt(digitalPinToInterrupt(3), debug_step, FALLING);

  /*
      Set PD51 as INPUT for Debug Switch
  */
  DDRB &= ~_BV (2);

  /*
      Set PD50 as OUTPUT for Degug LED
  */
  DDRB |= _BV (3);
  PORTB &= ~_BV (3);

  /*
      Set PD8 and PD9 as INPUT for CPU Speed
  */
  DDRH &= ~_BV (5);
  DDRH &= ~_BV (6);

  /*
      Set PD38 as INPUT for Run/Program Switch
  */
  DDRD &= ~_BV (7);

  /*
    Set pin D46 and D47 as OUTPUT for Speed LED
  */
  DDRL |= _BV (2);
  DDRL |= _BV (3);

  /*
      Set pin D48 and D49 as OUTPUT for Speed LED
  */
  DDRL |= _BV (0);
  DDRL |= _BV (1);

  /*
      Set pin D13 as OUTPUT for keyboard LED
  */
  KB_LED_BEGIN;

  /*
      Enable global interrupts
  */
  sei();

  /*
        Setup the emulator
  */
  clear_screen();

  clear_system_memory();

  store_fonts();

  /*
        Delay a little to allow the monitor
        to sync
  */
  sync_delay();

  /*
        Give a starting beep
  */
  chip8.st = 8;

  /*
    Load the splash screen into memory
  */
  for (uint16_t i = 0x00; i < sizeof(test); i ++)
  {
    ram[PROGRAM_OFFSET + i] = test[i];
  }

  Serial.println("CHIP8 on a Mega!");


  // ================================================================
  //                          WHILE
  // ================================================================
  while (1) {

    if (sys.reset == true)
    {
      /*
        Clear the screen
      */
      clear_screen();
      /*
          Reset the program counter
          and clear the registers
      */
      chip8.pc = PROGRAM_OFFSET;
      chip8.i = 0x00;
      for (uint8_t i = 0; i < sizeof(chip8.v); i ++)
      {
        chip8.v[i] = 0x00;
      }
      /*
        Clear the waiting for key
      */
      waiting_for_key = false;

      /*
          Clear the break point
      */
      sys.bp_set = false;

      /*
          Clear the bool
      */
      sys.reset = false;
    }

    // ========================================
    //      Run/Program
    // ========================================
    if (sys.program == false)
    {
      /*
             The CPU Section
      */
      if (sys_cpu_clock == true && blanking == true)
      {

        /*
              If not waiting for a key, run the next opcode
              otherwise, skip
        */
        if (!waiting_for_key && !sys.debug)
        {
          /*
              Run the next opcode
          */
          execute_opcode();
        }

        /********************** Debug *****************************/

        /*
              Run the cpu until the break point is reached
        */
        if (sys.debug == true && sys.bp > 0 && sys.bp_set == false)
        {
          if (chip8.pc == sys.bp)
          {
            sys.bp_set = true;
            Serial.print("Break point :");
            Serial.println(chip8.pc, HEX);
            chip8.step = false;
          } else {
            chip8.step = true;
          }
        }

        /*
              Step the cpu one step
        */
        if (sys.debug == true && chip8.step == true && sys.bp > 0)
        {

          /*
              Run the next opcode
          */
          execute_opcode();

          /*
               Clear the bool
          */
          chip8.step = false;
        }

        /*************************************************************/

        /*
          Set the bool for programming mode
        */
        sys.program_mode_setup = true;

        /*
              Clear the bool
        */
        sys_cpu_clock = false;
      }
    } else {                      /* Program Mode */
      if (sys.program_mode_setup == true)
      {

        /*
          Clear the screen
        */
        clear_screen();
        /*
            Reset the program counter
        */
        chip8.pc = PROGRAM_OFFSET;

        /*
            Reset the download counter
        */
        sys.download_count = PROGRAM_OFFSET;

        /*
            Send a ready to the serial port
        */
        Serial.println("Ready for download....");

        /*
              Clear the bool
        */
        sys.program_mode_setup = false;
      }

      /*
            Check the serial
      */
      if (Serial.available() >= 2)
      {
        ram[sys.download_count] = Serial.read();

        ram[sys.download_count + 1] = Serial.read();

        sys.download_count += 2;

      }

    }/*********************** End Run/Proram ********************************/

    /************************ Debug ****************************************/

    /*
        If the debug mode is set, listen for the break point
    */
    uint16_t s = 0;
    uint8_t h = 0;
    uint8_t l = 0;

    if (Serial.available() >= 2 && sys.debug == true)
    {

      h = Serial.read();
      l = Serial.read();
      s = (h << 8) | l;

      sys.bp = s;

      Serial.print("Break point set :");
      Serial.println(sys.bp, HEX);

      /*
            Flush the serial
      */
      while (Serial.available() > 0)
      {
        h = Serial.read();
      }

    }

    /***********************************************************************/

    /*
          Put the mega to sleep untill the
          next interrupt to keep the screen stable
    */
    sleep();


  } /*************************** End While Loop *****************************/
} /****************************End Main Loop ******************************/
