/*
 * wekker.asm
 *
 *  Created: 8-4-2015 12:33:47
 *   Author: Jan & Ricardo 
 */ 

.include "m32def.inc"; include m32def file 

.def tmp = r16; Define temp on reg 16

.def HighSec = r20
.def LowSec = r21

.def HighMin = r22
.def LowMin = r23

.def HighHr = r24
.def LowHr = r25

.def newDay = r19;


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

	rjmp loop

// Init/reset timer to 0 sec. 

reset:	// Reset clock to 00:00:00.
	ldi HighSec, 0x00
	ldi LowSec, 0x00

	ldi HighMin, 0x00
	ldi LowMin, 0x00

	ldi HighHr, 0x00
	ldi LowHr, 0x00

	ret 

// Begin timer loop //////////////////////


 loop: 
	rcall incLowHr		;
	rjmp loop			;
	
incLowSec:
	cpi LowSec, 9
	brsh incHighSec		;
	inc LowSec			; 
	ret 

incHighSec: 
	clr LowSec			;
	cpi HighSec, 5		; 
	brsh incLowMin		; 
	inc HighSec			;
	ret					;

incLowMin:
	clr HighSec			;
	cpi LowMin, 9		;
	brsh incHighMin		;
	inc LowMin			;
	ret					;

incHighMin:
	clr LowMin			;
	cpi HighMin, 5		; 
	brsh incLowHr		;
	inc HighMin			;
	ret					;

incLowHr:				
	clr HighMin			;
	rcall checkNewDay	;
	cpi LowHr, 9		; 
	brsh incHighHr		;
	inc LowHr			;
	ret

incHighHr:
	clr LowHr			;
	inc HighHr			;
	ret

checkNewDay:	
	mov newDay, Highhr	;
	add newDay, LowHr	; 		
	cpi newDay, 23		;
	brsh reset			;
	ret					;	
	
///////////////////////////////

stop: 
	rjmp stop;			
	
