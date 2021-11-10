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

         TITLE 'ECHO - CONSOLE ECHO TEST'
* Program Description:
*
* ECHO is a bare-metal program.  It requires input/output commands to
* the system's console device.  It's purpose is to exercise the console
* device.  
*
* The program is executed by means of an IPL from a card deck. Initially
* a line is diplayed explaining the use of the program.  Following this
* a prompt is displayed with the keyboard unlocked for user input.
* Whatever is typed is then printed on the next line.  This is followed by the
* prompt with user input expected until the user enters 'quit' in lower case.
* without quotes.  quit terminates the program normally.
*
* The system interrupt key or console 'cancel' key will interrupt the
* executing program.  Display a message.  And then return to the normal
* echo functions described above.
*
* Target Platform: SimH
* Target Architecture: S/360
*
* Devices Used:
*   01F - Console device
*
* Program Register Usage:
         SPACE 1
R0       EQU   0   Base register for access to the ASA. Required by DSECT 
*                  usage, but available for program usage
R1       EQU   1   Device Channel and Unit Address for I/O instructions
R2       EQU   2   I/O Routine Channel-Address Word
R3       EQU   3   Length of data received from the operator
R4       EQU   4   available
R5       EQU   5   available
R6       EQU   6   available
R7       EQU   7   available
R8       EQU   8   available
R9       EQU   9   available
R10      EQU   10  available
R11      EQU   11  Contains zero for STATUS clearing (zero'd from CPU reset).
R12      EQU   12  The global program base register
R13      EQU   13  External Interruption R15 save register
R14      EQU   14  I/O Routine return register.  Program is the caller
R15      EQU   15  Subroutine return register.  I/O routine is the caller
         SPACE 1
* Disabled Wait State PSW's address field values used by the program:
*    X'000000' - Successful execution of the program
* Note: Restart interruptions are not available on S/360 systems.
*    X'000018' - Unexpected External interruption occurred.
*                Old External PSW at address X'18'
*    X'000020' - Unexpected Supervisor interruption occurred.
*                Old Supervisor PSW at address X'20'
*    X'000028' - Unexpected Program interruption occurred.
*                Old Program PSW address X'28'
*    X'000030' - Unexpected Machine Check interruption occurred.
*                Old Machine Check PSW at address X'30'
*    X'000038' - Unexpected Input/Output interruption occurred.
*                Old Input/Output PSW at address X'38'
*    X'1xccuu' - Device or channel not operational. ccuu=Device Address
*    X'2xccuu' - Device or channel busy.            ccuu=Device Address
*    X'3xccuu' - Device storing of CSW missed       ccuu=Device Address
*    X'4xccuu' - Unexpected device interruption.    ccuu=Device Address
*    X'5xddcc' - Console Status problem.  dd=device status, cc=channel status
*    X'6x00ss' - Console Device sense data.  ss=general sense byte
*                Sense data reporting is not yet enabled.
* Note: The 'x' in the above wait state codes indicates the program position
* in which the error was detected.
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
         TITLE 'ECHO - POSITION 00 - PROGRAM INITIALIZATION'
*
* The Bare-Metal Echo Program
*
         SPACE 1
PGMSECT  START X'2000',ECHO  Start a second region for the program itself
* This results in ECHO.bin being created in the list directed IPL directory
         USING ASA,0           Give me instruction access to the ASA CSECT
PGMSTART BALR  R12,0           Establish my base register
         USING *,R12           Tell the assembler
         SPACE 3
* Determine if the console device, subchannel and channel are ready for use.
         LH    R1,CONDEV   Console device address in I/O inst. register
         TIO   0(R1)       Determine if the console is there
         BC    B'0001',DEVNOAVL  ..No, CC=3 might have a different config address
         BC    B'0010',DEVBUSY   ..No, CC=2 console device or channel is busy
         BC    B'0100',CSWSTRD   ..No, CC=1 CSW stored in ASA at X'40'
* Console device is available (CC=0)!
         TITLE 'ECHO - POSITION 01 - GET CONSOLE INPUT'     
* Send operator prompt and accept the operator's input
ECHOMAIN DS    0H    Query operator and echo data
         MVI   PGMRTN,ECHOGET    Displaying the query...
         CLI   EISTATUS,EIENABLE Are the external interrupts enabled?
         BE    INITECHO          ..Yes, do not need to do anything.
         BAL   R15,EXTENA        Enable external interruptions
INITECHO DS    0H   Bypass external interruptions when already enabled
         MVI   CANATTN,X'00'     Clear cancel/ATTN state
         MVI   DATA,X'00'        Clear the input...
         MVC   DATA+1(L'DATA-1),DATA     ...I/O area.
         LA    R2,GETDATA        Locate the initial CCW
         BAL   R15,DOIO    Request console input
         B     CNCLHND           ..Accept CANCEL and wait for ATTN
*                                ..On success, echo the operator's response
         SPACE 1
* Calculate the length of the operator's input string (may be zero).
         LH    R3,INLEN          Fetch the lengh of the input area
         SH    R3,CSW+6          Calculate actual bytes read
         BZ    ECHOCR            If no data, operator just hit ENTER
         CH    R3,QUITLEN        Was only four bytes entered?
         BNE   CONSECHO          ..No, echo the input
         SPACE 1
CKQUIT   DS    0H   Check if quit was entered (only when four bytes entered)e
         CLC   QUIT,DATA         Did operator enter quit
         BE    FINISH            ..Yes, end the program.
*                                ..No, echo the operator's input (fall through)
         TITLE 'ECHO - POSITION 02 - ECHO INPUT BACK TO THE CONSOLE'
*
* Echo operator's input data on the console
*
CONSECHO DS    0H   Echo operator's input back to the operator
         MVI   PGMRTN,ECHODATA   Displaying the query response..
         STH   R3,PUTLEN         Update the CCW with the actual output length
         LA    R2,PUTDATA        Locate the initial CCW
         BAL   R15,DOIO          Echo the operator's input
         B     ECHOMAIN          ..Ignore CANCEL from operator during echo
         B     ECHOMAIN          On success, return to the main echo loop
         SPACE 1
ECHOCR   DS    0H   Simply echo a carriage return
* Note: a different channel program is required to handle the case where the
* operator has hit only the ENTER key.  This results in a calculated length
* of zero (detected above).  Zero can not be used as the length of a device
* directed CCW.  This logic (functionaly identical to the preceding logic in
* CONSECHO)transmits one byte of data, a new line (carriage return) character
* without the CCW itself adding the carriage return.  This logic has a CCW
* lengthfield of one, which IS valid.
         MVI   PGMRTN,ECHOCRCH   Displaying the query response, just a CR
         LA    R2,PUTCR          Point to the CCW that outputs just a CR
         BAL   R15,DOIO          Use subroutine to perform the I/O
         B     ECHOMAIN          ..Ignore CANCEL from the operator
         B     ECHOMAIN          On success, return to the main echo loop
         TITLE 'ECHO - CANCEL/ATTN HANDLERS'
CNCLHND  DS    0H   Handle a CANCEL (UNIT EXCEPTION) from the console
         MVI   PGMRTN,CNCLPOS    CANCEL being handled
         OI    CANATTN,CANHIT    Set existence of the cancel state
         LA    R2,PUTCNCL        Display that a CANCEL was detected
         BAL   R15,DOIO          Perform the console display
         B     ATTNWAIT          ..Ignore CANCEL from the operator
* Wait for an I/O interruption
ATTNWAIT BAL   R15,IOWAIT        Wait for an I/O interruption
         TM    CSW+4,X'80'       Does the interrupt contain an ATTN?
         BNO   ATTNWAIT          ..No, continue waiting
* ATTENTION detected
         OI    CANATTN,ATTNHIT   ATTN hit (turning off cancel state)
         LA    R2,PUTATTN        Display that an ATTN was detected
         BAL   R15,DOIO          Use subroutine to perform the I/O
         B     ECHOMAIN          ..Ignore CANCEL from the operator
         B     ECHOMAIN          On success, return to the main echo loop
         TITLE 'ECHO - INPUT/OUTPUT ROUTINE'
*
* CONSOLE INPUT/OUTPUT ROUTINE
*
* Register Usage:
*  R1  - Device address performing the I/O in low-order 16 bits
*  R2  - Address of the first CCW of the I/O request, bits 0-7 zeros, 8-31 address
*  R11 - Zero (0), used to clear accumulated status field
*  R15 - Routine return address:
* Return Conventions:
*    R15+0   CANCEL signaled by operator
*    R15+4   Normal termination
         SPACE 1
DOIO     DS    0H
         STH   R11,STATUS      Clear status for console I/O operation
         ST    R2,CAW          Tell the I/O request its address in ASA
         SIO   0(R1)       Request console channel program to start, did it?
         BC    B'0001',DEVNOAVL  ..No, CC=3 don't know why, but tell someone.
         BC    B'0010',DEVBUSY   ..No, CC=2 console device or channel is busy
         BC    B'0100',CSWSTRD   ..No, CC=1 CSW stored in ASA at X'40'
* Transfer initiated (CC=0)...
POLL     TIO   0(R1)             Test the I/O progress.
         BC    B'0010',POLL      CC=2, data still being sent, cont. polling
         BC    B'0001',DEVNOAVL  CC=3, don't know why, but tell someone.
         BC    B'1000',NOCSW     CC=0, missed CSW, don't know why abort
* CSW stored (CC=1), analyze for result.
         OC    STATUS,CSW+4      Accummulate Device and Channel status
         CLI   STATUS+1,X'00'    Did the channel have a problem?
         BNE   CSWACCUM          ..Yes, end with a device/channel error
* Test for abnormal status for a console device
         TM    STATUS,X'C2'      Was a device error reported?
* ATTN, STATUS MODIFIER, and UNIT CHECK are treated as errors.  ATTN is only
* possible when no I/O operation (from SIO through DEVICE END) is occurring.
         BNZ   CSWACCUM          ..Yes, end with a device/channel error
* Channel end, control unit end and busy are ignored.
         TM    STATUS,X'04'      Device finally done?
* If DEVICE END not present, the program continues to test for it
         BNO   POLL              ..No, Check again...
         SPACE 1
* Check for normal conditions and return to caller
         TM    STATUS,X'01'      UNIT EXCEPTION present?
         BNO   4(,R15)           ..No, return to caller +4 (Normal end)
* UNIT EXCEPTION, is treated as normal.  UNIT EXCEPTION is
* generated by the operator hitting the CANCEL key.  Not all console
* emulations support CANCEL from the operator.
         BR    R15               ..Yes, return to caller +0 (Handle CANCEL)
         TITLE 'ECHO - INTERRUPTION HANDLERS AND WAIT ROUTINES'
*
* I/O WAIT SUBROUTINE
*
*  Register usage:
*    R1  - Device Channel/Unit address
*    R12 - Global program base address
*    R15 - Subroutine return address
*
*  Side Effects:
*    External interrupts are disabled following this routine
*
*  Abnormal Terminations:
*    Interrupt from unexpected device received.
         SPACE 1
IOWAIT   MVC   IONPSW(8),CONT  Set up continuation PSW for after I/O interrupt
         LPSW  WAIT       Wait for I/O interruption and CSW from channel
IODONE   EQU   *          The bare-metal program continues here after I/O
         MVC   IONPSW(8),IOTRAP     Restore I/O trap PSW
*   Did the interruption come from the expected device?
         CH    R1,IOOPSW+2          Is the interrupt from the expected device?
         BER   R15                  ..Yes, return to caller
         B     DEVUNKN              ..No, end program with an error
         SPACE 1
WAIT     PSW360 X'F8',0,2,0,0       Causes CPU to wait for I/O interruption
*                                   Channels 0-4 enabled for interrupts
CONT     PSW360 0,0,0,0,IODONE      Causes the CPU to continue after waiting
IOTRAP   PSW360 0,0,2,0,X'38'       I/O trap New PSW (restored after I/O)
         SPACE 3
*
* DISABLE EXTERNAL INTERRUPTS
*
*  Register usage:
*    R12 - Global program base address
*    R15 - Routine return address
*
* Side Effects:
*    Input/output interruptions disabled for all channels
         SPACE 1
EXTDIS   DS    0H
         LPSW  EXTDPSW              Disable external interruptions
* Execution continues with the following instruction
EXTDISC  MVC   EXTNPSW,EXTTRAP      Trap any unexpected external interruptions
         BR    R15                  Return to caller
         SPACE 1
EXTTRAP  PSW360 0,0,0,0,X'58'       External interruption trap PSW
* Disable external interruptions and continue with the routine
EXTDPSW  PSW360 0,0,0,0,EXTDISC
         SPACE 3
*
* ENABLE EXTERNAL INTERRUPTS
*
*  Register usage:
*    R12 - Global program base address
*    R15 - Routine return address
*
* Side Effects:
*    Input/output interruptions disabled for all channels
         SPACE 1
EXTENA   DS    0H
         MVC   EXTNPSW,EXTHPSW     Set external interrupt handler
* Actual external interruptions are not yet enabled.
* Return to caller and simulataneously set external interruptions
         ST    R15,EXTCPSW+4    Return to caller when the PSW is loaded
         MVI   EISTATUS,EIENABLE  External inteerupts are enabled by the LPSW
         LPSW  EXTCPSW      This instruction enables external interruptions
* Theoretically an external interruption may occur following this
* instruction, but control has already been returned to the caller.
         SPACE 1      
* Pass control to interrupt handler when an external interrupt occurs, but
* disable any more external interruptions while in the handler.
EXTHPSW  PSW360 X'00',0,0,0,EXTHDL
* Enables actual external interruptions while returning to the caller.
EXTCPSW  PSW360 X'01',0,0,0,0
         SPACE 3
*
* EXTERNAL INTERRUPT HANDLER
*
*  Register usage:
*    R12 - Global program base address
*
*  Two bytes of external interruption information is stored within the 
*  exernal old PSW at address X'1A'.  The old PSW format is:
*
*   18       19       1A       1B       1C       1D       1E       1F
*   +0       +8       +16      +24      +32      +40      +48      +56
*  +--------+--------+--------+--------+--------+--------+--------+--------+
*  |........|........|00000000|TKS00000|........|........|........|........|
*  +--------+--------+--------+--------+--------+--------+--------+--------+
*
*  Where:
*     T == a timer interruption (X'80') 
*     K == the interrupt key has been hit (X'40')
*     S == an external signal has occurred (X'20')
*
* This handler ignores timer and external signals.  Only the interrupt key
* is recognized.  When an external interruption is ignored, control returns
* to the point of the interruption with external interrupts enabled.
* 
* When an interrupt key is detected, any current I/O operation is halted and
* the interrupt key is treated as a cancel, namely waiting for ATTN being
* recognized.
         SPACE 1
EXTHDL   DS    0H
* The external new PSW that passes control to this point also disables
* external interruptions
         TM    EXTOPSW+3,X'40'     Is this an interrupt key interruption?
         BO    EXTKEY              ..Yes, handle the interrupt key
         LPSW  EXTOPSW             ..No, just return to interrupted logic
* External interrupts are enabled when this PSW is loaded.
         SPACE 1
EXTKEY   DS    0H   Treat the interrupt key like a cancel
         MVI   PGMRTN,EXTPOS       Handling an external interrupt
         MVI   EISTATUS,X'00'      External interrupts disabled
* HALT any I/O operation being executed
         HIO   0(R1)               Halt the I/O..
         BC    B'0001',DEVNOAVL    CC=3, Device not available, abend
*         BC    B'1000',AVAILWAT   CC=0, Interruption pending in subchannel
*         BC    B'0100',AVAILWAT   CC=1, CSW stored, wait for availability
*         BC    B'0010',AVAILWAT   CC=2, Burst ended on selector channel
         SPACE 1
* Wait for the device to become available
* AVAILWAT DS    0H   Wait for device to become available
         STH   R11,STATUS        Clear status for console availability
AVAILTST TIO   0(R1)             Test the device path
         BC    B'0010',AVAILTST  CC=2, device still busy, cont. checking
         BC    B'0100',EXTCSW    CC=1, CSW stored check it...
         BC    B'1000',EXTAVAIL  CC=0, device is available, continue
         BC    B'0001',DEVNOAVL  CC=3, don't know why, but tell someone.
         SPACE 1
EXTCSW   DS    0H  CSW stored, see if the device and channel are available
         OC    STATUS,CSW+4      Accummulate Device and Channel status
         CLI   STATUS+1,X'00'    Did the channel have a problem?
         BNE   CSWACCUM          ..Yes, end with a device/channel error
         TM    STATUS,X'0C'      Channel end and device end?
         BNO   AVAILTST          ..No, wait for them to become available
         SPACE 1
EXTAVAIL DS    0H   Console device now available
         LA    R2,PUTINKY     Point to the CCW that outputs interrupt key msg
         BAL   R15,DOIO       Use subroutine to perform the I/O
         B     ATTNWAIT       ..Ignore CANCEL from the operator
         B     ATTNWAIT       On success, return to the main echo loop
* These branches leave the interrupt handler with external interrupts disabled.
* The external interrupt key is treated as a "cancel".  The difference is the
* source: console I/O for the CANCEL key, the program itself for the external
* key interruption.
         TITLE 'ECHO - DATA AREAS'
*
* Channel Command Words
*
         SPACE 1
* Doubleword aligned data
GETDATA  CCW   X'01',ENTER,X'40',L'ENTER   Display 'ENTER: ' on console
*              Command-chain (X'40') to the next CCW
         CCW   X'0A',DATA,X'20',L'DATA     Read operator's data
*              Suppress Incorrect Length Indicator - operator's data varies
         SPACE 1
PUTATTN  CCW   X'09',ATTNSTR,0,ATTNSTRL    Display ATTN string
         SPACE 1
PUTCNCL  CCW   X'09',CNCLSTR,0,CNCLSTRL    Display the CANCEL string
         SPACE 1
PUTCR    CCW   X'01',CRDATA,X'00',L'CRDATA   Echo just a CR
         SPACE 1
PUTDATA  CCW   X'09',DATA,0,0              Echo operator's data
         ORG   PUTDATA+6
PUTLEN   DS    HL2                         Echo'd data's length
         SPACE 1
PUTINKY  CCW   X'09',INKYDAT,X'00',INKYDATL  '** INTRP KEY **' message sent
         SPACE 1
*
* I/O related information
*
* Half-word aligned data
         DS    0H          Align half words
CONDEV   DC    XL2'001F'   Console device address
STATUS   DC    XL2'0000'   Used to accumulate unit and channel status
         SPACE 1
INLEN    DC    Y(L'DATA)   Input data length (Could also use prev. CCW)
QUITLEN  DC    Y(L'QUIT)   Length of quit literal
         SPACE 3
* Unaligned data
         SPACE 1
* Program position used in building abend address
INIT     EQU   X'00'        Program initialization
ECHOGET  EQU   X'01'        Operator prompt and input retrieved
ECHODATA EQU   X'02'        Echoing data from the operator
ECHOCRCH EQU   X'03'        Echo just a new line character (carriage return)
ATTNPOS  EQU   X'04'        ATTN handler
CNCLPOS  EQU   X'05'        CANCEL handler
EXTPOS   EQU   X'06'        Interruption key being handled
PGMRTN   DC    AL1(INIT)    Initialize program position data
         SPACE 1
* CANCEL/ATTN status
CANATTN  DC    XL1'00'      
CANHIT   EQU   X'80'         A cancel key was detected (control-c)
ATTNHIT  EQU   X'40'         An ATTN key was detected (esc)
         SPACE 1
* EXTERNAL INTERRUPTION PSW STATE
EISTATUS DC    XL1'00'       External interrupts disabled     
EIENABLE EQU   X'80'         External interrupts enabled
         SPACE 1
* ECHO program data areas
ATTNSTR  DC    XL1'15',C'** ATTN **'
ATTNSTRL EQU   *-ATTNSTR
CNCLSTR  DC    XL1'15',C'** CANCEL **'
CNCLSTRL EQU   *-CNCLSTR
CRDATA   DC    XL1'15'      Just a new line (carriage return) character
ENTER    DC    C'ENTER: '   Operator prompt
INKYDAT  DC    XL1'15',C'** INTRP KEY **'
INKYDATL EQU   *-INKYDAT
QUIT     DC    C'quit'      'quit' entered by operator terminates the program
DATA     DC    XL80'00'
         TITLE 'ECHO - PROGRAM TERMINATIONS'
*
* NORMAL PROGARM TERMINATION
*
* Register usage:
*   R12 - Global program base address
* Normal Termination:
*   Termination code X'000000'
         SPACE 1
FINISH   LPSW  DONE     Normally Terminate the program
         SPACE 3
*
* REPORT DEVICE NOT OPERATIONAL - Uses Format 1 ABEND
*
* Register usage:
*   R1  - Device Channel/Unit address
*   R12 - Global program base address
* Abnormal Termination:
*    Format 1 ABEND code X'1x'
         SPACE 1
DEVNOAVL DS    0H
         STH   1,FMT1CUU         Set the failing device address
         MVI   FMT1CODE,X'10'    Set the abend code
         OC    FMT1CODE,PGMRTN   Set where the abend was detected
         LPSW  DONE              End execution abnormally
         SPACE 3
*
* REPORT DEVICE BUSY - Uses Format 1 ABEND
*
* Register usage:
*   R1  - Device Channel/Unit address
*   R12 - Global program base address
* Abnormal Termination:
*    Format 1 ABEND code X'2x
         SPACE 1
DEVBUSY  DS    0H
         STH   1,FMT1CUU         Set the failing device address
         MVI   FMT1CODE,X'20'    Set the abend code
         OC    FMT1CODE,PGMRTN   Set where the abend was detected
         LPSW  DONE              End execution abnormally
         SPACE 1
*
* REPORT STORING OF CSW MISSING - Uses Format 1 ABEND
*
* Register usage:
*   R1  - Device Channel/Unit address
*   R12 - Global program base address
* Abnormal Termination:
*    Format 1 ABEND code X'3x
         SPACE 1
NOCSW    DS    0H
         STH   1,FMT1CUU         Set the failing device address
         MVI   FMT1CODE,X'30'    Set the abend code
         OC    FMT1CODE,PGMRTN   Set where the abend was detected
         LPSW  DONE              End execution abnormally
         SPACE 3
*
* REPORT UNEXPECTED DEVICE RESPONSE - Uses Format 1 ABEND PSW
*
* Register usage:
*   R1  - Device Channel/Unit address
*   R12 - Global program base address
* Abnormal Termination:
*    Format 1 ABEND code X'4x'
         SPACE 1
DEVUNKN  DS    0H
         MVC   FMT1CUU,IOOPSW+2 Set the unexpected device address
         MVI   FMT1CODE,X'40'   Set the abend code
         OC    FMT1CODE,PGMRTN  Set where the abend was detected
         LPSW  DONE             End execution abnormally
         SPACE 3      
*
* REPORT CONSOLE DEVICE OR CHANNEL ERROR STATUS - Uses Format 2 ABEND PSW
*
* Register usage:
*   R1  - Device Channel/Unit address
*   R12 - Global program base address
* Abnormal Termination:
*    Format 2 ABEND code X'5x'
         SPACE 1
CSWACCUM DS    0H    Store the accumulated status in the abort PSW
         MVC   FMT2STAT,STATUS   Move accumulated status to abort PSW
         B     CODE50            Set up format 2 abend code
CSWSTRD  DS    0H
         MVC   FMT2STAT,CSW+4    Move stored CSW status to the abort PSW
         SPACE 1
CODE50   DS    0H
         MVI   FMT2CODE,X'50'    Set the abend code
         OC    FMT2CODE,PGMRTN   Set where the abend was detected
         LPSW  DONE              End execution abnormally
         SPACE 3
*
* REPORT CONSOLE DEVICE SENSE - Uses Format 3 ABEND PSW
*
* Register usage:
*   R1  - Device Channel/Unit address
*   R12 - Global program base address
* Abnormal Termination:
*    Format 3 ABEND code X'6x'
*
*ABENDSNS DS    0H
*         MVC   FMT3SNS,SENSDATA   Move the generic sense byte abend PSW
*         MVI   FMT3CODE,X'60'     Set the abend code
*         LPSW  DONE
          SPACE 3
*
* TERMINATION PSW Formats
*
DONE     PSW360 0,0,2,0,0
         ORG   *-3
FORMAT   DS    0AL3
* Format 1 ABEND FORMAT
FMT1CODE DS    X'00'   aa - Abend codes: 1x, 2x, 3x, 4x - x=program position
FMT1CUU  DS    H'0'    ccuu - address of device causing the termination
         ORG  FORMAT
* Format 2 ABEND FORMAT
FMT2CODE DS    X'00'   aa - Abend Code: 5x -          x=program position
FMT2STAT DS    H'00'   ddcc - dd=console device status, cc=channel status
         ORG  FORMAT
* Format 3 ABEND FORMAT
FMT3CODE DS    X'00'   aa - Abend Code: 50
         DS    X'00'   not used: X'00'
FMT3SNS  DS    X'00'   ss - console device generic sense data
         SPACE 3
*
* Hardware Assigned Storage Locations
*
         SPACE 1
* This DSECT allows symbolic access to these locations.  The DSECT created is
* named ASA.
ASA      ASAREA DSECT=YES
         END
