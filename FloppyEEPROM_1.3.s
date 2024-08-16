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
            dc.b    5                               ; Length byte
            dc.b    "1.3b2"                        ; ROM version string
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
            clr.w   SCSI_Base
            moveq   #-1,D1
            move.w  #512*342/8/4-1,D0               ; Size of the Macintosh CRT
            movea.l #ScreenLow,A0
.ClearScreenLoop2:
            move.l  D1,(A0)+
            dbf     D0,.ClearScreenLoop2
            lea     SCSI_Base,A0
            move.b  (sICR,A0),D0
            or.b    (sCSR,A0),D0
            andi.b  #%10000000,D0
            bne.b   .L6
            move.b  #%10000000,(sICR,A0)
            move.b  (sICR,A0),D0
            and.b   (sCSR,A0),D0
            andi.b  #-$80,D0
            beq.b   .L6
.L5:
            bset.b  #CfgBit2,OutboundCfg
.L6:
            clr.b   SCSI_ICRwrite
.L7:
            movea.l $707D00,SP
            move.l  #NewTraceVector,TraceVector
            bset.b  #CfgBit5,OutboundCfg
            move    1<<TraceBit|1<<Supervisor|1<<InterruptBit2|1<<InterruptBit1|1<<InterruptBit0,SR
            jmp     (A1)
PatchPlusBoot2:
            andi.b  #$F,D2
            or.b    D2,($1E00,A5)
            move.b  #$7F,($600,A5)
            move.b  (A5),D6
            lsl.b   #4,D6
            move.b  #$7F,($1C00,A5)
            clr.b   ($1800,A5)
            moveq   #$28,D3
            lea     PatchPlusBoot3,A6
            lea     VBase,A5
            lea     $707D1C,A0
.L1:
            movea.l A0,A4
            move    SR,D5
            andi.w  #$700,D5
            bne.b   .L3
            move.l  Ticks,D0
.L2:
            cmp.l   Ticks,D0
            beq.b   .L2
            bra.b   .L5
.L3:
            moveq   #-1,D0
.L4:
            btst.b  #ifCA1,(vIFR,A5)
            dbne    D0,.L4
            move.b  #ifSR,(vIFR,A5)
.L5:
            move.w  #$D00,D0
.L6:
            dbf     D0,.L6
.L7:
            move.l  #$C006FA40,D1
.L8:
            moveq   #$13,D2
.L9:
            move.b  D1,(A0)
            addq.w  #2,A0
            cmpa.l  #OutboundDisp+32768,A0
            beq.b   .L10
            subq.w  #1,D2
            bne.b   .L9
            lsl.l   #8,D1
            bne.b   .L8
            bra.b   .L7
.L10:
            btst.b  #IsMacSEROM,OutboundCfg
            beq.b   .PlusJump
            pea     PatchPlusBoot4
            jmp     $402A42
.PlusJump:
            jmp     $4002E0
PatchPlusBoot3:
            bset.b  #7,(A5)
            andi.w  #$7FFF,(SP)
            lea     PatchPlusBoot5,A6
            jmp     $400D74
PatchPlusBoot5:
            bne.b   PatchPlusBoot5
            movea.l A3,A0
            moveq   #-1,D1
            sub.l   A3,D0
            lsr.l   #2,D0
.L1:
            move.l  D1,(A0)+
            subq.l  #1,D0
            bne.b   .L1
            lea     PatchPlusBoot6,A6
            jmp     $401036
PatchPlusBoot6:
            move.w  #$2700,(SP)
            move.l  #$400368,(2,SP)
            rte
PatchMinorStartTest:
            lea     PatchMinorStartTest3,A6
            jmp     $4026C8
PatchMinorStartTest3:
            addq.w  #4,(4,SP)
            rte
PatchMinorStartTest4:
            addq.w  #4,(4,SP)
            andi.w  #$7FFF,(SP)
            rte
PatchMinorStartTest5:
            lea     .L1,A0
            lea     .L2,A3
            move.w  #$401CEC-BaseOfROM,ExpectedPC
            move.w  PatchMinorStartTest4-PtchROMBase,PatchOffset
            rte
.L1:
            dc.w    $1820
            dc.w    $2830
            dc.w    $40FF
.L2:
            dc.l    $100000
            dc.l    $100000
            dc.l    $200000
            dc.l    $200000
            dc.l    $0
