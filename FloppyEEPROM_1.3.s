            INCLUDE 'ROMTools/Include.s'
            INCLUDE 'ROMTools/Hardware/Outbound125.s'
            INCLUDE 'ROMTools/Globals.s'
            INCLUDE 'ROMTools/CommonConst.s'
            INCLUDE 'ROMTools/TrapMacros.s'
            INCLUDE 'ROMTools/Macros.s'
            INCLUDE 'SEROM/ROM.s'
            INCLUDE 'Plus/ROM.s'

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
            dc.w    GetPRAM\.OB_GetPRAMSEPatch-BaseOfROM
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
            btst.b  #ExpansionConn,OutboundVIA+vBufB    ; Check for something connected to the expansion port?
            beq.w   .NoExpansion
            movea.l #$580800,A0
            movep.w ($0,A0),D0                      ; Read two bytes
            cmpi.w  #$55AA,D0                       ; Check for SCSI adapter
            beq.b   .SCSIPresent
            cmpi.w  #$AA55,D0
            beq.b   .SCSIPresent
            bset.b  #ExtFloppy,OutboundCfg          ; Set external floppy connected bit
            cmpi.w  #$4BB4,D0                       ; Check for external floppy ID?
            beq.b   .NoExpansion
            cmpi.w  #$4558,D0                       ; Check for external floppy ID 'EXTD'
            beq.b   .NoExpansion
            bclr.b  #ExtFloppy,OutboundCfg          ; Clear external floppy connected bit
            ori.b   #1<<HostMac|1<<CfgBit1,OutboundCfg  ; Connection must be a host mac
            move.l  #300000,D0                    ; Set delay counter
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
; Check for SCSI
            lea     SCSIRd,A0
            move.b  (sICR,A0),D0
            or.b    (sCSR,A0),D0
            andi.b  #iRST,D0                        ; Make sure reset is not asserted
            bne.b   .NoSCSI
            move.b  #iRST,(sICR,A0)                 ; Assert reset
            move.b  (sICR,A0),D0
            and.b   (sCSR,A0),D0
            andi.b  #iRST,D0                        ; Verify reset is asserted
            beq.b   .NoSCSI
.SCSIPresent:
            bset.b  #SCSIPresent,OutboundCfg        ; Set the bit to mark SCSI present
.NoSCSI:
            clr.b   SCSIWr+sICR                     ; Clear the reset
.NoExpansion:
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
            btst.b  #HostMac,OutboundCfg
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
            btst.b  #HostMac,OutboundCfg
            bne.b   .L1
            move.b  #%11110111,VBase+vDIRB
            move.b  #%11110111,VBase+vBufB
.L1:
            btst.b  #SCSIPresent,OutboundCfg
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
            bset.b  #VIAB7,OutboundVIA+vBufB
            rts
PatchPlusBoot:
            btst.b  #HostMac,OutboundCfg
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
            btst.b  #HostMac,OutboundCfg
            bne.b   .L1
            move.w  #518,TimeSCCDB
.L1:
            jmp     $4000CE
.L2:
            btst.b  #HostMac,OutboundCfg
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
            btst.b  #HostMac,OutboundCfg
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
            btst.b  #HostMac,OutboundCfg
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
            btst.b  #HostMac,OutboundCfg
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
            btst.b  #SCSIPresent,OutboundCfg
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
            btst.b  #HostMac,OutboundCfg
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
            movea.l LineAVector,A0                  ; Get the current LineA vector
            move.l  A0,-(SP)                        ; Save it for later
            move.l  ($6,A0),LineAVector             ; Skip the first instruction
            movea.l #OutboundFlpBase+$40010,A0
            lea     (-$8,A0),A1
            moveq   #-128,D0
            moveq   #0,D1
            move.b  D0,(A0)
            move.b  (A1),D2
            move.b  D1,(A0)
            move.b  (A1),D2
            move.b  D1,(A1)
            move.b  #$14,(A0)
            movea.l #OutboundFlpBase+18,A0
            moveq   #%00000111,D0
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
            bset.b  #HDPresent,OutboundCfg2
.L6:
            move.l  (SP)+,LineAVector
            lea     VBase,A0
            move.b  #1<<ifT2,(vIFR,A0)
            btst.b  #IsMacSEROM,OutboundCfg
            beq.b   .PlusRestoreVector
            btst.b  #HostMac,OutboundCfg
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
            btst.b  #HostMac,OutboundCfg
            beq.b   .L3
            movea.l #ScreenLow+$245E,A2
.L3:
            lea     .L4,A6
            btst.b  #HostMac,OutboundCfg
            beq.w   PatchLineA_Unknown2
            jmp     $400EC4                         ; Plus ROM PutIcon?
.L4:
            tst.w   D7
            beq.b   .L6
            movea.l #OutboundDisp+$35E7,A2
            btst.b  #HostMac,OutboundCfg
            beq.b   .L5
            movea.l #ScreenLow+$281F,A2
.L5:
            movea.l D7,A4
            moveq   #14,D2
            lea     .L6,A6
            btst.b  #HostMac,OutboundCfg
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
            move.l  (SP)+,D3
            move.l  $30A,D0
            beq.b   .Exit
.L7:
            movea.l D0,A0
            cmp.w   ($8,A0),D3
            beq.b   .L8
            move.l  (A0),D0
            bne.b   .L7
            bra.b   .Exit
.L8:
            move.l  $30A,D0
.L9:
            movea.l D0,A0
            cmpi.w  #4,($6,A0)
            bge.b   .L10
            move.l  (A0),D0
            bne.b   .L9
            bra.b   .Exit
.L10:
            cmp.w   ($8,A0),D3
            beq.b   .Exit
            movea.l A0,A2
            lea     DrvQHdr,A1
            _Dequeue
            movea.l A2,A0
            lea     DrvQHdr,A1
            _Enqueue
            bra.b   .L8
.Exit:
            rts
PatchLineA_Unknown1_L22:
            move.w  BootMask,D0
            btst.l  D3,D0
            bne.b   .L1
            movea.l #$400762,A0
            clr.l   ($4,SP)
            bra.b   .L2
.L1:
            _HideCursor
            movea.l #$400740,A0
            btst.b  #HostMac,OutboundCfg
            bne.b   .L2
            lea     .L3,A0
.L2:
            move.l  A0,($3E,SP)
            movem.l (SP)+,D0-D7/A0-A6
            rte
.L3:
            movem.l A6-A5,-(SP)
            movea.l #$40074C,A5
            bra.w   PatchLineA_L24_2
PatchLineA_Unknown1_L22_L4:
            lea     PatchLineA_Unknown1_L22_L5,A0
            move.l  A0,($3E,SP)
            movem.l (SP)+,D0-D7/A0-A6
            rte
PatchLineA_Unknown1_L22_L5:
            moveq   #1,D0
.L1:
            subq.l  #1,D0
            bne.b   .L1
            _HideCursor
            move.l  Ticks,D0
.L2:
            cmp.l   Ticks,D0
            beq.b   .L2
            movea.l #$400FB2,A4
            movea.l #$703136,A2
            BSR6    PatchLineA_Unknown2
            tst.w   D7
            beq.b   .L3
            movea.l #$7035E7,A2
            movea.l D7,A4
            moveq   #$E,D2
            BSR6    PatchLineA_Unknown3
.L3:
            _ShowCursor
            movem.l (SP)+,D3-D7/A2-A6
            rts
PatchLineA_L25:
            move.w  ($6,A2),D3
            move.w  BootMask,D0
            btst.l  D3,D0
            bne.b   .L1
            movea.l #$400CBE,A0
            bra.b   .L2
.L1:
            _HideCursor
            movea.l #$400E74,A0
            btst.b  #HostMac,OutboundCfg
            bne     .L2
            lea     .L3,A0
.L2:
            move.l  A0,($3E,SP)
            movem.l (SP)+,D0-D7/A0-A6
            rte
.L3:
            movem.l A6-A5,-(SP)
            movea.l #$40125C,A0
            movea.l A6,A5
            lea     $4011F8,A4
            move.l  A0,D5
            movea.l #$703136,A2
            lea     .L4,A6
            bra.b   PatchLineA_Unknown2
.L4:
            movea.l #$703317,A2
            movea.l D5,A4
            lea     .L5,A6
            bra.b   PatchLineA_Unknown4
.L5:
            movem.l (SP)+,A5-A6
            rts
PatchLineA_L24:
            movea.l ($20,SP),A0
            clr.l   (A0)
            move.l  DrvQHdr+2,D0
            beq.b   .L2
.L1:
            movea.l D0,A1
            cmpi.w  #4,($6,A1)
            bge.b   .L2
            tst.b   (-3,A1)
            bne.b   .L3
            move.l  (A1),D0
            bne.b   .L1
.L2:
            _GetDefaultStartup
.L3:
            move.l  #$400D0A,($3E,SP)
            movem.l (SP)+,D0-D7/A0-A6
            rte
PatchLineA_L24_2:
            movea.l #$400F3E,A4
            lea     $400FD2,A0
            move.l  A0,D7
            movea.l #$703136,A2
            lea     .L1,A6
            bra.b   PatchLineA_Unknown2
.L1:
            movea.l #$703317,A2
            movea.l D7,A4
            lea     .L2,A6
            bra.b   PatchLineA_Unknown4
.L2:
            jmp     (A5)
PatchLineA_Unknown4:
            moveq   #9,D2
PatchLineA_Unknown3:
            move.b  (A4)+,(A2)+
            move.b  (A4)+,(A2)+
            adda.w  #$4E,A2
            dbf     D2,PatchLineA_Unknown3
            jmp     (A6)
PatchLineA_Unknown2:
            moveq   #$F,D3
            movea.l A2,A0
            moveq   #3,D2
.L1:
            move.w  #$100,D4
            move.b  (A4)+,D4
.L2:
            lsr.w   #1,D4
            beq.b   .L5
            bcc.b   .L3
            clr.b   (A2)+
            bra.b   .L4
.L3:
            move.b  (A4)+,(A2)+
.L4:
            dbf     D2,.L2
            adda.w  #$4C,A2
            moveq   #3,D2
            bra.b   .L2
.L5:
            dbf     D3,.L1
            movea.l A0,A1
            moveq   #$1E,D3
.L6:
            adda.w  #$50,A1
            move.l  (A0),D4
            eor.l   D4,(A1)
            movea.l A1,A0
            dbf     D3,.L6
            jmp     (A6)
PatchLineA:
            movem.l A6-A0/D7-D0,-(SP)
            movea.l ($3E,SP),A0
            btst.b  #IsMacSEROM,OutboundCfg         ; On SE ROMs?
            bne.b   .L5                             ; Jump to the right checks if yes
            cmpa.l  #$400B9A,A0                     ; _Control
            beq.w   .L21
            cmpa.l  #$40073E,A0                     ; _HideCursor
            beq.w   .L22
            cmpa.l  #$4007CE,A0                     ; _HideCursor
            beq.w   PatchLineA_L23
            btst.b  #HostMac,OutboundCfg            ; Is a host Mac connected?
            bne.b   .L3                             ; If yes
            cmpi.w  #__InitGraf,(A0)
            bne.b   .L1
            bsr.w   PatchInitIOMgr8
            bra.w   .L14
.L1:
            cmpa.l  #$401382,A0                     ; _EraseRect
            bne.b   .L2
            bra.b   .L6
