����                                        	incdir	vincludeos3asm:

	include include/macros.i
	include include/equates.i

	include exec/exec.i
	include dos/dos.i
	include graphics/gfx.i
	include graphics/gfxbase.i
	include graphics/copper.i

	include hardware/blit.i	
	include hardware/cia.i
	include hardware/custom.i
	include hardware/dmabits.i

	include	dos/dos_lib.i
	include exec/exec_lib.i
	include include/mathieeesingbas.i
	include	include/mathieeesingtrans.i

PX_WIDE	=	320
PX_TALL	=	200
PX_COUNT=	PX_WIDE*PX_TALL
PX_BYTES=	PX_COUNT/8

PX_WIDE_BYTES=	PX_WIDE/8
PX_TALL_BYTES=	PX_TALL/8

	JUMPPTR	start

	SECTION CODE,CODE

	include matrix.s
	include include/takeover.s
	include	include/blitter.s
	include include/shapedraw.s

;;;;;;;
; FP Matrix math
;;;;;;;

	STRUCTURE	MatrixFloatRow4,0
	FLOAT		r_col0
	FLOAT		r_col1
	FLOAT		r_col2
	FLOAT		r_col3
	LABEL		MatrixFloatRow4_SIZEOF

	STRUCTURE 	MatrixFloat44,0
	STRUCT		mat_row0,MatrixFloatRow4_SIZEOF
	STRUCT		mat_row1,MatrixFloatRow4_SIZEOF
	STRUCT		mat_row2,MatrixFloatRow4_SIZEOF
	STRUCT		mat_row3,MatrixFloatRow4_SIZEOF
	LABEL		MatrixFloat44_SIZEOF


;;;;;

start:
	move.l	SysBase,a6	;Exec library base address
	lea	dos_name,a1
	moveq	#36,d0
	jsr	_LVOOpenLibrary(a6)
	beq	final_exit	;failed to open dos.library
	move.l	d0,dos_base

	lea	gfx_name,a1
	moveq	#36,d0
	jsr	_LVOOpenLibrary(a6)
	beq	final_exit	;failed to open graphics.library
	move.l	d0,gfx_base

	lea	mathieeesingbas_name,a1
	moveq	#36,d0
	jsr	_LVOOpenLibrary(a6)
	beq	final_exit
	move.l	d0,mathieeesingbas_base

	lea	mathieeesingtrans_name,a1
	moveq	#36,d0
	jsr	_LVOOpenLibrary(a6)
	beq	final_exit
	move.l	d0,mathieeesingtrans_base

; matrix test stuff
	InitMatrix44 MatrixBufferLeft
	InitMatrix44 MatrixBufferRight

	move.l	mat_row0,d0
	move.l	mat_row1,d1
	move.l	mat_row2,d2
	move.l	mat_row3,d3

	move.l	#1,(r_col0,a0,d0)
	move.l	#2,(r_col1,a0,d0)
	move.l	#3,(r_col2,a0,d0)
	move.l	#4,(r_col3,a0,d0)

	AddMatrix44 MatrixBufferLeft,MatrixBufferRight
	
	jsr	PrecalculateRadians

	jsr	SystemTakeover

	jsr	ResetBitplanePtr

;clear bitplane
	move.l	#Bitplane1,d0
	move.l	#Bitplane1,d1
	add.l	#PX_BYTES,d1

	move.l	d0,a0
	move.l	d1,a1

.bplclear:
	move.l	#Bitplane1,a0
	JSR	ClearLoRes

DoCoolStuff:
	;TODO: cool stuff
	JSR	CoolDemoStuff	

done:
	jsr	SystemRelease

CloseFFPLibs:
	move.l	mathieeesingtrans_base,d0
	move.l	d0,a1
	move.l	SysBase,a6
	jsr	_LVOCloseLibrary(a6)

	move.l	mathieeesingbas_base,d0
	move.l	d0,a1
	move.l	SysBase,a6
	jsr	_LVOCloseLibrary(a6)

CloseGfxLib:
	move.l	gfx_base,d0
	move.l	d0,a1
	move.l	SysBase,a6
	jsr	_LVOCloseLibrary(a6)

CloseDosLib:
	move.l	dos_base,d0
	move.l	d0,a1
	move.l	SysBase,a6
	jsr	_LVOCloseLibrary(a6)

final_exit:
	rts

;;;;;;;;;;;;;;;;;;;;;;;;;;;


;;;;;;;;;;;;;;;;;;;;;;;;;;;

	SECTION CoolStuff,CODE



;;;;;;;;;;;;;;;;

DemoVBL:
	PRESERVE_D
	PRESERVE_A

	move.l	#CustomBase,a6
	move.w	intenar(a6),d0
	and.w	intreqr(a6),d0
	btst	#5,d0		;VBL interrupt?
	beq	IRQ_done

FrameLoop:
	lea	Bitplane1,a0
	jsr	ClearLoRes

	addq.w	#1,shape_rot_deg
	DrawShape Bitplane1,Square,#160,#100	
	jsr	ResetBitplanePtr	

	cmp.w	#360,shape_rot_deg
	bne	.clearFlag

	move.w	#0,shape_rot_deg

.clearFlag:
	move.w	#$20,intreq(a6)		;clear VBL interrupt flag
IRQ_done:
	RESTORE_A
	RESTORE_D
	
	RTE
	
;;;;;;;;

