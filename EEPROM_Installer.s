            INCLUDE 'ROMTools/Include.s'
            INCLUDE 'ROMTools/TrapMacros.s'
            INCLUDE 'ROMTools/Globals.s'
            INCLUDE 'ROMTools/CommonConst.s'
            INCLUDE 'ROMTools/Hardware/Outbound125.s'

ROMData     EQU     -12
EEPROMWrCnt EQU     -16
            
EEPROM_Installer:
            link.w  A6,#-$10
            movem.l A4-A3/D7-D4,-(SP)               ; Save registers
            jsr     onWallaby                       ; Test if we're on compatible hardware
            tst.l   D0                              ; Check the result
            bne.b   .L1                             ; If everything matches continue
            move.b  #1,(28,A6)
            bra.w   .Exit                           ; Wrong hardware, exit
.L1:
            jsr     hasHD                           ; Check to see if a hard drive is installed
            tst.l   D0
            beq.b   .NoHD
            subq.l  #4,SP
            move.l  #'EROM',-(SP)                   ; Set resource type
            moveq   #HardDiskEEPROM,D0              ; Load the hard drive image ID
            move.w  D0,-(SP)                        ; Set resource ID
            _GetResource
            move.l  (SP)+,(ROMData,A6)
            bra.b   .ProgressUI
.NoHD:
            subq.l  #4,SP
            move.l  #'EROM',-(SP)                   ; Set resource type
            moveq   #FloppyEEPROM,D0                ; Load the floppy image ID
            move.w  D0,-(SP)                        ; Set resource ID
            _GetResource
            move.l  (SP)+,(ROMData,A6)
; Draw the progress window
.ProgressUI:
            pea     (-8,SP)
            moveq   #$14,D0
            move.w  D0,-(SP)
            move.l  #$16E009C,-(SP)
            move.w  #$9D,-(SP)
            _SetRect
            pea     (-8,SP)
            _EraseRect
            pea     (-8,SP)
            moveq   #$13,D0
            move.l  #$1130096,-(SP)
            move.w  #$A4,-(SP)
            _SetRect
            pea     (-8,SP)
            _FrameRect
            move.b  #1,EEPROMReg1                   ; Enable writing to EEPROM
            move.b  #1,EEPROMReg2                   ; Enable writing to EEPROM
            movea.l (ROMData,A6),A0                 ; Load the handle to the ROM image resource
            movea.l (A0),A3                         ; A3 = ROM image pointer
            move.l  #EEPROMWrite,(EEPROMWrCnt,A6)   ; Set EEPROM write location
            movea.l #PtchROMBase,A4                 ; A4 = EEPROM pointer
            subq.l  #4,SP
            move.l  (ROMData,A6),-(SP)
            _SizeRsrc                               ; Size the ROM image
            move.l  (SP)+,D7                        ; Retrieve the size of the ROM image
            add.l   A3,D7                           ; D7 = end of ROM image (ROM image start + ROM image size)
            subq.l  #4,SP
            move.l  (ROMData,A6),-(SP)
            _SizeRsrc                               ; Size the ROM image again
            move.l  (SP)+,D0
            asr.l   #8,D0
            moveq   #-2,D4
            and.l   D0,D4
            move.l  A3,D5
            add.l   D4,D5
            pea     (-8,A6)
            moveq   #$13,D0
            move.w  D0,-(SP)
            move.w  #$96,-(SP)
            move.w  D0,-(SP)
            move.w  #$A4,-(SP)
            _SetRect
            bra.b   .CopyEndCheck
.CopyLoop:
            move.w  (A3),D0                         ; Read data from ROM image
            cmp.w   (A4),D0                         ; Compare to EEPROM contents
            beq.b   .DrawProgress                   ; If they match already, skip writing
            movea.l (EEPROMWrCnt,A6),A0             ; Load location to write to
            move.w  (A3),(A0)                       ; Write to EEPROM
            move.l  #10000,D6                       ; Set max retry value
            bra.b   .VerifyWrite                    ; Verify what was written
.VerifyRetry:
            move.l  D6,D0
            subq.l  #1,D6                           ; Decrement retry count
            tst.l   D0                              ; Have we exceeded max retries?
            bne.b   .VerifyWrite                    ; No, read again
            movea.l D7,A3                           ; Write failed, set pointer to end of image
            bra.b   .DrawProgress
.VerifyWrite:
            move.w  (A3),D0                         ; Read data from ROM image
            cmp.w   (A4),D0                         ; See if it matches written EPROM contents
            bne.b   .VerifyRetry                    ; No, try reading again
.DrawProgress:
            cmp.l   A3,D5
            bne.b   .IncrementCount
            cmpi.w  #$113,(-2,A6)
            bgt.b   .IncrementCount
            pea     (-8,A6)
            _PaintRect
            addq.w  #1,(-2,A6)
            add.l   D4,D5
.IncrementCount:
            adda.w  #2,A3                           ; Increment ROM image location
            adda.w  #2,A4                           ; Increment EEPROM read location
            addq.l  #2,(EEPROMWrCnt,A6)             ; Increment EEPROM write location
.CopyEndCheck:
            cmp.l   A3,D7                           ; Are we at the end of the image?
            bhi.b   .CopyLoop                       ; No, continue from start
            clr.b   EEPROMReg1                      ; Done writing to EEPROM
            clr.b   EEPROMReg2                      ; Done writing to EEPROM
            move.l  (ROMData,A6),-(SP)
            _ReleaseResource
            move.b  #1,(28,A6)
.Exit:
            movem.l (-$28,A6),D4-D7/A3-A4           ; Restore registers
            unlk    A6
            movea.l (SP)+,A0
            adda.w  #$14,SP
            jmp     (A0)                            ; Return to caller
            INCLUDE 'onWallaby.s'
; hasHD
; Read Outbound config register to see if a hard drive is present
hasHD:
            link.w  A6,#0
            moveq   #0,D0
            moveq   #1<<HDPresent,D1
            and.b   OutboundCfg2,D1
            sne     D0
            neg.b   D0
            unlk    A6
            rts
            dc.b    $85
            dc.b    'hasHD'
            dc.b    $0,$0