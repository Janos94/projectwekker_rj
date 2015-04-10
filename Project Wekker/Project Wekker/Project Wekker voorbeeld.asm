/*
 * wekker.ASM
 */ 
 
 
 ; leds met portB om output te zien
.include "m32def.inc"
.def saveSR = r17
.def temp = r18
 
.def highSecond = r19
.def lowSecond = r20
 
.def highMinute = r20
.def lowMinute = r21
 
.def highHour = r22
.def lowHour = r23
 
.org 0x0000
	rjmp init ; bij opstarten & reset naar init
 
.org OC1Aaddr
	rjmp increaseSeconds ; adres ISR (Timer1 Output Compare Match)
 
 
init:
	; init stack pointer
	ldi R16, high(RAMEND)
	out SPH, R16
	ldi R16, low(RAMEND)
	out SPL, R16
 
	RCALL initTimer
	RCALL initOutputCompare
	RCALL initPorts
 
 
loop:
	cpi TimerFlags,0x01
	breq newLowSecond
	rjmp loop; wacht in lus op interrupt
 
secondCounter: ; ISR wordt elke seconde aangeroepen
	in saveSR, SREG ; save SREG
	ldi TimerFlags,0x01 ; nieuwe seconde
	out SREG, saveSR; restore SREG
	reti
 
newLowSecond:
	clr TimerFlags 
 
	cpi lowSecond,0x09
	breq newHighSecond
 
	inc lowSecond
 
	jmp loop
 
newHighSecond:
	clr lowSecond
 
	cpi highSecond,0x5
	breq newLowMinute
 
	inc highSecond
 
	jmp loop
 
newLowMinute:
	clr highSecond
 
	cpi lowMinute,0x09
	breq newHighMinute
 
	inc lowMinute
 
	in r16, PORTB ; schrijf de inhoud van PORTB naar r16
	com r16 ; inverteer alle bits $00 <-> $FF
	out PORTB, r16 ; schrijf waarde r16 naar PORTB
 
	jmp loop
 
newHighMinute:
	clr lowMinute
 
	cpi highMinute,0x05
	breq newHour
 
	inc highMinute
 
	jmp loop
 
 
newHour:
	clr highMinute
	cpi hours,0x17
	breq newDay
 
	inc hours
 
	jmp loop
 
newDay:
	clr hours
	jmp loop
 
 
increaseSeconds: ; ISR wordt elke seconde aangeroepen
	in saveSR, SREG ; save SREG
	in r16, PORTB ; schrijf de inhoud van PORTB naar r16
 
	RCALL addSecond
 
calcIsDone:
	com r16 ; inverteer alle bits $00 <-> $FF
	out PORTB, r16 ; schrijf waarde r16 naar PORTB
	out SREG, saveSR; restore SREG
	reti ; return from interrupt
 
 
addSecond:
	inc lowSecond
	cpi lowSecond,10
	breq addHighSecond
	RET
 
 
addHighSecond:
	ldi lowSecond,0x00
	inc highSecond
	inc r16
	rjmp calcIsDone
 
 
GetNumberValue:
	/*
			0 = 0124652
			1 = 2 5
			2 = 02346
			3 = 0 2356
			4 = 1235
			5 = 01356
			6 = 13564
			7 = 0235
			8 = 0123456
			9 = 012356
	*/
 
	RET
 
 
 
 
/*
	init subroutines
*/
initTimer:
	ldi lowSecond,0x00;
	ldi highSecond,0x00
 
	ldi highMinute,0x00
	ldi lowMinute,0x00
 
	ldi highHour,0x00
	ldi lowHour,0x00
 
	RET
 
initOutputCompare:
	; init Output Compare Register
	; f kristal = 11059200 en 1 sec = (256/11059200) * 43200
	; to do a 16-bit write, the high byte must be written before the low byte !
	; for a 16-bit read, the low byte must be read before the high byte !
	; (p 89 datasheet)
	ldi temp, high(43200)
	out OCR1AH, temp
	ldi temp, low(43200)
	out OCR1AL, temp
 
	; zet prescaler op 256 & zet timer in CTC-mode
	ldi temp, (1 << CS12) | (1 << WGM12) 
	out TCCR1B, temp
	; enable interrupt
	ldi temp, (1 << OCIE1A)
	out TIMSK, temp
	RET
 
initPorts:
	; init port
	ser temp ; tmp = $FF
	out DDRB, temp ; Port B is output port (via LEDs)
	out PORTB, temp ; LEDs uitzetten
	sei ; enable alle interrupts
	; wacht in lus op interrupt
	RET