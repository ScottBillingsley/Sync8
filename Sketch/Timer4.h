#ifndef TIMER4_H
#define TIMER4_H

#include <Arduino.h>

namespace Timer4 {

void begin()
{
    pinMode(7, OUTPUT);
    
    // Reset Timer 4 control registers
    TCCR4A = 0;
    TCCR4B = 0;

    // Set Mode 14: Fast PWM with TOP = ICR4
    TCCR4A |= (1 << WGM41);
    TCCR4B |= (1 << WGM42) | (1 << WGM43);

    // Set initial frequency (e.g., 440Hz)
    // Formula: TOP = (Clock / (Prescaler * Frequency)) - 1
    // (16,000,000 / (64 * 440)) - 1 = 567
    ICR4 = 359;

    // Set 50% duty cycle (Volume/Square wave symmetry)
    OCR4B = ICR4 / 2;

    // Set Prescaler to 64 (balanced for audible frequencies)
    TCCR4B |= (1 << CS41) | (1 << CS40);

    // Ensure sound is OFF initially
    TCCR4A &= ~(1 << COM4B1);  
}
  
}
#endif

// Musical Notes for CHIP-8 "Beep" Upgrades
// Formula: (16MHz / (64 * Freq)) - 1
/*
const uint16_t pitchTable[] PROGMEM = {
  605,  // C4 (261.63 Hz)
  571,  // C#4
  539,  // D4 (293.66 Hz)
  508,  // D#4
  480,  // E4 (329.63 Hz)
  453,  // F4 (349.23 Hz)
  427,  // F#4
  403,  // G4 (392.00 Hz)
  381,  // G#4
  359,  // A4 (440.00 Hz) - Standard CHIP-8 Beep
  339,  // A#4
  320,  // B4
  302   // C5 (523.25 Hz)
};

void setPitch(uint8_t noteIndex) {
    if (noteIndex > 12) noteIndex = 9; // Default to A4 (440Hz)
    
    uint16_t topValue = pgm_read_word(&pitchTable[noteIndex]);
    
    ICR4 = topValue;
    OCR4B = topValue >> 1; // 50% Duty Cycle (Bitshift is faster than /2)
}

*/
