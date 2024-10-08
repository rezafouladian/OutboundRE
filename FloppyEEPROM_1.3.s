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
PatchLocGetPRAM:
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
PatchLocPlusCPU:
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
            dc.b    "1.3b2"                         ; Patch ROM version string
            dc.b    0,0,1,3
; Called once every instruction while trace bit is set.
; Checks the current Program Counter to see if it an address to patch.
PatchException:
            move.w  D0,-(SP)                        ; Save D0
            move.w  ExpectedPC,D0                   ; Get address of next patch location
            cmp.w   ($6,SP),D0                      ; Compare against Program Counter from exception
            beq.b   .PatchROM                       ; If it matches this a location to patch
.ExitException:
            move.w  (SP)+,D0                        ; Restore D0
            rte                                     ; Go back to ROM code
.PatchROM:
            cmpi.w  #$40,($4,SP)                    ; Ensure we are in the right ROM space ($40xxxx)
            bne.b   .ExitException                  ; Just incase we got a match in code not in main system ROM
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
            rts                                     ; Go to the address we loaded onto the stack earlier
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
            move.l  SP,OutboundGlobals
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
            move.l  #$FE000,OutboundGlobals
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
            beq.w   .L7
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
            movea.l OutboundGlobals,SP
            move.l  #PatchException,TraceVector
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
            move.l  #PatchException,TraceVector
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
            move.l  #PatchException,TraceVector
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
            jsr     $4004CE                         ; InitSCSI
.L2:
            jsr     $4003EE                         ; WhichCPU
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
; Patch ROM entry point reached if the system is restarting
WarmEntry:
            move.l  #PatchException,TraceVector
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
            addq.w  #4,(4,SP)                       ; Add 4 to the Program Counter
            movem.l A1-A0/D0,-(SP)                  ; Save registers
            movea.l #PtchROMBase,A0
            movea.w #$1400,A1                       ; HeapStart for Plus is $1400
            btst.b  #IsMacSEROM,OutboundCfg         ; Is this an SE ROM
            beq.b   .L1                             ; No, must be a Plus ROM
            movea.w #$1600,A1                       ; HeapStart for SE is $1600
.L1:
; Copy the patch ROM into RAM
            move.l  A1,PtchTblBase
            move.l  #16384/4-1,D0                   ; 16KB total to copy
.CopyLoop:
            move.l  (A0)+,(A1)+
            dbf     D0,.CopyLoop
            move.l  A1,OutboundGlobals
            movea.l PtchTblBase,A0
            adda.w  #PatchException-PtchROMBase,A0
            move.l  A0,TraceVector                  ; Point to the trace exception in RAM now
            move.l  #$4940,D0
.L3:
            clr.b   (A1)+
            subq.l  #1,D0                           ; Decrement loop counter
            bne.b   .L3
            movem.l (SP)+,D0/A0-A1                  ; Restore registers
            rte
; Patch the WhichCPU instruction on the Plus ROM, possibly to
; deal with the illegal instruction exception that is generated
PatchWhichCPUPlus:
            pea     PatchExceptionUnknown
            move.l  (SP)+,Lev1AutoVector
            move.w  #$59A,(4,SP)                    ; Skip ahead
            bset.b  #CfgBit5,OutboundCfg
            rte
PatchGetPRAM:
            bset.b  #CfgBit5,OutboundCfg
            btst.b  #CfgBit3,OutboundCfg
            bne.b   .L1
            bsr.w   ReplaceTraps
.L1:
            move.l  A0,-(SP)
            movea.l OutboundGlobals,A0
            adda.w  #$D2,A0
            move.l  LineAVector,-(A0)
            move.w  #$4EF9,-(A0)
            move.l  #$7C8000,-(A0)
            move.l  A0,LineAVector
            movea.l (SP)+,A0
            rte
PatchSetupSysAppZone:
            lea     SysAppZonePatch,A0
            rte
PatchInitADB:
            bset.b  #2,($15D,A3)
            lea     ($C0,A3),A0
            move.l  A0,($13C,A3)
            move.l  A0,($144,A3)
            move.l  A0,($148,A3)
            lea     ($130,A3),A0
            move.l  A0,($140,A3)
            lea     ($164,A3),A0
            move.l  A0,($130,A3)
            move.l  #$40339C,($134,A3)
            move.w  #$3366,(4,SP)
            rte
