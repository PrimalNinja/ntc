// sprdata.js - DEFENDER: the 16 sprite patterns (16 x 16, 256 colours) and their palette -> SprData.cls
// (c) 2026 Cyborg Unicorn Pty Ltd - MIT License
//
//   node tools/sprdata.js          (writes ../SprData.cls; build.js runs it)
//
// A pattern is 16 rows of 16 characters; a character is a colour of the palette below ('.' =
// see-through). The pattern numbers are Main.bas's PAT_ constants.
'use strict';
var fs = require('fs');
var path = require('path');

// colour: [character, RRRGGGBB, the 9th bit (low blue)]
var PAL = [['.', 0x00, 0], ['W', 0xFF, 1], ['Y', 0xFC, 0], ['O', 0xF0, 0], ['R', 0xE0, 0], ['M', 0xE2, 1], ['G', 0x1C, 0], ['C', 0x17, 1],
	['B', 0x03, 1], ['g', 0x92, 1], ['d', 0x0C, 0], ['b', 0x5F, 1], ['r', 0x80, 0], ['y', 0xB4, 0], ['m', 0x82, 0], ['w', 0xDB, 0]];

var PATS = {};
PATS[0] = ['................', '................', '................', '................', '....CC..........', '...gCCC.........', '..ggCCCCCC......', 'RRggCCbbCCCCCC..',
	'OOggCCbbCCCCCCWW', 'RRggCCCCCCCCCC..', '..ggCCCCCC......', '...gRRR.........', '....RR..........', '................', '................', '................'];
PATS[4] = ['................', '................', '................', '................', '....CC..........', '...gCCC.........', 'O.ggCCCCCC......', 'YOggCCbbCCCCCC..',
	'WYggCCbbCCCCCCWW', 'YOggCCCCCCCCCC..', 'O.ggCCCCCC......', '...gRRR.........', '....RR..........', '................', '................', '................'];
PATS[1] = ['................', '.....GGGGGG.....', '....GGGGGGGG....', '...GGdWWWWdGG...', '...GdWWYYWWdG...', '...GdWWYYWWdG...', '...GGdWWWWdGG...', '....GGGGGGGG....',
	'.....GGGGGG.....', '....YY.GG.YY....', '...YY..GG..YY...', '..YY...GG...YY..', '..Y....GG....Y..', '.YY....YY....YY.', '................', '................'];
PATS[5] = ['................', '.....GGGGGG.....', '....GGGGGGGG....', '...GGdWWWWdGG...', '...GdWYWWYWdG...', '...GdWYWWYWdG...', '...GGdWWWWdGG...', '....GGGGGGGG....',
	'.....GGGGGG.....', '.....YYGGYY.....', '....YY.GG.YY....', '....Y..GG..Y....', '...YY..GG..YY...', '...Y...YY...Y...', '................', '................'];
PATS[2] = ['................', '.R............R.', '..R..RRRRRR..R..', '...RRRRRRRRRR...', '...RRYYRRYYRR...', '..RRRYWRRYWRRR..', '..RRRYYRRYYRRR..', '..RRRRRRRRRRRR..',
	'...RRRMMMMRRR...', '...RRMRRRRMRR...', '....RRRRRRRR....', '...R.RR..RR.R...', '..R..R....R..R..', '.R...R....R...R.', '................', '................'];
PATS[6] = ['................', '..R..........R..', '...R.RRRRRR.R...', '...RRRRRRRRRR...', '...RRWYRRWYRR...', '..RRRYYRRYYRRR..', '..RRRYYRRYYRRR..', '..RRRRRRRRRRRR..',
	'...RRMRRRRMRR...', '...RRRMMMMRRR...', '....RRRRRRRR....', '....RRR..RRR....', '...R.R....R.R...', '...R..R..R..R...', '................', '................'];
PATS[3] = ['................', '................', '................', '......WWW.......', '......WWW.......', '......WWW.......', '.....MMMMM......', '....MMMMMMM.....',
	'....M.MMM.M.....', '....M.MMM.M.....', '......MMM.......', '......B.B.......', '......B.B.......', '......B.B.......', '.....BB.BB......', '................'];
PATS[7] = ['................', '................', '................', '......WWW.......', '......WWW.......', '......WWW.......', '.....MMMMM......', '....MMMMMMM.....',
	'...M..MMM..M....', '......MMM.......', '......MMM.......', '.....B...B......', '....B.....B.....', '....B.....B.....', '...BB.....BB....', '................'];
PATS[8] = ['................', '................', '................', '................', '................', '................', '................', 'RROOYYYYWWWWWWWW',
	'RROOYYYYWWWWWWWW', '................', '................', '................', '................', '................', '................', '................'];
PATS[9] = ['................', '................', '................', '................', '................', '......RR........', '.....RYYR.......', '....RYWWYR......',
	'....RYWWYR......', '.....RYYR.......', '......RR........', '................', '................', '................', '................', '................'];
PATS[10] = ['................', '................', '................', '................', '................', '......YY........', '.....YWWY.......', '....YWWWWY......',
	'....YWWWWY......', '.....YWWY.......', '......YY........', '................', '................', '................', '................', '................'];
