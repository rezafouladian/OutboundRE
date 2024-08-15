            INCLUDE 'ROMTools/Hardware/Outbound125.s'
            INCLUDE 'ROMTools/Globals.s'
            INCLUDE 'ROMTools/CommonConst.s'
            INCLUDE 'ROMTools/TrapMacros.s'

            org     $F80000
            dc.l    TROMCode
            dc.l    ColdEntry
SEPatchTbl:
            dc.w    $401C68-BaseOfROM
            dc.w    PatchMinorStartTest-PtchROMBase
            dc.w    $401CC0-BaseOfROM
            dc.w    PatchMinorStartTest2-PtchROMBase
            dc.w    $401D10-BaseOfROM
            dc.w    PatchLoadExceptionVectors-PtchROMBase
            dc.w    $400050-BaseOfROM
            dc.w    InitPatch-PtchROMBase
            dc.w    $4029F8-BaseOfROM
            dc.w    PatchBeep-PtchROMBase
            dc.w    $4000D2-BaseOfROM
            dc.w    PatchBootRetry-PtchROMBase
            dc.w    $400358-BaseOfROM
            dc.w    PatchGetPRAM-PtchROMBase
            dc.w    $4001A0-BaseOfROM
            dc.w    PatchSetupSysAppZone-PtchROMBase
            dc.w    $4000FE-BaseOfROM
            dc.w    PatchBootRetry2-PtchROMBase
            dc.w    $40331E-BaseOfROM
            dc.w    PatchInitADB-PtchROMBase
            dc.w    $400786-BaseOfROM
            dc.w    PatchInitIOMgr-PtchROMBase
            dc.w    $400790-BaseOfROM
            dc.w    PatchInitIOMgr2-PtchROMBase
            dc.w    $4001DA-BaseOfROM
            dc.w    PatchDrawBeepScreen-PtchROMBase
PlusPatchTbl:
            dc.w    $400094-BaseOfROM
            dc.w    PatchPlusBoot-PtchROMBase
            dc.w    $4001F8-BaseOfROM
            dc.w    PatchClkNoMem-PtchROMBase
            dc.w    $4000CE-BaseOfROM
            dc.w    PatchPlusBoot2-PtchROMBase
            dc.w    $4003A8-BaseOfROM 
            dc.w    PatchBootRetry-PtchROMBase
            dc.w    $400594-BaseOfROM
            dc.w    PatchCPUFlag-PtchROMBase
            dc.w    $4005BC-BaseOfROM
            dc.w    PatchGetPRAM-PtchROMBase
            dc.w    $400972-BaseOfROM
            dc.w    PatchGNEFilter-PtchROMBase
            dc.w    $40087E-BaseOfROM
            dc.w    PatchPlusInitIOMgr-PtchROMBase
            dc.w    $400894-BaseOfROM
            dc.w    PatchInitIOMgr-PtchROMBase
            dc.w    $4008A2-BaseOfROM
            dc.w    PatchInitIOMgr2-PtchROMBase

            org     $F80080
            dc.l    TROMCode
            dc.l    WarmEntry
            dc.b    5
            dc.b    '1','.','3','b','2'             ; ROM version string
            dc.b    0,0,1,3
NewTraceVector:
            move.w  D0,-(SP)                        ; Save D0
            move.w  ExpectedPC,D0                   ; Get address of next patch location
            cmp.w   ($6,SP),D0                      ; Compare against Program Counter from exception
            beq.b   .PatchROM                       ; If it matches this a location to patch
.ExitException:
            move.w  (SP)+,D0                        ; Restore D0
            rte                                     ; Go back to ROM code
.PatchROM:
            cmpi.w  #$40,($4,SP)                    ; Ensure we are in the right ROM space ($40xxxx)
            bne.b   .ExitException
            move.w  (SP)+,D0                        ; Restore D0
            move.l  A0,(-$8,SP)                     ; Save A0
            movea.l PtchTblBase,A0                  ; Load the patch location base
            adda.w  PatchOffset,A0                  ; Add the offset to the current patch
            move.l  A0,-(SP)                        ; Put the address on the stack for RTS
            movea.l PatchTblPtr,A0
            move.w  (A0)+,ExpectedPC                ; Load the next location to patch
            move.w  (A0)+,PatchOffset               ; Load the next patch
            move.l  A0,PatchTblPtr                  ; Update position in table
            movea.l (-$4,SP),A0                     ; Restore A0
            rts
ColdEntry:
            lea     OutboundVIA,A0
            moveq   #-$60,D0
            or.b    D0,($400,A0)
            or.b    D0,($0,A0)
            move.w  #32768/4-1,D0
            moveq   #-1,D1
            movea.l #OutboundDisp+32768,A0
