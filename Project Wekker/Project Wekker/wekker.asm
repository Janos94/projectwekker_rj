/*
 * wekker.asm
 *
 *  Created: 8-4-2015 12:33:47
 *   Author: Jan & Ricardo 
 */ 

.org 0x0000
rjmp time_init

rjmp init

.org OC1Aaddr
rjmp TIMER1_COMP_ISR ; adres ISR (Timer1 Output Compare Match)

.include "m32def.inc"; include m32def file 

time_init: 	
	.def seconds = r20	;
	.def minutes = r21	;
	.def hours = r22	
	.def button = r28	; sw1 = b > instellen modus , sw0 = a > verhogen tijd

	.def alarm = r23	;
	.def alarm_h = r24	;
	.def alarm_m = r25	;

	clr seconds 
	clr minutes
	clr hours 

	clr alarm
	clr alarm_h
	clr alarm_m

init: 
	.def tmp = r16; Define tmp on reg 16
	.def tmp1 = r19

	.def var2 = r17		;
	.def var1 = r18		;	

	.def saveSR = r26	;
	.def flags = r27	;

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
	
	sei			; Enable interrupts
	clr		tmp

loop: 	
	cpi flags, 1
	breq init_time
	rcall setTime
	rcall compare_time_state
	jmp loop



// Timer routine //////////////////////

init_time:
	rcall send_time
	clr flags
	jmp sec_increment

	sec_increment:
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

		hr_increment:
		clr minutes
		inc hours
		cpi hours, 24
		breq newday
		ret
			
		newday: 
			clr hours
			ret


////// DEBOUNCER AND WAIT some miliseconds ////
debouncer: 
	cpi var2, 0
	brne count
	in tmp, PINA
	count:
		inc var2 
		cpi var2, 5
		breq update	
	count_low:
		cpi tmp, 0
		brne count_high 
		inc var1
	count_high: 
		inc tmp1
		jmp debouncer
	check: 
		cp tmp1, var1
		brsh update
		ret
	update: 
		com tmp
		out PORTB, tmp 
		mov button, tmp
		call wait_time
		ret	

wait_time:
	call wait 
	call wait 
	call wait
	call wait 
	wait: 
		inc tmp
		cpi tmp, 0xff
		brne wait1
		ret
		wait1: 
			inc tmp1
			cpi tmp1, 0xff	
			brne wait1
			rjmp wait

//////////////////////////////////////////

setTime:
	call debouncer
	CPI		button,	0b10
	BREQ	setHr
	ret
///////////
setHr:
	call debouncer
	cpi button, 0b01
	breq setHrInc
	cpi button, 0b10
	breq setMin
	//rcall blinkHr
	rjmp setHr
	////////////////
	setHrInc:
		call wait_time
		inc hours
		cpi hours, 24
		breq resetHr
		rcall send_time
		rjmp setHr
		///////////////////
		resetHr:
			clr hours
			rcall send_time
			rjmp setHr
				/*blinkHr:
					mov var1, hours
					clr hours
					rcall send_time 
					mov hours, var1
					call wait_time
					call wait_time
					ret*/

////////////		
setMin: 
	call debouncer
	cpi button, 0b01
	breq setMinInc
	cpi button, 0b10
	breq setSec
	rjmp setMin
	////////////
	setMinInc:
		call wait_time
		inc minutes
		cpi minutes, 60
		breq resetMin
		rcall send_time
		rjmp setMin	
		///////////
		resetMin:
			clr minutes
			rcall send_time
			rjmp setMin
///////////
setSec: 
	call debouncer
	cpi button, 0b01
	breq setSecInc
	cpi button, 0b10
	breq setAlarm
	rjmp setSec

	setSecInc:
		call wait_time
		inc seconds
		cpi seconds, 60
		breq resetSec
		rcall send_time
		rjmp setSec
	
	resetSec:
		clr seconds
		rcall send_time
		rjmp setSec

