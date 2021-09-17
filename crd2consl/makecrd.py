#!/usr/bin/python3
# Copyright 2021 Harold Grovesteen
#
# MIT License:
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.

this_module="makecrd.py"
copyright="%s Copyright (C) %s Harold Grovesteen" % (this_module,"2021")

import sys
if sys.hexversion<0x03040500:
    raise NotImplementedError("%s requires Python version 3.4.5 or higher, "
        "found: %s.%s" % (this_module,sys.version_info[0],sys.version_info[1]))
import argparse       # Access command-line parser

# Python EBCDIC code page used for conversion to/from ASCII
# Change this value to use a different Python codepage.
EBCDIC="cp037"


# Converts an ascii string into EBCDIC
# Function Argument:
#   string   a string object of ASCII characters
# Returns:
#   a byte sequence of EBCDIC characters
def a2e(string):
    assert isinstance(string,str),\
        "'string' argument must be a str: %s" % string
    return string.encode(EBCDIC)


class MAKECRD(object):
    def __init__(self,args):
        self.args=args
        self.ofile=args.card[0]
        self.contents="HAPPY TESTING FROM AN IPL CARD"

    # Executes the simple utility.
    def run(self):
        card=self.contents.ljust(80)  # Create a card image in ASCII
        ebcdic=a2e(card)              # Convert card image to EBCDIC
        self.write(ebcdic)

    # Write the card to the output file
    def write(self,seq):
        # Any I/O Error exceptions will propagate up and terminate the program
        fo=open(self.ofile,mode="wb")
        fo.write(seq)
        fo.close()
        print("%s - test card written to: %s" % (this_module,self.ofile))


# Analyze command-line arguments
def parse_args():

    parser=argparse.ArgumentParser(prog=this_module,
        epilog=copyright,
        description="create a card containing EBCDIC for crd2consl test")

    parser.add_argument("card",nargs=1,metavar="FILEPATH",\
        help="output card file")

    return parser.parse_args()


if __name__ == "__main__":
    args=parse_args()
    print(copyright)
    tool=MAKECRD(args).run()
