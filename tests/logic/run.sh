#!/usr/bin/env bash
# Logic tests for the shell's DDC, night light, autostart, drives and
# backup services: the QML functions are pulled out of the files and run
# in Node against fake commands. No Quickshell, no hardware needed.
#   tests/logic/run.sh
set -e
cd "$(dirname "$0")"
S=../../quickshell/nothing/services
node ddc_test.js       "$S/Ddc.qml" | tail -1
node night_test.js     "$S/NightLight.qml"
node autostart_test.js "$S/Autostart.qml"
node drives_test.js    "$S/Drives.qml"
node backup_test.js    "$S/ConfigBackup.qml"
node phone_test.js     "$S/Phone.qml"
node wallpaper_test.js "$S/Wallpapers.qml"
