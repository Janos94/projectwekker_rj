/*
 * wekker.asm
 *
 *  Created: 8-4-2015 12:33:47
 *   Author: Jan & Ricardo 
 */ 

.include "m32def.inc"; include m32def file 

.def tmp = r17; Define temp on reg 17

.def highSec = r20
.def lowSec = r21

.def highMin = r22
.def lowMin = r23

.def highHr = r24
.def lowHr = r25


// Init stackpointer program 

init: 

	ldi R16, high(RAMEND)	;
	out SPH, R16			;
	ldi R16, low(RAMEND)	;
	out SPL, R16			;
	rcall reset				;


	; f kristal = 11059200 en 1 sec = (256/11059200) * 43200
	; to do a 16-bit write, the high byte must be written before the low byte !
	; for a 16-bit read, the low byte must be read before the high byte !
	; (p 89 datasheet)
	ldi tmp, high(43200)
	out OCR1AH, tmp
	ldi tmp, low(43200)
	out OCR1AL, tmp
 
	; zet prescaler op 256 & zet timer in CTC-mode
	ldi tmp, (1 << CS12) | (1 << WGM12) 
	out TCCR1B, tmp
	; enable interrupt
	ldi tmp, (1 << OCIE1A)
	out TIMSK, tmp

// Init/reset timer to 0 sec. 

init_timer: 

	ldi highSec, 0x00
	ldi lowSec, 0x00

	ldi highMin, 0x00
	ldi lowSec, 0x00

	ldi highHr, 0x00
	ldi lowHr, 0x00

	ret
 