PatchGNEFilter:
            lea     GNEFilterPatch,A0
            rte
GNEFilterPatch:
            dc.w    $0,$9D40,$3,$2740,$20,$0,$0
SysAppZonePatch:
            dc.w    $0,$9F40,$3,$2940,$40,$0,$0
PatchPlusInitIOMgr:
            moveq #$40,D0
            rte
PatchInitIOMgr:
            btst.b  #IsMacSEROM,OutboundCfg
            bne.b   .L3
            bset.b  #(1<<hwCbClock)>>8,HWCfgFlags
            btst.b  #CfgBit3,OutboundCfg
            beq.b   .L1
            pea     PatchInitIOMgr3
            move.l  (SP)+,Lvl1DT+8
            bra.b   .L3
.L1:
            cmpi.b  #$67,$407D44                    ; Check for v1 Mac Plus ROM
            bne.b   .L2
            move.b  #(1<<hwCbSCSI)>>8,HWCfgFlags
.L2:
            bsr.w   PatchInitIOMgr4
.L3:
            btst.b  #CfgBit3,OutboundCfg
            bne.b   .L5
            addi.w  #$A,(4,SP)
            movem.l A1-A0/D2-D0,-(SP)
            movea.l LineAVector,A0
            move.l  A0,-(SP)
            move.l  (6,A0),LineAVector
            move.l  #$310,D0
            btst.b  #IsMacSEROM,OutboundCfg
            beq.b   .L4
            addi.l  #$34,D0
.L4:
            _NewPtrSysClear
            move.l  A0,SonyVars
            lea     ($118,A0),A0
            _InsTime
            move.l  (SP)+,LineAVector
            movem.l (SP)+,D0-D2/A0-A1
.L5:
            btst.b  #CfgBit2,OutboundCfg
            bne.b   .Exit
            bset.b  #(1<<hwCbSCSI)>>8,HWCfgFlags
            pea     PatchBootRetry2\.PatchInitIOMgr5
            move.l  (SP)+,$E54
.Exit:
            ori     #1<<TraceBit,SR
            rte
PatchBootRetry2:
            addq.w  #4,(4,SP)
            move.w  #$A000,(SP)
            btst.b  #CfgBit3,OutboundCfg
            beq.b   .Exit
            addq.w  #4,(4,SP)
            move    #1<<Supervisor,SR
            jsr     $403306
            move.w  $400786-BaseOfROM,ExpectedPC
            move.w  PatchInitIOMgr,PatchOffset
            addq.l  #4,PatchTblPtr
.Exit:
            rte
.PatchInitIOMgr5:
            movea.l (SP)+,A0
            move.w  (SP)+,D0
            moveq   #0,D1
            cmpi.w  #0,D0
            beq.b   .L1
            cmpi.w  #1,D0
            beq.b   .L1
            cmpi.w  #10,D0
            beq.b   .L1
            moveq   #2,D1
            cmpi.w  #2,D0
            beq.b   .L1
            moveq   #6,D1
            cmpi.w  #3,D0
            beq.b   .L1
            moveq   #12,D1
            cmpi.w  #9,D0
            beq.b   .L1
            moveq   #4,D1
            cmpi.w  #4,D0
            beq.b   .L1
            cmpi.w  #5,D0
            beq.b   .L1
            cmpi.w  #6,D0
            beq.b   .L1
            cmpi.w  #8,D0
            beq.b   .L1
            moveq   #0,D1
            adda.l  D1,SP
            moveq   #0,D0
            move.w  D0,(SP)
            jmp     (A0)
.L1:
            adda.l  D1,SP
            moveq   #2,D0
            move.w  D0,(SP)
            jmp     (A0)
PatchInitIOMgr3:
            btst.b  #4,($1600,A1)
            bne.b   .L1
            jmp     $40260E
.L1:
            move.b  #4,($1A00,A1)
            move.w  #$190,D0
            jmp     $4025FE
PatchInitIOMgr2:
            andi.w  #$7FFF,(SP)
            movem.l A1-A0/D2-D0,-(SP)
            movea.l LineAVector,A0
            move.l  A0,-(SP)
            move.l  ($6,A0),LineAVector             ; Skip the first instruction
            movea.l #$CC0010,A0
            lea     (-$8,A0),A1
            moveq   #-128,D0
            moveq   #0,D1
            move.b  D0,(A0)
            move.b  (A1),D2
            move.b  D1,(A0)
            move.b  (A1),D2
            move.b  D1,(A1)
            move.b  #$14,(A0)
            movea.l #$C80018,A0
            moveq   #7,D0
            btst.b  D0,(A0)
            bne.b   .L2
            moveq   #30,D1
