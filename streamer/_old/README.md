# Streamer - the Stream UniDOS Node

What is UniDOS? It is the Best New DOS available for enhancing AMSDOS for the Amstrad CPC.  More information can be found about UniDOS
from it's official homepage here: https://unidos.cpcscene.net/doku.php?id=en:accueil

UniDOS allows for extension ROMs to be created as 'Nodes' that give additional functionality to the overall DOS.


What is the Streamer Node?

The streamer node brings some streaming abilities to UniDOS. The purpose of this is to simplify programming of some hardware for BASIC
programmers.

Streamer exposes 5 new devices:  AUDIO, PRINT, RTG, SPEECH and TEST. The purpose of these devices are not as per a normal storage device,
but to send data to various hardware in the same way as is usually done for writing to a file.  For that reason, the devices have virtual
folders within them for which to write data into files.  The files themselves for now do nothing, they are not even saved, but they are
streamed to the hardware to cause different outcomes.

A summary of the folders within each device is as follows:

AUDIO:
	- AMDRUM.DAC - AMDRUM *
 	- ASIC.DAC - Plus Machine DAC simulation * (Not implemented)
	- AY8912.DAC - all CPC DAC simulation *
	- DIGBLAST.DAC - DigiBlaster *
	- MMACHINE.DAC - RAM Music Machine * **

* hardcoded delay that should be user specified, see DAC_DELAY
** untested

 note, all the DACs should be able to play the same sample data. Future functionality will allow for sound fonts to be configured via streams.

PRINT:
	7BIT - Standard 7bit Printer Port
	8BIT - 8bit Printer Port (Not implemented)

note, all the printers ports should be able to print the same text later printer drivers could be easily added, e.g. epson, citoh (does anyone use them anymore?)

RTG:
	CRTC6845.VDP - Standard CRTC6845 (Not implemented)
	V9990.VDP - V9990 Graphics Card (Not implemented)

note, goal here is to create a virtual VDP which can handle different protocol-like commands such as sendit sprite data, tile data, CRTC6845 would use extended memory. sprites & tiles will be allocated IDs, there will be protocol commands to move them via attribute memory that is streamed

SPEECH:
	DKTRONIC.RAW - DkTronics Speech Synthesizer (Not implemented)
	SSA1.RAW - Amstrad SSA1 Speech Synthesizer (Not implemented)

note, pretty straight forward as they use the same chip, just different ports. RAW takes raw allophone data. it is possible to add additional vocabluary streams that could interpret common words.

TEST:
	TXT2SCRN - Text to Screen


Usage:

Mount a device or change to it and a folder.  

e.g. 

LOAD "AUDIO:AMDRUM/"
SAVE "BLAH",B,&4000,&4000 : REM Assuming the sample is loaded already at &4000 *

* As with the RTGs, future memory buffers can be added to the AUDIO DACs so that they can easily be handled from BASIC also.

Pending Improvements

 - Change the filename and device test heirarchies in most functions to lists rather than manual testing of each element.
 - Modify all streams to have a versioned header for the first few bytes of what is sent.
 

A lot is not finished, can I do anything with it yet?

Yes, you can play with the currently implemented streams and if you are capable, improve the code for them and extend upon the ideas within
the node.


Building Streamer (in Windows)

Use WinApe, copy the assembler source into it's assember, and assemble it.


More documentation will eventuate for streamer as it evolves.

- Julian
