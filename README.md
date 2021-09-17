# simh_tests - simh360 Stand-alone (Bare-Metal) Tests

simh_tests and its content is released under the MIT license...

Copyright 2021 Harold S. Grovesteen

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

simh-tests use the tools provided by Stand Alone Tool Kit, [SATK](http://github.com/s390guy/SATK).  SATK is required to build the stand alone (bare-metal) programs supplied by simh_tests.  A simH simulator is recommended to run the program.  The program may run on Hercules, but are designed explicitly for use with simH 360.

## simH 360 Tests

    hello      A stand-alone program sending a Hello World message to the console.
    crd2consl  Read a card from the IPL stream and send it to the console.

## Directory Content

Each directory contains a single stand-alone program.  Execution of the program does not require it to be built.  Simply boot the file with the .deck extension into your installed simH 360 simulator.  The ipl script illustrates how to do this.

Each directory contains a number of scripts.  Each script is a step in the process of building the stand-alone program.  The scripts are written for Linux but are very simple and can be readily modified for use on other platforms.

In the following discussion of the various scripts, "test" is the file name used for the test.  An output listing contains the name of the tool used to create it with a date and time of creation.  Output files use the .txt file extension.

Modification for compatibility with your environment may be required.

### asm - Step 1

asm assembles the assembler source program into a list-directed IPL directory.

    Input:   test.asm - assembler source program
    Listing: asma-mmddyy-hhmmss.txt - ASMA assembly listing
    Output:  ldid directory and contents.

### med - Step 2

med converts the the ldid directory output by ASMI into an IPL ready card deck.

    Input:   ldid directory created by the asm step
    Listing: iplasma-mmddyy-hhmmss.txt - iplasma.py listing
    Output:  test.deck - IPL capable card deck

### ipl - Step 3

ipl will cause the test.deck stand-alone program to be executed by the simH 360 simulator.

    Input:   test.deck and simh configuration, test.ini
    Listing: log-mmddyy-hhmmss.txt - Execution output from the simulator
    Output may vary depending upon the test program.

