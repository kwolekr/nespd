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

dir_xpos_lut:
	db PSPEED, PSPEED, PSPEED, 0, -1 * PSPEED, -1 * PSPEED, -1 * PSPEED, 0

dir_ypos_lut:
	db PSPEED, 0, -1 * PSPEED, -1 * PSPEED, -1 * PSPEED, 0, PSPEED, PSPEED

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
ProjectileAdd:
	lda numproj
	cmp #32
	bcc .not_too_many
		rts
	.not_too_many:

	lda #0
	.top:
		tax
		lda sprite1 + 1, x
		beq .break

		clc
		adc #4
	bpl .top
	.break:

	lda posY
	sta sprite1 + 0, x ;; Y pos

	lda #11
	sta sprite1 + 1, x ;; tile no.

	lda orientation
	asl A
	asl A
	sta sprite1 + 2, x ;; attributes

	lda posX
	clc
	adc #3
	sta sprite1 + 3, x ;; X pos

	inc numproj

	rts

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
ProjectileStepAll:
	lda #0

	.top:
		cmp #128
		beq .end

		pha

		jsr ProjectileStep

		pla
		clc
		adc #4
	jmp .top
	.end:

	rts

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;void ProjectileStep(int i) {
;	int dir, x, y;
;
;	if (!sprites[i].tile)
;		return;
;
;	dir = (sprites[i].attributes >> 2) & 7;
;
;	x = sprites[i].x;
;	x += x_lut[dir];
;	sprites[i].x = x;
;
;	y = sprites[i].y;
;	y += y_lut[dir];
;	sprites[i].y = y;
;
;	if (!IsNotCollision(x, y)) {
;		sprites[i].tile = 0;
;	} else {
;		sprites[i].attributes ^= 0x80;
;	}
;}
ProjectileStep: ;; parameter: projectile desc offset in A
	tay

	;; stop if unused projectile
	lda sprite1 + 1, y
	bne .valid
		rts
	.valid:

	;; Extract the direction stored in the 3 unused bits
	;; of the PPU OAM descriptor
	lda sprite1 + 2, y
	lsr A
	lsr A
	and #7
	tax

	lda posX
	pha
	lda posY
	pha

	;; Update X position
	lda sprite1 + 3, y
	clc
	adc dir_xpos_lut, x
	sta sprite1 + 3, y
	sta posX

	;; Update Y position
	lda sprite1 + 0, y
	clc
	adc dir_ypos_lut, x
	sta sprite1 + 0, y
	sta posY

	tya
	pha

	jsr IsNotCollision
	beq .no_collision
		pla
		tay

		lda #0
		sta sprite1 + 1, y

		dec numproj

		;; call action here
		jmp .endif
	.no_collision:
		pla
		tay

		;; flip the projectile vertically
		lda sprite1 + 2, y
		eor #%01000000
		sta sprite1 + 2, y
	.endif:

	pla
	sta posY
	pla
	sta posX

	rts

;;;;
