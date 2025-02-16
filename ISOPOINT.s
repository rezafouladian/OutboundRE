            INCLUDE 'ROMTools/Include.s'
            INCLUDE 'ROMTools/TrapMacros.s'
            INCLUDE 'ROMTools/Globals.s'
            INCLUDE 'ROMTools/CommonConst.s'
            INCLUDE 'ROMTools/Hardware/Outbound125.s'
ISOPOINT:
            link.w  A6,#0
            movem.l A4-A3,-(SP)
            jsr     onWallaby
            tst.l   D0
            beq.w   .Exit
            subq.l  #4,SP
            move.l  #'ISOP',-(SP)
            move.w  #18280,-(SP)
            _GetResource
            movea.l (SP)+,A4
            move.l  A4,D0
            beq.b   .L4
            movea.l (A4),A3
            tst.b   (A3)
            beq.b   .L1
            movea.l OutboundGlobals,A0
            move.b  (A3),($7B,A0)
            bra.b   .L2
.L1:
            movea.l (OutboundGlobals),A0
            move.b  #4,($7B,A0)
.L2:
            tst.b   (1,A3)
            beq.b   .L3
            movea.l OutboundGlobals,A0
            move.b  (1,A3),($9A,A0)
            bra.b   .L5
.L3:
            movea.l OutboundGlobals,A0
            move.b  (1,A3),($9A,A0)
            bra.b   .L5
.L4:
            movea.l OutboundGlobals,A0
            move.b  #4,($7B,A0)
            movea.l OutboundGlobals,A0
            move.b  #3,($9A,A0)
.L5:
            move.b  OutboundCfg,D0
            btst.l  #IsMacSEROM,D0
            beq.b   .L6
            movea.l MickeyBytes,A0
            lea     ($14,A0),A0
            movea.l OutboundGlobals,A1
            move.l  A0,($94,A1)
            bra.b   .L7
.L6:
            movea.l JCrsrTask,A0
            subq.l  #8,A0
            movea.l OutboundGlobals,A1
            move.l  A0,($94,A1)
.L7:
            movea.l OutboundGlobals,A0
            move.l  #$12345678,(A0)
            move.l  A4,-(SP)
            _ReleaseResource
            jsr     ISOPOINT_F2
.Exit:
            moveq   #0,D0
            movem.l (-8,A6),A3-A4
            unlk    A6
            rts
            dc.b    $84
            dc.b    'main'
            dc.b    $0,$0,$0
ISOPOINT_F1:
            tst.l   ($94,A1)
            beq.w   .Exit
            tst.w   ($34,A1)
            bne.w   .Exit
            movea.l ($94,A1),A0
            tst.b   ($98,A1)
            beq.b   .L2
            move.b  ($7B,A1),D0
            cmp.b   ($99,A1),D0
            beq.b   .L1
            move.b  ($99,A1),D0
.L1:
            lea     ISOPOINT_Data,A1
            subq.w  #1,D0
            andi.w  #$FF,D0
            lsl.w   #3,D0
            adda.w  D0,A1
            move.l  (A1),D0
            cmp.l   (A0),D0
            bne.b   .L3
            move.l  ($4,A1),D0
            cmp.l   ($4,A1),D0
            bne.b   .L3
            movea.l OutboundGlobals,A1
            bra.b   .L4
.L2:
            move.l  (A0),D1
            cmp.l   ($7C,A1),D1
            bne.b   .L3
            move.l  (4,A0),D1
            cmp.l   ($80,A1),D1
            bne.b   .L3
            bra.b   .L4
.L3:
            movea.l OutboundGlobals,A1
            move.l  (A0),($7C,A1)
            move.l  (4,A0),($80,A1)
.L4:
            move.b  ($7B,A1),($99,A1)
            btst.b  #6,($69,A1)
            beq.b   .L5
            move.b  ($7B,A1),D0
            lea     ISOPOINT_Data,A1
            subq.w  #1,D0
            andi.w  #$FF,D0
            lsl.w   #3,D0
            adda.w  D0,A1
            move.l  (A1)+,(A0)+
            move.l  (A1),(A0)
            movea.l OutboundGlobals,A1
            move.b  #-1,($98,A1)
            bra.b   .Exit
.L5:
            move.l  ($7C,A1),(A0)+
            move.l  ($80,A1),(A0)
            clr.b   ($98,A1)
.Exit:
            rts
ISOPOINT_Data:
            dc.l    $FFFFFFFF
            dc.l    $FFFFFFFE
            dc.l    $1FFFFFF
            dc.l    $FFFFFFFF
            dc.l    $102FFFF
            dc.l    $FFFFFFFF
            dc.l    $10203FF
            dc.l    $FFFFFFFF
            dc.l    $1020304
            dc.l    $FFFFFFFF
            dc.l    $1020303
            dc.l    $FFFFFFFF
            dc.l    $1020203
            dc.l    $3FFFFFF
            dc.b    $0,$0
ISOPOINT_F2:
            movem.l A1-A0/D1-D0,-(SP)
            lea     ISOPOINT_F1,A0
            lea     ISOPOINT_F2,A1
            suba.l  A0,A1
            move.l  A1,D0
            move.l  D0,D1
            _NewPtrSys
            movea.l A0,A1
            lea     ISOPOINT_F1,A0
            move.l  D1,D0
            _BlockMove
            movea.l OutboundGlobals,A0
            move.l  A1,($AA,A0)
            movem.l (SP)+,D0-D1/A0-A1
            rts
            INCLUDE 'onWallaby.s'