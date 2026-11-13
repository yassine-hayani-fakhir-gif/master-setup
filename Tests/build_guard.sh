#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
task_build=$(mktemp -d)
trap 'rm -rf "$task_build"' EXIT
as --64 Kit/native/stubs.s -o "$task_build/stubs.o"
ld -mi386pep --dll --out-implib "$task_build/kernel.a" -o "$task_build/stubs.dll" "$task_build/stubs.o" Kit/native/kernel.def
gcc -c -Os -fshort-wchar -ffreestanding -fno-stack-protector -fno-asynchronous-unwind-tables -mno-red-zone Kit/native/DiskGuard.c -o "$task_build/guard.o"
ld -mi386pep --subsystem console --entry entry --image-base 0x140000000 --dynamicbase --nxcompat -o Kit/DiskGuard.exe "$task_build/guard.o" "$task_build/kernel.a"
objcopy --remove-section .comment Kit/DiskGuard.exe
gcc -O1 -fshort-wchar -maccumulate-outgoing-args Tests/guard_test.c -o "$task_build/test"
"$task_build/test"
