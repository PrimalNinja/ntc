// lang.js - the extra characters of the Spanish and Russian editions of INTRODUCTION TO ZOSCII, and how text becomes font codes.
// The 5 x 7 font has ASCII 32-90 (lower case is shown as upper case). Text bytes 128 and up are 24 more glyphs, drawn after Z in the font
// table (the program maps byte 128 + n to glyph 91 + n). Russian capitals that look like a Latin capital use that capital's glyph;
// accents on Spanish capitals are left off (the font has 7 rows: no room above a capital), but N with a tilde and U with a diaeresis are drawn.
// (c) 2026 Cyborg Unicorn Pty Ltd
// ES5.
'use strict';
var EXT = 'БГДЖЗИЙЛПФЦЧШЩЪЫЬЭЮЯÑÜ¿¡';
var ART = [
	['XXXXX', 'X....', 'X....', 'XXXX.', 'X...X', 'X...X', 'XXXX.'],      // B (be)
	['XXXXX', 'X....', 'X....', 'X....', 'X....', 'X....', 'X....'],      // G (ge)
	['..XXX', '.X..X', '.X..X', '.X..X', '.X..X', 'XXXXX', 'X...X'],      // D (de)
	['X.X.X', 'X.X.X', '.XXX.', '..X..', '.XXX.', 'X.X.X', 'X.X.X'],      // ZH
	['XXXX.', '....X', '....X', '.XXX.', '....X', '....X', 'XXXX.'],      // Z (ze)
	['X...X', 'X...X', 'X..XX', 'X.X.X', 'XX..X', 'X...X', 'X...X'],      // I
	['X.X.X', 'X...X', 'X..XX', 'X.X.X', 'XX..X', 'X...X', 'X...X'],      // short I
	['..XXX', '.X..X', '.X..X', '.X..X', '.X..X', 'X...X', 'X...X'],      // L
	['XXXXX', 'X...X', 'X...X', 'X...X', 'X...X', 'X...X', 'X...X'],      // P
	['..X..', '.XXX.', 'X.X.X', 'X.X.X', '.XXX.', '..X..', '..X..'],      // F
	['X..X.', 'X..X.', 'X..X.', 'X..X.', 'X..X.', 'XXXXX', '....X'],      // TS
	['X...X', 'X...X', 'X...X', '.XXXX', '....X', '....X', '....X'],      // CH
	['X.X.X', 'X.X.X', 'X.X.X', 'X.X.X', 'X.X.X', 'X.X.X', 'XXXXX'],      // SH
	['X.X.X', 'X.X.X', 'X.X.X', 'X.X.X', 'X.X.X', 'XXXXX', '....X'],      // SHCH
	['XX...', '.X...', '.X...', '.XXX.', '.X..X', '.X..X', '.XXX.'],      // hard sign
	['X...X', 'X...X', 'X...X', 'XX..X', 'X.X.X', 'X.X.X', 'XX..X'],      // YERU
	['X....', 'X....', 'X....', 'XXXX.', 'X...X', 'X...X', 'XXXX.'],      // soft sign
	['.XXX.', 'X...X', '....X', '..XXX', '....X', 'X...X', '.XXX.'],      // E (reversed)
	['X.XX.', 'XX..X', 'XX..X', 'XXX.X', 'XX..X', 'XX..X', 'X.XX.'],      // YU
	['.XXXX', 'X...X', 'X...X', '.XXXX', '..X.X', '.X..X', 'X...X'],      // YA
	['.XX.X', 'X...X', 'XX..X', 'X.X.X', 'X..XX', 'X...X', 'X...X'],      // N with a tilde
	['.X.X.', 'X...X', 'X...X', 'X...X', 'X...X', 'X...X', '.XXX.'],      // U with a diaeresis
	['..X..', '.....', '..X..', '.X...', 'X....', 'X...X', '.XXX.'],      // inverted ?
	['..X..', '.....', '..X..', '..X..', '..X..', '..X..', '..X..']       // inverted !
];
function glyphBytes(rows)
{
	var out = [], c, r;
	for (c = 0; c < 5; c++) { var b = 0; for (r = 0; r < 7; r++) { if (rows[r].charAt(c) === 'X') { b |= 1 << r; } } out.push(b); }
	return out;
}
function extFont()
{
	var f = [];
	ART.forEach(function(g) { f = f.concat(glyphBytes(g)); });
	return f;
}
var LOOK = { 'А': 'A', 'В': 'B', 'Е': 'E', 'Ё': 'E', 'К': 'K', 'М': 'M', 'Н': 'H', 'О': 'O', 'Р': 'P', 'С': 'C', 'Т': 'T', 'Х': 'X', 'У': 'Y',
	'Á': 'A', 'É': 'E', 'Í': 'I', 'Ó': 'O', 'Ú': 'U', '—': '-', '–': '-', '«': '"', '»': '"', '“': '"', '”': '"', '‘': "'", '’': "'" };
// encode(s): the text as an array of byte codes (10 = new line); throws on a character the font hasn't
function encode(s, name)
{
	var a = [], q, ch, i;
	s = s.toUpperCase();
	for (q = 0; q < s.length; q++)
	{
		ch = s.charAt(q);
		if (ch === '\n') { a.push(10); continue; }
		if (LOOK[ch]) { ch = LOOK[ch]; }
		i = EXT.indexOf(ch);
		if (i >= 0) { a.push(128 + i); continue; }
		if (ch.charCodeAt(0) >= 32 && ch.charCodeAt(0) <= 90) { a.push(ch.charCodeAt(0)); continue; }
		throw new Error((name || '') + ': character ' + JSON.stringify(s.charAt(q)) + ' (U+' + s.charCodeAt(q).toString(16) + ') is not in the font');
	}
	return a;
}
module.exports = { EXT: EXT, extFont: extFont, encode: encode, ART: ART };