PatchMinorStartTest2:
            lea     PatchMinorStartTest6,A6
            jmp     $4026F0
PatchMinorStartTest6:
            addq.w  #8,(4,SP)
            move.l  #NewTraceVector,TraceVector
            btst.b  #CfgBit3,OutboundCfg
            beq.b   .Exit
            move.w  $402602-BaseOfROM,ExpectedPC
            move.w  PatchMinorStartTest5-PtchROMBase,PatchOffset
            addq.l  #4,PatchTblPtr
.Exit:
            rte
PatchLoadExceptionVectors:
            move.l  (A0)+,(A1)+
            dbf     D0,PatchLoadExceptionVectors
            move.l  #NewTraceVector,TraceVector
            rte
InitPatch:
            move.w  #$5C,(4,SP)
            btst.b  #CfgBit3,OutboundCfg
            bne.b   .L1
            move.b  #%11110111,VBase+vDIRB
            move.b  #%11110111,VBase+vBufB
.L1:
            btst.b  #CfgBit2,OutboundCfg
            beq.b   .L2
            jsr     $4004CE
.L2:
            jsr     $4003EE
            rte
PatchBeep:
            movea.l #$707D1C,A0
            move.l  #PatchPlusBoot2\.L1,(2,SP)
            andi.w  #$7FFF,(SP)
            rte
PatchPlusBoot4:
            bset.b  #7,OutboundVIA
            rts
PatchPlusBoot:
            btst.b  #CfgBit3,OutboundCfg
            beq.b   .L1
            andi.w  #$7FFF,(SP)
            rte
.L1:
            move.b  #%11100111,(vDIRB,A5)
            move.b  #%11100111,(vBufB,A5)
            move.w  #$9E,(4,SP)
            rte
PatchClkNoMem:
            move.w  #$252,(4,SP)
            rte
WarmEntry:
            move.l  #NewTraceVector,TraceVector
            move    1<<TraceBit|1<<Supervisor|1<<InterruptBit2|1<<InterruptBit1|1<<InterruptBit0,SR
            btst.b  #IsMacSEROM,OutboundCfg
            beq.b   .L2
            move.l  #82444605,TimeDBRA
            btst.b  #CfgBit3,OutboundCfg
            bne.b   .L1
            move.w  #518,TimeSCCDB
.L1:
            jmp     $4000CE
.L2:
            btst.b  #CfgBit3,OutboundCfg
            beq.b   .L3
            movea.l PatchTblPtr,A0
            addq.l  #4,A0
            move.w  (A0)+,ExpectedPC
            move.w  (A0)+,PatchOffset
            move.l  A0,PatchTblPtr
.L3:
            jmp     $40037E
PatchBootRetry:
            addq.w  #4,(4,SP)
            movem.l A1-A0/D0,-(SP)
            movea.l #PtchROMBase,A0
            movea.w #$1400,A1
            btst.b  #IsMacSEROM,OutboundCfg
            beq.b   .L1
            movea.w #$1600,A1
.L1:
            move.l  A1,(PtchTblBase)
            move.l  #4095,D0
.CopyLoop:
            move.l  (A0)+,(A1)
            dbf     D0,.CopyLoop
            move.l  A1,$707D00
            movea.l PtchTblBase,A0
            adda.w  #NewTraceVector-PtchROMBase,A0
            move.l  A0,TraceVector
            move.l  #$4940,D0
.L3:
            clr.w   (A1)+
            subq.l  #1,D0
            bne.b   .L3
            movem.l (SP)+,D0/A0-A1
            rte
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
            moveq   #4*2,D0                         ; Test 4MB
            bsr.b   RamMirrorCheck
            bne.b   .Exit
            move.b  #1,$50000D
            moveq   #2*2+1,D0                       ; Test 2.5MB
            bsr.b   RamMirrorCheck
            bne.b   .Exit
            clr.b   $50000B
            moveq   #2*2,D0                         ; Test 2MB
            bsr.b   RamMirrorCheck
            bne.b   .Exit
            clr.b   $50000D
            moveq   #1*2,D0                         ; Test 1MB
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
DrawWallaby:
            lea     .WallabyBitmap,A0
            movea.l #OutboundDisp+9335,A4
.L1:
            move.w  #7,D2
            clr.w   D3
            adda.w  #289,A4
