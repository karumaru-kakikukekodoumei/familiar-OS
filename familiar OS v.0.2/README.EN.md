# familiar-OS

**familiar OS** is a simple, bootable x86 operating system that I’m developing from scratch as a personal project.  
It is written in assembly (NASM) and runs on QEMU.

---

## Features
- Bootloader that initializes hardware and enables A20 line
- Transition from Real Mode (16-bit) to Protected Mode (32-bit)
- Load and execute a custom kernel from disk
- VGA text mode output for displaying messages
- Keyboard input
- Planned features:
  - Familiar-style interactive prompt
  - Simple file manager

---

## Requirements
- **Windows / macOS / Linux**
- [NASM](https://www.nasm.us/) – assembler
- [QEMU](https://www.qemu.org/) – emulator
- GNU Make (optional, for automated build scripts)

---

## Build & Run
```bash
# Assemble the bootloader
nasm -f bin boot.asm -o boot.bin

# Assemble the kernel
nasm -f bin kernel.asm -o kernel.bin

# Combine into a single bootable image
cat boot.bin kernel.bin > os-image.img

# Run in QEMU
qemu-system-x86_64 -drive format=raw,file=os-image.img

On Windows (PowerShell):
nasm -f bin boot.asm -o boot.bin
nasm -f bin kernel.asm -o kernel.bin
cmd /c copy /b boot.bin+kernel.bin os-image.img
qemu-system-x86_64 -drive format=raw,file=os-image.img

License
MIT License.
Feel free to use, modify, and distribute under the same license.