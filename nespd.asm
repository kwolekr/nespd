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

; nespd.asm -
;    Main source file to NesPD
;    started 6/5/10
;

	.inesprg 1   ; 1 bank of program code
	.ineschr 1   ; 1 bank of picture data
	.inesmap 0   ; we use mapper 0
	.inesmir 1   ; mirror setting always 1

	.bank 0		 ; code

	.org $0000

PSPEED = 2

PRESSED_UP   = 1
PRESSED_DOWN = 2

POS_SE = 0
POS_E  = 1
POS_NE = 2
POS_N  = 3
POS_NW = 4
POS_W  = 5
POS_SW = 6
POS_S  = 7

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

posX	    db 0
posY	    db 0
orientation db 0
stepspeed	db 0
stepstate	db 0
numproj     db 0

blankstate  db 0
vblankcount db 0

textpos_x   db 0
textpos_y   db 0

singleshot	db 0

bstate		db 0

tmp0 		db 0
tmp1 		db 0
tmpaddr     dw 0

str_arg		dw 0

dbg_table_start dw 0
symbol0			dw 0
symbol1			dw 0
dbg_table_end   dw 0

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

	.org $0300	 ; oam copy

sprite0:
	db 0
	db 0
	db 0
	db 0
sprite1:
	db 0
	db 0
	db 0
	db 0
sprite2:
	db 0
	db 0
	db 0
	db 0

	.org $8000

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
main:
	sei

	jsr LoadDebugSymbols

	bit $2002
	.vblank_wait1:
		bit $2002
	bpl .vblank_wait1
	.vblank_wait2:
		bit $2002
	bpl .vblank_wait2

	lda #10		;;;initial position
	sta posX
	sta posY

	jsr LoadPalette
	jsr LoadIntroScreen

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
	ldx #%00011110		;; normal color, show all bkg and spr. top 3 bits intensify B, G, R respectively
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


	ldy #0
	sty $2001 ; disable ppu

	jsr LoadBackground

	;;;;; init and enable ppu
	ldx #%10001000      ;; generate nmi, sprite pattern table addr is 0x1000
	stx $2000           ;; PPU controller reg
	ldx #%00011110		;; normal color, show all bkg and spr. top 3 bits intensify B, G, R respectively
	stx $2001			;; PPU mask reg

	.main_loop:
		lda blankstate ; wait for vblank
		cmp #1
		bne .main_loop
		dec blankstate

		jsr ScanGamepad

		;;;;;;;;;;;;;;;;;;;;;
		lda posY
		;clc
		;adc 4
		sta sprite0 + 0  ; Y pos
		lda orientation ;player sprite
		clc
		adc #1
		sta sprite0 + 1 ; Tile no.
		lda posX
		;clc
		;sbc 4
		sta sprite0 + 3  ; X pos
		;;;;;;;;;;;;;;;;;;;;;

		jsr DrawProjectiles

		lda #3		;reload OAM addrs
		sta $4014

	jmp .main_loop

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
str_start .db 'P', 'R', 'E', 'S', 'S', ' ', 'S', 'T', 'A', 'R', 'T', '!', 0

