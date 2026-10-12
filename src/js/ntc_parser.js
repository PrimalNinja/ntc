// ntc_parser.js - VB5/VB6 style parser for the NTC compiler. ES5.
// Developed by Julian Cassin. 2019-2026.
// (c) 2026 Cyborg Unicorn Pty Ltd - MIT License
//
// Built on the VBCC (Visual BASIC Cross Compiler) parser concept:
//	- each physical line is normalised (lower case outside quotes, spaces
//	  collapsed, ' comments removed) and split into statements on ":"
//	- a statement is matched on its first words (prefix dispatch), the
//	  same way VBCC's pvtParseApp / pvtParseObject / pvtParseFunction do
//	- context flags say where we are: module, class, procedure, type
//	- every statement becomes one record, declarations go into the
//	  element table
//	- no parse tree, no recursive descent. Expressions stay as text in
//	  the records and are turned to postfix by IFtoPF (shunting yard).
//
// Usage:
//	var objParse = ntcParse([{ name: 'Main.bas', text: '...' }, ...]);
//	objParse.records	- statement records in source order
//	objParse.elements	- element table, full identifier -> element
//	objParse.procs		- procedures in source order
//	objParse.errors		- [{ file, line, msg }]

// ============================================================
// IFtoPF - infix to postfix (shunting yard), BASIC operator set
// ============================================================

// operators, prefix operators are NEG and NOT (functions are prefix too)
var NTC_OPERATORS = ['_NEG_', '_NOT_', '_^_', '_*_', '_/_', '_\\_', '_MOD_', '_+_', '_-_', '_&_', '_=_', '_<>_', '_<_', '_<=_', '_>_', '_>=_', '_LIKE_', '_AND_', '_OR_', '_XOR_'];

// lower binds tighter, equal = same level (left to right)
var NTC_PRECEDENCE = {
	'^': 0,
	'NEG': 1,
	'*': 3, '/': 3, '\\': 3, 'MOD': 3,
	'+': 4, '-': 4,
	'&': 5,
	'=': 6, '<>': 6, '<': 6, '<=': 6, '>': 6, '>=': 6, 'LIKE': 6,
	'NOT': 7,
	'AND': 8,
	'OR': 9, 'XOR': 9
};