setAlarm:
call debouncer
rcall send_alarm_time

	setAlarmHr: 
		call debouncer
		cpi button, 0b01
		breq IncAlarmHr
		cpi button, 0b10
		breq setAlarmMin
		rjmp setAlarmHr
		////////////////
		IncAlarmHr:
			call wait_time
			inc alarm_h
			cpi alarm_h, 24
			breq resetAlarmHr
			rcall send_alarm_time
			rjmp setAlarmHr
			///////////////////
			resetAlarmHr:
				clr alarm_h
				rcall send_alarm_time
				rjmp setAlarmHr

	setAlarmMin: 
		call debouncer
		cpi button, 0b01
		breq IncAlarmMin
		cpi button, 0b10
		breq AlarmModeOnOff
		rjmp setAlarmMin
		////////////////
		IncAlarmMin:
			call wait_time
			inc alarm_m
			cpi alarm_m, 60
			breq resetAlarmMin
			rcall send_alarm_time
			rjmp setAlarmMin
			///////////////////
			resetAlarmMin:
				clr alarm_m
				inc alarm_h
				rcall send_alarm_time
				rjmp setAlarmMin

	AlarmModeOnOff: 
		call debouncer 
		call wait_time
		cpi button, 0b01
		breq ChangeAlarmMode
		cpi button, 0b10
		breq endSet
		rjmp AlarmModeOnOff
			///////////////
			ChangeAlarmMode: 
				call wait_time
				cpi alarm, 0x00 
				breq ChangeAlarmOn	
				cpi alarm, 0x01
				breq ChangeAlarmOff
				rjmp AlarmModeOnOff

			ChangeAlarmOn:
				ldi alarm, 1				
				rcall send_alarm_time
				rjmp AlarmModeOnOff

			ChangeAlarmOff:
				ldi alarm, 0
				rcall send_alarm_time
				rjmp AlarmModeOnOff
				
	
endSet:
	ret

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
	// Send indicator 
	rcall indicator 
	RCALL output
	ldi tmp, 0x80
	RCALL output
	RET

send_alarm_time:	
	//	Send zero's
	ldi tmp, 0 
	rcall output
	rcall output
	//	Send alarm hours
	MOV	tmp, alarm_h
	RCALL calc_segment
	MOV	tmp, var2
	RCALL output
	MOV	tmp, var1
	RCALL output
	//	Send alarm Minutes
	MOV	tmp, alarm_m
	RCALL calc_segment
	MOV	tmp, var2
	RCALL output
	MOV tmp, var1
	RCALL output
	// Send incators
	rcall indicator 
	RCALL output
	ldi tmp, 0x80
	RCALL output
	RET
	

compare_time_state:
	cpi alarm, 1 
	breq compare_hours
	ret 
	compare_hours: 
		cp hours, alarm_h
		brne return_from_compare
		cp minutes, alarm_m
		breq buzz_alarm 
		ret

		buzz_alarm: 
			ldi alarm, 2
			rcall send_time
			ret 

return_from_compare: 
	ret

indicator: 
	alarm_off_time:
		cpi alarm, 0 
		brne alarm_activated
		ldi tmp, 0b0110
		ret
	alarm_activated:
		cpi alarm, 1
		brne alarm_buzz
		ldi tmp, 0b0111
		ret 
	alarm_buzz: 
		cpi alarm, 2
		brne return_indicator
		ldi tmp, 0b1111
		ret

return_indicator:
	ret
	/*set_alarm_mode_off: // Used to display dots on alarm setting screen 
		cpi alarm, 2
		brne 
		ldi tmp, 0b0010
	alarm_activated_alarm mode*/



	

TIMER1_COMP_ISR:
	IN		saveSR, SREG	; save SREG
	ldi		flags, 1
	OUT		SREG, saveSR	; restore SREG
	RETI					; return from interrupt