LoadDebugSymbols:

	lda #$CC
	sta dbg_table_start
	sta dbg_table_start + 1
	sta dbg_table_end
	sta dbg_table_end + 1


	lda #HIGH(TileAtPos)
	sta symbol0
	lda #LOW(TileAtPos)
	sta symbol0 + 1

	lda #HIGH(DrawProjectiles)
	sta symbol1
	lda #LOW(DrawProjectiles)
	sta symbol1 + 1

	rts

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
HaltExec:
	jmp HaltExec

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
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
		jsr ShootProjectile
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

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;void ShootProjectile() {
;	a = numproj
;	if (a < 32) {
;		a <<= 2;
;		y = a;
;
;
;
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

;#define POS_SE 0   - (000)  X+ Y+
;#define POS_E  1   - (001)  X+ 0
;#define POS_NE 2   - (010)  X+ Y-
;#define POS_N  3   - (011)  0  Y-
;#define POS_NW 4   - (100)  X- Y-
;#define POS_W  5   - (101)  X- 0
;#define POS_SW 6   - (110)  X- Y+
;#define POS_S  7   - (111)  0  Y+
orient_xpos_lut:
	db PSPEED, PSPEED, PSPEED, 0, -1 * PSPEED, -1 * PSPEED, -1 * PSPEED, 0

orient_ypos_lut:
	db PSPEED, 0, -1 * PSPEED, -1 * PSPEED, -1 * PSPEED, 0, PSPEED, PSPEED

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

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;int TileAtCurrentPos() {
;	tmpaddr[1] = posY >> 6;
;	tmpaddr[0] = (posY & 0xF8) << 2;
;	tmpaddr[0] += nametablemap[0];
;	tmpaddr[1] += nametablemap[1] + Carry;
;	return *(*tmpaddr + (posX >> 3));
;}
;
;   tmpaddr[1]    |   tmpaddr[0]
; F E D C B A 9 8 | 7 6 5 4 3 2 1 0
;=================|=================
; 0 0 0 0 0 0 1 1 | 1 1 1 0 0 0 0 0  posY
;
TileAtCurrentPos:
	ldx posX
	ldy posY
	jsr TileAtPos
	rts

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
TileAtPos: ; Parameters: Y == y pos, X == x pos
	tya
	lsr A
	lsr A
	lsr A
	lsr A
	lsr A
	lsr A
	sta tmpaddr + 1

	tya
	and #$F8
	asl A
	asl A
	sta tmpaddr

	clc
	lda tmpaddr
	adc #LOW(nametablemap)
	sta tmpaddr
	lda tmpaddr + 1
	adc #HIGH(nametablemap)
	sta tmpaddr + 1

	txa
	lsr A
	lsr A
	lsr A
	tay

	lda [tmpaddr], Y
	rts

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
IsNotCollision:
	lda posX
	clc
	adc #2
	tax

	lda posY
	clc
	adc #8
	tay

	jsr TileAtPos
	cmp #0 ;;is the tile empty?
	rts

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
puts: ;str_arg - string to print out, returns len
	ldy #0
	;sty $2001 ; disable ppu

	;$2000 + y * 32 + x;
	;


	lda textpos_y
	;and #7
	clc
	asl A
	asl A
	asl A
	asl A
	asl A
	clc
	adc textpos_x
	tax

	lda textpos_y
	lsr A
	lsr A
	lsr A
	adc #$20

	sta $2006
	stx $2006

	;lda #$20	;addr $2000
	;sta $2006
	;sta $2006

	.puts_loop:
		lda [str_arg], Y
		cmp #0
		beq .puts_done
		clc
		adc #$10
		sta $2007
		iny
		jmp .puts_loop
	.puts_done:

	lda #%00011110 ; enable ppu
	sta $2001
	tya
	rts

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
LoadPalette:
	ldx #$3F
	stx $2006
	ldx #$00
	stx $2006 		;pallate control reg 1, location

	.pal_load_top:
		lda pal, x
		sta $2007		; pallate control reg 2, data
		inx
		cpx #32
	bne .pal_load_top
	rts

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
LoadIntroScreen:
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

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
LoadBackground:
	lda #$20
	sta $2006 ; bg location loading
	lda #$00
	sta $2006

	;ldx #0
	;lda #0
	;.bkg_load_buffer_space:
	;	sta $2007
	;	inx
	;	cpx #32
	;bne .bkg_load_buffer_space

	ldx #0
	.bkg_load_nametable_x:
		lda nametablemap, x
		inx
		sta $2007
		cpx #0
	bne .bkg_load_nametable_x
	.bkg_load_nametable_x2:
		lda nametablemap + $100, x
		inx
		sta $2007
		cpx #0
	bne .bkg_load_nametable_x2
	.bkg_load_nametable_x3:
		lda nametablemap + $200, x
		inx
		sta $2007
		cpx #0
	bne .bkg_load_nametable_x3
	.bkg_load_nametable_x4:
		lda nametablemap + $300, x
		inx
		sta $2007
		cpx #192 ;#160
	bne .bkg_load_nametable_x4

	lda #0
	ldx #0
	.bkg_pallate_load:
		sta $2007
		inx
		cpx #64
	bne .bkg_pallate_load
	rts

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
irq:
	rti

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
vblank:

	inc blankstate
	rti

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
pal:
	db $0F					; universal bg color

	db $2D, $30, $00		; bg palette 0
	db 0
	db $0C, $0C, $0C		; bg palette 1
	db 0
	db $0B, $0B, $0B		; bg palette 2
	db 0
	db $0A, $0A, $0A		; bg palette 3

	db $0F					; universal BG color

	db $0C, $00, $30		; sprite palette 0
	db 0
	db $0C, $0C, $0C		; sprite palette 1

	db 0
	db $0B, $0B, $0B		; sprite palette 2
	db 0
	db $0A, $0A, $0A		; sprite palette 3
	db 0

nametablemap:
	.incbin "level.map"
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

	.bank 1
	.org $FFFA  ; interrupt vectors
	.dw vblank 	; nmi
	.dw main 	; reset
	.dw irq 	; irq

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

	.bank 2
	.org $0000
	.incbin "nespd.bkg" ;;;;this is exactly 0x1000 bytes
	.incbin "nespd.spr"
	;;;;;THERE MUST BE A LINE HERE, NESASM IS BUGGED!;;;;;;;
