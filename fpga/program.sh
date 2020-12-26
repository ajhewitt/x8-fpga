#!/bin/sh
if [ ! -f "../programmer/programmer_tool/obj/programmer_tool" ]; then
    make -C ../programmer/programmer_tool
fi

../programmer/programmer_tool/obj/programmer_tool -I impl/x8_impl.bin -B
