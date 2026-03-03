#pragma once

#include <Arduino.h>

// =================================================
//          The CPU Core
// =================================================

uint8_t execute_opcode()
{
  /*
      Temporary scratch buffer
      for internal use
  */
  uint8_t temp[5];
  int16_t temp16 = 0;


  /*
        Fetch the instruction pointed to
        by the program counter
  */
  chip8.opcode = (ram[chip8.pc] << 8) | ram[chip8.pc + 1];

  /****************** Debug ****************************/

  if (sys.debug == true && sys.bp_set == true)
  {
    Serial.print("Address : 0x");
    Serial.print(chip8.pc, HEX);
    Serial.print("\t");
    Serial.print("Opcode : 0x");
    Serial.print(chip8.opcode, HEX);
    Serial.print("\t");
    Serial.print("I : 0x");
    Serial.println(chip8.i, HEX);

    for (uint8_t i = 0; i < 16; i ++)
    {
      Serial.print("v");
      Serial.print(i);
      Serial.print(" = ");
      Serial.print(chip8.v[i], HEX);
      Serial.print(" ");
    }
    
    Serial.println();
    Serial.println();
  }

  /*****************************************************/

  /*
        Decode the opcode and execute
  */
  switch (chip8.opcode & 0xF000)
  {
    case 0x0000:
      switch (chip8.opcode & 0x00FF)
      {

        case 0x00E0:                      /* Clear the display */
          clear_screen();
          /*
              Increment the PC
          */
          chip8.pc += 2;
          break;
        case 0x00EE:                      /* Return from sub   */
          chip8.pc = chip8.stack[chip8.sp];

          chip8.sp --;
          /*
              Increment the PC
          */
          chip8.pc += 2;
          break;
      }
      break;

    case 0x1000:                           /* Jump Load address to PC */
      chip8.pc = (chip8.opcode & 0x0FFF);
      break;

    case 0x2000:                           /* Call address */

      /*
          Increment the stack pointer
      */
      chip8.sp ++;
      /*
           Place the program counter on the stack
      */
      chip8.stack[chip8.sp] = chip8.pc;
      /*
          Place the address in the program counter
      */
      chip8.pc = (chip8.opcode & 0x0FFF);

      break;

    case 0x3000:                           /* Skip next if register == byte */
      temp[0] = (chip8.opcode >> 8) & 0x0F;
      temp[1] = chip8.opcode & 0x00FF;
      if (chip8.v[temp[0]] == temp[1])
      {
        chip8.pc += 4;
      } else {
        chip8.pc += 2;
      }
      break;

    case 0x4000:                           /* Skip next if register != byte */
      temp[0] = (chip8.opcode >> 8) & 0x0F;
      temp[1] = chip8.opcode & 0x00FF;
      if (chip8.v[temp[0]] != temp[1])
      {
        chip8.pc += 4;
      } else {
        chip8.pc += 2;
      }
      break;

    case 0x5000:                         /* Skip if Vx == Vy   */

      temp[0] = (chip8.opcode >> 8) & 0x0F;
      temp[1] = (chip8.opcode >> 4) & 0x0F;

      if (chip8.v[temp[0]] == chip8.v[temp[1]])
      {
        chip8.pc += 4;
      } else {
        chip8.pc += 2;
      }
      break;

    case 0x6000:                          /* Load byte into register */
      chip8.v[((chip8.opcode >> 8) & 0x0F)] = (chip8.opcode & 0x00FF);
      /*
        Increment the PC
      */
      chip8.pc += 2;
      break;

    case 0x7000:                          /* Add byte to register */
      chip8.v[((chip8.opcode >> 8) & 0x0F)] += (chip8.opcode & 0x00FF);
      /*
        Increment the PC
      */
      chip8.pc += 2;
      break;

    case 0x8000:

      switch (chip8.opcode & 0x000F)
      {
        case 0x0000:                    /*  vX = vY */
          temp[0] = (chip8.opcode >> 8) & 0x0F;
          temp[1] = (chip8.opcode >> 4) & 0x0F;

          chip8.v[temp[0]] = chip8.v[temp[1]];


          /*
            Increment the PC
          */
          chip8.pc += 2;
          break;
        case 0x0001:                   /* vX = vX | vY  */
          temp[0] = (chip8.opcode >> 8) & 0x0F;
          temp[1] = (chip8.opcode >> 4) & 0x0F;

          chip8.v[temp[0]] |= chip8.v[temp[1]];
          chip8.v[0x0F] = 0x00;

          /*
            Increment the PC
          */
          chip8.pc += 2;

          break;
        case 0x0002:                  /*  vX = vX & vY   */
          temp[0] = (chip8.opcode >> 8) & 0x0F;
          temp[1] = (chip8.opcode >> 4) & 0x0F;

          chip8.v[temp[0]] &= chip8.v[temp[1]];
          chip8.v[0x0F] = 0x00;
          /*
            Increment the PC
          */
          chip8.pc += 2;

          break;
        case 0x0003:                /*  vX = vX ^ vY    */
          temp[0] = (chip8.opcode >> 8) & 0x0F;
          temp[1] = (chip8.opcode >> 4) & 0x0F;

          chip8.v[temp[0]] ^= chip8.v[temp[1]];
          chip8.v[0x0F] = 0x00;
          /*
            Increment the PC
          */
          chip8.pc += 2;
          break;
        case 0x0004:                /* vX = vX + vY with carry */
          temp[0] = (chip8.opcode >> 8) & 0x0F;
          temp[1] = (chip8.opcode >> 4) & 0x0F;

          temp16 = chip8.v[temp[0]] + chip8.v[temp[1]];

          chip8.v[temp[0]] = temp16 & 0xFF;

          if ((temp16 >> 8) > 0x00)
          {
            chip8.v[0x0F] = 0x01;
          } else {
            chip8.v[0x0F] = 0x00;
          }

          /*
            Increment the PC
          */
          chip8.pc += 2;
          break;
        case 0x0005:              /* vX = vX - vY with carry */
          temp[0] = (chip8.opcode >> 8) & 0x0F;
          temp[1] = (chip8.opcode >> 4) & 0x0F;

          if (chip8.v[temp[0]] >= chip8.v[temp[1]])
          {
            temp[3] = 0x01;
          }  else {
            temp[3] = 0x00;
          }

          chip8.v[temp[0]] -= chip8.v[temp[1]];

          chip8.v[0x0F] = temp[3];

          /*
            Increment the PC
          */
          chip8.pc += 2;
          break;
        case 0x0006:              /* vX right shifted 1 */
          temp[0] = (chip8.opcode >> 8) & 0x0F;
          /*
              Save LSB in temp
          */
          temp[1] = chip8.v[temp[0]] & 0x01;
          /*
              Right shift one
          */
          chip8.v[temp[0]] >>= 0x01;

          chip8.v[0x0F] = temp[1];

          /*
            Increment the PC
          */
          chip8.pc += 2;
          break;
        case 0x0007:            /* vX = vY - vX with carry */
          temp[0] = (chip8.opcode >> 8) & 0x0F;
          temp[1] = (chip8.opcode >> 4) & 0x0F;

          chip8.v[temp[0]] = chip8.v[temp[1]] - chip8.v[temp[0]];

          if (chip8.v[temp[1]] >= chip8.v[temp[0]])
          {
            chip8.v[0x0F] = 0x01;
          }  else {
            chip8.v[0x0F] = 0x00;
          }


          /*
            Increment the PC
          */
          chip8.pc += 2;
          break;
        case 0x000E:            /* vX = Left shift 1 */
          temp[0] = (chip8.opcode >> 8) & 0x0F;
          /*
              Save MSB in temp
          */
          temp[1] = (chip8.v[temp[0]] >> 0x07) & 0x01;
          /*
              Multiply by 2
          */
          chip8.v[temp[0]] <<= 1;

          chip8.v[0x0F] = temp[1];
          /*
            Increment the PC
          */
          chip8.pc += 2;
          break;
      }
      break;
    case 0x9000:                          /* Skip if Vx != Vy */
      temp[0] = (chip8.opcode >> 8) & 0x0F;
      temp[1] = (chip8.opcode >> 4) & 0x0F;

      if (chip8.v[temp[0]] != chip8.v[temp[1]])
      {
        chip8.pc += 4;
      } else {
        chip8.pc += 2;
      }
      break;

    case 0xA000:                          /* Load Addres to I   */
      chip8.i = (chip8.opcode & 0x0FFF);
      /*
        Increment the PC
      */
      chip8.pc += 2;
      break;

    case 0xB000:                          /* Jumps to the address NNN plus V0. */
      if (sys.screen_mode == CLIP)
      {
        chip8.pc = (chip8.opcode & 0x0FFF) + chip8.v[0x00];
      } else {
        temp[0] = (chip8.opcode >> 8) & 0x0F;
        chip8.pc = (chip8.opcode & 0x0FFF) + chip8.v[temp[0]];
      }

      break;

    case 0xC000:                          /* Sets VX to a random number and NN. */
      temp[0] = (chip8.opcode >> 8) & 0x0F;
      temp[1] = chip8.opcode & 0xFF;
      temp[2] = random(255);

      chip8.v[temp[0]] = temp[2] & temp[1];
      /*
        Increment the PC
      */
      chip8.pc += 2;
      break;

    case 0xD000:                          /* Draw command       */
      temp[0] = (chip8.opcode >> 8) & 0x0F;
      temp[1] = (chip8.opcode >> 4) & 0x0F;
      temp[2] = chip8.opcode & 0x0F;

      chip8.v[0x0F] = draw_sprite(chip8.v[temp[0]], chip8.v[temp[1]], chip8.i, temp[2]); //, sys.mode);

      /*
        Increment the PC
      */
      chip8.pc += 2;
      break;

    case 0xE000:
      switch (chip8.opcode & 0x00FF)
      {
        case 0x9E:                        /* Skip next if vX is pressed */
          temp[0] = (chip8.opcode >> 8) & 0x0F;

          if (key.pressed[chip8.v[temp[0]]] == 0x01)
          {
            chip8.pc += 4;
          } else {
            chip8.pc += 2;
          }

          break;
        case 0xA1:                       /* Skip next if vX is not pressed */
          temp[0] = (chip8.opcode >> 8) & 0x0F;

          if (key.pressed[chip8.v[temp[0]]] != 0x01)
          {
            chip8.pc += 4;
          } else {
            chip8.pc += 2;
          }

          break;
      }

      break;

    case 0xF000:
      switch (chip8.opcode & 0x00FF)
      {
        case 0x07:                              /* Read the delay timer */
          temp[0] = (chip8.opcode >> 8) & 0x0F;
          chip8.v[temp[0]] = chip8.dt;
          /*
            Increment the PC
          */
          chip8.pc += 2;
          break;

        case 0x0A:                              /* Wait for key press  */
          target_v_reg = (chip8.opcode >> 8) & 0x0F;

          waiting_for_key = true;

          break;

        case 0x15:                              /* Set the delay timer */
          temp[0] = (chip8.opcode >> 8) & 0x0F;
          chip8.dt = chip8.v[temp[0]];
          /*
            Increment the PC
          */
          chip8.pc += 2;
          break;

        case 0x18:                              /* Set the sound timer */
          temp[0] = (chip8.opcode >> 8) & 0x0F;
          chip8.st = chip8.v[temp[0]];

          /*
            Increment the PC
          */
          chip8.pc += 2;
          break;
        case 0x1E:                            /* i = i + vX */

          temp[0] = (chip8.opcode >> 8) & 0x0F;
          temp[1] = chip8.v[temp[0]];

          chip8.i += temp[1];

          /*
            Increment the PC
          */
          chip8.pc += 2;

          break;
        case 0x29:                          /* i = font address of vX  */
          temp[0] = (chip8.opcode >> 8) & 0x0F;
          temp[1] = chip8.v[temp[0]];

          chip8.i = FONT_OFFSET + (5 * temp[1]);

          /*
            Increment the PC
          */
          chip8.pc += 2;
          break;
        case 0x33:                          /* Store BCD in memory at i */
          temp[0] = (chip8.opcode >> 8) & 0x0F;
          temp[1] = chip8.v[temp[0]];

          ram[chip8.i + 2] = temp[1] % 10;
          temp[1] /= 10;

          ram[chip8.i + 1] = temp[1] % 10;
          temp[1] /= 10;

          ram[chip8.i] = temp[1] % 10;

          /*
            Increment the PC
          */
          chip8.pc += 2;

          break;
        case 0x55:                          /* Store registers in memory at i */
          temp[0] = (chip8.opcode >> 8) & 0x0F;

          for (uint8_t q = 0; q <= temp[0]; q ++)
          {
            ram[chip8.i] = chip8.v[q];
            chip8.i ++;
          }

          /*
            Increment the PC
          */
          chip8.pc += 2;

          break;
        case 0x65:                          /* Load register from memory at i */
          temp[0] = (chip8.opcode >> 8) & 0x0F;

          for (uint8_t q = 0; q <= temp[0]; q ++)
          {
            chip8.v[q] = ram[chip8.i];
            chip8.i ++;
          }

          /*
            Increment the PC
          */
          chip8.pc += 2;
          break;

          //case 0xF8:      //output vX to the port

          //case 0xFB:      //vX = input from port


      }/* End switch */

      break;

  }/* End switch */
}
