// ============================================================
// NTC BASIC - the JS flavour: a flavour preprocessor (ntcPrep, ntc_compiler.js)
// (c) 2026 Cyborg Unicorn Pty Ltd - MIT License
// ============================================================
// A JS-shaped source (ES5 / ES6 subset) turned into VB5 text for NTC's one parser and
// compiler, the way JSCC does it: a JS syntax over NTC, not a JavaScript engine. Every VB
// line remembers the JS line it came from (arrLines), so messages name the JS line.
// Everything NTC adds stays a JS comment, so the file stays valid JS:
//   //# Option ... / //# Turbo On / //# #If ...   a line of its own: an NTC line
//   let n = 0; //#long                            after code: a type hint
//   /* #asm ... */                                inline assembly
// Usage: ntcFlavourJs({ name, text }, options) -> { text, lines: [js line per VB line],
//        cls: true for a class file, classname, errors: [{ file, line, msg }] }
// ============================================================

function ntcFlavourJs(objFile_a, objOptions_a)
{
	var strFile = objFile_a.name || 'main.js';
	var arrErrors = [];
	var arrOut = [];			// { line, text }
	var arrTok = [];
	var intPos = 0;
	var objTypes = {};			// lower case name -> 'Integer' / 'Long' / 'String' ... ('[]' on the end: an array)
	var objFuncs = {};			// lower case function name -> its result type ('' = a Sub)
	var objDeclared = null;		// names declared in the procedure being read (VB has one scope per procedure)
	var objModDeclared = {};	// and at the module's level
	var arrLoops = [];			// { kind: 'For' / 'While', cont: label or '' }
	var intLabel = 0;
	var blnClass = false;
	var strClassName = '';
	var strProcKind = '';		// 'Sub' / 'Function' while reading a procedure
	var strProcName = '';
	var intHead = -1;			// the procedure's first VB line (its type is set by what it returns)
	var blnRetHint = false;
	var JS_TYPES = { 'int': 'Integer', 'integer': 'Integer', 'long': 'Long', 'byte': 'Byte', 'bool': 'Boolean', 'boolean': 'Boolean', 'string': 'String' };

	function error(intLine_a, strMsg_a)
	{
		arrErrors.push({ file: strFile, line: intLine_a, msg: strMsg_a });
	}
	function emit(intLine_a, strText_a)
	{
		arrOut.push({ line: intLine_a, text: strText_a });
	}

	// ------------------------------------------------------------
	// tokens: id, num, str, tpl (template: parts), op, dir (//# line), hint (//#type after
	// code), asm (/* #asm */ block). Comments are dropped
	// ------------------------------------------------------------
	function tokenise(strText_a)
	{
		var str = String(strText_a).replace(/\r\n?/g, '\n');
		var i = 0;
		var intLine = 1;
		var blnCode = false;		// something on this line before (a //# after it is a hint)
		var OPS = ['===', '!==', '**=', '<<=', '>>=', '=>', '==', '!=', '<=', '>=', '&&', '||', '++', '--', '+=', '-=', '*=', '/=', '%=', '&=', '|=', '^=', '**', '<<', '>>',
			'+', '-', '*', '/', '%', '=', '<', '>', '!', '~', '&', '|', '^', '?', ':', ';', ',', '.', '(', ')', '[', ']', '{', '}', '#'];

		function push(strT_a, v_a, intL_a)
		{
			arrTok.push({ t: strT_a, v: v_a, line: intL_a || intLine });
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
			if (str.substr(i, 2) === '//')
			{
				var intEnd = str.indexOf('\n', i);
				var strCom = str.substring(i + 2, (intEnd < 0) ? str.length : intEnd);

				if (strCom.charAt(0) === '#')
				{
					if (blnCode)
					{
						arrTok.push({ t: 'hint', v: strCom.substr(1).replace(/^\s+|\s+$/g, ''), line: intLine });
					}
					else
					{
						arrTok.push({ t: 'dir', v: strCom.substr(1).replace(/^\s+|\s+$/g, ''), line: intLine });
					}
				}
				i = (intEnd < 0) ? str.length : intEnd;
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
					// /* #asm ... */: the lines after "#asm" up to the line with */
					var arrAsm = strBody.split('\n');
					arrTok.push({ t: 'asm', v: arrAsm.slice(1), line: intStart, endline: intStart + arrAsm.length - 1 });
					blnCode = true;
				}
				else if (/^#/.test(strBody) && (strBody.indexOf('\n') < 0))
				{
					arrTok.push({ t: 'hint', v: strBody.substr(1).replace(/^\s+|\s+$/g, ''), line: intLine });		// /*#long*/ after a parameter
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
			if ((m = str.substr(i).match(/^[A-Za-z_$][\w$]*/)))
			{
				push('id', m[0]);
				i += m[0].length;
				continue;
			}
			if ((c === '"') || (c === "'"))
			{
				var objStr = readString(str, i + 1, c);

				push('str', objStr.v);
				i = objStr.end;
				continue;
			}
			if (c === '`')
			{
				// template text: parts, every ${expr} kept as its own token list
				var arrParts = [];
				var strLit = '';
				var intTplLine = intLine;

				i++;
				while ((i < str.length) && (str.charAt(i) !== '`'))
				{
					if (str.substr(i, 2) === '${')
					{
						var intDepth = 1;
						var j = i + 2;

						while ((j < str.length) && (intDepth > 0))
						{
							if (str.charAt(j) === '{') { intDepth++; }
							if (str.charAt(j) === '}') { intDepth--; }
							j++;
						}
						arrParts.push({ s: strLit });
						strLit = '';
						arrParts.push({ e: str.substring(i + 2, j - 1) });
						i = j;
						continue;
					}
					if (str.charAt(i) === '\\')
					{
						strLit += unescape1(str.charAt(i + 1));
						i += 2;
						continue;
					}
					if (str.charAt(i) === '\n') { intLine++; }
					strLit += str.charAt(i);
					i++;
				}
				arrParts.push({ s: strLit });
				push('tpl', arrParts, intTplLine);
				i++;
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
	}
	function unescape1(c_a)
	{
		return { 'n': '\n', 't': '\t', 'r': '\r', '0': '\0' }[c_a] || c_a;
	}
	function readString(str_a, i_a, strQ_a)
	{
		var strV = '';
		var i = i_a;

		while ((i < str_a.length) && (str_a.charAt(i) !== strQ_a) && (str_a.charAt(i) !== '\n'))
		{
			if (str_a.charAt(i) === '\\')
			{
				strV += unescape1(str_a.charAt(i + 1));
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
	function isId(strV_a, intAhead_a) { var o = peek(intAhead_a); return (o.t === 'id') && (o.v === strV_a); }
	function expectOp(strV_a)
	{
		if (isOp(strV_a)) { return next(); }
		error(peek().line, 'expected ' + strV_a + (peek().t === 'eof' ? ' (the file ended)' : ' before ' + String(peek().v)));
		return peek();
	}
	// a refused form: skip it (its ( ) and { } and up to ; ) so one message is enough
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
				if (intDepth <= 0 && o.v === '}' && !(isId('catch') || isId('finally') || isId('while'))) { if (isOp(';')) { next(); } return; }
			}
			if (intDepth <= 0 && o.t === 'op' && o.v === ';') { return; }
		}
	}
	function semi()
	{
		if (isOp(';')) { next(); }
	}
	// a //#type hint on the line just read (after ; or straight after the code)
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
		if (JS_TYPES[strH] !== undefined) { return JS_TYPES[strH]; }
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
		// a JS string as VB text: quotes doubled, control characters as Chr$()
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
		arrParts = arrParts.filter(function(s_a, i_a) { return !((s_a === '""') && (arrParts.length > 1)); });
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
		var objE = parseTernary();

		if (isOp('=>'))
		{
			error(peek().line, 'arrow functions are not in the NTC JS flavour');
			skipRefused();
		}
		return objE;
	}
	function parseTernary()
	{
		var objC = parseBinary(0);

		if (isOp('?'))
		{
			next();
			var objA = parseTernary();
			expectOp(':');
			var objB = parseTernary();
			return { s: 'IIf(' + objC.s + ', ' + objA.s + ', ' + objB.s + ')', t: (objA.t === 's' || objB.t === 's') ? 's' : 'n' };
		}
		return objC;
	}
	var BIN = [
		{ '||': 'Or' }, { '&&': 'And' }, { '|': 'Or' }, { '^': 'Xor' }, { '&': 'And' },
		{ '==': '=', '===': '=', '!=': '<>', '!==': '<>' }, { '<': '<', '<=': '<=', '>': '>', '>=': '>=' },
		{ '<<': '<<', '>>': '>>' }, { '+': '+', '-': '-' }, { '*': '*', '/': '/', '%': 'Mod' }
	];
	function parseBinary(intLevel_a)
	{
		if (intLevel_a >= BIN.length) { return parsePower(); }
		var objL = parseBinary(intLevel_a + 1);

		while ((peek().t === 'op') && (BIN[intLevel_a][peek().v] !== undefined))
		{
			var strOp = next().v;
			var objR = parseBinary(intLevel_a + 1);
			var strVb = BIN[intLevel_a][strOp];

			if ((strOp === '<<') || (strOp === '>>'))
			{
				if (!/^\d+$/.test(objR.s)) { error(peek().line, strOp + ' needs a number after it (a constant shift)'); }
				objL = { s: '(' + objL.s + ((strOp === '<<') ? ' * ' : ' \\ ') + Math.pow(2, parseInt(objR.s, 10) || 0) + ')', t: 'n' };
				continue;
			}
			if ((strOp === '+') && ((objL.t === 's') || (objR.t === 's')))
			{
				strVb = '&';		// text on either side: joined
			}
			objL = { s: '(' + objL.s + ' ' + strVb + ' ' + objR.s + ')', t: (strVb === '&') ? 's' : 'n' };
		}
		return objL;
	}
	function parsePower()
	{
		var objL = parseUnary();

		if (isOp('**'))
		{
			next();
			var objR = parsePower();
			return { s: '(' + objL.s + ' ^ ' + objR.s + ')', t: 'n' };
		}
		return objL;
	}
	function parseUnary()
	{
		if (isOp('!') || isOp('~'))
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
		if (isId('typeof') || isId('delete') || isId('void'))
		{
			error(peek().line, next().v + ' is not in the NTC JS flavour');
			return parseUnary();
		}
		return parsePostfix();
	}
	function parseArgs()
	{
		var arrArgs = [];

		expectOp('(');
		while (!isOp(')') && (peek().t !== 'eof'))
		{
			arrArgs.push(parseExpr());
			if (isOp(',')) { next(); } else { break; }
		}
		expectOp(')');
		return arrArgs;
	}
	function parsePrimary()
	{
		var o = next();

		if (o.t === 'num') { return { s: o.v, t: 'n' }; }
		if (o.t === 'str') { return { s: vbStr(o.v), t: 's' }; }
		if (o.t === 'tpl')
		{
			var arrS = [];

			o.v.forEach(function(objP_a)
			{
				if (objP_a.s !== undefined)
				{
					if (objP_a.s.length > 0) { arrS.push(vbStr(objP_a.s)); }
				}
				else
				{
					arrS.push('(' + subExpr(objP_a.e, o.line).s + ')');
				}
			});
			return { s: '(' + (arrS.length ? arrS.join(' & ') : '""') + ')', t: 's' };
		}
		if (o.t === 'op' && o.v === '(')
		{
			var objE = parseExpr();
			expectOp(')');
			return { s: '(' + objE.s + ')', t: objE.t };
		}
		if (o.t === 'op' && o.v === '[')
		{
			error(o.line, 'array literals: use new Array(n)');
			while (!isOp(']') && peek().t !== 'eof') { next(); }
			next();
			return { s: '0', t: 'n' };
		}
		if (o.t === 'id')
		{
			if (o.v === 'true') { return { s: 'True', t: 'n' }; }
			if (o.v === 'false') { return { s: 'False', t: 'n' }; }
			if ((o.v === 'null') || (o.v === 'undefined')) { error(o.line, o.v + ' is not in the NTC JS flavour'); return { s: '0', t: 'n' }; }
			if (o.v === 'this') { return { s: 'Me', t: 'n', me: true }; }
			if ((o.v === 'function') || (o.v === 'new')) { error(o.line, (o.v === 'new') ? 'new: only as  let x = new ClassName();' : 'functions as values (closures) are not in the NTC JS flavour'); return { s: '0', t: 'n' }; }
			return { s: o.v, t: isStrType(typeOfName(o.v)) ? 's' : 'n', name: o.v };
		}
		error(o.line, 'unexpected ' + (o.t === 'eof' ? 'end of the file' : String(o.v)));
		return { s: '0', t: 'n' };
	}
	// an expression held as text (inside a template's ${ }): read with its own tokens
	function subExpr(strText_a, intLine_a)
	{
		var arrSaved = arrTok;
		var intSaved = intPos;
		var objR = null;

		arrTok = [];
		tokenise(strText_a);
		arrTok.forEach(function(o_a) { o_a.line = intLine_a; });
		intPos = 0;
		objR = parseExpr();
		arrTok = arrSaved;
		intPos = intSaved;
		return objR;
	}
	// built in calls: JS name -> VB text
	function builtin(strName_a, arrA_a, intLine_a)
	{
		var A = arrA_a.map(function(o_a) { return o_a.s; });
		var MAP = {
			'Math.abs': ['Abs(@0)', 'n'], 'Math.sqrt': ['Sqr(@0)', 'n'], 'Math.sign': ['Sgn(@0)', 'n'], 'Math.floor': ['@0', 'n'], 'Math.trunc': ['@0', 'n'],
			'Math.round': ['@0', 'n'], 'Math.ceil': ['@0', 'n'], 'Math.min': ['IIf(@0 < @1, @0, @1)', 'n'], 'Math.max': ['IIf(@0 > @1, @0, @1)', 'n'], 'Math.pow': ['(@0 ^ @1)', 'n'],
			'String.fromCharCode': ['Chr$(@0)', 's'], 'String': ['CStr(@0)', 's'], 'parseInt': ['Val(@0)', 'n'], 'Number': ['Val(@0)', 'n'], 'Boolean': ['CBool(@0)', 'n'],
			'random': ['Rnd(@0)', 'n'], 'peek': ['Peek(@0)', 'n'], 'deek': ['Deek(@0)', 'n'], 'inp': ['Inp(@0)', 'n'], 'inkey': ['Inkey', 'n'], 'inkeyStr': ['Inkey$', 's'],
			'ticks': ['Ticks', 'n'], 'timer': ['Timer', 'n'], 'call': ['CallAddr(@*)', 'n']
		};
		var objM = MAP[strName_a];

		if (objM === undefined) { return null; }
		return { s: objM[0].replace(/@\*/g, A.join(', ')).replace(/@(\d)/g, function(s_a, d_a) { return (A[d_a] !== undefined) ? A[d_a] : '0'; }), t: objM[1] };
	}
	// methods on a value: s.length, s.toUpperCase() ...
	function method(objObj_a, strM_a, arrA_a, blnCall_a, intLine_a)
	{
		var o = objObj_a.s;
		var A = arrA_a.map(function(x_a) { return x_a.s; });
		var blnArr = objObj_a.name && /\[\]$/.test(typeOfName(objObj_a.name));

		if (!blnCall_a && (strM_a === 'length'))
		{
			return blnArr ? { s: '(UBound(' + o + ') + 1)', t: 'n' } : { s: 'Len(' + o + ')', t: 'n' };
		}
		if (!blnCall_a) { return null; }
		switch (strM_a)
		{
			case 'toUpperCase': return { s: 'UCase$(' + o + ')', t: 's' };
			case 'toLowerCase': return { s: 'LCase$(' + o + ')', t: 's' };
			case 'trim': return { s: 'Trim$(' + o + ')', t: 's' };
			case 'trimStart': return { s: 'LTrim$(' + o + ')', t: 's' };
			case 'trimEnd': return { s: 'RTrim$(' + o + ')', t: 's' };
			case 'charCodeAt': return { s: (A.length && A[0] !== '0') ? 'Asc(Mid$(' + o + ', ' + A[0] + ' + 1, 1))' : 'Asc(' + o + ')', t: 'n' };
			case 'charAt': return { s: 'Mid$(' + o + ', ' + (A[0] || '0') + ' + 1, 1)', t: 's' };
			case 'substr': return { s: 'Mid$(' + o + ', ' + (A[0] || '0') + ' + 1' + (A.length > 1 ? ', ' + A[1] : '') + ')', t: 's' };
			case 'substring': return { s: 'Mid$(' + o + ', ' + (A[0] || '0') + ' + 1' + (A.length > 1 ? ', ' + A[1] + ' - ' + A[0] : '') + ')', t: 's' };
			case 'slice':
				if (A.length === 1 && /^\(-\d+\)$/.test(A[0])) { return { s: 'Right$(' + o + ', ' + A[0].replace(/[()\-]/g, '') + ')', t: 's' }; }
				return { s: 'Mid$(' + o + ', ' + (A[0] || '0') + ' + 1' + (A.length > 1 ? ', ' + A[1] + ' - ' + A[0] : '') + ')', t: 's' };
			case 'indexOf': return { s: '(InStr(' + o + ', ' + A[0] + ') - 1)', t: 'n' };
			case 'lastIndexOf': return { s: '(InStrRev(' + o + ', ' + A[0] + ') - 1)', t: 'n' };
			case 'repeat': return { s: (o === '" "') ? 'Space$(' + A[0] + ')' : 'String$(' + A[0] + ', ' + o + ')', t: 's' };
			case 'replace': case 'replaceAll': return { s: 'Replace(' + o + ', ' + A[0] + ', ' + A[1] + ')', t: 's' };
			case 'padStart': return { s: 'Right$(Space$(' + A[0] + ') & ' + o + ', ' + A[0] + ')', t: 's' };
			case 'padEnd': return { s: 'Left$(' + o + ' & Space$(' + A[0] + '), ' + A[0] + ')', t: 's' };
			case 'toString':
				if (A.length && A[0] === '16') { return { s: 'Hex$(' + o + ')', t: 's' }; }
				if (A.length && A[0] === '8') { return { s: 'Oct$(' + o + ')', t: 's' }; }
				return { s: 'CStr(' + o + ')', t: 's' };
		}
		return null;
	}
	function parsePostfix()
	{
		var objE = null;
		var strDotted = '';

		// Math.floor(Math.random() * n) -> Rnd(n)
		if (isId('Math') && isOp('.', 1) && isId('floor', 2) && isOp('(', 3) && isId('Math', 4) && isOp('.', 5) && isId('random', 6) && isOp('(', 7) && isOp(')', 8) && isOp('*', 9))
		{
			intPos += 10;
			var objN = parseUnary();
			expectOp(')');
			return { s: 'Rnd(' + objN.s + ')', t: 'n' };
		}
		// a dotted built in name (Math.abs, String.fromCharCode, console.log is a statement)
		if ((peek().t === 'id') && isOp('.', 1) && (peek(2).t === 'id') && isOp('(', 3) && /^(Math|String)$/.test(peek().v))
		{
			strDotted = peek().v + '.' + peek(2).v;
			intPos += 3;
			var objB = builtin(strDotted, parseArgs(), peek().line);
			if (objB === null) { error(peek().line, strDotted + ' is not in the NTC JS flavour'); return { s: '0', t: 'n' }; }
			return objB;
		}
		if (isId('function'))
		{
			error(peek().line, 'functions as values (closures) are not in the NTC JS flavour');
			next();
			if (peek().t === 'id') { next(); }
			skipRefused();
			return { s: '0', t: 'n' };
		}
		if ((peek().t === 'id') && isOp('(', 1) && (objFuncs[peek().v.toLowerCase()] === undefined))
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
				// a[i] / a[i][j] / a[i, j] -> a(i) / a(i, j)
				var arrIdx = [];

				while (isOp('['))
				{
					next();
					arrIdx.push(parseExpr().s);
					while (isOp(',')) { next(); arrIdx.push(parseExpr().s); }
					expectOp(']');
				}
				objE = { s: objE.s + '(' + arrIdx.join(', ') + ')', t: (objE.name && isStrType(typeOfName(objE.name).replace(/\[\]$/, ''))) ? 's' : 'n', elem: true };
				continue;
			}
			if (isOp('.'))
			{
				next();
				var blnHash = false;
				if (isOp('#')) { next(); blnHash = true; }
				var strM = (blnHash ? 'p_' : '') + next().v;		// #name (private) -> p_name: JS keeps #x and x apart
				var blnCall = isOp('(');
				var arrA = blnCall ? parseArgs() : [];
				var objMe = null;

				if (objE.me)
				{
					// this.x -> Me.x (the class's own member)
					objE = { s: 'Me.' + strM + (blnCall ? '(' + arrA.map(function(o_a) { return o_a.s; }).join(', ') + ')' : ''), t: isStrType(typeOfName(strM)) ? 's' : 'n', name: strM };
					continue;
				}
				objMe = method(objE, strM, arrA, blnCall, peek().line);
				if (objMe !== null) { objE = objMe; continue; }
				// a class's member: c.add(7), Counter.total
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
			if (objScope[strKey] !== strType_a + (strDims_a || '')) { error(intLine_a, strName_a + ' is declared again with another type (one variable per name in a procedure, or in the module)'); }
			return;		// the same name again in another block: one variable
		}
		objScope[strKey] = strType_a + (strDims_a || '');
		objTypes[strKey] = strType_a + (strDims_a !== undefined ? '[]' : '');
		emit(intLine_a, (strScope_a || 'Dim') + ' ' + strName_a + (strDims_a !== undefined ? '(' + strDims_a + ')' : '') + ' As ' + strType_a);
	}
	function statementVar()
	{
		var strKw = next().v;		// let / var / const
		var intLine = peek().line;
		var arrDecl = [];
		var strScope = '';

		if (statementVar.exported) { strScope = 'Public'; statementVar.exported = false; }
		for (;;)
		{
			var objN = next();
			var objInit = null;
			var objNew = null;

			if (objN.t !== 'id') { error(objN.line, 'a name after ' + strKw); break; }
			if (isOp('='))
			{
				next();
				if (isId('new'))
				{
					next();
					var strCls = next().v;
					var arrNa = (isOp('(')) ? parseArgs() : [];
					objNew = { cls: strCls, args: arrNa };
				}
				else
				{
					objInit = parseExpr();
				}
			}
			arrDecl.push({ name: objN.v, init: objInit, obj: objNew, line: objN.line });
			if (isOp(',')) { next(); continue; }
			break;
		}
		semi();
		var strHint = takeHint(intLine);
		var strHType = hintType(strHint, intLine);

		arrDecl.forEach(function(objD_a)
		{
			if (objD_a.obj !== null)
			{
				if (objD_a.obj.cls === 'Array')
				{
					// new Array(n) / new Array(n, m): n elements, 0 .. n - 1
					var arrDims = objD_a.obj.args.map(function(o_a) { return /^\d+$/.test(o_a.s) ? String(parseInt(o_a.s, 10) - 1) : o_a.s + ' - 1'; });
					declare(objD_a.name, strHType || 'Integer', objD_a.line, arrDims.join(', '), strScope);
					return;
				}
				if (objD_a.obj.args.length > 0) { error(objD_a.line, 'new ' + objD_a.obj.cls + '(...): no constructors - call a method to set it up'); }
				objTypes[objD_a.name.toLowerCase()] = 'object';
				emit(objD_a.line, (strScope || 'Dim') + ' ' + objD_a.name + ' As New ' + objD_a.obj.cls);
				return;
			}
			var strType = strHType || ((objD_a.init !== null && objD_a.init.t === 's') ? 'String' : 'Integer');

			if ((strKw === 'const') && (objD_a.init !== null) && (objDeclared === null) && /^(&?[HXO]?[\dA-F]+|"[^"]*")$/i.test(objD_a.init.s))
			{
				objTypes[objD_a.name.toLowerCase()] = (objD_a.init.t === 's') ? 'String' : 'Integer';
				emit(objD_a.line, (strScope ? strScope + ' ' : '') + 'Const ' + objD_a.name + ' = ' + objD_a.init.s);
				return;
			}
			declare(objD_a.name, strType, objD_a.line, undefined, strScope);
			if (objD_a.init !== null)
			{
				emit(objD_a.line, objD_a.name + ' = ' + objD_a.init.s);
			}
		});
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
		while (isId('else'))
		{
			var intEl = next().line;

			if (isId('if'))
			{
				next();
				expectOp('(');
				var objC2 = parseExpr();
				expectOp(')');
				emit(intEl, 'ElseIf ' + objC2.s + ' Then');
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
	// a simple statement without its ; (assignment, ++, a call) as VB text
	function simpleText(blnIsFor_a)
	{
		var intLine = peek().line;

		if (isId('let') || isId('var'))
		{
			next();
			var strN = next().v;

			if (objTypes[strN.toLowerCase()] === undefined) { declare(strN, 'Integer', intLine); }
			expectOp('=');
			return { text: strN + ' = ' + parseExpr().s, name: strN };
		}
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
		var ASSIGN = { '=': '', '+=': '+', '-=': '-', '*=': '*', '/=': '/', '%=': 'Mod', '&=': 'And', '|=': 'Or', '^=': 'Xor', '**=': '^' };

		if ((peek().t === 'op') && (ASSIGN[peek().v] !== undefined))
		{
			var strOp = next().v;
			var objR = parseExpr();
			var strVb = ASSIGN[strOp];

			if ((strOp === '+=') && (objL.t === 's' || objR.t === 's')) { strVb = '&'; }
			return { text: objL.s + ' = ' + (strVb ? '(' + objL.s + ' ' + strVb + ' ' + objR.s + ')' : objR.s), name: objL.s,
				inc: (strOp === '+=') ? objR.s : ((strOp === '-=') ? '-' + objR.s : '') };
		}
		// a call as a statement
		if (/\)$/.test(objL.s))
		{
			return { text: 'Call ' + objL.s };
		}
		error(intLine, 'not a statement: ' + objL.s);
		return { text: '' };
	}
	function statementFor()
	{
		var intLine = next().line;
		var objLoop = { kind: 'For', cont: '' };
		var intSave = 0;

		expectOp('(');
		// counting form: for (let i = a; i <|<=|>|>= b; i++ / i-- / i += k / i -= k)
		intSave = intPos;
		var objCount = (function()
		{
			var blnLet = isId('let') || isId('var');
			if (blnLet) { next(); }
			if (peek().t !== 'id') { return null; }
			var strI = next().v;
			if (!isOp('=')) { return null; }
			next();
			var objA = parseExpr();
			if (!isOp(';')) { return null; }
			next();
			if (!isId(strI)) { return null; }
			next();
			var strCmp = peek().v;
			if (!/^(<|<=|>|>=)$/.test(strCmp) || peek().t !== 'op') { return null; }
			next();
			var objB = parseExpr();
			if (!isOp(';')) { return null; }
			next();
			if (!isId(strI) && !(isOp('++') || isOp('--'))) { return null; }
			var objStep = simpleText(true);
			if (!isOp(')') || !objStep.inc || objStep.name.toLowerCase() !== strI.toLowerCase()) { return null; }
			next();
			return { i: strI, let: blnLet, a: objA.s, b: objB.s, cmp: strCmp, step: objStep.inc };
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
		// any other for: init, While cond, body, step, Wend
		intPos = intSave;
		var arrSaveOut = arrOut.length;
		var objInit = isOp(';') ? null : simpleText(false);

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
		void arrSaveOut;
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

			while (isId('case') || isId('default'))
			{
				if (next().v === 'default') { blnDefault = true; }
				else { arrCase.push(parseExpr().s); }
				expectOp(':');
			}
			if (!arrCase.length && !blnDefault) { error(peek().line, 'expected case or default'); next(); continue; }
			emit(intCl, blnDefault ? 'Case Else' : 'Case ' + arrCase.join(', '));
			var blnEnded = false;

			while (!isId('case') && !isId('default') && !isOp('}') && peek().t !== 'eof')
			{
				if (isId('break')) { next(); semi(); blnEnded = true; continue; }
				if (blnEnded) { error(peek().line, 'code after break in a case is never run'); }
				if (isId('return')) { blnEnded = true; }
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
		if (o.t === 'id')
		{
			switch (o.v)
			{
				case 'let': case 'var': case 'const': statementVar(); return;
				case 'if': statementIf(); return;
				case 'while': statementWhile(); return;
				case 'for': statementFor(); return;
				case 'switch': statementSwitch(); return;
				case 'do': error(o.line, 'do ... while is not in the NTC JS flavour (use while)'); skipRefused(); return;
				case 'try': case 'throw': case 'class': case 'import': case 'async': case 'await': case 'yield':
					if (o.v === 'class') { error(o.line, 'a class goes in a file of its own'); }
					else { error(o.line, o.v + ((o.v === 'try') ? ' / catch' : '') + ' is not in the NTC JS flavour'); }
					skipRefused();
					return;
				case 'function':
					if (strProcKind) { error(o.line, 'a function inside a function (a closure) is not in the NTC JS flavour'); }
					func(''); return;
				case 'export':
					next();
					if (isId('function')) { func('Public'); return; }
					if (isId('let') || isId('var') || isId('const')) { statementVar.exported = true; statementVar(); return; }
					error(o.line, 'export: a function or a variable after it');
					return;
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
						if (!objLc.cont) { objLc.cont = 'jsc' + (++intLabel); }
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
							// returns text: a String function
							arrOut[intHead].text = arrOut[intHead].text.replace(/ As Integer$/, ' As String');
							objFuncs[strProcName.toLowerCase()] = 'String';
						}
						emit(o.line, strProcName + ' = ' + objR.s);
					}
					semi();
					emit(o.line, 'Exit ' + strProcKind);
					return;
			}
			// console.log(a, b) / print(a, b) / cls() ... as statements
			if (statementBuiltin()) { return; }
		}
		var objS = simpleText(false);

		semi();
		takeHint(o.line);
		if (objS.text) { emit(o.line, objS.text); }
	}
	function statementBuiltin()
	{
		var o = peek();
		var strName = o.v;
		var arrA = null;

		if ((strName === 'console') && isOp('.', 1) && peek(2).t === 'id')
		{
			strName = 'console.' + peek(2).v;
			intPos += 2;
		}
		var STMT = {
			'console.log': 'Print', 'print': 'Print', 'console.debug': 'Debug.Print', 'console.assert': 'Debug.Assert',
			'cls': 'Cls', 'locate': 'Locate', 'mode': 'Mode', 'poke': 'Poke', 'doke': 'Doke', 'out': 'Out', 'beep': 'Beep', 'frame': 'Frame',
			'exit': 'End', 'randomize': 'Randomize', 'tab': 'Tab', 'doEvents': 'DoEvents'
		};
		if ((STMT[strName] === undefined) || !isOp('(', 1) || (objFuncs[strName.toLowerCase()] !== undefined))
		{
			if (strName !== o.v) { intPos -= 2; }
			return false;
		}
		next();
		arrA = parseArgs();
		semi();
		var arrS = arrA.map(function(x_a) { return x_a.s; });

		if (strName === 'console.log' || strName === 'console.debug')
		{
			emit(o.line, STMT[strName] + (arrS.length ? ' ' + arrS.join('; ') : ''));
		}
		else if (strName === 'print')
		{
			emit(o.line, 'Print ' + arrS.join('; ') + ';');
		}
		else
		{
			emit(o.line, STMT[strName] + (arrS.length ? ' ' + arrS.join(', ') : ''));
		}
		return true;
	}
	function directive(o_a)
	{
		if (/^Option\s+Flavour\b/i.test(o_a.v)) { return; }		// (read by ntcPrep)
		emit(o_a.line, o_a.v);
	}
	function asmBlock(o_a)
	{
		emit(o_a.line, '#asm');
		o_a.v.forEach(function(s_a, i_a) { emit(o_a.line + 1 + i_a, s_a.replace(/\s+$/, '')); });
		emit(o_a.endline, '#endasm');
	}
	// function name(a, b = 5, c /*#long*/) { ... } //#long
	function func(strScope_a)
	{
		var intLine = next().line;
		var objName = next();
		var arrP = [];
		var intBody = 0;
		var intDepth = 0;
		var blnValue = false;
		var strRet = '';

		if (objName.t !== 'id') { error(intLine, 'a function needs a name'); return; }
		expectOp('(');
		while (!isOp(')') && peek().t !== 'eof')
		{
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
		if (peek().t === 'hint') { strRet = hintType(next().v, intLine); }
		if (!isOp('{')) { error(peek().line, 'a function body { } after its parameters'); return; }
		// a Function when a return gives a value
		intBody = intPos;
		for (var i = intPos; i < arrTok.length; i++)
		{
			if (arrTok[i].t === 'op' && arrTok[i].v === '{') { intDepth++; }
			if (arrTok[i].t === 'op' && arrTok[i].v === '}') { intDepth--; if (intDepth === 0) { break; } }
			if (arrTok[i].t === 'id' && arrTok[i].v === 'return' && !(arrTok[i + 1].t === 'op' && (arrTok[i + 1].v === ';' || arrTok[i + 1].v === '}')) && arrTok[i + 1].line === arrTok[i].line) { blnValue = true; }
		}
		if (peek(1).t === 'hint' && peek(1).line === intLine) { strRet = hintType(arrTok[intPos + 1].v, intLine); arrTok.splice(intPos + 1, 1); }
		void intBody;
		strProcKind = blnValue ? 'Function' : 'Sub';
		strProcName = objName.v;
		if (blnValue) { objFuncs[objName.v.toLowerCase()] = strRet || 'Integer'; } else { objFuncs[objName.v.toLowerCase()] = ''; }
		var objSavedTypes = {};
		var k;
		for (k in objTypes) { if (objTypes.hasOwnProperty(k)) { objSavedTypes[k] = objTypes[k]; } }
		// a parameter used as text in the body (joined with text, a string method on it) is a String
		var objPStr = {};
		var intD2 = 0;
		var STR_METHODS = { length: 1, toUpperCase: 1, toLowerCase: 1, trim: 1, trimStart: 1, trimEnd: 1, charCodeAt: 1, charAt: 1, substr: 1, substring: 1, slice: 1, indexOf: 1, lastIndexOf: 1, repeat: 1, replace: 1, replaceAll: 1, padStart: 1, padEnd: 1 };
		for (var q = intPos; q < arrTok.length; q++)
		{
			var oq = arrTok[q];

			if (oq.t === 'op' && oq.v === '{') { intD2++; }
			if (oq.t === 'op' && oq.v === '}') { intD2--; if (intD2 === 0) { break; } }
			if (oq.t !== 'id') { continue; }
			var oN = arrTok[q + 1];
			var oP = arrTok[q - 1];
			var oN2 = arrTok[q + 2];
			var blnText = (oN.t === 'op' && oN.v === '.' && oN2.t === 'id' && STR_METHODS[oN2.v] && oN2.v !== 'length') ||
				(oN.t === 'op' && oN.v === '+' && (oN2.t === 'str' || oN2.t === 'tpl')) ||
				(oP.t === 'op' && oP.v === '+' && (arrTok[q - 2].t === 'str' || arrTok[q - 2].t === 'tpl'));
			if (blnText) { objPStr[oq.v.toLowerCase()] = true; }
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
	// an ES6 class: class Name { field = 0; #field = 0; method() { } #method() { } get x() { } }
	// ------------------------------------------------------------
	function classFile()
	{
		var intLine = next().line;		// class
		var objName = next();

		strClassName = objName.v;
		emit(intLine, 'Attribute VB_Name = "' + strClassName + '"');
		if (isId('extends')) { error(peek().line, 'extends: no inheritance in NTC'); next(); next(); }
		expectOp('{');
		while (!isOp('}') && peek().t !== 'eof')
		{
			var o = peek();
			var blnPriv = false;
			var strProp = '';

			if (o.t === 'dir') { next(); directive(o); continue; }
			if (o.t === 'asm') { next(); asmBlock(o); continue; }
			if (isOp(';')) { next(); continue; }
			if (isId('static')) { next(); }
			if (isOp('#')) { next(); blnPriv = true; }
			if ((isId('get') || isId('set')) && peek(1).t === 'id' && isOp('(', 2)) { strProp = next().v; }
			var objM = next();

			if (objM.t !== 'id') { error(objM.line, 'a member name'); continue; }
			if (blnPriv) { objM = { t: 'id', v: 'p_' + objM.v, line: objM.line }; }
			if (objM.v === 'constructor') { error(objM.line, 'no constructors in NTC: give the class a method to set it up and call it'); }
			if (isOp('('))
			{
				// a method: rewritten as "function name(...)" and read as one
				intPos--;
				arrTok[intPos] = { t: 'id', v: objM.v, line: objM.line };
				arrTok.splice(intPos, 0, { t: 'id', v: 'function', line: objM.line });
				if (strProp)
				{
					memberProp(strProp, blnPriv);
					continue;
				}
				func(blnPriv ? 'Private' : 'Public');
				continue;
			}
			// a field: name [= value]; //#type
			var objInit = null;

			if (isOp('=')) { next(); objInit = parseExpr(); }
			semi();
			var strHT = hintType(takeHint(objM.line), objM.line);
			var strT = strHT || ((objInit !== null && objInit.t === 's') ? 'String' : 'Integer');

			if (objInit !== null && !/^(0|""|False|\(-?0\))$/.test(objInit.s))
			{
				error(objM.line, 'a field starts at 0 / "" in NTC (no start values in a class yet): set it in a method');
			}
			objTypes[objM.v.toLowerCase()] = strT;
			emit(objM.line, (blnPriv ? 'Private ' : 'Public ') + objM.v + ' As ' + strT);
		}
		expectOp('}');
	}
	// get x() { return ...; } / set x(v) { ... } -> Property Get / Let
	function memberProp(strKind_a, blnPriv_a)
	{
		var intLine = peek().line;
		var intStart = arrOut.length;

		func(blnPriv_a ? 'Private' : 'Public');
		var objHead = arrOut[intStart];
		var objEnd = arrOut[arrOut.length - 1];

		objHead.text = objHead.text.replace(/\b(Sub|Function)\b/, 'Property ' + (strKind_a === 'get' ? 'Get' : 'Let'));
		objEnd.text = 'End Property';
		for (var i = intStart; i < arrOut.length; i++)
		{
			arrOut[i].text = arrOut[i].text.replace(/^Exit (Sub|Function)$/, 'Exit Property');
		}
		void intLine;
	}

	// ------------------------------------------------------------
	// the file
	// ------------------------------------------------------------
	tokenise(objFile_a.text);
	// a class file: a class (and NTC lines, comments) only
	(function()
	{
		var arrTop = arrTok.filter(function(o_a) { return o_a.t !== 'dir' && o_a.t !== 'eof'; });
		blnClass = (arrTop.length > 0) && (arrTop[0].t === 'id') && (arrTop[0].v === 'class');
	})();
	// functions first seen anywhere in the file can be called before they are defined
	for (var t = 0; t < arrTok.length - 1; t++)
	{
		if (arrTok[t].t === 'id' && arrTok[t].v === 'function' && arrTok[t + 1].t === 'id')
		{
			objFuncs[arrTok[t + 1].v.toLowerCase()] = '?';
		}
	}
	while (peek().t !== 'eof')
	{
		if (blnClass && isId('class')) { classFile(); continue; }
		if (blnClass && peek().t !== 'dir' && peek().t !== 'asm') { error(peek().line, 'a class file holds the class only'); next(); continue; }
		statement();
	}

	// VB text, one VB line per entry, and the JS line each came from
	return {
		text: arrOut.map(function(o_a) { return o_a.text; }).join('\n'),
		lines: arrOut.map(function(o_a) { return o_a.line; }),
		cls: blnClass,
		classname: strClassName,
		errors: arrErrors
	};
}