CoolDemoStuff:
	move.l	$6C,old_vbl_isr
	move.l	#DemoVBL,$6C		;VBL/Copper/Blitter interrupt vector
	
	move.w	#$87C0,dmacon(a5)	;turn on everything we need
	move.w	#$0020,dmacon(a5)	;turn off sprites
	move.w	#$C030,intena(a5)	;enable VBL/Copper interrupts

	move.w	#0,shape_rot_deg	;initialize rotation to 0 degrees

;	SetPixel Bitplane1,#0,#0
;	PlotVertex Bitplane1,Square+2,#100,#100
;	DrawLine Bitplane1,#20,#20,#20,#120

.setCopper
	lea	Copperlist,a0
	move.l	a0,cop1lc(a5)		;use our copperlist

MouseLoop:
	btst	#CIAB_GAMEPORT0,_ciaa	;wait for a mouse click
	bne.w	MouseLoop

	move.l	old_vbl_isr,$6C		;restore the old VBL interrupt
	RTS

;;;

ResetBitplanePtr:
	;Need to do this every frame.
	move.l	#Bitplane1,d0
	lea	C_BitplanePtr,a1

	move.w	d0,6(a1)	; low word of bitplane ptr
	swap	d0	
	move.w	d0,2(a1)	; high word of bitplane ptr
	rts

;;;

DegreesToRadians:
	;d0.w = integer degrees
	;returns fp radian value in d0.l

	lea	RadiansTable,a0
	asl.w	#2,d0	;get offset. each entry in table is 4 bytes
	add.w	d0,a0
	move.l	(a0),d0	;retrieve value from table

	rts

RadiansToDegrees:
	;d0.l = fp radian value
	;returns integer degrees value in d0.w

;TODO: lookup table
	PUSHL	a6
	
	move.l	mathieeesingbas_base,a6

	move.l	ONEEIGHTY_DIV_PI,d1
	jsr	IEEESPMul(a6)

	POPL	a6
	RTS	

PrecalculateRadians:
	;Populate the Radians table with values for 0-359 degrees.
	lea	RadiansTable,a0
	move.l	#0,d7

.loop:
	move.l	mathieeesingbas_base,a6
	move.l	d7,d0
	jsr	IEEESPFlt(a6)

	move.l	PI_DIV_ONEEIGHTY,d1
	jsr	IEEESPMul(a6)	;d0 degrees * 1 degrees in radians
	
	move.l	d0,(a0)+
	addq.w	#1,d7
	cmp.w	#360,d7
	bne	.loop

.done:
	rts

;;;;;;;;;;;;;;;;;;;;;;;;;;;

SerialCharOut:
	;char to spit out is in d0
	PUSHL	a6
	and.w	#$00FF,d0
	or.w	#$0100,d0
	move.l	#CustomBase,a6
	move.w	d0,serdat(a6)
	POPL	a6
	rts

;;;;;;;;;;;;;;;;;;;;;;;;;;;

	SECTION DATA,DATA

old_vbl_isr	dc.l	0

;dos.library
dos_name	DOSNAME
dos_base 	dc.l	0

;graphics.library
gfx_name	GRAPHICSNAME
	even
gfx_base	dc.l	0

;mathieeesingbas.library
mathieeesingbas_name	dc.b	"mathieeesingbas.library",0
mathieeesingbas_base	dc.l	0

mathieeesingtrans_name	dc.b	"mathieeesingtrans.library",0
mathieeesingtrans_base	dc.l	0
	even

;;;
shape_rot_deg	dc.w	0

;Some IEEE 754 constants.
PI			dc.l	$40490fdb	;IEEE 754 format
PI_DIV_ONEEIGHTY	dc.l	$3c8efa35
ONEEIGHTY_DIV_PI	dc.l	$42652ee1

RadiansTable		ds.l	360	;precalculated radian values
;;;
	SECTION SHAPES,DATA

;Matrix math buffers.

MatrixBufferLeft:	ds.l	64
MatrixBufferRight:	ds.l	64
MatrixBufferResult:	ds.l	64

;Transformed vertices are X,Y,Z as well
TransformedVertexBuffer: 		ds.w	128

;Projected vertices are X,Y
;ProjectedVertexBuffer: 		ds.w	128

Square:
	dc.w	4
	Vertex3D_DEF	-50, -50, 0
	Vertex3D_DEF	 50, -50, 0
	Vertex3D_DEF	 50,  50, 0
	Vertex3D_DEF	-50,  50, 0

;;;;;;;;;;;;;;;;;;;;;;;;;;

	SECTION	CHIP,DATA_C

;Data for chip mem
blank_sprite:	dc.l	$0,$0,$0,$0

	CNOP	0,4
Copperlist:
	dc.w	bplcon0,$1200	;BPLCON0 = one bitplane, colorburst
	dc.w	bplcon1,$0000	;BPLCON1 = no scrolling
	dc.w	bpl1mod,$0000	;Odd bitplane modulo of 0

C_BitplanePtr:
	dc.w	bpl1pth,0
	dc.w	bpl1ptl,0

	;Set up display parameters for 320x200 NTSC format
	dc.w	diwstrt,$2c81	;DIWSTRT
	dc.w	diwstop,$f4c1	;DIWSTOP
	dc.w	ddfstrt,$0038	;DDFSTRT
	dc.w	ddfstop,$00d0	;DDFSTOP

;			$0RGB	;color table
	dc.w	color+0,$0000	;COLOR00
	dc.w	color+2,$00A0	;COLOR01

	dc.w	$ffff,$fffe	;end

	CNOP	0,4
Bitplane1:	ds.b	PX_BYTES

