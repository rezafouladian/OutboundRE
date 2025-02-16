            INCLUDE 'ROMTools/Include.s'
            INCLUDE 'ROMTools/TrapMacros.s'
            INCLUDE 'ROMTools/Globals.s'
            INCLUDE 'ROMTools/CommonConst.s'
            INCLUDE 'ROMTools/Hardware/Outbound125.s'
; Hiss Fix Init
HissFix:
            link.w  A6,#0
            jsr     onWallaby
            tst.l   D0
            beq.b   .Exit
            moveq   #1<<CfgBit3,D0
            and.b   OutboundCfg,D0
            bne.b   .Exit
            jsr     HissFix_F1
.Exit:
            unlk    A6
            rts
            dc.b    $84
            dc.b    'main'
            dc.b    $0,$0,$0
HissFix_F1:
            movem.l A1-A0/D1-D0,-(SP)
            lea     onWallaby,A0
            move.l  A0,D0
            lea     HissFix_F2,A0
            sub.l   A0,D0
            move.l  D0,D1
            _NewPtrSys
            bne.b   .Exit
            move.l  D1,D0
            movea.l A0,A1
            lea     HissFix_F2,A0
            _BlockMove
            movea.l OutboundGlobals,A0
            move.l  A1,($AE,A0)
.Exit:
            movem.l (SP)+,D0-D1/A0-A1
            rts
HissFix_F2:
            movem.l A2-A0/D2-D0,-(SP)
            movea.l OutboundGlobals,A2
            movea.l VIA,A1
            movea.l SoundBase,A0
            movep.l (0,A0),D1
            movep.l ($F4,A0),D0
            cmp.l   D0,D1
            bne.b   .L4
            movep.l ($1E8,A0),D0
            cmp.l   D0,D1
            bne.b   .L4
            movep.l ($2DC,A0),D0
            cmp.l   D0,D1
            bne.b   .L4
            btst.b  #7,(A1)
            bne.b   .L5
            move.w  #$5B,D2
.L1:
            movep.l (0,A0),D0
            cmp.l   D0,D1
            bne.b   .L5
            addq.w  #8,A0
            dbf     D2,.L1
            movep.w (0,A0),D0
            cmp.w   D0,D1
            bne.b   .L5
            cmpi.b  #3,($A7,A2)
            beq.b   .L3
            addq.b  #1,($A7,A2)
            bra.b   .Exit
.L3:
            btst.b  #7,(A1)
            bra.b   .L5
.L4:
            bclr.b  #7,(A1)
.L5:
            clr.b   ($A7,A2)
.Exit:
            movem.l (SP)+,D0-D2/A0-A2
            rts
            INCLUDE 'onWallaby.s'