.L1:
            subq.l  #1,D1
            beq.b   .L2
            btst.b  D0,(A0)
            beq.b   .L1
            bset.b  #Cfg2Bit0,OutboundCfg2
            bsr.w   Super_Install
.L2:
            bsr.w   RamDisk_Install
            move.l  #10000000,D0                    ; Set loop counter
.WaitLoop:
            cmpi.b  #-$80,$C00005
            bne.b   .L3
            subq.l  #1,D0                           ; Decrement loop counter
            bne.b   .WaitLoop
.L3:
            moveq   #10,D0                          ; Set loop counter
.L4:
            moveq   #-$13,D1
            and.b   $C00005,D1
            cmpi.b  #$40,D1
            beq.b   .L5
            subq.l  #1,D0
            bne.b   .L4
            bra.b   .L6
.L5:
            bset.b  #Cfg2Bit1,OutboundCfg2
.L6:
            move.l  (SP)+,LineAVector
            lea     VBase,A0
            move.b  #1<<ifT2,(vIFR,A0)
            btst.b  #IsMacSEROM,OutboundCfg
            beq.b   .PlusRestoreVector
            btst.b  #CfgBit3,OutboundCfg
            bne.b   .SERestoreVector
            ori.w   #1<<15,(4,SP)
            bra.b   .Exit
.SERestoreVector:
            move.l  $40137A,TraceVector             ; Restore original Mac SE trace vector
.L8:
            bsr.b   InstallLineAPatch
.Exit:
            movem.l (SP)+,D0-D2/A0-A1
            rte
.PlusRestoreVector:
            move.l  $401136,TraceVector             ; Restore original Mac Plus trace vector
            bra.b   .L8
InstallLineAPatch:
            movea.l LineAVector,A0
            movea.l ($6,A0),A0
            move.l  A0,$707D14
            lea     PatchLineA,A0
            move.l  A0,LineAVector
            rts
PatchDrawBeepScreen:
            andi.w  #$7FFF,(SP)
            movem.l A6-A0/D7-D1,-(SP)
            bsr.b   InstallLineAPatch
            bsr.w   PatchInitIOMgr4
            bsr.w   PatchInitIOMgr8
            move.l  #$40137A,TraceVector
            move.w  HWCfgFlags,D0
            bclr.l  #(1<<hwCbMMU|1<<hwCbAUX)>>8,D0
            move.w  D0,HWCfgFlags
            lea     New_CountADBs,A0
            move.w  #$77,D0
            _SetOSTrapAddress
            lea     New_GetIndADB,A0
            move.w  #$78,D0
            _SetOSTrapAddress
            movem.l (SP)+,D0-D7/A0-A6
            rte
New_GetIndADB:
            moveq   #-1,D0
            rts
New_CountADBs:
            moveq   #0,D0
            rts
PatchLineA_L23:
            lea     PatchLineA_Unknown1,A0
            move.l  A0,($3E,SP)
            movem.l (SP)+,D0-D7/A0-A6               ; Restore registers
            rte
PatchLineA_Unknown1:
            move.l  #$40000,D0
.L1:
            subq.l  #1,D0
            bne.b   .L1
            _HideCursor
            move.l  Ticks,D0
.L2:
            cmp.l   Ticks,D0
            beq.b   .L2
            movea.l #$400FA2,A4
            movea.l #OutboundDisp+$3136,A2
            btst.b  #CfgBit3,OutboundCfg
            beq.b   .L3
            movea.l #ScreenLow+$245E,A2
.L3:
            lea     .L4,A6
            btst.b  #CfgBit3,OutboundCfg
            beq.w   PatchLineA_Unknown2
            jmp     $400EC4                         ; Plus ROM PutIcon?
.L4:
            tst.w   D7
            beq.b   .L6
            movea.l #OutboundDisp+$35E7,A2
            btst.b  #CfgBit3,OutboundCfg
            beq.b   .L5
            movea.l #ScreenLow+$281F,A2