.ClearScreenLoop:
            move.l  D1,-(A0)
            dbf     D0,.ClearScreenLoop
            move.l  SP,$707D00
            movea.l #OutboundDisp+32768,SP
            bsr.w   DrawWallaby
            move.l  #262144,D0
.DelayLoop:
            subq.l  #1,D0
            bne.b   .DelayLoop
            move.w  #369,D0
            clr.w   D1
            movea.l #$707D1C,A0
.Loop3:
            move.w  D1,(A0)+
            dbf     D0,.Loop3
            movea.l #OutboundDisp+32768,SP
            clr.w   OutboundCfg
            cmpa.l  #$400062,A1                     ; Mac Plus return address in A1?
            bne.b   .IsSE                           ; No, must be a Mac SE
            move.l  #$FE000,$707D00
            addq.l  #4,A1                           ; Skip past setting the Status Register in the Plus ROM
            movea.l #PlusPatchTbl,A6                ; Load the Plus patch table
            bra.b   .LoadFirstPatchLocation
.IsSE:
            bset.b  #IsMacSEROM,OutboundCfg
            movea.l #$401C04,A1                     ; Set the return address (SE ROM does not do this for some reason)
            movea.l #SEPatchTbl,A6                  ; Load the SE patch table
.LoadFirstPatchLocation:
            move.w  (A6)+,ExpectedPC
            move.w  (A6)+,PatchOffset
            move.l  A6,PatchTblPtr
            move.l  #PtchROMBase,PtchTblBase
            move.w  BaseOfROM,D0
            bsr.w   RamSizing
            btst.b  #3,OutboundVIA
            beq.b   .L7
            movea.l #$580800,A0
            movep.w ($0,A0),D0
            cmpi.w  #$55AA,D0
            beq.b   .L5
            cmpi.w  #$AA55,D0
            beq.b   .L5
            bset.b  #CfgBit7,OutboundCfg
            cmpi.w  #$4BB4,D0
            beq.b   .L7
            cmpi.w  #$4558,D0
            beq.b   .L7
            bclr.b  #CfgBit7,OutboundCfg
            ori.b   #1<<CfgBit3|1<<CfgBit1,OutboundCfg
            move.l  #300000,D0
.DelayLoop2:
            subq.w  #1,D0
            bne.b   .DelayLoop2
            move.b  #1,$500009
            clr.w   SCSIBase
            moveq   #-1,D1
            move.w  #512*342/8/4-1,D0               ; Size of the Macintosh CRT
            movea.l #ScreenLow,A0
.ClearScreenLoop2:
            move.l  D1,(A0)+
            dbf     D0,.ClearScreenLoop2
            lea     SCSIBase,A0

            


PatchPlusBoot2:
PatchMinorStartTest:
PatchMinorStartTest2:
PatchLoadExceptionVectors:
InitPatch:
PatchBeep:
PatchPlusBoot:
PatchClkNoMem:
WarmEntry:
PatchBootRetry:
PatchCPUFlag:
PatchGetPRAM:
PatchSetupSysAppZone:
PatchInitADB:
PatchGNEFilter:
PatchPlusInitIOMgr:
        moveq #$40,D0
        rte
PatchInitIOMgr:
PatchBootRetry2:
PatchInitIOMgr2:
PatchDrawBeepScreen:
RamSizing:
        suba.l  A0,A0
        move.b  #1,$50000B
        clr.b   $50000D
        moveq   #4*2,D0                             ; Test 4MB
        bsr.b   RamMirrorCheck
        bne.b   .Exit
        move.b  #1,$50000D
        moveq   #2*2+1,D0                           ; Test 2.5MB
        bsr.b   RamMirrorCheck
        bne.b   .Exit
        clr.b   $50000B
        moveq   #2*2,D0                             ; Test 2MB
        bsr.b   RamMirrorCheck
        bne.b   .Exit
        clr.b   $50000D
        moveq   #1*2,D0                             ; Test 1MB
        bsr.b   RamMirrorCheck
.Exit:
        rts
RamMirrorCheck:
        move.l  D0,D1
        move.w  D0,D2
        swap    D1
        lsl.l   #3,D1
.WriteValues:
        subi.l  #512*1024,D1
        move.w  D2,(A0,D1)
        subq.w  #1,D2
        bne.b   .WriteValues
        move.l  D0,D1
        move.w  D0,D2
        swap    D1
        lsl.l   #3,D1
.CheckValues:
        subi.l  #512*1024,D1
        cmp.w   (A0,D1),D2
        bne.b   .FailExit
        subq.w  #1,D2
        bne.b   .CheckValues
        tst.w   D0
        rts
.FailExit:
        moveq   #0,D0
        rts






