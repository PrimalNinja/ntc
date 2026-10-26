// prep.js - NTC3D's build-time settings, applied to the framework's sources as they're read
// (c) 2026 Cyborg Unicorn Pty Ltd - MIT License
//   nobj: how many objects (game.json "nobj", 32 when not given; at most 64): Obj3D's NOBJ and its
//         arrays (lines tagged @objarr / @nobj), E3's object table (@objtab)
//   features: Z80 kept or left out (game.json "features": ["ground"]): ; @if NAME ... ; @else
//         ... ; @end in #asm blocks - the lines of the branch not wanted are dropped (saves room);
//         ; @if !NAME: kept unless the game names NAME (for parts a game can do without:     // <--- NEW
//         "noquad3", "noflyers")                                                          // <--- NEW
//   maxv, maxfv: (NEW) the most points in a model and in a face (the model tool's E3Data.cls     // <--- NEW
//         MaxV, MaxFV - build.js reads them): E3's vertex buffers (lines tagged @verts) sized  // <--- NEW
//         to fit (64 points and 48 in a face's clipping when not given)                        // <--- NEW
// ES5.
'use strict';
function prep(text, cfg)
{
	var n = (cfg && cfg.nobj) || 32, feats = (cfg && cfg.features) || [];
	if (n < 8 || n > 64) throw new Error('nobj: 8 - 64');
	var out = [], keep = [true];
	text.split('\n').forEach(function(l)
	{
		var m = /^\s*;\s*@(if|else|end)\b\s*(!?\w*)/.exec(l);   // <--- CHANGED (! too)
		if (m)
		{
			if (m[1] === 'if') keep.push(keep[keep.length - 1] && (m[2].charAt(0) === '!' ? feats.indexOf(m[2].slice(1)) < 0 : feats.indexOf(m[2]) >= 0));   // <--- CHANGED
			else if (m[1] === 'else') { var k = keep.pop(); keep.push(keep[keep.length - 1] && !k); }
			else keep.pop();
			return;
		}
		if (!keep[keep.length - 1]) return;
		if (/@objarr\b/.test(l)) l = l.replace(/\(31\) As Integer/g, '(' + (n - 1) + ') As Integer');
		if (/@objtab\b/.test(l)) l = l.replace(/obj\(255\)/, 'obj(' + (n * 8 - 1) + ')');
		if (/@nobj\b/.test(l)) l = l.replace(/NOBJ = 32/, 'NOBJ = ' + n);
		if (/@verts\b/.test(l) && cfg && cfg.maxv)                                   // <--- NEW
		{                                                                               // <--- NEW
			l = l.replace(/ov\(191\)/, 'ov(' + (cfg.maxv * 3 - 1) + ')').replace(/osx\(63\)/, 'osx(' + (cfg.maxv - 1) + ')').replace(/osy\(63\)/, 'osy(' + (cfg.maxv - 1) + ')');   // <--- NEW
			l = l.replace(/cla\(143\)/, 'cla(' + ((cfg.maxfv + 6) * 3 - 1) + ')').replace(/clb\(143\)/, 'clb(' + ((cfg.maxfv + 6) * 3 - 1) + ')');   // <--- NEW
		}                                                                               // <--- NEW
		out.push(l);
	});
	return out.join('\n');
}
module.exports = { prep: prep };
