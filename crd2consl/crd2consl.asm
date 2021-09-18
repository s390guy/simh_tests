* Copyright 2021 Harold Grovesteen
*
* MIT License:
*
* Permission is hereby granted, free of charge, to any person obtaining a copy
* of this software and associated documentation files (the "Software"), to deal
* in the Software without restriction, including without limitation the rights
* to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
* copies of the Software, and to permit persons to whom the Software is
* furnished to do so, subject to the following conditions:
*
* The above copyright notice and this permission notice shall be included in
* all copies or substantial portions of the Software.
*
* THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
* IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
* FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
* AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
* LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
* OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
* THE SOFTWARE.

         TITLE 'CRD2CONSL - SEND CARD CONTENTS TO CONSOLE'
* Program Description:
*
* CRD2CONSL is a bare-metal program.  It requires input/output commands to
* the IPL card stream to read a card's contents and then send the card's
* contents to the consolde device.
*
* The program is executed by means of an IPL from a card deck containing as
* the last card the one that is sent to the console.  The card contains
* EBCDIC data and is part of the IPL deck.
*
* Target Architecture: S/360
*
* Devices Used:
*   10C - IPL card reader
*   01F - Console device
*
* Program Register Usage:
*
*   R0   Base register for access to the ASA.  Required by DSECT usage
*   R1   Device Channel and Unit Address for I/O instructions
*   R11  Contains zero for STATUS clearing (zero from CPU reset).
*   R12  The program base register
*   R15  Subroutine return register
*
* Disabled Wait State PSW's address field values used by the program:
*    X'000000' - Successful execution of the program
*    X'000008' - Unexpected Restart interruption occurred. Old Restart PSW at
*                address X'8'
*    X'000018' - Unexpected External interruption occurred.  Old External PSW at
*                address X'18'
*    X'000020' - Unexpected Supervisor interruption occurred.  Old Supervisor
*                PSW at address X'20'
*    X'000028' - Unexpected Program interruption occurred. Old Program PSW at
*                address X'28'
*    X'000030' - Unexpected Machine Check interruption occurred.  Old Machine
*                Check PSW at address X'30'
*    X'000038' - Unexpected Input/Output interruption occurred.  Old Input/Output
*                PSW at address X'38'
*    X'010004' - Console Device X'01F' or channel not operational
*    X'010008' - Console Device X'01F' or channel busy
*    X'01000C' - Console Device X'01F' or channel had a problem. See CSW.
*    X'010010' - Unexpected interruption from some other device. See ASA X'BA'
*    X'010014' - Console channel error occurred
*    X'010018' - Console device did not complete the I/O without a problem
*    X'020004' - Reader Device X'00C' or channel not operational
*    X'020008' - Reader Device X'00C' or channel busy
*    X'02000C' - Reader Device X'00C' or channel had a problem. See CSW.
*    X'020010' - Not used
*    X'020014' - Reader channel error occurred
*    X'020018' - Reader device did not complete the I/O without a problem
         EJECT
* See all object data and macro generated model statements in the listing
         PRINT DATA,GEN
         SPACE 1
* Inform the SATK macros of the architecture being targeted.  Inferred from
* the ASMA -t command-line argument.
         ARCHLVL
* Ensure interrupt traps are loaded by iplasma.py before program execution
* begins.  This macro will create the memory region that will also contain
* the IPL PSW.  The region name defaults to ASAREGN.  iplasma.py knows how
* to deal with this situation.
ASASECT  ASALOAD
         ASAIPL IA=PGMSTART    Define the bare-metal program's IPL PSW
         SPACE 2
*
* The Bare-Metal Hello World Program
*
         SPACE 1
PGMSECT  START X'2000',CRD2CSL Start a second region for the program itself
* This results in CRD2CSL.bin being created in the list directed IPL directory
         USING ASA,0           Give me instruction access to the ASA CSECT
PGMSTART BALR  12,0            Establish my base register
         USING *,12            Tell the assembler
         SPACE 1
         LH    1,2         Get the card reader device address (stored by IPL)
* Do this before bytes 2 and 3 are overlayed by the restart trap PSW.
         SPACE 1
