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
;    Main source file to NesPD.  Contains main game loop and core functionality.
;    started 6/5/10
;

	.inesprg 1   ; 1 bank of program code
	.ineschr 1   ; 1 bank of picture data
	.inesmap 0   ; we use mapper 0
	.inesmir 1   ; mirror setting always 1

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;; Constants

PSPEED = 2

PRESSED_UP   = 1
PRESSED_DOWN = 2

POS_SE = 0 ;000  X+ Y+
POS_E  = 1 ;001  X+ 0
POS_NE = 2 ;010  X+ Y-
POS_N  = 3 ;011  0  Y-
POS_NW = 4 ;100  X- Y-
POS_W  = 5 ;101  X- 0
POS_SW = 6 ;110  X- Y+
POS_S  = 7 ;111  0  Y+

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;; Non-stack variables

	.bank 0
	.org $0000

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
;;;;;;;;; OAM

	.org $0300
;;;;;;sprite breakdown:
;; assume each player takes 4 sprites
;; each projectile takes 1
;; 64 sprites max
;; 32 maximum projectiles, 32 / 4 = 8 actors present on screen
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

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;; Code section

	.org $8000
	.include "src/gamepad.asm"
	.include "src/intro.asm"
	.include "src/projectile.asm"

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
main:
	sei

	jsr LoadDebugSymbols

	;; Wait for the PPU to warm up
	bit $2002
	.vblank_wait1:
		bit $2002
	bpl .vblank_wait1
	.vblank_wait2:
		bit $2002
	bpl .vblank_wait2

	;; Initial player position
	lda #10	 ;; not important right now, will get from map later
	sta posX
	sta posY

	jsr LoadPalette

	jsr IntroLoadBkgnd
	jsr IntroScreenShow

	ldy #0
	sty $2001 ; disable ppu

	jsr LoadBackground

	;; init and enable ppu
	ldx #%10001000  ;; generate nmi, sprite pattern table addr is 0x1000
	stx $2000       ;; PPU controller reg
	ldx #%00011110  ;; normal color, show all bkg and spr. top 3 bits intensify B, G, R (resp.)
	stx $2001       ;; PPU mask reg

	.main_loop:
		lda blankstate ; wait for vblank
		cmp #1
		bne .main_loop
		dec blankstate

		jsr ScanGamepad

		;; Update player sprite
		ldx posY
		stx sprite0 + 0  ; Y pos

		ldx orientation
		inx
		stx sprite0 + 1 ; Tile no.

		ldx posX
		stx sprite0 + 3  ; X pos

		;; Update projectiles
		jsr ProjectileStepAll

	jmp .main_loop

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
LoadDebugSymbols:
	lda #$CC
	sta dbg_table_start
	sta dbg_table_start + 1
	sta dbg_table_end
	sta dbg_table_end + 1


	lda #HIGH(ProjectileAdd)
	sta symbol0
	lda #LOW(ProjectileAdd)
	sta symbol0 + 1

	lda #HIGH(ProjectileStep)
	sta symbol1
	lda #LOW(ProjectileStep)
	sta symbol1 + 1

	rts

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
Halt:
	jmp Halt

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
TileAtCurrentPos:
	ldx posX
	ldy posY
	jsr TileAtPos
	rts

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;int TileAtPos(uint8_t x, uint8_t y) {
;	tmpaddr[1] = y >> 6;
;	tmpaddr[0] = (y & 0xF8) << 2;
;	tmpaddr[0] += nametablemap[0];
;	tmpaddr[1] += nametablemap[1] + Carry;
;	return *(*tmpaddr + (x >> 3));
;}
;
;   tmpaddr[1]    |   tmpaddr[0]
; F E D C B A 9 8 | 7 6 5 4 3 2 1 0
;=================|=================
; 0 0 0 0 0 0 1 1 | 1 1 1 0 0 0 0 0  Y bits
;
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
	;; TODO: Write text to a buffer instead to be printed during vblank

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
	stx $2006 		;palette control reg 1, location

	.pal_load_top:
		lda pal, x
		sta $2007		; palette control reg 2, data
		inx
		cpx #32
	bne .pal_load_top
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
	pha

	;; All PPU drawing code goes here
	lda #3         ;; perform OAM DMA
	sta $4014

	inc blankstate ;; signal to the main loop

	pla
	rti

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;; Color palette
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
	.incbin "maps/level.map"

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;; Interrupt vectors

	.bank 1
	.org $FFFA
	.dw vblank ; nmi
	.dw main   ; reset
	.dw irq    ; irq

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;; Assets

	.bank 2
	.org $0000
	.incbin "assets/nespd.bkg" ;;;;this is exactly 0x1000 bytes
	.incbin "assets/nespd.spr"

;;;;
