// ============================================================
// NTC BASIC - the Locomotive BASIC flavour (Amstrad CPC): a flavour preprocessor (ntcPrep)
// (c) 2026 Cyborg Unicorn Pty Ltd - MIT License
// ============================================================
// A Locomotive BASIC 1.1 listing turned into VB5 text for NTC's one parser and compiler, line
// for line. Familiar, not a recreation: whole numbers only, no editor commands. A line using
// something NTC has not got becomes a comment (its line number kept, so a GOTO to it still
// lands) and a warning - the program compiles without it.
//   a, a%, a$     three variables (renamed when they clash: a, a_i, a_s; an array and a
//                 plain variable of one name: the array gets _a)
//   '#long        a type hint at the end of a line (DIM x '#long, total = 0 '#long)
//   DATA / READ / RESTORE, DEF FN, SWAP, MAX / MIN, BIN$, WAIT: written as VB lines
// Usage: ntcFlavourLoco({ name, text }, options) -> { text, lines, errors, warnings }
// ============================================================

function ntcFlavourLoco(objFile_a, objOptions_a)
{
	var strFile = objFile_a.name || 'main.bas';
	var arrErrors = [];
	var arrWarnings = [];
	var arrSrc = String(objFile_a.text || '').replace(/\r\n?/g, '\n').split('\n');
	var arrLineToks = [];		// per source line: its tokens (after the line number) and hint
	var arrTop = [];			// declarations, DATA table { line, text }
	var arrBody = [];			// the program { line, text }
	var arrTail = [];			// DEF FN functions, helpers { line, text }
	var objVars = {};			// base name (lower case) -> { '': {...}, '%': {...}, '$': {...} }
	var arrData = [];			// DATA items { line (the Locomotive line number), text, src }
	var arrDataLines = [];		// [Locomotive line number, first item index]
	var objFn = {};				// FN name -> true
	var objHelpers = {};		// helper name -> true (written once at the end)
	var intSrcLine = 0;			// the physical line being read (1 based)
	var strWarnThis = '';		// set when the line uses something unsupported

	// the keywords (lower case): statements, functions, and words that are neither variables
	var KEYWORDS = ('abs after and asc atn auto bin$ border break call cat chain chr$ cint clear clg closein closeout cls cont copychr$ cos creal cursor ' +
		'data dec$ def defint defreal defstr deg delete derr di dim draw drawr edit ei else end ent env eof erase erl err error every exp fill fix fn for ' +
		'frame fre gosub goto graphics hex$ himem if ink inkey inkey$ inp input instr int joy key left$ len let line list load locate log log10 lower$ ' +
		'mask max memory merge mid$ min mod mode move mover new next not on openin openout or origin out paper peek pen pi plot plotr poke pos print ' +
		'rad randomize read release rem remain renum restore resume return right$ rnd round run save sgn sin sound space$ spc speed sq sqr step stop ' +
		'str$ string$ swap symbol tab tag tagoff tan test testr then time to troff tron unt upper$ using val vpos wait wend while width window write xor ' +
		'xpos ypos zone').split(' ');
	var objKw = {};
	KEYWORDS.forEach(function(k_a) { objKw[k_a] = true; });
	// names VB / NTC keeps for itself: a variable called one of these gets _v
	var VB_RESERVED = {};
	('as byval byref call case const do each enum exit explicit function get global inkey is like loop me new optional option preserve private ' +
		'property public redim select set static sub then timer ticks turbo type until wend with beep deek doke interrupt doevents debug ' +
		'integer long byte boolean string true false nothing iif choose ucase lcase trim ltrim rtrim replace split join format strcomp ' +
		'instrrev strreverse mid left right chr hex oct space str val cstr cbyte cint clng cbool lbound ubound erase sqr rnd randomize').split(' ').forEach(function(k_a) { VB_RESERVED[k_a] = true; });
	// functions NTC has under the same or another name
	var FUNCS = { 'abs': 'Abs', 'asc': 'Asc', 'chr$': 'Chr$', 'cint': 'CInt', 'fix': 'Fix', 'int': 'Int', 'len': 'Len', 'left$': 'Left$', 'right$': 'Right$',
		'mid$': 'Mid$', 'instr': 'InStr', 'peek': 'Peek', 'inp': 'Inp', 'sgn': 'Sgn', 'sqr': 'Sqr', 'str$': 'Str$', 'val': 'Val', 'space$': 'Space$',
		'string$': 'String$', 'upper$': 'UCase$', 'lower$': 'LCase$', 'hex$': 'Hex$' };
	var UNSUPPORTED_F = { 'atn': 1, 'cos': 1, 'sin': 1, 'tan': 1, 'exp': 1, 'log': 1, 'log10': 1, 'pi': 1, 'creal': 1, 'copychr$': 1, 'dec$': 1,
		'err': 1, 'erl': 1, 'derr': 1, 'fre': 1, 'himem': 1, 'remain': 1, 'sq': 1, 'test': 1, 'testr': 1, 'vpos': 1, 'xpos': 1, 'ypos': 1 };

	function warn(strWhat_a)
	{
		if (!strWarnThis) { strWarnThis = strWhat_a; }
		throw { unsupported: strWhat_a };
	}

	// ------------------------------------------------------------
	// tokens of one line: num, str, id (with its suffix), kw, op, rem (the rest: a comment)
	// ------------------------------------------------------------
	function tokenise(str_a)
	{
		var arrT = [];
		var i = 0;
		var m = null;

		while (i < str_a.length)
		{
			var c = str_a.charAt(i);

			if (/\s/.test(c)) { i++; continue; }
			if (c === "'") { arrT.push({ t: 'rem', v: str_a.substr(i + 1) }); break; }
			if (c === '"')
			{
				var j = str_a.indexOf('"', i + 1);
				if (j < 0) { j = str_a.length; }		// a string left open runs to the end of the line, as on the CPC
				arrT.push({ t: 'str', v: str_a.substring(i + 1, j) });
				i = j + 1;
				continue;
			}
			if ((m = str_a.substr(i).match(/^&[Xx][01]+/))) { arrT.push({ t: 'num', v: '&X' + m[0].substr(2) }); i += m[0].length; continue; }
			if ((m = str_a.substr(i).match(/^&[Hh]?[0-9A-Fa-f]+/))) { arrT.push({ t: 'num', v: '&H' + m[0].replace(/^&[Hh]?/, '').toUpperCase() }); i += m[0].length; continue; }
			if ((m = str_a.substr(i).match(/^(\d*\.\d+|\d+\.?\d*)(E[+-]?\d+)?/i)))
			{
				arrT.push({ t: 'num', v: m[0], real: /[.Ee]/.test(m[0]) });
				i += m[0].length;
				continue;
			}
			if ((m = str_a.substr(i).match(/^[A-Za-z][A-Za-z0-9.]*[$%!]?/)))
			{
				var strW = m[0];
				var strL = strW.toLowerCase();

				// FNname (no space) is FN name
				if (/^fn[a-z]/.test(strL) && !objKw[strL]) { arrT.push({ t: 'kw', v: 'fn' }); arrT.push(ident(strW.substr(2))); i += strW.length; continue; }
				if (strL === 'rem') { arrT.push({ t: 'rem', v: str_a.substr(i + 3) }); break; }
				if (objKw[strL]) { arrT.push({ t: 'kw', v: strL }); }
				else if (objKw[strL.replace(/[$%!]$/, '')] && /[%!]$/.test(strL)) { arrT.push({ t: 'kw', v: strL.replace(/[$%!]$/, '') }); }
				else { arrT.push(ident(strW)); }
				i += strW.length;
				continue;
			}
			if ((m = str_a.substr(i).match(/^(<>|<=|>=|=<|=>|><)/))) { arrT.push({ t: 'op', v: { '=<': '<=', '=>': '>=', '><': '<>' }[m[0]] || m[0] }); i += 2; continue; }
			if ('+-*/\\^=<>(),;:#|@'.indexOf(c) > -1) { arrT.push({ t: 'op', v: c }); i++; continue; }
			if (c === '?') { arrT.push({ t: 'kw', v: 'print' }); i++; continue; }
			arrT.push({ t: 'op', v: c });
			i++;
		}
		return arrT;
	}
	function ident(strW_a)
	{
		var arrM = strW_a.match(/^([A-Za-z][A-Za-z0-9.]*)([$%!]?)$/);
		return { t: 'id', base: arrM[1].toLowerCase(), suf: arrM[2], src: strW_a };
	}

	// ------------------------------------------------------------
	// pass 1: tokens, variables (suffix, array use, hints), DATA, line numbers
	// ------------------------------------------------------------
	function varRec(strBase_a, strSuf_a)
	{
		if (!objVars[strBase_a]) { objVars[strBase_a] = {}; }
		if (!objVars[strBase_a][strSuf_a]) { objVars[strBase_a][strSuf_a] = { scalar: false, array: false, dims: null, hint: '', line: intSrcLine, dimline: 0 }; }
		return objVars[strBase_a][strSuf_a];
	}
	var JS_TYPES = { 'int': 'Integer', 'integer': 'Integer', 'long': 'Long', 'byte': 'Byte', 'bool': 'Boolean', 'boolean': 'Boolean', 'string': 'String' };
	function hintType(strH_a)
	{
		var strH = String(strH_a).toLowerCase().replace(/\s+/g, ' ').replace(/^\s+|\s+$/g, '');
		var m = null;

		if ((m = strH.match(/^string\s*\*\s*(\d+)$/))) { return 'String * ' + m[1]; }
		if ((m = strH.match(/^stringmax\s*(\d+)$/))) { return 'String Max ' + m[1]; }
		if (JS_TYPES[strH] !== undefined) { return JS_TYPES[strH]; }
		arrErrors.push({ file: strFile, line: intSrcLine, msg: "unknown type hint: '#" + strH_a });
		return '';
	}
	arrSrc.forEach(function(strLine_a, intI_a)
	{
		var strRest = strLine_a;
		var intNum = null;
		var m = strRest.match(/^\s*(\d+)\s?/);
		var arrT = null;
		var strHint = '';

		intSrcLine = intI_a + 1;
		if (m) { intNum = parseInt(m[1], 10); strRest = strRest.substr(m[0].length); }
		arrT = tokenise(strRest);
		// '#type at the end: a hint (a comment to the CPC)
		if (arrT.length && arrT[arrT.length - 1].t === 'rem' && /^#/.test(arrT[arrT.length - 1].v) && !/^#\s*option\s+flavour/i.test(arrT[arrT.length - 1].v))
		{
			strHint = arrT[arrT.length - 1].v.substr(1);
			arrT.pop();
		}
		arrLineToks.push({ num: intNum, toks: arrT, hint: strHint, src: strLine_a.replace(/^\s+|\s+$/g, '') });
		// variables: a name followed by ( is an array
		for (var k = 0; k < arrT.length; k++)
		{
			var o = arrT[k];

			if (o.t === 'kw' && o.v === 'fn' && arrT[k + 1] && arrT[k + 1].t === 'id') { k++; continue; }
			if (o.t === 'kw' && o.v === 'def') { break; }			// DEF FN: its parameters are its own
			if (o.t === 'kw' && o.v === 'data') { break; }
			if (o.t !== 'id') { continue; }
			var objV = varRec(o.base, o.suf);
			if (arrT[k + 1] && arrT[k + 1].t === 'op' && arrT[k + 1].v === '(') { objV.array = true; } else { objV.scalar = true; }
		}
		// DIM: the sizes, and the hint for the names in it
		if (arrT.length && arrT[0].t === 'kw' && arrT[0].v === 'dim')
		{
			dimScan(arrT, strHint);
		}
		else if (strHint && arrT.length && arrT[0].t === 'id')
		{
			varRec(arrT[0].base, arrT[0].suf).hint = hintType(strHint);
		}
		else if (strHint && arrT.length > 1 && arrT[0].t === 'kw' && arrT[0].v === 'let' && arrT[1].t === 'id')
		{
			varRec(arrT[1].base, arrT[1].suf).hint = hintType(strHint);
		}
		// DATA: the items, in order, with their line number
		for (var d = 0; d < arrT.length; d++)
		{
			if (arrT[d].t === 'kw' && arrT[d].v === 'data')
			{
				var strItems = strRest.substr(strRest.toUpperCase().indexOf('DATA') + 4);

				arrDataLines.push([intNum, arrData.length]);
				splitData(strItems).forEach(function(s_a) { arrData.push({ line: intNum, text: s_a }); });
				break;
			}
		}
	});
	function dimScan(arrT_a, strHint_a)
	{
		var k = 1;

		while (k < arrT_a.length)
		{
			if (arrT_a[k].t !== 'id') { k++; continue; }
			var o = arrT_a[k];
			var objV = varRec(o.base, o.suf);

			k++;
			if (arrT_a[k] && arrT_a[k].t === 'op' && arrT_a[k].v === '(')
			{
				var intDepth = 0;
				var arrDim = [];
				var arrCur = [];

				for (k++; k < arrT_a.length; k++)
				{
					var p = arrT_a[k];
					if (p.t === 'op' && p.v === '(') { intDepth++; }
					if (p.t === 'op' && p.v === ')') { if (intDepth === 0) { break; } intDepth--; }
					if (p.t === 'op' && p.v === ',' && intDepth === 0) { arrDim.push(arrCur); arrCur = []; continue; }
					arrCur.push(p);
				}
				arrDim.push(arrCur);
				objV.dims = arrDim;
				objV.dimline = intSrcLine;
				objV.array = true;
				k++;
			}
			else
			{
				objV.scalar = true;
			}
			if (strHint_a) { objV.hint = hintType(strHint_a); }
			while (k < arrT_a.length && !(arrT_a[k].t === 'op' && arrT_a[k].v === ',')) { if (arrT_a[k].t === 'op' && arrT_a[k].v === ':') { return; } k++; }
			k++;
		}
	}
	function splitData(str_a)
	{
		// items between commas; quotes keep commas; the statement ends at : (outside quotes)
		var arrI = [];
		var strCur = '';
		var blnQ = false;
		var blnWasQ = false;

		for (var i = 0; i < str_a.length; i++)
		{
			var c = str_a.charAt(i);

			if (c === '"') { blnQ = !blnQ; blnWasQ = true; continue; }
			if (!blnQ && (c === ',' || c === ':')) { arrI.push(blnWasQ ? strCur : strCur.replace(/^\s+|\s+$/g, '')); strCur = ''; blnWasQ = false; if (c === ':') { return arrI; } continue; }
			strCur += c;
		}
		arrI.push(blnWasQ ? strCur : strCur.replace(/^\s+|\s+$/g, ''));
		return arrI;
	}

	// VB names: a, a%, a$ apart when they clash; an array apart from a plain variable
	function vbName(strBase_a, strSuf_a, blnArray_a)
	{
		var objB = objVars[strBase_a] || {};
		var intKinds = Object.keys(objB).length;
		var strName = strBase_a.replace(/\./g, '_');
		var objV = objB[strSuf_a] || {};

		if (strSuf_a === '$') { strName += '_s'; }
		else if (strSuf_a === '%' && intKinds > 1) { strName += '_i'; }
		if (blnArray_a && objV.scalar && objV.array) { strName += '_a'; }
		if (VB_RESERVED[strName] || objKw[strName]) { strName += '_v'; }
		return strName;
	}
	function vbType(strBase_a, strSuf_a)
	{
		var objV = (objVars[strBase_a] || {})[strSuf_a] || {};

		if (objV.hint) { return objV.hint; }
		if (strSuf_a === '$') { return 'String'; }
		return 'Integer';
	}

	// ------------------------------------------------------------
	// expressions: the tokens copied across with names changed (the precedence of Locomotive
	// BASIC and VB is the same); MAX / MIN / FN / INT(RND * n) / BIN$ / HEX$(n, d) rewritten
	// ------------------------------------------------------------
	var arrT = [];
	var intP = 0;
	function pk(n_a) { return arrT[intP + (n_a || 0)] || { t: 'end', v: '' }; }
	function nx() { return arrT[intP++] || { t: 'end', v: '' }; }
	function isO(v_a, n_a) { var o = pk(n_a); return o.t === 'op' && o.v === v_a; }
	function isK(v_a, n_a) { var o = pk(n_a); return o.t === 'kw' && o.v === v_a; }
	function stopper()
	{
		var o = pk();
		return o.t === 'end' || o.t === 'rem' || (o.t === 'op' && (o.v === ':' || o.v === ',' || o.v === ';' || o.v === ')')) ||
			(o.t === 'kw' && (o.v === 'then' || o.v === 'else' || o.v === 'to' || o.v === 'step' || o.v === 'goto' || o.v === 'gosub'));
	}
	function args()
	{
		var arrA = [];

		if (!isO('(')) { return arrA; }
		nx();
		while (!isO(')') && pk().t !== 'end')
		{
			arrA.push(expr());
			if (isO(',')) { nx(); } else { break; }
		}
		if (isO(')')) { nx(); }
		return arrA;
	}
	function expr()
	{
		var arrOut = [];

		while (!stopper())
		{
			var o = nx();

			if (o.t === 'num')
			{
				if (o.real) { warn('a real number (' + o.v + ')'); }
				arrOut.push(o.v);
				continue;
			}
			if (o.t === 'str') { arrOut.push('"' + o.v.replace(/"/g, '""') + '"'); continue; }
			if (o.t === 'op')
			{
				if (o.v === '(')
				{
					var strIn = expr();
					if (isO(')')) { nx(); }
					arrOut.push('(' + strIn + ')');
					continue;
				}
				if (o.v === '#' || o.v === '|' || o.v === '@') { warn(o.v); }
				arrOut.push(o.v);
				continue;
			}
			if (o.t === 'id')
			{
				if (o.suf === '!') { warn('a real variable (' + o.src + ')'); }
				if (isO('('))
				{
					arrOut.push(vbName(o.base, o.suf, true) + '(' + args().join(', ') + ')');
				}
				else
				{
					arrOut.push(vbName(o.base, o.suf, false));
				}
				continue;
			}
			if (o.t === 'kw')
			{
				arrOut.push(kwExpr(o.v));
				continue;
			}
			warn(String(o.v));
		}
		return arrOut.join(' ').replace(/\( /g, '(').replace(/ \)/g, ')');
	}
	function kwExpr(strK_a)
	{
		var arrA = null;

		switch (strK_a)
		{
			case 'and': return 'And';
			case 'or': return 'Or';
			case 'xor': return 'Xor';
			case 'not': return 'Not';
			case 'mod': return 'Mod';
			case 'time': return 'Ticks';
			case 'inkey$': return 'Inkey$';
			case 'int':
				// INT(RND * n) -> Rnd(n)
				if (isO('(') && isK('rnd', 1) && isO('*', 2))
				{
					nx(); nx(); nx();
					var strN = expr();
					if (isO(')')) { nx(); }
					return 'Rnd(' + strN + ')';
				}
				return 'Int(' + args().join(', ') + ')';
			case 'rnd': warn('RND (a fraction: use INT(RND * n))'); break;
			case 'fn':
				var o = nx();
				if (o.t !== 'id') { warn('FN without a name'); }
				arrA = args();
				return 'fn_' + vbName(o.base, o.suf, false) + (arrA.length ? '(' + arrA.join(', ') + ')' : '');
			case 'max': case 'min':
				arrA = args();
				var strR = arrA[0] || '0';
				for (var i = 1; i < arrA.length; i++) { strR = 'IIf((' + strR + ') ' + (strK_a === 'max' ? '>' : '<') + ' (' + arrA[i] + '), ' + strR + ', ' + arrA[i] + ')'; }
				return strR;
			case 'unt': case 'round': case 'cint':
				arrA = args();
				return (strK_a === 'cint') ? 'CInt(' + arrA[0] + ')' : '(' + arrA[0] + ')';
			case 'bin$':
				arrA = args();
				objHelpers.bin = true;
				return 'loco_bin(' + arrA[0] + ', ' + (arrA[1] || '0') + ')';
			case 'hex$':
				arrA = args();
				if (arrA.length > 1) { return 'Right$(String$(' + arrA[1] + ', "0") & Hex$(' + arrA[0] + '), ' + arrA[1] + ')'; }
				return 'Hex$(' + arrA[0] + ')';
			case 'pos':
				arrA = args();
				return '(StdIO.Column + 1)';
			case 'inkey':
				// INKEY(n): 0 held, -1 not (the shift / control values 32, 128 ... aren't given)
				arrA = args();
				return '(-1 - Keys.Down(' + arrA[0] + '))';
			case 'joy':
				arrA = args();
				return 'Keys.Joystick(' + arrA[0] + ')';
			case 'eof':
				objHelpers.fi = true;
				return 'FileSystem.Eof(loco_fi)';
		}
		if (UNSUPPORTED_F[strK_a]) { warn(strK_a.toUpperCase()); }
		if (FUNCS[strK_a] !== undefined)
		{
			arrA = args();
			return FUNCS[strK_a] + '(' + arrA.join(', ') + ')';
		}
		warn(strK_a.toUpperCase());
		return '';
	}

	// ------------------------------------------------------------
	// statements
	// ------------------------------------------------------------
	function lineNum(o_a)
	{
		if (!o_a || o_a.t !== 'num' || o_a.real) { warn('a line number'); }
		return o_a.v;
	}
	function lineList()
	{
		var arrL = [lineNum(nx())];

		while (isO(',')) { nx(); arrL.push(lineNum(nx())); }
		return arrL.join(', ');
	}
	function target()
	{
		// after THEN / ELSE: a line number is a GOTO
		if (pk().t === 'num') { return 'GoTo ' + lineNum(nx()); }
		return statements(true);
	}
	function lvalue()
	{
		var o = nx();

		if (o.t !== 'id') { warn('LET without a variable'); }
		if (o.suf === '!') { warn('a real variable (' + o.src + ')'); }
		if (isO('(')) { return vbName(o.base, o.suf, true) + '(' + args().join(', ') + ')'; }
		return vbName(o.base, o.suf, false);
	}
	function stream(blnFile_a)
	{
		// #0 is the screen; #9 the file (PRINT, INPUT, LINE INPUT); others are not here
		var strN = '0';
		if (isO('#'))
		{
			nx();
			var o = nx();
			strN = String(o.v);
			if ((strN !== '0') && !(blnFile_a && (strN === '9'))) { warn('stream #' + o.v); }
			if (isO(',')) { nx(); }
		}
		return strN;
	}
	// PRINT #9: the items as one string (numbers as PRINT shows them: a space after); ; and ,
	// join them (no zones). A trailing ; can't keep the line open: a warning
	function printFile()
	{
		var arrS = [];
		var blnOpen = false;
		while (!(pk().t === 'end' || pk().t === 'rem' || isO(':') || isK('else')))
		{
			if (isO(';') || isO(',')) { nx(); blnOpen = true; continue; }
			blnOpen = false;
			var o = pk();
			var blnStr = (o.t === 'str') || (o.suf === '$') || ((o.t === 'kw') && /\$$/.test(o.v));
			var strE = expr();
			arrS.push(blnStr ? strE : ('Str$(' + strE + ') & " "'));
		}
		if (blnOpen) { warn('PRINT #9 ending with ; or , (each PRINT #9 writes a whole line)'); }
		objHelpers.fo = true;
		objHelpers.r = true;
		return 'loco_r = FileSystem.WriteLine(loco_fo, ' + (arrS.length ? arrS.join(' & ') : '""') + ')';
	}
	function printItems()
	{
		var strOut = '';

		while (!(pk().t === 'end' || pk().t === 'rem' || isO(':') || isK('else')))
		{
			if (isO(';') || isO(',')) { strOut += nx().v + ' '; continue; }
			if (isK('using')) { warn('PRINT USING'); }
			if (isK('tab') || isK('spc'))
			{
				var strF = (nx().v === 'tab') ? 'Tab' : 'Spc';
				strOut += strF + '(' + args().join(', ') + ')';
				continue;
			}
			strOut += expr();
		}
		return strOut.replace(/\s+$/, '');
	}
	function statement()
	{
		var o = pk();

		if (o.t === 'id' || (o.t === 'kw' && o.v === 'let'))
		{
			if (o.t === 'kw') { nx(); }
			var strL = lvalue();
			if (!isO('=')) { warn('a statement (' + strL + ')'); }
			nx();
			return strL + ' = ' + expr();
		}
		if (o.t === 'kw' && o.v === 'mid$' && isO('(', 1))
		{
			// MID$(a$, i [, n]) = b$: NTC has the Mid$ statement too
			nx();
			var arrMa = args();
			if (!isO('=')) { warn('MID$'); }
			nx();
			return 'Mid$(' + arrMa.join(', ') + ') = ' + expr();
		}
		if (o.t !== 'kw') { warn(String(o.v || o.t)); }
		nx();
		switch (o.v)
		{
			case 'print':
				if (stream(true) === '9') { return printFile(); }
				return 'Print' + (pk().t === 'end' || isO(':') || isK('else') ? '' : ' ' + printItems());
			case 'input':
			case 'line':
				if (o.v === 'line') { if (!isK('input')) { warn('LINE'); } nx(); }
				if (stream(true) === '9')
				{
					// INPUT #9 / LINE INPUT #9: one line of the file for each variable
					var arrFv = [];
					objHelpers.fi = true;
					do
					{
						var objFt = pk();
						var strFv = lvalue();
						arrFv.push(strFv + ' = ' + ((objFt.suf === '$') ? 'FileSystem.ReadLine(loco_fi)' : 'Val(FileSystem.ReadLine(loco_fi))'));
						if (isO(',')) { nx(); continue; }
						break;
					} while (true);
					return arrFv.join(' : ');
				}
				var strIn = '';
				if (pk().t === 'str')
				{
					strIn = '"' + nx().v.replace(/"/g, '""') + '"';
					if (isO(';') || isO(',')) { strIn += nx().v; }
					strIn += ' ';
				}
				var arrV = [lvalue()];
				while (isO(',')) { nx(); arrV.push(lvalue()); }
				return 'Input ' + strIn + arrV.join(', ');
			case 'if':
				var strC = expr();
				var strThen = '';
				if (isK('then')) { nx(); strThen = target(); }
				else if (isK('goto')) { nx(); strThen = 'GoTo ' + lineNum(nx()); }
				else { warn('IF without THEN'); }
				var strElse = '';
				if (isK('else')) { nx(); strElse = ' Else ' + target(); }
				return 'If ' + strC + ' Then ' + strThen + strElse;
			case 'for':
				var strV = lvalue();
				if (!isO('=')) { warn('FOR'); }
				nx();
				var strA = expr();
				if (!isK('to')) { warn('FOR without TO'); }
				nx();
				var strB = expr();
				var strS = '';
				if (isK('step')) { nx(); strS = ' Step ' + expr(); }
				return 'For ' + strV + ' = ' + strA + ' To ' + strB + strS;
			case 'next':
				var intN = 0;
				while (pk().t === 'id') { nx(); intN++; if (isO(',')) { nx(); } }
				return (intN > 1) ? new Array(intN + 1).join('Next : ').replace(/ : $/, '') : 'Next';
			case 'while': return 'While ' + expr();
			case 'wend': return 'Wend';
			case 'goto': return 'GoTo ' + lineNum(nx());
			case 'gosub': return 'GoSub ' + lineNum(nx());
			case 'return': return 'Return';
			case 'end': return 'End';
			case 'stop': return 'Stop';
			case 'on':
				if (isK('error') || isK('break') || isK('sq')) { warn('ON ' + pk().v.toUpperCase()); }
				var strX = expr();
				if (isK('goto')) { nx(); return 'On ' + strX + ' GoTo ' + lineList(); }
				if (isK('gosub')) { nx(); return 'On ' + strX + ' GoSub ' + lineList(); }
				warn('ON');
				break;
			case 'rem': return '';
			case 'data':
				intP = arrT.length;		// (collected in pass 1)
				return '';
			case 'read':
				var arrR = [];
				objHelpers.data = true;
				do
				{
					var objT = pk();
					var strR = lvalue();
					arrR.push(strR + ' = ' + ((objT.suf === '$') ? 'loco_d(loco_p)' : 'Val(loco_d(loco_p))') + ' : loco_p = loco_p + 1');
					if (isO(',')) { nx(); continue; }
					break;
				} while (true);
				return arrR.join(' : ');
			case 'restore':
				objHelpers.data = true;
				if (pk().t === 'num')
				{
					var intLn = parseInt(nx().v, 10);
					var intIdx = arrData.length;
					for (var q = 0; q < arrDataLines.length; q++) { if (arrDataLines[q][0] >= intLn) { intIdx = arrDataLines[q][1]; break; } }
					return 'loco_p = ' + intIdx;
				}
				return 'loco_p = 0';
			case 'dim':
				// the arrays are declared at the top (a size with a variable in it: ReDim here)
				var arrRd = [];
				while (pk().t === 'id')
				{
					var objD = nx();
					var objVd = (objVars[objD.base] || {})[objD.suf];
					if (isO('('))
					{
						var arrDa = args();
						if (objVd && objVd.redim) { arrRd.push('ReDim ' + vbName(objD.base, objD.suf, true) + '(' + arrDa.join(', ') + ')'); }
					}
					if (isO(',')) { nx(); }
				}
				return arrRd.join(' : ');
			case 'erase':
				var arrE = [];
				while (pk().t === 'id') { var objEv = nx(); arrE.push(vbName(objEv.base, objEv.suf, true)); if (isO(',')) { nx(); } }
				return 'Erase ' + arrE.join(', ');
			case 'swap':
				var strP = lvalue();
				var objFirst = arrT[intP - 1];
				if (!isO(',')) { warn('SWAP'); }
				nx();
				var strQ = lvalue();
				var strTmp = 'loco_t' + ((vbType(objFirst.base || '', objFirst.suf || '') === 'String') ? 's' : ((vbType(objFirst.base || '', objFirst.suf || '') === 'Long') ? 'l' : 'i'));
				objHelpers[strTmp] = true;
				return strTmp + ' = ' + strP + ' : ' + strP + ' = ' + strQ + ' : ' + strQ + ' = ' + strTmp;
			case 'def':
				if (!isK('fn')) { warn('DEF'); }
				nx();
				defFn();
				return '';
			case 'cls': stream(); return 'Cls';
			case 'mode': return 'Mode ' + expr();
			case 'locate': stream(); var strLx = expr(); nx(); return 'Locate ' + strLx + ', ' + expr();
			case 'poke': var strPa = expr(); nx(); return 'Poke ' + strPa + ', ' + expr();
			case 'out': var strOa = expr(); nx(); return 'Out ' + strOa + ', ' + expr();
			case 'call':
				var strCa = expr();
				if (isO(',')) { warn('CALL with arguments'); }
				return 'Call ' + strCa;
			case 'randomize': return 'Randomize' + (stopper() ? '' : ' ' + expr());
			case 'frame': return 'Frame';
			case 'wait':
				var strWp = expr(); nx();
				var strWm = expr();
				var strWi = '0';
				if (isO(',')) { nx(); strWi = expr(); }
				objHelpers.wait = true;
				return 'loco_wait ' + strWp + ', ' + strWm + ', ' + strWi;
			case 'load':
				var strLf = expr();
				if (!isO(',')) { warn('LOAD of a program'); }
				nx();
				objHelpers.r = true;
				return 'loco_r = FileSystem.Load(' + strLf + ', ' + expr() + ', &H7FFF)';
			case 'save':
				var strSf = expr();
				if (!isO(',')) { warn('SAVE of a program'); }
				nx();
				var o2 = nx();
				if (!o2.base || o2.base !== 'b') { warn('SAVE (only ,b binary)'); }
				nx();
				var strSa = expr(); nx();
				var strSl = expr();
				objHelpers.r = true;
				return 'loco_r = FileSystem.Save(' + strSf + ', ' + strSa + ', ' + strSl + ')';
			case 'error': return 'Error ' + expr();
			case 'openin':
				objHelpers.fi = true;
				return 'loco_fi = FileSystem.Open(' + expr() + ', 1)';
			case 'openout':
				objHelpers.fo = true;
				return 'loco_fo = FileSystem.Open(' + expr() + ', 2)';
			case 'closein':
				objHelpers.fi = true;
				objHelpers.r = true;
				return 'loco_r = FileSystem.Close(loco_fi)';
			case 'closeout':
				objHelpers.fo = true;
				objHelpers.r = true;
				return 'loco_r = FileSystem.Close(loco_fo)';
		}
		warn(o.v.toUpperCase());
		return '';
	}
	// statements up to the end of the line (or ELSE, after a THEN)
	function statements(blnInIf_a)
	{
		var arrS = [];

		while (pk().t !== 'end' && pk().t !== 'rem')
		{
			if (isO(':')) { nx(); continue; }
			if (blnInIf_a && isK('else')) { break; }
			var strS = statement();
			if (strS) { arrS.push(strS); }
		}
		return arrS.join(' : ');
	}
	// DEF FN name[(a, b)] = expr -> a Function at the end of the module
	function defFn()
	{
		var o = nx();
		var arrP = [];
		var objSaved = null;

		if (o.t !== 'id') { warn('DEF FN without a name'); }
		if (isO('('))
		{
			nx();
			while (pk().t === 'id')
			{
				var objP = nx();
				arrP.push(objP);
				if (isO(',')) { nx(); }
			}
			if (isO(')')) { nx(); }
		}
		if (!isO('=')) { warn('DEF FN'); }
		nx();
		var strName = 'fn_' + vbName(o.base, o.suf, false);
		// the parameters are the function's own (they hide variables of the same name)
		objSaved = {};
		arrP.forEach(function(objP_a) { objSaved[objP_a.base] = objVars[objP_a.base]; objVars[objP_a.base] = {}; objVars[objP_a.base][objP_a.suf] = { scalar: true }; });
		var strBody = expr();
		arrP.forEach(function(objP_a) { if (objSaved[objP_a.base] === undefined) { delete objVars[objP_a.base]; } else { objVars[objP_a.base] = objSaved[objP_a.base]; } });
		arrBodyFn.push({ line: intSrcLine, text: 'Function ' + strName + '(' + arrP.map(function(p_a) { return 'ByVal ' + p_a.base.replace(/\./g, '_') + (p_a.suf === '$' ? '_s' : '') + ' As ' + (p_a.suf === '$' ? 'String' : 'Integer'); }).join(', ') + ') As ' + (o.suf === '$' ? 'String' : 'Integer') });
		arrBodyFn.push({ line: intSrcLine, text: strName + ' = ' + strBody });
		arrBodyFn.push({ line: intSrcLine, text: 'End Function' });
		objFn[strName] = true;
	}
	var arrBodyFn = [];

	// the line numbers something jumps to: only these stay in the VB text
	var objTargets = {};
	arrLineToks.forEach(function(objL_a)
	{
		var arrTk = objL_a.toks;
		for (var k = 0; k < arrTk.length; k++)
		{
			if (arrTk[k].t === 'kw' && /^(goto|gosub|then|else)$/.test(arrTk[k].v))
			{
				for (var j = k + 1; j < arrTk.length && arrTk[j].t === 'num'; j += 2)
				{
					objTargets[arrTk[j].v] = true;
					if (!(arrTk[j + 1] && arrTk[j + 1].t === 'op' && arrTk[j + 1].v === ',')) { break; }
				}
			}
		}
	});

	// ------------------------------------------------------------
	// pass 2: every line
	// ------------------------------------------------------------
	arrLineToks.forEach(function(objL_a, intI_a)
	{
		var strNum = ((objL_a.num !== null) && objTargets[String(objL_a.num)]) ? objL_a.num + ' ' : '';
		var strText = '';
		var intFnBefore = arrBodyFn.length;

		intSrcLine = intI_a + 1;
		arrT = objL_a.toks;
		intP = 0;
		strWarnThis = '';
		if (arrT.length && arrT[0].t === 'rem' && /^#\s*option\s+flavour/i.test(arrT[0].v)) { arrBody.push({ line: intSrcLine, text: strNum }); return; }
		try
		{
			strText = statements(false);
		}
		catch (e)
		{
			if (!e || !e.unsupported) { throw e; }
			arrBodyFn.length = intFnBefore;
			arrWarnings.push({ file: strFile, line: intSrcLine, msg: 'unsupported ' + e.unsupported + ' - the line is left out' });
			arrBody.push({ line: intSrcLine, text: strNum + "' WARNING: unsupported " + e.unsupported + ': ' + objL_a.src.replace(/^\d+\s*/, '') });
			return;
		}
		arrBody.push({ line: intSrcLine, text: (strNum + strText).replace(/\s+$/, '') });
	});

	// ------------------------------------------------------------
	// the top: Option VBPrint (the CPC's print spacing), the variables, the DATA table
	// ------------------------------------------------------------
	arrTop.push({ line: 1, text: 'Option VBPrint' });
	Object.keys(objVars).sort().forEach(function(strBase_a)
	{
		Object.keys(objVars[strBase_a]).forEach(function(strSuf_a)
		{
			var objV = objVars[strBase_a][strSuf_a];
			var strT = vbType(strBase_a, strSuf_a);

			if (strSuf_a === '!') { return; }
			if (objV.scalar) { arrTop.push({ line: objV.line, text: 'Dim ' + vbName(strBase_a, strSuf_a, false) + ' As ' + strT }); }
			if (objV.array)
			{
				var strDims = '10';
				if (objV.dims)
				{
					// a size made of numbers: declared here; one with a variable: ReDim at the DIM
					var arrSaveT = arrT;
					var intSaveP = intP;
					var arrD = objV.dims.map(function(arrTk_a) { arrT = arrTk_a; intP = 0; try { return expr(); } catch (e) { return '10'; } });
					arrT = arrSaveT;
					intP = intSaveP;
					if (arrD.every(function(s_a) { return /^[\d\s+\-*()&HX0-9A-F]+$/i.test(s_a); })) { strDims = arrD.join(', '); }
					else { objV.redim = true; strDims = ''; }
				}
				arrTop.push({ line: objV.dimline || objV.line, text: 'Dim ' + vbName(strBase_a, strSuf_a, true) + '(' + strDims + ') As ' + strT });
			}
		});
	});
	if (objHelpers.data || arrData.length)
	{
		arrTop.push({ line: 1, text: 'Dim loco_p As Integer' });
		arrTop.push({ line: 1, text: 'Dim loco_d(' + Math.max(0, arrData.length - 1) + ') As String' });
		arrData.forEach(function(objD_a, i_a)
		{
			arrTop.push({ line: arrDataLine(objD_a.line), text: 'loco_d(' + i_a + ') = "' + objD_a.text.replace(/"/g, '""') + '"' });
		});
	}
	function arrDataLine(intNum_a)
	{
		for (var i = 0; i < arrLineToks.length; i++) { if (arrLineToks[i].num === intNum_a) { return i + 1; } }
		return 1;
	}
	['loco_ti', 'loco_ts', 'loco_tl', 'r', 'fi', 'fo'].forEach(function(k_a)
	{
		if (objHelpers[k_a]) { arrTop.push({ line: 1, text: 'Dim ' + ((k_a.length < 3) ? 'loco_' + k_a : k_a) + ' As ' + ({ loco_ti: 'Integer', loco_ts: 'String', loco_tl: 'Long', r: 'Integer', fi: 'Integer', fo: 'Integer' })[k_a] }); }
	});

	// ------------------------------------------------------------
	// the end: End (so the program does not run into the functions), DEF FNs, helpers
	// ------------------------------------------------------------
	arrTail.push({ line: arrSrc.length, text: 'End' });
	arrTail = arrTail.concat(arrBodyFn);
	if (objHelpers.bin)
	{
		[
			'Function loco_bin(ByVal n As Integer, ByVal d As Integer) As String',
			'  Dim loco_bs As String', '  Dim loco_bi As Integer',
			'  loco_bs = ""', '  For loco_bi = 0 To 15', '    If n And 1 Then loco_bs = "1" & loco_bs Else loco_bs = "0" & loco_bs', '    n = (n \\ 2) And &H7FFF', '  Next',
			'  While Len(loco_bs) > 1 And Left$(loco_bs, 1) = "0" And Len(loco_bs) > d', '    loco_bs = Mid$(loco_bs, 2)', '  Wend',
			'  loco_bin = loco_bs', 'End Function'
		].forEach(function(s_a) { arrTail.push({ line: arrSrc.length, text: s_a }); });
	}
	if (objHelpers.wait)
	{
		[
			'Sub loco_wait(ByVal p As Integer, ByVal m As Integer, ByVal v As Integer)',
			'  While ((Inp(p) Xor v) And m) = 0', '  Wend', 'End Sub'
		].forEach(function(s_a) { arrTail.push({ line: arrSrc.length, text: s_a }); });
	}

	var arrAll = arrTop.concat(arrBody, arrTail);
	return {
		text: arrAll.map(function(o_a) { return o_a.text; }).join('\n'),
		lines: arrAll.map(function(o_a) { return o_a.line; }),
		cls: false,
		errors: arrErrors,
		warnings: arrWarnings
	};
}
