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
	ldi R16, high(RAMEND)
	out SPH, R16
	ldi R16, low(RAMEND)
	out SPL, R16

