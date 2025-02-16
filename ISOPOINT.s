            INCLUDE 'ROMTools/TrapMacros.s'
ISOPOINT:
            link.w  A6,#0
            movem.l A4-A3,-(SP)
            jsr     onWallaby
            tst.l   D0
            beq.b   .Exit
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
            

            INCLUDE 'onWallaby.s'