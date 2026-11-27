// gen.js - writes src/lib/<platform>/Graphics.cls for the platforms whose Graphics class is BASIC:
// one line loop (the same on every machine) over the platform's own dot. The CPC's, CP/M's and
// the Next's Graphics classes are machine code and are not made here.
//
//   node tools/graphics/gen.js            (from NTC's top folder, or anywhere)
//
// A platform is an entry in parts.js: the header comment, the size, the private variables, Start
// (the screen made ready, run before the first dot) and Dot (one pixel XORed with the pen).
// (c) 2026 Cyborg Unicorn Pty Ltd - MIT License
'use strict';
var fs = require('fs'), path = require('path');
var LIB = path.join(__dirname, '..', '..', 'src', 'lib');
var objParts = require('./parts.js');

function make(p)
{
	var a = [];

	a.push(p.header.trim());
	a.push("' Lines are XORed: drawing a line again takes it off and leaves what was under it. The same");
	a.push("' methods as the CPC's class, so programs carry over. One screen: DoubleBuffer, Flip and");
	a.push("' CopyText do nothing, Back() is 0. Made by tools/graphics/gen.js: change it there.");
	a.push('Option Explicit');
	a.push('');
	a.push('Private m_pen As Integer, m_penset As Integer, m_noclip As Integer, m_on As Integer');
	if (p.vars) { a.push(p.vars.trim()); }
	a.push('');
	a.push("' the screen made ready (before the first dot)");
	a.push('Private Sub Start()');
	a.push('  m_on = 1');
	a.push('  If m_penset = 0 Then');
	a.push('    m_pen = ' + (p.pen || 1));
	a.push('  End If');
	if (p.start) { a.push(p.start.replace(/^\n+|\s+$/g, '')); }
	a.push('End Sub');
	a.push('');
	a.push("' one dot XORed with the pen (x and y on the screen)");
	a.push('Private Sub Dot(ByVal x As Integer, ByVal y As Integer)');
	a.push(p.dot.replace(/^\n+|\s+$/g, ''));
	a.push('End Sub');
	a.push('');
	if (p.extra) { a.push(p.extra.replace(/^\n+|\s+$/g, '')); a.push(''); }
	if (p.bits)
	{
		a.push("' the bit of dot n of a byte (0 = the left one)");
		a.push('Private Function Bits(ByVal n As Integer) As Integer');
		a.push('  Select Case n');
		[128, 64, 32, 16, 8, 4, 2].forEach(function(v, i) { a.push('    Case ' + i); a.push('      Bits = ' + v); });
		a.push('    Case Else');
		a.push('      Bits = 1');
		a.push('  End Select');
		a.push('End Function');
		a.push('');
	}
	a.push("' Line x0, y0, x1, y1: a line in the pen (XOR), in pixels");
	a.push('Public Sub Line(ByVal x0 As Integer, ByVal y0 As Integer, ByVal x1 As Integer, ByVal y1 As Integer)');
	a.push('  Dim x As Integer, y As Integer, dx As Integer, dy As Integer, sx As Integer, sy As Integer');
	a.push('  Dim e As Integer, e2 As Integer, n As Integer');
	a.push('  If m_on = 0 Then');
	a.push('    Start');
	a.push('  End If');
	a.push('  If m_noclip = 0 Then');
	a.push('    If x0 < 0 Or x1 < 0 Or y0 < 0 Or y1 < 0 Then');
	a.push('      Exit Sub');
	a.push('    End If');
	a.push('    If x0 >= ' + p.w + ' Or x1 >= ' + p.w + ' Or y0 >= ' + p.h + ' Or y1 >= ' + p.h + ' Then');
	a.push('      Exit Sub');
	a.push('    End If');
	a.push('  End If');
	a.push('  x = x0');
	a.push('  y = y0');
	a.push('  dx = x1 - x0');
	a.push('  sx = 1');
	a.push('  If dx < 0 Then');
	a.push('    dx = 0 - dx');
	a.push('    sx = -1');
	a.push('  End If');
	a.push('  dy = y1 - y0');
	a.push('  sy = 1');
	a.push('  If dy < 0 Then');
	a.push('    dy = 0 - dy');
	a.push('    sy = -1');
	a.push('  End If');
	a.push('  n = dx');
	a.push('  If dy > dx Then');
	a.push('    n = dy');
	a.push('  End If');
	a.push('  e = dx - dy');
	a.push('  Do');
	a.push('    Dot x, y');
	a.push('    If n = 0 Then');
	a.push('      Exit Do');
	a.push('    End If');
	a.push('    n = n - 1');
	a.push('    e2 = e + e');
	a.push('    If e2 > 0 - dy Then');
	a.push('      e = e - dy');
	a.push('      x = x + sx');
	a.push('    End If');
	a.push('    If e2 < dx Then');
	a.push('      e = e + dx');
	a.push('      y = y + sy');
	a.push('    End If');
	a.push('  Loop');
	if (p.after) { a.push(p.after.replace(/^\n+|\s+$/g, '')); }
	a.push('End Sub');
	a.push('');
	a.push("' Plot x, y: one pixel in the pen (XOR)");
	a.push('Public Sub Plot(ByVal x As Integer, ByVal y As Integer)');
	a.push('  Line x, y, x, y');
	a.push('End Sub');
	a.push('');
	a.push("' Pen p: the pen lines are drawn in" + (p.pennote ? ' (' + p.pennote + ')' : ''));
	a.push('Public Sub Pen(ByVal p As Integer)');
	a.push('  m_pen = p');
	a.push('  m_penset = 1');
	if (p.penset) { a.push(p.penset.replace(/^\n+|\s+$/g, '')); }
	a.push('End Sub');
	a.push('');
	a.push("' Clip on: on (the default) a line with an end off the screen isn't drawn; off: no checks");
	a.push("' (the program keeps every point on the screen, or it writes over memory)");
	a.push('Public Sub Clip(ByVal on As Integer)');
	a.push('  m_noclip = 0');
	a.push('  If on = 0 Then');
	a.push('    m_noclip = 1');
	a.push('  End If');
	a.push('End Sub');
	a.push('');
	a.push("' DoubleBuffer on: nothing here (one screen)");
	a.push('Public Sub DoubleBuffer(ByVal on As Integer)');
	a.push('End Sub');
	a.push('');
	a.push("' Flip: nothing here (one screen)");
	a.push('Public Sub Flip()');
	a.push('End Sub');
	a.push('');
	a.push("' CopyText rows: nothing here (one screen)");
	a.push('Public Sub CopyText(ByVal rows As Integer)');
	a.push('End Sub');
	a.push('');
	a.push("' Width(): the width in pixels");
	a.push('Public Function Width() As Integer');
	a.push('  Width = ' + (p.wexpr || p.w));
	a.push('End Function');
	a.push('');
	a.push("' Height(): the height in pixels");
	a.push('Public Function Height() As Integer');
	a.push('  Height = ' + (p.hexpr || p.h));
	a.push('End Function');
	a.push('');
	a.push("' Back(): the buffer drawn on now: always 0");
	a.push('Public Function Back() As Integer');
	a.push('  Back = 0');
	a.push('End Function');
	a.push('');
	a.push("' Buffering(): True while double buffering is on: never");
	a.push('Public Function Buffering() As Integer');
	a.push('  Buffering = 0');
	a.push('End Function');
	return a.join('\n') + '\n';
}

Object.keys(objParts).forEach(function(strName)
{
	var p = objParts[strName], strText = make(p);

	(p.platforms || [strName]).forEach(function(strPlat)
	{
		var strDir = path.join(LIB, strPlat);

		if (!fs.existsSync(strDir)) { fs.mkdirSync(strDir, { recursive: true }); }
		fs.writeFileSync(path.join(strDir, 'Graphics.cls'), strText);
		console.log('src/lib/' + strPlat + '/Graphics.cls  (' + strText.split('\n').length + ' lines)');
	});
});