.L2:
            cmpa.l  #$401328,A0                     ; _MoveTo
            bne.b   .L3
            bra.b   .L8
.L3:
            cmpa.l  #$4012AC,A0                     ; _PlotIcon
            bne.b   .L4
            bra.b   .L10
.L4:
            cmpa.l  #$400A30,A0
            bne.w   .L14
            bra.w   .L12
.L5:
            cmpa.l  #$400D08,A0                     ; _GetDefaultStartup
            beq.w   .L24
            cmpa.l  #$400A6A,A0                     ; _Control
            beq.w   .L21
            cmpa.l  #$400E72,A0                     ; _HideCursor
            beq.w   .L25
            btst.b  #HostMac,OutboundCfg            ; Is a host Mac connected?
            bne.b   .L9                             ; If yes
            cmpa.l  #$400F3A,A0                     ; _HideCursor
            beq.w   PatchLineA_Unknown1_L22_L4
            cmpa.l  #$401592,A0                     ; _EraseRect
            bne.b   .L7
.L6:
            movea.l ($20,SP),A0
            move.l  #$600060,(A0)
            move.l  #$DE0220,($4,A0)
            movea.l ($3E,SP),A0
            bra.b   .L14
.L7:
            cmpa.l  #$401538,A0                     ; _MoveTo
            bne.b   .L9
.L8:
            addi.l  #$200040,($42,SP)
            bra.b   .L14
.L9:
            cmpa.l  #$4014BC,A0                     ; _PlotIcon
            bne.b   .L11
.L10:
            bclr.b  #CfgBit5,OutboundCfg
            btst.b  #HostMac,OutboundCfg
            bne.b   .L14
            movea.l ($20,SP),A0
            addi.l  #$200040,(A0)
            addi.l  #$200040,($4,A0)
            movea.l ($3E,SP),A0
            bra.b   .L14
.L11:
            cmpa.l  #$4008EE,A0                     ; _CopyBits
            bne.b   .L14
.L12:
            bclr.b  #CfgBit5,OutboundCfg
            btst.b  #HostMac,OutboundCfg
            bne.b   .L14
            move.w  #$40,($5C,SP)
            pea     .L13
            move.l  (SP)+,($48,SP)
            bra.b   .L14
.L13:
            dc.l    $1D0040
            dc.l    $1730240
.L14:
            btst.b  #HostMac,OutboundCfg
            bne.b   .L16
            cmpi.w  #$A647,(A0)                     ; _SetToolTrapAddress
            bne.b   .L15
            cmpi.w  #$15,D0
            bne.b   .L15
            movem.l (SP)+,D0-D7/A0-A6
            addq.l  #$2,($2,SP)
            rte
.L15:
            btst.b  #SCSIPresent,OutboundCfg
            beq.b   .L17
.L16:
            cmpi.w  #$A9A5,(A0)                     ; _SizeRsrc
            bne.w   .L20
            move.l  $707D14,LineAVector
            bra.b   .L20
.L17:
            cmpi.w  #$A9A0,(A0)                     ; _GetResource
            bne.b   .L18
            cmpi.l  #"INIT",($44,SP)
            bne.b   .L18
            move.l  $707D14,LineAVector
            bclr.b  #hwCbSCSI-8,HWCfgFlags          ; No SCSI
            bra.b   .L20
.L18:
            cmpi.w  #$A02E,(A0)                     ; _BlockMove
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
            btst.b  #HostMac,OutboundCfg
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
            btst.b  #IsMacSEROM,OutboundCfg         ; On SE ROMs?
            bne.b   .L24                            ; If yes
            lea     PatchLocPlusCPU,A6
            bra.b   .L25
.L24:
            lea     PatchLocGetPRAM,A6
.L25:
            move.w  (A6)+,ExpectedPC
            move.w  (A6)+,PatchOffset
            move.l  A6,PatchTblPtr
            move    #1<<TraceBit|1<<Supervisor|1<<InterruptBit2|1<<InterruptBit1|1<<InterruptBit0,SR
            btst.b  #IsMacSEROM,OutboundCfg         ; On SE ROMs?
            bne.b   .MacSEExit                      ; If yes, use the SE exit point
            jmp     $4003AC                         ; Return to the Plus ROM
.MacSEExit:
            jmp     $4000D6                         ; Return to the SE ROM
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
            ;andi.w  #$190,(-$80,A0,D0*2)
            dc.w    $0270, $0190, $0280
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
.L5:
            lea     .L6,A0
            move.w  #$33,D0                         ; _VInstall?
            _SetToolBoxTrapAddress
            move.l  #OutboundDisp,ScrnBase
            move.w  #80,ScreenRow
            move.w  #640,$83A
            move.w  $400,$838
            clr.b   CrsrBusy
            move.l  #$707D1C,SoundBase
            movem.l (SP)+,D0-D7/A0-A6
            rts
.L6:
            movea.l (SP)+,A1
            movea.l (SP)+,A0
            move.l  ScrnBase,(A0)+
            move.w  ScreenRow,(A0)+
            clr.l   (A0)+
            move.w  #400,(A0)+
            move.w  #640,(A0)
            jmp     (A1)
ReplaceTraps:
            movem.l A1-A0/D2-D0,-(SP)
            lea     New_InitUtil,A0
            move.w  #$3F,D0
            _SetTrapAddress
            lea     New_WriteParam,A0
            move.w  #$38,D0
            _SetTrapAddress
            lea     New_ReadDateTime,A0
            move.w  #$39,D0
            _SetTrapAddress
            lea     New_SetDateTime,A0
            move.w  #$3A,D0
            _SetTrapAddress
            lea     New_ReadXPRam,A0
            move.w  #$51,D0
            _SetOSTrapAddress
            lea     New_WriteXPRam,A0
            move.w  #$52,D0
            _SetOSTrapAddress
            lea     OutboundVIA,A0
            ori.b   #7,(vDIRB,A0)
            bclr.b  #PRAMBit1,(vBufB,A0)
            bset.b  #PRAMBit2,(vBufB,A0)
            move.b  #-$4F,D0
            bsr.b   PRAMOp
            move.b  #-$4B,D0
            bsr.b   PRAMOp
            bset.b  #PRAMBit2,(vBufB,A0)
            movem.l (SP)+,D0-D2/A0-A1
            rts
; New_InitUtil
;
; This replaces the _InitUtil trap.
; Reads PRAM checking SPValid to see if PRAM data is valid,
; and initilizes it if not.
;
; Outputs:  D0  Result code
New_InitUtil:
            movem.l A1-A0/D1,-(SP)                  ; Save registers
            lea     Time,A0
            _ReadDateTime
            lea     SysParam,A0                     ; Read to PRAM global space in RAM
            move.w  #20,D1                          ; 20 bytes to read
            clr.w   D0
            bsr.w   PRAMReadOp
            cmpi.b  #$A8,SPValid                    ; Is clock data valid?
            beq.b   .L3
            lea     SysParam,A1
            btst.b  #IsMacSEROM,OutboundCfg         ; Do we have an SE ROM?
            beq.b   .PlusROM
            movea.l #$40A0F8,A0                     ; Default PRAM contents location on SE ROM
            bra.b   .L2
.PlusROM:
            movea.l #$40FCAE,A0                     ; Default PRAM contents location on Plus ROM
.L2:
            moveq   #20,D0
            _BlockMove
            lea     SysParam,A0
            move.l  MinusOne,D0
            _WriteParam
            moveq   #0,D0
            _SetDateTime
            moveq   #prInitErr,D0
            bra.b   .Exit
.L3:
            moveq   #0,D0
.Exit:
            movem.l (SP)+,D1/A0-A1                  ; Restore registers
            rts
; New_WriteParam
New_WriteParam:
            movem.l A1-A0/D1,-(SP)
            move.w  #$14,D1
            clr.w   D0
            bsr.w   PRAMWriteOp
            lea     Scratch20,A0
            move.w  #$14,D1
            clr.w   D0
            bsr.w   PRAMReadOp
            moveq   #0,D0
            movem.l (SP)+,D1/A0-A1
            rts
New_SetDateTime:
            movem.l A1-A0/D1,-(SP)
            suba.w  #14,SP
            movea.l SP,A0
            move.l  D0,Time
            _SecondsToDate
            subq.l  #8,SP
            move.w  (A0)+,D0
            subi.w  #$76C,D0
            bsr.w   New_SetDateTime2
            move.b  D0,(6,SP)
            move.w  (A0)+,D0
            bsr.w   New_SetDateTime2
            move.b  D0,(5,SP)
            move.w  (A0)+,D0
            bsr.w   New_SetDateTime2
            move.b  D0,(4,SP)
            move.w  (A0)+,D0
            bsr.w   New_SetDateTime2
            move.b  D0,(2,SP)
            move.w  (A0)+,D0
            bsr.w   New_SetDateTime2
            move.b  D0,(1,SP)
            move.w  (A0)+,D0
            bsr.w   New_SetDateTime2
            move.b  D0,(0,SP)
            move.w  (A0)+,D0
            bsr.w   New_SetDateTime2
            move.b  D0,(3,SP)
            movea.l SP,A0
            move.w  #7,D1
            move.w  #$20,D0
            bsr.w   PRAMWriteOp
            adda.w  #$16,SP
            movem.l (SP)+,D1/A0-A1
            rts
New_ReadDateTime:
            movem.l A1/D1,-(SP)
            move.l  A0,-(SP)
            suba.w  #$18,SP
            movea.l SP,A0
            move.w  #7,D1
            move.w  #$20,D0
            bsr.w   PRAMReadOp
            movea.l SP,A1
            lea     (8,SP),A0
            move.b  (6,A1),D0
            bsr.b   New_ReadDateTime2
            addi.w  #$76C,D0
            move.w  D0,(A0)+
            move.b  (5,A1),D0
            bsr.b   New_ReadDateTime2
            move.w  D0,(A0)+
            move.b  (4,A1),D0
            bsr.b   New_ReadDateTime2
            move.w  D0,(A0)+
            move.b  (2,A1),D0
            bsr.b   New_ReadDateTime2
            move.w  D0,(A0)+
            move.b  (1,A1),D0
            bsr.b   New_ReadDateTime2
            move.w  D0,(A0)+
            move.b  (0,A1),D0
            bsr.b   New_ReadDateTime2
            move.w  D0,(A0)+
            move.b  (3,A1),D0
            bsr.b   New_ReadDateTime2
            move.w  D0,(A0)+
            lea     (8,SP),A0
            _DateToSeconds
            move.l  D0,Time
            adda.w  #$18,SP
            movea.l (SP)+,A0
            move.l  D0,(A0)
            moveq   #0,D0
            movem.l (SP)+,D1/A1
            rts
New_SetDateTime2:
            movem.l D1,-(SP)
            move.w  D0,D1
            ext.l   D1
            divu.w  #$A,D1
            swap    D1
            move.w  D1,D0
            swap    D1
            ext.l   D1
            divu.w  #$A,D1
            swap    D1
            asl.w   #4,D1
            or.w    D1,D0
            movem.l (SP)+,D1
            rts
New_ReadDateTime2:
            movem.l D1,-(SP)
            move.b  D0,D1
            andi.w  #$F0,D1
            asr.w   #4,D1
            mulu.w  #$A,D1
            andi.w  #$F,D0
            add.w   D1,D0
            movem.l (SP)+,D1
            rts
