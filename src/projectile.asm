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

; projectile.asm -
;    Contains routines to create and advance projectiles along a path, and
;    handle collisions with other objects.
;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

orient_xpos_lut:
	db PSPEED, PSPEED, PSPEED, 0, -1 * PSPEED, -1 * PSPEED, -1 * PSPEED, 0

orient_ypos_lut:
	db PSPEED, 0, -1 * PSPEED, -1 * PSPEED, -1 * PSPEED, 0, PSPEED, PSPEED

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
ShootProjectile:
	lda numproj
	cmp #32
	bcs .too_many_proj
		clc
		asl a
		asl a
		tax

		lda posY
		dec A
		sta sprite1 + 0, x    ;;;; Y pos

		lda #11
		sta sprite1 + 1, x    ;;;; tile no.

		lda orientation
		asl A
		asl A
		sta sprite1 + 2, x    ;;;; attributes

		lda posX
		clc
		adc #3
		sta sprite1 + 3, x    ;;;; X pos

		inc numproj
	.too_many_proj:
	rts

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;void DrawProjectiles() {      //0x04, 0x08, 0x10
;	for (i = 0; i != nprojs; i++) {
;		pos = (sprites[1 + i].attributes >> 2) & 7;
;		sprites[1 + i].x += x_lut[pos]
;		sprites[1 + i].y += y_lut[pos]
;		if (IsCollision(x, y)) {
;			sprites[1 + i] = sprites[1 + nprojs];
;			nprojs--;
;			i--;
;		}
;		if ()
;
;
;
DrawProjectiles:
	lda #0
	.top:
		cmp numproj
		bne .notdone
			rts
		.notdone:

		sta tmp0
		clc
		asl A
		asl A
		tay	;; Y = A * 4;

		;; X = (sprite1[Y].attrib >> 2) & 7;
		lda sprite1 + 2, y
		lsr A
		lsr A
		and #7
		tax

		lda posX
		pha
		lda posY
		pha

		;; sprite1[Y].x += orient_xpos_lut[x];
		lda sprite1 + 3, y
		adc orient_xpos_lut, x
		sta sprite1 + 3, y
		sta posX

		lda sprite1 + 0, y
		adc orient_ypos_lut, x
		sta sprite1 + 0, y
		sta posY

		jsr IsNotCollision
		beq .no_collision
			dec numproj
			lda numproj
			asl A
			asl A
			tax

			lda sprite1 + 0, x
			sta sprite1 + 0, y
			lda sprite1 + 1, x
			sta sprite1 + 1, y
			lda sprite1 + 2, x
			sta sprite1 + 2, y
			lda sprite1 + 3, x
			sta sprite1 + 3, y

			lda #0
			sta sprite1 + 0, x
			sta sprite1 + 1, x
			sta sprite1 + 2, x
			sta sprite1 + 3, x

			dec tmp0
		.no_collision:

		lda sprite1 + 2, y
		eor #%01000000
		sta sprite1 + 2, y

		pla
		sta posY
		pla
		sta posX

		lda tmp0
		clc
		adc #1
	jmp .top

;;;;
