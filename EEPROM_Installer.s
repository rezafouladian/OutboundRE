            INCLUDE 'ROMTools/Include.s'
            INCLUDE 'ROMTools/TrapMacros.s'
            INCLUDE 'ROMTools/Globals.s'
            INCLUDE 'ROMTools/CommonConst.s'
            INCLUDE 'ROMTools/Hardware/Outbound125.s'

ROMData     EQU     -12
            

            link.w  A6,#-$10
            movem.l A4-A3/D7-D4,-(SP)
            jsr     onWallaby
            tst.l   D0
            bne.b   .L1
            move.b  #1,($1C,A6)
            bra.w   .Exit
.L1:
            jsr     hasHD
            tst.l   D0
            beq.b   .NoHD
            subq.l  #4,SP
            move.l  #'EROM',-(SP)                   ; Set resource type
            moveq   #HardDiskEEPROM,D0
            move.w  D0,-(SP)                        ; Set resource ID
            _GetResource
            move.l  (SP)+,(ROMData,A6)
            bra.b   .L2
.NoHD:
            subq.l  #4,SP
            move.l  #'EROM',-(SP)                   ; Set resource type
            moveq   #FloppyEEPROM,D0
            move.w  D0,-(SP)                        ; Set resource ID
            _GetResource
            move.l  (SP)+,(ROMData,A6)
            bra.b   .L2
.L2:
            pea     (-8,SP)
            moveq   #$14,D0
            move.w  D0,-(SP)
            move.l  #$16E009C,-(SP)
            move.w  #$9D,-(SP)
            _SetRect
            pea     (-8,SP)
            _EraseRect
            pea     (-8,SP)
            moveq   #$13,D0
            move.l  #$1130096,-(SP)
            move.w  #$A4,-(SP)
            _SetRect
            pea     (-8,SP)
            _FrameRect
            move.b  #1,$50000F
            move.b  #1,$500007
            movea.l (ROMData,A6),A0
            movea.l (A0),A3
            move.l  #$7C0000,(-16,A6)
            movea.l #PtchROMBase,A4
            subq.l  #4,SP
            move.l  (ROMData,A6),-(SP)
            _SizeRsrc
            move.l  (SP)+,D7
            add.l   A3,D7
            subq.l  #4,SP
            move.l  (ROMData,A6),-(SP)
            _SizeRsrc
            move.l  (SP)+,D0
            asr.l   #8,D0
            moveq   #-2,D4
            and.l   D0,D4
            move.l  A3,D5
            add.l   D4,D5
            pea     (-8,A6)
            moveq   #$13,D0
            move.w  D0,-(SP)
            move.w  #$96,-(SP)
            move.w  D0,-(SP)
            move.w  #$A4,-(SP)
            _SetRect
            bra.b   .L7
.CopyLoop:
            move.w  (A3),D0
            cmp.w   (A4),D0
            beq.b   .L5
            movea.l (-16,A6),A0
            move.w  (A3),(A0)
            move.l  #10000,D6
            bra.b   .L4
.L3:
            move.l  D6,D0
            subq.l  #1,D6
            tst.l   D0
            bne.b   .L4
            movea.l D7,A3
            bra.b   .L5
.L4:
            move.w  (A3),D0
            cmp.w   (A4),D0
            bne.b   .L3
.L5:
            cmp.l   A3,D5
            bne.b   .L6
            cmpi.w  #$113,(-2,A6)
            bgt.b   .L6
            pea     (-8,A6)
            _PaintRect
            addq.w  #1,(-2,A6)
            add.l   D4,D5
.L6:
            adda.w  #2,A3
            adda.w  #2,A4
            addq.l  #2,(-16,A6)
.L7:
            cmp.l   A3,D7
            bhi.b   .CopyLoop
            clr.b   $50000F
            clr.b   $500007
            move.l  (ROMData,A6),-(SP)
            _ReleaseResource
            move.b  #1,(28,A6)
.Exit:
            movem.l (-$28,A6),D4-D7/A3-A4
            unlk    A6
            movea.l (SP)+,A0
            adda.w  #$14,SP
            jmp     (A0)
onWallaby:
            link.w  A6,#0
            movem.l D7-D6,-(SP)
            movea.l ROMBase,A0
            move.w  (8,A0),D7
            cmpi.w  #PlusROMVersion,D7
            beq.b   .L1
            cmpi.w  #UnknownROM,D7
            beq.b   .L1
            cmpi.w  #SEROMVersion,D7
            bne.b   .L4
.L1:
            cmpi.l  #TROMCode,PtchROMBase
            beq.b   .L2
            moveq   #0,D0
            bra.b   .L5
.L2:
            move.l  OutboundDisp,D6
            move.l  #"WSIS",OutboundDisp
            cmpi.l  #'WSIS',OutboundDisp
            beq.b   .L3
            moveq   #0,D0
            bra.b   .L5
.L3:
            move.l  D6,OutboundDisp
            moveq   #1,D0
            bra.b   .L5
.L4:
            moveq   #0,D0
.L5:
            movem.l (-8,A6),D6-D7
            unlk    A6
            rts
            dc.b    $89
            dc.b    'onWallaby'
            dc.b    $0,$0
hasHD:
            link.w  A6,#0
            moveq   #0,D0
            moveq   #Cfg2Bit1,D1
            and.b   OutboundCfg2,D1
            sne     D0
            neg.b   D0
            unlk    A6
            rts
            dc.b    $85
            dc.b    'hasHD'
            dc.b    $0,$0