.L2:
            move.b  (A0)+,D1
            add.b   D1,D3
            beq.b   .Return
.L3:
            bchg.b  D2,(A4)
            bsr.b   .ReturnCheck
            subq.b  #1,D1
            bne.b   .L3
            cmpi.b  #-1,D3
            beq.b   .L1
            move.b  (A0)+,D1
            add.b   D1,D3
.L4:
            bsr.b   .ReturnCheck
            subq.b  #1,D1
            bne.b   .L4
            bra.b   .L2
.ReturnCheck:
            dbf     D2,.Return
            move.w  #7,D2
            addq.w  #1,A4
.Return:
            rts
.WallabyBitmap:
RAMDisk_Driver:
            dc.w    $4F00
            dc.w    $0
            dc.w    $0
            dc.w    $0
            dc.w    RAMDisk_Driver-RAMDisk_Open
            dc.w    RAMDisk_Driver-RAMDisk_Prime
            dc.w    RAMDisk_Driver-RAMDisk_Ctl
            dc.w    RAMDisk_Driver-RAMDisk_Status
            dc.w    RAMDisk_Driver-RAMDisk_Close
RAMDisk_Name:
            dc.b    5
            dc.b    ".RAMd"
RAMDisk_Open:
RAMDisk_Close:
RAMDisk_Prime:
RAMDisk_Ctl:
RAMDisk_Status:
Super_Install:
            movem.l A6-A0/D7-D0,-(SP)
            movea.l $707D00,A1
            lea     ($140,A1),A0
            move.l  A0,($26,A1)
            moveq   #-5,D0
            btst.b  #CfgBit3,OutboundCfg
            beq.b   .L1
            moveq   #-49,D0
.L1:
            _DrvrInstall
            lea     Super_Driver,A1
            movea.l UTableBase,A0
            btst.b  #CfgBit3,OutboundCfg
            bne.b   .L2
            movea.l ($10,A0),A0
            bra.b   .L3
.L2:
            move.l  ($C0,A0),A0
.L3:
            movea.l (A0),A0
            move.l  A1,(A0)+
            move.w  (A1),(A0)+
            suba.w  #50,SP
            movea.l SP,A0
            clr.b   ($1B,A0)
            lea     Super_Name,A1
            move.l  A1,($12,A0)
            clr.l   ($C,A0)
            _Open
            adda.w  #50,SP
            movem.l (SP)+,D0-D7/A0-A6
            rts
Super_Open:
            movem.l A6-A0/D7-D1,-(SP)
            move.l  A0,-(SP)
            move.l  A1,-(SP)
            move.l  A0,-(SP)
            jsr     Super_Unknown5
            addq.l  #8,SP
            movea.l (SP)+,A0
            move.w  D0,($10,A0)
            movem.l (SP)+,D1-D7/A0-A6
            rts
Super_Close:
            clr.w   ($10,A0)
            clr.w   D0
            rts
Super_Prime:
            movem.l A6-A0/D7-D1,-(SP)
            move.l  A1,-(SP)
            move.l  A0,-(SP)
            movea.l $707D00,A0
            addq.w  #1,($34,A0)
            jsr     Super_Unknown3
            ; Fall-through

Super_Unknown2:
            addq.l  #8,SP
            movea.l $707D00,A0
            subq.w  #1,($34,A0)
            movem.l (SP)+,D1-D7/A0-A6
            move.w  D1,($10,A0)
            move.w  ($6,A0),D1
            btst.l  #9,D1
            bne.b   .Exit
            move.l  JIODone,-(SP)
.Exit:
            move.w  ($10,A0),D1
            rts
Super_Ctl:
            movem.l A6-A0/D7-D1,-(SP)
            move.l  A1,-(SP)
            move.l  A0,-(SP)
            movea.l $707D00,A0
            addq.w  #1,($34,A0)
            jsr     Super_Unknown4
            bra.b   Super_Unknown2
Super_Status:
            movem.l A6-A0/D7-D1,-(SP)
            move.l  A1,-(SP)
            move.l  A0,-(SP)
            movea.l $707D00,A0
            addq.w  #1,($34,A0)
            jsr     Super_Unknown1
            bra.b   Super_Unknown2
