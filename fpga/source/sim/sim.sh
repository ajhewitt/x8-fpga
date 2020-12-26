#!/bin/bash
set -e
iverilog -DSIM=1 -Wall -Wno-timescale -Wno-implicit-dimensions -g2001 -gno-xtypes -gstrict-ca-eval -gstrict-expr-width -y. -y.. -y../cpu -y../uart -y../spi -y../usb -y../video -y../audio tb.v
./a.out
rm -f a.out