// str_a: the expression. arrFunctions_a: upper case names that are
// functions even without brackets (may be empty).
// Any name followed by ( is a function or array: it comes out as NAME@n,
// n = the number of arguments. "text" is one token (quotes kept, spaces
// inside are sent as \s). ? marks an error.
function IFtoPF(str_a, arrFunctions_a)
{
	var arrArgCount = [];		// per open bracket: { fn, commas }
	var arrResultStack = [];
	var arrOperatorStack = [];
	var blnComma = false;
	var blnElementComplete = false;
	var blnEndBrace = false;
	var blnExpectOperand = true;
	var blnFound = false;
	var blnInIdentifier = false;
	var blnInOperator = false;
	var blnInString = false;
	var blnLastName = false;	// last thing out was a plain name
	var blnOpenBrace = false;
	var blnProceed = true;
	var blnSpecialChars = false;
	var lngI = 0;
	var objCount = null;
	var strChar = '';
	var strElement = '';
	var strOperand = '';
	var strOperator = '';
	var strUpper = '';

	function isFunction(str_a)
	{
		return ((arrFunctions_a !== undefined) && (arrFunctions_a.indexOf(str_a) > -1));
	}

	function isOperator(str_a)
	{
		return (NTC_OPERATORS.indexOf('_' + str_a + '_') > -1);
	}

	function isPrefix(str_a)
	{
		return ((str_a === 'NEG') || (str_a === 'NOT'));
	}

	function maybeIdentifier(str_a)
	{
		return ((str_a.length > 0) && ("abcdefghijklmnopqrstuvwxyz1234567890_$#.%!@".indexOf(str_a.toLowerCase()) > -1));
	}

	function maybeOperator(str_a)
	{
		return ((str_a.length > 0) && ("+-*/\\<>=&^".indexOf(str_a) > -1));
	}

	function precedence(str_a)
	{
		var intResult = 0;

		if (NTC_PRECEDENCE[str_a] !== undefined)
		{
			intResult = NTC_PRECEDENCE[str_a];
		}

		return intResult;
	}

	// & starts a number (&H1F, &1F, &X101, &O17) when an operand is expected
	function isNumberAmp(intPos_a)
	{
		var strNext = str_a.substr(intPos_a + 1, 1).toLowerCase();

		return (blnExpectOperand && (strNext.length > 0) && ("0123456789abcdefhxo".indexOf(strNext) > -1));
	}

	while (lngI <= str_a.length)
	{
		blnEndBrace = false;
		blnElementComplete = false;
		blnOpenBrace = false;
		blnComma = false;
		blnProceed = true;
		blnSpecialChars = false;
		strChar = (lngI < str_a.length) ? str_a.substr(lngI, 1) : '';

		if (blnInString)
		{
			if (strChar === '"')
			{
				if (str_a.substr(lngI + 1, 1) === '"')
				{
					strElement += '""';		// "" inside a string is one quote
					lngI++;
				}
				else
				{
					strElement += '"';
					blnInString = false;
					arrResultStack.push(strElement.replace(/ /g, '\\s'));
					strElement = '';
					blnExpectOperand = false;
					blnLastName = false;
				}
			}
			else if (strChar === '')
			{
				arrResultStack.push('?');	// string not closed
				blnInString = false;
				strElement = '';
			}
			else
			{
				strElement += strChar;
			}
			lngI++;
			continue;
		}

		if (blnInIdentifier)
		{
			// & continues a number that started with &, and is the Long suffix
			// right after a name or number (x&, 1000&, &HFFFF&) when no name follows
			if (maybeIdentifier(strChar) || ((strElement.substr(0, 1) === '&') && /[0-9a-fhxo]/i.test(strChar)) ||
				((strChar === '&') && /[a-z0-9_]$/i.test(strElement) && !/[a-z0-9_"$.&]/i.test(str_a.substr(lngI + 1, 1))))
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
			if (strChar === '"')
			{
				blnInString = true;
				strElement = '"';
				lngI++;
				continue;
			}
			else if ((strChar === '&') && isNumberAmp(lngI))
			{
				strElement += strChar;
				blnInIdentifier = true;
			}
			else if (maybeIdentifier(strChar))
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
			else if (strChar === ',')
			{
				blnElementComplete = true;
				blnComma = true;
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
				if (isOperator(strUpper))
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
				if (isFunction(strOperand.toUpperCase()) && !blnOpenBrace)
				{
					arrResultStack.push(strOperand.toUpperCase() + '@0');
					blnLastName = false;
				}
				else
				{
					arrResultStack.push(strOperand);
					blnLastName = /^[a-z_][\w.]*[$%&!#@]?$/i.test(strOperand);
				}
				blnExpectOperand = false;
			}

			if (strOperator.length > 0)
			{
				blnLastName = false;

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
				// a name right before ( is a function or array: it owns the bracket
				objCount = { fn: false, commas: 0 };
				if (blnLastName && (arrResultStack.length > 0))
				{
					objCount.fn = true;
					objCount.name = arrResultStack.pop().toUpperCase();
				}
				arrArgCount.push(objCount);
				arrOperatorStack.push('(');
				blnExpectOperand = true;
				blnLastName = false;
			}

			if (blnComma)
			{
				// argument separator: finish the argument, keep the bracket
				while ((arrOperatorStack.length > 0) && (arrOperatorStack[arrOperatorStack.length - 1] !== '('))
				{
					arrResultStack.push(arrOperatorStack.pop());
				}
				if ((arrArgCount.length === 0) || !arrArgCount[arrArgCount.length - 1].fn)
				{
					arrResultStack.push('?');	// comma outside a function
				}
				else
				{
					arrArgCount[arrArgCount.length - 1].commas++;
				}
				blnExpectOperand = true;
				blnLastName = false;
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
				objCount = (arrArgCount.length > 0) ? arrArgCount.pop() : null;
				if ((objCount !== null) && objCount.fn)
				{
					arrResultStack.push(objCount.name + '@' + ((blnExpectOperand && (objCount.commas === 0)) ? 0 : (objCount.commas + 1)));
				}
				strOperator = '';
				blnExpectOperand = false;
				blnLastName = false;
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
// Parser
// ============================================================

var NTC_TYPES = {
	'byte': 'byte', 'boolean': 'bool', 'integer': 'int', 'long': 'long',
	'currency': 'cur', 'single': 'single', 'double': 'double', 'string': 'str',
	'object': 'object', 'variant': 'variant'
};

var NTC_SUFFIX_TYPES = { '%': 'int', '&': 'long', '!': 'single', '#': 'double', '@': 'cur', '$': 'str' };

// words that can never be a label at the start of a line
var NTC_STATEMENT_WORDS = ['cls', 'end', 'stop', 'return', 'else', 'endif', 'wend', 'next', 'loop', 'do', 'frame',
	'print', 'rem', 'beep', 'randomize', 'doevents', 'exit', 'resume'];

function ntcParse(arrFiles_a, objDefines_a)
{
	var arrRecords = [];
	var arrErrors = [];
	var arrProcs = [];
	var objElements = {};
	var objDefines = {};		// #Const values; objDefines_a: predefined (NTC, NTC_CPC ...)
	var strDefine = '';

	for (strDefine in (objDefines_a || {}))
	{
		if (objDefines_a.hasOwnProperty(strDefine))
		{
			objDefines[strDefine.toLowerCase()] = objDefines_a[strDefine];
		}
	}

	// context flags (VBCC: m_blnInObject, m_blnInSub, m_blnInFunc, m_blnInUDT, m_blnSkip)
	var blnInClass = false;
	var blnInProc = false;
	var blnInType = false;
	var objEnum = null;			// Enum being read: { name, scope, next }
	var arrWith = [];			// With stack (object names)
	var arrSkip = [];			// #if stack: { skip, done }
	var strFile = '';
	var strModule = '';			// current module / class name (lower case)
	var strProc = '';			// current procedure full identifier, '' at module level
	var objProc = null;
	var objType = null;
	var intLine = 0;
	var intFile = 0;
	var strSrc = '';			// the source line being parsed (for comments)

	// ------------------------------------------------------------
	// helpers
	// ------------------------------------------------------------

	function error(strMessage_a)
	{
		arrErrors.push({ file: strFile, line: intLine, msg: strMessage_a });
	}

	function trim(str_a)
	{
		return str_a.replace(/^\s+|\s+$/g, '');
	}

	function left(str_a, strPrefix_a)
	{
		return (str_a.substr(0, strPrefix_a.length) === strPrefix_a);
	}

	function right(str_a, strSuffix_a)
	{
		return ((str_a.length >= strSuffix_a.length) && (str_a.substr(str_a.length - strSuffix_a.length) === strSuffix_a));
	}

	// VBCC StrTok: text up to the delimiter, and the rest after it
	function strTok(objText_a, strDelim_a)
	{
		var intPos = objText_a.s.indexOf(strDelim_a);
		var strResult = '';

		if (intPos > -1)
		{
			strResult = objText_a.s.substr(0, intPos);
			objText_a.s = objText_a.s.substr(intPos + strDelim_a.length);
		}
		else
		{
			strResult = objText_a.s;
			objText_a.s = '';
		}

		return strResult;
	}

	// split on a separator that is outside quotes and brackets
	function splitTop(str_a, strSep_a)
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
			else if ((intDepth === 0) && (str_a.substr(intI, strSep_a.length) === strSep_a))
			{
				arrResult.push(strText);
				strText = '';
				intI += strSep_a.length - 1;
			}
			else
			{
				strText += strChar;
			}
		}
		arrResult.push(strText);

		return arrResult;
	}

	// position of a word (surrounded by spaces / ends) outside quotes and brackets, or -1
	function findWord(str_a, strWord_a, intFrom_a)
	{
		var blnInString = false;
		var intDepth = 0;
		var intI = 0;
		var strChar = '';
		var strBefore = '';
		var strAfter = '';

		for (intI = intFrom_a || 0; intI < str_a.length; intI++)
		{
			strChar = str_a.substr(intI, 1);
			if (strChar === '"')
			{
				blnInString = !blnInString;
			}
			else if (!blnInString)
			{
				if (strChar === '(')
				{
					intDepth++;
				}
				else if (strChar === ')')
				{
					intDepth--;
				}
				else if ((intDepth === 0) && (str_a.substr(intI, strWord_a.length) === strWord_a))
				{
					strBefore = (intI > 0) ? str_a.substr(intI - 1, 1) : ' ';
					strAfter = str_a.substr(intI + strWord_a.length, 1);
					if (!/[\w$]/.test(strBefore) && ((strAfter === '') || !/[\w$]/.test(strAfter)))
					{
						return intI;
					}
				}
			}
		}

		return -1;
	}

	// strip a type suffix: { name, type }
	function splitSuffix(str_a)
	{
		var strLast = str_a.substr(str_a.length - 1, 1);

		if ((str_a.length > 1) && (NTC_SUFFIX_TYPES[strLast] !== undefined))
		{
			return { name: str_a.substr(0, str_a.length - 1), type: NTC_SUFFIX_TYPES[strLast] };
		}

		return { name: str_a, type: '' };
	}

	function isIdentifier(str_a)
	{
		return /^[a-z_][\w]*[%&!#@$]?$/.test(str_a);
	}

	function dataType(str_a)
	{
		var strType = trim(str_a);
		var intStar = strType.indexOf('*');

		if (left(strType, 'new '))
		{
			strType = trim(strType.substr(4));
		}
		if (intStar > -1)
		{
			strType = trim(strType.substr(0, intStar));
		}
		strType = strType.replace(/\s+max\s+.*$/, '');		// String Max n
		if (NTC_TYPES[strType] !== undefined)
		{
			return NTC_TYPES[strType];
		}

		return strType;	// a type (UDT) or class name
	}

	// ------------------------------------------------------------
	// element table (VBCC cElement / pvtElementAdd)
	// ------------------------------------------------------------

	function elementAdd(strType_a, strScope_a, strFull_a, strId_a, objExtra_a)
	{
		var objElement = null;
		var strKey = '';

		if (objElements[strFull_a] !== undefined)
		{
			return null;
		}
		objElement = { etype: strType_a, scope: strScope_a, full: strFull_a, id: strId_a, module: strModule, proc: strProc, file: strFile, line: intLine };
		if (blnPubMember)
		{
			objElement.pub = true;		// a Public member of a class
		}
		if (objExtra_a)
		{
			for (strKey in objExtra_a)
			{
				if (objExtra_a.hasOwnProperty(strKey))
				{
					objElement[strKey] = objExtra_a[strKey];
				}
			}
		}
		objElements[strFull_a] = objElement;

		return objElement;
	}

	function fullName(strScope_a, strId_a)
	{
		if (strScope_a === 'global')
		{
			return strId_a;
		}
		if (strScope_a === 'local')
		{
			return strProc + '.' + strId_a;
		}

		return strModule + '.' + strId_a;	// module private or class member
	}

	function record(strKind_a, objFields_a)
	{
		var objRecord = { k: strKind_a, file: strFile, fileno: intFile, line: intLine, module: strModule, proc: strProc, inclass: blnInClass, src: strSrc };
		var strKey = '';

		if (objFields_a)
		{
			for (strKey in objFields_a)
			{
				if (objFields_a.hasOwnProperty(strKey))
				{
					objRecord[strKey] = objFields_a[strKey];
				}
			}
		}
		arrRecords.push(objRecord);

		return objRecord;
	}

	// ------------------------------------------------------------
	// line normalising (VBCC pvtStatementTok)
	// lower case outside quotes, one space between words, ' comment cut
	// ------------------------------------------------------------

	function normalise(str_a)
	{
		var blnInString = false;
		var blnSpace = false;
		var intI = 0;
		var strChar = '';
		var strResult = '';

		for (intI = 0; intI < str_a.length; intI++)
		{
			strChar = str_a.substr(intI, 1);
			if (blnInString)
			{
				strResult += strChar;
				if (strChar === '"')
				{
					blnInString = false;
				}
				continue;
			}
			if (strChar === '"')
			{
				blnInString = true;
				blnSpace = false;
				strResult += strChar;
				continue;
			}
			if (strChar === "'")
			{
				break;
			}
			if ((strChar === ' ') || (strChar === '\t'))
			{
				if (!blnSpace)
				{
					strResult += ' ';
				}
				blnSpace = true;
				continue;
			}
			blnSpace = false;
			strResult += strChar.toLowerCase();
		}

		return trim(strResult);
	}

	// next statement from the line (up to : outside quotes)
	function statementTok(objText_a)
	{
		var blnInString = false;
		var intI = 0;
		var strChar = '';
		var strResult = '';

		for (intI = 0; intI < objText_a.s.length; intI++)
		{
			strChar = objText_a.s.substr(intI, 1);
			if (strChar === '"')
			{
				blnInString = !blnInString;
			}
			else if (!blnInString && (strChar === ':'))
			{
				strResult = objText_a.s.substr(0, intI);
				objText_a.s = objText_a.s.substr(intI + 1);
				return trim(strResult);
			}
		}
		strResult = objText_a.s;
		objText_a.s = '';

		return trim(strResult);
	}

	// ------------------------------------------------------------
	// declarations
	// ------------------------------------------------------------

	// "a(10) as integer" / "s as string * 10" / "o as new cfoo" / "x%"
	function parseVar(str_a)
	{
		var arrMatch = str_a.match(/^\s*([a-z_]\w*[%&!#@$]?)\s*(\((.*)\))?\s*(as\s+(.+))?\s*$/);
		var objResult = null;
		var objSuffix = null;
		var strAs = '';

		if (!arrMatch)
		{
			return null;
		}
		objSuffix = splitSuffix(arrMatch[1]);
		strAs = arrMatch[5] ? trim(arrMatch[5]) : '';
		objResult = {
			name: objSuffix.name,
			type: strAs ? dataType(strAs) : (objSuffix.type || ''),
			typed: !!(strAs || objSuffix.type),
			isnew: left(strAs, 'new '),
			dims: (arrMatch[2] !== undefined) ? ((trim(arrMatch[3]).length > 0) ? splitTop(arrMatch[3], ',') : []) : null,
			fixed: 0,
			strmax: 0
		};
		if (strAs.indexOf('*') > -1)
		{
			objResult.fixed = trim(strAs.substr(strAs.indexOf('*') + 1));
		}
		else if ((arrMatch = strAs.match(/^string\s+max\s+(.+)$/)))
		{
			objResult.strmax = trim(arrMatch[1]);		// String Max n: at most n chars, not padded (NTC)
		}

		return objResult;
	}

	// redim [preserve] a(bounds) [as type], ...
	function parseRedim(strText_a)
	{
		var arrParts = [];
		var arrVars = [];
		var blnPreserve = false;
		var intI = 0;
		var objVar = null;
		var strText = trim(strText_a);

		if (left(strText, 'preserve '))
		{
			blnPreserve = true;
			strText = trim(strText.substr(9));
		}
		arrParts = splitTop(strText, ',');
		for (intI = 0; intI < arrParts.length; intI++)
		{
			objVar = parseVar(arrParts[intI]);
			if ((objVar === null) || (objVar.dims === null) || (objVar.dims.length === 0))
			{
				error('bad ReDim: ' + trim(arrParts[intI]));
				continue;
			}
			arrVars.push(objVar);
		}
		record('redim', { preserve: blnPreserve, vars: arrVars });
	}

	// dim / public / private / static / global: the list after the word
	function declareVars(strScope_a, strText_a, blnStatic_a)
	{
		var arrParts = splitTop(strText_a, ',');
		var arrVars = [];
		var intI = 0;
		var objVar = null;
		var strFull = '';

		for (intI = 0; intI < arrParts.length; intI++)
		{
			objVar = parseVar(arrParts[intI]);
			if (objVar === null)
			{
				error('bad declaration: ' + trim(arrParts[intI]));
				continue;
			}
			strFull = fullName(strScope_a, objVar.name);
			if (elementAdd(objVar.dims !== null ? 'array' : 'var', strScope_a, strFull, objVar.name,
				{ datatype: objVar.type, typed: objVar.typed, dims: objVar.dims, isnew: objVar.isnew, fixed: objVar.fixed, strmax: objVar.strmax, isstatic: !!blnStatic_a }) === null)
			{
				error('already declared: ' + objVar.name);
				continue;
			}
			objVar.full = strFull;
			arrVars.push(objVar);
		}
		record('dim', { scope: strScope_a, vars: arrVars, isstatic: !!blnStatic_a });
	}

	// const name [as type] = value [, ...]
	function declareConsts(strScope_a, strText_a)
	{
		var arrParts = splitTop(strText_a, ',');
		var arrMatch = null;
		var intI = 0;
		var objSuffix = null;
		var strFull = '';

		for (intI = 0; intI < arrParts.length; intI++)
		{
			arrMatch = arrParts[intI].match(/^\s*([a-z_]\w*[%&!#@$]?)\s*(as\s+([a-z_]\w*))?\s*=\s*(.+)$/);
			if (!arrMatch)
			{
				error('bad const: ' + trim(arrParts[intI]));
				continue;
			}
			objSuffix = splitSuffix(arrMatch[1]);
			strFull = fullName(strScope_a, objSuffix.name);
			if (elementAdd('const', strScope_a, strFull, objSuffix.name, { datatype: arrMatch[3] ? dataType(arrMatch[3]) : objSuffix.type, value: trim(arrMatch[4]) }) === null)
			{
				error('already declared: ' + objSuffix.name);
				continue;
			}
			record('const', { scope: strScope_a, name: objSuffix.name, full: strFull, value: trim(arrMatch[4]) });
		}
	}

	// "(byval a as integer, optional b = 5, c() as string)"
	function parseParams(str_a)
	{
		var arrParts = [];
		var arrResult = [];
		var arrMatch = null;
		var intI = 0;
		var objSuffix = null;
		var strText = trim(str_a);

		if (strText.length === 0)
		{
			return arrResult;
		}
		arrParts = splitTop(strText, ',');
		for (intI = 0; intI < arrParts.length; intI++)
		{
			arrMatch = trim(arrParts[intI]).match(/^(optional\s+)?(byval\s+|byref\s+)?(paramarray\s+)?([a-z_]\w*[%&!#@$]?)\s*(\(\s*\))?\s*(as\s+([a-z_]\w*))?\s*(=\s*(.+))?$/);
			if (!arrMatch)
			{
				error('bad parameter: ' + trim(arrParts[intI]));
				continue;
			}
			if (arrMatch[3])
			{
				error('ParamArray is not supported');
			}
			objSuffix = splitSuffix(arrMatch[4]);
			arrResult.push({
				name: objSuffix.name,
				type: arrMatch[7] ? dataType(arrMatch[7]) : objSuffix.type,
				typed: !!(arrMatch[7] || objSuffix.type),
				byval: (arrMatch[2] !== undefined) && left(arrMatch[2], 'byval'),
				optional: !!arrMatch[1],
				def: arrMatch[9] ? trim(arrMatch[9]) : '',
				isarray: !!arrMatch[5]
			});
		}

		return arrResult;
	}

	// sub / function / property get|let|set header
	function procBegin(strScope_a, strKind_a, strText_a, blnStatic_a)
	{
		var arrMatch = strText_a.match(/^([a-z_]\w*[%&!#@$]?)\s*(\((.*)\))?\s*(as\s+([a-z_]\w*))?\s*$/);
		var arrParams = [];
		var intI = 0;
		var objSuffix = null;
		var strFull = '';
		var strId = '';

		if (!arrMatch)
		{
			error('bad ' + strKind_a + ' header');
			return;
		}
		objSuffix = splitSuffix(arrMatch[1]);
		strId = objSuffix.name;
		if (strKind_a === 'propget')
		{
			strId += '.get';
		}
		else if (strKind_a === 'proplet')
		{
			strId += '.let';
		}
		else if (strKind_a === 'propset')
		{
			strId += '.set';
		}

		// public module procedures are global, class methods belong to the class
		if (blnInClass || (strScope_a !== 'global'))
		{
			strFull = strModule + '.' + strId;
		}
		else
		{
			strFull = strId;
		}

		arrParams = parseParams(arrMatch[3] || '');
		objProc = elementAdd('proc', strScope_a, strFull, objSuffix.name,
			{ kind: strKind_a, params: arrParams, datatype: arrMatch[5] ? dataType(arrMatch[5]) : objSuffix.type, typed: !!(arrMatch[5] || objSuffix.type), isstatic: !!blnStatic_a, inclass: blnInClass, cls: blnInClass ? strModule : '', src: strSrc });
		if (objProc === null)
		{
			error('already declared: ' + strId);
			objProc = { kind: strKind_a, params: arrParams, full: strFull + '#dup' + intLine, datatype: '' };
		}

		blnInProc = true;
		strProc = objProc.full;
		arrProcs.push(objProc);

		// parameters are locals of the procedure
		for (intI = 0; intI < arrParams.length; intI++)
		{
			arrParams[intI].full = strProc + '.' + arrParams[intI].name;
			elementAdd(arrParams[intI].isarray ? 'array' : 'param', 'local', arrParams[intI].full, arrParams[intI].name, { datatype: arrParams[intI].type, typed: arrParams[intI].typed, byval: arrParams[intI].byval, index: intI, dims: arrParams[intI].isarray ? [] : null });
		}
		// a function's name is its result variable
		if ((strKind_a === 'function') || (strKind_a === 'propget'))
		{
			elementAdd('result', 'local', strProc + '.' + objSuffix.name, objSuffix.name, { datatype: objProc.datatype, typed: objProc.typed });
		}

		record('proc', { kind: strKind_a, full: strProc, name: objSuffix.name, params: arrParams, scope: strScope_a });
	}

	function procEnd(strKind_a)
	{
		var strWant = strKind_a;

		if (!blnInProc)
		{
			error('end ' + strKind_a + ' outside a procedure');
			return;
		}
		if ((objProc.kind === 'propget') || (objProc.kind === 'proplet') || (objProc.kind === 'propset'))
		{
			strWant = 'property';
		}
		if (((objProc.kind === 'propget') || (objProc.kind === 'proplet') || (objProc.kind === 'propset')) ? (strKind_a !== 'property') : (objProc.kind !== strKind_a))
		{
			error('end ' + strKind_a + ' does not match ' + objProc.kind);
		}
		record('procend', { full: strProc });
		blnInProc = false;
		strProc = '';
		objProc = null;
	}

	// ------------------------------------------------------------
	// conditional compile (#const / #if / #else / #end if, VBCC #define)
	// ------------------------------------------------------------

	function defineValue(strExpr_a)
	{
		var arrStack = [];
		var arrTokens = IFtoPF(strExpr_a.replace(/\bthen\b/g, ''), []).split(' ');
		var intA = 0;
		var intB = 0;
		var intI = 0;
		var strToken = '';
		var strUpper = '';

		for (intI = 0; intI < arrTokens.length; intI++)
		{
			strToken = arrTokens[intI];
			strUpper = strToken.toUpperCase();
			if (strToken.length === 0)
			{
				continue;
			}
			if ((strUpper === 'NEG') || (strUpper === 'NOT'))
			{
				intA = arrStack.pop() || 0;
				arrStack.push((strUpper === 'NEG') ? -intA : ~intA);
			}
			else if (NTC_PRECEDENCE[strUpper] !== undefined)
			{
				intB = arrStack.pop() || 0;
				intA = arrStack.pop() || 0;
				switch (strUpper)
				{
					case '+': arrStack.push(intA + intB); break;
					case '-': arrStack.push(intA - intB); break;
					case '*': arrStack.push(intA * intB); break;
					case '=': arrStack.push((intA === intB) ? -1 : 0); break;
					case '<>': arrStack.push((intA !== intB) ? -1 : 0); break;
					case '<': arrStack.push((intA < intB) ? -1 : 0); break;
					case '>': arrStack.push((intA > intB) ? -1 : 0); break;
					case '<=': arrStack.push((intA <= intB) ? -1 : 0); break;
					case '>=': arrStack.push((intA >= intB) ? -1 : 0); break;
					case 'AND': arrStack.push(intA & intB); break;
					case 'OR': arrStack.push(intA | intB); break;
					case 'XOR': arrStack.push(intA ^ intB); break;
					default: arrStack.push(0); break;
				}
			}
			else if (/^\d+$/.test(strToken))
			{
				arrStack.push(parseInt(strToken, 10));
			}
			else if (strUpper === 'TRUE')
			{
				arrStack.push(-1);
			}
			else if (strUpper === 'FALSE')
			{
				arrStack.push(0);
			}
			else
			{
				arrStack.push((objDefines[strToken.toLowerCase()] !== undefined) ? objDefines[strToken.toLowerCase()] : 0);
			}
		}

		return (arrStack.length > 0) ? arrStack[arrStack.length - 1] : 0;
	}

	function skipping()
	{
		var intI = 0;

		for (intI = 0; intI < arrSkip.length; intI++)
		{
			if (arrSkip[intI].skip)
			{
				return true;
			}
		}

		return false;
	}

	// true if the statement was a directive
	function directive(str_a)
	{
		var arrMatch = null;
		var objTop = null;

		if ((arrMatch = str_a.match(/^#(const|define)\s+([a-z_]\w*)\s*=?\s*(.*)$/)))
		{
			if (!skipping())
			{
				objDefines[arrMatch[2]] = defineValue(arrMatch[3] || '1');
			}
			return true;
		}
		if ((arrMatch = str_a.match(/^#if\s+(.+?)(\s+then)?$/)))
		{
			objTop = { skip: false, done: false };
			if (skipping())
			{
				objTop.skip = true;
				objTop.done = true;
			}
			else
			{
				objTop.skip = (defineValue(arrMatch[1]) === 0);
				objTop.done = !objTop.skip;
			}
			arrSkip.push(objTop);
			return true;
		}
		if ((arrMatch = str_a.match(/^#elseif\s+(.+?)(\s+then)?$/)))
		{
			objTop = arrSkip[arrSkip.length - 1];
			if (objTop === undefined)
			{
				error('#elseif without #if');
				return true;
			}
			arrSkip.pop();
			if (objTop.done || skipping())
			{
				objTop.skip = true;
			}
			else
			{
				objTop.skip = (defineValue(arrMatch[1]) === 0);
				objTop.done = !objTop.skip;
			}
			arrSkip.push(objTop);
			return true;
		}
		if (str_a === '#else')
		{
			objTop = arrSkip[arrSkip.length - 1];
			if (objTop === undefined)
			{
				error('#else without #if');
				return true;
			}
			arrSkip.pop();
			objTop.skip = objTop.done || skipping();
			objTop.done = true;
			arrSkip.push(objTop);
			return true;
		}
		if ((str_a === '#end if') || (str_a === '#endif'))
		{
			if (arrSkip.length === 0)
			{
				error('#end if without #if');
			}
			arrSkip.pop();
			return true;
		}

		return false;
	}

	// ------------------------------------------------------------
	// module / class level (VBCC pvtParseApp / pvtParseObject)
	// ------------------------------------------------------------

	function parseModuleLevel(str_a)
	{
		var arrMatch = null;

		switch (true)
		{
			case left(str_a, 'private declare ') || left(str_a, 'public declare ') || left(str_a, 'declare '):
				error('Declare is not supported (no DLLs on a Z80)');
				break;

			case left(str_a, 'private enum '):
				enumBegin('module', str_a.substr(13));
				break;

			case left(str_a, 'public enum ') || left(str_a, 'enum '):
				enumBegin(blnInClass ? 'module' : 'global', str_a.substr(left(str_a, 'enum ') ? 5 : 12));
				break;

			case left(str_a, 'private event ') || left(str_a, 'public event ') || left(str_a, 'event ') || (findWord(str_a, 'withevents') > -1):
				error('events are not supported');
				break;

			case left(str_a, 'option '):
				parseOption(str_a.substr(7));
				break;

			case left(str_a, 'attribute '):
			case left(str_a, 'implements '):
				break;

			case left(str_a, 'private type '):
				typeBegin('module', str_a.substr(13));
				break;

			case left(str_a, 'public type '):
				typeBegin('global', str_a.substr(12));
				break;

			case left(str_a, 'type '):
				typeBegin('global', str_a.substr(5));
				break;

			case (arrMatch = str_a.match(/^(private |public |friend |global )?(static )?(sub|function|property get|property let|property set) (.+)$/)) !== null:
				procBegin(((arrMatch[1] === 'private ') ? 'module' : 'global'), procKind(arrMatch[3]), arrMatch[4], !!arrMatch[2]);
				break;

			case left(str_a, 'private const '):
				declareConsts('module', str_a.substr(14));
				break;

			case left(str_a, 'public const ') || left(str_a, 'global const '):
				blnPubMember = blnInClass;
				declareConsts(blnInClass ? 'module' : 'global', str_a.substr(13));
				blnPubMember = false;
				break;

			case left(str_a, 'const '):
				declareConsts('module', str_a.substr(6));
				break;

			case left(str_a, 'private '):
				declareVars('module', str_a.substr(8), false);
				break;

			case left(str_a, 'public ') || left(str_a, 'global '):
				blnPubMember = blnInClass;
				declareVars(blnInClass ? 'module' : 'global', str_a.substr(7), false);
				blnPubMember = false;
				break;

			case left(str_a, 'dim '):
				declareVars('module', str_a.substr(4), false);
				break;

			default:
				if (blnInClass)
				{
					error('statement outside a procedure in a class: ' + str_a);
				}
				else
				{
					parseStatement(str_a);	// top level code is the main program
				}
				break;
		}
	}

	function procKind(str_a)
	{
		switch (str_a)
		{
			case 'property get': return 'propget';
			case 'property let': return 'proplet';
			case 'property set': return 'propset';
			default: return str_a;
		}
	}

	function parseOption(str_a)
	{
		var strText = trim(str_a);

		if (strText === 'explicit')
		{
			record('option', { what: 'explicit' });
		}
		else if ((strText === 'turbo') || (strText === 'turbo on'))
		{
			record('option', { what: 'turbo' });
		}
		else if (strText === 'turbo off')
		{
			record('option', { what: 'normal' });
		}
		else if (strText === 'vbprint')
		{
			record('option', { what: 'vbprint' });	// Print spacing like VB
		}
		else if (/^base [01]$/.test(strText))
		{
			record('option', { what: 'base', value: parseInt(strText.substr(5), 10) });
		}
		else if (/^classsize \d+$/.test(strText))
		{
			record('option', { what: 'classsize', value: parseInt(strText.substr(10), 10) });	// planned, not enforced
		}
		else if (/^terminal (none|vt52|ansi)$/.test(strText))
		{
			record('option', { what: 'terminal', value: strText.substr(9) });	// CP/M: the terminal's codes for Cls / Locate
		}
		else if (left(strText, 'stack '))
		{
			record('option', { what: 'stack', value: trim(strText.substr(6)) });	// where the real stack starts
		}
		else if (left(strText, 'romenable '))
		{
			record('option', { what: 'romenable', value: trim(strText.substr(10)) });	// CPC firmware: the ROMs to start
		}
		else if (left(strText, 'class '))
		{
			record('option', { what: 'class', value: trim(strSrc.replace(/^\s*option\s+class\s+/i, '')) });	// a class's kind: overlay ["file"], interrupt rate | frame
		}
		else if (left(strText, 'memory '))
		{
			record('option', { what: 'memory', value: trim(strText.substr(7)) });	// the Memory class's scheme: small, cpcexpansion [maxpages]
		}
		else if (left(strText, 'reserve '))
		{
			record('option', { what: 'reserve', value: trim(strText.substr(8)) });	// memory the program must not reach into
		}
		else if (strText === 'compare text')
		{
			record('option', { what: 'comparetext' });	// string compares ignore case in this module
		}
		else if (left(strText, 'compare ') || left(strText, 'private module'))
		{
			// no effect here
		}
		else
		{
			error('unknown option: ' + strText);
		}
	}

	function typeBegin(strScope_a, str_a)
	{
		var strName = trim(str_a);

		if (!/^[a-z_]\w*$/.test(strName))
		{
			error('bad type name: ' + strName);
		}
		objType = elementAdd('type', strScope_a, strName, strName, { fields: [] });
		if (objType === null)
		{
			error('already declared: ' + strName);
			objType = { fields: [] };
		}
		blnInType = true;
		record('type', { name: strName });
	}

	// Enum: members are constants (also reachable as EnumName.Member)
	function enumBegin(strScope_a, str_a)
	{
		var strName = trim(str_a);

		if (!/^[a-z_]\w*$/.test(strName))
		{
			error('bad Enum name: ' + strName);
		}
		objEnum = { name: strName, scope: strScope_a, next: 0 };
		if (elementAdd('#' + 'enum', 'global', '#enum.' + strName, strName, {}) === null)
		{
			error('already declared: ' + strName);
		}
		record('enum', { name: strName });
	}

	function parseEnumLevel(str_a)
	{
		var arrMatch = null;
		var strFull = '';
		var strValue = '';

		if (str_a === 'end enum')
		{
			objEnum = null;
			return;
		}
		arrMatch = str_a.match(/^([a-z_]\w*)\s*(=\s*(.+))?$/);
		if (!arrMatch)
		{
			error('bad Enum member: ' + str_a);
			return;
		}
		strValue = arrMatch[3] ? trim(arrMatch[3]) : String(objEnum.next);
		if (arrMatch[3])
		{
			objEnum.next = NaN;		// worked out by the compiler from here on
			strValue = '(' + strValue + ')';
		}
		if (isNaN(objEnum.next))
		{
			objEnum.prev = arrMatch[3] ? strValue : ('(' + objEnum.prev + ') + 1');
			strValue = objEnum.prev;
		}
		else
		{
			objEnum.next++;
		}
		strFull = fullName(objEnum.scope, arrMatch[1]);
		if (elementAdd('const', objEnum.scope, strFull, arrMatch[1], { datatype: 'int', value: strValue }) === null)
		{
			error('already declared: ' + arrMatch[1]);
		}
		// EnumName.Member as well
		elementAdd('const', objEnum.scope, objEnum.name + '.' + arrMatch[1], arrMatch[1], { datatype: 'int', value: strValue });
	}

	// VBCC pvtParseUDT
	function parseTypeLevel(str_a)
	{
		var objVar = null;

		if ((str_a === 'end type'))
		{
			blnInType = false;
			record('typeend', { name: objType.full });
			objType = null;
			return;
		}
		objVar = parseVar(str_a);
		if (objVar === null)
		{
			error('bad type field: ' + str_a);
			return;
		}
		objType.fields.push(objVar);
	}

	// ------------------------------------------------------------
	// statements (VBCC pvtParseFunction plus the NTC built ins)
	// ------------------------------------------------------------

	function parseStatement(str_a)
	{
		var arrMatch = null;
		var intPos = 0;
		var strText = str_a;

		// With: .member means the With object's member
		if (left(strText, 'with '))
		{
			arrWith.push(withName(trim(strText.substr(5))));
			return;
		}
		if ((strText === 'end with'))
		{
			if (arrWith.length === 0)
			{
				error('End With without With');
			}
			arrWith.pop();
			return;
		}
		if (arrWith.length > 0)
		{
			strText = withRewrite(strText, arrWith[arrWith.length - 1]);
		}

		// a built in statement word used as a variable: mode = 2
		if (/^(cls|locate|mode|frame|poke|doke|randomize|break|turbo|beep|doevents)\s*(\(.*\))?\s*=/.test(strText))
		{
			parseAssign(strText, false);
			return;
		}

		switch (true)
		{
			case strText.length === 0:
			case left(strText, 'rem ') || (strText === 'rem'):
				break;

			case left(strText, 'raise ') || left(strText, 'raiseevent '):
				error('events are not supported');
				break;

			case left(strText, 'on error ') || left(strText, 'resume'):
				error('On Error is not supported - NTC has no error handling: return a status from a Function and check it');
				break;

			case left(strText, 'redim '):
				parseRedim(strText.substr(6));
				break;

			case left(strText, 'erase '):
				record('erase', { names: splitTop(strText.substr(6), ',').map(function(str_a) { return trim(str_a); }) });
				break;

			case left(strText, 'const ') && blnInProc:
				declareConsts('local', strText.substr(6));
				break;

			case left(strText, 'dim ') && blnInProc:
				declareVars('local', strText.substr(4), false);
				break;

			case left(strText, 'static ') && blnInProc:
				declareVars('local', strText.substr(7), true);
				break;

			case left(strText, 'dim ') || left(strText, 'private ') || left(strText, 'public ') || left(strText, 'global ') || left(strText, 'const ') || left(strText, 'option '):
				parseModuleLevel(strText);
				break;

			case (arrMatch = strText.match(/^end (sub|function|property)$/)) !== null:
				procEnd(arrMatch[1]);
				break;

			case (arrMatch = strText.match(/^exit (sub|function|property|for|do|while)$/)) !== null:
				record('exit', { what: arrMatch[1] });
				break;

			case left(strText, 'select case '):
				record('select', { expr: strText.substr(12) });
				break;

			case strText === 'case else':
				record('caseelse', {});
				break;

			case left(strText, 'case '):
				record('case', { items: splitTop(strText.substr(5), ',') });
				break;

			case strText === 'end select':
				record('endselect', {});
				break;

			case left(strText, 'while '):
				record('while', { cond: strText.substr(6) });
				break;

			case strText === 'wend' || strText === 'end while':
				record('wend', {});
				break;

			case (arrMatch = strText.match(/^do(\s+(while|until)\s+(.+))?$/)) !== null:
				record('do', { cond: arrMatch[3] || '', until: arrMatch[2] === 'until' });
				break;

			case (arrMatch = strText.match(/^loop(\s+(while|until)\s+(.+))?$/)) !== null:
				record('loop', { cond: arrMatch[3] || '', until: arrMatch[2] === 'until' });
				break;

			case left(strText, 'for each '):
				if ((arrMatch = strText.match(/^for each ([a-z_][\w.]*[$%&!#@]?) in ([a-z_][\w.]*[$%&!#@]?)$/)) !== null)
				{
					record('foreach', { v: arrMatch[1], arr: arrMatch[2] });
				}
				else
				{
					error('For Each needs: For Each x In array');
				}
				break;

			case left(strText, 'for '):
				parseFor(strText.substr(4));
				break;

			case strText === 'next' || left(strText, 'next '):
				record('next', { vars: (strText.length > 5) ? splitTop(strText.substr(5), ',') : [] });
				break;

			case left(strText, 'if ') && right(strText, ' then'):
				record('if', { cond: strText.substr(3, strText.length - 8) });
				break;

			case left(strText, 'if '):
				parseSingleIf(strText);
				break;

			case left(strText, 'elseif ') && right(strText, ' then'):
				record('elseif', { cond: strText.substr(7, strText.length - 12) });
				break;

			case left(strText, 'else if ') && right(strText, ' then'):
				record('elseif', { cond: strText.substr(8, strText.length - 13) });
				break;

			case strText === 'else':
				record('else', {});
				break;

			case strText === 'end if' || strText === 'endif':
				record('endif', {});
				break;

			case (arrMatch = strText.match(/^on (.+?) (go\s?to|go\s?sub) (.+)$/)) !== null:
				record('ongoto', { expr: arrMatch[1], gosub: /sub$/.test(arrMatch[2]), targets: splitTop(arrMatch[3], ',') });
				break;

			case (arrMatch = strText.match(/^go\s?to (\S+)$/)) !== null:
				record('goto', { target: arrMatch[1] });
				break;

			case (arrMatch = strText.match(/^go\s?sub (\S+)$/)) !== null:
				record('gosub', { target: arrMatch[1] });
				break;

			case strText === 'return':
				record('return', {});
				break;

			case strText === 'end' || strText === 'stop':
				record('end', {});
				break;

			case strText === 'turbo on' || strText === 'turbo off':
				record('turbo', { on: strText === 'turbo on' });
				break;

			case left(strText, 'debug.print') && ((strText.length === 11) || (strText.substr(11, 1) === ' ')):
				record('print', { args: trim(strText.substr(11)) });
				break;

			case left(strText, 'print') && ((strText.length === 5) || (strText.substr(5, 1) === ' ')):
				record('print', { args: trim(strText.substr(5)) });
				break;

			case left(strText, '?'):
				record('print', { args: trim(strText.substr(1)) });
				break;

			case left(strText, 'input ') || (strText === 'input'):
				record('input', { args: trim(strText.substr(5)) });
				break;

			case strText === 'cls':
				record('cls', {});
				break;

			case strText === 'frame':
				record('frame', {});
				break;

			case strText === 'beep':
				break;		// no sound yet: accepted, does nothing

			case strText === 'doevents':
				parseCall('doevents', false);	// a safe point in normal mode
				break;

			case left(strText, 'locate '):
				record('locate', { args: splitTop(strText.substr(7), ',') });
				break;

			case left(strText, 'mode '):
				record('mode', { expr: strText.substr(5) });
				break;

			case left(strText, 'poke '):
				record('poke', { args: splitTop(strText.substr(5), ','), word: false });
				break;

			case left(strText, 'doke '):
				record('poke', { args: splitTop(strText.substr(5), ','), word: true });
				break;

			case left(strText, 'randomize') && ((strText.length === 9) || (strText.substr(9, 1) === ' ')):
				record('randomize', { expr: trim(strText.substr(9)) });
				break;

			case (arrMatch = strText.match(/^break(\s+([a-z_]\w*))?$/)) !== null:
				record('break', { name: arrMatch[2] || '' });
				break;

			case left(strText, 'call '):
				parseCall(trim(strText.substr(5)), true);
				break;

			case left(strText, 'set '):
				parseAssign(strText.substr(4), true);
				break;

			case left(strText, 'let '):
				parseAssign(strText.substr(4), false);
				break;

			default:
				// VBCC function_expression: assignment or procedure call
				intPos = assignPos(strText);
				if (intPos > -1)
				{
					parseAssign(strText, false);
				}
				else
				{
					parseCall(strText, false);
				}
				break;
		}
	}

	// the With object itself may start with . (nested With)
	function withName(str_a)
	{
		if ((str_a.substr(0, 1) === '.') && (arrWith.length > 0))
		{
			return arrWith[arrWith.length - 1] + str_a;
		}

		return str_a;
	}

	// .member (not after a name, number, ) or quote) -> object.member
	function withRewrite(str_a, strObject_a)
	{
		var blnInString = false;
		var intI = 0;
		var strChar = '';
		var strPrev = ' ';
		var strResult = '';

		for (intI = 0; intI < str_a.length; intI++)
		{
			strChar = str_a.substr(intI, 1);
			if (strChar === '"')
			{
				blnInString = !blnInString;
			}
			if (!blnInString && (strChar === '.') && !/[\w)"$]/.test(strPrev) && /[a-z_]/.test(str_a.substr(intI + 1, 1)))
			{
				strResult += strObject_a;
			}
			strResult += strChar;
			if (strChar !== ' ')
			{
				strPrev = strChar;
			}
			else
			{
				strPrev = ' ';
			}
		}

		return strResult;
	}

	// position of the = of an assignment (outside quotes / brackets) or -1
	function assignPos(str_a)
	{
		var arrParts = splitTop(str_a, '=');

		if ((arrParts.length > 1) && /^\s*[a-z_][\w.]*[%&!#@$]?\s*(\(.*\))?(\.[a-z_]\w*)?\s*$/.test(arrParts[0]))
		{
			return arrParts[0].length;
		}

		return -1;
	}

	function parseAssign(str_a, blnSet_a)
	{
		var intPos = assignPos(str_a);

		if (intPos < 0)
		{
			error('bad assignment: ' + str_a);
			return;
		}
		record('assign', { target: trim(str_a.substr(0, intPos)), expr: trim(str_a.substr(intPos + 1)), set: blnSet_a });
	}

	// "name args" / "name(args)" / "obj.method args" / call name(args) / call addr
	function parseCall(str_a, blnCall_a)
	{
		var arrMatch = str_a.match(/^([a-z_][\w.]*[%&!#@$]?)\s*(.*)$/);
		var strArgs = '';
		var strName = '';

		if (!arrMatch)
		{
			if (blnCall_a)
			{
				record('callm', { expr: str_a });	// machine code address
			}
			else
			{
				error('unknown statement: ' + str_a);
			}
			return;
		}
		strName = arrMatch[1];
		strArgs = trim(arrMatch[2]);
		// name(args) with nothing after the bracket: the brackets hold the args
		if ((strArgs.substr(0, 1) === '(') && (splitTop(strArgs, ' ')[0] === strArgs || matchingBracket(strArgs) === strArgs.length - 1))
		{
			if (matchingBracket(strArgs) === strArgs.length - 1)
			{
				strArgs = strArgs.substr(1, strArgs.length - 2);
			}
		}
		record('call', { name: strName, args: (trim(strArgs).length > 0) ? splitTop(strArgs, ',') : [], explicit: blnCall_a, raw: str_a });
	}

	function matchingBracket(str_a)
	{
		var blnInString = false;
		var intDepth = 0;
		var intI = 0;
		var strChar = '';

		for (intI = 0; intI < str_a.length; intI++)
		{
			strChar = str_a.substr(intI, 1);
			if (strChar === '"')
			{
				blnInString = !blnInString;
			}
			else if (!blnInString)
			{
				if (strChar === '(')
				{
					intDepth++;
				}
				else if (strChar === ')')
				{
					intDepth--;
					if (intDepth === 0)
					{
						return intI;
					}
				}
			}
		}

		return -1;
	}

	// for v = a to b [step s]
	function parseFor(str_a)
	{
		var intEq = str_a.indexOf('=');
		var intTo = 0;
		var intStep = 0;
		var strRest = '';
		var strVar = '';

		if (intEq < 0)
		{
			error('bad FOR');
			return;
		}
		strVar = trim(str_a.substr(0, intEq));
		strRest = str_a.substr(intEq + 1);
		intTo = findWord(strRest, 'to');
		if (intTo < 0)
		{
			error('FOR without TO');
			return;
		}
		intStep = findWord(strRest, 'step', intTo + 2);
		record('for', {
			v: strVar,
			start: trim(strRest.substr(0, intTo)),
			limit: trim((intStep > -1) ? strRest.substring(intTo + 2, intStep) : strRest.substr(intTo + 2)),
			step: (intStep > -1) ? trim(strRest.substr(intStep + 4)) : ''
		});
	}

	// if c then s : s [else s : s] on one line - becomes block records
	function parseSingleIf(str_a)
	{
		var intThen = findWord(str_a, 'then');
		var intElse = 0;
		var strCond = '';
		var strThen = '';
		var strElse = '';
		var arrMatch = null;

		if (intThen < 0)
		{
			// if c goto n (old form)
			if ((arrMatch = str_a.match(/^if (.+?) go\s?to (\S+)$/)))
			{
				record('ifgoto', { cond: arrMatch[1], target: arrMatch[2] });
				return;
			}
			error('IF without THEN');
			return;
		}
		strCond = trim(str_a.substring(3, intThen));
		strThen = str_a.substr(intThen + 4);
		intElse = findElse(strThen);
		if (intElse > -1)
		{
			strElse = trim(strThen.substr(intElse + 4));
			strThen = trim(strThen.substr(0, intElse));
		}
		else
		{
			strThen = trim(strThen);
		}

		// if c then 100 / if c then goto lbl - one branch
		if ((intElse < 0) && ((arrMatch = strThen.match(/^(go\s?to\s+)?(\S+)$/)) && (/^\d+$/.test(arrMatch[2]) || arrMatch[1])))
		{
			record('ifgoto', { cond: strCond, target: arrMatch[2] });
			return;
		}

		record('if', { cond: strCond, single: true });
		parseInline(strThen);
		if (intElse > -1)
		{
			record('else', { single: true });
			parseInline(strElse);
		}
		record('endif', { single: true });
	}

	// the else that belongs to this if: an inner if takes the first else after it
	function findElse(str_a)
	{
		var intDepth = 0;
		var intIf = 0;
		var intElse = 0;
		var intPos = 0;

		while (true)
		{
			intIf = findWord(str_a, 'if', intPos);
			intElse = findWord(str_a, 'else', intPos);
			if (intElse < 0)
			{
				return -1;
			}
			if ((intIf > -1) && (intIf < intElse))
			{
				intDepth++;
				intPos = intIf + 2;
			}
			else if (intDepth === 0)
			{
				return intElse;
			}
			else
			{
				intDepth--;
				intPos = intElse + 4;
			}
		}
	}

	// statements inside a single line if (a number alone is a goto)
	function parseInline(str_a)
	{
		var objText = { s: str_a };
		var strStatement = '';

		while (objText.s.length > 0)
		{
			if (left(trim(objText.s), 'if '))
			{
				parseStatement(trim(objText.s));	// a nested if takes the rest
				return;
			}
			strStatement = statementTok(objText);
			if (/^\d+$/.test(strStatement))
			{
				record('goto', { target: strStatement });
			}
			else if (strStatement.length > 0)
			{
				parseStatement(strStatement);
			}
		}
	}

	// ------------------------------------------------------------
	// one statement in its context (VBCC pvtParseStatement)
	// ------------------------------------------------------------

	function dispatch(str_a)
	{
		if (directive(str_a))
		{
			return;
		}
		if (skipping())
		{
			return;
		}
		if (objEnum !== null)
		{
			parseEnumLevel(str_a);
			return;
		}
		if (blnInType)
		{
			parseTypeLevel(str_a);
		}
		else if (blnInProc)
		{
			parseStatement(str_a);
		}
		else
		{
			parseModuleLevel(str_a);
		}
	}

	function parseLine(strLine_a)
	{
		var arrMatch = null;
		var blnFirst = true;
		var objText = { s: normalise(strLine_a) };
		var strStatement = '';

		// line number
		if ((arrMatch = objText.s.match(/^(\d+)\s*(.*)$/)))
		{
			if (!skipping())
			{
				record('label', { name: arrMatch[1], number: true });
			}
			objText.s = arrMatch[2];
		}

		while (objText.s.length > 0)
		{
			// a single line if takes the whole rest of the line
			if (left(objText.s, 'if ') && !right(objText.s.split(':')[0], ' then') && (findWord(objText.s, 'then') > -1) && !right(trim(objText.s), ' then'))
			{
				strStatement = objText.s;
				objText.s = '';
			}
			else
			{
				strStatement = statementTok(objText);
			}

			// label:
			if (blnFirst && /^[a-z_]\w*$/.test(strStatement) && (NTC_STATEMENT_WORDS.indexOf(strStatement) < 0) && !blnInType && (objText.s.length > 0 || true) && lineHadColon(strLine_a, strStatement))
			{
				if (!skipping())
				{
					record('label', { name: strStatement, number: false });
				}
				blnFirst = false;
				continue;
			}
			blnFirst = false;

			if (strStatement.length > 0)
			{
				dispatch(strStatement);
			}
		}
	}

	// was "word" followed by : on the original line (label) rather than a lone statement
	function lineHadColon(strLine_a, strWord_a)
	{
		var strNorm = normalise(strLine_a).replace(/^\d+\s*/, '');

		return left(strNorm, strWord_a + ':');
	}

	// ------------------------------------------------------------
	// main
	// ------------------------------------------------------------

	var arrLines = [];
	var intI = 0;
	var intJ = 0;
	var objFile = null;
	var strExt = '';
	var strJoined = '';
	var strName = '';
	var objPublicProcs = {};		// public procedure names in .bas files
	var objAsm = null;				// open #asm block { line, lines }
	var blnPubMember = false;		// declaring Public members of a class
	var arrProcMatch = null;

	// a module named like a public procedure (ShellSort in shellsort.bas)
	// would share names with the procedure's locals: such a module gets _mod
	for (intI = 0; intI < arrFiles_a.length; intI++)
	{
		if (!/\.cls$/i.test(arrFiles_a[intI].name || ''))
		{
			arrLines = String(arrFiles_a[intI].text || '').split(/\r\n?|\n/);
			for (intJ = 0; intJ < arrLines.length; intJ++)
			{
				arrProcMatch = arrLines[intJ].match(/^\s*(?:(public|global|friend|private)\s+)?(?:static\s+)?(?:sub|function|property\s+(?:get|let|set))\s+([a-z_]\w*)/i);
				if (arrProcMatch && ((arrProcMatch[1] || '').toLowerCase() !== 'private'))
				{
					objPublicProcs[arrProcMatch[2].toLowerCase()] = true;
				}
			}
		}
	}

	for (intI = 0; intI < arrFiles_a.length; intI++)
	{
		objFile = arrFiles_a[intI];
		strFile = objFile.name || ('file' + intI);
		intFile = intI;
		strExt = (strFile.lastIndexOf('.') > -1) ? strFile.substr(strFile.lastIndexOf('.') + 1).toLowerCase() : 'bas';
		strName = strFile.replace(/^.*[\/\\]/, '').replace(/\.[^.]*$/, '').toLowerCase().replace(/[^\w]/g, '_');
		blnInClass = (strExt === 'cls');
		blnInProc = false;
		blnInType = false;
		strProc = '';
		arrSkip = [];

		arrLines = String(objFile.text || '').replace(/\r\n?/g, '\n').split('\n');

		// Attribute VB_Name = "x" names the module / class
		for (intJ = 0; intJ < arrLines.length; intJ++)
		{
			var arrName = arrLines[intJ].match(/^\s*Attribute\s+VB_Name\s*=\s*"([^"]+)"/i);
			if (arrName)
			{
				strName = arrName[1].toLowerCase();
				break;
			}
		}
		if (objPublicProcs[strName] === true)
		{
			strName += '_mod';
		}
		strModule = strName;
		intLine = 0;
		if (elementAdd(blnInClass ? 'class' : 'module', 'global', '#' + strModule, strModule, {}) === null)
		{
			error('module name used twice: ' + strModule);
		}
		record(blnInClass ? 'class' : 'module', { name: strModule });

		// VB form / class headers (VERSION, BEGIN ... END) are skipped
		intJ = 0;
		while ((intJ < arrLines.length) && /^\s*(VERSION\s|Object\s*=|BEGIN\b|END\s*$|MultiUse|Persistable|DataBindingBehavior|DataSourceBehavior|MTSTransactionMode)/i.test(arrLines[intJ]))
		{
			intJ++;
		}

		strJoined = '';
		objAsm = null;
		for (; intJ < arrLines.length; intJ++)
		{
			// #asm ... #endasm: Z80 lines kept as they are
			if (objAsm !== null)
			{
				if (/^\s*#endasm\b/i.test(arrLines[intJ]))
				{
					if (!skipping())
					{
						intLine = objAsm.line;
						strSrc = '#asm';
						record('asm', { lines: objAsm.lines, endline: intJ + 1 });
					}
					objAsm = null;
				}
				else
				{
					objAsm.lines.push(arrLines[intJ].replace(/\s+$/, ''));
				}
				continue;
			}
			if (/^\s*#asm\b/i.test(arrLines[intJ]) && (strJoined.length === 0))
			{
				objAsm = { line: intJ + 1, lines: [] };
				continue;
			}
			if (/^\s*#endasm\b/i.test(arrLines[intJ]))
			{
				intLine = intJ + 1;
				error('#endasm without #asm');
				continue;
			}
			// line continuation: " _" at the end
			if (/\s_\s*$/.test(arrLines[intJ]))
			{
				if (strJoined.length === 0)
				{
					intLine = intJ + 1;
				}
				strJoined += arrLines[intJ].replace(/\s_\s*$/, ' ');
				continue;
			}
			if (strJoined.length === 0)
			{
				intLine = intJ + 1;
			}
			strSrc = (strJoined + arrLines[intJ]).replace(/^\s+|\s+$/g, '');
			parseLine(strJoined + arrLines[intJ]);
			strJoined = '';
		}
		if (strJoined.length > 0)
		{
			parseLine(strJoined);
		}
		if (objAsm !== null)
		{
			intLine = objAsm.line;
			error('#asm is not closed (#endasm)');
			objAsm = null;
		}

		if (blnInProc)
		{
			error(objProc.kind + ' ' + objProc.id + ' is not closed');
			record('procend', { full: strProc });
			blnInProc = false;
			strProc = '';
		}
		if (blnInType)
		{
			error('Type is not closed');
			blnInType = false;
		}
		if (objEnum !== null)
		{
			error('Enum is not closed');
			objEnum = null;
		}
		if (arrWith.length > 0)
		{
			error('With is not closed');
			arrWith = [];
		}
		if (arrSkip.length > 0)
		{
			error('#if is not closed');
		}
		record(blnInClass ? 'classend' : 'moduleend', { name: strModule });
	}

	return {
		records: arrRecords,
		elements: objElements,
		procs: arrProcs,
		defines: objDefines,
		errors: arrErrors
	};
}
