#pragma once

#include <Arduino.h>

// ===============================================
// This is the interrupt routine for Timer1 and
// is the pixel clock for the display
// ================================================

typedef struct {
  volatile uint16_t line_count = 0;
  volatile uint16_t ram_line = 0;
  volatile bool output_pixel = false;
  volatile uint8_t line_repeat = 0;

} PIXEL_CLOCK;

PIXEL_CLOCK pixel_clock;


volatile static uint8_t* ptr;

volatile static bool new_key = false;
volatile uint8_t rp = 0;


ISR(TIMER1_COMPA_vect) {

  if (pixel_clock.output_pixel == true)
  {

    /*
      Point the pointer to the ram
    */
    ptr = &(video_ram[pixel_clock.ram_line]);

    /* Pixel Clock */
    asm volatile(
      // =============================================
      //      Back Porch
      // =============================================
      "ldi  r16, 71   \n\t"
      "dly_%=:        \n\t"
      "dec  r16       \n\t"
      "brne dly_%=    \n\t"
      "nop            \n\t"
      "nop            \n\t"
      // ==============================================
      //      Pixel Clock
      // ==============================================

      "ld  r16, z+     \n\t"
      "out %0, r16     \n\t"
      DELAY_A
      "lsl r16         \n\t"
      "out %0, r16     \n\t"
      DELAY_A
      "lsl r16         \n\t"
      "out %0, r16     \n\t"
      DELAY_A
      "lsl r16         \n\t"
      "out %0, r16     \n\t"
      DELAY_A
      "lsl r16         \n\t"
      "out %0, r16     \n\t"
      DELAY_A
      "lsl r16         \n\t"
      "out %0, r16     \n\t"
      DELAY_A
      "lsl r16         \n\t"
      "out %0, r16     \n\t"
      DELAY_A
      "lsl r16         \n\t"
      "out %0, r16     \n\t"
      DELAY_B
      //8
      "ld  r16, z+     \n\t"
      "out %0, r16     \n\t"
      DELAY_A
      "lsl r16         \n\t"
      "out %0, r16     \n\t"
      DELAY_A
      "lsl r16         \n\t"
      "out %0, r16     \n\t"
      DELAY_A
      "lsl r16         \n\t"
      "out %0, r16     \n\t"
      DELAY_A
      "lsl r16         \n\t"
      "out %0, r16     \n\t"
      DELAY_A
      "lsl r16         \n\t"
      "out %0, r16     \n\t"
      DELAY_A
      "lsl r16         \n\t"
      "out %0, r16     \n\t"
      DELAY_A
      "lsl r16         \n\t"
      "out %0, r16     \n\t"
      DELAY_B
      //16
      "ld  r16, z+     \n\t"
      "out %0, r16     \n\t"
      DELAY_A
      "lsl r16         \n\t"
      "out %0, r16     \n\t"
      DELAY_A
      "lsl r16         \n\t"
      "out %0, r16     \n\t"
      DELAY_A
      "lsl r16         \n\t"
      "out %0, r16     \n\t"
      DELAY_A
      "lsl r16         \n\t"
      "out %0, r16     \n\t"
      DELAY_A
      "lsl r16         \n\t"
      "out %0, r16     \n\t"
      DELAY_A
      "lsl r16         \n\t"
      "out %0, r16     \n\t"
      DELAY_A
      "lsl r16         \n\t"
      "out %0, r16     \n\t"
      DELAY_B
      //24
      "ld  r16, z+     \n\t"
      "out %0, r16     \n\t"
      DELAY_A
      "lsl r16         \n\t"
      "out %0, r16     \n\t"
      DELAY_A
      "lsl r16         \n\t"
      "out %0, r16     \n\t"
      DELAY_A
      "lsl r16         \n\t"
      "out %0, r16     \n\t"
      DELAY_A
      "lsl r16         \n\t"
      "out %0, r16     \n\t"
      DELAY_A
      "lsl r16         \n\t"
      "out %0, r16     \n\t"
      DELAY_A
      "lsl r16         \n\t"
      "out %0, r16     \n\t"
      DELAY_A
      "lsl r16         \n\t"
      "out %0, r16     \n\t"
      DELAY_B
      //32
      "ld  r16, z+     \n\t"
      "out %0, r16     \n\t"
      DELAY_A
      "lsl r16         \n\t"
      "out %0, r16     \n\t"
      DELAY_A
      "lsl r16         \n\t"
      "out %0, r16     \n\t"
      DELAY_A
      "lsl r16         \n\t"
      "out %0, r16     \n\t"
      DELAY_A
      "lsl r16         \n\t"
      "out %0, r16     \n\t"
      DELAY_A
      "lsl r16         \n\t"
      "out %0, r16     \n\t"
      DELAY_A
      "lsl r16         \n\t"
      "out %0, r16     \n\t"
      DELAY_A
      "lsl r16         \n\t"
      "out %0, r16     \n\t"
      DELAY_B
      //40
      "ld  r16, z+     \n\t"
      "out %0, r16     \n\t"
      DELAY_A
      "lsl r16         \n\t"
      "out %0, r16     \n\t"
      DELAY_A
      "lsl r16         \n\t"
      "out %0, r16     \n\t"
      DELAY_A
      "lsl r16         \n\t"
      "out %0, r16     \n\t"
      DELAY_A
      "lsl r16         \n\t"
      "out %0, r16     \n\t"
      DELAY_A
      "lsl r16         \n\t"
      "out %0, r16     \n\t"
      DELAY_A
      "lsl r16         \n\t"
      "out %0, r16     \n\t"
      DELAY_A
      "lsl r16         \n\t"
      "out %0, r16     \n\t"
      DELAY_B
      //48
      "ld  r16, z+     \n\t"
      "out %0, r16     \n\t"
      DELAY_A
      "lsl r16         \n\t"
      "out %0, r16     \n\t"
      DELAY_A
      "lsl r16         \n\t"
      "out %0, r16     \n\t"
      DELAY_A
      "lsl r16         \n\t"
      "out %0, r16     \n\t"
      DELAY_A
      "lsl r16         \n\t"
      "out %0, r16     \n\t"
      DELAY_A
      "lsl r16         \n\t"
      "out %0, r16     \n\t"
      DELAY_A
      "lsl r16         \n\t"
      "out %0, r16     \n\t"
      DELAY_A
      "lsl r16         \n\t"
      "out %0, r16     \n\t"
      DELAY_B
      //56
      "ld  r16, z+     \n\t"
      "out %0, r16     \n\t"
      DELAY_A
      "lsl r16         \n\t"
      "out %0, r16     \n\t"
      DELAY_A
      "lsl r16         \n\t"
      "out %0, r16     \n\t"
      DELAY_A
      "lsl r16         \n\t"
      "out %0, r16     \n\t"
      DELAY_A
      "lsl r16         \n\t"
      "out %0, r16     \n\t"
      DELAY_A
      "lsl r16         \n\t"
      "out %0, r16     \n\t"
      DELAY_A
      "lsl r16         \n\t"
      "out %0, r16     \n\t"
      DELAY_A
      "lsl r16         \n\t"
      "out %0, r16     \n\t"
      DELAY_A
      //64

      // ===============================================
      //        Front Porch
      // ===============================================
      "cbr r16, 0xFF  \n\t"
      "out  %0, r16   \n\t"

      ::"i"(_SFR_IO_ADDR(PORTA)), "z"(ptr)
      : "r16"); /* End pixel clock */

    pixel_clock.line_repeat ++;
    if (pixel_clock.line_repeat == 0x03)
    {
      pixel_clock.line_repeat = 0;

      pixel_clock.ram_line += 8;

    }

  }/* End pixel clock */

  //  ===========================================================
  //          Sync
  //  ===========================================================



  switch (pixel_clock.line_count)
  {

    case 76:      //Blanking End
      /*
          End the blnking period
      */
      blanking = false;
      break;
    case 78: case 79: case 80: case 81:

      {
        /*
           Get the current column
        */
        uint8_t col = pixel_clock.line_count - 78;
        /*
            Pull current column LOW
        */
        PORTC &= ~(1 << col);
        /*
            Short delay
        */
        NOP;
        NOP;
        /*
             Read the rows
        */
        uint8_t row_data = (~(PINC >> 4)) & 0x0F;
        /*
             Store the key data
        */
        if (row_data > 0x00)
        {
          switch (col)
          {
            case 0:
              switch (row_data)
              {
                case 1:
                  key.value = 0x0F;
                  break;
                case 2:
                  key.value = 0x0B;
                  break;
                case 4:
                  key.value = 0x00;
                  break;
                case 8:
                  key.value = 0x0A;
                  break;
              }
              new_key = true;
              break;
            case 1:
              switch (row_data)
              {
                case 1:
                  key.value = 0x0E;
                  break;
                case 2:
                  key.value = 0x09;
                  break;
                case 4:
                  key.value = 0x08;
                  break;
                case 8:
                  key.value = 0x07;
                  break;
              }
              new_key = true;
              break;
            case 2:
              switch (row_data)
              {
                case 1:
                  key.value = 0x0D;
                  break;
                case 2:
                  key.value = 0x06;
                  break;
                case 4:
                  key.value = 0x05;
                  break;
                case 8:
                  key.value = 0x04;
                  break;
              }
              new_key = true;
              break;
            case 3:
              switch (row_data)
              {
                case 1:
                  key.value = 0x0C;
                  break;
                case 2:
                  key.value = 0x03;
                  break;
                case 4:
                  key.value = 0x02;
                  break;
                case 8:
                  key.value = 0x01;
                  break;
              }
              new_key = true;
              break;
          }

        }

        /*
            Rest the column
        */
        PORTC |= (1 << col);

      }

      break;
    case 82:
      if (new_key == true)
      {

        KB_LED_ON;

        for (uint8_t i = 0; i < 0x10; i ++)
        {
          key.released[i] = 0x00;
          key.pressed[i] = 0x00;
        }
        key.pressed[key.value] = 0x01;

        new_key = false;

        key.new_key = true;

      } else {

        KB_LED_OFF;

        for (uint8_t i = 0; i < 0x10; i ++)
        {
          if (key.pressed[i] == 0x01)
          {

            if (waiting_for_key) {

              /*
                  Store the key that was just released
              */
              chip8.v[target_v_reg] = i;
              /*
                Increment the PC
              */
              chip8.pc += 2;

              /*
                    Resume the CPU
              */
              waiting_for_key = false;
            }
            key.pressed[key.value] = 0x00;
            key.released[key.value] = 0x01;

            key.new_key = false;

          }
        }

      }
      break;
    case 83:
      /*
          Start the pixel clock
      */
      pixel_clock.output_pixel = true;
      break;
    case 179:
      /*
          End the pixel clock
      */
      pixel_clock.output_pixel = false;
      break;
    case 181:
      /*
            Read the debug switch
      */
      sys.debug = (PINB >> 2) & 0x01;

      /*
            Read the screen wrap mode
      */
      sys.screen_mode = (PINB >> 1) & 0x01;

      /*
            The CPU speed switch
      */
      sys_speed = cpu_speed[(PINH >> 5) & 0x03];
      /*
            Set the speed LED
      */
      PORTL = (PORTL & 0xFC) | ~((PINH >> 5) & 0x03);

      /*
            The run/program switch
      */
      sys.program = ((PIND >> 7) & 0x01);

      rp = (((PIND >> 7) & 0x01) << 1) | (~(PIND >> 7) & 0x01);
      PORTL = (PORTL & 0xF3) | (rp << 2);
      break;
    case 182:

      /*
          Set the debug LED
      */
      if (sys.debug == true)
      {
        PORTB |= _BV (3);
      } else {
        PORTB &= ~_BV (3);
        /*
           Clear the break point
        */
        sys.bp = 0;
        sys.bp_set = false;

      }

      /*
            Increment the debounce timer
      */
      debounce ++;

      /*
          Start the blanking period
      */
      blanking = true;
      break;
    case 255:
      /* V_Sync Start   */
      /* Invert the pin */
      TCCR1A &= ~(1 << COM1A0);

      /*
            Check the timers
      */
      if (chip8.dt > 0x00)
      {
        chip8.dt --;
      }

      if (chip8.st > 0x00)
      {
        chip8.st --;
        sys.sound_on = true;
      } else {
        sys.sound_on = false;
      }
      break;
    case 261:
      /* Reset the counts  */
      pixel_clock.line_count = 0;

      pixel_clock.ram_line = 0;

      pixel_clock.line_repeat = 0;

      /* V_Sync End     */
      /* Invert the pin */
      TCCR1A |= (1 << COM1A1) | (1 << COM1A0);

      break;
  }

  /*
    Increment the screen line count
  */
  pixel_clock.line_count++;

  /*
      Sound generator on pin D7
  */
  if (sys.sound_on == true) {
    TCCR4A |= (1 << COM4B1);  // Connect Pin 7 to Timer 4 (SOUND ON)
  } else {
    TCCR4A &= ~(1 << COM4B1); // Disconnect Timer (SOUND OFF)
    PORTE &= ~(1 << 4);       // Ensure pin is low
  }


}/* End ISR */