; PRAMWriteOp
;
; For writing to the 68HC68 RTC RAM
; 
; Inputs    A0  Memory location to write data from
;           D0  PRAM location to write to
;           D1  Data length
PRAMWriteOp:
            move    SR,-(SP)
            ori     #$300,SR
            movea.l A0,A1
            lea     OutboundVIA,A0
            ori.b   #%111,(vDIRB,A0)
            bclr.b  #PRAMBit1,(vBufB,A0)
            bset.b  #PRAMBit2,(vBufB,A0)
            ori.b   #$FF80,D0                       ; Write addresses start at $80
            bsr.b   PRAMOp
            bra.b   .L2
.L1:
            move.b  (A1)+,D0
            bsr.b   PRAMOp
.L2:
            dbf     D1,.L1
            bset.b  #PRAMBit2,(vBufB,A0)
            move    (SP)+,SR
            rts
; PRAMReadOp
;
; For reading from the 68HC68 RTC RAM
;
; Inputs    A0  Memory location to save read data to
;           D0  PRAM location to read from
;           D1  Data length
PRAMReadOp:
            move    SR,-(SP)
            ori     #$300,SR
            movea.l A0,A1
            lea     OutboundVIA,A0
            ori.b   #%111,(vDIRB,A0)
            bclr.b  #PRAMBit1,(vBufB,A0)
            bset.b  #PRAMBit2,(vBufB,A0)
            andi.b  #$3F,D0
            bsr.b   PRAMOp
            bclr.b  #VIAB0,(vBufB,A0)
            bra.b   .L2
.L1:
            bsr.b   PRAMReadOp2
            move.b  D0,(A1)+
.L2:
            dbf     D1,.L1
            bset.b  #PRAMBit2,(vBufB,A0)
            move    (SP)+,SR
            rts
; PRAMOp
;
; Inputs:   A0  Outbound VIA base address
;           D0  ?
PRAMOp:
            movem.l D2-D0,-(SP)
            moveq   #7,D2
            andi.b  #$F8,(vBufB,A0)
.L1:
            asl.b   #1,D0
            bcc.b   .L2
            bset.b  #VIAB0,(vBufB,A0)
            bra.b   .L3
.L2:
            bclr.b  #VIAB0,(vBufB,A0)
.L3:
            bset.b  #PRAMBit1,(vBufB,A0)
            bclr.b  #PRAMBit1,(vBufB,A0)
            dbf     D2,.L1
            movem.l (SP)+,D0-D2
            rts
; PRAMReadOp2
;
; Inputs    A0  Outbound VIA base address
;           D0
;
; Outputs   D0
PRAMReadOp2:
            movem.l D3-D1,-(SP)
            moveq   #7,D2
            andi.b  #$F8,(vBufB,A0)
.L1:
            asl.b   #1,D0
            bset.b  #PRAMBit1,(vBufB,A0)
            move.b  (vBufB,A0),D3
            andi.b  #1,D3
            or.b    D3,D0
            bclr.b  #PRAMBit1,(vBufB,A0)
            dbf     D2,.L1
            movem.l (SP)+,D1-D3
            rts
; New_ReadXPRam
;
; This replaces the _ReadXPRam trap.
; Converts Macintosh PRAM addresses to locations in the 32 byte
; range of the 68HC68.
;
; Inputs    A0  ?
;           D0  Location and data length
New_ReadXPRam:
            movem.l A2-A0/D2-D0,-(SP)
            swap    D0
            move.w  D0,D1
            swap    D0
            cmpi.w  #$7C,D0                         ; Sound
            beq.b   .SoundAddr
            cmpi.w  #$08,D0
            beq.b   .L3
            cmpi.w  #$78,D0                         ; Default boot device
            beq.b   .BootDevAddr
            cmpi.w  #$E0,D0
            beq.b   .L7
            subq.w  #1,D1
.L1:
            clr.b   (A0)+
            dbf     D1,.L1
.Exit:
            movem.l (SP)+,D0-D2/A0-A2
            rts
.L3:
            move.w  #$10,D0
            move.w  #1,D1
            bra.b   .DoRead
.SoundAddr:
            move.w  #$14,D0
            bra.b   .DoRead
.BootDevAddr:
            move.w  #$16,D0
            bra.b   .DoRead
.L7:
            move.w  #$1A,D0
.DoRead:
            bsr.w   PRAMReadOp
            bra.b   .Exit
; New_WriteXPRam
;
; This replaces the _WriteXPRam trap.
; Converts Macintosh PRAM addresses to locations in the 32 byte
; range of the 68HC68.
;
; Inputs    D0  Location and data length
New_WriteXPRam:
            movem.l A2-A0/D2-D0,-(SP)
            swap    D0
            move.w  D0,D1
            swap    D0
            cmpi.w  #$7C,D0                         ; Sound
            beq.b   .SoundAddr
            cmpi.w  #$08,D0
            beq.b   .L1
            cmpi.w  #$78,D0                         ; Default boot device
            beq.b   .BootDevAddr
            cmpi.w  #$E0,D0
            beq.b   .L4
.Exit:
            movem.l (SP)+,D0-D2/A0-A2
            rts
.L1:
            move.w  #$10,D0
            move.w  #1,D1
            bra.b   .DoWrite
.SoundAddr:
            move.w  #$14,D0
            bra.b   .DoWrite
.BootDevAddr:
            move.w  #$16,D0
            bra.b   .DoWrite
.L4:
            move.w  #$1A,D0
.DoWrite:
            bsr.w   PRAMWriteOp
            bra.b   .Exit
CommonUnknown4:
            movea.l OutboundGlobals,A1
            move.b  OutboundVIA+vSR,D1
            move.b  #$10,OutboundVIA+vIFR
            clr.b   ($6D,A1)
            move.b  ($68,A1),D0
            btst.l  #0,D0
            bne.w   CommonUnknown18
            tst.b   D1
            beq.b   .L1
            bpl.b   .L4
.L1:
            btst.l  #1,D0
            bne.b   CommonUnknown19
            bclr.b  #2,($68,A1)
            beq.b   .L2
            rts
.L2:
            move.b  D1,($6A,A1)
            bset.b  #1,($68,A1)
            move    SR,D0
            andi.w  #$700,D0
            cmpi.w  #$700,D0
            bne.b   .L5
            move.l  Ticks,($64,A1)
            move.w  #$4000,D0
.L3:
            btst.b  #2,OutboundVIA+vIFR
            bne.b   CommonUnknown4
            dbf     D0,.L3
            bra.b   CommonUnknown5
.L4:
            move.b  D1,($69,A1)
            bset.b  #0,($68,A1)
.L5:
            move.l  Ticks,($64,A1)
            rts
CommonUnknown5:
            move.w  #$FFFF,D0
.L1:
            dbf     D0,.L1
            movea.l OutboundGlobals,A1
            addq.w  #1,($A8,A1)
            tst.w   ($34,A1)
            bne.b   .L2
            move    SR,D0
            andi.w  #$700,D0
            cmpi.w  #$700,D0
            bne.b   .L3
.L2:
            bsr.w   CommonUnknown15
.L3:
            bsr.w   CommonUnknown17
            bclr.b  #0,($68,A1)
            bclr.b  #1,($68,A1)
            bchg.b  #7,OutboundDisp
            rts
CommonUnknown18:
            bsr.w   CommonUnknown14
            move.b  D1,($6B,A1)
            bclr.b  #0,($68,A1)
            clr.b   D2
            clr.b   D0
            bsr.b   CommonUnknown6
            move.b  ($69,A1),D1
            bsr.b   CommonUnknown6
            not.w   D0

CommonUnknown6:

CommonUnknown7:

CommonUnknown19:

CommonUnknown7_2:

CommonUnknown8:

PatchInitIOMgr8:

; DrawWallaby
;
; Draws the Wallaby logo on the Outbound's built in display 
; (regardless of whether a host Mac is connected or not)
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
            incbin 'bin/WallabyBitmap.bin'
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
Super_PBOffLine:
            movea.l (SP)+,A1                        ; Get return address
            movea.l (SP)+,A0                        ; Get param pointer
            move.l  A1,-(SP)                        ; Put return address back on the stack
            _OffLine
            move.w  D0,(4,SP)                       ; Save result
            rts
Super_Unknown21:
            movea.l (SP)+,A0                        ; Get return address
            move.w  (SP)+,D0                        ; Get refNum
            addq.w  #1,D0
            neg.w   D0
            lsl.w   #2,D0
            movea.l UTableBase,A1
            move.l  (A1,D0.w),(SP)
            jmp     (A0)
Super_BlockMove:
            move.l  (SP)+,D1                        ; Get return address
            move.l  (SP)+,D0                        ; Get byte count
            movea.l (SP)+,A1                        ; Get destination pointer
            movea.l (SP)+,A0                        ; Get source pointer
            _BlockMove
            movea.l D1,A1                           ; Restore return address
            move.l  A1,-(SP)                        ; Put return address back on the stack
            move.w  D0,MemErr
            rts
Super_NewPtr:
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
            dc.w    RAMDisk_Open-RAMDisk_Driver
            dc.w    RAMDisk_Prime-RAMDisk_Driver
            dc.w    RAMDisk_Ctl-RAMDisk_Driver
            dc.w    RAMDisk_Status-RAMDisk_Driver
            dc.w    RAMDisk_Close-RAMDisk_Driver
RAMDisk_Name:
            dc.b    5
            dc.b    ".RAMd"
RAMDisk_Open:
            movem.l A1-A0/D0,-(SP)
            bsr.w   RamDisk_Sizing
            movea.l OutboundGlobals,A2
            tst.b   (RAMDiskSize,A2)
            beq.b   .Exit
            moveq   #4,D0
            move.l  D0,-(SP)
            move.b  (RAMDiskSize,A2),D0
            mulu.w  #$1FF,D0
            clr.l   -(SP)
            move.l  D0,-(SP)
            move.w  ($18,A1),D0
            ext.w   D0
            move.l  D0,-(SP)
            bsr.w   Shared_Unknown2
            move.w  D0,($13A,A2)
            lea     ($10,SP),SP
            btst.b  #5,(4,A1)
            move.w  #1,($22,A1)
            move.l  #$11A,D0
            _NewPtrSys
            movea.l (8,SP),A1
            move.l  A0,($14,A1)
            lea     RAMDisk_Data1,A1
            jsr     Shared_Unknown1
            move.w  #$19,D0
.L1:
            move.b  (A1)+,(A0)+
            dbf     D0,.L1
            movem.l (SP)+,A0-A1/D0
            clr.w   ($10,A0)
            rts
.Exit:
            movem.l (SP)+,D0/A0-A1
            move.w  #$FFE9,($10,A0)
            rts
RAMDisk_Close:
            clr.w   D0
            rts
RAMDisk_Prime:
            move.l  ($10,A1),D0
            move.l  D0,D4
            moveq   #9,D2
            lsr.l   D2,D0
            move.l  ($24,A0),D1
            lsr.l   D2,D1
            movea.l ($20,A0),A3
            bclr.b  #5,($4,A1)
            bsr.b   RamDisk_Unknown10
            add.l   ($24,A0),D4
            move.l  D4,($10,A1)
            move.l  ($24,A0),($28,A0)
            btst.b  #1,(6,A0)
            bne.b   .Exit
            move.l  (JIODone),-(SP)
.Exit:
            move.l  D7,D0
            rts
RamDisk_Unknown10:
            link.w  A6,#-$14
            movem.l A6-A0/D6-D0,-(SP)
            moveq   #0,D7
            clr.b   (-2,A6)
            move.w  (6,A0),D2
            andi.w  #$F,D2
            cmpi.w  #$2,D2
            beq.b   .L1
            bset.b  #1,(-2,A6)
            bra.b   .L2
.L1:
            btst.b  #6,($2D,A0)
            bne.b   .L2
            bset.b  #0,(-2,A6)
.L2:
            movea.l OutboundGlobals,A2
            adda.w  #$FA,A2
            move.w  D0,(-4,A6)
            move.w  D1,(-6,A6)
            move.l  A3,(-$E,A6)
            movea.l A3,A0
            move.w  D0,D3
            ext.l   D3
            divs.w  #$1FF,D3
            swap    D3
            move.l  D3,(-$A,A6)
            swap    D3
            ext.l   D3
            clr.w   D0
            clr.w   D1
            clr.w   D2
.L3:
            move.w  #$F,D4
            and.b   (A2,D0.w),D4
            beq.b   .L4
            add.w   D4,D1
            cmp.w   D3,D1
            bhi.b   .L5
            move.w  D1,D2
.L4:
            addq.w  #1,D0
            cmpi.w  #$10,D0
            bne.b   .L3
            bra.w   .ErrorExit
.L5:
            sub.w   D2,D3
            move.w  D3,D1
            move.b  (A2,D0.w),D2
            lsr.b   #4,D2
            move.b  #3,D3
            and.w   D2,D3
            move.b  (.L6,PC,D3.w),D4
            bra.b   .L7
.L6:
            dc.b    0
            dc.b    1
            dc.b    1
            dc.b    2
.L7:
            sub.w   D4,D1
            blt.b   .L8
            bset.b  #4,(-2,A6)
            lsr.b   #2,D2
            bra.b   .L9
.L8:
            add.w   D4,D1
.L9:
            andi.w  #3,D2
            cmpi.w  #3,D2
            bne.b   .L10
            tst.w   D1
            beq.b   .L10
            addi.w  #$1FF,(-$A,A6)
.L10:
            move.w  D0,(-$10,A6)
            bsr.w   RamDiskUnknown2
            movea.l #RAMDiskBase,A1
            clr.w   D2
            move.b  (A2,D0.w),D2
            lsr.b   #4,D2
            btst.b  #4,(-2,A6)
            beq.b   .L11
            lsr.b   #2,D2
            adda.l  #$80000,A1
.L11:
            clr.w   D3
            andi.b  #3,D2
            beq.b   .L18
            move.b  (.L6,PC,D2.w),D3
            add.w   D3,(-$A,A6)
            bclr.b  #2,(-2,A6)
            move.w  #$200,D3
            cmpi.b  #3,D2
            bne.b   .L12
            bset.b  #2,(-2,A6)
            move.w  #$400,D3
            bra.b   .L13
.L12:
            cmpi.w  #1,D2
            beq.b   .L13
            addq.w  #1,A1
.L13:
            move.w  (-$A,A6),D6
            add.w   (-6,A6),D6
            cmp.w   D6,D3
            bhi.b   .L14
            move.w  D3,D6
            sub.w   (-$A,A6),D6
            bra.b   .L15
.L14:
            move.w  (-6,A6),D6
.L15:
            sub.w   D6,(-6,A6)
            move.w  D6,(-8,A6)
            btst.b  #2,(-2,A6)
            bne.b   .L16
            bsr.b   RamDisk_Unknown9
            bra.b   .L17
.L16:
            bsr.w   RamDisk_Unknown7
.L17:
            tst.l   D7
            bne.b   .Exit
            tst.w   (-6,A6)
            beq.b   .Exit
.L18:
            clr.w   (-$A,A6)
            move.w  (-10,A6),D0
            bchg.b  #4,(-2,A6)
            beq.w   .L10
            addq.w  #1,D0
            cmpi.w  #10,D0
            beq.b   .ErrorExit
            bra.w   .L10
.ErrorExit:
            moveq   #ioErr,D7
.Exit:
            movem.l (SP)+,D0-D6/A0-A6
            unlk    A6
            rts
RamDisk_Unknown9:
            moveq   #0,D0
            move.w  (-$A,A6),D0
            lsl.l   #5,D0
            lsl.l   #5,D0
            adda.l  D0,A1
            moveq   #0,D0
            move.w  (-8,A6),D0
            lsl.l   #5,D0
            subq.l  #1,D0
            move.l  A0,D2
            btst.b  #1,(-2,A6)
            beq.b   .L4
            bset.b  #RAMDiskBit,OutboundVIA+vDIRB
            bclr.b  #RAMDiskBit,OutboundVIA+vBufB
            bsr.w   RamDisk_Unknown6
            btst.l  #0,D2
            beq.b   .L1
            move.b  (A0)+,(A1)
            subq.l  #6,A1
            bra.b   .L2
.L1:
            move.l  (A0)+,D1
            movep.l D1,(0,A1)
.L2:
            move.l  (A0)+,D1
            movep.l D1,(8,A1)
            move.l  (A0)+,D1
            movep.l D1,($10,A1)
            move.l  (A0)+,D1
            movep.l D1,($18,A1)
            adda.w  #$20,A1
            dbf     D0,.L1
            btst.l  #0,D2
            beq.b   .L3
            move.w  (A0)+,D1
            movep.w D1,(0,A1)
            move.b  (A0)+,(4,A1)
.L3:
            moveq   #0,D7
            bset.b  #RAMDiskBit,OutboundVIA+vBufB
            rts
.L4:
            btst.b  #0,(-2,A6)
            beq.b   .L8
            btst.l  #0,D2
            beq.b   .L5
            move.b  (A1),(A0)+
            subq.l  #6,A1
            bra.b   .L6
.L5:
            movep.l (0,A1),D1
            move.l  D1,(A0)+
.L6:
            movep.l (8,A1),D1
            move.l  D1,(A0)+
            movep.l ($10,A1),D1
            move.l  D1,(A0)+
            movep   ($18,A1),D1
            move.l  D1,(A0)+
            adda.w  #$20,A1
            dbf     D0,.L5
            btst.l  #0,D2
            beq.b   .L7
            movep.w (0,A1),D1
            move.w  D1,(A0)+
            move.b  (4,A1),(A0)+
.L7:
            exg     D2,A0
            bsr.w   RamDisk_Unknown3
            bne.b   RamDisk_VerifyError
            exg     D2,A0
            moveq   #0,D7
            rts
.L8:
            btst.l  #0,D2
            beq.b   .L9
            move.b  (A0)+,D1
            cmpb    (A1),D1
            bne.b   RamDisk_VerifyError
            subq.w  #6,A1
            bra.b   .L10
.L9:
            movep.l (0,A1),D1
            cmp.l   (A0)+,D1
            bne.b   RamDisk_VerifyError
.L10:
            movep.l (8,A1),D1
            cmp.l   (A0)+,D1
            bne.b   RamDisk_VerifyError
            movep.l ($10,A1),D1
            cmp.l   (A0)+,D1
            bne.b   RamDisk_VerifyError
            movep.l ($18,A1),D1
            cmp.l   (A0)+,D1
            bne.b   RamDisk_VerifyError
            adda.w  #$20,A1
            dbf     D0,.L9
            btst.l  #0,D2
            beq.b   .Exit
            movep.l (0,A1),D1
            cmp.w   (A0)+,D1
            bne.b   RamDisk_VerifyError
            move.b  (A0)+,D1
            cmp.b   (4,A1),D1
            bne.b   RamDisk_VerifyError
.Exit:
            moveq   #0,D7
            rts
RamDisk_VerifyError:
            moveq   #dataVerErr,D7
            rts
RamDisk_Unknown7:
            move.w  #9,D6
            moveq   #0,D0
            move.w  (-$A,A6),D0
            lsl.l   D6,D0
            adda.l  D0,A1
            moveq   #0,D0
            move.w  (-8,A6),D0
            lsl.l   D6,D0
            movem.l A0/D0,-(SP)
            btst.b  #1,(-2,A6)
            bne.b   .L1
            btst.b  #0,(-2,A6)
            beq.b   .L3
            exg     A0,A1
            _BlockMove
            bsr.w   RamDisk_Unknown3
            beq.b   .L2
            movem.l (SP)+,D0/A0
            bra.b   RamDisk_VerifyError
.L1:
            bset.b  #RAMDiskBit,OutboundVIA+vDIRB
            bclr.b  #RAMDiskBit,OutboundVIA+vBufB
            bsr.w   RamDisk_Unknown6
            _BlockMove
            bset.b  #RAMDiskBit,OutboundVIA+vBufB
.L2:
            movem.l (SP)+,D0/A0
            adda.l  D0,A0
            bra.b   .Exit
.L3:
            movem.l (SP)+,D0/A0
.L4:
            cmpm.b  (A0)+,(A1)+
            bne.b   RamDisk_VerifyError
            subq.l  #1,D0
            bne.b   .L4
            moveq   #0,D7
            rts
RamDisk_Checksum:
            movem.l A0/D2-D1,-(SP)
            moveq   #0,D0
            move.l  A0,D2
            btst.l  #0,D2
            bne.b   .L2
            addq.l  #1,D1
            asr.l   #4,D1
            subq.l  #1,D1
.L1:
            move.l  (A0)+,D2
            eor.l   D2,D0
            move.l  (A0)+,D2
            eor.l   D2,D0
            move.l  (A0)+,D2
            eor.l   D2,D0
            move.l  (A0)+,D2
            eor.l   D2,D0
            dbf     D1,.L1
            move.l  D0,D2
            asr.w   #8,D2
            eor.b   D2,D0
            swap    D2
            eor.b   D2,D0
            asr.w   #8,D2
            eor.b   D2,D0
            bra.b   .Exit
.L2:
            move.b  (A0)+,D2
            eor.b   D2,D0
            dbf     D1,.L2
.Exit:
            movem.l (SP)+,D1-D2/A0
            rts
RamDisk_Unknown4:
            movea.l #RAMDiskBase,A1
            move.w  (-$10,A6),D0
            move.b  (A2,D0.w),D4
            btst.b  #4,(-2,A6)
            beq.b   .L1
            adda.l  #$80000,A1
            lsr.b   #2,D4
.L1:
            andi.b  #$30,D4
            cmpi.b  #$30,D4
            beq.b   .L3
            cmpi.b  #$10,D4
            beq.b   .PatchLineA_L23
            addq.w  #1,A1
.L2:
            moveq   #2,D4
            bra.b   .L4
.L3:
            moveq   #1,D4
.L4:
            move.w  (-$A,A6),D3
            mulu.w  D4,D3
            adda.w  D3,A1
            move.w  (-8,A6),D3
            subq.w  #1,D3
            move.l  #$1FF,D1
            rts
RamDisk_Unknown6:
            movem.l A3-A0/D4-D0,-(SP)
            bsr.b   RamDisk_Unknown4
.L1:
            bsr.w   RamDisk_Checksum
            move.b  D0,(A1)
            adda.l  D4,A1
            adda.l  D1,A0
            addq.l  #1,A0
            dbf     D3,.L1
            movem.l (SP)+,D0-D4/A0-A3
            rts
RamDisk_Unknown3:
            movem.l A3-A0/D5-D0,-(SP)
            bsr.b   RamDisk_Unknown4
.L1:
            bsr.b   RamDisk_Checksum
            move.b  (A1),D5
            cmp.b   D0,D5
            bne.b   .Exit
            adda.l  D4,A1
            adda.l  D1,A0
            addq.l  #1,A0
            dbf     D3,.L1
            cmp.w   D0,D0
.Exit:
            movem.l (SP)+,D0-D5/A0-A3
            rts
;
RAMDisk_Ctl:
            clr.w   D0
            cmpi.w  #$41,($1A,A0)
            beq.b   .L1
            cmpi.w  #5,($1A,A0)
            beq.b   .Verify
            cmpi.w  #6,($1A,A0)
            beq.b   .Format
            cmpi.w  #7,($1A,A0)
            beq.b   .Eject
            cmpi.w  #21,($1A,A0)
            beq.b   .Info
            cmpi.w  #22,($1A,A0)
            beq.b   .Info
            cmpi.w  #23,($1A,A0)
            beq.b   .Info
            move.w  #controlErr,D0
            bra.w   .Exit
.L1:
            movem.l A1-A0/D0,-(SP)
            bclr.b  #5,(4,A1)
            tst.w   SysEvtMask
            bne.b   .L2
            btst.b  #5,(4,A1)
            move.w  #$3C,($22,A1)
            bra.b   .L3
.L2:
            movea.w #7,A0
            movea.l OutboundGlobals,A1
            moveq   #0,D0
            move.w  ($13A,A1),D0
            _PostEvent
.L3:
            movem.l (SP)+,D0/A0-A1
            bra.w   .Exit
.Verify:
            bra.w   .Exit
.Format:
            movem.l A1-A0/D1-D0,-(SP)
            move.w  #15,D0
            moveq   #0,D1
            lea     OutboundDisp,A1                 ; A1 = end (display SRAM start)
            bset.b  #RAMDiskBit,OutboundVIA+vDIRB
            bclr.b  #RAMDiskBit,OutboundVIA+vBufB
.SetupLoop:
            bsr.w   RamDisk_BankSwitch
            lea     RAMDiskBase,A0                  ; A1 = start (RAM disk start)
            clr.w   (A0)
            tst.b   (A0)
            beq.b   .ClearLoop
            tst.b   (1,A0)
            bne.b   .L8
.ClearLoop:
            move.l  D1,(A0)+
            move.l  D1,(A0)+
            move.l  D1,(A0)+
            move.l  D1,(A0)+
            cmpa.l  A0,A1
            bne.b   .ClearLoop
.L8:
            dbf     D0,.SetupLoop
            bset.b  #RAMDiskBit,OutboundVIA+vBufB
            movem.l (SP)+,D0-D1/A0-A1
            bra.b   .Exit
.Eject:
            btst.b  #CfgBit5,OutboundCfg
            beq.b   .L10
            bset.b  #5,(4,A1)
            move.w  #$1E,($22,A1)
            move.w  #controlErr,D0
            bra.b   .Exit
.L10:
            clr.w   D0
            bra.b   .Exit
.Info:
            move.l  ($14,A1),($1C,A0)
            bra.b   .Exit
            move.l  #$602,($1C,A0)
.Exit:
            btst.b  #1,(6,A0)
            bne.b   .DoneExit
            move.l  JIODone,-(SP)
.DoneExit:
            rts
RAMDisk_Status:
            move.w  #-$12,D0
            cmpi.w  #8,($1A,A0)
            bne.b   .L1
            lea     ($1C,A0),A2
            clr.w   (A2)
            clr.b   (2,A2)
            move.b  #1,(3,A2)
            move.b  #1,(4,A2)
            move.w  ($16,A0),($C,A2)
            move.w  ($18,A0),($E,A2)
            clr.w   ($10,A2)
            clr.w   ($14,A2)
            clr.w   D0
.L1:
            btst.b  #1,(6,A0)
            move.l  JIODone,-(SP)
            rts
RAMDisk_Data1:
            incbin  'bin/RAMDisk_Data1.bin'
            dc.b    21
            dc.b    'Outbound Silicon Disk'
;
; Inputs:   D0
RamDisk_BankSwitch:
            move.b  D0,$500001
            ror.b   #1,D0
            move.b  D0,$500003
            ror.b   #1,D0
            move.b  D0,$500005
            ror.b   #1,D0
            move.b  D0,$500007
            ror.b   #3,D0
            rts
RamDisk_Sizing:
            bset.b  #RAMDiskBit,OutboundVIA+vDIRB
            bclr.b  #RAMDiskBit,OutboundVIA+vBufB
            movem.l A4-A0/D3-D0,-(SP)
            movea.l RAMDiskBase,A0
            movea.l RAMDiskBase+$80000,A1
            movea.l OutboundGlobals,A2
            movea.l A2,A4
            adda.w  #$FA,A4
            clr.w   D0
.L1:
            bsr.b   RamDisk_BankSwitch
            move.w  (A0),-(SP)
            move.w  (A1),-(SP)
            clr.w   (A0)
            clr.w   (A1)
            clr.b   (A4,D0.w)
            addq.w  #1,D0
            cmpi.w  #$10,D0
            bne.b   .L1
            clr.w   D1
            clr.w   D2
            movea.l A0,A3
.L2:
            clr.w   D0
.L3:
            bsr.b   RamDisk_BankSwitch
            tst.b   (A3)
            bne.b   .L4
            subq.b  #1,(A3)
            bpl.b   .L4
            bset.b  D1,(A4,D0.w)
            addq.w  #1,D2
.L4:
            addq.w  #1,D0
            cmpi.w  #$10,D0
            bne.b   .L3
            addq.w  #1,D1
            btst.l  #0,D1
            beq.b   .L5
            addq.l  #1,A3
            bra.b   .L2
.L5:
            cmpi.w  #2,D1
            bne.b   .L6
            movea.l A1,A3
            bra.b   .L2
.L6:
            move.b  D2,(RAMDiskSize,A2)
            clr.w   D2
            moveq   #$F,D0
.L7:
            bsr.w   RamDisk_BankSwitch
            move.b  (A4,D0.w),D2
            move.b  (.BankTable,PC,D2.w),D2
            move.b  D2,(A4,D0.w)
            move.w  (SP)+,(A1)
            move.w  (SP)+,(A0)
            dbf     D0,.L7
            movem.l (SP)+,D0-D3/A0-A4
            bset.b  #RAMDiskBit,OutboundVIA+vBufB
            rts
.BankTable:
            dc.b    $0
            dc.b    $11
            dc.b    $21
            dc.b    $32
            dc.b    $41
            dc.b    $52
            dc.b    $62
            dc.b    $73
            dc.b    $81
            dc.b    $92
            dc.b    $A2
            dc.b    $B3
            dc.b    $C2
            dc.b    $D3
            dc.b    $E3
            dc.b    $F4
floppyopen:
            link.w  A6,#-4
            movem.l A4-A3/D7,-(SP)
            movea.l ($C,A6),A4
            movea.l OutboundGlobals,A3
            jsr     Super_Unknown6
            pea     ($14,A4)
            jsr     Super_Unknown7
            jsr     Super_Unknown9
            move.b  #3,(-4,A6)
            move.b  #$DF,(-3,A6)
            move.b  #$F,(-2,A6)
            moveq   #3,D0
            move.l  D0,-(SP)
            pea     (-4,A6)
            jsr     Floppy_WriteCMD
            clr.b   (5,A3)
            move.b  #1,(6,A3)
            move.b  #-1,(7,A3)
            clr.w   ($C,A3)
            move.w  #$FFBF,(30,A3)
            clr.w   ($34,A3)
            move.w  #1,($38,A3)
            move.w  #1,($36,A3)
            clr.w   ($32,A3)
            move.b  #$50,($3E,A3)
            move.b  #$30,($3A,A3)
            move.l  #$4800,($2A,A3)
            jsr     Super_Unknown30
            move.b  $4A,(-4,A6)
            clr.b   (-3,A6)
            

floppyprime:
            link.w  A6,#-$A
            movem.l A4-A3/D7-D4,-(SP)
            movea.l (8,A6),A4
            movea.l OutboundGlobals,A3
            movea.l ($C,A6),A0
            move.l  ($10,A0),(-$A,A6)
            move.l  ($24,A4),D4
            move.l  ($20,A4),(-6,A6)
            bra.w   .L12
.L1:
            tst.b   ($3A,A3)
            beq.b   .L2
            move.l  (-$A,A6),D0

floppycontrol:
            link.w  A6,#-$40
            movem.l A4-A3,-(SP)
            movea.l OutboundGlobals,A4
            movea.l (8,A6),A0
            move.w  ($1A,A0),D0
            subq.w  #5,D0
            beq.b   .verify
            subq.w  #1,D0
            beq.b   .format
            subq.w  #1,D0
            beq.b   .eject
            subi.w  #$E,D0
            beq.b   .PhysIcon
            subq.w  #1,D0
            beq.b   .LogIcon
            subq.w  #1,D0
            beq.b   .info
            subi.w  #$2A,D0
            beq.b   .L8
            bra.w   .ErrorExit
.verify:
            jsr     verifydisk
            bra.w   .Exit
.format:
            jsr     formatdisk
            bra.w   .Exit
.eject:
            moveq   #0,D0
            move.l  D0,-(SP)
            jsr     driveready
            move.b  #-1,(5,A4)
            moveq   #1<<CfgBit5,D0
            and.b   OutboundCfg,D0
            addq.l  #4,SP
            beq.b   .L4
            ori.b   #1<<CfgBit6,OutboundCfg
            clr.b   (5,A4)
            moveq   #-$11,D0
            bra.w   .Exit
.L4:
            move.w  ($30,A4),D0
            bra.w   .Exit
.PhysIcon:
            movea.l ($C,A6),A0
            move.l  ($14,A0),D0
            add.l   #$100,D0
            movea.l (8,A6),A0
            move.l  D0,($1C,A0)
            bra.b   .SuccessExit
.LogIcon:
            movea.l ($C,A6),A0
            movea.l (8,A6),A1
            move.l  ($14,A0),($1C,A1)
            bra.b   .SuccessExit
.info:
            movea.l (8,A6),A0
            moveq   #4,D0
            move.l  D0,($1C,A0)
            bra.b   .SuccessExit
.L8:
            moveq   #0,D0
            pea     (-$40,A6)
            jsr     Super_Unknown22
            movea.l $358,A3
            addq.l  #2,SP
            bra.b   .L11
.L9:
            tst.w   ($48,A3)
            bne.b   .L10
            move.w  ($E,A4),D0
            neg.w   D0
            cmp.w   ($4A,A3),D0
            bne.b   .L10
            move.w  ($E,A4),($4A,A3)
            bra.b   .L12
.L10:
            movea.l (A3),A3
.L11:
            move.l  A3,D0
            bne.b   .L9
.L12:
            movea.l ($C,A6),A0
            andi.w  #$DFFF,(4,A0)
            bra.b   .SuccessExit
.ErrorExit:
            moveq   #controlErr,D0
            bra.b   .Exit
.SuccessExit:
            moveq   #0,D0
.Exit:
            movem.l (-$48,A6),A3-A4
            unlk    A6
            rts
floppystatus:
            link.w  A6,#-$16
            movem.l A4-A3,-(SP)
            movea.l (8,A6),A4
            movea.l OutboundGlobals,A3
            move.w  ($1A,A4),D0

readwriteop:
            link.w  A6,#0
            movem.l A4-A3/D7-D3,-(SP)
            movea.l ($14,A6),A4
            move.l  ($18,A6),D5
            move.l  ($10,A6),D6
            movea.l OutboundGlobals,A3
            move.b  ($F,A6),D0

verifydisk:
            movem.l A3/D7,-(SP)
            movea.l OutboundGlobals,A3
            move.b  ($3E,A3),D0
            subq.b  #1,D0
            move.b  D0,($2E,A3)
            bra.w   .L6
.L1:
            tst.b   ($3A,A3)
            bne.b   .L4
            clr.w   D7
            bra.b   .L3
.L2:

formatdisk:
            move.l  A3,-(SP)                        ; Save A3
            movea.l OutboundGlobals,A3
            moveq   #1,D0
            move.l  D0,-(SP)
            jsr     driveready
            tst.w   D0
            addq.l  #4,SP
            bne.b   .L1
            moveq   #offLinErr,D0                   ; Set error code
            bra.b   .Exit
.L1:
            moveq   #1,D0
            move.l  D0,-(SP)
            jsr     determinetype
            tst.w   D0
            addq.l  #4,SP
            bne.b   .L2
            moveq   #noNybErr,D0                    ; Set error code
            bra.b   .Exit
.L2:
            clr.b   ($2E,A3)
            bra.b   .L5
.L3:
            jsr     formatcylinder
            move.w  D0,($30,A3)
            beq.b   .L4
            move.w  ($30,A3),D0
            bra.b   .Exit
.L4:
            addq.b  #1,($2E,A3)
.L5:
            move.b  ($2E,A3),D0
            cmp.b   ($3E,A3),D0
            bcs.b   .L3
            moveq   #0,D0
.Exit:
            movea.l (SP)+,A3                        ; Restore A3
            rts
formatcylinder:
            link.w  A6,#-$56
            movem.l A4-A3/D7-D6,-(SP)
            movea.l OutboundGlobals,A4
            moveq   #0,D0
            move.b  (FlpCylinder,A4),D0
            move.l  D0,-(SP)
            jsr     seek_sense
            tst.w   D0
            addq.l  #4,SP
            bne.b   .L1
            moveq   #seekErr,D0                     ; Return seek error
            bra.w   .Exit
.L1:
            clr.b   D6
            bra.w   .L16
.L2:
            tst.b   (FlpType,A4)                    ; GCR disk?
            beq.w   .GCR
            clr.w   D7
            lea     (-$48,A6),A3
            bra.b   .L4
.L3:
            move.b  (FlpCylinder,A4),(A3)+
            move.b  D6,(A3)+
            move.w  D7,D0
            addq.w  #1,D0
            move.b  D0,(A3)+
            move.b  #2,(A3)+
            addq.w  #1,D7
.L4:
            moveq   #0,D0
            move.w  D7,D0
            moveq   #0,D1
            move.b  (FlpSectors,A4),D1
            cmp.l   D0,D1
            bhi.b   .L3
            move.b  #$4D,(-$56,A6)
            move.b  D6,D0
            lsl.b   #2,D0
            move.b  D0,(-$54,A6)
            move.b  (FlpSectors,A4),(-53,A6)
            move.b  (FlpType,A4),(-$52,A6)
            move.b  #$3B,(-$51,A6)
            moveq   #6,D0
            move.l  D0,-(SP)
            pea     (-$56,A6)
            jsr     Floppy_WriteCMD
            tst.w   D0
            addq.l  #8,SP
            bne.b   .PatchLineA_L25
            moveq   #noAdrMkErr,D0
            bra.w   .Exit
.L5:
            moveq   #0,D0
            move.w  D7,D0
            asl.l   #2,D0
            move.l  D0,-(SP)
            pea     (-$48,A6)
            jsr     Floppy_WriteSector
            tst.w   D0
            addq.l  #8,SP
            bne.b   .L6
            moveq   #badCksmErr,D0
            bra.w   .Exit
.L6:
            moveq   #7,D0
            move.l  D0,-(SP)
            pea     (-$50,A6)
            jsr     Super_Unknown13
            tst.w   D0
            addq.l  #8,SP
            beq.b   .badBtSlp
            move.w  #$FB,D0
            and.b   (-$50,A6),D0
            bne.b   .Underrun




driveready:
            link.w  A6,#-$A
            movem.l A4-A3/D7,-(SP)
            movea.l OutboundGlobals,A3
            moveq   #$20,D0
            and.b   OutboundFlpBase+$18,D0
            beq.b   .L1
            moveq   #0,D0
            bra.w   .Exit
.L1:
            move.b  #$14,OutboundFlpBase+$10
            move.w  #$80,D0
            and.b   OutboundFlpBase+8,D0
            beq.b   .L4
            tst.b   (FlpStatus,A3)
            bne.b   .L2
            moveq   #1<<ExtFloppy,D0                ; Check if an external floppy drive is connected
            and.b   OutboundCfg,D0
            beq.b   .L4
.L2:
            moveq   #-1,D0
            cmp.b   (FlpStatus,A3),D0
            beq.b   .L3
            subq.l  #4,SP
            move.w  ($10,A3),-(SP)
            jsr     Super_Unknown21
            movea.l (SP)+,A0
            movea.l (A0),A4
            or.w    #$2000,(4,A4)
.L3:
            clr.b   (FlpStatus,A3)
            move.w  #volOffLinErr,(FlpLastError,A3)
            move.b  #$4A,(-$A,A6)
            moveq   #2,D0
            move.l  D0,-(SP)
            pea     (-$A,A6)
            jsr     Floppy_WriteCMD
            andi.b  #%10111111,OutboundCfg
            move.w  ($E,A3),D0
            moveq   #1,D0
            lsl.l   D0,D1
            or.w    D1,BootMask
            moveq   #0,D0
            addq.l  #8,SP
            bra.w   .Exit
.L4:
            tst.b   (FlpStatus,A3)
            bne.w   .L8
            moveq   #1<<CfgBit5,D0
            and.b   OutboundCfg,D0
            beq.b   .PatchLineA_L25
            moveq   #1<<CfgBit6,D0
            and.b   OutboundCfg,D0
            bne.b   .L8
.L5:
            moveq   #7,D0
            move.l  D0,-(SP)
            pea     (-8,A6)
            jsr     Super_Unknown13
            jsr     Super_Unknown30
            move.b  #1,(FlpStatus,A3)
            moveq   #0,D0
            move.l  D0,-(SP)
            jsr     determinetype
            move.b  #4,(-$A,A6)
            clr.b   (-9,A6)
            moveq   #2,D0
            move.l  D0,-(SP)
            pea     (-$A,A6)
            jsr     Floppy_WriteCMD
            moveq   #1,D0
            move.l  D0,-(SP)
            pea     (-8,A6)
            jsr     Super_Unknown13
            moveq   #$40,D0
            and.b   (-8,A6),D0
            lea     ($1C,SP),SP
            beq.b   .L6
            move.b  #-$80,(4,A3)
            bra.b   .L7
.L6:
            clr.b   (4,A3)
.L7:
            subq.l  #2,SP
            moveq   #7,D0
            move.w  D0,-(SP)
            move.w  ($E,A3),D1
            ext.l   D1
            move.l  D1,-(SP)
            jsr     Super_Unknown_PostEvent
            moveq   #1,D0
            addq.l  #2,SP
            bra.b   .Exit
.L8:
            moveq   #1,D0
            cmp.w   ($A,A6),D0
            bne.b   .L12
            moveq   #-1,D0
            cmp.b   (FlpStatus,A3),D0
            beq.b   .L12
            tst.w   ($36,A3)
            bne.b   .L11
            move.l  #$30000,D7
            bra.b   .L10
.L9:
            subq.l  #1,D7
.L10:
            tst.l   D7
            bne.b   .L9
            tst.b   (FlpType,A3)                    ; GCR disk?
            bne.b   .L11                            ; No, skip
            jsr     Floppy_GCRSync_T
.L11:
            move.w  #1,($38,A3)
            move.w  #1,($36,A3)
            moveq   #1,D0
            bra.b   .Exit
.L12:
            tst.w   ($32,A3)
            beq.b   .L13
            clr.w   ($32,A3)
            moveq   #1,D0
            move.l  D0,-(SP)
            jsr     rwop
            move.w  D0,(FlpLastError,A3)
            addq.l  #4,SP
.L13:
            move.b  #4,OutboundFlpBase+$40010
            move.b  #5,$B00003
            move.b  #$62,$B00003                    ; DTR off, 8 bit, RTS on
            clr.w   ($36,A3)
            moveq   #0,D0
.Exit:
            movem.l (-$16,A6),D7/A3-A4
            unlk    A6
            rts
determinetype:
            movem.l A4-A3/D7-D5,-(SP)               ; Save registers
            move.w  ($1A,A6),D5                     ; Operation type?
            movea.l OutboundGlobals,A3              ; Get pointer to globals
            clr.b   (FlpCylinder,A3)
            clr.w   ($32,A3)
            clr.w   D6
            lea     Floppy_FormatTable,A4
            bra.w   .L9
.L1:
            move.b  (A4),(FlpType,A3)
            move.b  (1,A4),($3B,A3)
            move.b  (2,A4),(FlpSectors,A3)
            move.b  (3,A4),(FlpSides,A3)
            move.l  (4,A4),(FlpTrkSize,A3)
            move.w  (8,A4),($14,A3)
            clr.b   (FlpCylinder,A3)
            moveq   #18,D0                          ; High density disk entry?
            cmp.b   (FlpSectors,A3),D0
            bne.b   .DoubleDensity                  ; No
            clr.b   OutboundFlpBase+$40008          ; Setup for high density disks
            bra.b   .L3
.DoubleDensity:
            move.b  #2,OutboundFlpBase+$40008       ; Setup for double density disks
.L3:
            tst.b   ($3A,A3)                        ; GCR type
            bne.b   .L6                             ; No, skip ahead
            clr.w   D7
            bra.b   .L5
.L4:
            lea     Floppy_Scratch,A0
            move.b  #1,(A0,D7.w)
            addq.w  #1,D7
.L5:
            cmpi.w  #24,D7
            bcs.b   .L4
            jsr     Floppy_GCRSync_T
.L6:
            cmpi.w  #1,D5
            bne.b   .L7
            jsr     formatcylinder
.L7:
            moveq   #0,D0
            move.l  D0,-(SP)
            jsr     rwop                            ; Attempt read/write
            move.w  D0,(FlpLastError,A3)            ; Store error if any
            addq.l  #4,SP
            bne.b   .L8                             ; Try the next format if error
            move.b  #2,(FlpStatus,A3)               ; Mark drive as ready?
            moveq   #1,D0                           ; Return success
            bra.b   .Exit
.L8:
            addq.w  #1,D6                           ; Increment counter
            adda.w  #10,A4                          ; Point to next table entry
.L9:
            cmpi.w  #5,D6                           ; Reached the end of the table?
            bcs.w   .L1
            moveq   #0,D0                           ; Return failure
.Exit:
            movem.l (SP)+,D5-D7/A3-A4               ; Restore registers
            rts
seek_sense:
            link.w  A6,#-6
            movem.l A4-A3/D7-D6,-(SP)
            lea     (-3,A6),A4
            lea     (-2,A6),A3
            move.b  ($B,A6),D6
            move.b  #$F,(-6,A6)
            clr.b   (-5,A6)
            move.b  D6,(-4,A6)
            move.b  #8,(A4)
            move.b  #-1,(A3)

.L2:
            addq.w  #1,D7
.L3:
            cmpi.w  #10000,D7
            bcs.b   .L1
.L4:
            moveq   #0,D0
.Exit:
            movem.l (-$16,A6),D6-D7/A3-A4
            unlk    A6
            rts
Super_Install:
            movem.l A6-A0/D7-D0,-(SP)
            movea.l OutboundGlobals,A1
            lea     ($140,A1),A0
            move.l  A0,($26,A1)
            moveq   #-5,D0
            btst.b  #HostMac,OutboundCfg            ; Is a host Mac connected?
            beq.b   .L1                             ; If not, skip ahead
            moveq   #-49,D0
.L1:
            _DrvrInstall                            ; Create DCE
            lea     Super_Driver,A1
            movea.l UTableBase,A0
            btst.b  #HostMac,OutboundCfg            ; Is a host Mac connected?
            bne.b   .HostConnected                  ; If so load a different address
            movea.l (16,A0),A0                      ; Replace the Sony disk driver?
            bra.b   .InstallDriver
.HostConnected:
            move.l  ($C0,A0),A0                     ; Install the floppy driver here
.InstallDriver:
            movea.l (A0),A0                         ; Get pointer to driver DCE
            move.l  A1,(A0)+                        ; Load driver
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
            jsr     floppyopen
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
            jsr     floppyprime
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
            jsr     floppycontrol
            bra.b   Super_Unknown2
Super_Status:
            movem.l A6-A0/D7-D1,-(SP)
            move.l  A1,-(SP)
            move.l  A0,-(SP)
            movea.l OutboundGlobals,A0
            addq.w  #1,($34,A0)
            jsr     floppystatus
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
            incbin  'bin/Super_UnknownData.bin'
            dc.b    21                              ; Length byte
            dc.b    "Outbound Floppy Drive"
            dc.b    0,0
Floppy_FormatTable:
            ; 1.44MB
            dc.b    $30
            dc.b    $15
            dc.b    18                              ; Sectors per track
            dc.b    2                               ; Sides
            dc.l    18432                           ; Bytes per track
            dc.w    2880
            ; 800KB
            dc.b    0
            dc.b    0
            dc.b    12                              ; Sectors per track
            dc.b    2                               ; Sides
            dc.l    12288                           ; Bytes per track
            dc.w    1600
            ; 400KB
            dc.b    0
            dc.b    0
            dc.b    12                              ; Sectors per track
            dc.b    1                               ; Sides
            dc.l    6144                            ; Bytes per track
            dc.w    800
            ; 720KB
            dc.b    $54
            dc.b    $1B
            dc.b    9                               ; Sectors per track
            dc.b    2                               ; Sides
            dc.l    9216                            ; Bytes per track
            dc.w    1440
            ; 360KB
            dc.b    $54,$1B,9,1,0,0,12,0,2,$D0
            dc.b    $54
            dc.b    $1B
            dc.b    9                               ; Sectors per track
            dc.b    1                               ; Sides
            dc.l    4608                            ; Bytes per track
            dc.w    720
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
            jsr     Shared_Unknown1
            jsr     Shared_Unknown1
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
            jsr     driveready
            addq.l  #4,SP
            bra.b   .Exit
.L1:
            clr.w   ($38,A0)
.Exit:
            movem.l (SP)+,D0-D7/A0-A6
            rts
; 
;   Inputs:
;
;   Outputs:    D0  Result
Floppy_WriteCMD:
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
            moveq   #0,D0                           ; Return 0
            bra.b   .Exit
.L4:
            btst.l  #6,D2
            bne.b   .L3
            move.b  (A0)+,OutboundFlpBase+$1A
            dbf     D0,.L1
            moveq   #1,D0                           ; Return 1
.Exit:
            movem.l (SP)+,D1-D2/A0
            unlk    A6
            rts
Floppy_ReadResponse:
            link.w  A6,#0
            movem.l A0/D2-D1,-(SP)
            movea.l (8,A6),A0
            move.w  ($E,A6),D0
            subq.w  #1,D0
.L1:
            move.l  #100000,D1
.L2:
            move.b  OutboundFlpBase+$18,D2
            bmi.b   .L4
            subq.l  #1,D1
            bne.b   .L2
.L3:
            moveq   #0,D0
            bra.b   .Exit
.L4:
            btst.l  #6,D2
            beq.b   .L3
            move.b  OutboundFlpBase+$1A,(A0)+
            dbf     D0,.L1
            moveq   #1,D0
.Exit:
            movem.l (SP)+,D1-D2/A0
            unlk    A6
            rts
Floppy_WriteSector:
            link.w  A6,#0
            movem.l A2-A0/D3-D1,-(SP)
            movea.l #OutboundFlpBase+$18,A0
            movea.l #OutboundFlpBase+$1A,A1
            movea.l ($8,A6),A2
            moveq   #-80,D0
            move.l  ($C,A6),D1
            subq.w  #1,D1
            move    SR,D3
            move    #$2300,SR
.L1:
            move.l  #100000,D2
.L2:
            cmp.b   (A0),D0
            bne.b   .L3
            move.b  (A2)+,(A1)
            dbf     D1,.L1
            moveq   #1,D0
            bra.b   .L4
.L3:
            subq.l  #1,D2
            bne.b   .L2
            moveq   #0,D0
.L4:
            move    D3,SR
            movem.l (SP)+,D1-D3/A0-A2
            unlk    A6
            rts
Floppy_ReadSector:
            link.w  A6,#0
            movem.l A2-A0/D3-D1,-(SP)
            movea.l #OutboundFlpBase+$18,A0
            movea.l #OutboundFlpBase+$1A,A1
            movea.l ($8,A6),A2
            moveq   #-15,D0
            move.l  ($C,A6),D1
            subq.w  #1,D1
            move    SR,D3
            move    #$2300,SR
.L1:
            move.l  #100000,D2
.L2:
            cmp.b   (A0),D0
            bne.b   .L3
            move.b  (A1),(A2)+
            dbf     D1,.L1
            moveq   #1,D0
            bra.b   .L4
.L3:
            subq.l  #1,D2
            bne.b   .L2
            moveq   #0,D0
.L4:
            move    D3,SR
            movem.l (SP)+,D1-D3/A0-A2
            unlk    A6
            rts
Super_4C0:
            movem.l A4-A3/D7,-(SP)
            movem.l ($10,SP),D7/A3-A4
            exg     D7,A4
            moveq   #0,D0
.L1:
            subq.l  #1,D7
            bmi.b   .L2
            cmpm.b  (A3)+,(A4)+
            beq.b   .L1
            moveq   #-68,D0
.L2:
            movem.l (SP)+,D7/A3-A4
            rts
Super_Unknown30:
            movem.l A4-A2/D7-D2/D1,-(SP)
            moveq   #1,D1
            moveq   #2,D2
            move.l  D1,-(SP)
            bsr.w   seek_sense
            move.l  #-$F800,(SP)
            lea     (2,SP),A4
            movea.l SP,A3
            move.w  #$700,-(SP)
            movea.l SP,A2
            bsr.b   Floppy_WriteCMDWrapper
            tst.w   D0
            beq.b   .L3
            move.w  #$270F,D7
.L1:
            move.l  D1,-(SP)
            move.l  A4,-(SP)
            bsr.w   Floppy_WriteCMD
            addq.l  #8,SP
            tst.w   D0
            beq.b   .L3
            move.l  D2,-(SP)
            move.l  A3,-(SP)
            bsr.w   Floppy_ReadResponse
            addq.l  #8,SP
            cmpi.w  #$2000,(A3)
            beq.b   .L4
            btst.b  #4,(A3)
            beq.b   .L2
            bsr.b   Floppy_WriteCMDWrapper
.L2:
            dbf     D7,.L1
.L3:
            moveq   #0,D0
            bra.b   .L5
.L4:
            moveq   #1,D0
.L5:
            addq.l  #6,SP
            movem.l (SP)+,D1-D2/D7/A2-A4
            rts
Floppy_WriteCMDWrapper:
            move.l  D2,-(SP)
            move.l  A2,-(SP)
            bsr.w   Floppy_WriteCMD
            addq.l  #8,SP
            rts
rwop:
            link.w  A6,#-$10
            movem.l A5-A2/D7-D3,-(SP)
            move.l  (8,A6),D3
            movea.l OutboundGlobals,A2
            moveq   #1,D7
            move.l  D7,-(SP)
            jsr     driveready
            addq.l  #4,SP
            tst.w   D0
            bne.b   .L1
            moveq   #offLinErr,D0
            bra.w   .Exit
.L1:
            moveq   #1,D0
            move.b  ($2E,A2),D0
            move.l  D0,-(SP)
            jsr     seek_sense
            addq.l  #4,SP
            tst.w   D0
            bne.b   .L2
            moveq   #seekErr,D0
            bra.w   .Exit
.L2:
            moveq   #5,D4
            tst.b   (FlpType,A2)
            beq.b   .L11
.L3:
            lea     (-$10,A6),A5
            moveq   #$45,D0
            cmp.b   (FlpSides,A2),D7
            beq.b   .L4
            addi.b  #-$80,D0
.L4:
            cmp.b   D3,D7
            beq.b   .L5
            addq.b  #1,D0
.L5:
            move.b  D0,(A5)+
            clr.b   (A5)+
            move.b  ($2E,A2),(A5)+
            clr.b   (A5)+
            move.b  D7,(A5)+
            move.b  #2,(A5)+
            move.b  (FlpSectors,A2),(A5)+
            move.b  ($3B,A2),(A5)+
            move.b  #-1,(A5)+
            moveq   #9,D0
            move.l  D0,-(SP)
            pea     (-$10,A6)
            jsr     Floppy_WriteCMD
            addq.l  #8,SP
            tst.w   D0
            bne.b   .L6
            moveq   #-$47,D0
            bra.w   .Exit
.L6:
            move.l  ($2A,A2),-(SP)
            move.l  ($26,A2),-(SP)
            cmp.b   D3,D7
            bne.b   .L7
            jsr     Floppy_WriteSector
            bra.b   .L8
.L7:
            jsr     Floppy_ReadSector
.L8:
            addq.l  #8,SP
            moveq   #7,D0
            move.l  D0,-(SP)
            move.l  A5,-(SP)
            jsr     Floppy_ReadResponse
            addq.l  #8,SP
            tst.w   D0
            bne.b   .L9
            moveq   #badDBtSlp,D0
            bra.w   .Exit
.L9:
            btst.b  #0,(1,A5)
            beq.b   .L10
            moveq   #noAdrMkErr,D0
            bra.w   .Exit
.L10:
            moveq   #$44,D0
            cmp.b   (A5)+,D0
            bne.w   .L15
            moveq   #-$80,D0
            cmp.b   (A5)+,D0
            bne.w   .L15
            moveq   #0,D0
            cmp.b   (A5)+,D0
            bne.w   .L15
            move.b  ($2E,A2),D0
            cmp.b   (A5)+,D0
            bne.w   .L15
            move.b  (FlpSides,A2),D0
            subq.b  #1,D0
            cmp.b   (A5)+,D0
            bne.b   .L15
            move.b  (FlpSectors,A2),D0
            cmp.b   (A5)+,D0
            bne.b   .L15
            moveq   #2,D0
            cmp.b   (A5)+,D0
            bne.b   .L15
            bra.w   .L18
.L11:
            moveq   #0,D5
            movea.l ($26,A2),A3
            lea     Floppy_Scratch,A4
.L12:
            lea     (-$10,A6),A5
            move.b  #4,(A5)+
            move.b  D5,(A5)+
            moveq   #2,D0
            move.l  D0,-(SP)
            pea     (-$10,A6)
            jsr     Floppy_WriteCMD
            addq.l  #8,SP
            tst.w   D0
            bne.b   .L13
            moveq   #noDtaMkErr,D0
            bra.b   .Exit
.L13:
            move.l  A4,-(SP)
            move.l  D3,-(SP)
            move.l  A3,-(SP)
            jsr     Super_0028e894
            adda.w  #$C,SP
            move.l  D0,D6
            move.l  D7,-(SP)
            move.l  A5,-(SP)
            jsr     Floppy_ReadResponse
            addq.l  #8,SP
            tst.w   D0
            bne.b   .L14
            moveq   #badDBtSlp,D0
            bra.b   .Exit
.L14:
            tst.w   D6
            beq.b   .L15
            tst.b   D5
            bne.b   .L18
            moveq   #4,D5
            moveq   #0,D0
            move.b  (FlpSectors,A2),D0
            adda.l  D0,A4
            moveq   #9,D1
            lsl.l   D1,D0
            adda.l  D0,A3
            moveq   #5,D4
            bra.b   .L12
.L15:
            tst.l   D4
            bne.b   .L16
            moveq   #wrUnderrun,D0
            bra.b   .Exit
.L16:
            subq.l  #1,D4
            jsr     Super_Unknown30
            jsr     Floppy_GCRSync_T
            moveq   #0,D0
            move.b  ($2E,A2),D0
            move.l  D0,-(SP)
            jsr     seek_sense
            addq.l  #4,SP
            tst.w   D0
            bne.b   .L17
            moveq   #seekErr,D0
            bra.b   .Exit
.L17:
            tst.b   (FlpType,A2)
            beq.w   .L12
            bra.w   .L3
.L18:
            move.w  #$28,($22,A2)
            moveq   #0,D0
.Exit:
            movem.l (SP)+,D3-D7/A2-A5
            unlk    A6
            rts
Floppy_GCRSync_T:
            bra.w   Floppy_GCRSync
FloppyBaudSet1:
            dc.b    14,0                            ; Write register 14, BR off
            dc.b    12,$A0
            dc.b    13,$F
            dc.b    14,1                            ; Write register 14, BR on
FloppyBaudSet2:
            dc.b    14,0                            ; Write register 14, BR off
            dc.b    12,6
            dc.b    13,0
            dc.b    14,1                            ; Write register 14, BR on
; Write 4 commands (8 bytes) to control channel B
Floppy_SCCconfigureB:
            moveq   #8-1,D1                         ; Set loop counter
.Loop:
            move.b  (A0)+,$B00003                   ; Write to control channel B
            dbf     D1,.Loop                        ; Loop until all commands written
            rts
Floppy_MeasureZoneTiming:
            moveq   #-1,D3
            move.b  D3,(A2)                         ; Start VIA timer
.L1:
            btst.b  D6,(A4)                         ; Wait for RxCA set
            dbne    D3,.L1                          ; Loop until RxCA or timeout
            beq.b   .Fail                           ; Timeout?
            moveq   #-1,D3
.L2:
            btst.b  D6,(A4)                         ; Wait for RxCA clear
            dbeq    D3,.L2
            bne.b   .Fail                           ; Timeout?
            moveq   #-1,D3
            move.b  D3,(A1)
.L3:
            btst.b  D6,(A4)                         ; Wait for RxCA set
            dbne    D3,.L3
            beq.b   .Fail
            move.b  (A1),D3
            move.b  (A2),D2
            cmp.b   (A1),D3
            beq.b   .L4
            tst.b   D2
            bpl.b   .L4
            subq.b  #1,D3
.L4:
            lsl.l   #8,D3
            move.b  D2,D3
            neg.l   D3
            cmp.w   (FlpZoneTime,A6),D3
            beq.b   .Success
            rts
.Success:
            addq.l  #4,SP
            bra.w   Floppy_GCRSync_Success
.Fail:
            addq.l  #4,SP
            bra.w   Floppy_GCRSync_Fail
Super_0028e770:
            bclr.b  #0,(A3)
            bra.b   Super_0028e77a
Super_0028e776:
            bset.b  #0,(A3)
Super_0028e77a:
            moveq   #4,D5
.L1:
            dbf     D5,.L1
            bclr.b  #1,(A3)
            moveq   #4,D5
.L2:
            dbf     D5,.L2
            bset.b  #1,(A3)
            rts
Floppy_GCRSync:
            link.w  A6,#-8
            movem.l A5-A0/D7-D1,-(SP)
            lea     $B00001,A5                      ; SCC write Z85C30
            lea     $900000,A4                      ; SCC read Z85C30
            lea     $E0E1FE,A3                      ; Also VIA?
            lea     OutboundVIA+vT2C,A2             ; VIA T2C
            lea     ($C8,A2),A1                     ; ???
            movea.l OutboundGlobals,A0
            moveq   #5,D6                           ; Configuring write register 5
            ori.b   #%11,$E0E5FE                    ; ???
            move    SR,(-6,A6)                      ; Save SR
            move    #$2300,SR
            moveq   #-$1E,D1                        ; DTR on, 8-bit, RTS on
            move.b  D6,(A5)                         ; A channel write register = 5
            move.b  D1,(A5)                         ; A channel value = $E2
            move.b  D6,$B00003                      ; B channel write register = 5
            moveq   #0,D0
            move.b  (FlpSectors,A0),D0              ; Get current sectors per track
            cmpi.b  #10,D0                          ; 10 or more sectors?
            bge.b   .L1                             ; If yes, skip ahead
            subq.b  #2,D1                           ; Turn RTS off when configuring B
.L1:
            move.b  D1,$B00003                      ; B channel value = D1
            subq.l  #8,D0                           ; Adjust for table
            lsl.l   #1,D0
            move.w  (.ZoneTiming,D0),(FlpZoneTime,A6)
            move.w  (.ZoneTolerance,D0),(FlpZoneTol,A6)
            move.w  (.VIATiming,D0),(FlpVIATiming,A0)
            lea     FloppyBaudSet1,A0
            bsr.w   Floppy_SCCconfigureB
            moveq   #$32,D7
.L2:
            moveq   #$66,D1
.L3:
            bsr.w   Floppy_MeasureZoneTiming
            bhi.b   .L7
            bsr.w   Super_0028e776
            dbf     D1,.L3
            bra.b   Floppy_GCRSync_Fail
.ZoneTiming:
            dc.w    1476                            ; 8 sectors
            dc.w    1312                            ; 9 sectors
            dc.w    1181                            ; 10 sectors
            dc.w    1073                            ; 11 sectors
            dc.w    984                             ; 12 sectors
.ZoneTolerance:
            dc.w    28                              ; 8 sectors
            dc.w    22                              ; 9 sectors
            dc.w    18                              ; 10 sectors
            dc.w    15                              ; 11 sectors
            dc.w    12                              ; 12 sectors
; Timings for VIA timer 2
.VIATiming:
            dc.w    $874A                           ; 8 sectors
            dc.w    $7845                           ; 9 sectors
            dc.w    $6C3B                           ; 10 sectors
            dc.w    $6263                           ; 11 sectors
            dc.w    $5A34                           ; 12 sectors
.L7:
            moveq   #102,D1
.L8:
            move.w  D3,(LastSyncTime,A6)
            bsr.w   Super_0028e770
            bsr.w   Floppy_MeasureZoneTiming
            bcs.b   .L9
            dbf     D1,.L8
            bra.b   Floppy_GCRSync_Fail
.L9:
            sub.w   (FlpZoneTime,A6),D3
            neg.l   D3
            move.w  (LastSyncTime,A6),D4
            sub.w   (FlpZoneTime,A6),D4
            cmp.w   D3,D4
            bsr.w   Super_0028e776
.L10:
            cmp.w   (FlpZoneTol,A6),D3
            bls.b   Floppy_GCRSync_Success
            dbf     D7,.L2
Floppy_GCRSync_Fail:
            moveq   #0,D0
            bra.b   Floppy_GCRSync_Exit
Floppy_GCRSync_Success:
            moveq   #1,D0
Floppy_GCRSync_Exit:
            lea     FloppyBaudSet2,A0
            bsr.w   Floppy_SCCconfigureB
            move    (-6,A6),SR                      ; Restore SR
            move.b  D6,(A5)                         ; A channel write register = 5
            move.b  #$62,(A5)                       ; DTR off, 8 bit, RTS on
            movem.l (SP)+,D1-D7/A0-A5
            unlk A6
            rts
Super_0028e894:
            link.w  A6,#0
            movem.l A4-A0/D7-D1,-(SP)
            move    SR,-(SP)
            moveq   #0,D0
            movea.l OutboundGlobals,A3

Super_0028eb0c:
            moveq   #-1,D0
.L1:
            btst.b  #0,(A0)


            
;temp
Super_UnknownData5:

Floppy_Scratch:
            ds.b    25






Unknown_DFA:
            link.w  A6,#0
            movem.l A4-A2/D6-D3,-(SP)
            move    SR,-(SP)
            move    #$2300,SR
            movea.l #$900000,A0
            movea.l #$B0000D,A1
            lea     Super_UnknownData5,A2
            moveq   #0,D7
            movea.l OutboundGlobals,A3
            move.b  ($3C,A3),D7
            cmpi.b  #$B,D7
            blt.b   .L1
            lea     Data_F8C,A4
            bra.b   .L3
.L1:
            cmpi.b  #$9,D7
            blt.b   .L2
            lea     Data_F98,A4
            bra.b   .L3
.L2:
            lea     Data_FA2,A4
.L3:
            subq.l  #1,D7
            moveq   #0,D4
            move.b  ($B,A6),D4
            lsl.b   #5,D4
            moveq   #0,D3
            move.b  ($2E,A3),D3
            btst.l  #6,D3
            beq.b   .L4
            andi.b  #$3F,D3
            ori.b   #1,D4
            moveq   #0,D1
.L4:
            move.b  #5,$B00001
            move.b  #$6A,$B00001
            bclr.b  #5,$E0FFFE

Unknown_F56:
            moveq   #-1,D0
.L1:
            btst.b  #2,(A0)
            dbne    D0,.L1
            beq.b   .L2
            move.b  D1,(A1)
            rts
.L2:
            addq.l  #4,SP
            moveq   #0,D0
.L3:
            bset.b  #5,$E0FFFE
            move.b  #5,$B00001
            move.b  #$62,$B00001
            move    (SP)+,SR
            movem.l (SP)+,D3-D7/A2-A4
            unlk    A6
            rts
Data_F8C:
            dc.b    0,6,1,7,2,8,3,9,4,10,5,11
Data_F98:
            dc.b    0,5,1,6,2,7,3,8,4,9
Data_FA2:
            dc.b    0,4,1,5,2,6,3,7
Data_FAA:
            dc.b    255,252,243,207,63,255
Data_FB0:
            dc.b    171,85,105,181,123,85