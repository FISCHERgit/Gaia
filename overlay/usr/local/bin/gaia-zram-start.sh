#!/bin/bash
modprobe zram
MEMTOTAL=$(awk '/MemTotal/{print int($2/2)}' /proc/meminfo)
echo "${MEMTOTAL}K" > /sys/block/zram0/disksize
mkswap /dev/zram0
swapon -p 100 /dev/zram0