.L5:
            movea.l D7,A4
            moveq   #14,D2
            lea     .L6,A6
            btst.b  #CfgBit3,OutboundCfg
            beq.w   PatchLineA_Unknown3
            jmp     $400F30
.L6:
            _ShowCursor
            cmpi.l  #$4006DE,(SP)
            bne.b   .Exit
            subq.l  #4,SP
            movea.l SP,A0
            move.l  #$40078,D0                      ; Read the default startup device from PRAM
            _ReadXPRam

.Exit:

PatchLineA:
            movem.l A6-A0/D7-D0,-(SP)
            movea.l ($3E,SP),A0
            btst.b  #IsMacSEROM,OutboundCfg
            bne.b   .L5
            cmpa.l  #$400B9A,A0
            beq.w   .L21
            cmpa.l  #$40073E,A0
            beq.w   .L22
            cmpa.l  #$4007CE,A0
            beq.w   PatchLineA_L23
            btst.b  #CfgBit3,OutboundCfg
            bne.b   .L3
            cmpi.w  #__InitGraf,(A0)
            bne.b   .L1
            bsr.w   PatchInitIOMgr8
            bra.w   .L14
.L1:
            cmpa.l  #$401382,A0
            bne.b   .L2
            bra.b   .L6
.L2:
            cmpa.l  #$401328,A0
            bne.b   .L3
            bra.b   .L8
.L3:
            cmpa.l  #$4012AC,A0
            bne.b   .L4
            bra.b   .L10
.L4:
            cmpa.l  #$400A30,A0
            bne.w   .L14
            bra.w   .L12
.L5:
            cmpa.l  #$400D08,A0
            beq.w   .L24
            cmpa.l  #$400A6A,A0
            beq.w   .L21
            cmpa.l  #$400E72,A0
            beq.w   .L25
            btst.b  #CfgBit3,OutboundCfg
            bne.b   .L9
            cmpa.l  #$400F3A,A0
            beq.w   .L26
            cmpa.l  #$401592,A0
            bne.b   .L7
.L6:
            movea.l ($20,SP),A0
            move.l  #$600060,(A0)
            move.l  #$DE0220,($4,A0)
            movea.l ($3E,SP),A0
            bra.b   .L14
.L7:
            cmpa.l  #$401538,A0
            bne.b   .L9
.L8:
            addi.l  #$200040,($42,SP)
            bra.b   L14
.L9:
            cmpa.l  #$4014BC,A0
            bne.b   .L11
.L10:
            bclr.b  #CfgBit5,OutboundCfg
            btst.b  #CfgBit3,OutboundCfg
            bne.b   .L14
            movea.l ($20,SP),A0
            addi.l  #$200040,(A0)
            addi.l  #$200040,($4,A0)
            movea.l ($3E,SP),A0
            bra.b   .L14
.L11:
            cmpa.l  #$4008EE,A0
            bne.b   .L14
.L12:
            bclr.b  #CfgBit5,OutboundCfg
            btst.b  #CfgBit3,OutboundCfg
            bne.b   .L14
            move.w  #$40,($5C,SP)
            pea     .L13
            move.l  (SP)+,($48,SP)
            bra.b   .L14
.L13:
            dc.l    $1D0040
            dc.l    $1730240
.L14:
            btst.b  #CfgBit3,OutboundCfg
            bne.b   .L16
            cmpi.w  #$A647,(A0)
            bne.b   .L15
            cmpi.w  #$15,D0
            bne.b   .L15
            movem.l (SP)+,D0-D7/A0-A6
            addq.l  #$2,($2,SP)
            rte
.L15:
            btst.b  #CfgBit2,OutboundCfg
            beq.b   .L17
.L16:
            cmpi.w  #$A9A5,(A0)
            bne.w   .L20
            move.l  $707D14,LineAVector
            bra.b   .L20
.L17:
            cmpi.w  #$A9A0,(A0)
            bne.b   .L18
            cmpi.l  #"INIT",($44,SP)
            bne.b   .L18
            move.l  $707D14,LineAVector
            bclr.b  #hwCbSCSI-7,HWCfgFlags
            bra.b   .L20