* Ensure program is not re-entered by a Hercules console initiated restart.
* Address 0 changed from its absolute storage role (IPL PSW) to its real
* storage role (Restart New PSW) after the IPL.
* Change from the IPL PSW at address 0 to Restart New PSW trap
         MVC   RSTNPSW,PGMRS
         SPACE 3
* Read a card from the IPL device
* No need to validate that the IPL device is present.  The fact that this
* program got loaded and is executing proves the reader device is present and
* working.
         MVC   CAW(4),RCCWADDR   Identify the IPL device CCW to be executed
         SIO   0(1)        Request the reader channel program to start, did it?
         BC    B'0001',RNOAVL  ..No, CC=3 don't know why, but tell someone.
         BC    B'0010',RBUSY   ..No, CC=2 console device or channel is busy
         BC    B'0100',RCSW    ..No, CC=1 CSW stored in ASA at X'40'
* Reader device is now sending the card's contents (CC=0)
* Wait for an I/O interruption
RDRWAIT  BAL   15,DOWAIT       WAIT FOR I/O interrupt
         SPACE 1
* I/O results can now be checked.
*   Yes, check the CSW conditions to determine if the console I/O worked
         OC    STATUS,CSW+4        Accummulate Device and Channel status
         CLI   STATUS+1,X'00'      Did the channel have, a problem?
         BNE   RCHLERR             ..Yes, end with a reader channel error
         TM    STATUS,X'F3'        Did the unit encounter a problem?
         BNZ   RUNTERR             ..No, end with a unit error
         TM    STATUS,X'0C'        Did both channel and unit end?
         BNO   RDRWAIT             Wait again for both to be done
* CARD HAS BEEN SUCCESSFULLY READ!
         SPACE 3
* Determine if the console device, subchannel and channel are ready for use.
         LH    1,CONDEV    Set up I/O device address in I/O instruction register
         TIO   0(1)        Determine if the console is there
         BC    B'0001',DEVNOAVL  ..No, CC=3 might have a different config address
         BC    B'0010',DEVBUSY   ..No, CC=2 console device or channel is busy
         BC    B'0100',DEVCSW    ..No, CC=1 CSW stored in ASA at X'40'
* Console device is available (CC=0)!
         SPACE 1
* Prepare for I/O to console
         STH   11,STATUS         Clear status for console I/O operation
         MVC   CAW(4),CCWADDR    Identify in ASA where first CCW resides
         SPACE 1
* Send the Hello World message to the console
         SIO   0(1)        Request console channel program to start, did it?
         BC    B'0001',DEVNOAVL  ..No, CC=3 don't know why, but tell someone.
         BC    B'0010',DEVBUSY   ..No, CC=2 console device or channel is busy
         BC    B'0100',DEVCSW    ..No, CC=1 CSW stored in ASA at X'40'
* Console device is now receiving the card contents (CC=0)
         SPACE 1
* Wait for an I/O interruption
CONWAIT  BAL   15,DOWAIT
         SPACE 1
* I/O results can now be checked.
*   Yes, check the CSW conditions to determine if the console I/O worked
         OC    STATUS,CSW+4        Accummulate Device and Channel status
         CLI   STATUS+1,X'00'      Did the channel have, a problem?
         BNE   CHNLERR             ..Yes, end with a channel error
         TM    STATUS,X'F3'        Did the unit encounter a problem?
         BNZ   UNITERR             ..No, end with a unit error
         TM    STATUS,X'0C'        Did both channel and unit end?
         BNO   CONWAIT              Wait again for both to be done
* Both channel and unit have ended
         SPACE 1
* HURRAY!  CARD CONTENTS HAVE BEEN SENT TO THE CONSOLE!
         LPSW  DONE      Normal program termination
         SPACE 3
*
* I/O WAIT SUBROUTINE
*
DOWAIT   MVC   IONPSW(8),CONT  Set up continuation PSW for after I/O interrupt
         LPSW  WAIT       Wait for I/O interruption and CSW from channel
IODONE   EQU   *          The bare-metal program continues here after I/O
         MVC   IONPSW(8),IOTRAP     Restore I/O trap PSW
*   Did the interruption come from the expected device?
         CH    1,IOOPSW+2          Is the interrupt from the expected device?
         BER   15                  ..Yes, return to caller
         B     DEVUNKN             ..No, end program with an error
         SPACE 3
