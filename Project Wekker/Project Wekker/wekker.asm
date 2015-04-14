/*
 * wekker.asm
 *
 *  Created: 8-4-2015 12:33:47
 *   Author: Jan & Ricardo 
 */ 

.org 0x0000
rjmp init

.org OC1Aaddr
rjmp TIMER1_COMP_ISR ; adres ISR (Timer1 Output Compare Match)

.include "m32def.inc"; include m32def file 

// Kleine aanpassing, kunnen beter alles in 1 variabele zetten

init: 
	.def tmp = r16; Define tmp on reg 16

	.def var2 = r17		;
	.def var1 = r18		;

	.def status = r19	;

	.def seconds = r20	;
	.def minutes = r21	;
	.def hours = r22	;

	.def alarm = r23	;
	.def alarm_h = r24	;
	.def alarm_m = r25	;

	.def saveSR = r26	;
	.def flags = r27	;

	.def clear = r28
	
	/*clr seconds
	clr minutes
	clr hours */

	// Init stackpointer program 
	ldi		tmp,low(RAMEND)
	out		Spl,tmp
	ldi		tmp,high(RAMEND)
	out		Sph,tmp	

	// Init UART/RS232
	clr tmp;
	out UBRRH, tmp
	ldi tmp, 35 ; 19200 baud
	out UBRRL, tmp
	; set frame format : asynchronous, parity disabled, 8 data bits, 1 stop bit
	ldi tmp, (1<<URSEL)|(1<<UCSZ1)|(1<<UCSZ0)
	out UCSRC, tmp
	; enable receiver & transmitter
	ldi tmp, (1 << RXEN) | (1 << TXEN)
	out UCSRB, tmp

	;f kristal = 11059200 en 1 sec = (256/11059200) * 43200
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

	// init INT1
	LDI		tmp, (1<<ISC11)	; INT1 genereert interrupt			
	OUT		MCUCR, tmp		
	LDI		tmp, (1<<INT1)	; enable INT1 (GICR)
	OUT		GICR, tmp

	// init port
	SER		tmp		; tmp = $FF
	OUT		DDRB,	tmp	; Port B is output port (via LEDs)
	OUT		PORTB,	tmp	; LEDs uitzetten
	SEI				; enable all interrupts

	//Clear tmp
	CLR		tmp

loop: 
	
	cpi flags, 1
	breq time_increment
	//rcall time_increment
	jmp loop

TIMER1_COMP_ISR:			; ISR wordt elke seconde aangeroepen
	IN		saveSR, SREG	; save SREG
	ldi		flags, 1
	OUT		SREG, saveSR	; restore SREG
	RETI				; return from interrupt

// Timer routine //////////////////////

time_increment: 
	rcall send_time
	clr flags
	inc seconds
	cpi seconds, 60
	breq min_increment
	ret
	
	min_increment:
		clr seconds
		inc minutes
		cpi minutes, 60
		breq hr_increment
		ret
		//rjmp call_interupt

		hr_increment:
		clr minutes
		inc hours
		cpi hours, 24
		breq newday
		ret
		//rjmp call_interupt
			
		newday: 
			clr hours
			ret
			//rjmp call_interupt

output:
	//Wait for empty transmit buffer
	SBIS UCSRA, UDRE
	rjmp output

	out UDR, tmp
	RET

input: 
	; Wait for data to be received
	sbis UCSRA, RXC
	rjmp input
	; Get and return received data from buffer
	in tmp, UDR
	ret

// Build segment value from tmp reg
build_segment: 

	zero:
		cpi tmp, 0
		brne one
		ldi tmp, 0b01110111
		ret
	one:
		cpi tmp, 1
		brne two
		ldi tmp, 0b00100100
		ret
	two:
		cpi tmp, 2
		brne three
		ldi tmp, 0b01011101
		ret
	three:
		cpi tmp, 3
		brne four
		ldi tmp, 0b01101101
		ret 
	four: 
		cpi tmp, 4
		brne five
		ldi tmp, 0b00101110
		ret 
	five: 
		cpi tmp, 5
		brne six
		ldi tmp, 0b01101011
		ret 
	six: 
		cpi tmp, 6
		brne seven
		ldi tmp, 0b01111011
		ret 
	seven: 
		cpi tmp, 7
		brne eight
		ldi tmp, 0b00100101
		ret 
	eight: 
		cpi tmp, 8
		brne nine
		ldi tmp, 0b01111111
		ret
	nine: 
		cpi tmp, 9 
		brne end_build
		ldi tmp, 0b01101111
		ret 

end_build: 
	ret

calc_segment:
MOV	var1,	tmp
CLR	var2

split_bytes_loop:
	CPI		var1, 10
	BRLO	split_bytes_loop_end
	INC		var2
	SUBI	var1, 10
	JMP		split_bytes_loop
split_bytes_loop_end:
MOV		tmp,	var1
RCALL	build_segment
MOV		var1,	tmp
MOV		tmp,	var2
RCALL	build_segment
MOV		var2,	tmp
RET
			
send_time:
	
	//	Send Hours
	MOV	tmp, hours
	RCALL calc_segment
	MOV	tmp, var2
	RCALL output
	MOV	tmp, var1
	RCALL output
	//	Send Minutes
	MOV	tmp, minutes
	RCALL calc_segment
	MOV	tmp, var2
	RCALL output
	MOV tmp, var1
	RCALL output
	//	Send Second
	MOV	tmp, seconds
	RCALL calc_segment
	MOV	 tmp, var2
	RCALL output
	MOV	tmp, var1
	RCALL output
	ldi tmp, 0b00000111
	RCALL output
	ldi tmp, 0x80
	RCALL output
	RET
	
/*
reset:	// Reset clock to 00:00:00.
	ldi seconds, 0x00
	ldi minutes, 0x00
	ldi hours, 0x00
	ret*/

/*TIMER1_ISR:				; ISR wordt elke seconde aangeroepen
	IN saveSR, SREG		; save SREG
	RCALL time_increment
	OUT	SREG, saveSR	; restore SREG
	RETI				; return from interrupt

// ISR voor INT1
handle_INT_1:
	IN		saveSR, SREG	; save SREG
	RCALL time_increment
	OUT		PORTB,	seconds
	OUT		SREG,	saveSR	; restore SREG
	RETI				; return from interrupt*/


	
/*// ISR voor Timer1 van 5Hz
TIMER1_ISR:					
	IN saveSR, SREG	; save SREG

//Timer Tellers
	CPI flags, 2
	BREQ TIMER1_ISR_Time
	CPI	flags, 5
	BREQ TIMER1_ISR_10Mark
	JMP	TIMER1_ISR_end
//Freq is 1Hz
TIMER1_ISR_10Mark:
	RCALL send_time
	CPI status, 0
	BRNE skip_inc
	RCALL time_increment
skip_inc:
	LDI flags, 0
	JMP	TIMER1_ISR_End
//Freq is 1Hz met  offset van 0.5sec
TIMER1_ISR_Time:
	rjmp send_time

TIMER1_ISR_End:
	INC	flags
	CPI	flags, 6
	BREQ nullify_flags
	//OUT PORTB,	seconds
	OUT SREG, saveSR	; restore SREG
	RETI				; return from interrupt

nullify_flags:
LDI		flags, 0
JMP	TIMER1_ISR_End 
	
	*/

/*(check0: 
		rcall input 
		cpi tmp, 0x02
		breq call_interupt
		rjmp check0

check1: 
		rcall input 
		cpi tmp, 0x03
		breq call_interupt
		rjmp check1
*/