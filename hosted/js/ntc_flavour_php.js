// ============================================================
// NTC BASIC - the PHP flavour: a flavour preprocessor (ntcPrep, ntc_compiler.js)
// (c) 2026 Cyborg Unicorn Pty Ltd - MIT License
// ============================================================
// A PHP-shaped source turned into VB5 text for NTC's one parser and compiler, the same
// technique as the JS flavour (ntc_flavour_js.js): a PHP syntax over NTC, not a PHP engine.
// Every VB line remembers the PHP line it came from (lines), so messages name the PHP line.
// Everything NTC adds stays a PHP comment, so the file stays valid PHP:
//   //# Option ... / //# Turbo On / //# #If ...   a line of its own: an NTC line
//   $n = 0; //#long                               after code: a type hint
//   /* #asm ... */                                inline assembly
// PHP and JS differ in syntax, not in what NTC supports: $ on variables, "." joins text (not
// "+"), "->" and "::" reach members, the standard library is PHP's function names (strlen,
// substr, strtoupper ...). The features are the JS flavour's.
// Usage: ntcFlavourPhp({ name, text }, options) -> { text, lines, cls, classname, errors }
// ============================================================

function ntcFlavourPhp(objFile_a, objOptions_a)
{
	var strFile = objFile_a.name || 'main.php';
	var arrErrors = [];
	var arrOut = [];			// { line, text }
	var arrTok = [];
	var intPos = 0;
	var objTypes = {};			// lower case name -> 'Integer' / 'Long' / 'String' ... ('[]' on the end: an array)
	var objFuncs = {};			// lower case function name -> its result type ('' = a Sub)
	var objDeclared = null;		// names declared in the procedure being read (VB: one scope per procedure)
	var objModDeclared = {};	// and at the module's level
	var arrLoops = [];			// { kind: 'For' / 'While' / 'Select', cont: label or '' }
	var intLabel = 0;
	var blnClass = false;
	var strClassName = '';
	var strProcKind = '';		// 'Sub' / 'Function' while reading a procedure
	var strProcName = '';
	var intHead = -1;			// the procedure's first VB line (its type is set by what it returns)
	var blnRetHint = false;
	var PHP_TYPES = { 'int': 'Integer', 'integer': 'Integer', 'long': 'Long', 'byte': 'Byte', 'bool': 'Boolean', 'boolean': 'Boolean', 'string': 'String' };

	function error(intLine_a, strMsg_a)
	{
		arrErrors.push({ file: strFile, line: intLine_a, msg: strMsg_a });
	}
	function emit(intLine_a, strText_a)
	{
		arrOut.push({ line: intLine_a, text: strText_a });
	}

	// ------------------------------------------------------------
	// tokens: id (var: true for a $variable), num, str, tpl (a "..." with $var / {$expr}
	// parts), op, dir (//# line on its own), hint (//#type after code), asm (/* #asm */).
	// Comments (//, #, /* */) and the <?php / ?> tags are dropped
	// ------------------------------------------------------------
	function tokenise(strText_a)
	{
		var str = String(strText_a).replace(/\r\n?/g, '\n');
		var i = 0;
		var intLine = 1;
		var blnCode = false;		// something on this line before (a //# after it is a hint)
		var OPS = ['===', '!==', '**=', '<<=', '>>=', '<=>', '==', '!=', '<>', '<=', '>=', '=>', '&&', '||', '++', '--', '+=', '-=', '*=', '/=', '%=', '.=', '&=', '|=', '^=', '->', '::', '**', '<<', '>>',
			'+', '-', '*', '/', '%', '.', '=', '<', '>', '!', '~', '&', '|', '^', '?', ':', ';', ',', '(', ')', '[', ']', '{', '}', '@'];

		function push(strT_a, v_a, intL_a, blnVar_a)
		{
			arrTok.push({ t: strT_a, v: v_a, line: intL_a || intLine, var: blnVar_a || false });
			blnCode = true;
		}
		while (i < str.length)
		{
			var c = str.charAt(i);
			var m = null;

			if (c === '\n')
			{
				intLine++;
				blnCode = false;
				i++;
				continue;
			}
			if (/\s/.test(c))
			{
				i++;
				continue;
			}
			// the PHP open / close tags: skipped (a one-file program is all PHP)
			if (str.substr(i, 5).toLowerCase() === '<?php') { i += 5; continue; }
			if (str.substr(i, 3) === '<?=') { i += 3; continue; }
			if (str.substr(i, 2) === '<?') { i += 2; continue; }
			if (str.substr(i, 2) === '?>') { i += 2; continue; }
			if (str.substr(i, 2) === '//')
			{
				var intEnd = str.indexOf('\n', i);
				var strCom = str.substring(i + 2, (intEnd < 0) ? str.length : intEnd);

				if (strCom.charAt(0) === '#')
				{
					arrTok.push({ t: blnCode ? 'hint' : 'dir', v: strCom.substr(1).replace(/^\s+|\s+$/g, ''), line: intLine });
				}
				i = (intEnd < 0) ? str.length : intEnd;
				continue;
			}
			// a # line comment (PHP), but not #[ (an attribute - also dropped as a comment)
			if (c === '#')
			{
				var intEndH = str.indexOf('\n', i);
				i = (intEndH < 0) ? str.length : intEndH;
				continue;
			}
			if (str.substr(i, 2) === '/*')
			{
				var intClose = str.indexOf('*/', i + 2);
				var strBody = str.substring(i + 2, (intClose < 0) ? str.length : intClose);
				var intStart = intLine;

				if (intClose < 0)
				{
					error(intLine, 'a /* comment is not closed');
					intClose = str.length - 2;
				}
				if (/^\s*#asm\b/i.test(strBody))
				{
					var arrAsm = strBody.split('\n');
					arrTok.push({ t: 'asm', v: arrAsm.slice(1), line: intStart, endline: intStart + arrAsm.length - 1 });
					blnCode = true;
				}
				else if (/^#/.test(strBody) && (strBody.indexOf('\n') < 0))
				{
					arrTok.push({ t: 'hint', v: strBody.substr(1).replace(/^\s+|\s+$/g, ''), line: intLine });
				}
				intLine += strBody.split('\n').length - 1;
				i = intClose + 2;
				continue;
			}
			if ((m = str.substr(i).match(/^(0[xX][0-9a-fA-F]+|0[bB][01]+|0[oO][0-7]+|\d+)/)))
			{
				var strNum = m[1];

				if (/^0[xX]/.test(strNum)) { strNum = '&H' + strNum.substr(2).toUpperCase(); }
				else if (/^0[bB]/.test(strNum)) { strNum = '&X' + strNum.substr(2); }
				else if (/^0[oO]/.test(strNum)) { strNum = '&O' + strNum.substr(2); }
				push('num', strNum);
				i += m[1].length;
				if (str.charAt(i) === '.' && /\d/.test(str.charAt(i + 1)))
				{
					error(intLine, 'no floating point numbers in NTC');
					while (/[\d.]/.test(str.charAt(i))) { i++; }
				}
				continue;
			}
			// a $variable
			if (c === '$' && /[A-Za-z_]/.test(str.charAt(i + 1)))
			{
				m = str.substr(i + 1).match(/^[A-Za-z_]\w*/);
				push('id', m[0], intLine, true);
				i += 1 + m[0].length;
				continue;
			}
			// a bare name: a function, a constant, a class, a keyword
			if ((m = str.substr(i).match(/^[A-Za-z_]\w*/)))
			{
				push('id', m[0], intLine, false);
				i += m[0].length;
				continue;
			}
			if (c === '"')
			{
				tokeniseDouble(str, i);
				i = tokeniseDouble.end;
				continue;
			}
			if (c === "'")
			{
				var objStr = readSingle(str, i + 1);

				push('str', objStr.v);
				i = objStr.end;
				continue;
			}
			var blnOp = false;

			for (var k = 0; k < OPS.length; k++)
			{
				if (str.substr(i, OPS[k].length) === OPS[k])
				{
					push('op', OPS[k]);
					i += OPS[k].length;
					blnOp = true;
					break;
				}
			}
			if (!blnOp)
			{
				error(intLine, 'unexpected character: ' + c);
				i++;
			}
		}
		arrTok.push({ t: 'eof', v: '', line: intLine });

		// a double-quoted PHP string: $var and {$expr} interpolate (like a JS template), \n \t
		// \r \\ \" \$ escape. A plain one becomes a str token; one with parts becomes a tpl token
		function tokeniseDouble(strAll_a, intI_a)
		{
			var arrParts = [];
			var strLit = '';
			var j = intI_a + 1;
			var intTplLine = intLine;

			while ((j < strAll_a.length) && (strAll_a.charAt(j) !== '"'))
			{
				var ch = strAll_a.charAt(j);

				if (ch === '\\')
				{
					strLit += unescapeD(strAll_a.charAt(j + 1));
					j += 2;
					continue;
				}
				if (ch === '{' && strAll_a.charAt(j + 1) === '$')
				{
					var intDepth = 1;
					var q = j + 1;

					while ((q < strAll_a.length) && (intDepth > 0))
					{
						if (strAll_a.charAt(q) === '{') { intDepth++; }
						if (strAll_a.charAt(q) === '}') { intDepth--; }
						q++;
					}
					arrParts.push({ s: strLit });
					strLit = '';
					arrParts.push({ e: strAll_a.substring(j + 1, q - 1) });		// {$a->b} -> $a->b
					j = q;
					continue;
				}
				if (ch === '$' && /[A-Za-z_]/.test(strAll_a.charAt(j + 1)))
				{
					var mm = strAll_a.substr(j).match(/^\$[A-Za-z_]\w*(?:\[[^\]]*\]|->[A-Za-z_]\w*)*/);

					arrParts.push({ s: strLit });
					strLit = '';
					arrParts.push({ e: mm[0] });
					j += mm[0].length;
					continue;
				}
				if (ch === '\n') { intLine++; }
				strLit += ch;
				j++;
			}
			tokeniseDouble.end = j + 1;
			if (arrParts.length === 0)
			{
				push('str', strLit, intTplLine);
				return;
			}
			arrParts.push({ s: strLit });
			push('tpl', arrParts, intTplLine);
		}
	}
	function unescapeD(c_a)
	{
		return { 'n': '\n', 't': '\t', 'r': '\r', '0': '\0', '"': '"', '\\': '\\', '$': '$' }[c_a] || ('\\' + c_a);
	}
	// a single-quoted PHP string: only \\ and \' escape, everything else literal
	function readSingle(str_a, i_a)
	{
		var strV = '';
		var i = i_a;

		while ((i < str_a.length) && (str_a.charAt(i) !== "'"))
		{
			if (str_a.charAt(i) === '\\' && (str_a.charAt(i + 1) === "'" || str_a.charAt(i + 1) === '\\'))
			{
				strV += str_a.charAt(i + 1);
				i += 2;
				continue;
			}
			strV += str_a.charAt(i);
			i++;
		}
		return { v: strV, end: i + 1 };
	}

	// ------------------------------------------------------------
	// token helpers
	// ------------------------------------------------------------
	function peek(intAhead_a) { return arrTok[Math.min(intPos + (intAhead_a || 0), arrTok.length - 1)]; }
	function next() { var o = arrTok[intPos]; if (intPos < arrTok.length - 1) { intPos++; } return o; }
	function isOp(strV_a, intAhead_a) { var o = peek(intAhead_a); return (o.t === 'op') && (o.v === strV_a); }
	function isKw(strV_a, intAhead_a) { var o = peek(intAhead_a); return (o.t === 'id') && !o.var && (o.v.toLowerCase() === strV_a); }
	function isVar(intAhead_a) { var o = peek(intAhead_a); return (o.t === 'id') && o.var; }
	function expectOp(strV_a)
	{
		if (isOp(strV_a)) { return next(); }
		error(peek().line, 'expected ' + strV_a + (peek().t === 'eof' ? ' (the file ended)' : ' before ' + String(peek().v)));
		return peek();
	}
	// a refused form: skip its ( ) { } [ ] and up to ; so one message is enough
	function skipRefused()
	{
		var intDepth = 0;

		for (;;)
		{
			var o = next();

			if (o.t === 'eof') { return; }
			if (o.t === 'op' && (o.v === '(' || o.v === '{' || o.v === '[')) { intDepth++; }
			if (o.t === 'op' && (o.v === ')' || o.v === '}' || o.v === ']'))
			{
				intDepth--;
				if (intDepth <= 0 && o.v === '}' && !(isKw('catch') || isKw('finally') || isKw('while'))) { if (isOp(';')) { next(); } return; }
			}
			if (intDepth <= 0 && o.t === 'op' && o.v === ';') { return; }
		}
	}
	function semi()
	{
		if (isOp(';')) { next(); }
	}
	function takeHint(intLine_a)
	{
		if ((peek().t === 'hint') && (peek().line === intLine_a)) { return next().v; }
		return '';
	}
	function hintType(strHint_a, intLine_a)
	{
		var strH = String(strHint_a).toLowerCase().replace(/\s+/g, ' ');
		var m = null;

		if (strH === '') { return ''; }
		if ((m = strH.match(/^string\s*\*\s*(\d+)$/))) { return 'String * ' + m[1]; }
		if ((m = strH.match(/^stringmax\s*(\d+)$/))) { return 'String Max ' + m[1]; }
		if (PHP_TYPES[strH] !== undefined) { return PHP_TYPES[strH]; }
		if (strH === 'byref') { return ''; }
		error(intLine_a, 'unknown type hint: //#' + strHint_a);
		return '';
	}

	// ------------------------------------------------------------
	// expressions -> VB5 expression text { s: text, t: 'n' / 's' (number / string) }
	// fully bracketed, so VB's precedence never matters
	// ------------------------------------------------------------
	function vbStr(str_a)
	{
		var arrParts = [];
		var strCur = '';
		var i = 0;

		for (i = 0; i < str_a.length; i++)
		{
			var intC = str_a.charCodeAt(i);

			if ((intC < 32) || (intC > 126))
			{
				if (strCur.length > 0 || arrParts.length === 0) { arrParts.push('"' + strCur + '"'); }
				strCur = '';
				arrParts.push('Chr$(' + intC + ')');
				continue;
			}
			strCur += (str_a.charAt(i) === '"') ? '""' : str_a.charAt(i);
		}
		if ((strCur.length > 0) || (arrParts.length === 0)) { arrParts.push('"' + strCur + '"'); }
		arrParts = arrParts.filter(function(s_a) { return !((s_a === '""') && (arrParts.length > 1)); });
		return arrParts.join(' & ');
	}
	function typeOfName(strName_a)
	{
		return objTypes[String(strName_a).toLowerCase()] || '';
	}
	function isStrType(strT_a)
	{
		return /^String/.test(String(strT_a));
	}
	function parseExpr()
	{
		return parseTernary();
	}
	function parseTernary()
	{
		var objC = parseBinary(0);

		if (isOp('?'))
		{
			next();
			var objA = parseExpr();
			expectOp(':');
			var objB = parseExpr();

			return { s: 'IIf(' + objC.s + ', ' + objA.s + ', ' + objB.s + ')', t: (objA.t === 's' || objB.t === 's') ? 's' : 'n' };
		}
		return objC;
	}
	// binary operators by precedence (low to high). "." joins text (VB &); word operators
	// and / or / xor sit with && / || as logic
	var BIN = [
		[['||', 'Or'], ['or', 'Or'], ['xor', 'Xor']],
		[['&&', 'And'], ['and', 'And']],
		[['|', 'Or']],
		[['^', 'Xor']],
		[['&', 'And']],
		[['===', '='], ['!==', '<>'], ['==', '='], ['!=', '<>'], ['<>', '<>'], ['<', '<'], ['<=', '<='], ['>', '>'], ['>=', '>=']],
		[['<<', '<<'], ['>>', '>>']],
		[['+', '+'], ['-', '-'], ['.', '&']],
		[['*', '*'], ['/', '\\'], ['%', 'Mod']]
	];
	function matchBin(intLevel_a)
	{
		var arr = BIN[intLevel_a];
		var o = peek();

		for (var k = 0; k < arr.length; k++)
		{
			if (o.t === 'op' && o.v === arr[k][0]) { return arr[k]; }
			if (o.t === 'id' && !o.var && o.v.toLowerCase() === arr[k][0]) { return arr[k]; }
		}
		return null;
	}
	function parseBinary(intLevel_a)
	{
		if (intLevel_a >= BIN.length) { return parseUnary(); }
		var objL = parseBinary(intLevel_a + 1);

		for (;;)
		{
			var objOp = matchBin(intLevel_a);

			if (objOp === null) { break; }
			next();
			var objR = parseBinary(intLevel_a + 1);
			var strVb = objOp[1];

			// << >> only with a constant count: x * 2^n / x \ 2^n
			if (strVb === '<<' || strVb === '>>')
			{
				if (!/^(&H[0-9A-F]+|&X[01]+|&O[0-7]+|\d+)$/i.test(objR.s)) { error(peek().line, (objOp[0]) + ' needs a constant count'); }
				var intN = parseInt(objR.s.replace(/^&H/i, '').replace(/^&X/i, '2#not#'), 16);
				if (/^&X/i.test(objR.s)) { intN = parseInt(objR.s.substr(2), 2); }
				else if (/^&O/i.test(objR.s)) { intN = parseInt(objR.s.substr(2), 8); }
				else if (/^\d+$/.test(objR.s)) { intN = parseInt(objR.s, 10); }
				objL = { s: '(' + objL.s + (strVb === '<<' ? ' * ' : ' \\ ') + Math.pow(2, intN) + ')', t: 'n' };
				continue;
			}
			if (objOp[0] === '.')		// text join
			{
				objL = { s: '(' + objL.s + ' & ' + objR.s + ')', t: 's' };
				continue;
			}
			var strT = (strVb === '&' || ((objOp[0] === '+') && (objL.t === 's' || objR.t === 's'))) ? 's' : 'n';

			if ((objOp[0] === '+') && (objL.t === 's' || objR.t === 's')) { strVb = '&'; }
			objL = { s: '(' + objL.s + ' ' + strVb + ' ' + objR.s + ')', t: strT };
		}
		return objL;
	}
	function parseUnary()
	{
		if (isOp('!'))
		{
			next();
			return { s: '(Not ' + parseUnary().s + ')', t: 'n' };
		}
		if (isKw('not'))
		{
			next();
			return { s: '(Not ' + parseUnary().s + ')', t: 'n' };
		}
		if (isOp('-'))
		{
			next();
			return { s: '(-' + parseUnary().s + ')', t: 'n' };
		}
		if (isOp('+'))
		{
			next();
			return parseUnary();
		}
		if (isOp('~'))
		{
			next();
			return { s: '(Not ' + parseUnary().s + ')', t: 'n' };
		}
		if (isOp('@'))		// PHP error suppression: ignored
		{
			next();
			return parseUnary();
		}
		return parsePower();
	}
	function parsePower()
	{
		var objL = parsePostfix();

		if (isOp('**'))
		{
			next();
			var objR = parseUnary();

			return { s: '(' + objL.s + ' ^ ' + objR.s + ')', t: 'n' };
		}
		return objL;
	}
	function parseArgs()
	{
		var arrA = [];

		expectOp('(');
		while (!isOp(')') && peek().t !== 'eof')
		{
			arrA.push(parseExpr());
			if (isOp(',')) { next(); continue; }
			break;
		}
		expectOp(')');
		return arrA;
	}
	function parsePrimary()
	{
		var o = peek();

		if (o.t === 'num') { next(); return { s: o.v, t: 'n' }; }
		if (o.t === 'str') { next(); return { s: vbStr(o.v), t: 's' }; }
		if (o.t === 'tpl')
		{
			next();
			var arrS = o.v.map(function(objP_a)
			{
				if (objP_a.s !== undefined) { return (objP_a.s === '') ? null : vbStr(objP_a.s); }
				return subExpr(objP_a.e.replace(/^\$/, ''), o.line).s;
			}).filter(function(s_a) { return s_a !== null; });
			return { s: '(' + (arrS.length ? arrS.join(' & ') : '""') + ')', t: 's' };
		}
		if (isOp('['))		// an array literal [a, b, c] - becomes a bracketed list (handled by the caller)
		{
			return parseArrayLiteral();
		}
		if (isOp('('))
		{
			next();
			var objE = parseExpr();
			expectOp(')');
			return { s: '(' + objE.s + ')', t: objE.t };
		}
		if (o.t === 'id')
		{
			if (!o.var)
			{
				var strLow = o.v.toLowerCase();

				if (strLow === 'true') { next(); return { s: 'True', t: 'n' }; }
				if (strLow === 'false') { next(); return { s: 'False', t: 'n' }; }
				if (strLow === 'null') { next(); return { s: '0', t: 'n' }; }
				if (strLow === 'function' || strLow === 'fn') { error(o.line, 'functions as values (closures) are not in the NTC PHP flavour'); next(); skipRefused(); return { s: '0', t: 'n' }; }
			}
			if (o.var && o.v.toLowerCase() === 'this') { next(); return { s: 'Me', t: 'n', me: true }; }
			next();
			return { s: o.v, t: isStrType(typeOfName(o.v)) ? 's' : 'n', name: o.v };
		}
		error(o.line, 'not a value: ' + String(o.v));
		next();
		return { s: '0', t: 'n' };
	}
	function parseArrayLiteral()
	{
		// [a, b, c] as an array constant is not a VB value; used only as a start for a declared
		// array (handled in the declaration). Here: flag it
		var arrEls = [];

		next();		// [
		while (!isOp(']') && peek().t !== 'eof')
		{
			arrEls.push(parseExpr());
			if (isOp(',')) { next(); continue; }
			break;
		}
		expectOp(']');
		return { s: '0', t: 'n', arrayLit: arrEls };
	}
	function subExpr(strText_a, intLine_a)
	{
		var arrSaved = arrTok;
		var intSaved = intPos;
		var objR = null;

		arrTok = [];
		tokenise('<?php ' + strText_a + ';');
		arrTok.forEach(function(o_a) { o_a.line = intLine_a; });
		intPos = 0;
		objR = parseExpr();
		arrTok = arrSaved;
		intPos = intSaved;
		return objR;
	}
	// PHP built in functions -> VB text. @0.. are the arguments, @* all of them
	function builtin(strName_a, arrA_a, intLine_a)
	{
		var A = arrA_a.map(function(o_a) { return o_a.s; });
		var strLow = String(strName_a).toLowerCase();
		function a(k) { return (A[k] !== undefined) ? A[k] : '0'; }
		var MAP = {
			// strings (PHP is 0 based: substr / strpos get + 1 for VB's 1 based Mid$ / InStr)
			'strlen': ['Len(@0)', 'n'], 'strtoupper': ['UCase$(@0)', 's'], 'strtolower': ['LCase$(@0)', 's'],
			'trim': ['Trim$(@0)', 's'], 'ltrim': ['LTrim$(@0)', 's'], 'rtrim': ['RTrim$(@0)', 's'], 'chop': ['RTrim$(@0)', 's'],
			'chr': ['Chr$(@0)', 's'], 'ord': ['Asc(@0)', 'n'], 'strrev': ['StrReverse(@0)', 's'],
			'str_repeat': ['String$(@1, @0)', 's'], 'strcmp': ['StrComp(@0, @1)', 'n'],
			'dechex': ['Hex$(@0)', 's'], 'decoct': ['Oct$(@0)', 's'], 'hexdec': ['Val("&H" & @0)', 'n'], 'octdec': ['Val("&O" & @0)', 'n'],
			'intval': ['Val(@0)', 'n'], 'strval': ['CStr(@0)', 's'], 'boolval': ['CBool(@0)', 'n'],
			// maths
			'abs': ['Abs(@0)', 'n'], 'sqrt': ['Sqr(@0)', 'n'], 'pow': ['(@0 ^ @1)', 'n'],
			'floor': ['@0', 'n'], 'ceil': ['@0', 'n'], 'round': ['@0', 'n'], 'intdiv': ['(@0 \\ @1)', 'n'],
			'min': ['IIf(@0 < @1, @0, @1)', 'n'], 'max': ['IIf(@0 > @1, @0, @1)', 'n'],
			'rand': ['Rnd(@0)', 'n'], 'mt_rand': ['Rnd(@0)', 'n'], 'random_int': ['Rnd(@0)', 'n'],
			// machine
			'peek': ['Peek(@0)', 'n'], 'deek': ['Deek(@0)', 'n'], 'inp': ['Inp(@0)', 'n'],
			'inkey': ['Inkey', 'n'], 'inkey_str': ['Inkey$', 's'], 'ticks': ['Ticks', 'n'], 'timer': ['Timer', 'n'],
			'call_addr': ['CallAddr(@*)', 'n']
		};
		// substr / strpos / str_replace / str_pad / number helpers: built by hand (base / arg order)
		if (strLow === 'substr') { return { s: 'Mid$(' + a(0) + ', ' + a(1) + ' + 1' + (A.length > 2 ? ', ' + a(2) : '') + ')', t: 's' }; }
		if (strLow === 'strpos') { return { s: '(InStr(' + a(0) + ', ' + a(1) + ') - 1)', t: 'n' }; }
		if (strLow === 'strrpos') { return { s: '(InStrRev(' + a(0) + ', ' + a(1) + ') - 1)', t: 'n' }; }
		if (strLow === 'str_replace') { return { s: 'Replace(' + a(2) + ', ' + a(0) + ', ' + a(1) + ')', t: 's' }; }
		if (strLow === 'substr_count') { return { s: '((Len(' + a(0) + ') - Len(Replace(' + a(0) + ', ' + a(1) + ', ""))) \\ Len(' + a(1) + '))', t: 'n' }; }
		if (strLow === 'str_pad')
		{
			// str_pad(s, len [, pad [, type]]): default right pad (STR_PAD_RIGHT)
			var strType = (A[3] || '').toUpperCase();
			if (/LEFT/.test(strType) || A[3] === '0') { return { s: 'Right$(Space$(' + a(1) + ') & ' + a(0) + ', ' + a(1) + ')', t: 's' }; }
			return { s: 'Left$(' + a(0) + ' & Space$(' + a(1) + '), ' + a(1) + ')', t: 's' };
		}
		if (strLow === 'count' || strLow === 'sizeof') { return { s: '(UBound(' + a(0) + ') + 1)', t: 'n' }; }
		if (strLow === 'explode') { return { s: 'Split(' + a(1) + ', ' + a(0) + ')', t: 'n' }; }		// explode(sep, s) -> Split(s, sep)
		if (strLow === 'implode' || strLow === 'join') { return { s: 'Join(' + a(1) + ', ' + a(0) + ')', t: 's' }; }
		var objM = MAP[strLow];

		if (objM === undefined) { return null; }
		return { s: objM[0].replace(/@\*/g, A.join(', ')).replace(/@(\d)/g, function(s_a, d_a) { return (A[d_a] !== undefined) ? A[d_a] : '0'; }), t: objM[1] };
	}
	function parsePostfix()
	{
		var objE = null;

		// array(a, b, c): a fixed array with those start values (like [a, b, c])
		if ((peek().t === 'id') && !peek().var && peek().v.toLowerCase() === 'array' && isOp('(', 1))
		{
			next();
			var arrEls = parseArgs();

			return { s: '0', t: 'n', arrayLit: arrEls };
		}
		// array_fill(0, n, v): n elements (0 .. n - 1), all v
		if ((peek().t === 'id') && !peek().var && peek().v.toLowerCase() === 'array_fill' && isOp('(', 1))
		{
			next();
			var arrFa = parseArgs();

			return { s: '0', t: 'n', arrayFill: { n: (arrFa[1] ? arrFa[1].s : '0'), v: (arrFa[2] ? arrFa[2].s : '0'), vt: (arrFa[2] ? arrFa[2].t : 'n') } };
		}
		// a user function call or a PHP built in: name(...) - but not the reserved function / fn (closures)
		if ((peek().t === 'id') && !peek().var && isOp('(', 1) && (objFuncs[peek().v.toLowerCase()] === undefined) &&
			(peek().v.toLowerCase() !== 'function') && (peek().v.toLowerCase() !== 'fn'))
		{
			var strName = peek().v;
			var intL = peek().line;

			intPos++;
			var arrArgs = parseArgs();
			var objBi = builtin(strName, arrArgs, intL);
			if (objBi !== null) { return objBi; }
			objE = { s: strName + '(' + arrArgs.map(function(o_a) { return o_a.s; }).join(', ') + ')', t: 'n', name: strName };
		}
		else
		{
			objE = parsePrimary();
		}
		for (;;)
		{
			if (isOp('['))
			{
				var arrIdx = [];

				while (isOp('['))
				{
					next();
					if (isOp(']')) { error(peek().line, 'an empty [] (append) is not in the NTC PHP flavour'); }
					else { arrIdx.push(parseExpr().s); while (isOp(',')) { next(); arrIdx.push(parseExpr().s); } }
					expectOp(']');
				}
				objE = { s: objE.s + '(' + arrIdx.join(', ') + ')', t: (objE.name && isStrType(typeOfName(objE.name).replace(/\[\]$/, ''))) ? 's' : 'n', elem: true };
				continue;
			}
			if (isOp('->') || isOp('::'))
			{
				next();
				var strM = next().v;
				var blnCall = isOp('(');
				var arrA = blnCall ? parseArgs() : [];

				if (objE.me)
				{
					objE = { s: 'Me.' + strM + (blnCall ? '(' + arrA.map(function(o_a) { return o_a.s; }).join(', ') + ')' : ''), t: isStrType(typeOfName(strM)) ? 's' : 'n', name: strM };
					continue;
				}
				objE = { s: objE.s + '.' + strM + (blnCall ? '(' + arrA.map(function(o_a) { return o_a.s; }).join(', ') + ')' : ''), t: 'n' };
				continue;
			}
			if (isOp('(') && objE.name && (objFuncs[objE.name.toLowerCase()] !== undefined))
			{
				var arrFa = parseArgs();

				objE = { s: objE.s + '(' + arrFa.map(function(o_a) { return o_a.s; }).join(', ') + ')', t: isStrType(objFuncs[objE.name.toLowerCase()]) ? 's' : 'n' };
				continue;
			}
			break;
		}
		return objE;
	}

	// ------------------------------------------------------------
	// statements -> VB5 lines
	// ------------------------------------------------------------
	function declare(strName_a, strType_a, intLine_a, strDims_a, strScope_a)
	{
		var strKey = strName_a.toLowerCase();
		var objScope = (objDeclared !== null) ? objDeclared : objModDeclared;

		if (objScope[strKey] !== undefined)
		{
			if (objScope[strKey] !== strType_a + (strDims_a || '')) { error(intLine_a, strName_a + ' is used again with another type (one variable per name in a function, or in the module)'); }
			return;
		}
		objScope[strKey] = strType_a + (strDims_a || '');
		objTypes[strKey] = strType_a + (strDims_a !== undefined ? '[]' : '');
		emit(intLine_a, (strScope_a || 'Dim') + ' ' + strName_a + (strDims_a !== undefined ? '(' + strDims_a + ')' : '') + ' As ' + strType_a);
	}
	function block()
	{
		if (isOp('{'))
		{
			next();
			while (!isOp('}') && (peek().t !== 'eof')) { statement(); }
			expectOp('}');
			return;
		}
		// a single statement (PHP allows no braces: if ($x) foo();)
		statement();
	}
	function statementIf()
	{
		var intLine = next().line;

		expectOp('(');
		var objC = parseExpr();
		expectOp(')');
		emit(intLine, 'If ' + objC.s + ' Then');
		block();
		while (isKw('elseif') || isKw('else'))
		{
			var intEl = peek().line;

			if (isKw('elseif'))
			{
				next();
				expectOp('(');
				var objC2 = parseExpr();
				expectOp(')');
				emit(intEl, 'ElseIf ' + objC2.s + ' Then');
				block();
				continue;
			}
			next();		// else
			if (isKw('if'))
			{
				next();
				expectOp('(');
				var objC3 = parseExpr();
				expectOp(')');
				emit(intEl, 'ElseIf ' + objC3.s + ' Then');
				block();
				continue;
			}
			emit(intEl, 'Else');
			block();
			break;
		}
		emit(peek(-1).line, 'End If');
	}
	function statementWhile()
	{
		var intLine = next().line;
		var objLoop = { kind: 'While', cont: '' };

		expectOp('(');
		var objC = parseExpr();
		expectOp(')');
		emit(intLine, 'While ' + objC.s);
		arrLoops.push(objLoop);
		block();
		arrLoops.pop();
		if (objLoop.cont) { emit(peek(-1).line, objLoop.cont + ':'); }
		emit(peek(-1).line, 'Wend');
	}
	function statementForeach()
	{
		var intLine = next().line;
		var objLoop = { kind: 'For', cont: '' };

		expectOp('(');
		var objArr = parseExpr();
		if (!isKw('as')) { error(peek().line, 'foreach (... as $v)'); } else { next(); }
		var strKey = '';
		var objV = next();
		var strVal = objV.v;

		if (isOp('=>'))		// foreach ($a as $k => $v)
		{
			next();
			strKey = strVal;
			strVal = next().v;
		}
		expectOp(')');
		var strIx = 'phpfe' + (++intLabel);

		if (objTypes[strIx.toLowerCase()] === undefined) { declare(strIx, 'Integer', intLine); }
		if (objTypes[strVal.toLowerCase()] === undefined) { declare(strVal, isStrType(typeOfName(objArr.name || '').replace(/\[\]$/, '')) ? 'String' : 'Integer', intLine); }
		if (strKey && objTypes[strKey.toLowerCase()] === undefined) { declare(strKey, 'Integer', intLine); }
		emit(intLine, 'For ' + strIx + ' = 0 To UBound(' + objArr.s + ')');
		if (strKey) { emit(intLine, strKey + ' = ' + strIx); }
		emit(intLine, strVal + ' = ' + objArr.s + '(' + strIx + ')');
		arrLoops.push(objLoop);
		block();
		arrLoops.pop();
		if (objLoop.cont) { emit(peek(-1).line, objLoop.cont + ':'); }
		emit(peek(-1).line, 'Next');
	}
	// a simple statement without its ; (assignment, ++, a call) as VB text
	function simpleText(blnIsFor_a)
	{
		var intLine = peek().line;

		if (isOp('++') || isOp('--'))
		{
			var strPre = next().v;
			var objT = parsePostfix();
			return { text: objT.s + ' = ' + objT.s + (strPre === '++' ? ' + 1' : ' - 1'), name: objT.s, inc: (strPre === '++') ? '1' : '-1' };
		}
		var objL = parsePostfix();

		if (isOp('++') || isOp('--'))
		{
			var strPost = next().v;
			return { text: objL.s + ' = ' + objL.s + (strPost === '++' ? ' + 1' : ' - 1'), name: objL.s, inc: (strPost === '++') ? '1' : '-1' };
		}
		var ASSIGN = { '=': '', '+=': '+', '-=': '-', '*=': '*', '/=': '\\', '%=': 'Mod', '.=': '&', '&=': 'And', '|=': 'Or', '^=': 'Xor', '**=': '^' };

		if ((peek().t === 'op') && (ASSIGN[peek().v] !== undefined))
		{
			var strOp = next().v;

			// new X(): an object (only as a plain assignment, not in a for)
			if (strOp === '=' && isKw('new'))
			{
				return { text: '', assignNew: objL.s, newInfo: readNew() };
			}
			var objR = parseExpr();
			var strVb = ASSIGN[strOp];

			if ((strOp === '+=') && (objL.t === 's' || objR.t === 's')) { strVb = '&'; }
			// an array( ) / [ ] / array_fill( ) assigned: handled by the caller (declaration)
			if (strOp === '=' && objR.arrayLit) { return { text: '', assignArrLit: objL, arrLit: objR.arrayLit }; }
			if (strOp === '=' && objR.arrayFill) { return { text: '', assignArrFill: objL, arrFill: objR.arrayFill }; }
			return { text: objL.s + ' = ' + (strVb ? '(' + objL.s + ' ' + strVb + ' ' + objR.s + ')' : objR.s), name: objL.s,
				type: objR.t, inc: (strOp === '+=') ? objR.s : ((strOp === '-=') ? '-' + objR.s : '') };
		}
		if (/\)$/.test(objL.s)) { return { text: 'Call ' + objL.s }; }
		error(intLine, 'not a statement: ' + objL.s);
		return { text: '' };
	}
	function readNew()
	{
		next();		// new
		var strCls = next().v;
		var arrNa = (isOp('(')) ? parseArgs() : [];

		return { cls: strCls, args: arrNa };
	}
	function statementFor()
	{
		var intLine = next().line;
		var objLoop = { kind: 'For', cont: '' };
		var intSave = 0;

		expectOp('(');
		intSave = intPos;
		var objCount = (function()
		{
			if (!isVar()) { return null; }
			var strI = next().v;
			if (!isOp('=')) { return null; }
			next();
			var objA = parseExpr();
			if (!isOp(';')) { return null; }
			next();
			if (!isVar() || peek().v.toLowerCase() !== strI.toLowerCase()) { return null; }
			next();
			var strCmp = peek().v;
			if (!/^(<|<=|>|>=)$/.test(strCmp) || peek().t !== 'op') { return null; }
			next();
			var objB = parseExpr();
			if (!isOp(';')) { return null; }
			next();
			if (!isVar() && !(isOp('++') || isOp('--'))) { return null; }
			var objStep = simpleText(true);
			if (!isOp(')') || !objStep.inc || objStep.name.toLowerCase() !== strI.toLowerCase()) { return null; }
			next();
			return { i: strI, a: objA.s, b: objB.s, cmp: strCmp, step: objStep.inc };
		})();
		if (objCount !== null)
		{
			var blnUp = !/^-/.test(objCount.step);
			var strTo = objCount.b;

			if ((objCount.cmp === '<') || (objCount.cmp === '>'))
			{
				strTo = /^\d+$/.test(strTo) ? String(parseInt(strTo, 10) + (objCount.cmp === '<' ? -1 : 1)) : '(' + strTo + (objCount.cmp === '<' ? ' - 1)' : ' + 1)');
			}
			if (blnUp !== /^</.test(objCount.cmp))
			{
				error(intLine, 'this for counts the wrong way for its test (it would never end, or never run)');
			}
			if (objTypes[objCount.i.toLowerCase()] === undefined) { declare(objCount.i, 'Integer', intLine); }
			emit(intLine, 'For ' + objCount.i + ' = ' + objCount.a + ' To ' + strTo + ((objCount.step === '1') ? '' : ' Step ' + objCount.step));
			arrLoops.push(objLoop);
			block();
			arrLoops.pop();
			if (objLoop.cont) { emit(peek(-1).line, objLoop.cont + ':'); }
			emit(peek(-1).line, 'Next');
			return;
		}
		intPos = intSave;
		var objInit = isOp(';') ? null : simpleStmtForInit();

		expectOp(';');
		var objCond = isOp(';') ? { s: 'True' } : parseExpr();

		expectOp(';');
		var objStep2 = isOp(')') ? null : simpleText(false);

		expectOp(')');
		if (objInit !== null && objInit.text) { emit(intLine, objInit.text); }
		emit(intLine, 'While ' + objCond.s);
		objLoop.kind = 'While';
		arrLoops.push(objLoop);
		block();
		arrLoops.pop();
		if (objLoop.cont) { emit(peek(-1).line, objLoop.cont + ':'); }
		if (objStep2 !== null && objStep2.text) { emit(peek(-1).line, objStep2.text); }
		emit(peek(-1).line, 'Wend');
	}
	function simpleStmtForInit()
	{
		var intLine = peek().line;
		var objS = simpleText(false);

		if (objS.name && objTypes[objS.name.toLowerCase()] === undefined && /^[A-Za-z_]\w*$/.test(objS.name))
		{
			declare(objS.name, objS.type === 's' ? 'String' : 'Integer', intLine);
		}
		return objS;
	}
	function statementSwitch()
	{
		var intLine = next().line;

		expectOp('(');
		var objX = parseExpr();
		expectOp(')');
		expectOp('{');
		emit(intLine, 'Select Case ' + objX.s);
		arrLoops.push({ kind: 'Select', cont: '' });
		while (!isOp('}') && peek().t !== 'eof')
		{
			var arrCase = [];
			var intCl = peek().line;
			var blnDefault = false;

			while (isKw('case') || isKw('default'))
			{
				if (next().v.toLowerCase() === 'default') { blnDefault = true; } else { arrCase.push(parseExpr().s); }
				if (isOp(':') || isOp(';')) { next(); }
			}
			if (!arrCase.length && !blnDefault) { error(peek().line, 'expected case or default'); next(); continue; }
			emit(intCl, blnDefault ? 'Case Else' : 'Case ' + arrCase.join(', '));
			var blnEnded = false;

			while (!isKw('case') && !isKw('default') && !isOp('}') && peek().t !== 'eof')
			{
				if (isKw('break')) { next(); semi(); blnEnded = true; continue; }
				if (blnEnded) { error(peek().line, 'code after break in a case is never run'); }
				if (isKw('return')) { blnEnded = true; }
				statement();
			}
			if (!blnEnded && !blnDefault) { error(intCl, 'each case ends with break (no falling into the next case)'); }
		}
		arrLoops.pop();
		expectOp('}');
		emit(peek(-1).line, 'End Select');
	}
	function loopFor(strWhat_a, intLine_a)
	{
		for (var i = arrLoops.length - 1; i >= 0; i--)
		{
			if (arrLoops[i].kind !== 'Select' || strWhat_a === 'break') { return arrLoops[i]; }
		}
		error(intLine_a, strWhat_a + ' outside a loop');
		return null;
	}
	function statement()
	{
		var o = peek();

		if (o.t === 'eof') { return; }
		if (o.t === 'dir') { next(); directive(o); return; }
		if (o.t === 'asm') { next(); asmBlock(o); return; }
		if (o.t === 'hint') { next(); error(o.line, '//#' + o.v + ' here has nothing to give a type to'); return; }
		if (o.t === 'op' && o.v === ';') { next(); return; }
		if (o.t === 'op' && o.v === '{') { block(); return; }
		if (o.t === 'id' && !o.var)
		{
			switch (o.v.toLowerCase())
			{
				case 'if': statementIf(); return;
				case 'while': statementWhile(); return;
				case 'for': statementFor(); return;
				case 'foreach': statementForeach(); return;
				case 'switch': statementSwitch(); return;
				case 'do': error(o.line, 'do ... while is not in the NTC PHP flavour (use while)'); skipRefused(); return;
				case 'try': case 'throw': case 'namespace': case 'use': case 'trait': case 'interface': case 'abstract': case 'final':
					if (o.v.toLowerCase() === 'class' || o.v.toLowerCase() === 'interface' || o.v.toLowerCase() === 'trait') { error(o.line, 'a class goes in a file of its own'); }
					else { error(o.line, o.v + ((o.v.toLowerCase() === 'try') ? ' / catch' : '') + ' is not in the NTC PHP flavour'); }
					skipRefused();
					return;
				case 'class': error(o.line, 'a class goes in a file of its own'); skipRefused(); return;
				case 'function': if (strProcKind) { error(o.line, 'a function inside a function is not in the NTC PHP flavour'); } func(''); return;
				case 'public': case 'private': case 'protected':
					next();
					if (isKw('function')) { func('Public'); } else { error(o.line, 'public / private here: on a function or a class member'); skipRefused(); }
					return;
				case 'const': statementConst(); return;
				case 'echo': case 'print': statementEcho(o.v.toLowerCase()); return;
				case 'global': case 'static': next(); while (isVar()) { next(); if (isOp(',')) { next(); } } semi(); return;
				case 'break':
					next(); semi();
					var objLb = loopFor('break', o.line);
					if (objLb !== null) { emit(o.line, 'Exit ' + objLb.kind); }
					return;
				case 'continue':
					next(); semi();
					var objLc = loopFor('continue', o.line);
					if (objLc !== null)
					{
						if (!objLc.cont) { objLc.cont = 'phpc' + (++intLabel); }
						emit(o.line, 'GoTo ' + objLc.cont);
					}
					return;
				case 'return':
					next();
					if (!strProcKind) { error(o.line, 'return outside a function'); semi(); return; }
					if (!isOp(';') && !isOp('}') && peek().line === o.line)
					{
						var objR = parseExpr();
						if ((objR.t === 's') && !blnRetHint && (intHead >= 0))
						{
							arrOut[intHead].text = arrOut[intHead].text.replace(/ As Integer$/, ' As String');
							objFuncs[strProcName.toLowerCase()] = 'String';
						}
						emit(o.line, strProcName + ' = ' + objR.s);
					}
					semi();
					emit(o.line, 'Exit ' + strProcKind);
					return;
				case 'exit': case 'die': next(); if (isOp('(')) { parseArgs(); } semi(); emit(o.line, 'End'); return;
				case 'unset': next(); if (isOp('(')) { parseArgs(); } semi(); return;
			}
			// cls() / locate() / mode() ... as statements
			if (statementBuiltin()) { return; }
		}
		// an assignment or a call (a $variable or a member starts it)
		var intLine = o.line;
		var objS = simpleText(false);

		semi();
		takeHint(intLine);
		if (objS.assignNew !== undefined) { assignNew(objS, intLine); return; }
		if (objS.arrLit !== undefined) { assignArrayLit(objS, intLine); return; }
		if (objS.arrFill !== undefined) { assignArrayFill(objS, intLine); return; }
		if (objS.name && objTypes[objS.name.toLowerCase()] === undefined && /^[A-Za-z_]\w*$/.test(objS.name))
		{
			var strHint = hintType(takeHint(intLine), intLine);

			declare(objS.name, strHint || (objS.type === 's' ? 'String' : 'Integer'), intLine);
		}
		if (objS.text) { emit(intLine, objS.text); }
	}
	function assignNew(objS_a, intLine_a)
	{
		var strName = objS_a.assignNew;
		var objNew = objS_a.newInfo;

		if (objNew.args.length > 0) { error(intLine_a, 'new ' + objNew.cls + '(...): no constructors - call a method to set it up'); }
		objTypes[strName.toLowerCase()] = 'object';
		objModDeclared[strName.toLowerCase()] = 'object';
		if (objDeclared !== null) { objDeclared[strName.toLowerCase()] = 'object'; }
		emit(intLine_a, 'Dim ' + strName + ' As New ' + objNew.cls);
	}
	function assignArrayLit(objS_a, intLine_a)
	{
		var strName = objS_a.assignArrLit.s;
		var arrLit = objS_a.arrLit;

		if (objTypes[strName.toLowerCase()] === undefined)
		{
			var strT = (arrLit.length && arrLit[0].t === 's') ? 'String' : 'Integer';
			declare(strName, strT, intLine_a, String(Math.max(0, arrLit.length - 1)));
		}
		arrLit.forEach(function(objE_a, intI_a) { emit(intLine_a, strName + '(' + intI_a + ') = ' + objE_a.s); });
	}
	function assignArrayFill(objS_a, intLine_a)
	{
		var strName = objS_a.assignArrFill.s;
		var objF = objS_a.arrFill;
		var strN = /^\d+$/.test(objF.n) ? String(parseInt(objF.n, 10) - 1) : '(' + objF.n + ' - 1)';

		if (objTypes[strName.toLowerCase()] === undefined)
		{
			declare(strName, objF.vt === 's' ? 'String' : 'Integer', intLine_a, strN);
		}
		if (objF.v !== '0' && objF.v !== '""')
		{
			var strIx = 'phpfill' + (++intLabel);

			if (objTypes[strIx.toLowerCase()] === undefined) { declare(strIx, 'Integer', intLine_a); }
			emit(intLine_a, 'For ' + strIx + ' = 0 To ' + strN);
			emit(intLine_a, strName + '(' + strIx + ') = ' + objF.v);
			emit(intLine_a, 'Next');
		}
	}
	function statementConst()
	{
		next();		// const
		var intLine = peek().line;

		for (;;)
		{
			var strN = next().v;

			expectOp('=');
			var objV = parseExpr();

			objTypes[strN.toLowerCase()] = (objV.t === 's') ? 'String' : 'Integer';
			emit(intLine, 'Const ' + strN + ' = ' + objV.s);
			if (isOp(',')) { next(); continue; }
			break;
		}
		semi();
	}
	function statementEcho(strKw_a)
	{
		var intLine = next().line;
		var arrA = [];

		if (isOp('(')) { arrA = parseArgs(); }
		else
		{
			arrA.push(parseExpr());
			while (isOp(',')) { next(); arrA.push(parseExpr()); }
		}
		semi();
		emit(intLine, 'Print ' + arrA.map(function(o_a) { return o_a.s; }).join('; ') + ';');
	}
	function statementBuiltin()
	{
		var o = peek();
		var strName = o.v.toLowerCase();
		var STMT = {
			'cls': 'Cls', 'locate': 'Locate', 'mode': 'Mode', 'poke': 'Poke', 'doke': 'Doke', 'out': 'Out', 'beep': 'Beep', 'frame': 'Frame',
			'randomize': 'Randomize', 'tab': 'Tab', 'do_events': 'DoEvents', 'interrupt': 'Interrupt'
		};

		if ((STMT[strName] === undefined) || !isOp('(', 1) || (objFuncs[strName] !== undefined)) { return false; }
		next();
		var arrA = parseArgs();
		semi();
		var arrS = arrA.map(function(x_a) { return x_a.s; });

		emit(o.line, STMT[strName] + (arrS.length ? ' ' + arrS.join(', ') : ''));
		return true;
	}
	function directive(o_a)
	{
		if (/^Option\s+Flavour\b/i.test(o_a.v)) { return; }
		emit(o_a.line, o_a.v);
	}
	function asmBlock(o_a)
	{
		emit(o_a.line, '#asm');
		o_a.v.forEach(function(s_a, i_a) { emit(o_a.line + 1 + i_a, s_a.replace(/\s+$/, '')); });
		emit(o_a.endline, '#endasm');
	}
	// function name($a, $b = 5) { ... } //#long     (visibility handled by the caller)
	function func(strScope_a)
	{
		var intLine = next().line;		// function
		var objName = next();
		var arrP = [];
		var intDepth = 0;
		var blnValue = false;
		var strRet = '';

		if (objName.t !== 'id') { error(intLine, 'a function needs a name'); return; }
		expectOp('(');
		while (!isOp(')') && peek().t !== 'eof')
		{
			// an optional type word before the parameter (int $x, string $s): skipped
			if (peek().t === 'id' && !peek().var && !isVar(0)) { if (peek(1).t === 'id' && peek(1).var) { next(); } }
			var objP = next();
			var strDef = '';
			var strPH = '';

			if (objP.t !== 'id') { error(objP.line, 'a parameter name'); break; }
			if (isOp('=')) { next(); strDef = parseExpr().s; }
			if (peek().t === 'hint') { strPH = next().v; }
			arrP.push({ name: objP.v, def: strDef, hint: strPH, line: objP.line });
			if (isOp(',')) { next(); continue; }
			break;
		}
		expectOp(')');
		// a : type return declaration (PHP 7): skipped; a //#type hint wins
		if (isOp(':')) { next(); if (peek().t === 'id') { next(); } }
		if (peek().t === 'hint') { strRet = hintType(next().v, intLine); }
		if (!isOp('{')) { error(peek().line, 'a function body { } after its parameters'); return; }
		for (var i = intPos; i < arrTok.length; i++)
		{
			if (arrTok[i].t === 'op' && arrTok[i].v === '{') { intDepth++; }
			if (arrTok[i].t === 'op' && arrTok[i].v === '}') { intDepth--; if (intDepth === 0) { break; } }
			if (arrTok[i].t === 'id' && !arrTok[i].var && arrTok[i].v.toLowerCase() === 'return' && !(arrTok[i + 1].t === 'op' && (arrTok[i + 1].v === ';' || arrTok[i + 1].v === '}')) && arrTok[i + 1].line === arrTok[i].line) { blnValue = true; }
		}
		if (peek(1).t === 'hint' && peek(1).line === intLine) { strRet = hintType(arrTok[intPos + 1].v, intLine); arrTok.splice(intPos + 1, 1); }
		strProcKind = blnValue ? 'Function' : 'Sub';
		strProcName = objName.v;
		if (blnValue) { objFuncs[objName.v.toLowerCase()] = strRet || 'Integer'; } else { objFuncs[objName.v.toLowerCase()] = ''; }
		var objSavedTypes = {};
		var k;
		for (k in objTypes) { if (objTypes.hasOwnProperty(k)) { objSavedTypes[k] = objTypes[k]; } }
		// a parameter used as text in the body (joined with ., passed to a string function) is a String
		var objPStr = {};
		var intD2 = 0;
		var STR_FUNCS = { strlen: 1, strtoupper: 1, strtolower: 1, trim: 1, ltrim: 1, rtrim: 1, chop: 1, ord: 1, strrev: 1, str_repeat: 1, substr: 1, strpos: 1, strrpos: 1, str_pad: 1, substr_count: 1, strval: 1, ucfirst: 1, lcfirst: 1, explode: 1 };

		for (var q = intPos; q < arrTok.length; q++)
		{
			var oq = arrTok[q];

			if (oq.t === 'op' && oq.v === '{') { intD2++; }
			if (oq.t === 'op' && oq.v === '}') { intD2--; if (intD2 === 0) { break; } }
			if (oq.t !== 'id' || !oq.var) { continue; }
			var oN = arrTok[q + 1];
			var oP = arrTok[q - 1];
			var oP2 = arrTok[q - 2];

			if ((oN.t === 'op' && oN.v === '.') || (oP.t === 'op' && oP.v === '.') ||
				(oN.t === 'op' && oN.v === '.=') || (oP.t === 'op' && oP.v === '=' && oP2 && oP2.t === 'str') ||
				(oP.t === 'op' && oP.v === '(' && oP2 && oP2.t === 'id' && !oP2.var && STR_FUNCS[oP2.v.toLowerCase()]))
			{
				objPStr[oq.v.toLowerCase()] = true;
			}
		}
		var arrPv = arrP.map(function(objP_a)
		{
			var strT = hintType(objP_a.hint, objP_a.line) || (objPStr[objP_a.name.toLowerCase()] ? 'String' : 'Integer');
			var blnRef = /^byref$/i.test(objP_a.hint);

			if (objP_a.def && /^"/.test(objP_a.def) && !objP_a.hint) { strT = 'String'; }
			objTypes[objP_a.name.toLowerCase()] = strT;
			return (objP_a.def ? 'Optional ' : '') + (blnRef ? 'ByRef ' : 'ByVal ') + objP_a.name + ' As ' + strT + (objP_a.def ? ' = ' + objP_a.def : '');
		});
		intHead = arrOut.length;
		blnRetHint = (strRet !== '');
		emit(intLine, (strScope_a ? strScope_a + ' ' : '') + strProcKind + ' ' + objName.v + '(' + arrPv.join(', ') + ')' + (blnValue ? ' As ' + (strRet || 'Integer') : ''));
		objDeclared = {};
		arrP.forEach(function(objP_a) { objDeclared[objP_a.name.toLowerCase()] = objTypes[objP_a.name.toLowerCase()]; });
		block();
		emit(peek(-1).line, 'End ' + strProcKind);
		objDeclared = null;
		strProcKind = '';
		strProcName = '';
		intHead = -1;
		objTypes = objSavedTypes;
	}

	// ------------------------------------------------------------
	// a class: class Name { public $f = 0; private $g; public function m() {} private function n() {} const C = 1; }
	// ------------------------------------------------------------
	function classFile()
	{
		var intLine = next().line;		// class
		var objName = next();

		strClassName = objName.v;
		emit(intLine, 'Attribute VB_Name = "' + strClassName + '"');
		if (isKw('extends') || isKw('implements')) { error(peek().line, 'extends / implements: no inheritance in NTC'); next(); next(); }
		expectOp('{');
		while (!isOp('}') && peek().t !== 'eof')
		{
			var o = peek();
			var blnPriv = false;

			if (o.t === 'dir') { next(); directive(o); continue; }
			if (o.t === 'asm') { next(); asmBlock(o); continue; }
			if (isOp(';')) { next(); continue; }
			// visibility + modifiers
			while (isKw('public') || isKw('private') || isKw('protected') || isKw('static') || isKw('final') || isKw('abstract') || isKw('var') || isKw('readonly'))
			{
				if (isKw('private') || isKw('protected')) { blnPriv = true; }
				next();
			}
			if (isKw('const'))
			{
				next();
				var strCN = next().v;

				expectOp('=');
				var objCV = parseExpr();
				objTypes[strCN.toLowerCase()] = (objCV.t === 's') ? 'String' : 'Integer';
				emit(o.line, (blnPriv ? 'Private ' : 'Public ') + 'Const ' + strCN + ' = ' + objCV.s);
				semi();
				continue;
			}
			if (isKw('function'))
			{
				func(blnPriv ? 'Private' : 'Public');
				continue;
			}
			// a property: public $name [= value];  (an optional type word may precede $name)
			if (peek().t === 'id' && !peek().var && peek(1).t === 'id' && peek(1).var) { next(); }		// a type word
			var objM = next();

			if (objM.t !== 'id' || !objM.var) { error(objM.line, 'a $property, a function, or a const'); if (!isOp('}')) { next(); } continue; }
			var objInit = null;

			if (isOp('=')) { next(); objInit = parseExpr(); }
			semi();
			var strHT = hintType(takeHint(objM.line), objM.line);
			var strT = strHT || ((objInit !== null && objInit.t === 's') ? 'String' : 'Integer');

			if (objInit !== null && !/^(0|""|False|\(-?0\))$/.test(objInit.s))
			{
				error(objM.line, 'a property starts at 0 / "" in NTC (no start values in a class yet): set it in a method');
			}
			objTypes[objM.v.toLowerCase()] = strT;
			emit(objM.line, (blnPriv ? 'Private ' : 'Public ') + objM.v + ' As ' + strT);
		}
		expectOp('}');
	}

	// ------------------------------------------------------------
	// the file
	// ------------------------------------------------------------
	tokenise(objFile_a.text);
	(function()
	{
		var arrTop = arrTok.filter(function(o_a) { return o_a.t !== 'dir' && o_a.t !== 'eof'; });
		var intI = 0;

		// skip leading visibility / abstract / final before "class"
		while (arrTop[intI] && arrTop[intI].t === 'id' && !arrTop[intI].var && /^(abstract|final)$/i.test(arrTop[intI].v)) { intI++; }
		blnClass = (arrTop.length > intI) && (arrTop[intI].t === 'id') && !arrTop[intI].var && (arrTop[intI].v.toLowerCase() === 'class');
	})();
	// functions defined anywhere can be called before their definition
	for (var t = 0; t < arrTok.length - 1; t++)
	{
		if (arrTok[t].t === 'id' && !arrTok[t].var && arrTok[t].v.toLowerCase() === 'function' && arrTok[t + 1].t === 'id' && !arrTok[t + 1].var)
		{
			objFuncs[arrTok[t + 1].v.toLowerCase()] = '?';
		}
	}
	while (peek().t !== 'eof')
	{
		if (blnClass && (isKw('class') || isKw('abstract') || isKw('final')))
		{
			if (isKw('abstract') || isKw('final')) { next(); continue; }
			classFile();
			continue;
		}
		if (blnClass && peek().t !== 'dir' && peek().t !== 'asm') { error(peek().line, 'a class file holds the class only'); next(); continue; }
		statement();
	}

	return {
		text: arrOut.map(function(o_a) { return o_a.text; }).join('\n'),
		lines: arrOut.map(function(o_a) { return o_a.line; }),
		cls: blnClass,
		classname: strClassName,
		errors: arrErrors
	};
}