* End the bare-metal program with an error indicated in PSW
DEVNOAVL LPSW  NODEV     Code 004 End console device is not available
DEVBUSY  LPSW  BUSYDEV   Code 008 End because device is busy (no wait)
DEVCSW   LPSW  CSWSTR    Code 00C End because CSW stored in ASA
DEVUNKN  LPSW  NOTCON    Code 010 End unexpected device caused I/O interruption
CHNLERR  LPSW  CHERROR   Code 014 End because console channel error occurred
UNITERR  LPSW  DVERROR   Code 018 End because console device error occurred
RNOAVL   LPSW  RNODEV    Code 004 End reader device is not available
RBUSY    LPSW  RBUSYDEV  Code 008 End because reader device is busy (no wait)
RCSW     LPSW  RCSWSTR   Code 00C End because CSW stored in ASA for reader
*RUNKN    LPSW  RNOTCON   Code 010 End unexpected device caused I/O interruption
RCHLERR  LPSW  RCHERROR  Code 014 End because reader channel error occurred
RUNTERR  LPSW  RDVERROR  Code 018 End because reader device error occurred
         SPACE 1
* I/O related information
CCWADDR  DC    A(CONCCW) Address of first CCW to be executed by console device.
RCCWADDR DC    A(RDRCCW) Address of first CCW to be executed by reader device.
CONDEV   DC    XL2'001F'   Console device address
STATUS   DC    XL2'0000'   Used to accumulate unit and channel status
         SPACE 1
* CCW used by the program to write the card contents to the console
CONCCW   CCW0  X'09',RIOAREA,0,L'RIOAREA     Write card to console with CR
*         CCW0  X'03',0,0,1                   ..then a NOP.
* If the preceding NOP CCW command is enabled, then the CONCCW must set
* command chaining in the flag byte, setting the third operand to X'40'
         SPACE 1
* CCW used to read the card from the IPL device stream on X'00C'
RDRCCW   CCW   X'02',RIOAREA,0,L'RIOAREA    Read the card into memory
*         CCW0  X'03',0,0,1                   ..then a NOP.
* If the preceding NOP CCW command is enabled, then the RDRCW must set
* command chaining in the flag byte, setting the third operand to X'40'
         SPACE 1
* PSW's used by the bare-metal program
PGMRS    DWAIT CODE=008     Restart New PSW trap.  Points to Restart Old PSW
WAIT     PSW360 X'F8',0,2,0,0    Causes CPU to wait for I/O interruption
CONT     PSW360 0,0,0,0,IODONE   Causes the CPU to continue after waiting
IOTRAP   PSW360 0,0,2,0,X'38'    I/O trap New PSW (restored after I/O)
         SPACE 1
* PSW's terminating program execution
DONE     DWAITEND              Successful execution of the program
NODEV    DWAIT PGM=01,CMP=0,CODE=004  Console device not available
BUSYDEV  DWAIT PGM=01,CMP=0,CODE=008  Console device busy
CSWSTR   DWAIT PGM=01,CMP=0,CODE=00C  CSW stored in ASA
NOTCON   DWAIT PGM=01,CMP=0,CODE=010  Unexpected interruption from other device
CHERROR  DWAIT PGM=01,CMP=0,CODE=014  Console channel error occurred
DVERROR  DWAIT PGM=01,CMP=0,CODE=018  Console device error occurred
RNODEV   DWAIT PGM=02,CMP=0,CODE=004  Reader device not available
RBUSYDEV DWAIT PGM=02,CMP=0,CODE=008  Reader device busy
RCSWSTR  DWAIT PGM=02,CMP=0,CODE=00C  CSW stored in ASA
*RNOTCON DWAIT PGM=02,CMP=0,CODE=010  Unexpected interruption from other device
RCHERROR DWAIT PGM=02,CMP=0,CODE=014  Reader channel error occurred
RDVERROR DWAIT PGM=02,CMP=0,CODE=018  Reader device error occurred
         SPACE 3
* No constants should be placed below this area.  Base register not needed
* because this area is only referenced by CCW's
RIOAREA  DS    0CL80
* Note: the 0 ensures no space is reserved in IPL deck for this area.
         SPACE 3
*
* Hardware Assigned Storage Locations
*
         SPACE 1
* This DSECT allows symbolic access to these locations.  The DSECT created is
* named ASA.
ASA      ASAREA DSECT=YES
         END
