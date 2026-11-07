
This repo uses submodules, ensure you download them when cloning the repo:

```bash
git clone --recurse-submodules https://github.com/rezafouladian/OutboundRE.git
```

Building byte accurate requires [a custom fork of asmotor](https://github.com/rezafouladian/asmotor/tree/mpw-rom-fixes).  
Build commands:

```bash
motor68k -mc0 -mpy -fb -z00 -oHardDisk_1.3.bin HardDisk_1.3.s
motor68k -mc0 -mpy -fb -z00 -oFloppy_1.3.bin Floppy_1.3.s
```
