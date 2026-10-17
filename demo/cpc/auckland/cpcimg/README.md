# cpcimg

Hard disc images for WinAPE's IDE drive (Symbiface II / X-Mass), for UniDOS's IDE node: a
raw `.IMG` (the disc's sectors, no header - WinAPE 2.0 takes IMG files as IDE drives) with an
MBR and one FAT16 or FAT32 partition at sector 2048. Names are 8.3 (UniDOS's FatFs is built
with long names off). A real CF card or disc written with this image (dd, Win32 Disk Imager)
is the same thing.

```
cpcimg new  DISC.IMG 64                    a new image, 64 MB (4 .. 32768; FAT16 below 64 MB, FAT32 from 64)
cpcimg put  DISC.IMG AUCKLAND.BIN AUCKLAND.DAT       files into the root
cpcimg put  DISC.IMG NULU.COM -to CPM/TOOLS          into a folder (made as needed)
cpcimg dir  DISC.IMG [CPM/TOOLS]           list the root or a folder
cpcimg get  DISC.IMG CPM/TOOLS/NULU.COM [OUT.COM]    a file out
cpcimg md   DISC.IMG GAMES                 a folder
cpcimg del  DISC.IMG GAMES/OLD.BAS         delete a file, or an empty folder
```

A file already in the image under that name is replaced. Names longer than 8.3 are cut (upper
case; characters FAT refuses become `_`). Files go in byte for byte: a `.BIN` taken off a .DSK
with its AMSDOS header keeps it.

`cpcimg.exe` is the Windows build (64-bit, a console program: run it in a Command Prompt).
Other systems: `gcc cpcimg.c -o cpcimg` (or `cl cpcimg.c`). Images over 2 GB work (64-bit file
offsets).

Sizes: FAT16 2K clusters (512 bytes under 16 MB), FAT32 512 bytes to 260 MB, then 4K / 8K / 16K.
The root folder of a FAT16 image holds 512 entries; folders hold up to 65,534 files.

Checked: images made by it read back by pyfatfs (an independent FAT reader) - files byte for byte,
folders, deletes; FAT16 8 MB and 32 MB, FAT32 128 MB and 4 GB.