Super_Driver:
            dc.w    $4F00                           ; Flags
            dc.w    $0                              ; Number of ticks between systask calls
            dc.w    $0                              ; Even mask
            dc.w    $0                              ; Driver menu ID
            dc.w    Super_Driver-Super_Open         ; Open routine offset
            dc.w    Super_Driver-Super_Prime        ; Prime routine offset
            dc.w    Super_Driver-Super_Ctl          ; Control routine offset
            dc.w    Super_Driver-Super_Status       ; Status routine offset
            dc.w    Super_Driver-Super_Close        ; Close rotine offset
Super_Name:
            dc.b    6                               ; Length byte
            dc.b    ".Super"                        ; Driver name
            dc.b    0,0,0
Super_UnknownData:
            ;incbin
            dc.b    21                              ; Length byte
            dc.b    "Outbound Floppy Drive"
            dc.b    0,0
Super_UnknownData2:
            ;incbin

Super_Unknown6:
            movem.l A6-A0/D7-D0,-(SP)
            movea.l #$B00003,A0
            lea     .Super_UnknownData3,A1
            move.b  (A1)+,(A0)
            move.b  (A1)+,(A0)
            move.w  #50,D0
.DelayLoop:
            dbf     D0,.DelayLoop
            move.w  #5,D0
.L1:
            move.b  (A1)+,(A0)
            dbf     D0,.L1
            movea.l #$B00001,A0
            lea     .Super_UnknownData4,A1
            move.w  #11,D0
.L2:
            move.b  (A1)+,(A0)
            dbf     D0,.L2
            bset.b  #5,$E0E7FE
            bset.b  #5,$E0FFFE
            movem.l (SP)+,D0-D7/A0-A6
            rts
.Super_UnknownData3:
            dc.b    $9,$C0,$0B,$16,$5,$60,$F,$0
.Super_UnknownData4:
            dc.b    $4,$10,$3,$C0,$6,$AB,$7,$55,$5,$62,$F,$0
Super_Unknown7:
            movem.l A6-A0/D7-D0,-(SP)
            move.l  #538,D0
            _NewPtrSys
            movea.l (64,SP),A1
            move.l  A0,(A1)
            lea     Super_UnknownData,A1
            suba.l  PtchTblBase,A1
            adda.l  #PtchROMBase,A1
            jsr     Super_Unknown8
            jsr     Super_Unknown8
            move.w  #24,D0
.L1:
            move.b  (A1)+,(A0)+
            dbf     D1,.L1
            movem.l (SP)+,D0-D7/A0-A6
            rts
Super_Unknown9:
            movem.l A6-A0/D7-D0,-(SP)
            lea     Super_UnknownData5,A0
            lea     Super_UknownData,A1
            movea.l A1,A2
            move.w  #255,D0
.L1:
            move.b  #$80,(A2)+
            subq.w  #1,D0
            bne.b   .L1
            moveq   #63,D2
.L2:
            move.b  (A0,D2),D0
            move.b  D2,(A1,D0)
            dbf     D2,.L2
            move.b  #$55,($55,A1)
            movem.l (SP)+,D0-D7/A0-A6
            rts
Super_Unknown10:
            movem.l A6-A0/D7-D0,-(SP)
            movea.l $707D00,A0
            move.w  #$14,($22,A0)
            tst.w   ($34,A0)
            bne.b   .Exit
            tst.w   ($38,A0)
            bne.b   .L1
            moveq   #0,D0
            move.l  D0,-(SP)
            jsr     Super_Unknown11
            addq.l  #4,SP
            bra.b   .Exit
.L1:
            clr.w   ($38,A0)
.Exit:
            movem.l (SP)+,D0-D7/A0-A6
            rts
Super_Unknown12:
            link.w  A6,#0
            movem.l A0/D2-D1,-(SP)
            movea.l ($8,A6),A0
            move.w  ($E,A6),D0
            subq.w  #1,D0
.L1:
            move.l  #100000,D1
.L2:
            move.b  $C80018,D2
            bmi.b   .L4
            btst.l  #5,D2
            bne.b   .L3
            subq.l  #1,D1
            bne.b   .L2
.L3:
            moveq   #0,D0
            bra.b   .L5
.L4:
            btst.l  #6,D2
            bne.b   .L3
            move.b  (A0)+,$C8001A
            dbf     D0,.L1
            moveq   #1,D0
.L5:
            movem.l (SP)+,D1-D2/A0
            unlk    A6
            rts

