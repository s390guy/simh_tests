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
R3       EQU   3   available
R4       EQU   4   available
R5       EQU   5   available
R6       EQU   6   available
R7       EQU   7   available
R8       EQU   8   available
R9       EQU   9   available
R10      EQU   10
R11      EQU   11  Contains zero for STATUS clearing (zero'd from CPU reset).
R12      EQU   12  The global program base register
R13      EQU   13  available
R14      EQU   14  I/O Routine return register.  Program is the caller
R15      EQU   15  Subroutine return register.  I/O routine is the caller
         SPACE 1
* Disabled Wait State PSW's address field values used by the program:
*    X'000000' - Successful execution of the program
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
*    X'5xddcc' - Console Device problem.  dd=device status, cc=channel status
*    X'6x00ss' - Console Device sense data.  ss=general sense byte
*                Sense data reporting is not yet enabled.
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
*         LPSW  DONE            Check memory before running
         SPACE 3
* Determine if the console device, subchannel and channel are ready for use.
         LH    R1,CONDEV   Console device address in I/O inst. register
         TIO   0(R1)       Determine if the console is there
         BC    B'0001',DEVNOAVL  ..No, CC=3 might have a different config address
         BC    B'0010',DEVBUSY   ..No, CC=2 console device or channel is busy
         BC    B'0100',CSWSTRD   ..No, CC=1 CSW stored in ASA at X'40'
* Console device is available (CC=0)!
         TITLE 'ECHO - POSITION 01 - GET CONSOLE INPUT'     
* Send HELLO WORLD message (this will be changed to instructions)
ECHOLOOP DS    0H    Query operator and echo data
         MVI   PGMRTN,HEADER     Displaying the query...
         STH   R11,STATUS        Clear status for console I/O operation
         MVI   DATA,X'00'        Clear the input...
         MVC   DATA+1(L'DATA-1),DATA     ...I/O area.
         LA    R2,GETDATA        Locate the initial CCW
         ST    R2,CAW            Tell the I/O request its address in ASA
         SIO   0(R1)       Request console channel program to start, did it?
         BC    B'0001',DEVNOAVL  ..No, CC=3 don't know why, but tell someone.
         BC    B'0010',DEVBUSY   ..No, CC=2 console device or channel is busy
         BC    B'0100',CSWSTRD   ..No, CC=1 CSW stored in ASA at X'40'
* Transfer initiated (CC=0)...
POLL1    TIO   0(R1)             Test the I/O progress.
         BC    B'0010',POLL1     CC=2, data still being sent, cont. polling
         BC    B'0001',DEVNOAVL  CC=3 don't know why, but tell someone.
         BC    B'1000',NOCSW     CC=0 missed CSW, don't know why abort
* CSW stored (CC=1), analyze for result.
         OC    STATUS,CSW+4      Accummulate Device and Channel status
         CLI   STATUS+1,X'00'    Did the channel have a problem?
         BNE   CSWACCUM          ..Yes, end with a device/channel error
* Test for abnormal status for a console device
         TM    STATUS,X'42'      Was a device error reported?
* ATTN, X'80', and UNIT EXCEPTION, X'01', are treated as normal.  ATTN is
* generated by the operator hitting the ATTN key.  And UNIT EXCEPTION is
* generated by the operator hitting the CANCEL key.  Not all console
* emulations support both possible actions by the operator.
*
* Channel end, control unit end and busy are ignored.  
         BNZ   CSWACCUM          ..Yes, end with a device/channel error
         TM    STATUS,X'04'      Device finally done?
         BNO   POLL1             ..No, Check again....
         SPACE 1
* TODO: Add logic to handle ATTN and CANCEL from the operator
         LH    R3,INLEN          Fetch the lengh of the input area
         SH    R3,CSW+6          Calculate actual bytes read
         CH    R3,QUITLEN        Was only four bytes entered?
         BE    CKQUIT
         SPACE 1
CKQUIT   DS    0H   Check if operator entered quit
         CLC   QUIT,DATA         Did operator enter quit
         BE    FINISH            ..Yes, end the program.
         SPACE 1
* No, need to echo input data - TODO
         B     ECHOLOOP
         B     FINISH            Program done
         
         SPACE 3
* Program position used in building abend address
INIT     EQU   X'00'        Program initialization
HEADER   EQU   X'01'        Operator prompt and input retrieved
PGMRTN   DC    AL1(INIT)    Initialize program position data
         SPACE 3
*
* I/O related information
*
         DS    0H          Align half words
CONDEV   DC    XL2'001F'   Console device address
STATUS   DC    XL2'0000'   Used to accumulate unit and channel status
         SPACE 3
*
* Channel Command Words
*
GETDATA  CCW   X'01',ENTER,X'40',L'ENTER   Display 'ENTER: ' on console
*              Command-chain (X'40') to the next CCW
         CCW   X'0A',DATA,X'20',L'DATA     Read operator's data
*              Suppress Incorrect Length Indicator - operator's data varies
INLEN    DC    Y(L'DATA)     Input data length (Could also use prev. CCW)
QUITLEN  DC    Y(L'QUIT)     Length of quit literal
         SPACE 1
QUIT     DC    C'quit'       quit (terminates the program)
ENTER    DC    C'ENTER: '
         DS    D
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
*    Format 1 ABEND code X'10'
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
*    Format 1 ABEND code X'20
         SPACE 1
DEVBUSY  DS    0H
         STH   1,FMT1CUU         Set the failing device address
         MVI   FMT1CODE,X'20'    Set the abend code
         OC    FMT1CODE,PGMRTN   Set where the abend was detected
         LPSW  DONE              End execution abnormally
         SPACE 1
*
* REPORT MISSING STORING OF CSW - Uses Format 1 ABEND
*
* Register usage:
*   R1  - Device Channel/Unit address
*   R12 - Global program base address
* Abnormal Termination:
*    Format 1 ABEND code X'30
         SPACE 1
NOCSW    DS    0H
         STH   1,FMT1CUU         Set the failing device address
         MVI   FMT1CODE,X'30'    Set the abend code
         OC    FMT1CODE,PGMRTN   Set where the abend was detected
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
         LPSW  DONE            End execution abnormally
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
*    Format 3 ABEND code X'50'
*
*ABENDSNS DS    0H
*         MVC   FMT3SNS,SENSDATA   Move the generic sense byte abend PSW
*         MVI   FMT3CODE,X'50'     Set the abend code
*         LPSW  DONE
         SPACE 3
*
* TERMINATION PSW Formats
*
DONE     PSW360 0,0,2,0,0
         ORG  *-3
FORMAT   DS   0AL3
* Format 1 ABEND FORMAT
FMT1CODE DS   X'00'   aa - Abend codes: 1x, 2x, 3x - x=program position
FMT1CUU  DS   H'0'    ccuu - address of device causing the termination
         ORG  FORMAT
* Format 2 ABEND FORMAT
FMT2CODE DS   X'00'   aa - Abend Code: 4x - x=program position
FMT2STAT DS   H'00'   ddcc - dd=console device status, cc=channel status
         ORG  FORMAT
* Format 3 ABEND FORMAT
FMT3CODE DS   X'00'   aa - Abend Code: 50
         DS   X'00'   not used: X'00'
FMT3SNS  DS   X'00'   ss - console device generic sense data
         TITLE 'ECHO - INPUT/OUTPUT SUBROUTINES'
*
* I/O WAIT SUBROUTINE
*
*  Register usage:
*    R1  - Device Channel/Unit address
*    R12 - Global program base address
*    R15 - Subroutine return address
*
*  Abnormal Terminations:
*    Interrupt from unexpected device received.
*DOWAIT   MVC   IONPSW(8),CONT  Set up continuation PSW for after I/O interrupt
*         LPSW  WAIT       Wait for I/O interruption and CSW from channel
*IODONE   EQU   *          The bare-metal program continues here after I/O
*         MVC   IONPSW(8),IOTRAP     Restore I/O trap PSW
*   Did the interruption come from the expected device?
*         CH    R1,IOOPSW+2          Is the interrupt from the expected device?
*         BER   R15                  ..Yes, return to caller
*         B     DEVUNKN              ..No, end program with an error
*         SPACE 1
*WAIT     PSW360 X'F8',0,2,0,0       Causes CPU to wait for I/O interruption
*                                   Channels 0-4 enabled for interrupts
*CONT     PSW360 0,0,0,0,IODONE      Causes the CPU to continue after waiting
*IOTRAP   PSW360 0,0,2,0,X'38'       I/O trap New PSW (restored after I/O)
         SPACE 3
*
* Hardware Assigned Storage Locations
*
         SPACE 1
* This DSECT allows symbolic access to these locations.  The DSECT created is
* named ASA.
ASA      ASAREA DSECT=YES
         END