.L18:
            cmpi.w  #$A02E,(A0)
            bne.b   .L20
            move.l  ($42,SP),D0
            andi.l  #$3FFFFE,D0
            movea.l D0,A0
            cmpi.l  #$7262D3C2,(A0)+
            bne.b   .L20
            cmpi.l  #$21C90028,(A0)+
            bne.b   .L20
            btst.b  #IsMacSEROM,OutboundCfg
            beq.b   .L19
            btst.b  #CfgBit3,OutboundCfg
            bne.b   .L19
            move.l  ADBBase,D0
            beq.b   .L19
            movea.l D0,A0
            bset.b  #2,($14D,A0)
.L19:
            movem.l (SP)+,D0-D7/A0-A6
            _BlockMove
            addq.l  #2,($2,SP)
            move.l  A1,$707D14
            movea.l LineAVector,A1
            rte
.L20:
            movem.l (SP)+,D0-D7/A0-A6
            move.l  $707D14,-(SP)
            rts
.L21:
            lea     .L22,A0
            move.l  A0,($3E,SP)
            movem.l (SP)+,D0-D7/A0-A6
            rte
.L22:
            _Control
            beq.b   .L23
            move.w  BootMask,D0
            bclr.l  D3,D0
            move.w  D0,BootMask
.L23:
            movea.l PtchTblBase,A0
            adda.w  #$92,A0
            move.l  A0,TraceVector
            btst.b  #IsMacSEROM,OutboundCfg
            bne.b   .L24
            lea     PatchLocPlusCPU,A6
            bra.b   .L25
.L24:
            lea     PatchLocGetPRAM,A6
.L25:
            move.w  (A6)+,ExpectedPC
            move.w  (A6)+,PatchOffset
            move.l  A6,PatchTblPtr
            move    #1<<TraceBit|1<<Supervisor|1<<InterruptBit2|1<<InterruptBit1|1<<InterruptBit0,SR
            btst.b  #IsMacSEROM,OutboundCfg
            bne.b   .MacSEExit
            jmp     $4003AC
.MacSEExit:
            jmp     $4000D6
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
            move.l  D0,D1                           ; D1 = RAM location
            move.w  D0,D2                           ; D2 = step number
            swap    D1
            lsl.l   #3,D1                           ; Left shift to form memory address
.WriteValues:
            subi.l  #512*1024,D1                    ; Test on 512KB boundaries
            move.w  D2,(A0,D1)                      ; Write step number to RAM
            subq.w  #1,D2                           ; Decrement step counter
            bne.b   .WriteValues                    ; Loop until complete
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
PatchExceptionUnknown:
            movem.l A3-A0/D3-D0,-(SP)
            jmp     $401A60
PatchInitIOMgr4_Data:
            dc.b    $36
            dc.b    $78
            dc.b    $6
            dc.b    $20
            dc.b    $6
            dc.b    $1E
            dc.b    $48
            dc.b    $8E
            dc.b    $6
            dc.b    $0
PatchInitIOMgr4_Other:
            moveq   #$50,D0
            andi.w  #$260,-(A0)
            bclr.l  D0,D0
            bclr.b  D0,(A0)
            moveq   #$50,D5
            andi.w  #$190,(-$80,A0,D0*2)
PatchInitIOMgr4:
            movem.l A6-A0/D7-D0,-(SP)
            move.b  #1,CrsrBusy
            movea.l JCrsrObscure,A1
            move.w  #$33,D0
            _GetToolBoxTrapAddress
            btst.b  #IsMacSEROM,OutboundCfg
            bne.b   .L1
            movea.l #$402000,A0
.L1:
            move.l  A0,D0
            sub.l   A1,D0
            move.l  D0,D1
            movea.l A1,A2
            _NewPtrSys
            exg     A0,A1
            move.l  D1,D0
            _BlockMove
            suba.l  A1,A0
            move.l  A0,D0
            movea.l #$800,A1
            moveq   #7,D1
.L2:
            sub.l   D0,(A1)+
            dbf     D1,.L2
            btst.b  #IsMacSEROM,OutboundCfg
            bne.b   .L3
            sub.l   D0,JCrsrTask
.L3:
            lea     PatchInitIOMgr4_Data,A0
            lea     PatchInitIOMgr4_Other,A1
            suba.l  D0,A2
            clr.w   D0
.L4:
            move.b  (A0)+,D0
            beq.b   .L5
            adda.w  D0,A2
            move.w  (A1)+,(A2)
            bra.b   .L4

