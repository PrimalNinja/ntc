// tinyz80b - BASIC to NTC (Native Threaded Code) compiler. ES5.
// Developed by Julian Cassin. 2019-2026.
// (c) 2026 Cyborg Unicorn Pty Ltd - MIT License
//
// Structure (unchanged from the original tinyz80b):
//	- statements are matched line by line with regex
//	- expressions go through IFtoPF (shunting yard) to postfix, then a
//	  postfix walk with a value stack emits one keyword per operator
//	- no parse tree, no recursive descent
//
// Two passes over the source: pass 1 only collects variable types,
// arrays and labels, pass 2 generates the thread.
//
// Usage:
//	var objResult = ntcCompile(strBASIC, { platform: 'cpc', org: '#4000', library: 'used' });
//	objResult.asm		- assembler source
//	objResult.errors	- [{ line: n, msg: '...' }]
//	objResult.stats		- { threadbytes, keywords, variables, temps }
//
// Library text comes from NTC_LIB_ASM / NTC_PLATFORMS (ntc_lib.js) unless
// passed as objOptions.libtext / objOptions.platformtext.

// ============================================================
// IFtoPF - infix to postfix (shunting yard), BASIC operator set
// ============================================================

// operators, prefix operators are NEG and NOT (functions are prefix too)
var NTC_OPERATORS = ['_NEG_', '_NOT_', '_*_', '_/_', '_\\_', '_MOD_', '_+_', '_-_', '_=_', '_<>_', '_<_', '_<=_', '_>_', '_>=_', '_AND_', '_OR_', '_XOR_'];

// lower binds tighter, equal = same level (left to right)
var NTC_PRECEDENCE = {
	'NEG': 1,
	'*': 3, '/': 3, '\\': 3, 'MOD': 3,
	'+': 4, '-': 4,
	'=': 5, '<>': 5, '<': 5, '<=': 5, '>': 5, '>=': 5,
	'NOT': 6,
	'AND': 7,
	'OR': 8, 'XOR': 8
};

function IFtoPF(str_a, arrFunctions_a)
{
	var arrResultStack = [];
	var arrOperatorStack = [];
	var blnElementComplete = false;
	var blnEndBrace = false;
	var blnExpectOperand = true;
	var blnFound = false;
	var blnInIdentifier = false;
	var blnInOperator = false;
	var blnOpenBrace = false;
	var blnProceed = true;
	var blnSpecialChars = false;
	var lngI = 0;
	var strChar = '';
	var strElement = '';
	var strOperand = '';
	var strOperator = '';
	var strUpper = '';

	function isFunction(arrFunctions_a, str_a)
	{
		return (arrFunctions_a.indexOf(str_a) > -1);
	}

	function isOperator(str_a)
	{
		return (NTC_OPERATORS.indexOf('_' + str_a + '_') > -1);
	}

	function isPrefix(str_a)
	{
		return ((str_a === 'NEG') || (str_a === 'NOT') || isFunction(arrFunctions_a, str_a));
	}

	function maybeIdentifier(str_a)
	{
		return ((str_a.length > 0) && ("abcdefghijklmnopqrstuvwxyz1234567890_$&#".indexOf(str_a.toLowerCase()) > -1));
	}

	function maybeOperator(str_a)
	{
		return ((str_a.length > 0) && ("+-*/\\<>=".indexOf(str_a) > -1));
	}

	function precedence(str_a)
	{
		var intResult = 0;	// functions bind tightest

		if (NTC_PRECEDENCE[str_a] !== undefined)
		{
			intResult = NTC_PRECEDENCE[str_a];
		}

		return intResult;
	}

	while (lngI <= str_a.length)
	{
		blnEndBrace = false;
		blnElementComplete = false;
		blnOpenBrace = false;
		blnProceed = true;
		blnSpecialChars = false;
		if (lngI < str_a.length)
		{
			strChar = str_a.substr(lngI, 1);
		}
		else
		{
			strChar = '';
		}

		if (blnInIdentifier)
		{
			if (maybeIdentifier(strChar))
			{
				strElement += strChar;
			}
			else
			{
				blnElementComplete = true;
				blnInIdentifier = false;
				blnProceed = false;
			}
		}
		else if (blnInOperator)
		{
			// only grow while it is still an operator, so a=-5 is = then -
			if (maybeOperator(strChar) && isOperator(strElement + strChar))
			{
				strElement += strChar;
			}
			else
			{
				blnElementComplete = true;
				blnInOperator = false;
				blnProceed = false;
			}
		}
		else
		{
			if (maybeIdentifier(strChar))
			{
				strElement += strChar;
				blnInIdentifier = true;
			}
			else if (maybeOperator(strChar))
			{
				strElement += strChar;
				blnInOperator = true;
			}
			else
			{
				blnSpecialChars = true;
			}
		}

		// special characters
		if (blnSpecialChars)
		{
			if ((strChar === '') || (strChar === ' ') || (strChar === '\t'))
			{
				strChar = '';	// whitespace becomes nothing
			}
			else if (strChar === '(')
			{
				blnElementComplete = true;
				blnOpenBrace = true;
			}
			else if (strChar === ')')
			{
				blnElementComplete = true;
				blnEndBrace = true;
			}
			else
			{
				arrResultStack.push('?');	// not allowed in an expression
			}
		}

		// end of line handling
		if (lngI == str_a.length)
		{
			blnElementComplete = true;
		}

		if (blnElementComplete)
		{
			if (strElement.length > 0)
			{
				strUpper = strElement.toUpperCase();
				if (isOperator(strUpper) || isFunction(arrFunctions_a, strUpper))
				{
					strOperator = strUpper;
				}
				else
				{
					strOperand = strElement;
				}
				strElement = '';
			}

			if (strOperand.length > 0)
			{
				arrResultStack.push(strOperand);
				blnExpectOperand = false;
			}

			if (strOperator.length > 0)
			{
				// unary minus / plus
				if (blnExpectOperand)
				{
					if (strOperator === '-')
					{
						strOperator = 'NEG';
					}
					else if (strOperator === '+')
					{
						strOperator = '';
					}
				}

				if (strOperator.length > 0)
				{
					if (!isPrefix(strOperator))
					{
						// pop everything that binds tighter or equal (left to right)
						while ((arrOperatorStack.length > 0) &&
							(arrOperatorStack[arrOperatorStack.length - 1] !== '(') &&
							(precedence(arrOperatorStack[arrOperatorStack.length - 1]) <= precedence(strOperator)))
						{
							arrResultStack.push(arrOperatorStack.pop());
						}
					}
					arrOperatorStack.push(strOperator);
					blnExpectOperand = true;
				}
			}

			strOperand = '';
			strOperator = '';

			if (blnOpenBrace)
			{
				arrOperatorStack.push('(');
				blnExpectOperand = true;
			}

			if (blnEndBrace)
			{
				blnFound = false;
				while ((arrOperatorStack.length > 0) && !blnFound)
				{
					strOperator = arrOperatorStack.pop();
					if (strOperator === '(')
					{
						blnFound = true;
					}
					else
					{
						arrResultStack.push(strOperator);
					}
				}
				if (!blnFound)
				{
					arrResultStack.push('?');	// unmatched )
				}
				strOperator = '';
				blnExpectOperand = false;
			}
		}

		if (blnProceed)
		{
			lngI++;
		}
	}

	while (arrOperatorStack.length > 0)
	{
		strOperator = arrOperatorStack.pop();
		if (strOperator === '(')
		{
			arrResultStack.push('?');	// unmatched (
		}
		else
		{
			arrResultStack.push(strOperator);
		}
	}

	return arrResultStack.join(' ');
}

// ============================================================
// Compiler
// ============================================================

