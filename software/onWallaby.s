            include "../ROMTools/Globals.s"
            include "../ROMTools/CommonConst.s"
            include "../ROMTools/Hardware/Outbound125.s"
; onWallaby
; Runs a few tests to see if we're on the right hardware and ROM
onWallaby:
            link.w  A6,#0
            movem.l D6-D7,-(SP)
            movea.l ROMBase,A0
            move.w  (8,A0),D7
            cmpi.w  #PlusROMVersion,D7              ; Is this a Macintosh Plus ROM?
            beq.b   .PatchROMDetect
            cmpi.w  #UnknownROM,D7                  ; Not sure what ROM it is looking for here
            beq.b   .PatchROMDetect
            cmpi.w  #SEROMVersion,D7                ; Is this a Macintosh SE ROM?
            bne.b   .WrongMacROM
.PatchROMDetect:
            cmpi.l  #TROMCode,PtchROMBase           ; Outbound EEPROM present?
            beq.b   .SRAMDetect
            moveq   #0,D0
            bra.b   .Exit
.SRAMDetect:
            move.l  OutboundDisp,D6                 ; Save current SRAM contents in test area
            move.l  #'WSIS',OutboundDisp
            cmpi.l  #'WSIS',OutboundDisp
            beq.b   .WallabySuccess
            moveq   #0,D0
            bra.b   .Exit
.WallabySuccess:
            move.l  D6,OutboundDisp                 ; Restore SRAM
            moveq   #1,D0
            bra.b   .Exit
.WrongMacROM:
            moveq   #0,D0
.Exit:
            movem.l (-8,A6),D6-D7
            unlk    A6
            rts
            dc.b    $89
            dc.b    'onWallaby'
            ds.b    2