ReplaceTraps:
            movem.l A1-A0/D2-D0,-(SP)
            lea     New_InitUtil,A0
            move.w  #$3F,D0
            _SetTrapAddress
            lea     New_WriteParam,A0
            move.w  #$38,D0
            _SetTrapAddress

New_InitUtil:
New_WriteParam:
New_SetDateTime:
New_ReadDateTime:
New_SetDateTime2:
New_ReadDateTime2:
New_ReadXPRam:
New_WriteXPRam:
; I'm fairly certain this is the step that draws the Wallaby logo on the Outbound's
; screen, but I'm not entirely sure.
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
            incbin 'WallabyBitmap.bin'
Shared_Unknown1:
            movem.l D3-D0,-(SP)
            move.w  #$1F,D3
.L1:
            move.l  (A1)+,D0
            moveq   #-1,D1
            move.w  #$1F,D2
.L2:
            btst.l  D2,D0
            bne.b   .L4
            bclr.l  D2,D1
            dbf     D2,.L2
.L3:
            move.l  D1,($80,A0)
            move.l  D0,(A0)+
            dbf     D3,.L1
            movem.l (SP)+,D0-D3
            adda.w  #$80,A0
            rts
.L4:
            clr.w   D2
.L5:
            btst.l  D2,D0
            bne.b   .L3
            bclr.l  D2,D1
            addq.w  #1,D2
            bra.b   .L5
Shared_Unknown2:
            link.w  A6,#-$32
            movem.l A3-A1/D4-D1,-(SP)
            lea     DrvQHdr,A2
            movea.l ($6,A2),A3
            movea.l ($2,A2),A1
            moveq   #0,D0
            move.w  ($16,A6),D0
            move.w  ($A,A6),D3
.L1:
            cmp.w   ($8,A1),D3
            beq.b   .L2
            cmp.w   ($6,A1),D3
            beq.b   .L3
            cmpa.l  A1,A3
            beq.b   .L4
            movea.l (A1),A1
            bra.b   .L1
.L2:
            move.w  ($6,A1),D0
            bra.b   .L7
.L3:
            movea.l ($2,A2),A1
            addq.w  #1,D0
            bra.b   .L1
.L4:
            move.w  D0,D3
            movea.l ($10,A6),A0
            cmpa.w  #0,A0
            bne.b   .L6
            moveq   #$14,D0
            _NewPtrSys
            beq.b   .L5
            bra.b   .L7
.L5:
            move.l  #$80000,(A0)+
.L6:
            move.w  #1,($4,A0)
            clr.w   ($A,A0)
            move.w  ($C,A6),($E,A0)
            move.w  ($E,A6),($C,A0)
            move.w  D3,D0
            swap    D0
            _AddDrive
            move.w  D3,D0
.L7:
            movem.l (SP)+,D1-D4/A1-A3
            unlk    A6
            rts
Super_Unknown27:
            move.l  D2,-(SP)
            move.l  D0,D2
            mulu.w  D1,D2
            movea.l D2,A0
            move.l  D1,D2
            swap    D2
            mulu.w  D0,D2
            swap    D0
            mulu.w  D0,D1
            add.w   D1,D2
            swap    D2
            clr.w   D2
            adda.l  D2,A0
            move.l  A0,D0
            move.l  (SP)+,D2
            rts
Super_Unknown26:
            movem.l D4-D2,-(SP)
            move.l  D1,D2
            swap    D2
            tst.w   D2
            bne.b   .L2
            move.w  D0,D3
            clr.w   D0
            swap    D0
            beq.b   .L1
            divu.w  D1,D0
            move.w  D0,D2
.L1:
            swap    D2
            move.w  D3,D0
            divu.w  D1,D0
            move.w  D0,D2
            move.l  D2,D1
            clr.w   D0
            swap    D0
            bra.b   .Exit
.L2:
            move.l  D0,D2
            clr.w   D0
            swap    D0
            swap    D2
            clr.w   D2
            move.l  D1,D3
            moveq   #0,D1
            moveq   #15,D4
.L3:
            add.l   D2,D2
            addx.l  D0,D0
            add.l   D1,D1
            cmp.l   D3,D0
            bcs.b   .L4
            sub.l   D3,D0
            addq.b  #1,D1
.L4:
            dbf     D4,.L3
.Exit:
            movem.l (SP)+,D2-D4
            rts
Super_Unknown25:
            jsr     Super_Unknown26
            move.l  D1,D0
            rts
