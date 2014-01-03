;
; Copyright (c) 2010 Ryan Kwolek
; All rights reserved.
;
; Redistribution and use in source and binary forms, with or without modification, are
; permitted provided that the following conditions are met:
;  1. Redistributions of source code must retain the above copyright notice, this list of
;     conditions and the following disclaimer.
;  2. Redistributions in binary form must reproduce the above copyright notice, this list
;     of conditions and the following disclaimer in the documentation and/or other materials
;     provided with the distribution.
;
; THIS SOFTWARE IS PROVIDED BY THE AUTHOR AND CONTRIBUTORS ``AS IS'' AND ANY EXPRESS OR IMPLIED
; WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND
; FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE AUTHOR OR
; CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
; CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
; SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON
; ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
; NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF
; ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

; intro.asm -
;    Contains routines to load the intro screen and handle its processing loop.
;

str_start .db 'P', 'R', 'E', 'S', 'S', ' ', 'S', 'T', 'A', 'R', 'T', '!', 0

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
IntroScreenShow:
	;; Set text position and print some stuff
	lda #2
	sta textpos_x
	lda #4
	sta textpos_y
	lda #LOW(str_start)
	sta str_arg
	lda #HIGH(str_start)
	sta str_arg + 1
	jsr puts

	;;;;; init and enable ppu
	ldx #%10001000      ;; generate nmi, sprite pattern table addr is 0x1000
	stx $2000           ;; PPU controller reg
	ldx #%00011110		;; normal color, show all bkg and spr
	stx $2001			;; PPU mask reg

	.intro_loop:
		lda blankstate ; wait for vblank
		cmp #1
		bne .intro_loop
		dec blankstate

		inc vblankcount
		lda vblankcount
		cmp #60
		bne .not_interval
			lda #0
			sta vblankcount


			;blink here!
		.not_interval:


		lda #$01  ; reset gamepad
		sta $4016
		lda #$00
		sta $4016

		lda $4016 ; A
		and #1
		bne .intro_done
		lda $4016 ; B
		and #1
		bne .intro_done
		lda $4016 ; select
		and #1
		bne .intro_done
		lda $4016 ; start
		and #1
		bne .intro_done
	jmp .intro_loop
	.intro_done:

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
IntroLoadBkgnd:
	lda #$20
	sta $2006 ; bg location loading
	lda #$00
	sta $2006

	ldx #0
	lda #0
	.bkg_load_buffer_space:
		sta $2007
		inx
		cpx #136
	bne .bkg_load_buffer_space

	;;;;;;;;;;;;;;;;;;;;;;;;;
	ldx #$70
	.intro_bkg_load:
		stx $2007
		inx
		cpx #$80
	bne .intro_bkg_load

	ldx #0
	lda #0
	.intro_bkg_load2:
		sta $2007
		inx
		cpx #16
	bne .intro_bkg_load2

	;;;;;;;;;;;;;;;;;;;;;;;;;
	ldx #$80
	.intro_bkg_load3:
		stx $2007
		inx
		cpx #$90
	bne .intro_bkg_load3

	ldx #0
	lda #0
	.intro_bkg_load4:
		sta $2007
		inx
		cpx #16
	bne .intro_bkg_load4

	;;;;;;;;;;;;;;;;;;;;;;;;;
	ldx #$90
	.intro_bkg_load5:
		stx $2007
		inx
		cpx #$A0
	bne .intro_bkg_load5

	ldx #0
	lda #0
	.intro_bkg_load6:
		sta $2007
		inx
		cpx #16
	bne .intro_bkg_load6

	;;;;;;;;;;;;;;;;;;;;;;;;;
	ldx #$A0
	.intro_bkg_load7:
		stx $2007
		inx
		cpx #$B0
	bne .intro_bkg_load7

	ldx #0
	lda #0
	.intro_bkg_load8:
		sta $2007
		inx
		cpx #48
	bne .intro_bkg_load8

	rts

;;;;
