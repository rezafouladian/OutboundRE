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
            org     $F80080
            dc.l    TROMCode
            dc.l    WarmEntry
            dc.b    5
            dc.b    '1','.','3','b','2'
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
            lea     $E7E1FE,A0
            moveq   #-$60,D0
            or.b    D0,($400,A0)
            or.b    D0,($0,A0)
            move.w  #32768/4-1,D0
            moveq   #-1,D1
WarmEntry:
PatchMinorStartTest:
PatchMinorStartTest2:
PatchLoadExceptionVectors:
InitPatch:
PatchBeep:
PatchBootRetry:
PatchGetPRAM:
PatchSetupSysAppZone:
PatchBootRetry2:
PatchInitADB:
PatchInitIOMgr:
PatchInitIOMgr2:
PatchDrawBeepScreen:
PatchPlusBoot:
PatchClkNoMem:
PatchPlusBoot2:
PatchCPUFlag:
PatchGNEFilter:
PatchPlusInitIOMgr:
