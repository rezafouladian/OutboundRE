; Outbound Laptop Hard Disk EEPROM
;
; Rebuilds the original 11,868-byte image byte for byte with asmotor (motor68k).

            include "ROMTools/Globals.s"
            include "ROMTools/CommonConst.s"
            include "ROMTools/TrapMacros.s"
            include "ROMTools/Macros.s"
            include "ROMTools/Hardware/Outbound125.s"
            include "Plus/PlusV3.syms.s"            ; Values of the Plus_ labels in PlusV3.s
            include "SEROM/rom_SE.syms.s"           ; Values of the SE_ labels in rom_SE.s
            IF      0                               ; Never assembled: lets the editor follow Plus_/SE_ labels into the ROM sources
            include "Plus/PlusV3.s"
            include "SEROM/rom_SE.s"
            ENDC

BaseOfROM   EQU     $400000                         ; Mac Plus/SE ROM Base

            ; Patch table entry: run \2 when the traced Mac ROM PC reaches \1
PatchEntry: MACRO
            dc.w    (\1)&$FFFF,\2-PtchROMBase
            ENDM

            mc68000
            OPT     w1008                           ; Disable warning on privileged instruction
            OPT     mqy                             ; Keep ADDI/SUBI/ADD #n,Dn etc. as written, no quick or immediate rewrite
            SECTION "ROM",CODE[$F80000]

            dc.l    TROMCode                        ; Signature
            dc.l    DiagEntry                       ; Entry point
SEPatchTable:
            PatchEntry SE_CallROMCheck,SEPatch401C68 ; SE $401C68: jmp $4026C8(PC)
            PatchEntry SE_CallRAMTest,SEPatch401CC0 ; SE $401CC0: lea $401CC8(PC),A6
            PatchEntry SE_TestCopyLoop,SEPatch401D10 ; SE $401D10: move.l (A0)+,(A1)+
            PatchEntry SE_InitIWMCall,SEPatch400050 ; SE $400050: bsr.w $4004F0
            PatchEntry SE_BeepFill,SEPatch4029F8    ; SE $4029F8: movea.l A0,A4
            PatchEntry SE_BootRetry,SEPatch4000D2   ; SE $4000D2 BootRetry: move #$2700,SR
SERetryPatches:
            PatchEntry SE_GetPRAM,SEPatch400358     ; Patches left to run after BootRetry - SE $400358 GetPRAM: _InitUtil
            PatchEntry SE_InitSysZone,SEPatch4001A0 ; SE $4001A0: _InitZone
            PatchEntry SE_BootRetryInts,SEPatch4000FE ; SE $4000FE: move #$2000,SR
            PatchEntry SE_KbdVIASetup,SEPatch40331E ; SE $40331E: clr.b ($1800,A1)
            PatchEntry SE_OpenSony,SEPatch400786    ; SE $400786: lea $4007BC(PC),A1
            PatchEntry SE_AfterSonyOpen,SEPatch400790 ; SE $400790: lea $4007C2(PC),A1
            PatchEntry SE_DrawBeepScreen,SEPatch4001DA ; SE $4001DA DrawBeepScreen: pea (-4,A5)
PlusPatchTable:
            PatchEntry Plus_InitVIAB,PlusPatch400094 ; Plus $400094: move.b #$87,($400,A5)
            PatchEntry Plus_ReadClock,PlusPatch4001F8 ; Plus $4001F8: ori #$300,SR
            PatchEntry Plus_InitVIAA,PlusPatch4000CE ; Plus $4000CE: move.b D2,($1E00,A5)
            PatchEntry Plus_BootRetry,SEPatch4000D2 ; Plus $4003A8: move #$2700,SR
PlusRetryPatches:
            PatchEntry Plus_CheckCACR,PlusPatch400594 ; Patches left to run after BootRetry - Plus $400594: movec D0,CACR
            PatchEntry Plus_GetPRAM,SEPatch400358   ; Plus $4005BC: _InitUtil
            PatchEntry Plus_InitSysZone,PlusPatch400972 ; Plus $400972: _InitZone
            PatchEntry Plus_SetUnitCount,PlusPatch40087E ; Plus $40087E: move.w D0,UnitNtryCnt
            PatchEntry Plus_OpenSony,SEPatch400786  ; Plus $400894: lea $40086E(PC),A1
            PatchEntry Plus_AfterSonyOpen,SEPatch400790 ; Plus $4008A2: move.l A1,($12,A0)
            dc.w    0,0                             ; End of table
            ds.b    24
BootDiagSig:
            dc.l    TROMCode                        ; Signature
            dc.l    BootDiagEntry                   ; Entry point
            dc.b    5,'1.3b2'                       ; Outbound ROM version
            dc.w    0,$0103
; TraceHandler
; Trace exception: run the next patch when the traced PC reaches it
TraceHandler:
            move.w  D0,-(SP)
            move.w  (ExpectedPC).l,D0
            cmp.w   (6,SP),D0
            beq.b   .PCMatches
.NotYet:
            move.w  (SP)+,D0
            rte
.PCMatches:
            cmpi.w  #BaseOfROM>>16,(4,SP)
            bne.b   .NotYet
            move.w  (SP)+,D0
            move.l  A0,(-8,SP)
            movea.l (PtchTblBase).l,A0
            adda.w  (PatchOffset).l,A0
            move.l  A0,-(SP)
            movea.l (PatchTblPtr).l,A0
            move.w  (A0)+,(ExpectedPC).l
            move.w  (A0)+,(PatchOffset).l
            move.l  A0,(PatchTblPtr).l
            movea.l (-4,SP),A0
            rts
; DiagEntry
; Diagnostic-ROM entry, called early by the Plus and SE ROMs: black screen and
; logo, size RAM, tell Plus from SE by the return address in A1, start the trace
; patches, see what's on the expansion connector (docked Plus/SE, external floppy
; or SCSI adapter), then back to the ROM with tracing on
DiagEntry:
            lea     (OutboundVIA).l,A0              ; VIA port B
            moveq   #-$60,D0
            or.b    D0,(vDIRB,A0)                   ; Bits 5 and 7: outputs, high
            or.b    D0,(A0)
            move.w  #$1FFF,D0                       ; Screen black ($700000-$707FFF)
            moveq   #-1,D1
            movea.l #OutboundSndEnd,A0
.FillScreen:
            move.l  D1,-(A0)
            dbra    D0,.FillScreen
            move.l  SP,(OutboundGlobals).l                ; Save the ROM's stack
            movea.l #OutboundSndEnd,SP
            bsr.w   DrawBootLogo
            move.l  #$40000,D0                      ; Pause
.Pause:
            subq.l  #1,D0
            bne.b   .Pause
            move.w  #$171,D0                        ; Clear the sound buffer
            clr.w   D1
            movea.l #OutboundSnd,A0
.ClearSound:
            move.w  D1,(A0)+
            dbra    D0,.ClearSound
            movea.l #OutboundSndEnd,SP
            clr.w   (OutboundCfg).l
            cmpa.l  #Plus_noDiagRom,A1              ; Called from Plus $400062?
            bne.b   .SE
            move.l  #$FE000,(OutboundGlobals).l     ; Plus: stack at $FE000
            addq.l  #4,A1                           ; Resume past move #$2700,SR
            movea.l #PlusPatchTable,A6
            bra.b   .StartPatches
.SE:
            bset    #IsMacSEROM,(OutboundCfg).l
            movea.l #SE_DiagReturn,A1               ; SE: resume in StartTest1
            movea.l #SEPatchTable,A6
.StartPatches:
            move.w  (A6)+,(ExpectedPC).l            ; First patch
            move.w  (A6)+,(PatchOffset).l
            move.l  A6,(PatchTblPtr).l
            move.l  #PtchROMBase,(PtchTblBase).l
            move.w  (BaseOfROM).l,D0
            bsr.w   SizeRAM                      ; Size RAM
            btst    #ExpansionConn,(OutboundVIA).l  ; Anything on the expansion connector?
            beq.w   .ToROM
            movea.l #ExpansionROM,A0
            movep.w 0.w(A0),D0                      ; Signature at $580800 (even bytes)
            cmpi.w  #$55AA,D0                       ; $55AA/$AA55: external SCSI adapter
            beq.b   .HasSCSI
            cmpi.w  #$AA55,D0
            beq.b   .HasSCSI
            bset    #ExtFloppy,(OutboundCfg).l      ; $4BB4/$4558: external floppy drive
            cmpi.w  #$4BB4,D0
            beq.b   .ToROM
            cmpi.w  #$4558,D0
            beq.b   .ToROM
            bclr    #ExtFloppy,(OutboundCfg).l
            ori.b   #1<<HostMac|1<<CfgBit1,(OutboundCfg).l ; Otherwise docked to a Plus or SE
            move.l  #$493E0,D0
.Settle:
            subq.l  #1,D0
            bne.b   .Settle
            move.b  #1,(ExpansionCtl).l
            clr.w   (SCSI_Base).l
            moveq   #-1,D1
            move.w  #$155F,D0                       ; Host Mac's screen: black
            movea.l #ScreenLow,A0
.ClearMacScreen:
            move.l  D1,(A0)+
            dbra    D0,.ClearMacScreen
            lea     (SCSI_Base).l,A0
            move.b  ($10,A0),D0                     ; Host SCSI chip at $580010/$580040?
            or.b    ($40,A0),D0
            andi.b  #$80,D0
            bne.b   .ProbeDone
            move.b  #$80,($10,A0)
            move.b  ($10,A0),D0
            and.b   ($40,A0),D0
            andi.b  #$80,D0
            beq.b   .ProbeDone
.HasSCSI:
            bset    #SCSIPresent,(OutboundCfg).l    ; SCSI present
.ProbeDone:
            clr.b   (SCSI_ICRwrite).l
.ToROM:
            movea.l (OutboundGlobals).l,SP                ; Back to the ROM's stack
            move.l  #TraceHandler,TraceVector       ; Trace patches on
            bset    #CfgBit5,(OutboundCfg).l
            move    #$A700,SR                       ; Trace on
            jmp     (A1)
; PlusPatch4000CE
; Plus $4000CE (VIA setup): set up the VIAs and play the boot beep through the
; Outbound sound buffer (.BeepWave is shared with the SE), then run the ROM
; checksum (hang if bad), fill RAM with $FF, set up the exception vectors and
; resume at $400368
PlusPatch4000CE:
            andi.b  #$F,D2
            or.b    D2,(vBufA,A5)
            move.b  #$7F,(vDIRA,A5)                 ; VIA setup as the ROM would
            move.b  (A5),D6
            lsl.b   #4,D6
            move.b  #$7F,(vIER,A5)                  ; IER: all off
            clr.b   (vPCR,A5)
            moveq   #$28,D3
            lea     .AfterBeep,A6                         ; Return from the ROM beep
            lea     (VBase).l,A5                    ; Mac VIA
            lea     (OutboundSnd).l,A0              ; Sound buffer
.BeepWave:
            movea.l A0,A4
            move    SR,D5                           ; Interrupts on: wait a tick, else poll VBL
            andi.w  #$700,D5
            bne.b   .MaskedWait
            move.l  Ticks,D0
.WaitTick:
            cmp.l   Ticks,D0
            beq.b   .WaitTick
            bra.b   .Delay
.MaskedWait:
            moveq   #-1,D0
.PollVBL:
            btst    #1,(vIFR,A5)
            dbne    D0,.PollVBL
            move.b  #2,(vIFR,A5)
.Delay:
            move.w  #$D00,D0
.DelayLoop:
            dbra    D0,.DelayLoop
.Cycle:
            move.l  #$C006FA40,D1                   ; Waveform levels, 19 samples each
.NextLevel:
            moveq   #$13,D2
.Fill:
            move.b  D1,(A0)                         ; Every other byte of the buffer
            addq.w  #2,A0
            cmpa.l  #OutboundSndEnd,A0
            beq.b   .Full
            subq.w  #1,D2
            bne.b   .Fill
            lsr.l   #8,D1
            bne.b   .NextLevel
            bra.b   .Cycle
.Full:
            btst    #IsMacSEROM,(OutboundCfg).l
            beq.b   .PlusBeep                            ; SE: finish BootBeep, then SEPatch4029F8.SoundOff
            pea     SEPatch4029F8.SoundOff
            jmp     (SE_BeepLoop).l
.PlusBeep:
            jmp     (Plus_BeepLoop).l               ; Plus: finish the ROM beep
.AfterBeep:
            bset    #7,(A5)                         ; Sound off
            andi.w  #$7FFF,(SP)                     ; Tracing off
            lea     .Hang,A6
            jmp     (Plus_CheckROM).l               ; ROM checksum
.Hang:
            bne.b   .Hang                            ; Hang if it failed
            movea.l A3,A0                           ; Fill RAM with $FF
            moveq   #-1,D1
            sub.l   A3,D0
            lsr.l   #2,D0
.FillRAM:
            move.l  D1,(A0)+
            subq.l  #1,D0
            bne.b   .FillRAM
            lea     .Resume,A6
            jmp     (Plus_InitExcVectors).l         ; Exception vectors
.Resume:
            move.w  #$2700,(SP)
            move.l  #Plus_CheckDiagROM2,(2,SP)      ; Resume at $400368, interrupts off
            rte
; SEPatch401C68
; SE $401C68 (StartTest1): run the ROM checksum at $4026C8 without tracing, then
; continue after the jmp
SEPatch401C68:
            lea     .Done,A6
            jmp     (SE_ROMCheck).l
.Done:
            addq.w  #4,(4,SP)
            rte
; Patch401CEC
; SE $401CEC (OutboundCfg bit 3): skip the jmp $402928 and stop tracing
Patch401CEC:
            addq.w  #4,(4,SP)
            andi.w  #$7FFF,(SP)
            rte
; Patch402602
; SE $402602 (OutboundCfg bit 3): give the RAM test loop the EEPROM's own 5-entry
; table (A0 codes, A3 sizes), then arm Patch401CEC
Patch402602:
            lea     .Codes,A0
            lea     .Sizes,A3
            move.w  #(SE_CallMemSize)&$FFFF,(ExpectedPC).l
            move.w  #Patch401CEC-PtchROMBase,(PatchOffset).l
            rte
.Codes:
            dc.w    $1820,$2830,$40FF               ; Codes, $FF ends
.Sizes:
            dc.w    $0010,0,$0010,0,$0020,0,$0020   ; 1 MB, 1 MB, 2 MB, 2 MB, 0
            ds.b    6
; SEPatch401CC0
; SE $401CC0 (StartTest1): run the RAM test at $4026F0 without tracing; with
; OutboundCfg bit 3, arm Patch402602 and skip SEPatch401D10
SEPatch401CC0:
            lea     .Done,A6
            jmp     (SE_RAMTest).l
.Done:
            addq.w  #8,(4,SP)
            move.l  #TraceHandler,TraceVector
            btst    #HostMac,(OutboundCfg).l
            beq.b   .Return
            move.w  #(SE_SizeTableLoop)&$FFFF,(ExpectedPC).l ; Next: Patch402602, skipping SEPatch401D10
            move.w  #Patch402602-PtchROMBase,(PatchOffset).l
            addq.l  #4,(PatchTblPtr).l
.Return:
            rte
; SEPatch401D10
; SE $401D10: run this copy loop without tracing, then continue at $400048
SEPatch401D10:
            move.l  (A0)+,(A1)+
            dbra    D0,SEPatch401D10
            move.w  #(SE_StartInit1)&$FFFF,(4,SP)
            move.l  #TraceHandler,TraceVector
            rte
; SEPatch400050
; SE $400050 (StartInit1): in place of InitIWM, InitSCSI and WhichCPU, set VIA
; port B for the Outbound (no IWM), run InitSCSI only with OutboundCfg bit 2, then
; WhichCPU
SEPatch400050:
            move.w  #(SE_AfterWhichCPU)&$FFFF,(4,SP) ; Skip InitIWM, InitSCSI, WhichCPU
            btst    #HostMac,(OutboundCfg).l
            bne.b   .CheckSCSI
            move.b  #$F7,(VBase+vDIRB).l            ; VIA port B: $F7
            move.b  #$F7,(VBase).l
.CheckSCSI:
            btst    #SCSIPresent,(OutboundCfg).l
            beq.b   .WhichCPU
            jsr     (SE_InitSCSI).l                 ; InitSCSI
.WhichCPU:
            jsr     (SE_WhichCPU).l                 ; WhichCPU
            rte
; SEPatch4029F8
; SE $4029F8 (BootBeep): play the beep through PlusPatch4000CE.BeepWave and the
; Outbound sound buffer; .SoundOff runs when it's done
SEPatch4029F8:
            movea.l #OutboundSnd,A0                 ; Sound buffer
            move.l  #PlusPatch4000CE.BeepWave,(2,SP)      ; Into the shared beep
            andi.w  #$7FFF,(SP)                     ; Tracing off
            rte
.SoundOff:
            bset    #7,(OutboundVIA).l              ; Sound off
            rts
; PlusPatch400094
; Plus $400094: VIA port B direction and data $E7 instead of $87 (with OutboundCfg
; bit 3, keep the ROM's and stop tracing)
PlusPatch400094:
            btst    #HostMac,(OutboundCfg).l
            beq.b   .OutboundVIA
            andi.w  #$7FFF,(SP)                     ; Bit 3: keep the ROM's, stop tracing
            rte
.OutboundVIA:
            move.b  #$E7,(vDIRB,A5)                 ; VIA port B: $E7
            move.b  #$E7,(A5)
            move.w  #(Plus_AfterVIAB)&$FFFF,(4,SP)  ; Continue at $40009E
            rte
; PlusPatch4001F8
; Plus $4001F8: skip the ROM's clock-chip access, to $400252
PlusPatch4001F8:
            move.w  #(Plus_ReadClockEnd)&$FFFF,(4,SP) ; Continue at $400252
            rte
; BootDiagEntry
; Second diag-ROM entry ($55AAAA55 at $F80080), called by the Plus at $400368
; and probed by the SE at $4000B8: tracing back on. SE: preset TimeDBRA and
; TimeSCCDB and continue at $4000CE. Plus: continue at $40037E, skipping
; PlusPatch400594 with OutboundCfg bit 3
BootDiagEntry:
            move.l  #TraceHandler,TraceVector
            move    #$A700,SR                       ; Trace on
            btst    #IsMacSEROM,(OutboundCfg).l
            beq.b   .Plus
            move.l  #$4EA013D,TimeDBRA              ; SE: TimeDBRA $4EA, TimeSCCDB $13D
            btst    #HostMac,(OutboundCfg).l
            bne.b   .SEStart
            move.w  #$206,TimeSCCDB                 ; Outbound: TimeSCCDB $206
.SEStart:
            jmp     (SE_CallInitHiMem).l            ; SE: continue at $4000CE
.Plus:
            btst    #HostMac,(OutboundCfg).l
            beq.b   .PlusStart
            movea.l (PatchTblPtr).l,A0
            addq.l  #4,A0                           ; Skip PlusPatch400594
            move.w  (A0)+,(ExpectedPC).l
            move.w  (A0)+,(PatchOffset).l
            move.l  A0,(PatchTblPtr).l
.PlusStart:
            jmp     (Plus_NoDiagROM2).l             ; Plus: continue at $40037E
; SEPatch4000D2
; BootRetry (SE $4000D2, Plus $4003A8): copy the 16K image to RAM at $1400
; (Plus) or $1600 (SE) and run from there; its globals and the floppy cache
; follow the copy
SEPatch4000D2:
PlusPatch4003A8:
            addq.w  #4,(4,SP)                       ; Past move #$2700,SR
            movem.l D0/A0-A1,-(SP)
            movea.l #PtchROMBase,A0
            movea.w #$1400,A1                       ; Plus: copy to $1400
            btst    #IsMacSEROM,(OutboundCfg).l
            beq.b   .CopyTo
            movea.w #$1600,A1                       ; SE: to $1600
.CopyTo:
            move.l  A1,(PtchTblBase).l              ; Patches run from the copy
            move.l  #$FFF,D0
.Copy:
            move.l  (A0)+,(A1)+
            dbra    D0,.Copy
            move.l  A1,(OutboundGlobals).l          ; Globals after the copy
            movea.l (PtchTblBase).l,A0
            adda.w  #TraceHandler-PtchROMBase,A0    ; TraceHandler in the copy
            move.l  A0,TraceVector
            move.l  #FlpCacheBuf+$4800,D0
.Clear:
            clr.b   (A1)+
            subq.l  #1,D0
            bne.b   .Clear
            movem.l (SP)+,D0/A0-A1
            rte
; PlusPatch400594
; Plus $400594 (movec in the CPU check): skip it, point the level-1 autovector
; at PlusLev1Intr and set OutboundCfg bit 5
PlusPatch400594:
            pea     PlusLev1Intr
            move.l  (SP)+,Lev1AutoVector            ; Level-1 autovector
            move.w  #(Plus_NoCACR)&$FFFF,(4,SP)     ; Skip the movec
            bset    #CfgBit5,(OutboundCfg).l
            rte
; SEPatch400358
; _InitUtil (SE $400358 GetPRAM, Plus $4005BC): install the clock and PRAM traps
; (not with OutboundCfg bit 3), then put a stub in front of the Line-A handler that
; turns tracing back on at every A-trap
SEPatch400358:
PlusPatch4005BC:
            bset    #CfgBit5,(OutboundCfg).l
            btst    #HostMac,(OutboundCfg).l
            bne.b   .TraceTraps
            bsr.w   InstallRTCTraps                 ; Clock and PRAM traps
.TraceTraps:
            move.l  A0,-(SP)
            movea.l (OutboundGlobals).l,A0
            adda.w  #$D2,A0
            move.l  LineAVector,-(A0)               ; Stub at OutboundGlobals+$C8: ori #$8000,SR; jmp old
            move.w  #$4EF9,-(A0)
            move.l  #$7C8000,-(A0)
            move.l  A0,LineAVector                  ; Line-A through the stub
            movea.l (SP)+,A0
            rte
; SEPatch4001A0
; SE $4001A0 (SetUpSysAppZone): _InitZone parameters that start the system heap
; after the EEPROM's RAM copy and globals
SEPatch4001A0:
            lea     PlusPatch400972.SEZone,A0           ; SE heap parameters
            rte
; SEPatch40331E
; SE $40331E (KBDMngr): skip the ADB hardware setup and fill in the ADB globals
; instead, then continue at $403366
SEPatch40331E:
            bset    #2,($15D,A3)                    ; ADB globals
            lea     ($C0,A3),A0
            move.l  A0,($13C,A3)
            move.l  A0,($144,A3)
            move.l  A0,($148,A3)
            lea     ($130,A3),A0
            move.l  A0,($140,A3)
            lea     ($164,A3),A0
            move.l  A0,($130,A3)
            move.l  #SE_KbdComplete,($134,A3)
            move.w  #(SE_KBDMngrCont)&$FFFF,(4,SP)  ; Continue at $403366
            rte
; PlusPatch400972
; Plus $400972: _InitZone parameters for the system heap, starting after the
; EEPROM's RAM copy and globals ($1400 + $4000 + $4940 = $9D40; $9F40 on the SE)
PlusPatch400972:
            lea     .PlusZone,A0
            rte
.PlusZone:
            dc.w    0,$9D40,$0003,$2740,$0020       ; Plus: start $9D40, limit $32740, 32 masters
            ds.b    4
.SEZone:
            dc.w    0,$9F40,$0003,$2940,$0040       ; SE: start $9F40, limit $32940, 64
            ds.b    4
; PlusPatch40087E
; Plus $40087E: UnitNtryCnt = 64, so units 48-50 (.Super's other slot, .RAMd,
; .PTek) exist
PlusPatch40087E:
            moveq   #$40,D0                         ; 64 unit table entries
            rte
; SEPatch400786
; Sony setup: unless OutboundCfg bit 3, skip the ROM's IWM setup but still allocate
; SonyVars
SEPatch400786:
PlusPatch400894:
Patch400786:
            btst    #IsMacSEROM,(OutboundCfg).l
            bne.b   .SonySetup
            bset    #7,HWCfgFlags
            btst    #HostMac,(OutboundCfg).l
            beq.b   .PlusNoBit3
            pea     PlusKbdIntr
            move.l  (SP)+,($19A).w                  ; OutboundCfg bit 3 (Plus): keep the ROM keyboard handler, through PlusKbdIntr
            bra.b   .SonySetup
.PlusNoBit3:
            cmpi.b  #$67,(Plus_SCSILoadCheck).l
            bne.b   .MoveScreen
            move.b  #$80,HWCfgFlags
.MoveScreen:
            bsr.w   MoveScreen
.SonySetup:
            btst    #HostMac,(OutboundCfg).l
            bne.w   .SetupDone
            addi.w  #$A,(4,SP)                      ; Skip the ROM's Sony hardware setup
            movem.l D0-D2/A0-A1,-(SP)
            movea.l LineAVector,A0
            move.l  A0,-(SP)
            move.l  (6,A0),LineAVector              ; Bypass the trace stub while calling traps
            move.l  #$310,D0
            btst    #IsMacSEROM,(OutboundCfg).l
            beq.b   .AllocSonyVars
            addi.l  #$34,D0
.AllocSonyVars:
            _NewPtrSysClear                         ; SonyVars: $310 bytes, $344 on the SE
            move.l  A0,SonyVars
            lea     ($118,A0),A0
            _InsTime                                ; Sony time manager task at SonyVars+$118
            btst    #ExtFloppy,(OutboundCfg).l      ; External floppy: load its EXTD module from ExpansionROM
            beq.b   .EXTDDone
            movea.l #ExpansionROM,A1
            movep.l 0.w(A1),D0                      ; Signature, read from every other byte
            cmpi.l  #'EXTD',D0
            bne.b   .EXTDDone
            movep.l (8,A1),D0                       ; Length to copy
            move.l  D0,D1
            movep.l ($10,A1),D2                     ; Extra zeroed space after it
            add.l   D2,D0
            _NewPtrSysClear                         ; Room for both
            bne.b   .EXTDDone
            move.l  A0,-(SP)
            movep.l ($18,A1),D0                     ; Offset of the code in the module
            lsl.l   #1,D0
            movea.l #ExpansionROM,A1
            adda.l  D0,A1
            clr.b   D2
.CopyEXTD:
            movep.l 0.w(A1),D0                      ; 4 bytes from every other address
            move.l  D0,(A0)+
            lea     (8,A1),A1
            cmpa.l  #ExpansionROM+$800,A1           ; End of the $800-byte window: next bank
            bne.b   .NextLong
            movea.l #ExpansionROM,A1
            addq.b  #8,D2
            move.b  D2,(ExpansionBank).l            ; Bank select
.NextLong:
            subq.l  #4,D1
            bgt.b   .CopyEXTD
            clr.b   (ExpansionBank).l               ; Back to bank 0
            movea.l (SP)+,A0
            move.w  #$11BC,($BB0,A0)                ; Patch the loaded code
            move.b  #$FB,($45,A0)
            move.b  #$10,($53,A0)
            jsr     (A0)                            ; Run it
.EXTDDone:
            move.l  (SP)+,LineAVector               ; Trace stub back
            movem.l (SP)+,D0-D2/A0-A1
.SetupDone:
            btst    #SCSIPresent,(OutboundCfg).l
            bne.b   .Return
            bset    #7,HWCfgFlags
            pea     SCSIDispatchStub
            move.l  (SP)+,($E54).w
.Return:
            ori     #$8000,SR
            rte
; SEPatch4000FE
; SE $4000FE (move #$2000,SR in BootRetry): keep tracing on. With OutboundCfg bit 3,
; also run KBDMngr ($403306) untraced and skip SEPatch40331E
SEPatch4000FE:
            addq.w  #4,(4,SP)
            move.w  #$A000,(SP)                     ; Trace on, interrupts on
            btst    #HostMac,(OutboundCfg).l
            beq.b   .Return
            addq.w  #4,(4,SP)                       ; Bit 3: also skip the jsr
            move    #$2000,SR
            jsr     (SE_KBDMngr).l                  ; KBDMngr, untraced
            move.w  #(SE_OpenSony)&$FFFF,(ExpectedPC).l ; Next: Patch400786, skipping SEPatch40331E
            move.w  #Patch400786-PtchROMBase,(PatchOffset).l
            addq.l  #4,(PatchTblPtr).l
.Return:
            rte
; SCSIDispatchStub
; SCSIDispatch replacement, put at $E54 (its entry in a toolbox trap table at
; $E00) when there is no SCSI: pops the selector's arguments and returns 2
; (scCommErr), or 0 for an unknown selector
SCSIDispatchStub:
            movea.l (SP)+,A0                        ; Return address
            move.w  (SP)+,D0                        ; Selector
            moveq   #0,D1
            cmpi.w  #0,D0
            beq.b   .Known
            cmpi.w  #1,D0
            beq.b   .Known
            cmpi.w  #$A,D0
            beq.b   .Known
            moveq   #2,D1
            cmpi.w  #2,D0
            beq.b   .Known
            moveq   #6,D1
            cmpi.w  #3,D0
            beq.b   .Known
            moveq   #$C,D1
            cmpi.w  #9,D0
            beq.b   .Known
            moveq   #4,D1
            cmpi.w  #4,D0
            beq.b   .Known
            cmpi.w  #5,D0
            beq.b   .Known
            cmpi.w  #6,D0
            beq.b   .Known
            cmpi.w  #8,D0
            beq.b   .Known
            moveq   #0,D1                           ; Unknown selector: result 0
            adda.l  D1,SP
            moveq   #0,D0
            move.w  D0,(SP)
            jmp     (A0)
.Known:
            adda.l  D1,SP
            moveq   #2,D0                           ; scCommErr
            move.w  D0,(SP)
            jmp     (A0)
; PlusKbdIntr
; OutboundCfg bit 3: ROM keyboard interrupt, other path when shifting out
PlusKbdIntr:
            btst    #4,(vACR,A1)
            bne.b   .ShiftingOut
            jmp     (Plus_KbdIntRead).l
.ShiftingOut:
            move.b  #4,(vIFR,A1)
            move.w  #$190,D0
            jmp     (Plus_KbdIntDelay).l
; SEPatch400790
; After Sony setup: probe the floppy controller and hard disk, install .RAMd and
; .PTek
SEPatch400790:
PlusPatch4008A2:
            andi.w  #$7FFF,(SP)
            movem.l D0-D2/A0-A1,-(SP)
            movea.l LineAVector,A0
            move.l  A0,-(SP)
            move.l  (6,A0),LineAVector              ; Bypass the trace stub while calling traps
            movea.l #FDCControl,A0
            lea     (-8,A0),A1
            moveq   #-$80,D0
            moveq   #0,D1
            move.b  D0,(A0)                         ; $CC0010: reset the floppy controller
            move.b  (A1),D2
            move.b  D1,(A0)
            move.b  (A1),D2
            move.b  D1,(A1)
            move.b  #$14,(A0)                       ; Release reset, motor on
            movea.l #FDCStatus,A0
            moveq   #7,D0
            btst    D0,(A0)                         ; Ready bit already set: nothing there
            bne.b   .NoFDC
            moveq   #$1E,D1
.WaitFDCReady:
            subq.l  #1,D1
            beq.b   .NoFDC
            btst    D0,(A0)
            beq.b   .WaitFDCReady
            bset    #Cfg2Bit0,(OutboundCfg2).l      ; Floppy controller found (no driver in this image)
.NoFDC:
            bsr.w   InstallRAMdDrvr                      ; Install .RAMd
            move.l  #$989680,D0
.WaitATANotBusy:
            cmpi.b  #$80,(ATAStatus).l              ; ATA status: wait for BSY to clear
            bne.b   .ATATries
            subq.l  #1,D0
            bne.b   .WaitATANotBusy
.ATATries:
            moveq   #$A,D0
.CheckATAStatus:
            moveq   #-$13,D1
            and.b   (ATAStatus).l,D1                ; Status without IDX and DSC: DRDY only?
            cmpi.b  #$40,D1
            beq.b   .ATAFound
            subq.l  #1,D0
            bne.b   .CheckATAStatus
            bra.b   .ProbeDone
.ATAFound:
            bset    #HDPresent,(OutboundCfg2).l     ; Hard disk found
            bsr.w   InstallPTekDrvr
.ProbeDone:
            move.l  (SP)+,LineAVector               ; Trace stub back
            lea     (VBase).l,A0
            move.b  #$20,(vIFR,A0)                  ; Clear the VIA T2 flag
            btst    #IsMacSEROM,(OutboundCfg).l
            beq.b   .TracePlus
            btst    #HostMac,(OutboundCfg).l
            bne.b   .TraceSE
            ori.w   #$8000,(4,SP)
            bra.b   .Return
.TraceSE:
            move.l  #SE_GenTrace,TraceVector        ; SE: ROM trace handler
.HookLineA:
            bsr.b   HookLineA
.Return:
            movem.l (SP)+,D0-D2/A0-A1
            rte
.TracePlus:
            move.l  #Plus_GenTrace,TraceVector      ; Plus: ROM trace handler
            bra.b   .HookLineA
; HookLineA
; Put LineAHook in front of the Line-A handler; SavedLineA keeps the real one
; (behind the trace stub)
HookLineA:
            movea.l LineAVector,A0
            movea.l (6,A0),A0                       ; Real handler behind the trace stub
            move.l  A0,(SavedLineA).l
            lea     LineAHook,A0
            move.l  A0,LineAVector                  ; LineAHook in front
            rts
; SEPatch4001DA
; SE $4001DA (DrawBeepScreen): hook Line-A, move the screen, take over keyboard
; and mouse, give the trace vector back to the ROM, no ADB
SEPatch4001DA:
            andi.w  #$7FFF,(SP)
            movem.l D0-D7/A0-A6,-(SP)
            bsr.b   HookLineA
            bsr.w   MoveScreen                      ; Outbound screen
            bsr.w   InitKbd                      ; Take over keyboard and mouse
            move.l  #SE_GenTrace,TraceVector        ; ROM trace handler
            move.w  HWCfgFlags,D0
            bclr    #$A,D0                          ; No ADB
            move.w  D0,HWCfgFlags
            lea     CountADBsStub,A0                   ; CountADBs: 0 devices
            move.w  #$77,D0
            _SetOSTrapAddress
            lea     GetIndADBStub,A0                   ; GetIndADB: -1
            move.w  #$78,D0
            _SetOSTrapAddress
            movem.l (SP)+,D0-D7/A0-A6
            rte
; GetIndADBStub
; GetIndADB replacement: always -1
GetIndADBStub:
            moveq   #-1,D0
            rts
; CountADBsStub
; CountADBs replacement: no ADB devices
CountADBsStub:
            moveq   #0,D0
            rts
; PlusDiskIconTrap
; _HideCursor at Plus $4007CE (the ROM's disk icon routine): run
; PlusDrawDiskIcon instead
PlusDiskIconTrap:
            lea     PlusDrawDiskIcon,A0
            move.l  A0,($3E,SP)
            movem.l (SP)+,D0-D7/A0-A6
            rte
; PlusDrawDiskIcon
; Plus: draw the disk icon and its overlay (D7) on the Outbound screen, or let
; the ROM do it with OutboundCfg bit 3. After the first call ($4006DE) reorder the
; drive queue so the default startup device (XPRAM $78) is the first non-floppy
; drive
PlusDrawDiskIcon:
            move.l  #$40000,D0                      ; Pause
.Pause:
            subq.l  #1,D0
            bne.b   .Pause
            _HideCursor
            move.l  Ticks,D0
.WaitTick:
            cmp.l   Ticks,D0
            beq.b   .WaitTick
            movea.l #Plus_DiskIcon,A4               ; ROM disk icon
            movea.l #OutboundDisp+$3136,A2          ; Center of the Outbound screen
            btst    #HostMac,(OutboundCfg).l
            beq.b   .Draw
            movea.l #ScreenLow+$245E,A2             ; Bit 3: Mac screen position
.Draw:
            lea     .Overlay,A6
            btst    #HostMac,(OutboundCfg).l
            beq.w   OBPutIcon                   ; Draw it here
            jmp     (Plus_PutIcon).l                     ; Bit 3: the ROM's PutIcon
.Overlay:
            tst.w   D7                              ; Overlay?
            beq.b   .ShowCursor
            movea.l #OutboundDisp+$35E7,A2
            btst    #HostMac,(OutboundCfg).l
            beq.b   .DrawOverlay
            movea.l #ScreenLow+$281F,A2
.DrawOverlay:
            movea.l D7,A4
            moveq   #$E,D2
            lea     .ShowCursor,A6
            btst    #HostMac,(OutboundCfg).l
            beq.w   OBPutOverlay.Rows
            jmp     (Plus_PutOverlayRows).l
.ShowCursor:
            _ShowCursor
            cmpi.l  #Plus_DiskIconReturn,(SP)       ; First call (boot start)?
            bne.b   .Return
            subq.l  #4,SP
            movea.l SP,A0
            move.l  #$40078,D0                      ; XPRAM $78: default startup device
            _ReadXPRam
            move.l  (SP)+,D3
            move.l  ($30A).w,D0                     ; Drive queue
            beq.b   .Return
.FindDefault:
            movea.l D0,A0
            cmp.w   (8,A0),D3                       ; Its driver in the queue?
            beq.b   .Scan
            move.l  (A0),D0
            bne.b   .FindDefault
            bra.b   .Return
.Scan:
            move.l  ($30A).w,D0
.NextDrive:
            movea.l D0,A0
            cmpi.w  #4,(6,A0)                       ; Skip floppies (drive < 4)
            bge.b   .MoveToEnd
            move.l  (A0),D0
            bne.b   .NextDrive
            bra.b   .Return
.MoveToEnd:
            cmp.w   (8,A0),D3                       ; First non-floppy is the default: done
            beq.b   .Return
            movea.l A0,A2                           ; Else move it to the end, look again
            lea     DrvQHdr,A1
            _Dequeue
            movea.l A2,A0
            lea     DrvQHdr,A1
            _Enqueue
            bra.b   .Scan
.Return:
            rts
; PlusHappyMacTrap
; _HideCursor at Plus $40073E (good boot blocks): a drive not in BootMask is
; ejected and the next one tried; otherwise draw the happy Mac
; (PlusDrawHappyMac, or the ROM with OutboundCfg bit 3)
PlusHappyMacTrap:
            move.w  BootMask,D0
            btst    D3,D0                           ; Drive in BootMask?
            bne.b   .Bootable
            movea.l #Plus_EjectNoRetry,A0           ; No: eject it and try the next
            clr.l   (4,SP)                          ; Saved D1 = 0: no retry after the eject
            bra.b   .Resume
.Bootable:
            _HideCursor
            movea.l #Plus_HappyMacIcon,A0           ; ROM's happy Mac
            btst    #HostMac,(OutboundCfg).l
            bne.b   .Resume
            lea     PlusDrawHappyMac,A0                   ; Ours
.Resume:
            move.l  A0,($3E,SP)
            movem.l (SP)+,D0-D7/A0-A6
            rte
; PlusDrawHappyMac
; Plus: the happy Mac on the Outbound screen, then back to the ROM at $40074C
PlusDrawHappyMac:
            movem.l A5-A6,-(SP)
            movea.l #Plus_HappyMacDone,A5           ; Back into the ROM
            bra.w   OBDrawHappyMac
; SEDiskIconTrap
; _HideCursor at SE $400F3A (PlotDisk): run SEDrawDiskIcon instead
SEDiskIconTrap:
            lea     SEDrawDiskIcon,A0
            move.l  A0,($3E,SP)
            movem.l (SP)+,D0-D7/A0-A6
            rte
; SEDrawDiskIcon
; SE PlotDisk for the Outbound screen: the disk icon at $400FB2 and the overlay
; in D7
SEDrawDiskIcon:
            moveq   #1,D0
.Pause:
            subq.l  #1,D0
            bne.b   .Pause
            _HideCursor
            move.l  Ticks,D0
.WaitTick:
            cmp.l   Ticks,D0
            beq.b   .WaitTick
            movea.l #SE_DiskIcon,A4                 ; ROM disk icon
            movea.l #OutboundDisp+$3136,A2          ; Center of the screen
            lea     .Overlay,A6
            bra.w   OBPutIcon
.Overlay:
            tst.w   D7
            beq.b   .Done
            movea.l #OutboundDisp+$35E7,A2
            movea.l D7,A4
            moveq   #$E,D2
            lea     .Done,A6
            bra.w   OBPutOverlay.Rows
.Done:
            _ShowCursor
            movem.l (SP)+,D3-D7/A2-A6
            rts
; SEHappyMacTrap
; _HideCursor at SE $400E72 (ShowSuccess): a drive not in BootMask goes back to
; FindStartupDevice ($400CBE); otherwise draw the happy Mac (SEDrawHappyMac, or
; the ROM with OutboundCfg bit 3)
SEHappyMacTrap:
            move.w  (6,A2),D3                       ; Drive number
            move.w  BootMask,D0                     ; In BootMask?
            btst    D3,D0
            bne.b   .Bootable
            movea.l #SE_SkipDrive,A0                ; No: FindStartupDevice moves on
            bra.b   .Resume
.Bootable:
            _HideCursor
            movea.l #SE_HappyMacIcon,A0             ; ROM's happy Mac
            btst    #HostMac,(OutboundCfg).l
            bne.b   .Resume
            lea     SEDrawHappyMac,A0
.Resume:
            move.l  A0,($3E,SP)
            movem.l (SP)+,D0-D7/A0-A6
            rte
; SEDrawHappyMac
; SE ShowSuccess for the Outbound screen
SEDrawHappyMac:
            movem.l A5-A6,-(SP)
            lea     (SE_HappyFace).l,A0             ; Face
            movea.l A6,A5
            lea     (SE_MacIcon).l,A4               ; Mac icon
            move.l  A0,D5
            movea.l #OutboundDisp+$3136,A2
            lea     .Face,A6
            bra.b   OBPutIcon
.Face:
            movea.l #OutboundDisp+$3317,A2
            movea.l D5,A4
            lea     .Done,A6
            bra.b   OBPutOverlay
.Done:
            movem.l (SP)+,A5-A6
            rts
; SEDefaultStartup
; _GetDefaultStartup at SE $400D08: if a floppy (drive 1-3, ahead of the other
; drives) has a disk, return no default so it boots first; otherwise ask
; _GetDefaultStartup
SEDefaultStartup:
            movea.l ($20,SP),A0                     ; Saved A0: result
            clr.l   (A0)                            ; No default
            move.l  ($30A).w,D0
            beq.b   .UseDefault
.NextDrive:
            movea.l D0,A1
            cmpi.w  #4,(6,A1)                       ; Floppies (drive < 4) come first
            bge.b   .UseDefault
            tst.b   (-3,A1)                         ; Disk in place
            bne.b   .Resume
            move.l  (A1),D0
            bne.b   .NextDrive
.UseDefault:
            _GetDefaultStartup                      ; None: ask for the default
.Resume:
            move.l  #SE_GotDefault,($3E,SP)         ; Continue at $400D0A
            movem.l (SP)+,D0-D7/A0-A6
            rte
; OBDrawHappyMac
; The Plus ROM's happy Mac (icon $400F3E, face $400FD2) on the Outbound screen;
; returns through A5
OBDrawHappyMac:
            movea.l #Plus_MacIcon,A4                ; Mac icon
            lea     ($94,A4),A0                     ; Face
            move.l  A0,D7
            movea.l #OutboundDisp+$3136,A2          ; Center of the screen
            lea     .Face,A6
            bra.b   OBPutIcon
.Face:
            movea.l #OutboundDisp+$3317,A2          ; Face position
            movea.l D7,A4
            lea     .Return,A6
            bra.b   OBPutOverlay
.Return:
            RTS5
; OBPutOverlay
; Copy D2+1 rows of 2 bytes from A4 to the screen at A2 (80-byte rows): 10 rows
; from here, D2 preset from .Rows; returns through A6
OBPutOverlay:
            moveq   #9,D2                           ; 10 rows
.Rows:
            move.b  (A4)+,(A2)+
            move.b  (A4)+,(A2)+
            adda.w  #$4E,A2                         ; Next row
            dbra    D2,.Rows
            RTS6
; OBPutIcon
; The ROM's PutIcon for 80-byte rows: unpack a compressed 32x32 icon from A4 to
; the screen at A2; returns through A6
OBPutIcon:
            moveq   #$F,D3                          ; 16 groups of 4 bytes
            movea.l A2,A0
            moveq   #3,D2
.NextGroup:
            move.w  #$100,D4
            move.b  (A4)+,D4                        ; Bitmask: 1 = zero byte, 0 = literal
.NextBit:
            lsr.w   #1,D4
            beq.b   .GroupDone
            bcc.b   .Literal
            clr.b   (A2)+
            bra.b   .Count
.Literal:
            move.b  (A4)+,(A2)+
.Count:
            dbra    D2,.NextBit
            adda.w  #$4C,A2                         ; Next row
            moveq   #3,D2
            bra.b   .NextBit
.GroupDone:
            dbra    D3,.NextGroup
            movea.l A0,A1                           ; XOR each row into the next
            moveq   #$1E,D3
.XorRows:
            adda.w  #$50,A1
            move.l  (A0),D4
            eor.l   D4,(A1)
            movea.l A1,A0
            dbra    D3,.XorRows
            RTS6
; LineAHook
; Line-A hook while booting: move the boot icons, the system alert box (also
; "Welcome to Macintosh") and the full-screen boot CopyBits to the 640x400
; screen, keep SCSIDispatch stubbed, stay installed when the System sets a new
; Line-A handler, and unhook once INITs load (at _SizeRsrc with SCSI)
LineAHook:
            movem.l D0-D7/A0-A6,-(SP)
            movea.l ($3E,SP),A0                     ; Trap address
            btst    #IsMacSEROM,(OutboundCfg).l
            bne.b   .SE
            cmpa.l  #Plus_EjectFailed,A0            ; Plus: eject after a failed boot
            beq.w   .EjectRetry
            cmpa.l  #Plus_ShowHappyMac,A0           ; Plus: happy Mac
            beq.w   PlusHappyMacTrap
            cmpa.l  #Plus_PlotDisk,A0               ; Plus: disk icon
            beq.w   PlusDiskIconTrap
            btst    #HostMac,(OutboundCfg).l
            bne.b   .PlusIcon
            cmpi.w  #$A86E,(A0)                     ; _InitGraf
            bne.b   .PlusAlert
            bsr.w   InitKbd                      ; Plus: _InitGraf takes over keyboard and mouse
            bra.w   .OtherTraps
.PlusAlert:
            cmpa.l  #Plus_DSDrawBox,A0              ; Plus: alert box
            bne.b   .PlusText
            bra.b   .AlertBox
.PlusText:
            cmpa.l  #Plus_DSDrawText,A0             ; Plus: alert text
            bne.b   .PlusIcon
            bra.b   .ShiftText
.PlusIcon:
            cmpa.l  #Plus_DSDrawIcon,A0             ; Plus: alert icon
            bne.b   .PlusCopyBits
            bra.b   .ShiftIcon
.PlusCopyBits:
            cmpa.l  #Plus_BootCopyBits,A0           ; Plus: full-screen CopyBits
            bne.w   .OtherTraps
            bra.w   .CenterScreen
.SE:
            cmpa.l  #SE_GetDefault,A0               ; SE: _GetDefaultStartup
            beq.w   SEDefaultStartup
            cmpa.l  #SE_EjectFailed,A0              ; SE: eject after a failed boot
            beq.w   .EjectRetry
            cmpa.l  #SE_ShowSuccess,A0              ; SE: happy Mac
            beq.w   SEHappyMacTrap
            btst    #HostMac,(OutboundCfg).l
            bne.b   .SEIcon
            cmpa.l  #SE_PlotDiskHide,A0             ; SE: disk icon
            beq.w   SEDiskIconTrap
            cmpa.l  #SE_DSDrawBox,A0                ; SE: alert box
            bne.b   .SEText
.AlertBox:
            movea.l ($20,SP),A0                     ; Alert box rect (saved A0)
            move.l  #$600060,(A0)                   ; 448x126 at (96,96): 64 right, 32 down
            move.l  #$DE0220,(4,A0)
            movea.l ($3E,SP),A0
            bra.b   .OtherTraps
.SEText:
            cmpa.l  #SE_DSDrawText,A0               ; SE: alert text
            bne.b   .SEIcon
.ShiftText:
            addi.l  #$200040,($42,SP)               ; MoveTo: 64 right, 32 down
            bra.b   .OtherTraps
.SEIcon:
            cmpa.l  #SE_DSDrawIcon,A0               ; SE: alert icon
            bne.b   .SECopyBits
.ShiftIcon:
            bclr    #CfgBit5,(OutboundCfg).l        ; Startup screen or alert drawn: bit 5 off
            btst    #HostMac,(OutboundCfg).l
            bne.b   .OtherTraps
            movea.l ($20,SP),A0
            addi.l  #$200040,(A0)                   ; Icon rect: 64 right, 32 down
            addi.l  #$200040,(4,A0)
            movea.l ($3E,SP),A0
            bra.b   .OtherTraps
.SECopyBits:
            cmpa.l  #SE_BootCopyBits,A0             ; SE: full-screen CopyBits
            bne.b   .OtherTraps
.CenterScreen:
            bclr    #CfgBit5,(OutboundCfg).l
            btst    #HostMac,(OutboundCfg).l
            bne.b   .OtherTraps
            move.w  #$40,($5C,SP)
            pea     .ScreenRect                            ; Destination rect: centered
            move.l  (SP)+,($48,SP)
            bra.b   .OtherTraps
.ScreenRect:
            dc.w    $001D,$0040,$0173,$0240         ; 512x342 at (64,29)
.OtherTraps:
            btst    #HostMac,(OutboundCfg).l
            bne.b   .SizeRsrc
            cmpi.w  #$A647,(A0)                     ; _SetToolBoxTrapAddress of SCSIDispatch: skip it
            bne.b   .CheckSCSI
            cmpi.w  #$15,D0
            bne.b   .CheckSCSI
            movem.l (SP)+,D0-D7/A0-A6
            addq.l  #2,(2,SP)
            rte
.CheckSCSI:
            btst    #SCSIPresent,(OutboundCfg).l    ; SCSI present: unhook at _SizeRsrc
            beq.b   .INITs
.SizeRsrc:
            cmpi.w  #$A9A5,(A0)                     ; _SizeRsrc
            bne.w   .Chain
            move.l  (SavedLineA).l,LineAVector
            bra.b   .Chain
.INITs:
            cmpi.w  #$A9A0,(A0)                     ; _GetResource of an INIT: unhook, SCSI flag off
            bne.b   .BlockMove
            cmpi.l  #'INIT',($44,SP)
            bne.b   .BlockMove
            move.l  (SavedLineA).l,LineAVector
            bclr    #7,HWCfgFlags
            bra.b   .Chain
.BlockMove:
            cmpi.w  #$A02E,(A0)                     ; _BlockMove from code that then sets Line-A?
            bne.b   .Chain
            move.l  ($42,SP),D0
            andi.l  #$3FFFFE,D0
            movea.l D0,A0
            cmpi.l  #$7262D3C2,(A0)+                ; moveq #$62,D1; adda.l D2,A1; move.l A1,$28
            bne.b   .Chain
            cmpi.l  #$21C90028,(A0)+
            bne.b   .Chain
            btst    #IsMacSEROM,(OutboundCfg).l
            beq.b   .DoBlockMove
            btst    #HostMac,(OutboundCfg).l
            bne.b   .DoBlockMove
            move.l  ADBBase,D0                      ; SE: bit 2 at ADBBase+$14D
            beq.b   .DoBlockMove
            movea.l D0,A0
            bset    #2,($14D,A0)
.DoBlockMove:
            movem.l (SP)+,D0-D7/A0-A6
            _BlockMove                              ; Do the move; the new handler goes behind this hook
            addq.l  #2,(2,SP)
            move.l  A1,(SavedLineA).l
            movea.l LineAVector,A1
            rte
.Chain:
            movem.l (SP)+,D0-D7/A0-A6
            move.l  (SavedLineA).l,-(SP)            ; Run the real handler
            rts
.EjectRetry:
            lea     EjectAndRetry,A0
            move.l  A0,($3E,SP)
            movem.l (SP)+,D0-D7/A0-A6
            rte
; EjectAndRetry
; _Control at Plus $400B9A / SE $400A6A (eject a disk that didn't boot): eject
; it, drop it from BootMask if that fails, re-arm the BootRetry patches and
; restart at BootRetry
EjectAndRetry:
            _Control                                ; Eject
            beq.b   .Rearm
            move.w  BootMask,D0                     ; Failed: drop the drive from BootMask
            bclr    D3,D0
            move.w  D0,BootMask
.Rearm:
            movea.l (PtchTblBase).l,A0
            adda.w  #TraceHandler-PtchROMBase,A0    ; Trace patches again
            move.l  A0,TraceVector
            btst    #IsMacSEROM,(OutboundCfg).l
            bne.b   .SETable
            lea     PlusRetryPatches,A6
            bra.b   .Start
.SETable:
            lea     SERetryPatches,A6
.Start:
            move.w  (A6)+,(ExpectedPC).l
            move.w  (A6)+,(PatchOffset).l
            move.l  A6,(PatchTblPtr).l
            move    #$A700,SR                       ; Trace on
            btst    #IsMacSEROM,(OutboundCfg).l
            bne.b   .SERetry
            jmp     (Plus_BootRetryCont).l          ; Plus BootRetry, past move #$2700,SR
.SERetry:
            jmp     (SE_BootRetryCont).l            ; SE BootRetry, same
; SizeRAM
; Set the RAM configuration latches ($50000B, $50000D) for the largest size that
; tests good: 4 MB, 2.5 MB, 2 MB, then 1 MB
SizeRAM:
            suba.l  A0,A0
            move.b  #1,(MemCfg1).l                  ; RAM configuration latches
            clr.b   (MemCfg2).l
            moveq   #8,D0                           ; 4 MB
            bsr.b   TestRAMSize
            bne.b   .Done
            move.b  #1,(MemCfg2).l
            moveq   #5,D0                           ; 2.5 MB
            bsr.b   TestRAMSize
            bne.b   .Done
            clr.b   (MemCfg1).l
            moveq   #4,D0                           ; 2 MB
            bsr.b   TestRAMSize
            bne.b   .Done
            clr.b   (MemCfg2).l
            moveq   #2,D0                           ; 1 MB
            bsr.b   TestRAMSize
.Done:
            rts
; TestRAMSize
; TestRAMSize(D0 = size in 512K units): mark the first word of each 512K block,
; top down, then check them all (aliasing shows as a mismatch); D0 = 0 if bad
TestRAMSize:
            move.l  D0,D1
            move.w  D0,D2
            swap    D1
            lsl.l   #3,D1                           ; Size in bytes
.Mark:
            subi.l  #$80000,D1
            move.w  D2,(0,A0,D1.l)                  ; Mark each 512K block, top down
            subq.w  #1,D2
            bne.b   .Mark
            move.l  D0,D1
            move.w  D0,D2
            swap    D1
            lsl.l   #3,D1
.Check:
            subi.l  #$80000,D1
            cmp.w   (0,A0,D1.l),D2                  ; Check them
            bne.b   .Bad
            subq.w  #1,D2
            bne.b   .Check
            tst.w   D0
            rts
.Bad:
            moveq   #0,D0
            rts
; PlusLev1Intr
; Plus level-1 autovector: save D0-D3/A0-A3 and enter the ROM's VIA interrupt
; dispatcher at $401A60
PlusLev1Intr:
            movem.l D0-D3/A0-A3,-(SP)
            jmp     (Plus_Lvl1Dispatch).l           ; ROM VIA dispatcher
; CursorPatchOffs
; Offsets (cumulative, 0 ends) of nine constants in the copied cursor code
CursorPatchOffs:
            dc.w    $3678,$0620,$061E,$488E,$0600
; CursorPatchVals
; Their new values: moveq #80 for the row bytes, and the limits 608, 384, 400,
; 624, 640
CursorPatchVals:
            dc.w    $7050,$0260,$0260,$0180,$0190,$7A50,$0270,$0190
            dc.w    $0280
; MoveScreen
; Switch to the Outbound's 640x400 screen at $700000: copy the ROM's cursor code
; to the system heap, retarget the cursor jump vectors, patch its screen
; constants, install OBScrnBitMap, set ScrnBase, ScreenRow, CrsrPin and
; SoundBase
MoveScreen:
            movem.l D0-D7/A0-A6,-(SP)
            move.b  #1,CrsrBusy                     ; Cursor busy
            movea.l JCrsrObscure,A1                 ; Start: CrsrObscure
            move.w  #$33,D0                         ; _ScrnBitMap: end of the cursor code
            _GetToolBoxTrapAddress
            btst    #IsMacSEROM,(OutboundCfg).l
            bne.b   .HaveEnd
            movea.l #BaseOfROM+$2000,A0             ; Plus: up to $402000
.HaveEnd:
            move.l  A0,D0
            sub.l   A1,D0
            move.l  D0,D1
            movea.l A1,A2
            _NewPtrSys                              ; Copy to the system heap
            exg     A0,A1
            move.l  D1,D0
            _BlockMove
            suba.l  A1,A0
            move.l  A0,D0
            movea.w #$800,A1                        ; Cursor jump vectors $800-$81F
            moveq   #7,D1
.Relocate:
            sub.l   D0,(A1)+
            dbra    D1,.Relocate
            btst    #IsMacSEROM,(OutboundCfg).l
            bne.b   .Patch
            sub.l   D0,JCrsrTask                    ; Plus: JCrsrTask too
.Patch:
            lea     CursorPatchOffs,A0
            lea     CursorPatchVals,A1
            suba.l  D0,A2
            clr.w   D0
.NextPatch:
            move.b  (A0)+,D0                        ; Patch the screen constants
            beq.b   .Done
            adda.w  D0,A2
            move.w  (A1)+,(A2)
            bra.b   .NextPatch
.Done:
            lea     OBScrnBitMap,A0
            move.w  #$33,D0
            _SetToolBoxTrapAddress                  ; _ScrnBitMap
            move.l  #OutboundDisp,ScrnBase          ; Outbound screen
            move.w  #$50,ScreenRow                  ; 80 bytes per row
            move.w  #$280,($83A).w                  ; CrsrPin right
            move.w  #$190,($838).w                  ; CrsrPin bottom
            clr.b   CrsrBusy
            move.l  #OutboundSnd,SoundBase          ; Sound buffer
            movem.l (SP)+,D0-D7/A0-A6
            rts
; OBScrnBitMap
; _ScrnBitMap replacement: the 640x400 screen at ScrnBase
OBScrnBitMap:
            movea.l (SP)+,A1
            movea.l (SP)+,A0
            move.l  ScrnBase,(A0)+                  ; baseAddr
            move.w  ScreenRow,(A0)+                 ; rowBytes
            clr.l   (A0)+                           ; bounds: top, left 0
            move.w  #$190,(A0)+                     ; bottom 400
            move.w  #$280,(A0)                      ; right 640
            jmp     (A1)
; Clock and parameter RAM (the same code is in Floppy_1.3.s and HardDisk_1.3.s). The
; clock chip, which looks like a Motorola MC68HC68T1, is on VIA port B at
; $E7E1FE: bit 0 data, bit 1 clock, bit 2 select (low while talking), MSB first.
; A command byte is the register address, plus $80 to write. Registers: $00-$1F
; RAM ($00-$13 the 20 PRAM bytes, $14-$1F XPRAM $7C, $78 and $E0), $20-$26 the
; time in BCD (seconds, minutes, hours, day of week, date, month, year - 1900),
; $31 clock control.

; InstallRTCTraps
; Replace _InitUtil, _WriteParam, _ReadDateTime, _SetDateTime, _ReadXPRam and
; _WriteXPRam with versions for the clock chip, then start the clock. Runs just
; before the ROM calls _InitUtil
InstallRTCTraps:
            movem.l D0-D2/A0-A1,-(SP)
            lea     RTCInitUtil,A0
            move.w  #$3F,D0                         ; _InitUtil
            _SetTrapAddress
            lea     RTCWriteParam,A0
            move.w  #$38,D0                         ; _WriteParam
            _SetTrapAddress
            lea     RTCReadDateTime,A0
            move.w  #$39,D0                         ; _ReadDateTime
            _SetTrapAddress
            lea     RTCSetDateTime,A0
            move.w  #$3A,D0                         ; _SetDateTime
            _SetTrapAddress
            lea     RTCReadXPRam,A0
            move.w  #$51,D0                         ; _ReadXPRam
            _SetOSTrapAddress
            lea     RTCWriteXPRam,A0
            move.w  #$52,D0                         ; _WriteXPRam
            _SetOSTrapAddress
            lea     (OutboundVIA).l,A0              ; Clock chip on VIA port B
            ori.b   #1<<VIAB0|1<<PRAMBit1|1<<PRAMBit2,(vDIRB,A0) ; Bits 0-2 outputs
            bclr    #PRAMBit1,(A0)                  ; Clock low
            bset    #PRAMBit2,(A0)                  ; Deselect
            move.b  #$B1,D0                         ; Write register $31 (clock control)
            bsr.w   RTCSendByte
            move.b  #$B5,D0                         ; $B5: start, crystal, 32.768 kHz
            bsr.w   RTCSendByte
            bset    #PRAMBit2,(A0)                  ; Deselect
            movem.l (SP)+,D0-D2/A0-A1
            rts
; RTCInitUtil
; _InitUtil: read the clock into Time and the 20 PRAM bytes into SysParam. If
; SPValid isn't $A8, load the ROM's default PRAM, write it out, set the clock to
; 0 and return prInitErr
RTCInitUtil:
            movem.l D1/A0-A1,-(SP)
            lea     TimeLM,A0                       ; Time
            _ReadDateTime
            lea     SPValid,A0                      ; SysParam
            move.w  #$14,D1                         ; 20 bytes from register $00
            clr.w   D0
            bsr.w   RTCRead
            cmpi.b  #$A8,SPValid                    ; Valid PRAM?
            beq.b   .Valid
            lea     SPValid,A1                      ; No: copy the ROM's defaults
            btst    #IsMacSEROM,(OutboundCfg).l
            beq.b   .PlusDefaults
            movea.l #SE_DefaultPRAM,A0              ; SE default PRAM
            bra.b   .CopyDefaults
.PlusDefaults:
            movea.l #Plus_DefaultPRAM,A0            ; Plus default PRAM
.CopyDefaults:
            moveq   #$14,D0
            _BlockMove
            lea     SPValid,A0                      ; Write them to the chip
            move.l  MinusOne,D0
            _WriteParam
            moveq   #0,D0                           ; Clock to 0 (1904)
            _SetDateTime
            moveq   #-$58,D0                        ; prInitErr
            bra.b   .Done
.Valid:
            moveq   #0,D0                           ; noErr
.Done:
            movem.l (SP)+,D1/A0-A1
            rts
; RTCWriteParam
; _WriteParam: write the 20 bytes at A0 to the chip's PRAM, then read them back
; into Scratch20 (not compared). Apple's version always writes SysParam and
; takes no arguments
RTCWriteParam:
            movem.l D1/A0-A1,-(SP)
            move.w  #$14,D1                         ; 20 bytes to register $00
            clr.w   D0
            bsr.w   RTCWrite
            lea     Scratch20,A0                    ; Read back, not compared
            move.w  #$14,D1
            clr.w   D0
            bsr.w   RTCRead
            moveq   #0,D0                           ; noErr
            movem.l (SP)+,D1/A0-A1
            rts
; RTCSetDateTime
; _SetDateTime: set Time and the chip's clock to the seconds in D0. The year is
; kept as two BCD digits of year - 1900, so 2000 on wraps to 1900. D0 comes back
; with $A0 in its low word, not noErr
RTCSetDateTime:
            movem.l D1/A0-A1,-(SP)
            suba.w  #$E,SP                          ; DateTimeRec
            movea.l SP,A0
            move.l  D0,TimeLM                       ; Time
            _SecondsToDate
            subq.l  #8,SP                           ; Clock registers in chip order
            move.w  (A0)+,D0
            subi.w  #$76C,D0                        ; Year - 1900
            bsr.w   BinToBCD
            move.b  D0,(6,SP)                       ; Year
            move.w  (A0)+,D0
            bsr.w   BinToBCD
            move.b  D0,(5,SP)                       ; Month
            move.w  (A0)+,D0
            bsr.w   BinToBCD
            move.b  D0,(4,SP)                       ; Date
            move.w  (A0)+,D0
            bsr.w   BinToBCD
            move.b  D0,(2,SP)                       ; Hours
            move.w  (A0)+,D0
            bsr.w   BinToBCD
            move.b  D0,(1,SP)                       ; Minutes
            move.w  (A0)+,D0
            bsr.w   BinToBCD
            move.b  D0,(SP)                         ; Seconds
            move.w  (A0)+,D0
            bsr.w   BinToBCD
            move.b  D0,(3,SP)                       ; Day of week
            movea.l SP,A0
            move.w  #7,D1                           ; 7 bytes to register $20
            move.w  #$20,D0
            bsr.w   RTCWrite
            adda.w  #$16,SP
            movem.l (SP)+,D1/A0-A1
            rts
; RTCReadDateTime
; _ReadDateTime: read the chip's clock and convert it with _Date2Secs into Time
; and (A0)
RTCReadDateTime:
            movem.l D1/A1,-(SP)
            move.l  A0,-(SP)                        ; Result pointer
            suba.w  #$18,SP
            movea.l SP,A0
            move.w  #7,D1                           ; 7 bytes from register $20
            move.w  #$20,D0
            bsr.w   RTCRead
            movea.l SP,A1
            lea     (8,SP),A0                       ; DateTimeRec
            move.b  (6,A1),D0
            bsr.b   BCDToBin
            addi.w  #$76C,D0                        ; Year + 1900
            move.w  D0,(A0)+
            move.b  (5,A1),D0
            bsr.b   BCDToBin
            move.w  D0,(A0)+                        ; Month
            move.b  (4,A1),D0
            bsr.b   BCDToBin
            move.w  D0,(A0)+                        ; Date
            move.b  (2,A1),D0
            bsr.b   BCDToBin
            move.w  D0,(A0)+                        ; Hours
            move.b  (1,A1),D0
            bsr.b   BCDToBin
            move.w  D0,(A0)+                        ; Minutes
            move.b  (A1),D0
            bsr.b   BCDToBin
            move.w  D0,(A0)+                        ; Seconds
            move.b  (3,A1),D0
            bsr.b   BCDToBin
            move.w  D0,(A0)+                        ; Day of week
            lea     (8,SP),A0
            _Date2Secs
            move.l  D0,TimeLM                       ; Time
            adda.w  #$18,SP
            movea.l (SP)+,A0
            move.l  D0,(A0)                         ; And at (A0)
            moveq   #0,D0                           ; noErr
            movem.l (SP)+,D1/A1
            rts
; BinToBCD
; D0 = D0 (0-99) as two BCD digits
BinToBCD:
            movem.l D1,-(SP)
            move.w  D0,D1
            ext.l   D1
            divu.w  #$A,D1                          ; Ones
            swap    D1
            move.w  D1,D0
            swap    D1
            ext.l   D1
            divu.w  #$A,D1                          ; Tens (mod 10)
            swap    D1
            asl.w   #4,D1
            or.w    D1,D0
            movem.l (SP)+,D1
            rts
; BCDToBin
; D0 = BCD byte D0 in binary
BCDToBin:
            movem.l D1,-(SP)
            move.b  D0,D1
            andi.w  #$F0,D1
            asr.w   #4,D1
            mulu.w  #$A,D1
            andi.w  #$F,D0
            add.w   D1,D0
            movem.l (SP)+,D1
            rts
; RTCWrite
; Write D1 bytes from A0 to the chip, from register D0 on, with interrupts
; masked to at least level 3
RTCWrite:
            move    SR,-(SP)
            ori     #$300,SR                        ; Mask interrupts
            movea.l A0,A1
            lea     (OutboundVIA).l,A0
            ori.b   #1<<VIAB0|1<<PRAMBit1|1<<PRAMBit2,(vDIRB,A0) ; Bits 0-2 outputs
            bclr    #PRAMBit1,(A0)                  ; Clock low
            bset    #PRAMBit2,(A0)                  ; Deselect
            ori.b   #$80,D0                         ; Write command
            bsr.b   RTCSendByte
            bra.b   .Loop
.NextByte:
            move.b  (A1)+,D0
            bsr.b   RTCSendByte
.Loop:
            dbra    D1,.NextByte
            bset    #PRAMBit2,(A0)                  ; Deselect
            move    (SP)+,SR
            rts
; RTCRead
; Read D1 bytes from the chip, from register D0 on, into A0
RTCRead:
            move    SR,-(SP)
            ori     #$300,SR                        ; Mask interrupts
            movea.l A0,A1
            lea     (OutboundVIA).l,A0
            ori.b   #1<<VIAB0|1<<PRAMBit1|1<<PRAMBit2,(vDIRB,A0)
            bclr    #PRAMBit1,(A0)
            bset    #PRAMBit2,(A0)
            andi.b  #$3F,D0                         ; Read command
            bsr.b   RTCSendByte
            bclr    #VIAB0,(vDIRB,A0)               ; Data line to input
            bra.b   .Loop
.NextByte:
            bsr.b   RTCRecvByte
            move.b  D0,(A1)+
.Loop:
            dbra    D1,.NextByte
            bset    #PRAMBit2,(A0)                  ; Deselect
            move    (SP)+,SR
            rts
; RTCSendByte
; Send D0 to the chip, MSB first; also selects it
RTCSendByte:
            movem.l D0-D2,-(SP)
            moveq   #7,D2
            andi.b  #$F8,(A0)                       ; Select; clock and data low
.NextBit:
            asl.b   #1,D0
            bcc.b   .Zero
            bset    #VIAB0,(A0)                     ; Data bit
            bra.b   .Clock
.Zero:
            bclr    #VIAB0,(A0)
.Clock:
            bset    #PRAMBit1,(A0)                  ; Clock pulse
            bclr    #PRAMBit1,(A0)
            dbra    D2,.NextBit
            movem.l (SP)+,D0-D2
            rts
; RTCRecvByte
; Receive a byte from the chip into D0, MSB first
RTCRecvByte:
            movem.l D1-D3,-(SP)
            moveq   #7,D2
            andi.b  #$F8,(A0)                       ; Select; clock and data low
.NextBit:
            asl.b   #1,D0
            bset    #PRAMBit1,(A0)                  ; Clock high
            move.b  (A0),D3                         ; Data bit in
            andi.b  #1,D3
            or.b    D3,D0
            bclr    #PRAMBit1,(A0)                  ; Clock low
            dbra    D2,.NextBit
            movem.l (SP)+,D1-D3
            rts
; RTCReadXPRam
; _ReadXPRam (D0 = count << 16 + address, A0 = buffer): only XPRAM $08 (always 1
; byte), $7C, $78 and $E0 are kept, at those exact addresses; anything else
; reads as zeros. D0 comes back unchanged
RTCReadXPRam:
            movem.l D0-D2/A0-A2,-(SP)
            swap    D0
            move.w  D0,D1                           ; Count
            swap    D0
            cmpi.w  #$7C,D0                         ; XPRAM $7C: chip $14
            beq.b   .Addr7C
            cmpi.w  #8,D0                           ; XPRAM $08: chip $10
            beq.b   .Addr08
            cmpi.w  #$78,D0                         ; XPRAM $78 (startup device): chip $16
            beq.b   .Addr78
            cmpi.w  #$E0,D0                         ; XPRAM $E0: chip $1A
            beq.b   .AddrE0
            subq.w  #1,D1                           ; Anything else reads as zeros
.ZeroFill:
            clr.b   (A0)+
            dbra    D1,.ZeroFill
.Done:
            movem.l (SP)+,D0-D2/A0-A2
            rts
.Addr08:
            move.w  #$10,D0
            move.w  #1,D1                           ; One byte only
            bra.b   .Read
.Addr7C:
            move.w  #$14,D0
            bra.b   .Read
.Addr78:
            move.w  #$16,D0
            bra.b   .Read
.AddrE0:
            move.w  #$1A,D0
.Read:
            bsr.w   RTCRead
            bra.b   .Done
; RTCWriteXPRam
; _WriteXPRam: the same mapping; writes anywhere else are ignored. D0 comes back
; unchanged
RTCWriteXPRam:
            movem.l D0-D2/A0-A2,-(SP)
            swap    D0
            move.w  D0,D1                           ; Count
            swap    D0
            cmpi.w  #$7C,D0                         ; XPRAM $7C: chip $14
            beq.b   .Addr7C
            cmpi.w  #8,D0                           ; XPRAM $08: chip $10
            beq.b   .Addr08
            cmpi.w  #$78,D0                         ; XPRAM $78 (startup device): chip $16
            beq.b   .Addr78
            cmpi.w  #$E0,D0                         ; XPRAM $E0: chip $1A
            beq.b   .AddrE0
.Done:
            movem.l (SP)+,D0-D2/A0-A2               ; Anything else: nothing written
            rts
.Addr08:
            move.w  #$10,D0
            move.w  #1,D1                           ; One byte only
            bra.b   .Write
.Addr7C:
            move.w  #$14,D0
            bra.b   .Write
.Addr78:
            move.w  #$16,D0
            bra.b   .Write
.AddrE0:
            move.w  #$1A,D0
.Write:
            bsr.w   RTCWrite
            bra.b   .Done
; Keyboard and mouse (the same code is in Floppy_1.3.s and HardDisk_1.3.s). The keyboard
; controller sends 2-byte packets into the VIA shift register:
;   mouse:   b1 bit 7 clear, bits 0-5 dx; b2 bits 0-5 dy, bits 6-7 check
;   key:     b1 bit 7 set, bit 6 up, bits 0-5 key; b2 bit 6 clear, bits 0-5 check
;   status:  b2 bit 6 set; b1 bit 6 set for pointer (button, auto-move, caps lock),
;            clear for modifiers
;   special: b1 0; b2 $81 all keys up, $88 keep-alive
; Globals at OutboundGlobals+: $64 time of last byte, $68 packet state, $69-$6B packet
; bytes, $6C key code, $6E/$6F last motion, $70 time of last motion, $74/$75 last
; modifier/pointer status, $76-$7A auto-move, $9C/$A0 idle timer, $A4 keys down,
; $A5 stuck-key timer, $A8 resync count, $AA/$B2 mouse hooks, $AE VBL hook,
; $B8 key $34 hook. Nothing here sets the hooks or the idle timer.

; KbdIntr
; Shift register interrupt: one byte from the keyboard controller
KbdIntr:
            movea.l (OutboundGlobals).l,A1
            move.b  (OutboundVIA+vSR).l,D1          ; The byte (VIA shift register)
            move.b  #$10,(OutboundVIA+vIFR).l       ; Clear the CB1 flag
            clr.b   ($6D,A1)
            move.b  ($68,A1),D0                     ; Packet state
            btst    #0,D0                           ; Waiting for a mouse packet's second byte?
            bne.w   MouseSecondByte
            tst.b   D1                              ; Bit 7 clear and not 0: starts a mouse packet
            beq.b   .NotMouse
            bpl.b   KbdFirstByte.MouseFirstByte
.NotMouse:
            btst    #1,D0                           ; Waiting for a key packet's second byte?
            bne.w   KeyPacket
            bclr    #2,($68,A1)                     ; Left set when a key packet's second byte came late: drop this byte
            beq.b   KbdFirstByte                      ; Otherwise it starts a key packet
            rts
; KbdFirstByte
; First byte of a key packet: key number and up/down, or status bits
KbdFirstByte:
            move.b  D1,($6A,A1)
            bset    #1,($68,A1)                     ; Wait for the second byte
            move    SR,D0                           ; Interrupts all masked: poll for the second byte
            andi.w  #$700,D0
            cmpi.w  #$700,D0
            bne.b   .SaveTime
            move.l  Ticks,($64,A1)                  ; Time of this byte
            move.w  #$4000,D0
.PollSecondByte:
            btst    #2,(OutboundVIA+vIFR).l         ; Shift register flag
            bne.b   KbdIntr
            dbra    D0,.PollSecondByte
            bra.b   KbdResync
.MouseFirstByte:
            move.b  D1,($69,A1)                     ; First byte of a mouse packet: horizontal motion
            bset    #0,($68,A1)                     ; Wait for the second byte
.SaveTime:
            move.l  Ticks,($64,A1)
            rts
; KbdResync
; Bad or late byte: wait, then resynchronize the shift register
KbdResync:
            move.w  #$FFFF,D0
.Delay:
            dbra    D0,.Delay
            movea.l (OutboundGlobals).l,A1
            addq.w  #1,($A8,A1)                     ; Count resyncs
            tst.w   ($34,A1)                        ; Floppy driver busy ($34) or interrupts masked: release every key
            bne.b   .ReleaseKeys
            move    SR,D0
            andi.w  #$700,D0
            cmpi.w  #$700,D0
            bne.b   .ResetSR
.ReleaseKeys:
            bsr.w   ReleaseAll
.ResetSR:
            bsr.w   ResetKbdSR
            bclr    #0,($68,A1)                     ; No packet in progress
            bclr    #1,($68,A1)
            bchg    #7,(OutboundDisp).l             ; Flip the top-left screen pixel (debug marker)
            rts
; MouseSecondByte
; Second byte of a mouse packet: vertical motion and check bits
MouseSecondByte:
            bsr.w   CheckByteGap
            move.b  D1,($6B,A1)
            bclr    #0,($68,A1)
            clr.b   D2
            clr.b   D0
            bsr.b   PopCount6
            move.b  ($69,A1),D1
            bsr.b   PopCount6
            not.w   D0                              ; Check bits = ~(set bits in both motion fields) & 3
            andi.w  #3,D0
            move.b  ($6B,A1),D1
            lsr.b   #6,D1                           ; Top two bits of the second byte
            cmp.b   D0,D1
            bne.b   KbdResync
            bra.b   MousePacket
; PopCount6
; D0 += number of bits set in D1 & $3F
PopCount6:
            andi.w  #$3F,D1
            bset    #7,D1
            lsr.b   #1,D1
.Loop:
            addx.b  D2,D0
            lsr.b   #1,D1
            bne.b   .Loop
            rts
; MousePacket
; Good mouse packet: wake the display, run the hooks, move the cursor
MousePacket:
            bsr.w   KbdActivity
            tst.l   ($AA,A1)                        ; Hook at $AA
            beq.b   .CallHookB2
            pea     .CallHookB2
            move.l  ($AA,A1),-(SP)
            rts
.CallHookB2:
            tst.l   ($B2,A1)                        ; Hook at $B2
            beq.b   .Horizontal
            pea     .Horizontal
            move.l  ($B2,A1),-(SP)
            rts
.Horizontal:
            move.b  ($69,A1),D1                     ; Horizontal: 6-bit signed, $20 = 0
            andi.w  #$3F,D1
            cmpi.b  #$20,D1
            bne.b   .HSign
            clr.b   D1
            bra.b   .HAdd
.HSign:
            btst    #5,D1
            beq.b   .HAdd
            ori.b   #$E0,D1
.HAdd:
            ext.w   D1
            btst    #2,($75,A1)                     ; Not during horizontal auto-move (status bits 1, 2)
            bne.b   .Vertical
            btst    #1,($75,A1)
            bne.b   .Vertical
            add.w   D1,($82A).w                     ; MTemp.h
.Vertical:
            move.b  ($6E,A1),($78,A1)               ; Previous horizontal step
            move.b  D1,($6E,A1)
            move.b  ($6B,A1),D1                     ; Vertical, same encoding
            andi.w  #$3F,D1
            cmpi.b  #$20,D1
            bne.b   .VSign
            clr.b   D1
            bra.b   .VAdd
.VSign:
            btst    #5,D1
            beq.b   .VAdd
            ori.w   #$E0,D1
.VAdd:
            ext.w   D1
            add.w   D1,MTemp                        ; MTemp.v
            move.b  D1,($6F,A1)
            move.b  CrsrCouple,CrsrNew              ; Redraw the cursor
            move.l  Ticks,($70,A1)                  ; Time of the last motion
            rts
; KeyPacket
; Second byte of a key packet
KeyPacket:
            bset    #2,($68,A1)
            bsr.w   CheckByteGap
            bclr    #2,($68,A1)
            bclr    #1,($68,A1)
            move.b  D1,($6B,A1)
            tst.b   ($6A,A1)                        ; First byte 0: special packet
            beq.w   KbdSpecial
            move.b  ($6A,A1),D0                     ; Check = b1 ^ (b1 >> 1) ^ $13, bit 0 flipped by bit 6 of b2
            move.b  D0,D1
            lsr.b   #1,D0
            eor.b   D0,D1
            btst    #6,($6B,A1)
            beq.b   .CheckBits
            eori.b  #1,D1
.CheckBits:
            eori.b  #$13,D1
            andi.b  #$3F,D1
            move.b  ($6B,A1),D0
            andi.b  #$3F,D0
            cmp.b   D0,D1                           ; Must match the low 6 bits of the second byte
            bne.w   KbdResync
            bsr.w   KbdActivity
            clr.b   ($A5,A1)                        ; Reset the stuck-key timer
            btst    #6,($6B,A1)                     ; Second byte bit 6: a status packet
            bne.w   StatusPacket
            move.b  ($6A,A1),D1                     ; Key number
            andi.l  #$3F,D1
            cmpi.b  #$34,D1                         ; Key $34 runs the hook at $B8
            beq.w   KbdKey34
            cmpi.b  #$3C,D1                         ; Keys $3C-$3F are the arrows
            bcs.b   .SetDown
            subi.b  #$3C,D1
            andi.w  #3,D1
            move.b  .ArrowCodes(PC,D1.w),D1
            bra.b   .SetDown
.ArrowCodes:
            dc.w    $7B7C,$7D7E                     ; Mac key codes: left, right, down, up
.SetDown:
            btst    #6,($6A,A1)                     ; Bit 6 clear: key down
            bne.b   .StoreKey
            bset    #7,D1
.StoreKey:
            move.b  D1,($6C,A1)                     ; Key code, bit 7 = down
            move.b  D1,D0
            bsr.w   UpdateKeyMap
            move.b  ($6C,A1),D1                     ; Raw key code for KeyTrans: bit 7 = up
            andi.w  #$7F,D1
            btst    #6,($6A,A1)
            beq.b   .Translate
            bset    #7,D1
.Translate:
            bsr.b   KeyTransGlue                      ; Two character codes on the stack
            movea.l (OutboundGlobals).l,A1
            moveq   #0,D0
            move.w  (SP)+,D0                        ; First character
            beq.b   .SecondChar
            andi.w  #$FF,D0
            move.b  ($6C,A1),D1
            andi.w  #$7F,D1
            lsl.w   #8,D1
            or.w    D1,D0
            movea.w #3,A0                           ; keyDown, or keyUp (4)
            btst    #7,($6C,A1)
            bne.b   .PostFirst
            movea.w #4,A0
.PostFirst:
            _PostEvent
            movea.l (OutboundGlobals).l,A1
.SecondChar:
            moveq   #0,D0
            move.w  (SP)+,D0                        ; Second character
            beq.b   .Done
            andi.w  #$FF,D0
            move.b  ($6C,A1),D1
            andi.w  #$7F,D1
            lsl.w   #8,D1
            or.w    D1,D0
            movea.w #3,A0
            btst    #7,($6C,A1)
            bne.b   .StartRepeat
            movea.w #4,A0
            clr.w   KeyLast                         ; Key up: stop auto-repeat
            bra.b   .PostSecond
.StartRepeat:
            move.w  D0,KeyLast                      ; Key down: start auto-repeat
            move.l  Ticks,D1
            move.l  D1,KeyTime
            move.l  D1,KeyRepTime
.PostSecond:
            _PostEvent
.Done:
            rts
; KeyTransGlue
; KeyTrans the key code in D1; two characters come back as a long on the stack
KeyTransGlue:
            move.w  #$1C3,D0
            _GetToolBoxTrapAddress
            cmpa.l  #BaseOfROM,A0                   ; Trap still in ROM (not implemented): no characters
            bgt.b   .NoKeyTrans
            move.b  ($17B).w,D0                     ; Modifiers from KeyMap: shift, caps lock, option, control
            andi.w  #$F,D0
            add.b   D0,D0
            tst.b   ($17A).w                        ; Command
            bpl.b   .ShiftMods
            addq.w  #1,D0
.ShiftMods:
            lsl.w   #8,D0
            andi.w  #$FF,D1
            or.w    D0,D1
            subq.l  #4,SP
            movea.l ExpandMem,A0
            move.l  ($E,A0),-(SP)                   ; emKeyCache (KCHR)
            move.w  D1,-(SP)
            pea     ($A,A0)                         ; emKeyDeadState
            _KeyTrans
            move.l  (SP)+,D0
            movea.l (SP)+,A0
            move.l  D0,-(SP)
            jmp     (A0)
.NoKeyTrans:
            movea.l (SP)+,A0
            pea     (0).w                           ; No KeyTrans: no characters
            jmp     (A0)
; UpdateKeyMap
; Set or clear key D0 (bit 7 = down) in KeyMap; count the keys down
UpdateKeyMap:
            movem.l D1-D2/A0,-(SP)
            move.b  D0,D1
            move.b  D0,D2
            andi.l  #$7F,D1
            movea.w #$174,A0                        ; KeyMap
            lsr.b   #3,D1
            adda.l  D1,A0
            move.b  (A0),D0
            move.b  D2,D1
            andi.l  #7,D1
            btst    #7,D2
            beq.b   .KeyUp
            addq.b  #1,($A4,A1)                     ; Keys down
            bset    D1,D0
            bra.b   .Store
.KeyUp:
            bclr    D1,D0
            subq.b  #1,($A4,A1)
            bpl.b   .Store
            clr.b   ($A4,A1)
.Store:
            move.b  D0,(A0)
            cmpi.w  #$80C,($17A).w                  ; Control-Option-Delete held alone: restart
            beq.b   .Restart
            movem.l (SP)+,D1-D2/A0
            moveq   #0,D0
            rts
.Restart:
            move    #$2700,SR
            movea.l (BaseOfROM+4).l,A0              ; ROM reset vector
            jmp     (A0)
; KbdSpecial
; Special packet: $81 = all keys up, $88 = keep-alive
KbdSpecial:
            cmpi.b  #$81,D1
            bne.w   PostKeyUp.CheckKeepAlive
; ReleaseKeys
; Key-up for every key still down, except $36-$3F (command and modifiers)
ReleaseKeys:
            clr.b   ($A5,A1)
            movea.w #$174,A0
            moveq   #0,D2
.NextByte:
            tst.b   (A0)
            beq.b   .Advance
            move.b  (A0),D0
            clr.b   (A0)
            bsr.b   ReleaseByteKeys
.Advance:
            addq.b  #8,D2
            addq.l  #1,A0
            cmpa.w  #$17A,A0                        ; Keys $30-$37: release only $30-$35
            beq.b   .Byte6
            cmpa.w  #$184,A0
            beq.b   ReleaseByteKeys
            bra.b   .NextByte
.Byte6:
            move.b  (A0),D0
            andi.b  #$3F,D0
            beq.b   .SkipModifiers
            andi.b  #$C0,(A0)
            bsr.b   ReleaseByteKeys
.SkipModifiers:
            movea.w #$17C,A0                        ; Skip $38-$3F
            addi.b  #$10,D2
            bra.b   .NextByte
; ReleaseByteKeys
; Key-up for each bit set in D0, key codes from D2
ReleaseByteKeys:
            lsr.b   #1,D0
            bcs.b   .KeyDown
            beq.b   PostKeyUp.ByteDone
            bra.b   .NextBit
.KeyDown:
            bsr.b   PostKeyUp
            tst.b   D0
            beq.b   PostKeyUp.ByteDone
.NextBit:
            addq.w  #1,D2
            bra.b   ReleaseByteKeys
; PostKeyUp
; Post key-up for key code D2
PostKeyUp:
            movem.l D0-D2/A0,-(SP)
            move.b  D2,D1
            andi.w  #$7F,D1
            move.b  D2,($6C,A1)
            subq.b  #1,($A4,A1)
            bpl.b   .Translate
            clr.b   ($A4,A1)
.Translate:
            bsr.w   KeyTransGlue
            movea.l (OutboundGlobals).l,A1
            move.w  (SP)+,D0                        ; Drop the first character, post the second
            moveq   #0,D0
            move.w  (SP)+,D0
            beq.b   .Done
            move.b  ($6C,A1),D1
            andi.w  #$7F,D1
            lsl.w   #8,D1
            or.w    D1,D0
            movea.w #4,A0                           ; keyUp
            clr.w   KeyLast
            _PostEvent
            movea.l (OutboundGlobals).l,A1
.Done:
            movem.l (SP)+,D0-D2/A0
            rts
.ByteDone:
            andi.b  #$F8,D2
            rts
.CheckKeepAlive:
            cmpi.b  #$88,D1                         ; $88: keep-alive while keys are held
            bne.w   KbdResync
            clr.b   ($A5,A1)
            rts
; StatusPacket
; Status packet: bit 6 of the first byte picks pointer or modifiers
StatusPacket:
            move.b  ($6A,A1),D0
            btst    #6,D0
            bne.b   PointerStatus
; ModifierStatus
; Modifier status: post up/down for each bit that changed
ModifierStatus:
            move.b  ($6A,A1),D1
            move.b  ($74,A1),D0
            eor.b   D1,D0
            andi.b  #$1F,D0
            beq.b   .Done
            move.w  #4,D1                           ; Bits 0-4: option, command, control, shift, enter
.NextBit:
            btst    D1,D0
            beq.b   .Unchanged
            bsr.w   PostModKey
.Unchanged:
            dbra    D1,.NextBit
.Done:
            move.b  ($6A,A1),($74,A1)               ; Remember the state
            rts
; PointerStatus
; Pointer status: button (bit 4), horizontal auto-move (bits 1, 2), caps lock
; (bit 3)
PointerStatus:
            move.b  ($6A,A1),D0
            btst    #4,($6A,A1)                     ; Button down?
            bne.b   .ButtonDown
            btst    #CfgBit4,(OutboundCfg).l
            beq.b   .AutoMove
            bclr    #CfgBit4,(OutboundCfg).l
            moveq   #2,D0                           ; mouseUp
            move.b  #$80,MBState                    ; Button up
            bra.b   .PostButton
.ButtonDown:
            btst    #CfgBit4,(OutboundCfg).l
            bne.b   .AutoMove
            bset    #CfgBit4,(OutboundCfg).l
            clr.b   MBState                         ; Button down
            moveq   #1,D0                           ; mouseDown
.PostButton:
            move.l  Ticks,D1
            sub.l   MBTicks,D1
            cmpi.l  #3,D1                           ; Debounce: 3 ticks since the last posted change
            blt.b   .AutoMove
            add.l   D1,RndSeed
            move.l  Ticks,MBTicks
            movea.l D0,A0
            moveq   #0,D0
            _PostEvent
.AutoMove:
            move.b  ($6A,A1),D1                     ; Auto-move bits changed?
            move.b  ($75,A1),D0
            eor.b   D1,D0
            andi.b  #6,D0
            beq.w   .CapsLock
            move.b  #6,D0
            and.b   ($6A,A1),D0                     ; Either set: start moving
            beq.b   .ReleasedRight
            clr.b   ($77,A1)
            move.b  #6,($7A,A1)                     ; Acceleration countdown
            tst.b   ($78,A1)                        ; Already moving that way within 5 ticks: keep the speed
            beq.b   .StartSlow
            move.l  Ticks,D0
            sub.l   ($70,A1),D0
            cmpi.l  #5,D0
            bls.b   .Recent
.StartSlow:
            move.b  #$FF,($76,A1)                   ; Else 1 pixel: -1 for bit 2, +1 for bit 1
            addq.b  #1,($A4,A1)                     ; Counts as a key held
            btst    #1,($6A,A1)
            beq.b   .CapsLock
            addq.b  #2,($76,A1)
            bra.b   .CapsLock
.Recent:
            btst    #1,($6A,A1)
            bne.b   .RecentRight
            tst.b   ($78,A1)
            bpl.b   .StartSlow
            bra.b   .KeepSpeed
.RecentRight:
            tst.b   ($78,A1)
            bmi.b   .StartSlow
.KeepSpeed:
            move.b  ($78,A1),($76,A1)
            addq.b  #1,($A4,A1)
            bra.b   .CapsLock
.ReleasedRight:
            btst    #1,($6A,A1)                     ; Released: these bits are already clear, so $A4 never drops
            beq.b   .ReleasedLeft
            subq.b  #1,($A4,A1)
            bpl.b   .ReleasedLeft
            clr.b   ($A4,A1)
.ReleasedLeft:
            btst    #2,($6A,A1)
            beq.b   .CapsLock
            subq.b  #1,($A4,A1)
            bpl.b   .CapsLock
            clr.b   ($A4,A1)
.CapsLock:
            move.b  ($6A,A1),D0                     ; Caps lock (bit 3) changed: post key $39
            move.b  ($75,A1),D1
            eor.b   D1,D0
            andi.b  #8,D0
            beq.b   .SaveState
            pea     .SaveState
            movem.l D0-D7,-(SP)
            move.b  #$39,D0
            move.b  #3,D1
            bra.b   PostModKey.WithCode
.SaveState:
            move.b  ($6A,A1),($75,A1)               ; Remember the state
            btst    #0,($75,A1)                     ; Bit 0 (unknown): counts to 10 in $B6, then counts $A6
            beq.b   .ClearB6
            cmpi.b  #$A,($B6,A1)
            beq.b   .CountA6
            addq.b  #1,($B6,A1)
            bra.b   .Done
.CountA6:
            addq.b  #1,($A6,A1)
            bra.b   .Done
.ClearB6:
            clr.b   ($B6,A1)
.Done:
            rts
ModifierKeys:
            dc.w    $3A37,$3B38,$4C00               ; Option, command, control, shift, enter
; PostModKey
; Post an event for modifier bit D1 of the status byte
PostModKey:
            movem.l D0-D7,-(SP)
            move.b  D0,D6
            move.b  D1,D7
            move.b  ModifierKeys(PC,D1.w),D0      ; Key code
.WithCode:
            btst    D1,($6A,A1)                     ; Bit set: down
            beq.b   .Update
            ori.b   #$80,D0
.Update:
            move.b  D0,D1
            bsr.w   UpdateKeyMap
            move.b  D1,D5
            andi.b  #$7F,D1
            bsr.w   KeyTransGlue
            movea.l (OutboundGlobals).l,A1
            moveq   #0,D0
            move.w  (SP)+,D0
            beq.b   .SecondChar
            andi.w  #$FF,D0
            move.b  D5,D1
            andi.w  #$7F,D1
            lsl.w   #8,D1
            or.w    D1,D0
            movea.w #3,A0
            btst    #7,D5
            bne.b   .PostFirst
            movea.w #4,A0
.PostFirst:
            _PostEvent
            movea.l (OutboundGlobals).l,A1
.SecondChar:
            moveq   #0,D0
            move.w  (SP)+,D0
            beq.b   .Done
            andi.w  #$FF,D0
            move.b  D5,D1
            andi.w  #$7F,D1
            lsl.w   #8,D1
            or.w    D1,D0
            movea.w #3,A0
            btst    #7,D5
            bne.b   .StartRepeat
            movea.w #4,A0
            clr.w   KeyLast
            bra.b   .PostSecond
.StartRepeat:
            move.w  D0,KeyLast
            move.l  Ticks,D1
            move.l  D1,KeyTime
            move.l  D1,KeyRepTime
.PostSecond:
            _PostEvent
.Done:
            movem.l (SP)+,D0-D7
            rts
; KbdKey34
; Key $34 down with the button up: jump to the hook at $B8
KbdKey34:
            btst    #6,($6A,A1)
            bne.b   .Done
            btst    #CfgBit4,(OutboundCfg).l
            bne.b   .Done
            tst.l   ($B8,A1)
            beq.b   .Done
            movea.l ($B8,A1),A0
            jmp     (A0)
.Done:
            rts
; CheckByteGap
; Second byte within 2 ticks? If not, resync instead of returning
CheckByteGap:
            move.l  Ticks,D0
            sub.l   ($64,A1),D0
            cmpi.l  #2,D0
            bhi.b   .TooLate
            move.l  Ticks,($64,A1)
            rts
.TooLate:
            addq.w  #4,SP
            bra.w   KbdResync
; ReleaseAll
; Release every key, modifier and the button
ReleaseAll:
            movea.l (OutboundGlobals).l,A1
            bsr.w   ReleaseKeys
            clr.b   ($6A,A1)                        ; All modifiers up
            bsr.w   ModifierStatus
            move.b  ($75,A1),($6A,A1)               ; Keep caps lock and bit 0; button and auto-move off
            andi.b  #9,($6A,A1)
            bsr.w   PointerStatus
            bclr    #1,($68,A1)
            clr.b   ($A4,A1)                        ; No keys down
.Return:
            rts
; KbdActivity
; Activity: VIA port A bit 6 high, restart the idle timer
KbdActivity:
            bset    #6,(OutboundVIA+vDIRA).l
            bset    #6,(OutboundVIA+vBufA).l
            move.l  ($9C,A1),($A0,A1)               ; Idle timer reload ($9C, -1 = off)
            rts
; KbdVBLIntr
; VBL interrupt (replaces the ROM's): keep the shift register shifting in
KbdVBLIntr:
            bclr    #4,(vACR,A1)
            btst    #2,(vIFR,A1)                    ; Missed shift register interrupt: handle it now
            beq.b   .CheckHook
            movem.l D0-D7/A0-A6,-(SP)
            bsr.w   KbdIntr
            movem.l (SP)+,D0-D7/A0-A6
.CheckHook:
            move.l  A0,-(SP)
            movea.l (OutboundGlobals).l,A0
            tst.l   ($AE,A0)                        ; Hook at $AE runs when this returns
            beq.b   .StuckKeys
            move.l  (SP),-(SP)
            move.l  ($AE,A0),(4,SP)
.StuckKeys:
            tst.b   ($A4,A0)                        ; Keys held, no key packet for 90 ticks: release everything
            beq.b   .IdleTimer
            addq.b  #1,($A5,A0)
            cmpi.b  #$5A,($A5,A0)
            bne.b   .IdleTimer
            movem.l D0-D7/A0-A6,-(SP)
            bsr.w   ReleaseAll
            movem.l (SP)+,D0-D7/A0-A6
.IdleTimer:
            cmpi.l  #$FFFFFFFF,($9C,A0)             ; Idle timer: when it runs out, VIA port A bit 6 low
            beq.b   .AutoLeft
            tst.l   ($A0,A0)
            beq.b   .AutoLeft
            subq.l  #1,($A0,A0)
            bne.b   .AutoLeft
            bset    #6,(OutboundVIA+vDIRA).l
            bclr    #6,(OutboundVIA+vBufA).l
.AutoLeft:
            btst    #2,($75,A0)                     ; Auto-move left: every 2 ticks, speeding up to 20
            beq.b   .AutoRight
            addq.b  #1,($77,A0)
            cmpi.b  #2,($77,A0)
            bne.b   .PacketTimeout
            cmpi.b  #$EC,($76,A0)
            beq.b   .MoveLeft
            subq.b  #1,($7A,A0)
            move.b  ($9A,A0),D0
            cmp.b   ($7A,A0),D0
            bne.b   .MoveLeft
            move.b  #6,($7A,A0)
            subq.b  #1,($76,A0)
.MoveLeft:
            move.b  ($76,A0),D0
            ext.w   D0
            add.w   D0,($82A).w                     ; MTemp.h
            move.b  CrsrCouple,CrsrNew
            clr.b   ($77,A0)
.AutoRight:
            btst    #1,($75,A0)                     ; Auto-move right
            beq.b   .PacketTimeout
            addq.b  #1,($77,A0)
            cmpi.b  #2,($77,A0)
            bne.b   .PacketTimeout
            cmpi.b  #$14,($76,A0)
            beq.b   .MoveRight
            subq.b  #1,($7A,A0)
            move.b  ($9A,A0),D0
            cmp.b   ($7A,A0),D0
            bne.b   .MoveRight
            move.b  #6,($7A,A0)
            addq.b  #1,($76,A0)
.MoveRight:
            move.b  ($76,A0),D0
            ext.w   D0
            move.b  CrsrCouple,CrsrNew
            add.w   D0,($82A).w                     ; MTemp.h
            clr.b   ($77,A0)
.PacketTimeout:
            btst    #1,($68,A0)                     ; Packet half done for over 3 ticks: drop it
            bne.b   .PacketAge
            btst    #0,($68,A0)
            bne.b   .PacketAge
            bra.b   .RomWork
.PacketAge:
            move.l  Ticks,D0
            sub.l   ($64,A0),D0
            cmpi.w  #3,D0
            ble.b   .RomWork
            bclr    #1,($68,A0)
            bclr    #0,($68,A0)
            bsr.b   ResetKbdSR
.RomWork:
            movea.l (SP)+,A0
            addq.l  #1,Ticks                        ; From here on, what the ROM's VBL handler does
            move.b  #2,(vIFR,A1)                    ; Clear the CA1 (VBL) flag
            move    #$2000,SR
            bset    #6,VBLQueue                     ; VBL tasks already running: return
            bne.w   ReleaseAll.Return
            move.l  StkLowPt,D0                     ; Stack ran into the heap: SysError 28
            beq.b   .CursorTask
            cmpa.l  D0,SP
            bcc.b   .CheckHeap
            move.l  SP,StkLowPt
.CheckHeap:
            movea.l ApplZone,A1
            cmpa.l  (A1),SP
            bcc.b   .CursorTask
            moveq   #$1C,D0
            _SysError
.CursorTask:
            move.l  JCrsrTask,D0                    ; Cursor task
            beq.b   .ContinueRom
            movea.l D0,A0
            jsr     (A0)
.ContinueRom:
            btst    #IsMacSEROM,(OutboundCfg).l                  ; Rest of the ROM's VBL handler: SE, then Plus
            beq.b   .PlusRom
            jmp     (SE_VBLTasks).l
.PlusRom:
            jmp     (Plus_VBLTasks).l
; NullKbdTask
; JKybdTask: nothing (no Mac keyboard to poll)
NullKbdTask:
            rts
; ResetKbdSR
; Reset the shift register and wait for a new packet
ResetKbdSR:
            movem.l A0-A1,-(SP)
            movea.l (OutboundGlobals).l,A0
            lea     (OutboundVIA).l,A1
            move.b  (vACR,A1),D0
            andi.b  #$E3,D0                         ; Shift register off
            move.b  D0,(vACR,A1)
            tst.b   (vSR,A1)
            ori.b   #$C,D0                          ; Shift in on external clock
            move.b  D0,(vACR,A1)
            tst.b   (vSR,A1)
            clr.b   ($6D,A0)
            move.b  #$10,(vIFR,A1)                  ; Clear the CB1 flag
            movem.l (SP)+,A0-A1
            rts
; KbdOneSecIntr
; One-second interrupt: catch a missed shift register byte
KbdOneSecIntr:
            btst    #2,(OutboundVIA+vIFR).l
            beq.b   .Reinstall
            movem.l D0-D7/A0-A6,-(SP)
            bsr.w   KbdIntr
            movem.l (SP)+,D0-D7/A0-A6
.Reinstall:
            pea     KbdIntr                      ; Shift register handler back in Lvl1DT+8
            move.l  (SP)+,($19A).w
            btst    #IsMacSEROM,(OutboundCfg).l     ; ROM one-second handler: SE, then Plus
            beq.b   .PlusRom
            jmp     (SE_OneSecInt).l
.PlusRom:
            jmp     (Plus_OneSecInt).l
; InitKbd
; Take over keyboard and mouse: VIA handlers, ROM keyboard task off, globals
InitKbd:
            movem.l D0-D1/A0-A1,-(SP)
            move    SR,D1
            move    #$2700,SR
            lea     (OutboundVIA).l,A1
            bset    #6,(vDIRA,A1)                   ; Port A bit 6: output, high
            bset    #6,(vBufA,A1)
            lea     NullKbdTask,A0
            move.l  A0,JKybdTask                    ; No ROM keyboard task
            move.b  #1,KbdType
            lea     KbdVBLIntr,A0
            move.l  A0,($196).w                     ; Lvl1DT+4: VBL
            lea     KbdOneSecIntr,A0
            move.l  A0,Lvl1DT                       ; Lvl1DT+0: one-second
            move.b  #$80,MBState                    ; Button up
            bclr    #CfgBit4,(OutboundCfg).l
            move.b  #$C,(vACR,A1)                   ; ACR: shift in on external clock
            move.b  #$84,(vIER,A1)                  ; IER: enable the shift register interrupt
            move.b  (vPCR,A1),D0                    ; PCR: clear the CB control bits
            andi.b  #$F,D0
            move.b  D0,(vPCR,A1)
            move.b  (vSR,A1),D0                     ; Read SR to clear it
            lea     KbdIntr,A0
            move.l  A0,($19A).w                     ; Lvl1DT+8: shift register
            move    D1,SR
            movea.l (OutboundGlobals).l,A0
            move.b  #6,($7A,A0)                     ; Auto-move acceleration countdown
            move.b  #1,($7B,A0)                     ; Not read here
            move.b  #1,($99,A0)                     ; Not read here
            move.b  #2,($9A,A0)                     ; Auto-move: speed up when the countdown reaches this
            move.l  MinusOne,($9C,A0)               ; Idle timer off
            clr.l   ($B8,A0)                        ; No key $34 hook
            movem.l (SP)+,D0-D1/A0-A1
            rts
; DrawBootLogo
; Draw the run-length-encoded boot logo, 255 pixels wide and centered, on every
; fourth line of the black screen
DrawBootLogo:
            lea     BootLogoRLE,A0
            movea.l #OutboundDisp+$2477,A4          ; Logo at row 120, x 192, less one row step
.NewRow:
            move.w  #7,D2
            clr.w   D3
            adda.w  #$121,A4                        ; Next row, 4 lines down
.DrawRun:
            move.b  (A0)+,D1                        ; Draw run
            add.b   D1,D3
            beq.b   NextLogoPixel.Return                   ; 0 at a row start ends it
.Toggle:
            bchg    D2,(A4)                         ; Toggle the pixel
            bsr.b   NextLogoPixel
            subq.b  #1,D1
            bne.b   .Toggle
            cmpi.b  #$FF,D3                         ; Row done (255 pixels)?
            beq.b   .NewRow
            move.b  (A0)+,D1                        ; Skip run
            add.b   D1,D3
.Skip:
            bsr.b   NextLogoPixel
            subq.b  #1,D1
            bne.b   .Skip
            bra.b   .DrawRun
; NextLogoPixel
; Advance the logo pen one pixel
NextLogoPixel:
            dbra    D2,.Return
            move.w  #7,D2
            addq.w  #1,A4
.Return:
            rts
; BootLogoRLE
; Logo rows: alternating draw and skip run lengths adding up to 255; a 0 ends it
BootLogoRLE:
            dc.b    $FF,$7A,$1B
            dc.b    'jp+di6`c@'
            dc.w    $1404,$0605,$395D,$4A0F,$1138,$5852,$0D11,$3753
            dc.w    $590B,$1434,$4E60,$041C,$3149,$882E,$0604,$3A8F
            dc.w    $2C08,$0532,$1D10,$5306,$0F2B,$0A09,$261C,$1B4A
            dc.w    $1107,$2D0D,$0E18,$1C23,$414C,$1237,$2B15,$0B16
            dc.w    $5518,$2836,$120D,$0A60,$2414,$3F10,$0D09,$6278
            dc.w    $0E0A,$0B64,$790D,$060A,$6979,$0D79,$7A0C,$797B
            dc.w    $0B79,$7B0B,$797C,$0A79,$7C0B,$787C,$1172,$8013
            dc.w    $6C86,$1366,$8C11,$6292,$0C61,$9807,$60FF,0
; CopyIconMask
; Copy a 32x32 icon from A1 to A0 and build its mask
CopyIconMask:
            movem.l D0-D3,-(SP)
            move.w  #$1F,D3
.NextRow:
            move.l  (A1)+,D0
            moveq   #-1,D1
            move.w  #$1F,D2
.FromLeft:
            btst    D2,D0
            bne.b   .Right
            bclr    D2,D1
            dbra    D2,.FromLeft
.StoreRow:
            move.l  D1,($80,A0)
            move.l  D0,(A0)+
            dbra    D3,.NextRow
            movem.l (SP)+,D0-D3
            adda.w  #$80,A0
            rts
.Right:
            clr.w   D2
.FromRight:
            btst    D2,D0
            bne.b   .StoreRow
            bclr    D2,D1
            addq.w  #1,D2
            bra.b   .FromRight
; AddDriveQEl
; AddDriveQEl(refNum, size, qEl, firstDrive): add at the first free drive number
AddDriveQEl:
            link.w  A6,#-$32
            movem.l D1-D4/A1-A3,-(SP)
            lea     DrvQHdr,A2
            movea.l (6,A2),A3
            movea.l (2,A2),A1
            moveq   #0,D0
            move.w  ($16,A6),D0
            move.w  ($A,A6),D3
.Scan:
            cmp.w   (8,A1),D3
            beq.b   .Found
            cmp.w   (6,A1),D0
            beq.b   .Taken
            cmpa.l  A1,A3
            beq.b   .Free
            movea.l (A1),A1
            bra.b   .Scan
.Found:
            move.w  (6,A1),D0                       ; Already in the queue: its drive number
            bra.b   .Done
.Taken:
            movea.l (2,A2),A1
            addq.w  #1,D0
            bra.b   .Scan
.Free:
            move.w  D0,D3
            movea.l ($10,A6),A0
            cmpa.w  #0,A0
            bne.b   .FillQEl
            moveq   #$14,D0
            _NewPtrSys
            beq.b   .NewQEl
            bra.b   .Done
.NewQEl:
            move.l  #$80000,(A0)+                   ; Flags: non-ejectable
.FillQEl:
            move.w  #1,(4,A0)
            clr.w   ($A,A0)
            move.w  ($C,A6),($E,A0)
            move.w  ($E,A6),($C,A0)
            move.w  D3,D0
            swap    D0
            move.w  ($A,A6),D0
            _AddDrive
            move.w  D3,D0
.Done:
            movem.l (SP)+,D1-D4/A1-A3
            unlk    A6
            rts
; Mul32
; D0 = D0 * D1 (32 bits)
Mul32:
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
; Div32
; D1 = D0 / D1, D0 = D0 mod D1 (unsigned)
Div32:
            movem.l D2-D4,-(SP)
            move.l  D1,D2
            swap    D2
            tst.w   D2
            bne.b   .Long
            move.w  D0,D3
            clr.w   D0
            swap    D0
            beq.b   .LowWord
            divu.w  D1,D0
            move.w  D0,D2
.LowWord:
            swap    D2
            move.w  D3,D0
            divu.w  D1,D0
            move.w  D0,D2
            move.l  D2,D1
            clr.w   D0
            swap    D0
            bra.b   .Done
.Long:
            move.l  D0,D2
            clr.w   D0
            swap    D0
            swap    D2
            clr.w   D2
            move.l  D1,D3
            moveq   #0,D1
            moveq   #$F,D4
.Shift:
            add.l   D2,D2
            addx.l  D0,D0
            add.l   D1,D1
            cmp.l   D3,D0
            bcs.b   .NextBit
            sub.l   D3,D0
            addq.b  #1,D1
.NextBit:
            dbra    D4,.Shift
.Done:
            movem.l (SP)+,D2-D4
            rts
; Div32Quot
; D0 = D0 / D1
Div32Quot:
            jsr     Div32
            move.l  D1,D0
            rts
; VInstallGlue
; Pascal glue for _VInstall (unused)
VInstallGlue:
            movea.l (SP)+,A1
            movea.l (SP)+,A0
            _VInstall
            move.w  D0,(SP)
            jmp     (A1)
; PostEventGlue
; Pascal glue for _PostEvent
PostEventGlue:
            movea.l (SP)+,A1
            move.l  (SP)+,D0
            movea.w (SP)+,A0
            _PostEvent
            move.w  D0,(SP)
            jmp     (A1)
; OffLineGlue
; Pascal glue for _OffLine (unused)
OffLineGlue:
            movea.l (SP)+,A1
            movea.l (SP)+,A0
            move.l  A1,-(SP)
            _OffLine
            move.w  D0,(4,SP)
            rts
; GetDCtlGlue
; GetDCtlEntry(refNum) (unused)
GetDCtlGlue:
            movea.l (SP)+,A0
            move.w  (SP)+,D0
            addq.w  #1,D0
            neg.w   D0
            lsl.w   #2,D0
            movea.l UTableBase,A1
            move.l  (0,A1,D0.w),(SP)
            jmp     (A0)
; BlockMoveGlue
; BlockMoveGlue(src, dst, count): Pascal glue for _BlockMove
BlockMoveGlue:
            move.l  (SP)+,D1                        ; Get return address
            move.l  (SP)+,D0                        ; Get byte count
            movea.l (SP)+,A1                        ; Get destination pointer
            movea.l (SP)+,A0                        ; Get source pointer
            _BlockMove
            movea.l D1,A1                           ; Restore return address
            move.l  A1,-(SP)                        ; Put return address back on the stack
            move.w  D0,MemErr
            rts
; NewPtrGlue
; Pascal glue for _NewPtr
NewPtrGlue:
            movea.l (SP)+,A1
            move.l  (SP)+,D0
            _NewPtr
            move.l  A0,(SP)
            move.l  A1,-(SP)
            move.w  D0,MemErr
            rts
; .RAMd, the Outbound silicon disk. Up to 16 banks, selected through $500001-$500007,
; each with two 512K windows at $600000 and $680000. A window can have memory on its
; even bytes, its odd bytes or both: each populated byte lane is a 256K unit of 511
; data blocks plus one block of checksums (one XOR byte per block) at its start.
; Writes need VIA port B bit 5 low. Globals at OutboundGlobals+: $FA bank table (16 bytes:
; bits 0-3 units, 4-5 low window lanes, 6-7 high window lanes), $13A drive number,
; $13C units found.

; InstallRAMdDrvr
; Install .RAMd at refNum -50 and open it
InstallRAMdDrvr:
            movem.l D0-D7/A0-A6,-(SP)
            moveq   #-$32,D0                        ; refNum -50
            _DrvrInstall
            lea     RAMdDriver,A1
            movea.l UTableBase,A0
            movea.l ($C4,A0),A0
            movea.l (A0),A0
            move.l  A1,(A0)+                        ; dCtlDriver = RAMdDriver (a pointer, not a handle)
            move.w  (A1),(A0)+                      ; dCtlFlags = drvrFlags
            suba.w  #$32,SP
            movea.l SP,A0
            clr.b   ($1B,A0)
            lea     RAMdDriver.Name,A1
            move.l  A1,($12,A0)
            clr.l   ($C,A0)
            _Open
            adda.w  #$32,SP
            movem.l (SP)+,D0-D7/A0-A6
            rts
RAMdDriver:
            dc.w    $4F00                       ; Driver '.RAMd' - drvrFlags
            dc.w    0                           ; drvrDelay
            dc.w    $0000                       ; drvrEMask
            dc.w    0                           ; drvrMenu
            dc.w    RAMdOpen-RAMdDriver         ; drvrOpen
            dc.w    RAMdPrime-RAMdDriver        ; drvrPrime
            dc.w    RAMdCtl-RAMdDriver          ; drvrCtl
            dc.w    RAMdStatus-RAMdDriver       ; drvrStatus
            dc.w    RAMdClose-RAMdDriver        ; drvrClose
.Name:
            dc.b    5,'.RAMd'
; RAMdOpen
; Open: size the silicon disk; add a drive of 511 blocks per unit, or openErr if
; there is none
RAMdOpen:
            movem.l D0/A0-A1,-(SP)
            bsr.w   SizeRAMDisk
            movea.l (OutboundGlobals).l,A2
            tst.b   (RAMDiskSize,A2)                ; Units found (256K each)
            beq.b   .NoMemory
            moveq   #4,D0                           ; AddDriveQEl(refNum, units * 511 blocks, nil, 4)
            move.l  D0,-(SP)
            move.b  (RAMDiskSize,A2),D0
            mulu.w  #$1FF,D0
            clr.l   -(SP)
            move.l  D0,-(SP)
            move.w  ($18,A1),D0
            ext.l   D0
            move.l  D0,-(SP)
            bsr.w   AddDriveQEl
            move.w  D0,(RAMDiskDrive,A2)            ; Drive number
            lea     ($10,SP),SP
            bset    #5,(4,A1)                       ; dNeedTime: accRun posts diskInsertEvt
            move.w  #1,($22,A1)                     ; dCtlDelay = 1
            move.l  #$11A,D0                        ; dCtlStorage: icon, mask and name
            _NewPtrSys
            movea.l (8,SP),A1
            move.l  A0,($14,A1)
            lea     RAMdIcon,A1
            jsr     CopyIconMask                    ; Icon and its mask
            move.w  #$19,D0                         ; Name
.CopyName:
            move.b  (A1)+,(A0)+
            dbra    D0,.CopyName
            movem.l (SP)+,D0/A0-A1
            clr.w   ($10,A0)                        ; ioResult = noErr
            rts
.NoMemory:
            movem.l (SP)+,D0/A0-A1
            move.w  #$FFE9,($10,A0)                 ; No memory: openErr
            rts
; RAMdClose
; Close: nothing to do
RAMdClose:
            clr.w   D0
            rts
; RAMdPrime
; Prime: read, write or verify whole blocks through RAMdXfer
RAMdPrime:
            move.l  ($10,A1),D0
            move.l  D0,D4
            moveq   #9,D2
            lsr.l   D2,D0                           ; First block
            move.l  ($24,A0),D1
            lsr.l   D2,D1                           ; Block count
            movea.l ($20,A0),A3                     ; ioBuffer
            bclr    #5,(4,A1)                       ; Clear dNeedTime: no more accRun once it is used
            bsr.b   RAMdXfer
            add.l   ($24,A0),D4
            move.l  D4,($10,A1)                     ; Advance dCtlPosition
            move.l  ($24,A0),($28,A0)               ; ioActCount = ioReqCount
            btst    #1,(6,A0)
            bne.b   .Immediate
            move.l  JIODone,-(SP)                   ; Not immediate: finish through IODone
.Immediate:
            move.l  D7,D0
            rts
; RAMdXfer
; RAMdXfer(D0 = block, D1 = count, A3 = buffer, A0 = pb): map the blocks to a
; bank, window and byte lane and transfer them a window at a time; result in D7
RAMdXfer:
            link.w  A6,#-$14
            movem.l D0-D6/A0-A6,-(SP)
            moveq   #0,D7
            clr.b   (-2,A6)                         ; Mode: bit 0 read, 1 write (neither = verify), 2 word lane, 4 high window
            move.w  (6,A0),D2
            andi.w  #$F,D2
            cmpi.w  #2,D2                           ; Read?
            beq.b   .Read
            bset    #1,(-2,A6)
            bra.b   .Setup
.Read:
            btst    #6,($2D,A0)                     ; rdVerify: verify, else a plain read
            bne.b   .Setup
            bset    #0,(-2,A6)
.Setup:
            movea.l (OutboundGlobals).l,A2
            adda.w  #RAMDiskBanks,A2                ; Bank table
            move.w  D0,(-4,A6)
            move.w  D1,(-6,A6)
            move.l  A3,(-$E,A6)
            movea.l A3,A0
            move.w  D0,D3
            ext.l   D3
            divs.w  #$1FF,D3                        ; 511 blocks per unit: unit, and block within it
            swap    D3
            move.w  D3,(-$A,A6)
            swap    D3
            ext.l   D3
            clr.w   D0
            clr.w   D1
            clr.w   D2
.FindBank:
            move.w  #$F,D4                          ; Find the bank holding this unit
            and.b   (0,A2,D0.w),D4
            beq.b   .NextBank
            add.w   D4,D1
            cmp.w   D3,D1
            bhi.b   .FoundBank
            move.w  D1,D2
.NextBank:
            addq.w  #1,D0
            cmpi.w  #$10,D0
            bne.b   .FindBank
            bra.w   .PastEnd
.FoundBank:
            sub.w   D2,D3                           ; Unit within the bank
            move.w  D3,D1
            move.b  (0,A2,D0.w),D2
            lsr.b   #4,D2
            move.b  #3,D3
            and.w   D2,D3
            move.b  .UnitsPerMode(PC,D3.w),D4                 ; Units in the low window
            bra.b   .CheckHigh
.UnitsPerMode:
            dc.w    $0001,$0102                     ; Units for lane modes 0-3
.CheckHigh:
            sub.w   D4,D1
            blt.b   .LowWindow
            bset    #4,(-2,A6)                      ; In the high window
            lsr.b   #2,D2
            bra.b   .WindowMode
.LowWindow:
            add.w   D4,D1
.WindowMode:
            andi.w  #3,D2
            cmpi.w  #3,D2                           ; Second unit of a word window: 511 blocks on
            bne.b   .Window
            tst.w   D1
            beq.b   .Window
            addi.w  #$1FF,(-$A,A6)
.Window:
            move.w  D0,(-$10,A6)                    ; Bank
            bsr.w   SelectBank
            movea.l #RAMDiskBase,A1                 ; Low window; the high one is at $680000
            clr.w   D2
            move.b  (0,A2,D0.w),D2
            lsr.b   #4,D2
            btst    #4,(-2,A6)
            beq.b   .Lanes
            lsr.b   #2,D2
            adda.l  #$80000,A1
.Lanes:
            clr.w   D3
            andi.b  #3,D2
            beq.b   .NextWindow
            move.b  .UnitsPerMode(PC,D2.w),D3                 ; Skip the checksum block(s) at the start
            add.w   D3,(-$A,A6)
            bclr    #2,(-2,A6)
            move.w  #$200,D3                        ; Window size: 512 blocks, 1024 for a word lane
            cmpi.b  #3,D2
            bne.b   .ByteLane
            bset    #2,(-2,A6)
            move.w  #$400,D3
            bra.b   .Chunk
.ByteLane:
            cmpi.w  #1,D2                           ; Mode 1: even bytes; mode 2: odd bytes
            beq.b   .Chunk
            addq.w  #1,A1
.Chunk:
            move.w  (-$A,A6),D6                     ; This chunk: up to the end of the window
            add.w   (-6,A6),D6
            cmp.w   D6,D3
            bhi.b   .Rest
            move.w  D3,D6
            sub.w   (-$A,A6),D6
            bra.b   .Count
.Rest:
            move.w  (-6,A6),D6
.Count:
            sub.w   D6,(-6,A6)
            move.w  D6,(-8,A6)
            btst    #2,(-2,A6)                      ; Word lane or byte lane
            bne.b   .WordLane
            bsr.b   ByteLaneXfer
            bra.b   .ChunkDone
.WordLane:
            bsr.w   WordLaneXfer
.ChunkDone:
            tst.l   D7
            bne.b   .Done
            tst.w   (-6,A6)
            beq.b   .Done
.NextWindow:
            clr.w   (-$A,A6)                        ; Next window: high half of this bank, then the next bank
            move.w  (-$10,A6),D0
            bchg    #4,(-2,A6)
            beq.w   .Window
            addq.w  #1,D0
            cmpi.w  #$10,D0
            beq.b   .PastEnd
            bra.w   .Window
.PastEnd:
            moveq   #-$24,D7                        ; Past the last bank: ioErr
.Done:
            movem.l (SP)+,D0-D6/A0-A6
            unlk    A6
            rts
; ByteLaneXfer
; Move a chunk through one byte lane (every other address) with movep, 16 bytes at a time;
; checksums written before a write, checked after a read
ByteLaneXfer:
            moveq   #0,D0
            move.w  (-$A,A6),D0
            lsl.l   #5,D0                           ; Block * 1024: two addresses per byte
            lsl.l   #5,D0
            adda.l  D0,A1
            moveq   #0,D0
            move.w  (-8,A6),D0
            lsl.l   #5,D0
            subq.l  #1,D0                           ; 16-byte groups
            move.l  A0,D2
            btst    #1,(-2,A6)                      ; Write?
            beq.b   .Read
            bset    #RAMDiskBit,(OutboundVIA+vDIRB).l ; Write enable: VIA port B bit 5 low
            bclr    #RAMDiskBit,(OutboundVIA).l
            bsr.w   PutChecksums                      ; Checksums first
            btst    #0,D2                           ; Odd buffer: first byte alone, then shift the lane by one
            beq.b   .WriteGroup
            move.b  (A0)+,(A1)
            subq.l  #6,A1
            bra.b   .WriteRest
.WriteGroup:
            move.l  (A0)+,D1
            movep.l D1,0.w(A1)                      ; 4 bytes to every other address
.WriteRest:
            move.l  (A0)+,D1
            movep.l D1,(8,A1)
            move.l  (A0)+,D1
            movep.l D1,($10,A1)
            move.l  (A0)+,D1
            movep.l D1,($18,A1)
            adda.w  #$20,A1
            dbra    D0,.WriteGroup
            btst    #0,D2                           ; Odd buffer: last 3 bytes
            beq.b   .WriteDone
            move.w  (A0)+,D1
            movep.w D1,0.w(A1)
            move.b  (A0)+,(4,A1)
.WriteDone:
            moveq   #0,D7
            bset    #RAMDiskBit,(OutboundVIA).l     ; Write protect again
            rts
.Read:
            btst    #0,(-2,A6)                      ; Read?
            beq.b   .Verify
            btst    #0,D2
            beq.b   .ReadGroup
            move.b  (A1),(A0)+
            subq.l  #6,A1
            bra.b   .ReadRest
.ReadGroup:
            movep.l 0.w(A1),D1
            move.l  D1,(A0)+
.ReadRest:
            movep.l (8,A1),D1
            move.l  D1,(A0)+
            movep.l ($10,A1),D1
            move.l  D1,(A0)+
            movep.l ($18,A1),D1
            move.l  D1,(A0)+
            adda.w  #$20,A1
            dbra    D0,.ReadGroup
            btst    #0,D2
            beq.b   .ReadDone
            movep.w 0.w(A1),D1
            move.w  D1,(A0)+
            move.b  (4,A1),(A0)+
.ReadDone:
            exg     D2,A0
            bsr.w   CheckChecksums                      ; Check the checksums
            bne.b   .Mismatch
            exg     D2,A0
            moveq   #0,D7
            rts
.Verify:
            btst    #0,D2                           ; Verify: compare
            beq.b   .VerifyGroup
            move.b  (A0)+,D1
            cmp.b   (A1),D1
            bne.b   .Mismatch
            subq.w  #6,A1
            bra.b   .VerifyRest
.VerifyGroup:
            movep.l 0.w(A1),D1
            cmp.l   (A0)+,D1
            bne.b   .Mismatch
.VerifyRest:
            movep.l (8,A1),D1
            cmp.l   (A0)+,D1
            bne.b   .Mismatch
            movep.l ($10,A1),D1
            cmp.l   (A0)+,D1
            bne.b   .Mismatch
            movep.l ($18,A1),D1
            cmp.l   (A0)+,D1
            bne.b   .Mismatch
            adda.w  #$20,A1
            dbra    D0,.VerifyGroup
            btst    #0,D2
            beq.b   .Ok
            movep.w 0.w(A1),D1
            cmp.w   (A0)+,D1
            bne.b   .Mismatch
            move.b  (A0)+,D1
            cmp.b   (4,A1),D1
            bne.b   .Mismatch
.Ok:
            moveq   #0,D7
            rts
.Mismatch:
            moveq   #-$44,D7                        ; Mismatch: dataVerErr
            rts
; WordLaneXfer
; The same for a window with both lanes, using BlockMove
WordLaneXfer:
            move.w  #9,D6
            moveq   #0,D0
            move.w  (-$A,A6),D0
            lsl.l   D6,D0                           ; Block * 512
            adda.l  D0,A1
            moveq   #0,D0
            move.w  (-8,A6),D0
            lsl.l   D6,D0
            movem.l D0/A0,-(SP)
            btst    #1,(-2,A6)                      ; Write?
            bne.b   .Write
            btst    #0,(-2,A6)                      ; Read?
            beq.b   .Verify
            exg     A0,A1                           ; Read: copy out, then check the checksums
            _BlockMove
            exg     A0,A1
            bsr.w   CheckChecksums
            beq.b   .Done
            movem.l (SP)+,D0/A0
            bra.b   ByteLaneXfer.Mismatch
.Write:
            bset    #RAMDiskBit,(OutboundVIA+vDIRB).l ; Write: enable, checksums, copy in
            bclr    #RAMDiskBit,(OutboundVIA).l
            bsr.w   PutChecksums
            _BlockMove
            bset    #RAMDiskBit,(OutboundVIA).l
.Done:
            movem.l (SP)+,D0/A0
            adda.l  D0,A0
            bra.b   ByteLaneXfer.Ok
.Verify:
            movem.l (SP)+,D0/A0
.Compare:
            cmpm.b  (A0)+,(A1)+                     ; Verify: compare
            bne.b   ByteLaneXfer.Mismatch
            subq.l  #1,D0
            bne.b   .Compare
            moveq   #0,D7
            rts
; BlockChecksum
; XOR of the D1+1 bytes at A0, folded to a byte in D0
BlockChecksum:
            movem.l D1-D2/A0,-(SP)
            moveq   #0,D0
            move.l  A0,D2
            btst    #0,D2
            bne.b   .Bytes
            addq.l  #1,D1                           ; 16 bytes at a time when aligned
            asr.l   #4,D1
            subq.l  #1,D1
.Longs:
            move.l  (A0)+,D2
            eor.l   D2,D0
            move.l  (A0)+,D2
            eor.l   D2,D0
            move.l  (A0)+,D2
            eor.l   D2,D0
            move.l  (A0)+,D2
            eor.l   D2,D0
            dbra    D1,.Longs
            move.l  D0,D2                           ; Fold to a byte
            asr.w   #8,D2
            eor.b   D2,D0
            swap    D2
            eor.b   D2,D0
            asr.w   #8,D2
            eor.b   D2,D0
            bra.b   .Done
.Bytes:
            move.b  (A0)+,D2                        ; Odd address: a byte at a time
            eor.b   D2,D0
            dbra    D1,.Bytes
.Done:
            movem.l (SP)+,D1-D2/A0
            rts
; ChecksumAddr
; A1 = checksum byte of the first block of the chunk, D4 = stride, D3 = blocks - 1,
; D1 = 511
ChecksumAddr:
            movea.l #RAMDiskBase,A1
            move.w  (-$10,A6),D0
            move.b  (0,A2,D0.w),D4
            btst    #4,(-2,A6)
            beq.b   .Mode
            adda.l  #$80000,A1
            lsr.b   #2,D4
.Mode:
            andi.b  #$30,D4                         ; Lane mode: word, even or odd
            cmpi.b  #$30,D4
            beq.b   .WordStride
            cmpi.b  #$10,D4
            beq.b   .ByteStride
            addq.w  #1,A1
.ByteStride:
            moveq   #2,D4
            bra.b   .Offset
.WordStride:
            moveq   #1,D4
.Offset:
            move.w  (-$A,A6),D3
            mulu.w  D4,D3
            adda.w  D3,A1
            move.w  (-8,A6),D3
            subq.w  #1,D3
            move.l  #$1FF,D1
            rts
; PutChecksums
; Store the checksum of each block about to be written
PutChecksums:
            movem.l D0-D4/A0-A3,-(SP)
            bsr.b   ChecksumAddr
.Next:
            bsr.w   BlockChecksum
            move.b  D0,(A1)
            adda.l  D4,A1
            adda.l  D1,A0
            addq.l  #1,A0
            dbra    D3,.Next
            movem.l (SP)+,D0-D4/A0-A3
            rts
; CheckChecksums
; Z set if every block read matches its checksum
CheckChecksums:
            movem.l D0-D5/A0-A3,-(SP)
            bsr.b   ChecksumAddr
.Next:
            bsr.w   BlockChecksum
            move.b  (A1),D5
            cmp.b   D0,D5
            bne.b   .Done
            adda.l  D4,A1
            adda.l  D1,A0
            addq.l  #1,A0
            dbra    D3,.Next
            cmp.w   D0,D0
.Done:
            movem.l (SP)+,D0-D5/A0-A3
            rts
; RAMdCtl
; Control: 5 verify, 6 format, 7 eject, 21-23 icon, 65 accRun
RAMdCtl:
            clr.w   D0
            cmpi.w  #$41,($1A,A0)
            beq.b   .AccRun
            cmpi.w  #5,($1A,A0)
            beq.b   .Verify
            cmpi.w  #6,($1A,A0)
            beq.b   .Format
            cmpi.w  #7,($1A,A0)
            beq.w   .Eject
            cmpi.w  #$15,($1A,A0)
            beq.w   .Icon
            cmpi.w  #$16,($1A,A0)
            beq.w   .Icon
            cmpi.w  #$17,($1A,A0)
            beq.w   .Icon
            move.w  #$FFEF,D0
            bra.w   .Finish
.AccRun:
            movem.l D0/A0-A1,-(SP)
            bclr    #5,(4,A1)                       ; 65 accRun: once only
            tst.w   SysEvtMask                      ; Events not set up yet: try again in 60 ticks
            bne.b   .Post
            bset    #5,(4,A1)
            move.w  #$3C,($22,A1)
            bra.b   .AccRunDone
.Post:
            movea.w #7,A0                           ; Post diskInsertEvt for the drive
            movea.l (OutboundGlobals).l,A1
            moveq   #0,D0
            move.w  (RAMDiskDrive,A1),D0
            _PostEvent
.AccRunDone:
            movem.l (SP)+,D0/A0-A1
            bra.w   .Finish
.Verify:
            bra.w   .Finish                            ; 5 verify: nothing to do
.Format:
            movem.l D0-D1/A0-A1,-(SP)               ; 6 format: zero every bank
            move.w  #$F,D0
            moveq   #0,D1
            lea     (RAMDiskBase+$100000).l,A1
            bset    #RAMDiskBit,(OutboundVIA+vDIRB).l ; Write enable
            bclr    #RAMDiskBit,(OutboundVIA).l
.FormatBank:
            bsr.w   SelectBank
            lea     (RAMDiskBase).l,A0
            clr.w   (A0)                            ; Memory here?
            tst.b   (A0)
            beq.b   .ClearBank
            tst.b   (1,A0)
            bne.b   .NextBank
.ClearBank:
            move.l  D1,(A0)+                        ; Clear $600000-$6FFFFF
            move.l  D1,(A0)+
            move.l  D1,(A0)+
            move.l  D1,(A0)+
            cmpa.l  A0,A1
            bne.b   .ClearBank
.NextBank:
            dbra    D0,.FormatBank
            bset    #RAMDiskBit,(OutboundVIA).l     ; Write protect again
            movem.l (SP)+,D0-D1/A0-A1
            bra.b   .Finish
.Eject:
            btst    #CfgBit5,(OutboundCfg).l        ; 7 eject: while booting, refuse and remount in 30 ticks
            beq.b   .EjectOk
            bset    #5,(4,A1)
            move.w  #$1E,($22,A1)
            move.w  #$FFEF,D0
            bra.b   .Finish
.EjectOk:
            clr.w   D0                              ; After boot: noErr
            bra.b   .Finish
.Icon:
            move.l  ($14,A1),($1C,A0)               ; 21-23: dCtlStorage (icon), for 23 as well
            bra.b   .Finish
            move.l  #$602,($1C,A0)                  ; Unreachable: probably meant for 23 (drive info)
.Finish:
            btst    #1,(6,A0)                       ; Not immediate: finish through IODone
            bne.b   .Return
            move.l  JIODone,-(SP)
.Return:
            rts
; RAMdStatus
; Status: 8 drive status, statusErr for anything else
RAMdStatus:
            move.w  #$FFEE,D0
            cmpi.w  #8,($1A,A0)
            bne.b   .Finish
            lea     ($1C,A0),A2                     ; Drive status record
            clr.w   (A2)
            clr.b   (2,A2)
            move.b  #1,(3,A2)                       ; diskInPlace
            move.b  #1,(4,A2)                       ; installed
            move.w  ($16,A0),($C,A2)                ; dQDrive = ioVRefNum
            move.w  ($18,A0),($E,A2)                ; dQRefNum = ioRefNum
            clr.w   ($10,A2)
            clr.w   ($14,A2)
            clr.w   D0
.Finish:
            btst    #1,(6,A0)                       ; No branch: always finishes through IODone
            move.l  JIODone,-(SP)
            rts
; RAMdIcon
; Icon (mask built at open) and the name Get Info shows
RAMdIcon:
            dc.l    %00000000000000000000000000000000
            dc.l    %00000000000000000000000000000000
            dc.l    %00000000000000000000000000000000
            dc.l    %01111111111111111111111110000000
            dc.l    %01000000000000000000000010000000
            dc.l    %01011011011011011011011010000000
            dc.l    %01011011011011011011011010000000
            dc.l    %01011011011011011011011010000000
            dc.l    %01011111111111111111111111100000
            dc.l    %01010000000000000000000000100000
            dc.l    %01110110110110110110110110100000
            dc.l    %00010110110110110110110110100000
            dc.l    %00010110110110110110110110100000
            dc.l    %00010111111111111111111111111000
            dc.l    %00010100000000000000000000001000
            dc.l    %00011101101101101101101101101000
            dc.l    %00000101101101101101101101101000
            dc.l    %00000101101101101101101101101000
            dc.l    %00000101111111111111111111111110
            dc.l    %00000101000000000000000000000010
            dc.l    %00000111011011011011011011011010
            dc.l    %00000001011011011011011011011010
            dc.l    %00000001011011011011011011011010
            dc.l    %00000001011011011011011011011010
            dc.l    %00000001000000000000000000000010
            dc.l    %00000001111111111111111111111110
            dc.l    %00000000011111111111111111111000
            dc.l    %00000000000000000000000000000000
            dc.l    %00000000000000000000000000000000
            dc.l    %00000000000000000000000000000000
            dc.l    %00000000000000000000000000000000
            dc.l    %00000000000000000000000000000000
.Name:
            dc.b    21,'Outbound Silicon Disk'
; SelectBank
; Latch bank D0 (0-15), one bit per register at $500001-$500007
SelectBank:
            move.b  D0,(RAMDiskBank).l
            ror.b   #1,D0
            move.b  D0,(RAMDiskBank+2).l
            ror.b   #1,D0
            move.b  D0,(RAMDiskBank+4).l
            ror.b   #1,D0
            move.b  D0,(RAMDiskBank+6).l
            rol.b   #3,D0
            rts
; SizeRAMDisk
; Find which byte lanes of each bank hold memory (an aliased bank reads back the $FF
; already written and is skipped); count in $13C, lane modes in the bank table
SizeRAMDisk:
            bset    #RAMDiskBit,(OutboundVIA+vDIRB).l ; Write enable
            bclr    #RAMDiskBit,(OutboundVIA).l
            movem.l D0-D3/A0-A4,-(SP)
            movea.l #RAMDiskBase,A0
            movea.l #RAMDiskHigh,A1
            movea.l (OutboundGlobals).l,A2
            movea.l A2,A4
            adda.w  #RAMDiskBanks,A4
            clr.w   D0
.SaveBank:
            bsr.b   SelectBank
            move.w  (A0),-(SP)
            move.w  (A1),-(SP)
            clr.w   (A0)                            ; Save the first word of each window, then clear it
            clr.w   (A1)
            clr.b   (0,A4,D0.w)
            addq.w  #1,D0
            cmpi.w  #$10,D0
            bne.b   .SaveBank
            clr.w   D1
            clr.w   D2
            movea.l A0,A3
.Lane:
            clr.w   D0
.ProbeBank:
            bsr.b   SelectBank
            tst.b   (A3)                            ; Still 0 (not an alias of a bank already marked)?
            bne.b   .NextBank
            subq.b  #1,(A3)                         ; Write $FF; reads back negative if memory is there
            bpl.b   .NextBank
            bset    D1,(0,A4,D0.w)                  ; Lane D1 present in this bank
            addq.w  #1,D2
.NextBank:
            addq.w  #1,D0
            cmpi.w  #$10,D0
            bne.b   .ProbeBank
            addq.w  #1,D1                           ; Next lane: $600000 even, odd, then $680000 even, odd
            btst    #0,D1
            beq.b   .NextWindow
            addq.l  #1,A3
            bra.b   .Lane
.NextWindow:
            cmpi.w  #2,D1
            bne.b   .Count
            movea.l A1,A3
            bra.b   .Lane
.Count:
            move.b  D2,(RAMDiskSize,A2)             ; Units found
            clr.w   D2
            moveq   #$F,D0
.Restore:
            bsr.w   SelectBank
            move.b  (0,A4,D0.w),D2
            move.b  .LaneModes(PC,D2.w),D2                 ; Lane mask to modes (bits 4-5 low, 6-7 high, 0-3 units)
            move.b  D2,(0,A4,D0.w)
            move.w  (SP)+,(A1)                      ; Restore the saved words
            move.w  (SP)+,(A0)
            dbra    D0,.Restore
            movem.l (SP)+,D0-D3/A0-A4
            bset    #RAMDiskBit,(OutboundVIA).l     ; Write protect again
            rts
.LaneModes:
            dc.w    $0011                           ; Modes for lane masks 0-15
            dc.b    '!2ARbs'
            dc.w    $8192,$A2B3,$C2D3,$E3F4
; PTekDoOpen
; PTekDoOpen(pb, dce): reset and identify the drive, set its geometry, add it
PTekDoOpen:
            link.w  A6,#-$204
            movem.l D3/D7/A3-A4,-(SP)
            movea.l #ATAStatus,A3                   ; ATA status/command register
            subq.l  #4,SP
            moveq   #$A,D0
            move.l  D0,-(SP)
            jsr     NewPtrGlue                      ; Geometry: heads, cylinders, sectors/track, drive number
            move.l  (SP)+,(-4,A6)
            movea.l ($C,A6),A0
            move.l  (-4,A6),($14,A0)                ; dCtlStorage
            movea.l (-4,A6),A0
            clr.w   (8,A0)
            move.b  #6,(ATADevCtl).l                ; Device control: soft reset, no interrupts
            moveq   #$20,D7
.ResetDelay:
            subq.l  #1,D7
            bne.b   .ResetDelay
            move.b  #2,(ATADevCtl).l                ; Release reset
            move.l  #$989680,D7
            bra.b   .WaitReady
.ReadyTimeout:
            subq.l  #1,D7
            bne.b   .WaitReady
            moveq   #-$24,D0                        ; ioErr on timeout
            bra.w   .Done
.WaitReady:
            move.w  #$80,D0                         ; Wait for not BSY and DRDY
            and.b   (A3),D0
            bne.b   .ReadyTimeout
            moveq   #$40,D0
            and.b   (A3),D0
            beq.b   .ReadyTimeout
            move.b  #$EC,(ATAStatus).l              ; IDENTIFY DRIVE
            move.l  #$989680,D7
            bra.b   .WaitDRQ
.DRQTimeout:
            subq.l  #1,D7
            bne.b   .WaitDRQ
            moveq   #-$24,D0
            bra.w   .Done
.WaitDRQ:
            move.w  #$80,D0                         ; Wait for not BSY and DRQ
            and.b   (A3),D0
            bne.b   .DRQTimeout
            moveq   #8,D0
            and.b   (A3),D0
            beq.b   .DRQTimeout
            moveq   #0,D7
            lea     (-$204,A6),A4
            move.l  #$100,D3
            bra.b   .ReadLoop
.ReadWord:
            move.w  (ATAData).l,(A4)+               ; Data register: 256 words of identify data
            addq.l  #1,D7
.ReadLoop:
            cmp.l   D7,D3
            bgt.b   .ReadWord
            cmpi.w  #$F5A,(-$204,A6)                ; General configuration $0F5A or $0A5A, else ioErr
            beq.b   .GoodDrive
            cmpi.w  #$A5A,(-$204,A6)
            beq.b   .GoodDrive
            moveq   #-$24,D0
            bra.w   .Done
.GoodDrive:
            movea.l (-4,A6),A0
            move.w  (-$1F8,A6),(4,A0)               ; Sectors per track (word 6)
            movea.l (-4,A6),A0
            move.w  (-$202,A6),(2,A0)               ; Cylinders (word 1)
            movea.l (-4,A6),A0
            move.w  (-$1FE,A6),(A0)                 ; Heads (word 3)
            movea.l (-4,A6),A0
            move.b  (5,A0),(ATASecCnt).l            ; Sector count = sectors per track
            movea.l (-4,A6),A0
            move.w  (A0),D0
            add.w   #$1F,D0
            move.b  D0,(ATADrvHead).l               ; Drive/head: $20 + last head
            movea.l (-4,A6),A0
            move.b  (3,A0),(ATACylLo).l             ; Cylinder low
            movea.l (-4,A6),A0
            move.w  (2,A0),D0
            ext.l   D0
            asr.l   #8,D0
            move.b  D0,(ATACylHi).l                 ; Cylinder high
            move.b  #$91,(ATAStatus).l              ; INITIALIZE DRIVE PARAMETERS
            jsr     ATAWaitReady
            moveq   #4,D0                           ; AddDriveQEl(refNum, blocks, nil, 4)
            move.l  D0,-(SP)
            moveq   #0,D1
            move.l  D1,-(SP)
            move.w  (-$202,A6),D2
            muls.w  (-$1F8,A6),D2                   ; Blocks = cylinders * sectors * heads
            move.w  (-$1FE,A6),D3
            ext.l   D3
            move.l  D2,D0
            move.l  D3,D1
            jsr     Mul32
            move.l  D0,-(SP)
            movea.l ($C,A6),A0
            move.w  ($18,A0),D0
            ext.l   D0
            move.l  D0,-(SP)
            jsr     AddDriveQEl
            movea.l (-4,A6),A0
            move.w  D0,(6,A0)                       ; Drive number
            movea.l ($C,A6),A0
            move.w  #1,($22,A0)                     ; dCtlDelay = 1
            movea.l ($C,A6),A0
            ori.w   #$2000,(4,A0)                   ; dNeedTime: accRun posts diskInsertEvt
            moveq   #0,D0
            lea     ($10,SP),SP
.Done:
            movem.l (-$214,A6),D3/D7/A3-A4
            unlk    A6
            rts
; ATASetCHS
; ATASetCHS(block, geom): load sector, head and cylinder for a block
ATASetCHS:
            link.w  A6,#-2
            movem.l D6-D7/A3,-(SP)
            move.l  (8,A6),D7
            movea.l ($C,A6),A3
            jsr     ATAWaitReady                      ; Wait for not BSY
            move.w  D0,D6
            bge.b   .Ready
            move.w  D6,D0
            bra.b   .Done
.Ready:
            move.w  (4,A3),D0
            ext.l   D0
            move.l  D0,D1
            move.l  D7,D0
            jsr     Div32
            addq.l  #1,D0
            move.b  D0,(ATASector).l                ; Sector = block mod sectors + 1
            move.w  (4,A3),D0
            ext.l   D0
            move.l  D0,D1
            move.l  D7,D0
            jsr     Div32Quot
            move.w  (A3),D1
            ext.l   D1
            jsr     Div32
            moveq   #$20,D1
            add.l   D1,D0
            move.b  D0,(ATADrvHead).l               ; Drive/head: $20 + (block / sectors) mod heads
            move.w  (A3),D0
            muls.w  (4,A3),D0
            move.l  D0,D1
            move.l  D7,D0
            jsr     Div32Quot
            move.w  D0,(-2,A6)
            move.b  (-2,A6),(ATACylHi).l            ; Cylinder high
            move.b  (-1,A6),(ATACylLo).l            ; Cylinder low
            moveq   #0,D0
.Done:
            movem.l (-$E,A6),D6-D7/A3
            unlk    A6
            rts
; PTekDoPrime
; PTekDoPrime(pb, dce): read or write whole blocks; verify reads do nothing
PTekDoPrime:
            link.w  A6,#0
            movem.l D4-D7/A3-A4,-(SP)
            movea.l (8,A6),A4
            movea.l ($C,A6),A0
            movea.l ($14,A0),A3
            moveq   #$40,D0                         ; rdVerify: nothing to do
            and.w   ($2C,A4),D0
            beq.b   .Transfer
            moveq   #0,D0
            bra.b   .Return
.Transfer:
            movea.l ($C,A6),A0
            move.l  ($10,A0),D4                     ; dCtlPosition
            moveq   #9,D0
            move.l  D4,D5
            lsr.l   D0,D5
            moveq   #9,D0
            move.l  ($24,A4),D6                     ; ioReqCount
            asr.l   D0,D6
            moveq   #$F,D0
            and.w   (6,A4),D0
            cmpi.w  #2,D0                           ; Read?
            bne.b   .Write
            movea.l ($C,A6),A0
            andi.w  #$DFFF,(4,A0)                   ; Clear dNeedTime: no more accRun once it reads
            move.l  ($20,A4),-(SP)
            moveq   #0,D0
            move.w  D6,D0
            move.l  D0,-(SP)
            move.l  D5,-(SP)
            move.l  A3,-(SP)
            jsr     ATAReadSectors
            move.w  D0,D7
            lea     ($10,SP),SP
            bra.b   .Finish
.Write:
            move.l  ($20,A4),-(SP)
            moveq   #0,D0
            move.w  D6,D0
            move.l  D0,-(SP)
            move.l  D5,-(SP)
            move.l  A3,-(SP)
            jsr     ATAWriteSectors
            move.w  D0,D7
            lea     ($10,SP),SP
.Finish:
            move.l  ($24,A4),($28,A4)               ; ioActCount = ioReqCount
            move.l  ($28,A4),D0
            add.l   D4,D0
            movea.l ($C,A6),A0
            move.l  D0,($10,A0)                     ; Advance dCtlPosition
            move.w  D7,D0
.Return:
            movem.l (-$18,A6),D4-D7/A3-A4
            unlk    A6
            rts
; PTekDoControl
; PTekDoControl(pb, dce): 1 killIO, 5 verify, 6 format, 7 eject, 21/22 icons, 65
; accRun
PTekDoControl:
            link.w  A6,#-4
            movem.l A3-A4,-(SP)
            movea.l ($C,A6),A4
            movea.l (8,A6),A3
            move.l  ($14,A4),(-4,A6)
            moveq   #1,D0                           ; 1 killIO: nothing to do
            cmp.w   ($1A,A3),D0
            beq.b   .NoErr
            move.w  ($1A,A3),D0
            subq.w  #5,D0
            beq.b   .Verify
            subq.w  #1,D0
            beq.b   .Format
            subq.w  #1,D0
            beq.b   .Eject
            subi.w  #$E,D0
            beq.b   .DriveIcon
            subq.w  #1,D0
            beq.b   .MediaIcon
            subi.w  #$2B,D0
            beq.b   .AccRun
            bra.b   .BadCode
.Verify:
            moveq   #0,D0                           ; 5 verify: nothing to do
            bra.b   .Done
.Format:
            move.l  (-4,A6),-(SP)                   ; 6: format the whole disk
            jsr     FormatHardDisk
            addq.l  #4,SP
            bra.b   .Done
.Eject:
            ori.w   #$2000,(4,A4)                   ; 7: can't eject; dNeedTime so accRun remounts it, controlErr
            moveq   #-$11,D0
            bra.b   .Done
.DriveIcon:
            lea     PTekDriveIcon,A0                ; 21: drive icon
            move.l  A0,($1C,A3)
            bra.b   .NoErr
.MediaIcon:
            lea     PTekMediaIcon,A0                ; 22: media icon
            move.l  A0,($1C,A3)
            bra.b   .NoErr
.AccRun:
            andi.w  #$DFFF,(4,A4)                   ; 65 accRun: once only
            subq.l  #2,SP
            moveq   #7,D0                           ; Post diskInsertEvt for the drive
            move.w  D0,-(SP)
            movea.l (-4,A6),A0
            move.w  (6,A0),D1
            ext.l   D1
            move.l  D1,-(SP)
            jsr     PostEventGlue
            addq.l  #2,SP
            bra.b   .NoErr
.BadCode:
            moveq   #-$11,D0                        ; Others: controlErr
            bra.b   .Done
.NoErr:
            moveq   #0,D0
.Done:
            movem.l (-$C,A6),A3-A4
            unlk    A6
            rts
; PTekDoStatus
; No status calls, always statusErr
PTekDoStatus:
            movem.l A3-A4,-(SP)
            movea.l ($C,SP),A3
            movea.l ($10,SP),A0
            movea.l ($14,A0),A4
            move.w  ($1A,A3),D0
            moveq   #-$12,D0                        ; statusErr
            bra.b   .Done
            dc.w    $002C,$7000                     ; Unreachable
.Done:
            movem.l (SP)+,A3-A4
            rts
; ATAFormatTrack
; ATAFormatTrack(geom, cyl, head, table): FORMAT TRACK; -64 on error
ATAFormatTrack:
            link.w  A6,#0
            movem.l D3/D6-D7/A3-A4,-(SP)
            move.l  ($C,A6),D6
            movea.l (8,A6),A4
            movea.l ($14,A6),A3
            jsr     ATAWaitReady
            tst.w   D0
            beq.b   .Ready
            moveq   #-$40,D0
            bra.b   .Done
.Ready:
            move.b  (5,A4),(ATASecCnt).l            ; Sector count = sectors per track
            move.l  D6,D0
            asr.l   #8,D0
            move.b  D0,(ATACylHi).l                 ; Cylinder high
            move.b  D6,(ATACylLo).l                 ; Cylinder low
            move.l  ($10,A6),D0
            moveq   #$20,D1
            add.l   D1,D0
            move.b  D0,(ATADrvHead).l               ; Drive/head: $20 + head
            move.b  #$50,(ATAStatus).l              ; FORMAT TRACK
            jsr     ATAWaitDRQ
            tst.w   D0
            beq.b   .SendTable
            moveq   #-$40,D0
            bra.b   .Done
.SendTable:
            moveq   #0,D7
            move.l  #$100,D3
.TableWord:
            move.w  (A3)+,(ATAData).l               ; 512-byte sector table
            addq.l  #1,D7
            cmp.l   D7,D3
            bgt.b   .TableWord
            jsr     ATAWaitReady
            move.b  (ATADevCtl).l,D0                ; Alternate status: ERR?
            btst    #0,D0
            beq.b   .Done
            moveq   #-$40,D0
.Done:
            movem.l (-$14,A6),D3/D6-D7/A3-A4
            unlk    A6
            rts
; FormatHardDisk
; FormatHardDisk(geom): format every track, sectors in order; errors ignored
FormatHardDisk:
            link.w  A6,#-$200
            movem.l D3/D6-D7/A3-A4,-(SP)
            movea.l (8,A6),A3
            lea     (-$200,A6),A4
            moveq   #1,D6
            bra.b   .GoodLoop
.GoodEntry:
            move.l  D6,D0
            lsl.l   #8,D0
            move.w  D0,(A4)+                        ; Table entry: flag 0 (good), sector n
            addq.l  #1,D6
.GoodLoop:
            move.w  (4,A3),D0
            ext.l   D0
            cmp.l   D6,D0
            bge.b   .GoodEntry
            move.w  (4,A3),D0
            ext.l   D0
            move.l  D0,D6
            move.l  #$100,D3
            bra.b   .ZeroLoop
.ZeroEntry:
            clr.w   (A4)+                           ; Rest of the table: zero
            addq.l  #1,D6
.ZeroLoop:
            cmp.l   D6,D3
            bgt.b   .ZeroEntry
            moveq   #0,D6
            bra.b   .CylLoop
.Cylinder:
            moveq   #0,D7
            bra.b   .HeadLoop
.Head:
            pea     (-$200,A6)
            move.l  D7,-(SP)
            move.l  D6,-(SP)
            move.l  A3,-(SP)
            jsr     ATAFormatTrack
            lea     ($10,SP),SP
            addq.l  #1,D7
.HeadLoop:
            move.w  (A3),D0
            ext.l   D0
            cmp.l   D7,D0
            bgt.b   .Head
            addq.l  #1,D6
.CylLoop:
            move.w  (2,A3),D0
            ext.l   D0
            cmp.l   D6,D0
            bgt.b   .Cylinder
            moveq   #0,D0
            movem.l (-$214,A6),D3/D6-D7/A3-A4
            unlk    A6
            rts
; InstallPTekDrvr
; Install .PTek at refNum -51 and open it
InstallPTekDrvr:
            movem.l D0-D7/A0-A6,-(SP)
            moveq   #-$33,D0                        ; refNum -51
            _DrvrInstall
            lea     PTekDriver,A1
            movea.l UTableBase,A0
            movea.l ($C8,A0),A0
            movea.l (A0),A0
            move.l  A1,(A0)+                        ; dCtlDriver = PTekDriver (a pointer, not a handle)
            move.w  (A1),(A0)+                      ; dCtlFlags = drvrFlags
            suba.w  #$32,SP
            movea.l SP,A0
            clr.b   ($1B,A0)
            lea     PTekDriver.Name,A1
            move.l  A1,($12,A0)
            clr.l   ($C,A0)
            _Open
            adda.w  #$32,SP
            movem.l (SP)+,D0-D7/A0-A6
            rts
; PTekOpen
; Open: PTekDoOpen(pb, dce), result in ioResult
PTekOpen:
            movem.l D1-D7/A0-A6,-(SP)
            move.l  A0,-(SP)
            move.l  A1,-(SP)
            move.l  A0,-(SP)
            jsr     PTekDoOpen
            addq.l  #8,SP
            movea.l (SP)+,A0
            move.w  D0,($10,A0)
            movem.l (SP)+,D1-D7/A0-A6
            rts
; PTekClose
; Close: nothing to do
PTekClose:
            clr.w   ($10,A0)
            clr.w   D0
            rts
; PTekPrime
; Prime: PTekDoPrime(pb, dce)
PTekPrime:
            movem.l D2-D7/A0-A6,-(SP)
            move.l  A1,-(SP)
            move.l  A0,-(SP)
            jsr     PTekDoPrime
.Finish:
            addq.l  #8,SP
            movem.l (SP)+,D2-D7/A0-A6
            move.w  D0,($10,A0)
            move.w  (6,A0),D0
            btst    #9,D0
            bne.b   .Return
            move.l  JIODone,-(SP)                   ; Not immediate: finish through IODone
.Return:
            move.w  ($10,A0),D0
            rts
; PTekCtl
; Control: PTekDoControl(pb, dce)
PTekCtl:
            movem.l D2-D7/A0-A6,-(SP)
            move.l  A1,-(SP)
            move.l  A0,-(SP)
            jsr     PTekDoControl
            bra.b   PTekPrime.Finish
; PTekStatus
; Status: PTekDoStatus(pb, dce)
PTekStatus:
            movem.l D2-D7/A0-A6,-(SP)
            move.l  A1,-(SP)
            move.l  A0,-(SP)
            jsr     PTekDoStatus
            bra.b   PTekPrime.Finish
PTekDriver:
            dc.w    $4F00                       ; Driver '.PTek' - drvrFlags
            dc.w    0                           ; drvrDelay
            dc.w    $0000                       ; drvrEMask
            dc.w    0                           ; drvrMenu
            dc.w    PTekOpen-PTekDriver         ; drvrOpen
            dc.w    PTekPrime-PTekDriver        ; drvrPrime
            dc.w    PTekCtl-PTekDriver          ; drvrCtl
            dc.w    PTekStatus-PTekDriver       ; drvrStatus
            dc.w    PTekClose-PTekDriver        ; drvrClose
.Name:
            dc.b    5,'.PTek'
; PTekMediaIcon
; Media icon and mask (Control 22)
PTekMediaIcon:
            dc.l    %10010010010010010010010010010010
            dc.l    %00000000000000000000000000000000
            dc.l    %00100100100100100100100100100100
            dc.l    %00000000000000000000000000000000
            dc.l    %10010010010010010010010010010010
            dc.l    %00000000000000000000000000000000
            dc.l    %01001001001001001001000000000001
            dc.l    %00000000000000000000001111111000
            dc.l    %10010010010010010001110101010100
            dc.l    %00000000000000000010101010101011
            dc.l    %00100100100100100101010101010101
            dc.l    %00000000000000001010101010101010
            dc.l    %10010010010010010101010101010101
            dc.l    %00000000000000011010101010101010
            dc.l    %01001001001001010101010101010101
            dc.l    %00000000000000101010101010101010
            dc.l    %10010010010010110101010101010101
            dc.l    %00000000000000101010101010101010
            dc.l    %00100100100100110101010101010101
            dc.l    %00000000000000011010101010101010
            dc.l    %10010010010010010101010101010101
            dc.l    %00000000000000001010101010101010
            dc.l    %01011111111111111101010101010101
            dc.l    %11110101010101010111111110101010
            dc.l    %11101110111011101110111011110101
            dc.l    %01010101010101010101010101010110
            dc.l    %10111011100000100010001010111011
            dc.l    %01010000000010001000100000010101
            dc.l    %00000010001000100010001001000010
            dc.l    %10001000100010001000100010000000
            dc.l    %00100010001000100010001000100010
            dc.l    %10001000100010001000100010001000
.Mask:
            dc.l    %11111111111111111111111111111111
            dc.l    %11111111111111111111111111111111
            dc.l    %11111111111111111111111111111111
            dc.l    %11111111111111111111111111111111
            dc.l    %11111111111111111111111111111111
            dc.l    %11111111111111111111111111111111
            dc.l    %11111111111111111111111111111111
            dc.l    %11111111111111111111111111111111
            dc.l    %11111111111111111111111111111111
            dc.l    %11111111111111111111111111111111
            dc.l    %11111111111111111111111111111111
            dc.l    %11111111111111111111111111111111
            dc.l    %11111111111111111111111111111111
            dc.l    %11111111111111111111111111111111
            dc.l    %11111111111111111111111111111111
            dc.l    %11111111111111111111111111111111
            dc.l    %11111111111111111111111111111111
            dc.l    %11111111111111111111111111111111
            dc.l    %11111111111111111111111111111111
            dc.l    %11111111111111111111111111111111
            dc.l    %11111111111111111111111111111111
            dc.l    %11111111111111111111111111111111
            dc.l    %11111111111111111111111111111111
            dc.l    %11111111111111111111111111111111
            dc.l    %11111111111111111111111111111111
            dc.l    %11111111111111111111111111111111
            dc.l    %11111111111111111111111111111111
            dc.l    %11111111111111111111111111111111
            dc.l    %11111111111111111111111111111111
            dc.l    %11111111111111111111111111111111
            dc.l    %11111111111111111111111111111111
            dc.l    %11111111111111111111111111111111
; PTekDriveIcon
; Drive icon and mask, then the name Get Info shows (Control 21)
PTekDriveIcon:
            dc.l    %00000000000000000000000000000000
            dc.l    %00000000000000000000000000000000
            dc.l    %00000000000000000000000000000000
            dc.l    %00000000000000000000000000000000
            dc.l    %01111111111111111111111110000000
            dc.l    %10000000000000000000000001000000
            dc.l    %10111111111111111111111101000000
            dc.l    %10100000000000000000000101000100
            dc.l    %10101010101010000000000101001100
            dc.l    %10100000000000000000000101011111
            dc.l    %10101010100000000000000101001101
            dc.l    %10100000000000000000000101000101
            dc.l    %10101010000000000000000101000001
            dc.l    %10100000000000000000000101000001
            dc.l    %10101010000000000000000101000001
            dc.l    %10100000000000000000000101000000
            dc.l    %10101000000000000000000101000000
            dc.l    %10100000000000000000000101000000
            dc.l    %10100000000000000000000101000000
            dc.l    %10111111111111111111111101000000
            dc.l    %10000000000000000000000001000000
            dc.l    %01111111111111111111111110000000
            dc.l    %10000000000000000000010000000000
            dc.l    %10001100000000000000010000000000
            dc.l    %10000000000000000000010000000000
            dc.l    %10000000000000000000010000000000
            dc.l    %11111111111111111111100000000000
            dc.l    %00000000000000000000000000000000
            dc.l    %00000000000000000000000000000000
            dc.l    %00000000000000000000000000000000
            dc.l    %00000000000000000000000000000000
            dc.l    %00000000000000000000000000000000
.Mask:
            dc.l    %00000000000000000000000000000000
            dc.l    %00000000000000000000000000000000
            dc.l    %00000000000000000000000000000000
            dc.l    %00000000000000000000000000000000
            dc.l    %01111111111111111111111110000000
            dc.l    %11111111111111111111111111000000
            dc.l    %11111111111111111111111111000000
            dc.l    %11111111111111111111111111000100
            dc.l    %11111111111111111111111111001100
            dc.l    %11111111111111111111111111011111
            dc.l    %11111111111111111111111111001101
            dc.l    %11111111111111111111111111000101
            dc.l    %11111111111111111111111111000001
            dc.l    %11111111111111111111111111000001
            dc.l    %11111111111111111111111111000001
            dc.l    %11111111111111111111111111000000
            dc.l    %11111111111111111111111111000000
            dc.l    %11111111111111111111111111000000
            dc.l    %11111111111111111111111111000000
            dc.l    %11111111111111111111111111000000
            dc.l    %11111111111111111111111111000000
            dc.l    %01111111111111111111111110000000
            dc.l    %11111111111111111111110000000000
            dc.l    %11111111111111111111110000000000
            dc.l    %11111111111111111111110000000000
            dc.l    %11111111111111111111110000000000
            dc.l    %11111111111111111111100000000000
            dc.l    %00000000000000000000000000000000
            dc.l    %00000000000000000000000000000000
            dc.l    %00000000000000000000000000000000
            dc.l    %00000000000000000000000000000000
            dc.l    %00000000000000000000000000000000
.Name:
            dc.b    18,'Outbound Hard Disk'
            dc.b    $00,$00,$00
; ATAWaitReady
; Wait for not BSY; D0 = 0, or the status if ERR is set
ATAWaitReady:
            move.b  (ATAStatus).l,D0
            bmi.b   ATAWaitReady
            btst    #0,D0
            bne.b   .Return
            clr.w   D0
.Return:
            rts
; ATAWaitDRQ
; Wait for not BSY, then DRQ (D0 = 0) or ERR (D0 = status, D1 = error)
ATAWaitDRQ:
            lea     (ATAStatus).l,A0
.WaitBusy:
            move.b  (A0),D0
            bmi.b   .WaitBusy
.WaitDRQ:
            or.b    (A0),D0
            btst    #0,D0
            beq.b   .NoError
            move.b  (ATAError).l,D1                 ; Error register
            bra.b   .Return
.NoError:
            btst    #3,D0
            beq.b   .WaitDRQ
            clr.w   D0
.Return:
            rts
; ATAReadSectors
; ATAReadSectors(geom, block, count, buf): READ SECTORS, up to 256 at a time
ATAReadSectors:
            link.w  A6,#0
            movem.l D2-D4/A2-A3,-(SP)
            movea.l ($14,A6),A3
            move.w  ($12,A6),D4
            move.l  ($C,A6),D3
.Command:
            move.l  (8,A6),-(SP)
            move.l  D3,-(SP)
            jsr     ATASetCHS
            addq.l  #8,SP
            tst.w   D0
            bmi.w   .Done
            move.w  D4,D0
            move.b  D0,(ATASecCnt).l                ; Sector count (0 = 256)
            move.b  #$20,(ATAStatus).l              ; READ SECTORS
            clr.w   D2
            move.b  D0,D2
            subq.b  #1,D2
            move.l  A3,D0
            andi.w  #1,D0
            bne.b   .OddSector                             ; Odd buffer: a byte at a time
.Sector:
            jsr     ATAWaitDRQ
            tst.w   D0
            bmi.b   .Done                             ; ERR status is positive: never taken
            move.w  #$1F,D1
            lea     (ATAData).l,A0                  ; Data register
.Words:
            move.w  (A0),(A3)+                      ; 256 words, 8 at a time
            move.w  (A0),(A3)+
            move.w  (A0),(A3)+
            move.w  (A0),(A3)+
            move.w  (A0),(A3)+
            move.w  (A0),(A3)+
            move.w  (A0),(A3)+
            move.w  (A0),(A3)+
            dbra    D1,.Words
            subq.w  #1,D4
            addq.l  #1,D3
            dbra    D2,.Sector
            tst.w   D4
            bne.b   .Command
            moveq   #0,D0
            bra.b   .Done
.OddSector:
            jsr     ATAWaitDRQ
            tst.w   D0
            bmi.b   .Done
            move.w  #$FF,D1
.OddWords:
            move.w  (ATAData).l,D0
            move.w  D0,-(SP)
            move.b  (SP)+,(A3)+
            move.b  D0,(A3)+
            dbra    D1,.OddWords
            subq.w  #1,D4
            addq.l  #1,D3
            dbra    D2,.OddSector
            tst.w   D4
            bne.w   .Command
            moveq   #0,D0
.Done:
            movem.l (SP)+,D2-D4/A2-A3
            unlk    A6
            rts
; ATAWriteSectors
; ATAWriteSectors(geom, block, count, buf): WRITE SECTORS, up to 256 at a time
ATAWriteSectors:
            link.w  A6,#0
            movem.l D2-D4/A2-A3,-(SP)
            movea.l ($14,A6),A3
            move.w  ($12,A6),D4
            move.l  ($C,A6),D3
.Command:
            move.l  (8,A6),-(SP)
            move.l  D3,-(SP)
            jsr     ATASetCHS
            addq.l  #8,SP
            tst.w   D0
            bmi.w   .Done
            move.w  D4,D0
            move.b  D0,(ATASecCnt).l                ; Sector count (0 = 256)
            clr.w   D2
            move.b  D0,D2
            subq.b  #1,D2
            move.b  #$30,(ATAStatus).l              ; WRITE SECTORS
            move.l  A3,D0
            andi.w  #1,D0
            bne.b   .OddSector                             ; Odd buffer: a byte at a time
.Sector:
            jsr     ATAWaitDRQ
            tst.w   D0
            bmi.b   .Done                             ; ERR status is positive: never taken
            move.w  #$1F,D1
            lea     (ATAData).l,A0
.Words:
            move.w  (A3)+,(A0)                      ; 256 words, 8 at a time
            move.w  (A3)+,(A0)
            move.w  (A3)+,(A0)
            move.w  (A3)+,(A0)
            move.w  (A3)+,(A0)
            move.w  (A3)+,(A0)
            move.w  (A3)+,(A0)
            move.w  (A3)+,(A0)
            dbra    D1,.Words
            subq.w  #1,D4
            addq.l  #1,D3
            dbra    D2,.Sector
            tst.w   D4
            bne.b   .Command
            moveq   #0,D0
            bra.b   .Done
.OddSector:
            jsr     ATAWaitDRQ
            tst.w   D0
            bmi.b   .Done
            move.w  #$FF,D1
.OddWords:
            move.b  (A3)+,-(SP)
            move.w  (SP)+,D0
            move.b  (A3)+,D0
            move.w  D0,(ATAData).l
            dbra    D1,.OddWords
            subq.w  #1,D4
            addq.l  #1,D3
            dbra    D2,.OddSector
            tst.w   D4
            bne.w   .Command
            moveq   #0,D0
.Done:
            movem.l (SP)+,D2-D4/A2-A3
            unlk    A6
            rts