PATS[11] = ['................', '................', '.....O....O.....', '......O..O......', '....OOYYYYOO....', '...O.YYWWYY.O...', '....YYWWWWYY....', '..OOYWWWWWWYOO..',
	'....YWWWWWWY....', '....YYWWWWYY....', '...O.YYWWYY.O...', '....OOYYYYOO....', '......O..O......', '.....O....O.....', '................', '................'];
PATS[12] = ['...R........R...', '....R..OO..R....', '..R..OO..OO..R..', '....O.YYYY.O....', '...O.Y....Y.O...', '.RO.Y..OO..Y.OR.', '...Y..O..O..Y...', '.O.Y.O....O.Y.O.',
	'.O.Y.O....O.Y.O.', '...Y..O..O..Y...', '.RO.Y..OO..Y.OR.', '...O.Y....Y.O...', '....O.YYYY.O....', '..R..OO..OO..R..', '....R..OO..R....', '...R........R...'];
PATS[13] = ['r......r.......r', '....r.......r...', '..r......R......', '.......r.....r..', '...R........r...', '.r......r.......', '......r.......R.', '..r.........r...',
	'........R.......', '.R...r.......r..', '..........r.....', '...r......R...r.', '.......r........', '.r..R.......r...', '.........r......', 'r....r.......r.r'];
PATS[14] = ['................', '................', '................', '................', '......bbbb......', '.....bWWWWb.....', '...GGGGGGGGGG...', '.GGYGGYGGYGGYGG.',
	'GGGGGGGGGGGGGGGG', '.dGGGGGGGGGGGGd.', '...dddddddddd...', '................', '................', '................', '................', '................'];
PATS[15] = ['................', '................', '................', '................', '......bbbb......', '.....bWWWWb.....', '...GGGGGGGGGG...', '.GGGYGGYGGYGGGG.',
	'GGGGGGGGGGGGGGGG', '.dGGGGGGGGGGGGd.', '...dddddddddd...', '................', '................', '................', '................', '................'];

var idx = {};
PAL.forEach(function(c, i) { idx[c[0]] = i; });
var out = [];
out.push("' SprData - DEFENDER: the 16 sprite patterns and their palette, made by tools/sprdata.js (change the");
out.push("' pictures there, not here). Upload sets the sprite palette and sends the patterns to the Next:");
out.push("' 0 ship, 1 lander, 2 mutant, 3 human, 4-7 their second frames, 8 the laser bolt, 9 an enemy");
out.push("' shot, 10-13 the explosion, 14-15 the baiter.");
out.push("' (c) 2026 Cyborg Unicorn Pty Ltd - MIT License");
out.push('Option Explicit');
out.push('');
out.push('Public Sub Upload()');
out.push('#asm');
out.push('            ld bc, #243B            ; the sprites\' first palette, from colour 0');
out.push('            ld a, #43');
out.push('            out (c), a');
out.push('            inc b');
out.push('            ld a, #20');
out.push('            out (c), a');
out.push('            dec b');
out.push('            ld a, #40');
out.push('            out (c), a');
out.push('            inc b');
out.push('            xor a');
out.push('            out (c), a');
out.push('            dec b');
out.push('            ld a, #44');
out.push('            out (c), a');
out.push('            inc b');
out.push('            ld hl, sd_pal');
out.push('            ld e, ' + (PAL.length * 2));
out.push('sd_pl:');
out.push('            ld a, (hl)');
out.push('            out (c), a');
out.push('            inc hl');
out.push('            dec e');
out.push('            jr nz, sd_pl');
out.push('            ld bc, #303B            ; pattern 0 on');
out.push('            xor a');
out.push('            out (c), a');
out.push('            ld hl, sd_pat');
out.push('            ld de, 16 * 256         ; 16 patterns of 256 bytes');
out.push('sd_pt:');
out.push('            ld a, (hl)');
out.push('            out (#5B), a');
out.push('            inc hl');
out.push('            dec de');
out.push('            ld a, d');
out.push('            or e');
out.push('            jr nz, sd_pt');
out.push('            jp sd_end');
out.push('sd_pal:');
PAL.forEach(function(c) { out.push('            db ' + c[1] + ', ' + c[2]); });
out.push('sd_pat:');
for (var p = 0; p < 16; p++)
{
	var rows = PATS[p];
	if (!rows || rows.length !== 16) throw new Error('pattern ' + p + ': 16 rows wanted');
	out.push('            ; pattern ' + p);
	rows.forEach(function(r, y)
	{
		if (r.length !== 16) throw new Error('pattern ' + p + ' row ' + y + ': 16 characters wanted');
		out.push('            db ' + r.split('').map(function(ch) { if (idx[ch] === undefined) throw new Error('pattern ' + p + ': no colour ' + ch); return idx[ch]; }).join(', '));
	});
}
out.push('sd_end:');
out.push('#endasm');
out.push('End Sub');
fs.writeFileSync(path.join(__dirname, '..', 'SprData.cls'), out.join('\n') + '\n');
console.log('SprData.cls: 16 patterns, ' + PAL.length + ' colours');
