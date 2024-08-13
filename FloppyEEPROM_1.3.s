            INCLUDE 'ROMTools/Hardware/Outbound125.s'
            INCLUDE 'ROMTools/Globals.s'
            INCLUDE 'ROMTools/CommonConst.s'
            INCLUDE 'ROMTools/TrapMacros.s'

            org     $F80000
            dc.l    TROMCode