function ntcCompile(strSource_a, objOptions_a)
{
	var objOptions = {
		org: '#4000',
		library: 'used',		// used, all, none
		platform: 'cpc',		// key into NTC_PLATFORMS (only cpc)
		sourcecomments: true,
		libtext: null,
		platformtext: null
	};

	var BUILTIN_FUNCTIONS = ['PEEK', 'DEEK', 'ABS', 'SGN', 'RND', 'LEN'];
	var BINARY = { '*': 1, '/': 1, '\\': 1, 'MOD': 1, '+': 1, '-': 1, '=': 1, '<>': 1, '<': 1, '<=': 1, '>': 1, '>=': 1, 'AND': 1, 'OR': 1, 'XOR': 1 };
	var COMPARE = { '=': 'eq', '<>': 'ne', '<': 'lt', '<=': 'le', '>': 'gt', '>=': 'ge' };
	var FLIP = { '=': '=', '<>': '<>', '<': '>', '<=': '>=', '>': '<', '>=': '<=' };
	var UNARY = { 'NEG': 1, 'NOT': 1, 'PEEK': 1, 'DEEK': 1, 'ABS': 1, 'SGN': 1, 'RND': 1, 'LEN': 1 };
	var STATEMENT_WORDS = ['CLS', 'END', 'STOP', 'RETURN', 'ELSE', 'ENDIF', 'WEND', 'NEXT', 'LOOP', 'DO', 'FRAME', 'PRINT', 'REM', 'BREAK'];
	var NTC_SCREEN_KEYWORDS = ['kw_printzoscii', 'kw_printstrvar', 'kw_printint', 'kw_printnl', 'kw_inputstr', 'kw_inputint', 'kw_inkey', 'kw_cls', 'kw_locatell', 'kw_locatevv'];
	var BRANCH_LABEL_ARG = { 'kw_goto': 0, 'kw_goto_iftrue': 0, 'kw_goto_iffalse': 0, 'kw_goto_ifzero': 1, 'kw_goto_ifnzero': 1, 'kw_forentry': 3, 'kw_fornext': 3,
		'kw_forupl': 2, 'kw_forupv': 2, 'kw_fordnl': 2, 'kw_fordnv': 2, 'kw_next1l': 2, 'kw_next1v': 2,
		'kw_nextupl': 3, 'kw_nextupv': 3, 'kw_nextdnl': 3, 'kw_nextdnv': 3 };

	var arrLines = [];
	var intRun = 0;
	var intPass = 1;
	var intLine = 0;

	// pass 1 results
	var objScanStrAssign = {};
	var objScanNumAssign = {};
	var objScanInput = {};
	var objScanNumUse = {};
	var objScanStrUse = {};
	var objTypes = {};
	var objArrays = {};		// name -> { label, size, line }
	var objLabels = {};		// label -> line
	var arrFunctionNames = BUILTIN_FUNCTIONS.slice(0);

	// per pass state
	var arrOut = [];
	var arrErrors = [];
	var arrDecl = [];
	var objDecl = {};
	var arrStrings = [];
	var objStrings = {};
	var arrCtl = [];
	var arrBreakpoints = [];
	var objBreakpoints = {};
	var arrLabelRefs = [];
	var intLabelId = 0;
	var intMaxTemp = -1;
	var blnGosub = false;
	var objGlyphs = {};

	// GOSUB as keywords (pass 1 collects, then decided once)
	var blnLastTransfer = false;	// last statement was END/STOP/RETURN/GOTO
	var arrScanJumps = [];		// { label, line } GOTO / THEN n / IF GOTO
	var arrScanCalls = [];		// { label, line } GOSUB
	var arrScanReturns = [];	// line of each RETURN
	var objScanFallIn = {};		// label -> true if code can fall into it
	var arrSubs = [];			// GOSUB targets sorted by line { label, line }
	var objFastSub = {};		// label -> true = keyword form
	var arrFastSubs = [];		// labels using the keyword form (output order)
	var objGotoStubs = {};		// label -> true = needs a GOTO stub
	var arrGotoStubs = [];

	var strKey = '';

	if (objOptions_a !== undefined)
	{
		for (strKey in objOptions_a)
		{
			if (objOptions_a.hasOwnProperty(strKey) && (objOptions_a[strKey] !== undefined))
			{
				objOptions[strKey] = objOptions_a[strKey];
			}
		}
	}

	// ------------------------------------------------------------
	// utils
	// ------------------------------------------------------------

	function s16(int_a)
	{
		var intResult = int_a & 0xffff;

		if (intResult & 0x8000)
		{
			intResult -= 0x10000;
		}

		return intResult;
	}

	function trunc(dbl_a)
	{
		return (dbl_a < 0) ? Math.ceil(dbl_a) : Math.floor(dbl_a);
	}

	function error(strMessage_a)
	{
		if (intPass === 2)
		{
			arrErrors.push({ line: intLine, msg: strMessage_a });
		}
	}

	// replace the inside of "strings" with spaces so searches skip them
	function maskStrings(str_a)
	{
		return str_a.replace(/"[^"]*("|$)/g, function(strMatch_a)
		{
			var strResult = '"';
			var intI = 1;

			for (intI = 1; intI < strMatch_a.length - 1; intI++)
			{
				strResult += ' ';
			}
			if (strMatch_a.length > 1)
			{
				strResult += strMatch_a.substr(strMatch_a.length - 1, 1);
			}

			return strResult;
		});
	}

	// split on separator chars that are outside quotes and brackets
	function splitTop(str_a, strSeps_a)
	{
		var arrResult = [];
		var blnInString = false;
		var intDepth = 0;
		var intI = 0;
		var strChar = '';
		var strText = '';

		for (intI = 0; intI < str_a.length; intI++)
		{
			strChar = str_a.substr(intI, 1);
			if (strChar === '"')
			{
				blnInString = !blnInString;
				strText += strChar;
			}
			else if (blnInString)
			{
				strText += strChar;
			}
			else if (strChar === '(')
			{
				intDepth++;
				strText += strChar;
			}
			else if (strChar === ')')
			{
				intDepth--;
				strText += strChar;
			}
			else if ((intDepth === 0) && (strSeps_a.indexOf(strChar) > -1))
			{
				arrResult.push({ text: strText, sep: strChar });
				strText = '';
			}
			else
			{
				strText += strChar;
			}
		}
		arrResult.push({ text: strText, sep: '' });

		return arrResult;
	}

	function isStatementWord(str_a)
	{
		return (STATEMENT_WORDS.indexOf(str_a.toUpperCase()) > -1);
	}

	// ------------------------------------------------------------
	// names, variables, strings
	// ------------------------------------------------------------

	function normName(str_a)
	{
		return str_a.toLowerCase();
	}

	function nameToLabel(strPrefix_a, str_a)
	{
		return strPrefix_a + normName(str_a).replace(/\$/g, '_s');
	}

	function typeOf(str_a)
	{
		var strName = normName(str_a);
		var strResult = 'int';

		if (strName.substr(strName.length - 1, 1) === '$')
		{
			strResult = 'str';
		}
		else if (objTypes[strName] !== undefined)
		{
			strResult = objTypes[strName];
		}

		return strResult;
	}

	function declare(strLabel_a, strKind_a, intSize_a)
	{
		if (objDecl[strLabel_a] === undefined)
		{
			objDecl[strLabel_a] = { label: strLabel_a, kind: strKind_a, size: intSize_a };
			arrDecl.push(objDecl[strLabel_a]);
		}

		return strLabel_a;
	}

	function varLabel(str_a)
	{
		var strLabel = nameToLabel('var_', str_a);

		declare(strLabel, typeOf(str_a), 0);

		return strLabel;
	}

	function tmp(intIndex_a)
	{
		if (intIndex_a > intMaxTemp)
		{
			intMaxTemp = intIndex_a;
		}

		return 'tmp' + intIndex_a;
	}

	function stringLabel(strText_a)
	{
		var strLabel = '';

		if (objStrings['_' + strText_a] === undefined)
		{
			strLabel = 'str' + arrStrings.length;
			objStrings['_' + strText_a] = strLabel;
			arrStrings.push({ label: strLabel, text: strText_a });
		}

		return objStrings['_' + strText_a];
	}

	function newId()
	{
		intLabelId++;
		return intLabelId;
	}

	function targetLabel(str_a, strKind_a)
	{
		var strResult = '';

		if (/^\d+$/.test(str_a))
		{
			strResult = 'ln_' + parseInt(str_a, 10);
		}
		else if (/^[A-Za-z_]\w*$/.test(str_a))
		{
			strResult = 'lbl_' + normName(str_a);
		}

		if (strResult.length > 0)
		{
			arrLabelRefs.push({ label: strResult, line: intLine });
			if (intPass === 1)
			{
				if (strKind_a === 'gosub')
				{
					arrScanCalls.push({ label: strResult, line: intLine });
				}
				else
				{
					arrScanJumps.push({ label: strResult, line: intLine });
				}
			}
		}
		else
		{
			error('bad label: ' + str_a);
			strResult = 'ntc_badlabel';
		}

		return strResult;
	}

	// ------------------------------------------------------------
	// output
	// ------------------------------------------------------------

	function emit(strKeyword_a, arrArgs_a)
	{
		var arrArgs = [];
		var intI = 0;

		for (intI = 0; intI < arrArgs_a.length; intI++)
		{
			arrArgs.push(argText(arrArgs_a[intI]));
		}
		arrOut.push({ t: 'kw', kw: strKeyword_a, args: arrArgs });
	}

	function emitLabel(str_a)
	{
		arrOut.push({ t: 'label', name: str_a });
	}

	function emitComment(str_a)
	{
		arrOut.push({ t: 'comment', text: str_a });
	}

	// inline ZOSCII text: kw_printzoscii then one glyph word per char, 0 ends it
	function emitZoscii(arrBytes_a)
	{
		var intI = 0;

		var arrCodes = [];
		var intCode = 0;

		emit('kw_printzoscii', []);
		for (intI = 0; intI < arrBytes_a.length; intI++)
		{
			intCode = arrBytes_a[intI];
			if ((intCode === 13) || (intCode === 10))
			{
				if ((intCode === 13) && (arrBytes_a[intI + 1] === 10))
				{
					intI++;
				}
				arrCodes.push(-1);		// newline word
			}
			else
			{
				if ((intCode < 32) || (intCode > 126))
				{
					intCode = 63;		// '?'
				}
				objGlyphs[intCode] = true;
				arrCodes.push(intCode);
			}
		}
		arrOut.push({ t: 'zw', bytes: arrCodes });
	}

	function glyphLabel(intCode_a)
	{
		var strHex = intCode_a.toString(16).toUpperCase();

		return 'glyph_' + ((strHex.length < 2) ? '0' : '') + strHex;
	}

	function argText(obj_a)
	{
		var strResult = '';

		if (typeof obj_a === 'string')
		{
			strResult = obj_a;
		}
		else if (typeof obj_a === 'number')
		{
			strResult = String(obj_a);
		}
		else if (obj_a.k === 'l')
		{
			strResult = String(obj_a.v);
		}
		else
		{
			strResult = obj_a.n;
		}

		return strResult;
	}

	function textToBytes(str_a)
	{
		var arrResult = [];
		var intI = 0;

		for (intI = 0; intI < str_a.length; intI++)
		{
			arrResult.push(str_a.charCodeAt(intI) & 0xff);
		}

		return arrResult;
	}

	// db line from byte codes: printable runs in quotes, the rest as numbers
	function dbText(arrBytes_a)
	{
		var arrParts = [];
		var intI = 0;
		var intCode = 0;
		var strRun = '';

		for (intI = 0; intI < arrBytes_a.length; intI++)
		{
			intCode = arrBytes_a[intI];
			if ((intCode >= 32) && (intCode <= 126) && (intCode !== 34) && (intCode !== 92))
			{
				strRun += String.fromCharCode(intCode);
			}
			else
			{
				if (strRun.length > 0)
				{
					arrParts.push('"' + strRun + '"');
					strRun = '';
				}
				arrParts.push(String(intCode));
			}
		}
		if (strRun.length > 0)
		{
			arrParts.push('"' + strRun + '"');
		}

		return 'db ' + arrParts.join(', ');
	}

	// ------------------------------------------------------------
	// expressions
	// operand: { k: 'l', v: n }	literal
	//			{ k: 'v', n: label }	variable (16 bit word at label)
	//			{ k: 's', n: label }	string (address of 0 terminated text)
	//			{ k: 'f' }			compare result in the Z flag
	// ------------------------------------------------------------

	function lit(int_a)
	{
		return { k: 'l', v: s16(int_a) };
	}

	function vr(str_a)
	{
		return { k: 'v', n: str_a };
	}

	function isArray(str_a)
	{
		return (objArrays[normName(str_a)] !== undefined);
	}

	// flags on the value stack must become a var before anything else runs
	function materialize(arrStack_a, intBase_a)
	{
		var intI = 0;
		var strTemp = '';

		for (intI = 0; intI < arrStack_a.length; intI++)
		{
			if (arrStack_a[intI].k === 'f')
			{
				strTemp = tmp(intBase_a + intI);
				emit('kw_ftov', [strTemp]);
				arrStack_a[intI] = vr(strTemp);
			}
		}
	}

	function parseNumber(str_a)
	{
		var arrMatch = null;
		var intResult = NaN;

		if (/^\d+$/.test(str_a))
		{
			intResult = parseInt(str_a, 10);
		}
		else if ((arrMatch = str_a.match(/^&H([0-9A-F]+)$/i)) || (arrMatch = str_a.match(/^&([0-9A-F]+)$/i)) || (arrMatch = str_a.match(/^#([0-9A-F]+)$/i)))
		{
			intResult = parseInt(arrMatch[1], 16);
		}
		else if ((arrMatch = str_a.match(/^&X([01]+)$/i)))
		{
			intResult = parseInt(arrMatch[1], 2);
		}

		return intResult;
	}

	function operand(strToken_a, arrStack_a, intBase_a)
	{
		var strUpper = strToken_a.toUpperCase();
		var intValue = parseNumber(strToken_a);
		var objResult = lit(0);
		var strTemp = '';

		if (!isNaN(intValue))
		{
			if (intValue > 65535)
			{
				error('number too big: ' + strToken_a);
			}
			objResult = lit(intValue);
		}
		else if (strUpper === 'TRUE')
		{
			objResult = lit(-1);
		}
		else if (strUpper === 'FALSE')
		{
			objResult = lit(0);
		}
		else if (strUpper === 'INKEY')
		{
			materialize(arrStack_a, intBase_a);
			strTemp = tmp(intBase_a + arrStack_a.length);
			emit('kw_inkey', [strTemp]);
			objResult = vr(strTemp);
		}
		else if (/^[A-Za-z_]\w*\$?$/.test(strToken_a))
		{
			if (isArray(strToken_a))
			{
				error('array needs an index: ' + strToken_a);
			}
			else if (typeOf(strToken_a) === 'str')
			{
				objResult = { k: 's', n: varLabel(strToken_a) };
			}
			else
			{
				objResult = vr(varLabel(strToken_a));
			}
		}
		else
		{
			error('bad value: ' + strToken_a);
		}

		return objResult;
	}

	function fold(strOp_a, intA_a, intB_a)
	{
		var intResult = 0;

		switch (strOp_a)
		{
			case '+': intResult = intA_a + intB_a; break;
			case '-': intResult = intA_a - intB_a; break;
			case '*': intResult = s16(intA_a * intB_a); break;
			case '/':
			case '\\': intResult = (intB_a === 0) ? 0 : trunc(intA_a / intB_a); break;
			case 'MOD': intResult = (intB_a === 0) ? intA_a : intA_a - trunc(intA_a / intB_a) * intB_a; break;
			case 'AND': intResult = intA_a & intB_a; break;
			case 'OR': intResult = intA_a | intB_a; break;
			case 'XOR': intResult = intA_a ^ intB_a; break;
			case '=': intResult = (intA_a === intB_a) ? -1 : 0; break;
			case '<>': intResult = (intA_a !== intB_a) ? -1 : 0; break;
			case '<': intResult = (intA_a < intB_a) ? -1 : 0; break;
			case '<=': intResult = (intA_a <= intB_a) ? -1 : 0; break;
			case '>': intResult = (intA_a > intB_a) ? -1 : 0; break;
			case '>=': intResult = (intA_a >= intB_a) ? -1 : 0; break;
			default: break;
		}

		return s16(intResult);
	}

	// emit a compare, result in Z flag
	function emitCompare(strOp_a, objA_a, objB_a)
	{
		var objA = objA_a;
		var objB = objB_a;
		var objSwap = null;
		var strOp = strOp_a;
		var strKeyword = '';

		if (objA.k === 'l')
		{
			objSwap = objA;
			objA = objB;
			objB = objSwap;
			strOp = FLIP[strOp];
		}

		if ((strOp === '=') || (strOp === '<>'))
		{
			strKeyword = 'kw_cp' + COMPARE[strOp];
		}
		else
		{
			strKeyword = 'kw_scp' + COMPARE[strOp];
		}
		strKeyword += 'v' + ((objB.k === 'l') ? 'l' : 'v');
		emit(strKeyword, [objA, objB]);

		return { k: 'f' };
	}

	// a temp from a deeper slot that is handed back as this slot's value
	// would be overwritten by the next sub expression, so move it down
	function keepSlot(obj_a, intSlot_a)
	{
		var arrMatch = (obj_a.k === 'v') ? obj_a.n.match(/^tmp(\d+)$/) : null;

		if ((arrMatch !== null) && (parseInt(arrMatch[1], 10) > intSlot_a))
		{
			emit('kw_vtov', [obj_a, tmp(intSlot_a)]);
			return vr(tmp(intSlot_a));
		}

		return obj_a;
	}

	function binaryOp(strOp_a, objA_a, objB_a, intDest_a, strTarget_a)
	{
		var objA = objA_a;
		var objB = objB_a;
		var objSwap = null;
		var objResult = null;
		var strDest = '';

		if ((objA.k === 's') || (objB.k === 's'))
		{
			error('string used in a number expression');
			return lit(0);
		}

		// both literal - work it out now
		if ((objA.k === 'l') && (objB.k === 'l'))
		{
			return lit(fold(strOp_a, objA.v, objB.v));
		}

		if (COMPARE[strOp_a] !== undefined)
		{
			emitCompare(strOp_a, objA, objB);
			if (strTarget_a)
			{
				emit('kw_ftov', [strTarget_a]);
				return { k: 'v', n: strTarget_a, done: true };
			}
			return { k: 'f' };
		}

		// literal second for things that don't care about order
		if ((objA.k === 'l') && ((strOp_a === '+') || (strOp_a === '*') || (strOp_a === 'AND') || (strOp_a === 'OR') || (strOp_a === 'XOR')))
		{
			objSwap = objA;
			objA = objB;
			objB = objSwap;
		}

		// things that need no code
		if (objB.k === 'l')
		{
			if (((strOp_a === '+') || (strOp_a === '-') || (strOp_a === 'OR') || (strOp_a === 'XOR')) && (objB.v === 0))
			{
				return keepSlot(objA, intDest_a);
			}
			if (((strOp_a === '*') || (strOp_a === '/') || (strOp_a === '\\')) && (objB.v === 1))
			{
				return keepSlot(objA, intDest_a);
			}
			if ((strOp_a === 'AND') && (objB.v === -1))
			{
				return keepSlot(objA, intDest_a);
			}
			if (((strOp_a === '*') || (strOp_a === 'AND')) && (objB.v === 0))
			{
				return lit(0);
			}
		}

		strDest = strTarget_a ? strTarget_a : tmp(intDest_a);

		switch (strOp_a)
		{
			case '+':
			case '-':
				if (objB.k === 'l')
				{
					objB = lit((strOp_a === '-') ? -objB.v : objB.v);
					if ((objB.v === 1) && (objA.n === strDest))
					{
						emit('kw_inc', [strDest]);
					}
					else if ((objB.v === -1) && (objA.n === strDest))
					{
						emit('kw_dec', [strDest]);
					}
					else
					{
						emit('kw_addl', [objA, objB, strDest]);
					}
				}
				else if (strOp_a === '+')
				{
					emit('kw_add', [objA, objB, strDest]);
				}
				else if (objA.k === 'l')
				{
					emit('kw_sublv', [objA, objB, strDest]);
				}
				else
				{
					emit('kw_subvv', [objA, objB, strDest]);
				}
				break;

			case '*':
				if ((objB.k === 'l') && (objB.v === 2))
				{
					emit('kw_2x', [objA, strDest]);
				}
				else if ((objB.k === 'l') && (objB.v === 4))
				{
					emit('kw_4x', [objA, strDest]);
				}
				else
				{
					emit((objB.k === 'l') ? 'kw_mulvl' : 'kw_mulvv', [objA, objB, strDest]);
				}
				break;

			case '/':
			case '\\':
			case 'MOD':
				emit(((strOp_a === 'MOD') ? 'kw_mod' : 'kw_div') + objA.k + objB.k, [objA, objB, strDest]);
				break;

			case 'AND':
			case 'OR':
			case 'XOR':
				emit('kw_' + strOp_a.toLowerCase() + 'v' + objB.k, [objA, objB, strDest]);
				break;

			default:
				error('operator not supported: ' + strOp_a);
				break;
		}

		objResult = vr(strDest);
		objResult.done = !!strTarget_a;

		return objResult;
	}

	function unaryOp(strOp_a, objA_a, intDest_a, strTarget_a)
	{
		var objA = objA_a;
		var objArray = null;
		var objResult = null;
		var strDest = strTarget_a ? strTarget_a : tmp(intDest_a);

		// array element
		if (isArray(strOp_a))
		{
			objArray = objArrays[normName(strOp_a)];
			if (objA.k === 's')
			{
				error('string used as an index');
				return lit(0);
			}
			if (objA.k === 'l')
			{
				if ((objA.v < 0) || (objA.v > objArray.size))
				{
					error('index out of range: ' + strOp_a + '(' + objA.v + ')');
				}
				return vr(objArray.label + ((objA.v !== 0) ? ('+' + (objA.v * 2)) : ''));
			}
			emit('kw_aget', [objArray.label, objA, strDest]);
		}
		else if (strOp_a === 'LEN')
		{
			if (objA.k !== 's')
			{
				error('LEN needs a string variable');
				return lit(0);
			}
			emit('kw_strlen', [objA.n, strDest]);
		}
		else if (objA.k === 's')
		{
			error('string used in a number expression');
			return lit(0);
		}
		else if ((objA.k === 'l') && (strOp_a === 'NEG'))
		{
			return lit(-objA.v);
		}
		else if ((objA.k === 'l') && (strOp_a === 'NOT'))
		{
			return lit(~objA.v);
		}
		else if ((objA.k === 'l') && (strOp_a === 'ABS'))
		{
			return lit(Math.abs(objA.v));
		}
		else if ((objA.k === 'l') && (strOp_a === 'SGN'))
		{
			return lit((objA.v > 0) ? 1 : ((objA.v < 0) ? -1 : 0));
		}
		else
		{
			switch (strOp_a)
			{
				case 'NEG': emit('kw_negv', [objA, strDest]); break;
				case 'NOT': emit('kw_notv', [objA, strDest]); break;
				case 'ABS': emit('kw_absv', [objA, strDest]); break;
				case 'SGN': emit('kw_sgnv', [objA, strDest]); break;
				case 'PEEK': emit((objA.k === 'l') ? 'kw_lptrtov8' : 'kw_vptrtov8', [objA, strDest]); break;
				case 'DEEK': emit((objA.k === 'l') ? 'kw_lptrtov' : 'kw_vptrtov', [objA, strDest]); break;
				case 'RND': emit((objA.k === 'l') ? 'kw_rndl' : 'kw_rndv', [objA, strDest]); break;
				default: error('function not supported: ' + strOp_a); break;
			}
		}

		objResult = vr(strDest);
		objResult.done = !!strTarget_a;

		return objResult;
	}

	// compile an expression. strTarget_a (optional) receives the last
	// operation directly. intBase_a = first temp number this may use.
	function compileExpr(strExpr_a, strTarget_a, intBase_a)
	{
		var arrStack = [];
		var arrTokens = [];
		var blnLast = false;
		var intBase = intBase_a || 0;
		var intI = 0;
		var objA = null;
		var objB = null;
		var strPostfix = '';
		var strToken = '';

		if (/^\s*$/.test(strExpr_a))
		{
			error('missing value');
			return lit(0);
		}
		if (strExpr_a.indexOf('"') > -1)
		{
			error('string used in a number expression: ' + strExpr_a);
			return lit(0);
		}

		strPostfix = IFtoPF(strExpr_a, arrFunctionNames);
		arrTokens = (strPostfix.length > 0) ? strPostfix.split(' ') : [];

		// pass 1: a plain name used with operators is a number
		if ((intPass === 1) && (arrTokens.length > 1))
		{
			for (intI = 0; intI < arrTokens.length; intI++)
			{
				if (/^[A-Za-z_]\w*$/.test(arrTokens[intI]) && (BINARY[arrTokens[intI].toUpperCase()] === undefined) && (UNARY[arrTokens[intI].toUpperCase()] === undefined))
				{
					objScanNumUse[normName(arrTokens[intI])] = true;
				}
			}
		}

		for (intI = 0; intI < arrTokens.length; intI++)
		{
			strToken = arrTokens[intI];
			blnLast = (intI === arrTokens.length - 1);

			if (strToken === '?')
			{
				error('bad expression: ' + strExpr_a);
				return lit(0);
			}
			else if (BINARY[strToken] !== undefined)
			{
				if (arrStack.length < 2)
				{
					error('bad expression: ' + strExpr_a);
					return lit(0);
				}
				materialize(arrStack, intBase);
				objB = arrStack.pop();
				objA = arrStack.pop();
				arrStack.push(binaryOp(strToken, objA, objB, intBase + arrStack.length, blnLast ? strTarget_a : null));
			}
			else if ((UNARY[strToken] !== undefined) || isArray(strToken))
			{
				if (arrStack.length < 1)
				{
					error('bad expression: ' + strExpr_a);
					return lit(0);
				}
				materialize(arrStack, intBase);
				objA = arrStack.pop();
				arrStack.push(unaryOp(strToken, objA, intBase + arrStack.length, blnLast ? strTarget_a : null));
			}
			else
			{
				arrStack.push(operand(strToken, arrStack, intBase));
			}
		}

		if (arrStack.length !== 1)
		{
			error('bad expression: ' + strExpr_a);
			return lit(0);
		}

		return arrStack[0];
	}

	// value as a literal or a var (flags become a temp)
	function compileValue(strExpr_a, intBase_a)
	{
		var objResult = compileExpr(strExpr_a, null, intBase_a);

		if (objResult.k === 'f')
		{
			emit('kw_ftov', [tmp(intBase_a)]);
			objResult = vr(tmp(intBase_a));
		}
		else if (objResult.k === 's')
		{
			error('string used where a number is needed');
			objResult = lit(0);
		}

		return objResult;
	}

	// value that must end up in a var (literals go to a temp)
	function compileVar(strExpr_a, intBase_a)
	{
		var objResult = compileValue(strExpr_a, intBase_a);

		if (objResult.k === 'l')
		{
			emitAssignLiteral(objResult.v, tmp(intBase_a));
			objResult = vr(tmp(intBase_a));
		}

		return objResult;
	}

	function emitAssignLiteral(int_a, strDest_a)
	{
		if (int_a === 0)
		{
			emit('kw_ztov', [strDest_a]);
		}
		else
		{
			emit('kw_ltov', [int_a, strDest_a]);
		}
	}

	function compileAssign(strDest_a, strExpr_a, intBase_a)
	{
		var objResult = compileExpr(strExpr_a, strDest_a, intBase_a);

		if (objResult.done)
		{
			return objResult;
		}

		if (objResult.k === 'l')
		{
			emitAssignLiteral(objResult.v, strDest_a);
		}
		else if (objResult.k === 'f')
		{
			emit('kw_ftov', [strDest_a]);
		}
		else if (objResult.k === 's')
		{
			error('string assigned to a number variable');
		}
		else if (objResult.n !== strDest_a)
		{
			emit('kw_vtov', [objResult, strDest_a]);
		}

		return objResult;
	}

	// string compare a$ = "x" / a$ <> b$, null if not a string compare
	function compileStringCompare(strCond_a)
	{
		var arrMatch = strCond_a.match(/^\s*("[^"]*"|[A-Za-z_]\w*\$?)\s*(=|<>)\s*("[^"]*"|[A-Za-z_]\w*\$?)\s*$/);
		var arrSides = [];
		var blnNumber = false;
		var blnString = false;
		var intI = 0;
		var strSide = '';

		if (!arrMatch)
		{
			return null;
		}

		// pass 1: a plain name compared with "text" is a string
		if (intPass === 1)
		{
			if ((arrMatch[1].substr(0, 1) === '"') && (arrMatch[3].substr(0, 1) !== '"'))
			{
				objScanStrUse[normName(arrMatch[3])] = true;
			}
			if ((arrMatch[3].substr(0, 1) === '"') && (arrMatch[1].substr(0, 1) !== '"'))
			{
				objScanStrUse[normName(arrMatch[1])] = true;
			}
		}

		for (intI = 1; intI <= 3; intI += 2)
		{
			strSide = arrMatch[intI];
			if (strSide.substr(0, 1) === '"')
			{
				blnString = true;
				arrSides.push(stringLabel(strSide.substr(1, strSide.length - 2)));
			}
			else if (typeOf(strSide) === 'str')
			{
				blnString = true;
				arrSides.push(varLabel(strSide));
			}
			else
			{
				blnNumber = true;
			}
		}

		if (!blnString)
		{
			return null;
		}
		if (blnNumber)
		{
			error('string compared with a number');
			return lit(0);
		}

		emit((arrMatch[2] === '=') ? 'kw_strcmpeq' : 'kw_strcmpne', arrSides);

		return { k: 'f' };
	}

	// branch to strLabel_a when the condition is true (or false)
	function compileCond(strCond_a, strLabel_a, blnJumpIfTrue_a)
	{
		var objResult = compileStringCompare(strCond_a);

		if (objResult === null)
		{
			objResult = compileExpr(strCond_a, null, 0);
		}

		if (objResult.k === 'f')
		{
			emit(blnJumpIfTrue_a ? 'kw_goto_iftrue' : 'kw_goto_iffalse', [strLabel_a]);
		}
		else if (objResult.k === 'l')
		{
			if ((objResult.v !== 0) === blnJumpIfTrue_a)
			{
				emit('kw_goto', [strLabel_a]);
			}
		}
		else if (objResult.k === 's')
		{
			error('string used as a condition');
		}
		else
		{
			emit(blnJumpIfTrue_a ? 'kw_goto_ifnzero' : 'kw_goto_ifzero', [objResult, strLabel_a]);
		}
	}

	// ------------------------------------------------------------
	// strings
	// ------------------------------------------------------------

	// "text" or string var -> address label
	function stringSource(str_a)
	{
		var strText = str_a.replace(/^\s+|\s+$/g, '');
		var strResult = '';

		if (/^"[^"]*"$/.test(strText))
		{
			strResult = stringLabel(strText.substr(1, strText.length - 2));
		}
		else if (/^[A-Za-z_]\w*\$?$/.test(strText) && (typeOf(strText) === 'str'))
		{
			strResult = varLabel(strText);
		}
		else
		{
			error('not a string: ' + strText);
			strResult = stringLabel('');
		}

		return strResult;
	}

	function isStringExpr(str_a)
	{
		var arrParts = splitTop(str_a, '+');
		var strFirst = arrParts[0].text.replace(/^\s+|\s+$/g, '');

		return ((maskStrings(str_a).indexOf('"') > -1) ||
			(/^[A-Za-z_]\w*\$?$/.test(strFirst) && (typeOf(strFirst) === 'str')));
	}

	function compileStringAssign(strDest_a, strExpr_a)
	{
		var arrParts = splitTop(strExpr_a, '+');
		var arrSources = [];
		var blnClash = false;
		var intI = 0;
		var strBuild = strDest_a;

		for (intI = 0; intI < arrParts.length; intI++)
		{
			arrSources.push(stringSource(arrParts[intI].text));
			if ((intI > 0) && (arrSources[intI] === strDest_a))
			{
				blnClash = true;
			}
		}

		if (blnClash)
		{
			strBuild = declare('ntc_strtmp', 'str', 0);
		}

		if (arrSources[0] !== strBuild)
		{
			emit('kw_strcpy', [strBuild, arrSources[0]]);
		}
		for (intI = 1; intI < arrSources.length; intI++)
		{
			emit('kw_strcat', [strBuild, arrSources[intI]]);
		}
		if (blnClash)
		{
			emit('kw_strcpy', [strDest_a, strBuild]);
		}
	}

	// ------------------------------------------------------------
	// statements
	// ------------------------------------------------------------

	function ctlTop(strType_a)
	{
		var objResult = null;

		if ((arrCtl.length > 0) && (arrCtl[arrCtl.length - 1].type === strType_a))
		{
			objResult = arrCtl[arrCtl.length - 1];
		}

		return objResult;
	}

	function ctlFind(strType_a)
	{
		var intI = 0;

		for (intI = arrCtl.length - 1; intI >= 0; intI--)
		{
			if (arrCtl[intI].type === strType_a)
			{
				return arrCtl[intI];
			}
		}

		return null;
	}

	function ctlClose(strType_a, strWord_a)
	{
		var objCtl = ctlTop(strType_a);

		if (objCtl === null)
		{
			if (arrCtl.length > 0)
			{
				error(strWord_a + ' does not match ' + arrCtl[arrCtl.length - 1].type + ' at line ' + arrCtl[arrCtl.length - 1].line);
			}
			else
			{
				error(strWord_a + ' without ' + strType_a);
			}
		}
		else
		{
			arrCtl.pop();
		}

		return objCtl;
	}

	function ifBegin(strCond_a, blnSingle_a)
	{
		var intId = newId();
		var objCtl = { type: 'IF', line: intLine, single: blnSingle_a, id: intId, k: 1, next: 'if' + intId + '_1', end: 'if' + intId + '_e', usedend: false, haselse: false };

		compileCond(strCond_a, objCtl.next, false);
		arrCtl.push(objCtl);
	}

	function ifElseIf(strCond_a)
	{
		var objCtl = ctlTop('IF');

		if ((objCtl === null) || objCtl.single || objCtl.haselse)
		{
			error('ELSEIF without IF');
			return;
		}
		emit('kw_goto', [objCtl.end]);
		objCtl.usedend = true;
		emitLabel(objCtl.next);
		objCtl.k++;
		objCtl.next = 'if' + objCtl.id + '_' + objCtl.k;
		compileCond(strCond_a, objCtl.next, false);
	}

	function ifElse(blnSingle_a)
	{
		var objCtl = ctlTop('IF');

		if ((objCtl === null) || (objCtl.single !== blnSingle_a) || objCtl.haselse)
		{
			error('ELSE without IF');
			return;
		}
		emit('kw_goto', [objCtl.end]);
		objCtl.usedend = true;
		emitLabel(objCtl.next);
		objCtl.next = '';
		objCtl.haselse = true;
	}

	function ifEnd(blnSingle_a)
	{
		var objCtl = ctlTop('IF');

		if ((objCtl === null) || (objCtl.single !== blnSingle_a))
		{
			if (blnSingle_a && (arrCtl.length > 0))
			{
				error(arrCtl[arrCtl.length - 1].type + ' not closed inside single line IF');
				while ((arrCtl.length > 0) && (ctlTop('IF') === null || !ctlTop('IF').single))
				{
					arrCtl.pop();
				}
				objCtl = ctlTop('IF');
				if (objCtl === null)
				{
					return;
				}
			}
			else
			{
				error('END IF without IF');
				return;
			}
		}
		arrCtl.pop();
		if (objCtl.next.length > 0)
		{
			emitLabel(objCtl.next);
		}
		if (objCtl.usedend)
		{
			emitLabel(objCtl.end);
		}
	}

	function compilePrint(strArgs_a)
	{
		var arrItems = splitTop(strArgs_a, ';,');
		var arrPending = [];
		var arrParts = [];
		var blnNewline = true;
		var intI = 0;
		var intJ = 0;
		var objValue = null;
		var strItem = '';
		var strPart = '';

		function flush()
		{
			if (arrPending.length > 0)
			{
				emitZoscii(arrPending);
				arrPending = [];
			}
		}

		function printString(str_a)
		{
			var strText = str_a.replace(/^\s+|\s+$/g, '');

			if (/^"[^"]*"$/.test(strText))
			{
				arrPending = arrPending.concat(textToBytes(strText.substr(1, strText.length - 2)));
			}
			else
			{
				flush();
				emit('kw_printstrvar', [stringSource(strText)]);
			}
		}

		for (intI = 0; intI < arrItems.length; intI++)
		{
			strItem = arrItems[intI].text.replace(/^\s+|\s+$/g, '');

			if (strItem.length > 0)
			{
				if (isStringExpr(strItem))
				{
					arrParts = splitTop(strItem, '+');
					for (intJ = 0; intJ < arrParts.length; intJ++)
					{
						printString(arrParts[intJ].text);
					}
				}
				else
				{
					objValue = compileValue(strItem, 0);
					if (objValue.k === 'l')
					{
						arrPending = arrPending.concat(textToBytes(String(objValue.v)));
					}
					else
					{
						flush();
						emit('kw_printint', [objValue]);
					}
				}
			}

			if (arrItems[intI].sep === ',')
			{
				arrPending.push(32);
			}

			if ((intI === arrItems.length - 1) && (strItem.length === 0) && (intI > 0))
			{
				blnNewline = false;	// ended with ; or ,
			}
		}

		if (blnNewline)
		{
			if (arrPending.length > 0)
			{
				arrPending.push(13);
				arrPending.push(10);
			}
			else
			{
				emit('kw_printnl', []);
			}
		}
		flush();
	}

	function compileInput(strArgs_a)
	{
		var arrMatch = strArgs_a.match(/^\s*"([^"]*)"\s*([;,])\s*(.*)$/);
		var arrVars = [];
		var intI = 0;
		var strName = '';
		var strPrompt = '? ';
		var strRest = strArgs_a;

		if (arrMatch)
		{
			strPrompt = arrMatch[1] + ((arrMatch[2] === ';') ? '? ' : '');
			strRest = arrMatch[3];
		}

		arrVars = splitTop(strRest, ',');
		for (intI = 0; intI < arrVars.length; intI++)
		{
			strName = arrVars[intI].text.replace(/^\s+|\s+$/g, '');
			if (!/^[A-Za-z_]\w*\$?$/.test(strName))
			{
				error('INPUT needs a variable: ' + strName);
				continue;
			}
			if (intPass === 1)
			{
				objScanInput[normName(strName)] = true;
			}
			if (strPrompt.length > 0)
			{
				emitZoscii(textToBytes(strPrompt));
				strPrompt = '';
			}
			if (typeOf(strName) === 'str')
			{
				emit('kw_inputstr', [varLabel(strName)]);
			}
			else
			{
				emit('kw_inputint', [varLabel(strName)]);
			}
		}
	}

	// FOR limit / step: literal stays literal, anything else gets its own var
	function forValue(strExpr_a, strLabel_a)
	{
		var objResult = compileExpr(strExpr_a, strLabel_a, 0);

		if (objResult.k === 'l')
		{
			return objResult;
		}

		declare(strLabel_a, 'int', 0);
		if (objResult.k === 'f')
		{
			emit('kw_ftov', [strLabel_a]);
		}
		else if (objResult.k === 's')
		{
			error('string used in FOR');
		}
		else if (!objResult.done)
		{
			emit('kw_vtov', [objResult, strLabel_a]);
		}

		return vr(strLabel_a);
	}

	function compileFor(strVar_a, strStart_a, strLimit_a, strStep_a)
	{
		var intId = newId();
		var objCtl = { type: 'FOR', line: intLine, name: normName(strVar_a), id: intId, top: 'for' + intId + '_t', end: 'for' + intId + '_e', varl: '', lim: null, step: null };
		var objStart = null;
		var objValue = null;
		var strVar = '';

		if (typeOf(strVar_a) === 'str')
		{
			error('FOR needs a number variable');
		}
		strVar = varLabel(strVar_a);
		objCtl.varl = strVar;

		objStart = compileAssign(strVar, strStart_a, 0);
		if (objStart.k !== 'l')
		{
			objStart = null;
		}

		// limit and step are worked out once, before the loop
		objCtl.lim = forValue(strLimit_a, 'for' + intId + '_l');
		objCtl.step = strStep_a ? forValue(strStep_a, 'for' + intId + '_s') : lit(1);

		if (objCtl.step.k === 'l')
		{
			// entry test, skipped when start and limit are both literal and in range
			if ((objStart !== null) && (objCtl.lim.k === 'l'))
			{
				if ((objCtl.step.v >= 0) ? (objStart.v > objCtl.lim.v) : (objStart.v < objCtl.lim.v))
				{
					emit('kw_goto', [objCtl.end]);
				}
			}
			else
			{
				// one keyword: skip the loop if it should not run at all
				emit(((objCtl.step.v >= 0) ? 'kw_forup' : 'kw_fordn') + objCtl.lim.k, [strVar, objCtl.lim, objCtl.end]);
			}
		}
		else
		{
			if (objCtl.lim.k === 'l')
			{
				objValue = objCtl.lim;
				objCtl.lim = vr(declare('for' + intId + '_l', 'int', 0));
				emitAssignLiteral(objValue.v, objCtl.lim.n);
			}
			emit('kw_forentry', [strVar, objCtl.step, objCtl.lim, objCtl.end]);
		}

		emitLabel(objCtl.top);
		arrCtl.push(objCtl);
	}

	function compileNext(strVars_a)
	{
		var arrNames = (strVars_a.replace(/\s/g, '').length > 0) ? splitTop(strVars_a, ',') : [{ text: '' }];
		var intI = 0;
		var objCtl = null;
		var strName = '';

		for (intI = 0; intI < arrNames.length; intI++)
		{
			strName = normName(arrNames[intI].text.replace(/\s/g, ''));
			objCtl = ctlTop('FOR');
			if ((objCtl !== null) && (strName.length > 0) && (strName !== objCtl.name))
			{
				error('NEXT ' + strName + ' does not match FOR ' + objCtl.name + ' at line ' + objCtl.line);
				return;
			}
			objCtl = ctlClose('FOR', 'NEXT');
			if (objCtl === null)
			{
				return;
			}

			if (objCtl.step.k === 'l')
			{
				// one keyword per pass: step, compare, jump back
				if (objCtl.step.v === 1)
				{
					emit('kw_next1' + objCtl.lim.k, [objCtl.varl, objCtl.lim, objCtl.top]);
				}
				else
				{
					emit(((objCtl.step.v >= 0) ? 'kw_nextup' : 'kw_nextdn') + objCtl.lim.k, [objCtl.varl, objCtl.step, objCtl.lim, objCtl.top]);
				}
			}
			else
			{
				emit('kw_fornext', [objCtl.varl, objCtl.step, objCtl.lim, objCtl.top]);
			}
			emitLabel(objCtl.end);
		}
	}

	function compileTwoValues(strArgs_a, strWord_a)
	{
		var arrParts = splitTop(strArgs_a, ',');

		if (arrParts.length !== 2)
		{
			error(strWord_a + ' needs two values');
			return null;
		}

		return [compileValue(arrParts[0].text, 0), compileValue(arrParts[1].text, 1)];
	}

	function compilePoke(strArgs_a, blnWord_a)
	{
		var arrValues = compileTwoValues(strArgs_a, blnWord_a ? 'DOKE' : 'POKE');
		var strSize = blnWord_a ? '' : '8';
		var strKeyword = '';

		if (arrValues === null)
		{
			return;
		}
		// arrValues[0] = address, arrValues[1] = value
		strKeyword = 'kw_' + ((arrValues[1].k === 'l') ? 'l' : 'v') + 'to' + ((arrValues[0].k === 'l') ? 'l' : 'v') + 'ptr' + strSize;
		emit(strKeyword, [arrValues[1], arrValues[0]]);
	}

	function compileDim(strArgs_a)
	{
		var arrParts = splitTop(strArgs_a, ',');
		var arrMatch = null;
		var intI = 0;
		var objSize = null;
		var strName = '';

		for (intI = 0; intI < arrParts.length; intI++)
		{
			arrMatch = arrParts[intI].text.match(/^\s*([A-Za-z_]\w*)\s*\((.+)\)\s*$/);
			if (!arrMatch)
			{
				error('bad DIM: ' + arrParts[intI].text);
				continue;
			}
			strName = normName(arrMatch[1]);
			if (intPass === 1)
			{
				objSize = compileExpr(arrMatch[2], null, 0);
				if ((objSize.k !== 'l') || (objSize.v < 0))
				{
					objSize = lit(0);
				}
				if (objArrays[strName] === undefined)
				{
					objArrays[strName] = { label: 'arr_' + strName, size: objSize.v, line: intLine };
					arrFunctionNames.push(strName.toUpperCase());
				}
			}
			else
			{
				objSize = compileExpr(arrMatch[2], null, 0);
				if ((objSize.k !== 'l') || (objSize.v < 0))
				{
					error('DIM size must be a number: ' + arrParts[intI].text);
				}
				else if (objArrays[strName].line !== intLine)
				{
					error(strName + ' already DIMmed at line ' + objArrays[strName].line);
				}
				declare(objArrays[strName].label, 'arr', objArrays[strName].size);
			}
		}
	}

	function compileArrayAssign(strName_a, strIndex_a, strExpr_a)
	{
		var objArray = objArrays[normName(strName_a)];
		var objIndex = compileValue(strIndex_a, 0);
		var objValue = null;

		if (objIndex.k === 'l')
		{
			if ((objIndex.v < 0) || (objIndex.v > objArray.size))
			{
				error('index out of range: ' + strName_a + '(' + objIndex.v + ')');
			}
			compileAssign(objArray.label + ((objIndex.v !== 0) ? ('+' + (objIndex.v * 2)) : ''), strExpr_a, 0);
			return;
		}

		objValue = compileValue(strExpr_a, 1);
		emit((objValue.k === 'l') ? 'kw_asetl' : 'kw_aset', [objArray.label, objIndex, objValue]);
	}

	// ------------------------------------------------------------
	// GOSUB / RETURN
	// A GOSUB target that is safe becomes a keyword: a code stub saves SP
	// (the return point) in its own RAM slot and jumps into the thread,
	// RETURN is a stub that loads SP back. 1 word each in the thread.
	// Anything else uses the GOSUB stack (kw_gosub / kw_return).
	// ------------------------------------------------------------

	// GOSUB target that owns this line (last target at or above it), or ''
	function subOwner(intLine_a)
	{
		var intI = 0;
		var strResult = '';

		for (intI = 0; intI < arrSubs.length; intI++)
		{
			if (arrSubs[intI].line <= intLine_a)
			{
				strResult = arrSubs[intI].label;
			}
		}

		return strResult;
	}

	function compileGosub(strLabel_a)
	{
		if (objFastSub[strLabel_a] === true)
		{
			arrOut.push({ t: 'stub', name: strLabel_a + '_gs', term: false });
		}
		else
		{
			emit('kw_gosub', [strLabel_a]);
			blnGosub = true;
		}
	}

	function compileReturn()
	{
		var strOwner = '';

		if (intPass === 1)
		{
			arrScanReturns.push(intLine);
		}
		strOwner = subOwner(intLine);
		if ((strOwner.length > 0) && (objFastSub[strOwner] === true))
		{
			arrOut.push({ t: 'stub', name: strOwner + '_rt', term: true });
		}
		else
		{
			emit('kw_return', []);
		}
	}

	// after pass 1: which GOSUB targets can be keywords
	function decideSubs()
	{
		var arrQueue = [];
		var intI = 0;
		var intJ = 0;
		var objBad = {};
		var objEdges = {};
		var objReturns = {};
		var objSeen = {};
		var strFrom = '';
		var strLabel = '';
		var strTo = '';

		arrSubs = [];
		objFastSub = {};
		arrFastSubs = [];

		for (intI = 0; intI < arrScanCalls.length; intI++)
		{
			strLabel = arrScanCalls[intI].label;
			if ((objLabels[strLabel] !== undefined) && (objSeen[strLabel] === undefined))
			{
				objSeen[strLabel] = true;
				arrSubs.push({ label: strLabel, line: objLabels[strLabel] });
			}
		}
		arrSubs.sort(function(objA_a, objB_a)
		{
			return objA_a.line - objB_a.line;
		});

		// code falling into a target: bad for it and for whatever falls in
		for (intI = 0; intI < arrSubs.length; intI++)
		{
			strLabel = arrSubs[intI].label;
			if (objScanFallIn[strLabel] !== false)
			{
				objBad[strLabel] = true;
				strFrom = subOwner(arrSubs[intI].line - 1);
				if (strFrom.length > 0)
				{
					objBad[strFrom] = true;
				}
			}
		}

		// needs a RETURN of its own
		for (intI = 0; intI < arrScanReturns.length; intI++)
		{
			strLabel = subOwner(arrScanReturns[intI]);
			if (strLabel.length > 0)
			{
				objReturns[strLabel] = true;
			}
		}
		for (intI = 0; intI < arrSubs.length; intI++)
		{
			if (objReturns[arrSubs[intI].label] !== true)
			{
				objBad[arrSubs[intI].label] = true;
			}
		}

		// GOTO crossing into or out of a target's lines
		for (intI = 0; intI < arrScanJumps.length; intI++)
		{
			if (objLabels[arrScanJumps[intI].label] !== undefined)
			{
				strFrom = subOwner(arrScanJumps[intI].line);
				strTo = subOwner(objLabels[arrScanJumps[intI].label]);
				if (strFrom !== strTo)
				{
					if (strFrom.length > 0)
					{
						objBad[strFrom] = true;
					}
					if (strTo.length > 0)
					{
						objBad[strTo] = true;
					}
				}
			}
		}

		// call graph: a target that can be called again while it runs
		for (intI = 0; intI < arrScanCalls.length; intI++)
		{
			strFrom = subOwner(arrScanCalls[intI].line);
			if (objEdges[strFrom] === undefined)
			{
				objEdges[strFrom] = [];
			}
			objEdges[strFrom].push(arrScanCalls[intI].label);
		}
		for (intI = 0; intI < arrSubs.length; intI++)
		{
			strLabel = arrSubs[intI].label;
			objSeen = {};
			arrQueue = (objEdges[strLabel] !== undefined) ? objEdges[strLabel].slice(0) : [];
			while (arrQueue.length > 0)
			{
				strTo = arrQueue.pop();
				if (strTo === strLabel)
				{
					objBad[strLabel] = true;
					break;
				}
				if ((objSeen[strTo] === undefined) && (objEdges[strTo] !== undefined))
				{
					objSeen[strTo] = true;
					for (intJ = 0; intJ < objEdges[strTo].length; intJ++)
					{
						arrQueue.push(objEdges[strTo][intJ]);
					}
				}
			}
		}

		for (intI = 0; intI < arrSubs.length; intI++)
		{
			if (objBad[arrSubs[intI].label] !== true)
			{
				objFastSub[arrSubs[intI].label] = true;
				arrFastSubs.push(arrSubs[intI].label);
			}
		}
	}

	function compileStatement(strStatement_a)
	{
		var arrMatch = null;
		var arrValues = null;
		var intId = 0;
		var objCtl = null;
		var objValue = null;
		var strLabel = '';
		var strName = '';
		var strUpper = '';
		var str = strStatement_a.replace(/^\s+|\s+$/g, '');

		if (str.length === 0)
		{
			return;
		}

		strUpper = str.toUpperCase();

		blnLastTransfer = false;

		if (/^\d+$/.test(str))	// THEN 100 / ELSE 200
		{
			emit('kw_goto', [targetLabel(str)]);
			blnLastTransfer = true;
		}
		else if (strUpper === 'CLS')
		{
			emit('kw_cls', []);
		}
		else if (/^END\s*IF$/.test(strUpper))
		{
			ifEnd(false);
		}
		else if ((strUpper === 'END') || (strUpper === 'STOP'))
		{
			emit('kw_stop', []);
			blnLastTransfer = true;
		}
		else if (strUpper === 'RETURN')
		{
			compileReturn();
			blnLastTransfer = true;
		}
		else if (strUpper === 'FRAME')
		{
			emit('kw_frame', []);
		}
		else if ((arrMatch = str.match(/^(?:PRINT\b|\?)\s*(.*)$/i)))
		{
			compilePrint(arrMatch[1]);
		}
		else if ((arrMatch = str.match(/^INPUT\b\s*(.*)$/i)))
		{
			compileInput(arrMatch[1]);
		}
		else if ((arrMatch = str.match(/^ELSE\s*IF\s+(.+?)\s+THEN$/i)))
		{
			ifElseIf(arrMatch[1]);
		}
		else if (strUpper === 'ELSE')
		{
			ifElse(false);
		}
		else if ((arrMatch = str.match(/^WHILE\s+(.+)$/i)))
		{
			intId = newId();
			objCtl = { type: 'WHILE', line: intLine, cond: arrMatch[1], top: 'wh' + intId + '_t', test: 'wh' + intId + '_c', end: 'wh' + intId + '_e' };
			emit('kw_goto', [objCtl.test]);
			emitLabel(objCtl.top);
			arrCtl.push(objCtl);
		}
		else if (strUpper === 'WEND')
		{
			objCtl = ctlClose('WHILE', 'WEND');
			if (objCtl !== null)
			{
				emitLabel(objCtl.test);
				intId = intLine;
				intLine = objCtl.line;
				compileCond(objCtl.cond, objCtl.top, true);
				intLine = intId;
				emitLabel(objCtl.end);
			}
		}
		else if ((arrMatch = str.match(/^DO(?:\s+(WHILE|UNTIL)\s+(.+))?$/i)))
		{
			intId = newId();
			objCtl = { type: 'DO', line: intLine, top: 'do' + intId + '_t', end: 'do' + intId + '_e' };
			emitLabel(objCtl.top);
			if (arrMatch[1])
			{
				compileCond(arrMatch[2], objCtl.end, arrMatch[1].toUpperCase() === 'UNTIL');
			}
			arrCtl.push(objCtl);
		}
		else if ((arrMatch = str.match(/^LOOP(?:\s+(WHILE|UNTIL)\s+(.+))?$/i)))
		{
			objCtl = ctlClose('DO', 'LOOP');
			if (objCtl !== null)
			{
				if (arrMatch[1])
				{
					compileCond(arrMatch[2], objCtl.top, arrMatch[1].toUpperCase() === 'WHILE');
				}
				else
				{
					emit('kw_goto', [objCtl.top]);
				}
				emitLabel(objCtl.end);
			}
		}
		else if ((arrMatch = str.match(/^EXIT\s+(DO|FOR|WHILE)$/i)))
		{
			objCtl = ctlFind(arrMatch[1].toUpperCase());
			if (objCtl === null)
			{
				error('EXIT ' + arrMatch[1].toUpperCase() + ' outside ' + arrMatch[1].toUpperCase());
			}
			else
			{
				emit('kw_goto', [objCtl.end]);
			}
		}
		else if ((arrMatch = str.match(/^FOR\s+([A-Za-z_]\w*)\s*=\s*(.+?)\s+TO\s+(.+?)(?:\s+STEP\s+(.+))?$/i)))
		{
			compileFor(arrMatch[1], arrMatch[2], arrMatch[3], arrMatch[4]);
		}
		else if ((arrMatch = str.match(/^NEXT\b\s*(.*)$/i)))
		{
			compileNext(arrMatch[1]);
		}
		else if ((arrMatch = str.match(/^GO\s*TO\s+(\S+)$/i)))
		{
			emit('kw_goto', [targetLabel(arrMatch[1])]);
			blnLastTransfer = true;
		}
		else if ((arrMatch = str.match(/^GO\s*SUB\s+(\S+)$/i)))
		{
			compileGosub(targetLabel(arrMatch[1], 'gosub'));
		}
		else if ((arrMatch = str.match(/^POKE\s+(.+)$/i)))
		{
			compilePoke(arrMatch[1], false);
		}
		else if ((arrMatch = str.match(/^DOKE\s+(.+)$/i)))
		{
			compilePoke(arrMatch[1], true);
		}
		else if ((arrMatch = str.match(/^LOCATE\s+(.+)$/i)))
		{
			arrValues = compileTwoValues(arrMatch[1], 'LOCATE');
			if (arrValues !== null)
			{
				if ((arrValues[0].k === 'l') && (arrValues[1].k === 'l'))
				{
					emit('kw_locatell', [arrValues[0], arrValues[1]]);
				}
				else
				{
					if (arrValues[0].k === 'l')
					{
						emitAssignLiteral(arrValues[0].v, tmp(0));
						arrValues[0] = vr(tmp(0));
					}
					if (arrValues[1].k === 'l')
					{
						emitAssignLiteral(arrValues[1].v, tmp(1));
						arrValues[1] = vr(tmp(1));
					}
					emit('kw_locatevv', [arrValues[0], arrValues[1]]);
				}
			}
		}
		else if ((arrMatch = str.match(/^MODE\s+(.+)$/i)))
		{
			objValue = compileValue(arrMatch[1], 0);
			emit((objValue.k === 'l') ? 'kw_model' : 'kw_modev', [objValue]);
		}
		else if ((arrMatch = str.match(/^CALL\s+(.+)$/i)))
		{
			objValue = compileValue(arrMatch[1], 0);
			if (objValue.k === 'l')
			{
				arrOut.push({ t: 'bp', name: argText(objValue) });	// machine code run as a keyword
			}
			else
			{
				emit('kw_callv', [objValue]);
			}
		}
		else if ((arrMatch = str.match(/^RANDOMIZE\s+(.+)$/i)))
		{
			objValue = compileValue(arrMatch[1], 0);
			emit((objValue.k === 'l') ? 'kw_seedl' : 'kw_seedv', [objValue]);
		}
		else if ((arrMatch = str.match(/^DIM\s+(.+)$/i)))
		{
			compileDim(arrMatch[1]);
		}
		else if ((arrMatch = str.match(/^BREAK(?:\s+([A-Za-z_]\w*))?$/i)))
		{
			strLabel = 'bp_' + (arrMatch[1] ? normName(arrMatch[1]) : ('line' + intLine));
			if (objBreakpoints[strLabel] === undefined)
			{
				objBreakpoints[strLabel] = true;
				arrBreakpoints.push(strLabel);
			}
			arrOut.push({ t: 'bp', name: strLabel });
		}
		else if ((arrMatch = str.match(/^(?:LET\s+)?([A-Za-z_]\w*)\s*\((.+)\)\s*=\s*(.+)$/i)) && isArray(arrMatch[1]))
		{
			compileArrayAssign(arrMatch[1], arrMatch[2], arrMatch[3]);
		}
		else if ((arrMatch = str.match(/^(?:LET\s+)?([A-Za-z_]\w*\$?)\s*=\s*(.*)$/i)))
		{
			strName = normName(arrMatch[1]);
			if (isArray(strName))
			{
				error('array needs an index: ' + arrMatch[1]);
			}
			else if (intPass === 1)
			{
				if (isStringExpr(arrMatch[2]))
				{
					objScanStrAssign[strName] = true;
				}
				else
				{
					objScanNumAssign[strName] = true;
				}
			}
			else if (typeOf(strName) === 'str')
			{
				compileStringAssign(varLabel(strName), arrMatch[2]);
			}
			else
			{
				compileAssign(varLabel(strName), arrMatch[2], 0);
			}
		}
		else if ((arrMatch = str.match(/^(?:LET\s+)?([A-Za-z_]\w*)\s*\(.*\)\s*=/i)))
		{
			error(arrMatch[1] + ' is not DIMmed');
		}
		else
		{
			error('unknown statement: ' + str);
			emitComment('?? ' + str);
		}
	}

	// ------------------------------------------------------------
	// line walker
	// ------------------------------------------------------------

	// the ELSE that belongs to this IF: an inner IF takes the first ELSE after it
	function findElse(strMasked_a)
	{
		var intDepth = 0;
		var objMatch = null;
		var objWords = /\b(IF|ELSE)\b/gi;

		while ((objMatch = objWords.exec(strMasked_a)) !== null)
		{
			if (objMatch[1].toUpperCase() === 'IF')
			{
				intDepth++;
			}
			else if (intDepth === 0)
			{
				return objMatch;
			}
			else
			{
				intDepth--;
			}
		}

		return null;
	}

	function compileLine(strText_a)
	{
		var arrMatch = null;
		var arrWork = [];
		var intIndex = 0;
		var objWork = null;
		var objThen = null;
		var objElse = null;
		var strAfter = '';
		var strCond = '';
		var strElse = '';
		var strMasked = '';
		var strLabel = '';
		var strText = strText_a.replace(/\r/g, '');
		var strThen = '';

		// ' comment (outside strings)
		strMasked = maskStrings(strText);
		intIndex = strMasked.indexOf("'");
		if (intIndex > -1)
		{
			strText = strText.substr(0, intIndex);
		}

		if (objOptions.sourcecomments && (intPass === 2) && (strText_a.replace(/\s/g, '').length > 0))
		{
			emitComment(intLine + ': ' + strText_a.replace(/^\s+|\s+$/g, ''));
		}

		// line number
		if ((arrMatch = strText.match(/^\s*(\d+)\s*(.*)$/)))
		{
			strLabel = 'ln_' + parseInt(arrMatch[1], 10);
			declareLabel(strLabel);
			strText = arrMatch[2];
		}

		// label:
		if ((arrMatch = strText.match(/^\s*([A-Za-z_]\w*)\s*:(?!=)(.*)$/)) && !isStatementWord(arrMatch[1]))
		{
			declareLabel('lbl_' + normName(arrMatch[1]));
			strText = arrMatch[2];
		}

		arrWork.push({ text: strText });

		while (arrWork.length > 0)
		{
			objWork = arrWork.pop();

			if (objWork.marker === 'ELSE')
			{
				ifElse(true);
				blnLastTransfer = false;
				continue;
			}
			if (objWork.marker === 'ENDIF')
			{
				ifEnd(true);
				blnLastTransfer = false;
				continue;
			}

			strText = objWork.text.replace(/^\s+|\s+$/g, '');
			if (strText.length === 0)
			{
				continue;
			}
			if (/^REM\b/i.test(strText))
			{
				continue;
			}

			strMasked = maskStrings(strText);

			if (/^IF\b/i.test(strText))
			{
				blnLastTransfer = false;
				objThen = /\bTHEN\b/i.exec(strMasked);
				if (objThen !== null)
				{
					strCond = strText.substring(2, objThen.index);
					strAfter = strText.substr(objThen.index + 4);
					if (strAfter.replace(/\s/g, '').length === 0)
					{
						ifBegin(strCond, false);	// block IF
						continue;
					}

					objElse = findElse(maskStrings(strAfter));
					strThen = (objElse !== null) ? strAfter.substr(0, objElse.index) : strAfter;
					strElse = (objElse !== null) ? strAfter.substr(objElse.index + 4) : '';
					strThen = strThen.replace(/^\s+|\s+$/g, '');

					// IF x THEN 100 / IF x THEN GOTO lbl - one branch
					if ((objElse === null) && ((arrMatch = strThen.match(/^(?:GO\s*TO\s+)?(\S+)$/i)) && (/^\d+$/.test(arrMatch[1]) || /^GO\s*TO\s/i.test(strThen))))
					{
						compileCond(strCond, targetLabel(arrMatch[1]), true);
						continue;
					}

					ifBegin(strCond, true);
					arrWork.push({ marker: 'ENDIF' });
					if (objElse !== null)
					{
						arrWork.push({ text: strElse });
						arrWork.push({ marker: 'ELSE' });
					}
					arrWork.push({ text: strThen });
					continue;
				}

				if ((arrMatch = strText.match(/^IF\s+(.+?)\s+GO\s*TO\s+(\S+)$/i)))
				{
					compileCond(arrMatch[1], targetLabel(arrMatch[2]), true);
					continue;
				}

				error('IF without THEN');
				continue;
			}

			// one statement up to the next :
			intIndex = strMasked.indexOf(':');
			if (intIndex > -1)
			{
				arrWork.push({ text: strText.substr(intIndex + 1) });
				strText = strText.substr(0, intIndex);
			}

			compileStatement(strText);
		}
	}

	function declareLabel(strLabel_a)
	{
		if (intPass === 1)
		{
			if (objLabels[strLabel_a] !== undefined)
			{
				arrErrors.push({ line: intLine, msg: 'label used twice: ' + strLabel_a.replace(/^(ln|lbl)_/, '') + ' (also line ' + objLabels[strLabel_a] + ')' });
			}
			else
			{
				objLabels[strLabel_a] = intLine;
			}
			objScanFallIn[strLabel_a] = (!blnLastTransfer) || (arrCtl.length > 0);
		}
		emitLabel(strLabel_a);
	}

	function compilePass(intPass_a)
	{
		var intI = 0;

		intPass = intPass_a;
		arrOut = [];
		arrDecl = [];
		objDecl = {};
		arrStrings = [];
		objStrings = {};
		arrCtl = [];
		arrBreakpoints = [];
		objBreakpoints = {};
		arrLabelRefs = [];
		intLabelId = 0;
		intMaxTemp = -1;
		blnGosub = false;
		objGlyphs = {};
		blnLastTransfer = false;
		objGotoStubs = {};
		arrGotoStubs = [];

		for (intI = 0; intI < arrLines.length; intI++)
		{
			intLine = intI + 1;
			compileLine(arrLines[intI]);
		}

		while (arrCtl.length > 0)
		{
			intLine = arrCtl[arrCtl.length - 1].line;
			error(arrCtl[arrCtl.length - 1].type + ' is not closed');
			arrCtl.pop();
		}
	}

	// ------------------------------------------------------------
	// peephole
	// ------------------------------------------------------------

	function peephole()
	{
		var arrNew = [];
		var blnChanged = true;
		var intGuard = 0;
		var intI = 0;
		var intJ = 0;
		var intArg = 0;
		var objItem = null;
		var objNext = null;
		var objTargets = {};
		var strTarget = '';

		// jump threading: a branch to a label that is just a goto, goes straight there
		for (intI = 0; intI < arrOut.length; intI++)
		{
			if (arrOut[intI].t === 'label')
			{
				intJ = intI + 1;
				while ((intJ < arrOut.length) && ((arrOut[intJ].t === 'label') || (arrOut[intJ].t === 'comment')))
				{
					intJ++;
				}
				if ((intJ < arrOut.length) && (arrOut[intJ].t === 'kw') && (arrOut[intJ].kw === 'kw_goto'))
				{
					objTargets[arrOut[intI].name] = arrOut[intJ].args[0];
				}
			}
		}

		for (intI = 0; intI < arrOut.length; intI++)
		{
			objItem = arrOut[intI];
			if ((objItem.t === 'kw') && (BRANCH_LABEL_ARG[objItem.kw] !== undefined))
			{
				intArg = BRANCH_LABEL_ARG[objItem.kw];
				strTarget = objItem.args[intArg];
				intGuard = 0;
				while ((objTargets[strTarget] !== undefined) && (objTargets[strTarget] !== strTarget) && (intGuard < 50))
				{
					strTarget = objTargets[strTarget];
					intGuard++;
				}
				objItem.args[intArg] = strTarget;
			}
		}

		// goto to the very next label
		while (blnChanged)
		{
			blnChanged = false;
			arrNew = [];
			for (intI = 0; intI < arrOut.length; intI++)
			{
				objItem = arrOut[intI];
				if ((objItem.t === 'kw') && (objItem.kw === 'kw_goto'))
				{
					intJ = intI + 1;
					while ((intJ < arrOut.length) && ((arrOut[intJ].t === 'label') || (arrOut[intJ].t === 'comment')))
					{
						objNext = arrOut[intJ];
						if ((objNext.t === 'label') && (objNext.name === objItem.args[0]))
						{
							break;
						}
						intJ++;
					}
					if ((intJ < arrOut.length) && (arrOut[intJ].t === 'label') && (arrOut[intJ].name === objItem.args[0]))
					{
						blnChanged = true;
						continue;
					}
				}
				arrNew.push(objItem);
			}
			arrOut = arrNew;
		}

		// code after an unconditional goto up to the next label can never run
		arrNew = [];
		blnChanged = false;
		for (intI = 0; intI < arrOut.length; intI++)
		{
			objItem = arrOut[intI];
			if (objItem.t === 'label')
			{
				blnChanged = false;
			}
			if (!blnChanged || (objItem.t === 'comment'))
			{
				arrNew.push(objItem);
			}
			if (((objItem.t === 'kw') && ((objItem.kw === 'kw_goto') || (objItem.kw === 'kw_stop') || (objItem.kw === 'kw_return'))) || ((objItem.t === 'stub') && objItem.term))
			{
				blnChanged = true;
			}
		}
		arrOut = arrNew;
	}

	// ------------------------------------------------------------
	// library linking
	// ------------------------------------------------------------

	function parseSections(strText_a, objInto_a, arrOrder_a)
	{
		var arrLines = strText_a.replace(/\r/g, '').split('\n');
		var arrMatch = null;
		var arrParts = [];
		var intI = 0;
		var objCurrent = null;

		for (intI = 0; intI < arrLines.length; intI++)
		{
			if ((arrMatch = arrLines[intI].match(/^;##\s+(\S+)(.*)$/)))
			{
				arrParts = arrMatch[2].replace(/^\s+|\s+$/g, '');
				objCurrent = { name: arrMatch[1], deps: (arrParts.length > 0) ? arrParts.split(/\s+/) : [], lines: [] };
				if (objInto_a[objCurrent.name] === undefined)
				{
					arrOrder_a.push(objCurrent.name);
				}
				objInto_a[objCurrent.name] = objCurrent;
			}
			else if (objCurrent !== null)
			{
				objCurrent.lines.push(arrLines[intI]);
			}
		}
	}

	function linkLibrary(objUsed_a)
	{
		var arrOrder = [];
		var arrQueue = [];
		var arrResult = [];
		var intI = 0;
		var objNeeded = {};
		var objSections = {};
		var objSection = null;
		var strLib = objOptions.libtext;
		var strName = '';
		var strPlatform = objOptions.platformtext;

		if ((strLib === null) && (typeof NTC_LIB_ASM !== 'undefined'))
		{
			strLib = NTC_LIB_ASM;
		}
		if ((strPlatform === null) && (typeof NTC_PLATFORMS !== 'undefined'))
		{
			strPlatform = NTC_PLATFORMS[objOptions.platform];
		}
		if ((strLib === null) || (strLib === undefined))
		{
			arrErrors.push({ line: 0, msg: 'keyword library not loaded (ntc_lib.js)' });
			return '';
		}
		if ((strPlatform === null) || (strPlatform === undefined))
		{
			arrErrors.push({ line: 0, msg: 'unknown platform: ' + objOptions.platform });
			strPlatform = '';
		}

		parseSections(strLib, objSections, arrOrder);
		parseSections(strPlatform, objSections, arrOrder);

		if (objOptions.library === 'all')
		{
			arrQueue = arrOrder.slice(0);
		}
		else
		{
			arrQueue = ['ntc_data', 'kw_stop'];
			for (strName in objUsed_a)
			{
				if (objUsed_a.hasOwnProperty(strName))
				{
					arrQueue.push(strName);
				}
			}
		}

		while (arrQueue.length > 0)
		{
			strName = arrQueue.pop();
			if (objNeeded[strName] !== undefined)
			{
				continue;
			}
			objSection = objSections[strName];
			if (objSection === undefined)
			{
				arrErrors.push({ line: 0, msg: 'not in library: ' + strName });
				objNeeded[strName] = false;
				continue;
			}
			objNeeded[strName] = true;
			for (intI = 0; intI < objSection.deps.length; intI++)
			{
				arrQueue.push(objSection.deps[intI]);
			}
		}

		for (intI = 0; intI < arrOrder.length; intI++)
		{
			if (objNeeded[arrOrder[intI]] === true)
			{
				arrResult.push(';## ' + arrOrder[intI] + ((objSections[arrOrder[intI]].deps.length > 0) ? (' ' + objSections[arrOrder[intI]].deps.join(' ')) : ''));
				arrResult.push(objSections[arrOrder[intI]].lines.join('\n').replace(/\s+$/, ''));
				arrResult.push('');
			}
		}

		return arrResult.join('\n');
	}

	// ------------------------------------------------------------
	// main
	// ------------------------------------------------------------

	arrLines = strSource_a.replace(/\r\n?/g, '\n').split('\n');

	// pass 1 (twice, so a = b$ style types settle) - types, arrays, labels
	for (intRun = 0; intRun < 2; intRun++)
	{
		objScanInput = {};
		objScanNumAssign = {};
		objScanStrAssign = {};
		objScanNumUse = {};
		objScanStrUse = {};
		objLabels = {};
		arrScanJumps = [];
		arrScanCalls = [];
		arrScanReturns = [];
		objScanFallIn = {};
		arrErrors = [];
		compilePass(1);
		objTypes = {};

		for (strKey in objScanInput)
		{
			if (objScanInput.hasOwnProperty(strKey))
			{
				objTypes[strKey] = 'str';
			}
		}
		// later rules win: INPUT, used in sums, compared with "text", assigned
		for (strKey in objScanNumUse)
		{
			if (objScanNumUse.hasOwnProperty(strKey))
			{
				objTypes[strKey] = 'int';
			}
		}
		for (strKey in objScanStrUse)
		{
			if (objScanStrUse.hasOwnProperty(strKey))
			{
				objTypes[strKey] = 'str';
			}
		}
		for (strKey in objScanNumAssign)
		{
			if (objScanNumAssign.hasOwnProperty(strKey))
			{
				objTypes[strKey] = 'int';
			}
		}
		for (strKey in objScanStrAssign)
		{
			if (objScanStrAssign.hasOwnProperty(strKey))
			{
				objTypes[strKey] = 'str';
			}
		}
	}

	decideSubs();

	// pass 2 - code
	compilePass(2);

	var intI = 0;
	var intJ = 0;
	var arrGlyphCodes = [];
	var arrGlyphLine = [];
	var strText = '';
	var intBytes = 0;
	var intKeywords = 0;
	var arrAsm = [];
	var objItem = null;
	var objUsed = {};
	var strIndent = '\t\t\t';

	for (intI = 0; intI < arrLabelRefs.length; intI++)
	{
		if (objLabels[arrLabelRefs[intI].label] === undefined)
		{
			arrErrors.push({ line: arrLabelRefs[intI].line, msg: 'no such label: ' + arrLabelRefs[intI].label.replace(/^(ln|lbl)_/, '') });
		}
	}

	peephole();

	// header
	arrAsm.push('; ============================================================');
	arrAsm.push('; NTC program - generated by tinyz80b (BASIC to NTC)');
	arrAsm.push('; platform: ' + objOptions.platform);
	arrAsm.push('; ============================================================');
	arrAsm.push('');
	if (String(objOptions.org).replace(/\s/g, '').length > 0)
	{
		arrAsm.push(strIndent + 'org ' + objOptions.org);
		arrAsm.push('');
	}
	arrAsm.push('ntc_start:');
	arrAsm.push(strIndent + 'di');
	arrAsm.push(strIndent + 'ld (ntc_csp), sp');
	if (blnGosub)
	{
		arrAsm.push(strIndent + 'ld hl, ntc_gstack_top');
		arrAsm.push(strIndent + 'ld (ntc_gsp), hl');
	}
	arrAsm.push(strIndent + 'ld sp, main_thread');
	arrAsm.push(strIndent + 'ret');
	arrAsm.push('');
	arrAsm.push('; ============================================================');
	arrAsm.push('; Main Thread');
	arrAsm.push('; ============================================================');
	arrAsm.push('');
	arrAsm.push('main_thread:');
	for (intI = 0; intI < arrOut.length; intI++)
	{
		if ((arrOut[intI].t === 'kw') && (NTC_SCREEN_KEYWORDS.indexOf(arrOut[intI].kw) > -1))
		{
			arrAsm.push(strIndent + 'dw kw_scrinit\t\t; mode 1, ROMs off, clear screen');
			objUsed['kw_scrinit'] = true;
			intBytes += 2;
			break;
		}
	}

	for (intI = 0; intI < arrOut.length; intI++)
	{
		objItem = arrOut[intI];
		if ((objItem.t === 'kw') && (objItem.kw === 'kw_goto') && (objItem.args[0] !== 'ntc_badlabel'))
		{
			// GOTO: 1 word, jumps to a 2 instruction stub (ld sp, label / ret)
			arrAsm.push(strIndent + 'dw ' + objItem.args[0] + '_go');
			if (objGotoStubs[objItem.args[0]] === undefined)
			{
				objGotoStubs[objItem.args[0]] = true;
				arrGotoStubs.push(objItem.args[0]);
			}
			intBytes += 2;
			intKeywords++;
		}
		else if (objItem.t === 'kw')
		{
			arrAsm.push(strIndent + 'dw ' + [objItem.kw].concat(objItem.args).join(', '));
			objUsed[objItem.kw] = true;
			intBytes += (1 + objItem.args.length) * 2;
			intKeywords++;
		}
		else if (objItem.t === 'stub')
		{
			arrAsm.push(strIndent + 'dw ' + objItem.name);
			intBytes += 2;
			intKeywords++;
		}
		else if (objItem.t === 'bp')
		{
			arrAsm.push(strIndent + 'dw ' + objItem.name);
			intBytes += 2;
		}
		else if (objItem.t === 'zw')
		{
			arrGlyphLine = [];
			strText = '';
			for (intJ = 0; intJ < objItem.bytes.length; intJ++)
			{
				if (objItem.bytes[intJ] < 0)
				{
					arrGlyphLine.push('1');
					strText += '\\n';
				}
				else
				{
					arrGlyphLine.push(glyphLabel(objItem.bytes[intJ]));
					strText += String.fromCharCode(objItem.bytes[intJ]);
				}
				if (arrGlyphLine.length === 8)
				{
					arrAsm.push(strIndent + 'dw ' + arrGlyphLine.join(', '));
					arrGlyphLine = [];
				}
			}
			arrGlyphLine.push('0');
			arrAsm.push(strIndent + 'dw ' + arrGlyphLine.join(', ') + '\t\t; "' + strText + '"');
			intBytes += (objItem.bytes.length + 1) * 2;
		}
		else if (objItem.t === 'label')
		{
			arrAsm.push(objItem.name + ':');
		}
		else if (objItem.t === 'comment')
		{
			arrAsm.push('');
			arrAsm.push(strIndent + '; ' + objItem.text);
		}
	}
	// end of program - only needed if the thread can fall off the end
	objItem = (arrOut.length > 0) ? arrOut[arrOut.length - 1] : null;
	if ((objItem === null) || ((objItem.t === 'stub') && !objItem.term) || ((objItem.t !== 'kw') && (objItem.t !== 'stub')) || ((objItem.t === 'kw') && (objItem.kw !== 'kw_stop') && (objItem.kw !== 'kw_goto') && (objItem.kw !== 'kw_return')))
	{
		arrAsm.push(strIndent + 'dw kw_stop');
		intBytes += 2;
	}
	objUsed['kw_stop'] = true;
	if (blnGosub)
	{
		objUsed['ntc_gstack'] = true;
	}

	if ((arrGotoStubs.length > 0) || (arrFastSubs.length > 0))
	{
		arrAsm.push('');
		arrAsm.push('; ============================================================');
		arrAsm.push('; Jump stubs (code, ROMable)');
		arrAsm.push(';   label_go: GOTO label            10 T + 20 T');
		arrAsm.push(';   label_gs: GOSUB label, return point -> label_rs (RAM)');
		arrAsm.push(';   label_rt: RETURN from label');
		arrAsm.push('; ============================================================');
		arrAsm.push('');
		for (intI = 0; intI < arrGotoStubs.length; intI++)
		{
			arrAsm.push(arrGotoStubs[intI] + '_go:' + strIndent + 'ld sp, ' + arrGotoStubs[intI]);
			arrAsm.push(strIndent + 'ret');
		}
		for (intI = 0; intI < arrFastSubs.length; intI++)
		{
			arrAsm.push(arrFastSubs[intI] + '_gs:' + strIndent + 'ld (' + arrFastSubs[intI] + '_rs), sp');
			arrAsm.push(strIndent + 'ld sp, ' + arrFastSubs[intI]);
			arrAsm.push(strIndent + 'ret');
			arrAsm.push(arrFastSubs[intI] + '_rt:' + strIndent + 'ld sp, (' + arrFastSubs[intI] + '_rs)');
			arrAsm.push(strIndent + 'ret');
		}
	}

	if (arrBreakpoints.length > 0)
	{
		arrAsm.push('');
		arrAsm.push('; ============================================================');
		arrAsm.push('; Breakpoints');
		arrAsm.push('; ============================================================');
		arrAsm.push('');
		for (intI = 0; intI < arrBreakpoints.length; intI++)
		{
			arrAsm.push(arrBreakpoints[intI] + ':' + strIndent + 'ret');
		}
	}

	arrAsm.push('');
	arrAsm.push('; ============================================================');
	arrAsm.push('; Variables');
	arrAsm.push('; ============================================================');
	arrAsm.push('');
	for (intI = 0; intI < arrDecl.length; intI++)
	{
		objItem = arrDecl[intI];
		if (objItem.kind === 'str')
		{
			arrAsm.push(objItem.label + ':' + strIndent + 'ds 41');
		}
		else if (objItem.kind === 'arr')
		{
			arrAsm.push(objItem.label + ':' + strIndent + 'ds ' + ((objItem.size + 1) * 2) + '\t\t; 0 to ' + objItem.size);
		}
		else
		{
			arrAsm.push(objItem.label + ':' + strIndent + 'dw 0');
		}
	}
	for (intI = 0; intI < arrFastSubs.length; intI++)
	{
		arrAsm.push(arrFastSubs[intI] + '_rs:' + strIndent + 'dw 0\t\t; return point');
	}
	for (intI = 0; intI <= intMaxTemp; intI++)
	{
		arrAsm.push('tmp' + intI + ':' + strIndent + 'dw 0');
	}

	arrGlyphCodes = [];
	for (strKey in objGlyphs)
	{
		if (objGlyphs.hasOwnProperty(strKey))
		{
			arrGlyphCodes.push(parseInt(strKey, 10));
		}
	}
	if (arrGlyphCodes.length > 0)
	{
		arrGlyphCodes.sort(function(intA_a, intB_a)
		{
			return intA_a - intB_a;
		});
		arrAsm.push('');
		arrAsm.push('; ============================================================');
		arrAsm.push('; ZOSCII glyphs - each points at its 8 byte bitmap in ntc_font');
		arrAsm.push('; ============================================================');
		arrAsm.push('');
		for (intI = 0; intI < arrGlyphCodes.length; intI++)
		{
			arrAsm.push(glyphLabel(arrGlyphCodes[intI]) + strIndent + 'equ ntc_font + ' + ((arrGlyphCodes[intI] - 32) * 8) + '\t\t; ' + dbText([arrGlyphCodes[intI]]).substr(3));
		}
	}

	if (arrStrings.length > 0)
	{
		arrAsm.push('');
		arrAsm.push('; ============================================================');
		arrAsm.push('; Strings');
		arrAsm.push('; ============================================================');
		arrAsm.push('');
		for (intI = 0; intI < arrStrings.length; intI++)
		{
			arrAsm.push(arrStrings[intI].label + ':' + strIndent + dbText(textToBytes(arrStrings[intI].text).concat([0])));
		}
	}

	arrAsm.push('');
	arrAsm.push('; ============================================================');
	arrAsm.push('; Keyword library (' + ((objOptions.library === 'none') ? 'not included' : objOptions.library) + ')');
	arrAsm.push('; ============================================================');
	arrAsm.push('');
	if (objOptions.library !== 'none')
	{
		arrAsm.push(linkLibrary(objUsed));
	}

	arrErrors.sort(function(objA_a, objB_a)
	{
		return objA_a.line - objB_a.line;
	});

	return {
		asm: arrAsm.join('\n'),
		errors: arrErrors,
		stats: {
			threadbytes: intBytes,
			keywords: intKeywords,
			variables: arrDecl.length,
			temps: intMaxTemp + 1
		}
	};
}

