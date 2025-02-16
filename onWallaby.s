; onWallaby
; Runs a few tests to see if we're on the right hardware and ROM
onWallaby:
            link.w  A6,#0
            movem.l D7-D6,-(SP)
            movea.l ROMBase,A0
            move.w  (8,A0),D7
            cmpi.w  #PlusROMVersion,D7
            beq.b   .PatchROMDetect
            cmpi.w  #UnknownROM,D7
            beq.b   .PatchROMDetect
            cmpi.w  #SEROMVersion,D7
            bne.b   .WrongMacROM
.PatchROMDetect:
            cmpi.l  #TROMCode,PtchROMBase           ; Check patch ROM for magic bytes
            beq.b   .SRAMDetect
            moveq   #0,D0                           ; Set failed result
            bra.b   .Exit
.SRAMDetect:
            move.l  OutboundDisp,D6                 ; Save start of SRAM
            move.l  #"WSIS",OutboundDisp
            cmpi.l  #'WSIS',OutboundDisp
            beq.b   .WallabySuccess
            moveq   #0,D0                           ; Set failed result
            bra.b   .Exit
.WallabySuccess:
            move.l  D6,OutboundDisp                 ; Restore start of SRAM
            moveq   #1,D0                           ; Set success result
            bra.b   .Exit
.WrongMacROM:
            moveq   #0,D0                           ; Set failed result
.Exit:
            movem.l (-8,A6),D6-D7
            unlk    A6
            rts
            dc.b    $89
            dc.b    'onWallaby'
            dc.b    $0,$0