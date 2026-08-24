@echo off
echo OpenStick Bootloader
echo please make sure your device in fastboot mode
pause
fastboot erase boot
fastboot flash aboot aboot.bin
fastboot reboot
echo when detected a fastboot device
pause
fastboot oem dump fsc && fastboot get_staged fsc.bin
fastboot oem dump fsg && fastboot get_staged fsg.bin
fastboot oem dump modemst1 && fastboot get_staged modemst1.bin
fastboot oem dump modemst2 && fastboot get_staged modemst2.bin
fastboot erase boot
fastboot reboot bootloader
echo when detected a fastboot device
pause
fastboot flash partition gpt_both0.bin
fastboot flash hyp hyp.mbn
fastboot flash rpm rpm.mbn
fastboot flash sbl1 sbl1.mbn
fastboot flash tz tz.mbn
fastboot flash fsc fsc.bin
fastboot flash fsg fsg.bin
fastboot flash modemst1 modemst1.bin
fastboot flash modemst2 modemst2.bin
fastboot flash aboot aboot.bin
fastboot flash cdt sbc_1.0_8016.bin
fastboot erase boot
fastboot erase rootfs

fastboot reboot
echo flashing debian!
echo when detected a fastboot device
pause
