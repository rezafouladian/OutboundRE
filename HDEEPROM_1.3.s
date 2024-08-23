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
            dc.w    PatchWhichCPUPlus-PtchROMBase
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
            dc.b    5                               ; Length byte
            dc.b    "1.3b2"                         ; ROM version string
            dc.b    0,0,1,3

HDDriver_Close:
            clr.w   ($10,A0)
            clr.w   D0
            rts
HDDriver_Prime:
            movem.l A6-A0/D7-D2,-(SP)
            move.l  A1,-(SP)
            move.l  A0,-(SP)
            jsr     HDDriver_Unknown3
.L1:
            addq.l  #8,SP
            movem.l (SP)+,D2-D7/A0-A6
            move.w  D0,($10,A0)
            move.w  ($6,A0),D0
            btst.l  #9,D0
            bne.b   .Exit
            move.l  JIODone,-(SP)
.Exit:
            move.w  ($10,A0),D0
            rts
HDDriver_Ctl:
            movem.l A6-A0/D7-D2,-(SP)
            move.l  A1,-(SP)
            move.l  A0,-(SP)
            jsr     HDDriver_Unknown2
            bra.b   HDDriver_Prime\.L1
HDDriver_Status:
            movem.l A6-A0/D7-D2,-(SP)
            move.l  A1,-(SP)
            move.l  A0,-(SP)
            jsr     HDDriver_Unknown1
            bra.b   HDDriver_Prime\.L1
HDDriver:
            dc.w    $4F00
            dc.w    0
            dc.w    0
            dc.w    0
            dc.w    HDDriver_Open-HDDriver
            dc.w    HDDriver_Prime-HDDriver
            dc.w    HDDriver_Ctl-HDDriver
            dc.w    HDDriver_Status-HDDriver
            dc.w    HDDriver_Close-HDDriver
HDDriver_Name:
            dc.b    5
            dc.b    ".PTek"
HDDriver_UnknownData1:
            incbin  'HDDriver_UnknownData1.bin'
HDDriver_UnknownData2:
            incbin  'HDDriver_UnknownData2.bin'
            dc.b    18
            dc.b    "Outbound Hard Disk"
            dc.b    0,0,0
