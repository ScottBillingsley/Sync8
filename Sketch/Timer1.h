#ifndef TIMER1_H
#define TIMER1_H

#include <Arduino.h>

// ============================================
//  Setup timer one for 63.55 uS with a 4.7 uS
//  pulse for the H_Sync, Output on pin 11
// ============================================

namespace Timer1 {

void begin()
{
  // Set Digital Pin 11 (PB5/OC1A) as output
  pinMode(11, OUTPUT);

  // Clear Timer1 Control Registers
  TCCR1A = 0;
  TCCR1B = 0;

  // Set Mode 14: Fast PWM with TOP in ICR1
  // WGM13=1, WGM12=1, WGM11=1 (TCCR1A/B bits)
  TCCR1A |= (1 << WGM11);
  TCCR1B |= (1 << WGM12) | (1 << WGM13);

  // Set COM1A1 and COM1A0 : Inverting PWM (Set OC1A on match, set at BOTTOM)
  // This produces a pulse that starts at the beginning of the cycle.
  TCCR1A |= (1 << COM1A1) | (1 << COM1A0);

  // Set TOP for frequency: 16MHz / 15.734kHz = ~1017 cycles
  ICR1 = 1016;

  // Set Compare Match for pulse width: 4.7us = ~75 cycles
  OCR1A = 75;

  // Start Timer1 with no prescaler (Clock = 16MHz)
  TCCR1B |= (1 << CS10);

  // Enable Compare Match A interrupt
  TIMSK1 |= (1 << OCIE1A);

  // Enable Pin Change Interrupts for Port B (PCIE0)
  PCICR |= (1 << PCIE0);

  // Enable Pin Change Interrupt specifically for Pin 11 (PCINT5)
  PCMSK0 |= (1 << PCINT5);

}

}/* End namespace */

#endif /* End Timer1,h */
