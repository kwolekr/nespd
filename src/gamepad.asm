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

; gamepad.asm -
;    Contains routines to scan the gamepad and handle button presses.
;

ScanGamepad:
	ldx #$01  ; reset gamepad
	stx $4016
	ldx #$00
	stx $4016

	stx bstate

	lda $4016 ; A
	and #1
	beq .not_A_button
		jsr ButtonA
		jmp .A_endif
	.not_A_button:
		stx singleshot
	.A_endif:

	lda $4016 ; B
	and #1
	beq .not_B_button
		jsr ButtonB
	.not_B_button:

	lda $4016 ; select
	and #1
	beq .not_select_button
		jsr ButtonSelect
	.not_select_button:

	lda $4016 ; start
	and #1
	beq .not_start_button
		jsr ButtonStart
	.not_start_button:

	lda $4016 ; up
	and #1
	beq .not_up_button
		lda #PRESSED_UP
		sta bstate

		jsr ButtonUp
	.not_up_button:

	lda $4016 ; down
	and #1
	beq .not_down_button
		lda #PRESSED_DOWN
		sta bstate

		jsr ButtonDown
	.not_down_button:

	lda $4016 ; left
	and #1
	beq .not_left_button
		jsr ButtonLeft
	.not_left_button:

	lda $4016 ; right
	and #1
	beq .not_right_button
		jsr ButtonRight
	.not_right_button:
	rts

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
ButtonA:
	lda #1
	cmp singleshot
	beq .already_shot
		sta singleshot
		jsr ProjectileAdd
	.already_shot:
	rts

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
ButtonB:

	;lda #LOW(str_0)
	;sta str_arg
	;lda #HIGH(str_0)
	;sta str_arg + 1

	;jsr puts

	rts
str_0: db 'L', 'O', 'L', 'W', 'U', 'T', 0

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
ButtonUp:
	lda #POS_N
	sta orientation
	;cmp orientation
	;bne .ch_orient
		dec posY
		dec posY
		jsr IsNotCollision
		bne .no_move_up
			dec posY
			dec posY

			;lda sprite0 + 2
			;eor #%11000000
			;sta sprite0 + 2
		.no_move_up:
		inc posY
		inc posY
		;jmp .end_if
	;.ch_orient:

	;.end_if:
	rts

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
ButtonDown:
	lda #POS_S
	sta orientation
	;cmp orientation
	;bne .ch_orient
		inc posY
		inc posY
		jsr IsNotCollision
		bne .no_move_down
			inc posY
			inc posY
			;;;lda stepspeed
			;lda sprite0 + 2
			;eor #%11000000
			;sta sprite0 + 2
		.no_move_down:
		dec posY
		dec posY
		;jmp .end_if
	;.ch_orient:

	;.end_if:
	rts

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
ButtonLeft:
	lda bstate
	cmp #PRESSED_UP
	bne .ldidnt_press_up
		lda #POS_NW
		jmp .lif_dp_done
	.ldidnt_press_up:
		cmp #PRESSED_DOWN
		bne .ldidnt_press_down
			lda #POS_SW
			jmp .lif_dp_done
		.ldidnt_press_down:
		lda #POS_W
	.lif_dp_done:
	sta orientation

	dec posX ; test the movement
	dec posX
	jsr IsNotCollision
	bne .no_move_left
		dec posX ; actually carry out the movement
		dec posX

		;lda sprite0 + 2
		;eor #%11000000
		;sta sprite0 + 2
	.no_move_left:
	inc posX
	inc posX
	rts

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
ButtonRight:
	lda bstate
	cmp #PRESSED_UP
	bne .didnt_press_up
		lda #POS_NE
		jmp .if_dp_done
	.didnt_press_up:
		cmp #PRESSED_DOWN
		bne .didnt_press_down
			lda #POS_SE
			jmp .if_dp_done
		.didnt_press_down:
		lda #POS_E
	.if_dp_done:
	sta orientation

	inc posX
	inc posX
	jsr IsNotCollision
	bne .no_move_right
		inc posX
		inc posX

		;lda sprite0 + 2
		;eor #%11000000
		;sta sprite0 + 2

		;;;;;;;;;experimental
		;lda posX
		;sta $2005
		;lda posY
		;sta $2005
		;;;;;;;;;;;;;;;;;;;;;

	.no_move_right:
	dec posX
	dec posX
	rts

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
ButtonStart:
	;;;;; STUB
	rts

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
ButtonSelect:
	inc stepspeed
	lda stepspeed
	cmp #3
	bne .stepspeed_not_over
		lda #0
		sta stepspeed
	.stepspeed_not_over:
	rts

;;;;
