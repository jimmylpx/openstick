#!/bin/sh
# 
# Copyright (C) 2021-2022 OpenStick Project
# Author : HandsomeYingyan <handsomeyingyan@gmail.com>
#
# get in new aboot
# now we flash debian
fastboot -S 200M flash rootfs rootfs.img
fastboot flash boot boot.img
fastboot reboot