Super_Unknown_VInstall:
            movea.l (SP)+,A1
            movea.l (SP)+,A0
            _VInstall
            move.w  D0,(SP)
            jmp     (A1)
Super_Unknown_PostEvent:
            movea.l (SP)+,A1
            move.l  (SP)+,D0
            movea.w (SP)+,A0
            _PostEvent
            move.w  D0,(SP)
            jmp     (A1)
Super_Unknown22:
            movea.l (SP)+,A1
            movea.l (SP)+,A0
            move.l  A1,-(SP)
            _OffLine
            move.w  D0,(4,SP)
            rts
Super_Unknown21:
            movea.l (SP)+,A0
            move.w  (SP)+,D0
            addq.w  #1,D0
            neg.w   D0
            lsl.w   #2,D0
            movea.l UTableBase,A1
            move.l  (A1,D0),(SP)
            jmp     (A0)
Super_Unknown_BlockMove:
            move.l  (SP)+,D1
            move.l  (SP)+,D0
            movea.l (SP)+,A1
            movea.l (SP)+,A0
            _BlockMove
            movea.l D1,A1
            move.l  A1,-(SP)
            move.w  D0,MemErr
            rts
Super_Unknown28:
            movea.l (SP)+,A1
            move.l  (SP)+,D0
            _NewPtr
            move.l  A0,(SP)
            move.l  A1,-(SP)
            move.w  D0,MemErr
            rts
RamDisk_Install:
            movem.l A6-A0/D7-D0,-(SP)
            moveq   #-50,D0
            _DrvrInstall
            lea     RAMDisk_Driver,A1
            movea.l UTableBase,A0
            movea.l ($C4,A0),A0
            movea.l (A0),A0
            move.l  A1,(A0)+
            move.w  (A1),(A0)+
            suba.w  #50,SP
            movea.l SP,A0
            clr.b   ($1B,A0)
            lea     (RAMDisk_Name,PC),A1
            move.l  A1,($12,A0)
            clr.l   ($C,A0)
            _Open
            adda.w  #50,SP
            movem.l (SP)+,D0-D7/A0-A6
            rts
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
            movem.l A1-A0/D0,-(SP)
            bsr.w   RamDisk_Unknown1
            movea.l OutboundGlobals,A2
            tst.b   ($13C,A2)
            beq.b   .Exit
            moveq   #4,D0
            move.l  D0,-(SP)

.Exit:
            movem.l (SP)+,D0/A0-A1
            move.w  #$FFE9,($10,A0)
            rts
RAMDisk_Close:
            clr.w   D0
            rts
RAMDisk_Prime:
RAMDisk_Ctl:
RAMDisk_Status:
            move.w  #-$12,D0
            cmpi.w  #8,($1A,A0)
            bne.b   .L1
            lea     ($1C,A0),A2
.L1:

Super_Unknown15:

Super_Unknown14:
            link.w  A6,#-6
            movem.l A4-A3/D7-D6,-(SP)
            lea     (-3,A6),A4
            lea     (-2,A6),A3

Super_Install:
            movem.l A6-A0/D7-D0,-(SP)
            movea.l OutboundGlobals,A1
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
            movea.l OutboundGlobals,A0
            addq.w  #1,($34,A0)
            jsr     Super_Unknown3
            ; Fall-through

Super_Unknown2:
            addq.l  #8,SP
            movea.l OutboundGlobals,A0
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
            movea.l OutboundGlobals,A0
            addq.w  #1,($34,A0)
            jsr     Super_Unknown4
            bra.b   Super_Unknown2
Super_Status:
            movem.l A6-A0/D7-D1,-(SP)
            move.l  A1,-(SP)
            move.l  A0,-(SP)
            movea.l OutboundGlobals,A0
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
            incbin  'Super_UnknownData.bin'
            dc.b    21                              ; Length byte
            dc.b    "Outbound Floppy Drive"
            dc.b    0,0
Super_UnknownData2:
            incbin  'Super_UnknownData2.bin'
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
            lea     Super_UnknownData,A1
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
            movea.l OutboundGlobals,A0
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
Super_Unknown13:
            link.w  A6,#0

            
;temp
Super_Unknown1:
Super_Unknown8:
Super_UnknownData5:
Super_Unknown11:
Super_Unknown4:
Super_Unknown3:
Super_Unknown5:







