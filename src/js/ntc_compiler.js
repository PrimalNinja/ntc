// ntc_compiler.js - VB5/VB6 style BASIC to NTC (Native Threaded Code). ES5.
// Developed by Julian Cassin. 2019-2026.
// (c) 2026 Cyborg Unicorn Pty Ltd - MIT License
//
// Needs ntc_parser.js (ntcParse, IFtoPF) and ntc_lib.js (the library text).
//
// Structure:
//	- ntcParse turns the source files into statement records and the
//	  element table (VBCC concept: prefix dispatch, context flags)
//	- this file walks the records one by one and emits the thread.
//	  Expressions: IFtoPF (shunting yard) to postfix, then a postfix walk
//	  with a value stack, one keyword per operation into tmpN / stmpN.
//	- no parse tree, no recursive descent
//
// Passes: pass 1 (run twice) walks every record to settle the types of
// undeclared variables, collect labels, GOSUB targets, procedure calls and
// the turbo / normal mode at each call. Then GOSUB keyword forms, the
// call graph (no recursion) and the modes each procedure is needed in are
// worked out. Pass 2 emits the main thread and each procedure once per
// mode it is called in.
//
// Usage:
//	var objResult = ntcCompile(strSource, { platform: 'cpc', org: '#4000', library: 'used', turbo: false });
//	var objResult = ntcCompile([{ name: 'Main.bas', text: '...' }, { name: 'Shapes.cls', text: '...' }], {...});
//	objResult.asm		- assembler source
//	objResult.errors	- [{ file, line, msg }]
//	objResult.stats		- { threadbytes, keywords, variables, temps }

function ntcCompile(input_a, objOptions_a)
{
	var objOptions = {
		org: '#4000',
		library: 'used',		// used, all, none
		platform: 'cpc',		// key into NTC_PLATFORMS
		sourcecomments: true,
		turbo: false,			// start in turbo mode (same as Option Turbo)
		libtext: null,
		platformtext: null
	};

	var BINARY = { '^': 1, '*': 1, '/': 1, '\\': 1, 'MOD': 1, '+': 1, '-': 1, '&': 1, '=': 1, '<>': 1, '<': 1, '<=': 1, '>': 1, '>=': 1, 'AND': 1, 'OR': 1, 'XOR': 1, 'LIKE': 1 };
	var COMPARE = { '=': 'eq', '<>': 'ne', '<': 'lt', '<=': 'le', '>': 'gt', '>=': 'ge' };
	var FLIP = { '=': '=', '<>': '<>', '<': '>', '<=': '>=', '>': '<', '>=': '<=' };
	var NTC_SCREEN_KEYWORDS = ['kw_printzoscii', 'kw_printstrvar', 'kw_printint', 'kw_printnl', 'kw_inputstr', 'kw_inputint', 'kw_inkey', 'kw_inkeys', 'kw_cls', 'kw_locatell', 'kw_locatevv', 'kw_l_print', 'kw_l_input', 'kw_printtab', 'kw_printnl0', 'kw_printintvb', 'kw_l_printvb', 'kw_printzone'];
	var BRANCH_LABEL_ARG = { 'kw_goto': 0, 'kw_goto_iftrue': 0, 'kw_goto_iffalse': 0, 'kw_goto_ifzero': 1, 'kw_goto_ifnzero': 1, 'kw_forentry': 3, 'kw_fornext': 3,
		'kw_forupl': 2, 'kw_forupv': 2, 'kw_fordnl': 2, 'kw_fordnv': 2, 'kw_next1l': 2, 'kw_next1v': 2,
		'kw_nextupl': 3, 'kw_nextupv': 3, 'kw_nextdnl': 3, 'kw_nextdnv': 3 };
	var DECLARATION_KINDS = { 'module': 1, 'moduleend': 1, 'class': 1, 'classend': 1, 'option': 1, 'dim': 1, 'const': 1, 'type': 1, 'typeend': 1, 'enum': 1 };

	// built in functions: [min args, max args, result n/s, argument kinds]
	var BUILTINS = {
		'abs': [1, 1, 'n'], 'sgn': [1, 1, 'n'], 'peek': [1, 1, 'n'], 'deek': [1, 1, 'n'], 'rnd': [1, 1, 'n'],
		'lbound': [1, 2, 'n'], 'ubound': [1, 2, 'n'], 'inp': [1, 1, 'n'], 'sqr': [1, 1, 'n'],
		'iif': [3, 3, '?'], 'choose': [2, 9, '?'], 'strcomp': [2, 3, 'n'], 'instrrev': [2, 3, 'n'],
		'replace': [3, 3, 's'], 'replace$': [3, 3, 's'], 'format': [1, 2, 's'], 'format$': [1, 2, 's'], 'join': [1, 2, 's'], 'join$': [1, 2, 's'], 'strreverse': [1, 1, 's'], 'oct': [1, 1, 's'], 'oct$': [1, 1, 's'],
		'int': [1, 1, 'n'], 'fix': [1, 1, 'n'], 'cint': [1, 1, 'n'], 'clng': [1, 1, 'n'], 'cbool': [1, 1, 'n'], 'cbyte': [1, 1, 'n'],
		'len': [1, 1, 'n'], 'asc': [1, 1, 'n'], 'val': [1, 1, 'n'], 'instr': [2, 3, 'n'],
		'left': [2, 2, 's'], 'left$': [2, 2, 's'], 'right': [2, 2, 's'], 'right$': [2, 2, 's'],
		'mid': [2, 3, 's'], 'mid$': [2, 3, 's'], 'chr': [1, 1, 's'], 'chr$': [1, 1, 's'],
		'str': [1, 1, 's'], 'str$': [1, 1, 's'], 'cstr': [1, 1, 's'], 'hex': [1, 1, 's'], 'hex$': [1, 1, 's'],
		'space': [1, 1, 's'], 'space$': [1, 1, 's'], 'spc': [1, 1, 's'], 'string': [2, 2, 's'], 'string$': [2, 2, 's'],
		'ucase': [1, 1, 's'], 'ucase$': [1, 1, 's'], 'lcase': [1, 1, 's'], 'lcase$': [1, 1, 's'],
		'ltrim': [1, 1, 's'], 'ltrim$': [1, 1, 's'], 'rtrim': [1, 1, 's'], 'rtrim$': [1, 1, 's'], 'trim': [1, 1, 's'], 'trim$': [1, 1, 's']
	};

	var objParse = null;
	var objEl = {};
	var arrRecords = [];
	var arrMainRecs = [];
	var objProcRecs = {};
	var arrProcOrder = [];

	var intRun = 0;
	var intPass = 1;
	var intLine = 0;
	var strFile = '';
	var strModule = '';
	var strFirstModule = '';
	var strProc = '';			// current procedure full name, '' = main
	var blnInClass = false;
	var strCopy = '';			// label suffix for the normal mode copy of a procedure
	var strMode = 't';			// current mode: t = turbo, n = normal, E = the procedure's entry mode (pass 1)
	var strStartMode = 't';
	var intLastComment = -1;
	var strLastCommentFile = '';
	var strProcEntry = '';		// mode a procedure copy started in

	var objExplicit = {};		// module -> Option Explicit
	var objBase = {};			// module -> Option Base

	// pass 1 results
	var objScanStrAssign = {};
	var objScanNumAssign = {};
	var objScanInput = {};
	var objScanNumUse = {};
	var objScanStrUse = {};
	var objTypes = {};
	var objLabels = {};			// label -> line
	var objWritten = {};		// param full -> written in its procedure
	var objDynMax = {};			// dynamic array full -> most bytes any ReDim asks for
	var blnVBPrint = false;		// Option VBPrint: numbers with spaces, comma = 14 column zones
	var objHookProcs = {};		// Subs set with Interrupt Name (their return lets the hook run again)
	var blnHookUsed = false;
	var objCompareText = {};	// module -> Option Compare Text
	var arrScanProcCalls = [];	// { from, to, mode, line, file }
	var objProcModes = {};		// proc full -> { t: true, n: true }

	// per pass state
	var arrOut = [];
	var arrErrors = [];
	var arrWarnings = [];		// [{ file, line, msg }] - not errors, the program still builds
	var objErrorSeen = {};
	var arrDecl = [];
	var objDecl = {};
	var arrStrings = [];
	var objStrings = {};
	var objLits = {};
	var arrLits = [];
	var arrCtl = [];
	var arrBreakpoints = [];
	var objBreakpoints = {};
	var arrLabelRefs = [];
	var intLabelId = 0;
	var intMaxTemp = -1;
	var intMaxSTemp = -1;
	var intMaxLTemp = -1;
	var blnGosub = false;
	var objGlyphs = {};
	var objLabelMode = {};		// emitted label -> mode at that label
	var arrGotoRefs = [];		// { label, mode, line, file }
	var arrProcStubs = [];		// code lines for procedure call / return stubs
	var objProcStubDone = {};
	var arrAsmBlocks = [];		// #asm blocks { name, lines }
	var objAsmDone = {};
	var objLabelNames = {};		// element full -> label
	var objLabelUsed = {};		// label -> element full
	var objConstCache = {};

	// GOSUB as keywords (pass 1 collects, then decided once)
	var blnLastTransfer = false;
	var arrScanJumps = [];		// { label, line, proc }
	var arrScanCalls = [];		// { label, line, proc } GOSUB
	var arrScanReturns = [];	// { line, proc }
	var objScanFallIn = {};
	var arrSubs = [];			// GOSUB targets sorted by line { label, line, proc }
	var objFastSub = {};
	var objFastUse = {};		// emitted fast GOSUB label -> true
	var arrFastUse = [];
	var objGotoStubs = {};
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

	function trim(str_a)
	{
		return String(str_a).replace(/^\s+|\s+$/g, '');
	}

	function error(strMessage_a)
	{
		var strKey = strFile + ':' + intLine + ':' + strMessage_a;

		if ((intPass === 2) && (objErrorSeen[strKey] === undefined))
		{
			objErrorSeen[strKey] = true;
			arrErrors.push({ file: strFile, line: intLine, msg: strMessage_a });
		}
	}

	function warning(strMessage_a)
	{
		var strKey = 'W' + strFile + ':' + intLine + ':' + strMessage_a;

		if ((intPass === 2) && (objErrorSeen[strKey] === undefined))
		{
			objErrorSeen[strKey] = true;
			arrWarnings.push({ file: strFile, line: intLine, msg: strMessage_a });
		}
	}

	function errorAlways(strMessage_a)
	{
		var strKey = strFile + ':' + intLine + ':' + strMessage_a;

		if (objErrorSeen[strKey] === undefined)
		{
			objErrorSeen[strKey] = true;
			arrErrors.push({ file: strFile, line: intLine, msg: strMessage_a });
		}
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

	function newId()
	{
		intLabelId++;
		return intLabelId;
	}

	function exitCode(strMode_a)
	{
		return (strMode_a === 'n') ? 'jp ntc_xn' : 'ret';
	}

	function kwMode()
	{
		return (strMode === 'n') ? 'n' : 't';
	}

	// ------------------------------------------------------------
	// elements, names, types
	// ------------------------------------------------------------

	function splitSuffix(str_a)
	{
		var strLast = str_a.substr(str_a.length - 1, 1);
		var objTypes = { '%': 'int', '&': 'long', '!': 'single', '#': 'double', '@': 'cur', '$': 'str' };

		if ((str_a.length > 1) && (objTypes[strLast] !== undefined))
		{
			return { name: str_a.substr(0, str_a.length - 1), type: objTypes[strLast] };
		}

		return { name: str_a, type: '' };
	}

	function isUdt(strType_a)
	{
		return (objEl[strType_a] !== undefined) && (objEl[strType_a].etype === 'type');
	}

	function isClass(strType_a)
	{
		return (objEl['#' + strType_a] !== undefined) && (objEl['#' + strType_a].etype === 'class');
	}

	// int / str / udt name / class name
	function typeOfEl(objEl_a)
	{
		var strType = objEl_a.datatype || '';

		switch (strType)
		{
			case 'int':
			case 'byte':
			case 'bool':
				return 'int';
			case 'str':
				return 'str';
			case '':
			case 'variant':
				return (objTypes[objEl_a.full] !== undefined) ? objTypes[objEl_a.full] : 'int';
			case 'long':
				return 'long';
			case 'single':
			case 'double':
			case 'cur':
			case 'object':
				error(objEl_a.id + ': type ' + strType + ' is not supported yet (Integer, Long, Byte, Boolean, String)');
				return 'int';
			default:
				return (objEl['#enum.' + strType] !== undefined) ? 'int' : strType;
		}
	}

	function cleanLabel(str_a)
	{
		return str_a.replace(/[^\w]/g, '_');
	}

	// storage label for an element (unique)
	function labelOf(objEl_a, strPrefix_a)
	{
		var strName = objEl_a.full;
		var strLabel = '';
		var intN = 2;

		if (objLabelNames[objEl_a.full] !== undefined)
		{
			return objLabelNames[objEl_a.full];
		}
		if ((strFirstModule.length > 0) && (strName.substr(0, strFirstModule.length + 1) === strFirstModule + '.'))
		{
			strName = strName.substr(strFirstModule.length + 1);
		}
		strLabel = strPrefix_a + cleanLabel(strName);
		while ((objLabelUsed[strLabel] !== undefined) && (objLabelUsed[strLabel] !== objEl_a.full))
		{
			strLabel = strPrefix_a + cleanLabel(strName) + '_' + intN;
			intN++;
		}
		objLabelUsed[strLabel] = objEl_a.full;
		objLabelNames[objEl_a.full] = strLabel;

		return strLabel;
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

	// String * n: n (1 .. 40), else 0
	function fixedLen(objEl_a)
	{
		var objValue = null;
		var strSaveModule = strModule;
		var strSaveProc = strProc;

		if (!objEl_a || !objEl_a.fixed || (typeOfEl(objEl_a) !== 'str'))
		{
			return 0;
		}
		strModule = objEl_a.module;
		strProc = objEl_a.proc || '';
		objValue = evalConst(String(objEl_a.fixed));
		strModule = strSaveModule;
		strProc = strSaveProc;
		if ((objValue === null) || (objValue.k !== 'l') || (objValue.v < 1) || (objValue.v > 40))
		{
			error('String * n: n must be a constant 1 .. 40 (' + objEl_a.id + ')');
			return 0;
		}

		return objValue.v;
	}

	// label of a scalar variable / param / function result, declared
	function varLabel(objEl_a)
	{
		var strLabel = labelOf(objEl_a, 'var_');

		if (fixedLen(objEl_a) > 0)
		{
			declare(strLabel, 'strfix', fixedLen(objEl_a));		// starts as n spaces
			return strLabel;
		}
		declare(strLabel, (typeOfEl(objEl_a) === 'str') ? 'str' : ((typeOfEl(objEl_a) === 'long') ? 'long' : 'int'), 0);

		return strLabel;
	}

	function procBase(objProc_a)
	{
		var strName = objProc_a.full;

		if ((strFirstModule.length > 0) && (strName.substr(0, strFirstModule.length + 1) === strFirstModule + '.'))
		{
			strName = strName.substr(strFirstModule.length + 1);
		}

		return 'p_' + cleanLabel(strName);
	}

	// label of a procedure's body for a mode (normal copy gets _n when there are two)
	function procLabel(objProc_a, strMode_a)
	{
		var objModes = objProcModes[objProc_a.full] || {};

		return procBase(objProc_a) + (((strMode_a === 'n') && objModes.t && objModes.n) ? '_n' : '');
	}

	function find(strFull_a)
	{
		var objResult = objEl[strFull_a];

		return ((objResult !== undefined) && (objResult.etype !== 'module') && (objResult.etype !== 'class')) ? objResult : null;
	}

	// a class member: var / const / proc / property
	function classMember(strClass_a, strMember_a, blnWrite_a)
	{
		var objResult = find(strClass_a + '.' + strMember_a);

		if (objResult === null)
		{
			objResult = find(strClass_a + '.' + strMember_a + (blnWrite_a ? '.let' : '.get'));
			if ((objResult === null) && blnWrite_a)
			{
				objResult = find(strClass_a + '.' + strMember_a + '.set');
			}
		}
		// a Private member used from outside its class
		if ((objResult !== null) && (strModule !== strClass_a) && (objResult.scope === 'module') && !objResult.pub)
		{
			error(strClass_a + '.' + strMember_a + ' is Private');
		}

		return objResult;
	}

	// name -> element (null if not found). blnImplicit_a: make an undeclared variable
	function resolve(strName_a, blnImplicit_a, blnWrite_a)
	{
		var objSuffix = splitSuffix(strName_a.toLowerCase());
		var strName = objSuffix.name;
		var arrParts = [];
		var objBase = null;
		var objResult = null;
		var strType = '';
		var strRest = '';

		if (strName.indexOf('.') > -1)
		{
			arrParts = strName.split('.');
			strRest = arrParts.slice(1).join('.');

			// me.member inside a class
			if ((arrParts[0] === 'me') && blnInClass)
			{
				return classMember(strModule, strRest, blnWrite_a);
			}

			objBase = resolve(arrParts[0], false, false);
			if (objBase !== null)
			{
				strType = objBase.datatype || '';
				if (objBase.udt)
				{
					return find(objBase.full + '.' + strRest);
				}
				if (isClass(strType))
				{
					return classMember(strType, strRest, blnWrite_a);
				}
				return null;
			}

			// EnumName.Member
			if (objEl['#enum.' + arrParts[0]] !== undefined)
			{
				return find(strName);
			}

			// module.name / class.name
			if (objEl['#' + arrParts[0]] !== undefined)
			{
				objResult = classMember(arrParts[0], strRest, blnWrite_a);
				if (objResult === null)
				{
					objResult = find(strRest);
				}
				return objResult;
			}

			return null;
		}

		if (strProc.length > 0)
		{
			objResult = find(strProc + '.' + strName);
			if (objResult !== null)
			{
				return implicitCheck(objResult);
			}
		}
		objResult = find(strModule + '.' + strName);
		if (objResult !== null)
		{
			return implicitCheck(objResult);
		}
		if (blnInClass)
		{
			objResult = classMember(strModule, strName, blnWrite_a);
			if (objResult !== null)
			{
				return objResult;
			}
		}
		objResult = find(strName);
		if (objResult !== null)
		{
			return objResult;
		}

		if (blnImplicit_a)
		{
			if (objExplicit[strModule])
			{
				error('not declared: ' + strName + ' (Option Explicit)');
			}
			objResult = {
				etype: 'var', scope: (strProc.length > 0) ? 'local' : 'module',
				full: ((strProc.length > 0) ? strProc : strModule) + '.' + strName,
				id: strName, module: strModule, proc: strProc,
				datatype: objSuffix.type, typed: (objSuffix.type.length > 0), implicit: true
			};
			if ((objSuffix.type !== '') && (objSuffix.type !== 'str') && (objSuffix.type !== 'int') && (objSuffix.type !== 'long'))
			{
				error(strName + ': type ' + objSuffix.type + ' is not supported yet');
				objResult.datatype = 'int';
			}
			objEl[objResult.full] = objResult;
		}

		return objResult;
	}

	// an undeclared variable (made in pass 1) under Option Explicit
	function implicitCheck(objEl_a)
	{
		if (objEl_a.implicit && objExplicit[objEl_a.module])
		{
			error('not declared: ' + objEl_a.id + ' (Option Explicit)');
		}

		return objEl_a;
	}

	// UDT variables become one variable per field (name.field)
	function expandUdts()
	{
		var arrQueue = [];
		var intI = 0;
		var objField = null;
		var objNew = null;
		var objType = null;
		var objItem = null;
		var strKey = '';

		for (strKey in objEl)
		{
			if (objEl.hasOwnProperty(strKey) && ((objEl[strKey].etype === 'var') || (objEl[strKey].etype === 'array') || (objEl[strKey].etype === 'param')) && isUdt(objEl[strKey].datatype || ''))
			{
				arrQueue.push(objEl[strKey]);
			}
		}

		while (arrQueue.length > 0)
		{
			objItem = arrQueue.shift();
			if (objItem.udt)
			{
				continue;
			}
			objItem.udt = true;
			objType = objEl[objItem.datatype];
			for (intI = 0; intI < objType.fields.length; intI++)
			{
				objField = objType.fields[intI];
				objNew = {
					etype: ((objItem.etype === 'array') || (objField.dims !== null)) ? 'array' : 'var',
					scope: objItem.scope, full: objItem.full + '.' + objField.name, id: objItem.id + '.' + objField.name,
					module: objItem.module, proc: objItem.proc, file: objItem.file, line: objItem.line,
					datatype: objField.type, typed: true, fixed: objField.fixed,
					dims: (objItem.etype === 'array') ? objItem.dims : objField.dims, isstatic: objItem.isstatic
				};
				// a field of an array of a Type parameter: an array parameter with its own descriptor
				if ((objItem.etype === 'array') && (objItem.index !== undefined))
				{
					objNew.index = objItem.index;
					if (objField.dims !== null)
					{
						intLine = objItem.line;
						strFile = objItem.file;
						error('a Type with an array inside can not be a parameter: ' + objItem.id);
					}
				}
				// a field of a Type parameter: filled by the call stub, not zeroed
				if ((objItem.etype === 'param') || objItem.pfield)
				{
					objNew.pfield = objItem.pfield || objItem.full;
					if (objField.dims !== null)
					{
						intLine = objItem.line;
						strFile = objItem.file;
						error('a Type with an array inside can not be a parameter: ' + objItem.id);
					}
				}
				if ((objItem.etype === 'array') && (objField.dims !== null))
				{
					intLine = objItem.line;
					strFile = objItem.file;
					error('arrays inside an array of a Type are not supported: ' + objNew.id);
				}
				objEl[objNew.full] = objNew;
				if (isUdt(objField.type))
				{
					arrQueue.push(objNew);
				}
			}
		}
	}

	// ------------------------------------------------------------
	// literals, strings, temps
	// ------------------------------------------------------------

	function tmp(intIndex_a)
	{
		if (intIndex_a > intMaxTemp)
		{
			intMaxTemp = intIndex_a;
		}

		return 'tmp' + intIndex_a;
	}

	function stmp(intIndex_a)
	{
		if (intIndex_a > intMaxSTemp)
		{
			intMaxSTemp = intIndex_a;
		}

		return 'stmp' + intIndex_a;
	}

	function ltmp(intIndex_a)
	{
		if (intIndex_a > intMaxLTemp)
		{
			intMaxLTemp = intIndex_a;
		}

		return 'ltmp' + intIndex_a;
	}

	// a Long literal as the address of 4 bytes holding it
	function llitLabel(int_a)
	{
		var intValue = int_a | 0;
		var strLabel = 'llit_' + ((intValue < 0) ? ('m' + (-intValue)) : intValue);

		if (objLits[strLabel] === undefined)
		{
			objLits[strLabel] = (intValue & 0xffff) + ', ' + ((intValue >>> 16) & 0xffff);
			arrLits.push(strLabel);
		}

		return strLabel;
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

	// a literal number as the address of a word holding it
	function litLabel(int_a)
	{
		var intValue = s16(int_a);
		var strLabel = 'lit_' + ((intValue < 0) ? ('m' + (-intValue)) : intValue);

		if (objLits[strLabel] === undefined)
		{
			objLits[strLabel] = intValue;
			arrLits.push(strLabel);
		}

		return strLabel;
	}

	// "text" token from IFtoPF -> the text
	function tokenText(strToken_a)
	{
		return strToken_a.substr(1, strToken_a.length - 2).replace(/\\s/g, ' ').replace(/""/g, '"');
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
	// output
	// ------------------------------------------------------------

	function argText(obj_a)
	{
		if (typeof obj_a === 'string')
		{
			return obj_a;
		}
		if (typeof obj_a === 'number')
		{
			return String(obj_a);
		}
		if (obj_a.k === 'l')
		{
			return String(obj_a.v);
		}

		return obj_a.n;
	}

	function emit(strKeyword_a, arrArgs_a)
	{
		var arrArgs = [];
		var intI = 0;
		var arrMatch = null;
		var objTarget = null;

		for (intI = 0; intI < arrArgs_a.length; intI++)
		{
			arrArgs.push(argText(arrArgs_a[intI]));
		}
		arrOut.push({ t: 'kw', kw: strKeyword_a, args: arrArgs, mode: kwMode() });
	}

	// a word that is already the right name for the mode (stubs, turbo keywords)
	function emitRaw(strName_a, arrArgs_a, blnTerm_a)
	{
		var arrArgs = [];
		var intI = 0;

		for (intI = 0; intI < arrArgs_a.length; intI++)
		{
			arrArgs.push(argText(arrArgs_a[intI]));
		}
		arrOut.push({ t: 'stub', name: strName_a, args: arrArgs, term: !!blnTerm_a, mode: kwMode() });
	}

	function emitLabel(str_a)
	{
		arrOut.push({ t: 'label', name: str_a });
		if (intPass === 2)
		{
			objLabelMode[str_a] = kwMode();
		}
	}

	function emitComment(str_a)
	{
		arrOut.push({ t: 'comment', text: str_a });
	}

	// inline ZOSCII text: kw_printzoscii then one glyph word per char, 0 ends it
	function emitZoscii(arrBytes_a)
	{
		var arrCodes = [];
		var intCode = 0;
		var intI = 0;

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

	// ------------------------------------------------------------
	// labels (user labels are per procedure)
	// ------------------------------------------------------------

	function procPart()
	{
		var objProc = (strProc.length > 0) ? objEl[strProc] : null;

		return (objProc !== null) ? (procBase(objProc).substr(2) + '_') : '';
	}

	// base label (without the copy suffix) of a label / line number
	function baseLabel(str_a)
	{
		if (/^\d+$/.test(str_a))
		{
			return 'ln_' + procPart() + parseInt(str_a, 10);
		}
		if (/^[a-z_]\w*$/i.test(str_a))
		{
			return 'lbl_' + procPart() + str_a.toLowerCase();
		}

		return '';
	}

	function targetLabel(str_a, strKind_a)
	{
		var strResult = baseLabel(str_a);

		if (strResult.length > 0)
		{
			arrLabelRefs.push({ label: strResult, line: intLine, file: strFile });
			if (intPass === 1)
			{
				if (strKind_a === 'gosub')
				{
					arrScanCalls.push({ label: strResult, line: intLine, proc: strProc, file: strFile });
				}
				else
				{
					arrScanJumps.push({ label: strResult, line: intLine, proc: strProc, file: strFile });
				}
			}
			else
			{
				arrGotoRefs.push({ label: strResult + strCopy, mode: kwMode(), line: intLine, file: strFile });
			}
			return strResult;
		}

		error('bad label: ' + str_a);
		return 'ntc_badlabel';
	}

	function declareLabel(strBase_a)
	{
		if (intPass === 1)
		{
			if (objLabels[strBase_a] !== undefined)
			{
				errorAlways('label used twice: ' + strBase_a.replace(/^(ln|lbl)_/, '').replace(/^\w+?_(?=\w)/, '') + ' (also line ' + objLabels[strBase_a] + ')');
			}
			else
			{
				objLabels[strBase_a] = intLine;
			}
			objScanFallIn[strBase_a] = (!blnLastTransfer) || (arrCtl.length > 0);
		}
		emitLabel(strBase_a + strCopy);
	}

	// ------------------------------------------------------------
	// expressions
	// operand: { k: 'l', v: n }	literal number
	//			{ k: 'v', n: label }	number variable (16 bit word at label)
	//			{ k: 's', n: label }	string (address of 0 terminated text)
	//			{ k: 'f' }			compare result in the Z flag
	// .el = the element of a plain variable, .done = already in the target
	// ------------------------------------------------------------

	// .raw keeps 32768..65535 for when the literal is used as a Long
	function lit(int_a)
	{
		var objResult = { k: 'l', v: s16(int_a) };

		if ((objResult.v !== int_a) && (int_a >= 0) && (int_a <= 65535))
		{
			objResult.raw = int_a;
		}

		return objResult;
	}

	// a number: Integer literal when it fits 16 bits, else a Long literal
	// { k: 'd', n: llit label, lv: value }
	function numLit(int_a)
	{
		var intValue = 0;

		if ((int_a >= -32768) && (int_a <= 65535))
		{
			return lit(int_a);
		}
		intValue = int_a | 0;

		return { k: 'd', n: llitLabel(intValue), lv: intValue };
	}

	// a number token: 1000& / &HFFFF& are Long whatever the size
	function numToken(strToken_a, int_a)
	{
		if (strToken_a.substr(strToken_a.length - 1) === '&')
		{
			return { k: 'd', n: llitLabel(int_a), lv: int_a | 0 };
		}

		return numLit(int_a);
	}

	// a value known now (Integer or Long literal)
	function isConstNum(objOp_a)
	{
		return (objOp_a.k === 'l') || ((objOp_a.k === 'd') && (objOp_a.lv !== undefined));
	}

	function constNum(objOp_a)
	{
		if (objOp_a.k === 'l')
		{
			return (objOp_a.raw !== undefined) ? objOp_a.raw : objOp_a.v;
		}

		return objOp_a.lv;
	}

	// whole number power, wrapping like the keywords (16 or 32 bit); exp < 0 gives 0
	function powInt(intA_a, intB_a, bln32_a)
	{
		var intResult = 1;
		var intI = 0;

		if (intB_a < 0)
		{
			return 0;
		}
		for (intI = 0; (intI < intB_a) && (intI < 64); intI++)
		{
			intResult = bln32_a ? mul32(intResult, intA_a) : s16(intResult * intA_a);
		}
		if (intB_a >= 64)
		{
			// past 64 steps the value has settled for 0, 1, -1 and wrapped to 0 otherwise
			intResult = (intA_a === 0) ? 0 : ((intA_a === 1) ? 1 : ((intA_a === -1) ? ((intB_a % 2 === 0) ? 1 : -1) : 0));
		}

		return intResult;
	}

	function mul32(intA_a, intB_a)
	{
		var intAh = (intA_a >>> 16) & 0xffff;
		var intAl = intA_a & 0xffff;
		var intBh = (intB_a >>> 16) & 0xffff;
		var intBl = intB_a & 0xffff;

		return ((intAl * intBl) + (((intAh * intBl + intAl * intBh) << 16) >>> 0)) | 0;
	}

	// 32 bit version of fold
	function fold32(strOp_a, intA_a, intB_a)
	{
		var intA = intA_a | 0;
		var intB = intB_a | 0;

		switch (strOp_a)
		{
			case '+': return (intA + intB) | 0;
			case '-': return (intA - intB) | 0;
			case '*': return mul32(intA, intB);
			case '^': return powInt(intA, intB, true);
			case '/':
			case '\\': return (intB === 0) ? 0 : (trunc(intA / intB) | 0);
			case 'MOD': return (intB === 0) ? intA : ((intA - trunc(intA / intB) * intB) | 0);
			case 'AND': return intA & intB;
			case 'OR': return intA | intB;
			case 'XOR': return intA ^ intB;
			case '=': return (intA === intB) ? -1 : 0;
			case '<>': return (intA !== intB) ? -1 : 0;
			case '<': return (intA < intB) ? -1 : 0;
			case '<=': return (intA <= intB) ? -1 : 0;
			case '>': return (intA > intB) ? -1 : 0;
			case '>=': return (intA >= intB) ? -1 : 0;
			default: return 0;
		}
	}

	// is this label (maybe with +n) a Long or Long array
	function isLongLabel(strLabel_a)
	{
		var strBase = String(strLabel_a).replace(/[+-]\d+$/, '');

		if (/^(ltmp\d+|llit_m?\d+)$/.test(strBase))
		{
			return true;
		}

		return ((objDecl[strBase] !== undefined) && ((objDecl[strBase].kind === 'long') || (objDecl[strBase].kind === 'larr')));
	}

	function longTarget(strTarget_a)
	{
		return (strTarget_a && isLongLabel(strTarget_a)) ? strTarget_a : null;
	}

	// address of a Long for an operand: an Integer is widened into ltmp slot
	function longAddr(objOp_a, intSlot_a)
	{
		var strAddr = '';

		if (objOp_a.k === 'd')
		{
			return objOp_a.n;
		}
		if (objOp_a.k === 'l')
		{
			return llitLabel(constNum(objOp_a));
		}
		if (objOp_a.k === 's')
		{
			emit('kw_l_val', [objOp_a.n, ltmp(intSlot_a)]);		// VB turns text into a number
			return ltmp(intSlot_a);
		}
		strAddr = numAddr(objOp_a, intSlot_a);
		emit('kw_l_itol', [strAddr, ltmp(intSlot_a)]);

		return ltmp(intSlot_a);
	}

	function vr(str_a)
	{
		return { k: 'v', n: str_a };
	}

	function sv(str_a)
	{
		return { k: 's', n: str_a };
	}

	// is this label (maybe with +n) a string buffer
	function isStrLabel(strLabel_a)
	{
		var strBase = String(strLabel_a).replace(/[+-]\d+$/, '');

		if (/^stmp\d+$/.test(strBase))
		{
			return true;
		}

		return ((objDecl[strBase] !== undefined) && ((objDecl[strBase].kind === 'str') || (objDecl[strBase].kind === 'strfix') || (objDecl[strBase].kind === 'sarr')));
	}

	function numTarget(strTarget_a)
	{
		return (strTarget_a && !isStrLabel(strTarget_a) && !isLongLabel(strTarget_a)) ? strTarget_a : null;
	}

	function strTarget(strTarget_a)
	{
		return (strTarget_a && isStrLabel(strTarget_a)) ? strTarget_a : null;
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
		else if ((arrMatch = str_a.match(/^&H([0-9A-F]+)&?$/i)) || (arrMatch = str_a.match(/^#([0-9A-F]+)$/i)))
		{
			intResult = parseInt(arrMatch[1], 16);
		}
		else if ((arrMatch = str_a.match(/^&X([01]+)$/i)))
		{
			intResult = parseInt(arrMatch[1], 2);
		}
		else if ((arrMatch = str_a.match(/^&O([0-7]+)$/i)))
		{
			intResult = parseInt(arrMatch[1], 8);
		}
		else if ((arrMatch = str_a.match(/^&([0-9A-F]+)$/i)))
		{
			intResult = parseInt(arrMatch[1], 16);
		}
		else if ((arrMatch = str_a.match(/^(\d+)[%&]$/)))
		{
			intResult = parseInt(arrMatch[1], 10);
		}

		return intResult;
	}

	// constant value: lit / { k: 'str', text } / null (not constant)
	function constValue(objConst_a)
	{
		var objResult = null;
		var strSaveModule = strModule;
		var strSaveProc = strProc;

		if (objConstCache[objConst_a.full] !== undefined)
		{
			return objConstCache[objConst_a.full];
		}
		objConstCache[objConst_a.full] = lit(0);	// cycle guard
		strModule = objConst_a.module;
		strProc = objConst_a.proc || '';
		objResult = evalConst(objConst_a.value);
		strModule = strSaveModule;
		strProc = strSaveProc;
		if (objResult === null)
		{
			error('Const ' + objConst_a.id + ' is not a constant value');
			objResult = lit(0);
		}
		objConstCache[objConst_a.full] = objResult;

		return objResult;
	}

	// compile time value of an expression with numbers, strings and consts
	function evalConst(strExpr_a)
	{
		var arrStack = [];
		var arrTokens = IFtoPF(trim(strExpr_a), []).split(' ');
		var intI = 0;
		var intValue = 0;
		var objA = null;
		var objB = null;
		var objEl_ = null;
		var strToken = '';

		for (intI = 0; intI < arrTokens.length; intI++)
		{
			strToken = arrTokens[intI];
			if (strToken.length === 0)
			{
				continue;
			}
			if (strToken.substr(0, 1) === '"')
			{
				arrStack.push({ k: 'str', text: tokenText(strToken) });
			}
			else if (BINARY[strToken] !== undefined)
			{
				objB = arrStack.pop();
				objA = arrStack.pop();
				if ((objA === undefined) || (objB === undefined))
				{
					return null;
				}
				if ((objA.k === 'str') || (objB.k === 'str'))
				{
					if ((strToken === '&') || (strToken === '+'))
					{
						arrStack.push({ k: 'str', text: ((objA.k === 'str') ? objA.text : String(constNum(objA))) + ((objB.k === 'str') ? objB.text : String(constNum(objB))) });
					}
					else
					{
						return null;
					}
				}
				else if (strToken === '&')
				{
					arrStack.push({ k: 'str', text: String(constNum(objA)) + String(constNum(objB)) });
				}
				else if ((objA.k === 'd') || (objB.k === 'd'))
				{
					arrStack.push(numLit(fold32(strToken, constNum(objA), constNum(objB))));
				}
				else
				{
					arrStack.push(lit(fold(strToken, objA.v, objB.v)));
				}
			}
			else if ((strToken === 'NEG') || (strToken === 'NOT'))
			{
				objA = arrStack.pop();
				if ((objA === undefined) || !isConstNum(objA))
				{
					return null;
				}
				if (objA.k === 'd')
				{
					arrStack.push(numLit((strToken === 'NEG') ? ((-objA.lv) | 0) : ~objA.lv));
				}
				else if ((strToken === 'NEG') && (objA.raw !== undefined))
				{
					arrStack.push(numLit(-objA.raw));
				}
				else
				{
					arrStack.push(lit((strToken === 'NEG') ? -objA.v : ~objA.v));
				}
			}
			else if (strToken.indexOf('@') > -1)
			{
				return null;
			}
			else
			{
				intValue = parseNumber(strToken);
				if (!isNaN(intValue))
				{
					arrStack.push(numToken(strToken, intValue));
				}
				else if (strToken.toUpperCase() === 'TRUE')
				{
					arrStack.push(lit(-1));
				}
				else if (strToken.toUpperCase() === 'FALSE')
				{
					arrStack.push(lit(0));
				}
				else
				{
					objEl_ = resolve(strToken, false, false);
					if ((objEl_ === null) || (objEl_.etype !== 'const'))
					{
						return null;
					}
					arrStack.push(constValue(objEl_));
				}
			}
		}

		return (arrStack.length === 1) ? arrStack[0] : null;
	}

	function fold(strOp_a, intA_a, intB_a)
	{
		var intResult = 0;

		switch (strOp_a)
		{
			case '+': intResult = intA_a + intB_a; break;
			case '-': intResult = intA_a - intB_a; break;
			case '*': intResult = s16(intA_a * intB_a); break;
			case '^': intResult = powInt(intA_a, intB_a, false); break;
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

	// pass 1: note how an undeclared variable is used
	function noteUse(objOp_a, strKind_a)
	{
		if ((intPass === 1) && objOp_a && objOp_a.el && !objOp_a.el.typed)
		{
			if (strKind_a === 's')
			{
				objScanStrUse[objOp_a.el.full] = true;
			}
			else
			{
				objScanNumUse[objOp_a.el.full] = true;
			}
		}
	}

	// address of a number operand (a literal goes through the lit pool)
	function numAddr(objOp_a, intSlot_a)
	{
		var objOp = objOp_a;

		if (objOp.k === 'f')
		{
			emit('kw_ftov', [tmp(intSlot_a)]);
			objOp = vr(tmp(intSlot_a));
		}
		if (objOp.k === 's')
		{
			error('string used where a number is needed');
			return litLabel(0);
		}
		if (objOp.k === 'l')
		{
			return litLabel(objOp.v);
		}
		if (objOp.k === 'd')
		{
			// a Long where an Integer is needed: the low 16 bits
			if (objOp.lv !== undefined)
			{
				return litLabel(objOp.lv);
			}
			emit('kw_l_ltoi', [objOp.n, tmp(intSlot_a)]);
			return tmp(intSlot_a);
		}

		return objOp.n;
	}

	// number operand as a var (literal goes to a temp)
	function numVar(objOp_a, intSlot_a)
	{
		if (objOp_a.k === 'l')
		{
			emitAssignLiteral(objOp_a.v, tmp(intSlot_a));
			return vr(tmp(intSlot_a));
		}
		if (objOp_a.k === 'f')
		{
			emit('kw_ftov', [tmp(intSlot_a)]);
			return vr(tmp(intSlot_a));
		}
		if (objOp_a.k === 's')
		{
			error('string used where a number is needed');
			return vr(tmp(intSlot_a));
		}
		if (objOp_a.k === 'd')
		{
			if (objOp_a.lv !== undefined)
			{
				emitAssignLiteral(s16(objOp_a.lv), tmp(intSlot_a));
			}
			else
			{
				emit('kw_l_ltoi', [objOp_a.n, tmp(intSlot_a)]);
			}
			return vr(tmp(intSlot_a));
		}

		return objOp_a;
	}

	// string operand: a number is turned to text in stmp slot
	function strOf(objOp_a, intSlot_a)
	{
		var strDest = '';

		if (objOp_a.k === 's')
		{
			return objOp_a;
		}
		if (objOp_a.k === 'l')
		{
			return sv(stringLabel(String(constNum(objOp_a))));
		}
		strDest = stmp(intSlot_a);
		if (objOp_a.k === 'd')
		{
			if (objOp_a.lv !== undefined)
			{
				return sv(stringLabel(String(objOp_a.lv)));
			}
			emit('kw_l_cstr', [strDest, objOp_a.n]);
			return sv(strDest);
		}
		emit('kw_strcstr', [strDest, numAddr(objOp_a, intSlot_a)]);

		return sv(strDest);
	}

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

	// a temp from a deeper slot handed back as this slot's value would be
	// overwritten by the next sub expression, so move it down
	function keepSlot(obj_a, intSlot_a)
	{
		var arrMatch = (obj_a.k === 'v') ? obj_a.n.match(/^tmp(\d+)$/) : null;
		var arrSMatch = (obj_a.k === 's') ? obj_a.n.match(/^stmp(\d+)$/) : null;
		var arrLMatch = (obj_a.k === 'd') ? obj_a.n.match(/^ltmp(\d+)$/) : null;

		if ((arrLMatch !== null) && (parseInt(arrLMatch[1], 10) > intSlot_a))
		{
			emit('kw_l_mov', [obj_a.n, ltmp(intSlot_a)]);
			return { k: 'd', n: ltmp(intSlot_a) };
		}
		if ((arrMatch !== null) && (parseInt(arrMatch[1], 10) > intSlot_a))
		{
			emit('kw_vtov', [obj_a, tmp(intSlot_a)]);
			return vr(tmp(intSlot_a));
		}
		if ((arrSMatch !== null) && (parseInt(arrSMatch[1], 10) > intSlot_a))
		{
			emit('kw_strcpy', [stmp(intSlot_a), obj_a.n]);
			return sv(stmp(intSlot_a));
		}

		return obj_a;
	}

	// Option Compare Text: a string compared in this module goes through UCase$ first
	function foldStr(objOp_a, intSlot_a)
	{
		if ((objCompareText[strModule] !== true) || (objOp_a.k !== 's'))
		{
			return objOp_a;
		}
		emit('kw_strucase', [stmp(intSlot_a), objOp_a.n]);

		return sv(stmp(intSlot_a));
	}

	// string & string (or + with a string)
	function concat(objA_a, objB_a, intDest_a, strTarget_a)
	{
		var objA = strOf(objA_a, intDest_a);
		var objB = strOf(objB_a, intDest_a + 1);
		var strDest = strTarget_a ? strTarget_a : stmp(intDest_a);

		// the right side is the target: build in a temp first
		if (objB.n === strDest)
		{
			strDest = stmp(intDest_a);
		}
		if (objA.n !== strDest)
		{
			emit('kw_strcpy', [strDest, objA.n]);
		}
		emit('kw_strcat', [strDest, objB.n]);

		return { k: 's', n: strDest, done: (strDest === strTarget_a) };
	}

	function binaryOp(strOp_a, objA_a, objB_a, intDest_a, strTarget_a)
	{
		var objA = objA_a;
		var objB = objB_a;
		var objSwap = null;
		var objResult = null;
		var strDest = '';

		// strings
		if ((objA.k === 's') || (objB.k === 's') || (strOp_a === '&'))
		{
			if ((strOp_a === '&') || (strOp_a === '+'))
			{
				if (isConstNum(objA) && isConstNum(objB))
				{
					return sv(stringLabel(String(constNum(objA)) + String(constNum(objB))));
				}
				noteUse(objA, 's');
				noteUse(objB, 's');
				return concat(objA, objB, intDest_a, strTarget(strTarget_a));
			}
			if (strOp_a === 'LIKE')
			{
				if ((objA.k !== 's') || (objB.k !== 's'))
				{
					error('Like needs strings');
					return lit(0);
				}
				objA = foldStr(objA, intDest_a);
				objB = foldStr(objB, intDest_a + 1);
				emit('kw_strlike', [objA.n, objB.n]);
				if (numTarget(strTarget_a))
				{
					emit('kw_ftov', [strTarget_a]);
					return { k: 'v', n: strTarget_a, done: true };
				}
				return { k: 'f' };
			}
			if (COMPARE[strOp_a] !== undefined)
			{
				if ((objA.k !== 's') || (objB.k !== 's'))
				{
					noteUse(objA, 's');
					noteUse(objB, 's');
					error('string compared with a number');
					return lit(0);
				}
				objA = foldStr(objA, intDest_a);
				objB = foldStr(objB, intDest_a + 1);
				emit('kw_strcmp' + COMPARE[strOp_a], [objA.n, objB.n]);
				if (numTarget(strTarget_a))
				{
					emit('kw_ftov', [strTarget_a]);
					return { k: 'v', n: strTarget_a, done: true };
				}
				return { k: 'f' };
			}
			error('string used in a number expression');
			return lit(0);
		}

		noteUse(objA, 'n');
		noteUse(objB, 'n');
		if (strOp_a === 'LIKE')
		{
			error('Like needs strings');
			return lit(0);
		}

		// a Long on either side: 32 bit
		if ((objA.k === 'd') || (objB.k === 'd'))
		{
			return longBinary(strOp_a, objA, objB, intDest_a, strTarget_a);
		}

		// both literal - work it out now
		if ((objA.k === 'l') && (objB.k === 'l'))
		{
			return lit(fold(strOp_a, objA.v, objB.v));
		}

		if (COMPARE[strOp_a] !== undefined)
		{
			emitCompare(strOp_a, objA, objB);
			if (numTarget(strTarget_a))
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

		strDest = numTarget(strTarget_a) ? strTarget_a : tmp(intDest_a);

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

			case '^':
				emit('kw_pow', [numAddr(objA, intDest_a), numAddr(objB, intDest_a + 1), strDest]);
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
		objResult.done = (strDest === strTarget_a);

		return objResult;
	}

	// Long operation: every argument is an address, an Integer side is widened
	function longBinary(strOp_a, objA_a, objB_a, intDest_a, strTarget_a)
	{
		var objNames = { '+': 'add', '-': 'sub', '*': 'mul', '/': 'div', '\\': 'div', 'MOD': 'mod', 'AND': 'and', 'OR': 'or', 'XOR': 'xor', '^': 'pow' };
		var strA = '';
		var strB = '';
		var strDest = '';

		if (isConstNum(objA_a) && isConstNum(objB_a))
		{
			return numLit(fold32(strOp_a, constNum(objA_a), constNum(objB_a)));
		}
		strA = longAddr(objA_a, intDest_a);
		strB = longAddr(objB_a, intDest_a + 1);

		if (COMPARE[strOp_a] !== undefined)
		{
			emit('kw_l_cp' + COMPARE[strOp_a], [strA, strB]);
			if (numTarget(strTarget_a))
			{
				emit('kw_ftov', [strTarget_a]);
				return { k: 'v', n: strTarget_a, done: true };
			}
			return { k: 'f' };
		}
		if (objNames[strOp_a] === undefined)
		{
			error('operator not supported: ' + strOp_a);
			return lit(0);
		}
		strDest = longTarget(strTarget_a) ? strTarget_a : ltmp(intDest_a);
		emit('kw_l_' + objNames[strOp_a], [strA, strB, strDest]);

		return { k: 'd', n: strDest, done: (strDest === strTarget_a) };
	}

	function unaryOp(strOp_a, objA_a, intDest_a, strTarget_a)
	{
		var objA = objA_a;
		var objResult = null;
		var strDest = numTarget(strTarget_a) ? strTarget_a : tmp(intDest_a);

		if (objA.k === 's')
		{
			error('string used in a number expression');
			return lit(0);
		}
		noteUse(objA, 'n');
		if (objA.k === 'd')
		{
			if (objA.lv !== undefined)
			{
				return numLit((strOp_a === 'NEG') ? ((-objA.lv) | 0) : ~objA.lv);
			}
			strDest = longTarget(strTarget_a) ? strTarget_a : ltmp(intDest_a);
			emit((strOp_a === 'NEG') ? 'kw_l_neg' : 'kw_l_not', [objA.n, strDest]);
			return { k: 'd', n: strDest, done: (strDest === strTarget_a) };
		}
		if (objA.k === 'l')
		{
			if ((strOp_a === 'NEG') && (objA.raw !== undefined))
			{
				return numLit(-objA.raw);		// -40000 is a Long
			}
			return lit((strOp_a === 'NEG') ? -objA.v : ~objA.v);
		}
		emit((strOp_a === 'NEG') ? 'kw_negv' : 'kw_notv', [objA, strDest]);
		objResult = vr(strDest);
		objResult.done = (strDest === strTarget_a);

		return objResult;
	}

	// ------------------------------------------------------------
	// arrays
	// ------------------------------------------------------------

	// an array parameter: a(), reached through a descriptor
	function isParamArray(objEl_a)
	{
		return (objEl_a !== null) && (objEl_a.etype === 'array') && (objEl_a.index !== undefined) && (objEl_a.scope === 'local');
	}

	// an array of Byte: 1 byte per element (scalar Byte variables stay 16 bit)
	function isByteArray(objEl_a)
	{
		return (objEl_a.etype === 'array') && (objEl_a.datatype === 'byte');
	}

	// a dynamic array: Dim a() then ReDim a(n) - reached through a descriptor too
	function isDynArray(objEl_a)
	{
		return (objEl_a !== null) && (objEl_a.etype === 'array') && (objEl_a.index === undefined) && (objEl_a.dims !== null) && (objEl_a.dims !== undefined) && (objEl_a.dims.length === 0);
	}

	// an array reached through a descriptor (parameter or dynamic)
	function isDescArray(objEl_a)
	{
		return isParamArray(objEl_a) || isDynArray(objEl_a);
	}

	function elementSize(objEl_a)
	{
		var strType = typeOfEl(objEl_a);

		if (isByteArray(objEl_a))
		{
			return 1;
		}

		return (strType === 'str') ? 41 : ((strType === 'long') ? 4 : 2);
	}

	// the array parameter's own descriptor (filled by the call stub)
	function descLabel(objEl_a)
	{
		return declare(labelOf(objEl_a, 'pa_'), 'desc', 0);
	}

	// address of a descriptor for an array argument
	function arrayDesc(objEl_a)
	{
		var arrDims = null;
		var strLabel = '';

		if (isDescArray(objEl_a))
		{
			return descLabel(objEl_a);
		}
		arrDims = dimsOf(objEl_a);
		if (arrDims.length > 2)
		{
			error('only 1 and 2 dimension arrays can be passed: ' + objEl_a.id);
		}
		strLabel = 'ad_' + arrayLabel(objEl_a);
		if (objDecl[strLabel] === undefined)
		{
			declare(strLabel, 'adesc', 0);
			objDecl[strLabel].words = (arrDims.length > 1) ?
				[arrayLabel(objEl_a), arrDims[0].lo, arrDims[1].lo, arrDims[0].n, arrDims[1].n, elementSize(objEl_a)] :
				[arrayLabel(objEl_a), arrDims[0].lo, 0, arrDims[0].n, 1, elementSize(objEl_a)];
		}

		return strLabel;
	}

	// [{ lo, n }] for each dimension
	function dimsOf(objArray_a)
	{
		var arrResult = [];
		var arrTo = null;
		var intBase = objBase[objArray_a.module] || 0;
		var intI = 0;
		var objHi = null;
		var objLo = null;
		var strSaveModule = strModule;
		var strSaveProc = strProc;

		if (objArray_a.dimcache !== undefined)
		{
			return objArray_a.dimcache;
		}
		strModule = objArray_a.module;
		strProc = objArray_a.proc || '';
		for (intI = 0; intI < objArray_a.dims.length; intI++)
		{
			arrTo = objArray_a.dims[intI].toLowerCase().split(/\s+to\s+/);
			objLo = (arrTo.length > 1) ? evalConst(arrTo[0]) : lit(intBase);
			objHi = evalConst(arrTo[arrTo.length - 1]);
			if ((objLo === null) || (objHi === null) || (objLo.k !== 'l') || (objHi.k !== 'l') || (objHi.v < objLo.v))
			{
				error('array size must be a constant: ' + objArray_a.id);
				objLo = lit(0);
				objHi = lit(0);
			}
			arrResult.push({ lo: objLo.v, n: objHi.v - objLo.v + 1 });
		}
		strModule = strSaveModule;
		strProc = strSaveProc;
		if (arrResult.length === 0)
		{
			error('dynamic arrays are not supported: ' + objArray_a.id);
			arrResult.push({ lo: 0, n: 1 });
		}
		objArray_a.dimcache = arrResult;

		return arrResult;
	}

	function arrayLabel(objArray_a)
	{
		var arrDims = dimsOf(objArray_a);
		var intCount = 1;
		var intI = 0;
		var strLabel = labelOf(objArray_a, 'arr_');

		for (intI = 0; intI < arrDims.length; intI++)
		{
			intCount *= arrDims[intI].n;
		}
		declare(strLabel, (typeOfEl(objArray_a) === 'str') ? 'sarr' : ((typeOfEl(objArray_a) === 'long') ? 'larr' : (isByteArray(objArray_a) ? 'barr' : 'arr')), intCount);

		return strLabel;
	}

	function offsetLabel(strLabel_a, intBytes_a)
	{
		if (intBytes_a === 0)
		{
			return strLabel_a;
		}

		return strLabel_a + ((intBytes_a > 0) ? '+' : '-') + Math.abs(intBytes_a);
	}

	// element index operands -> { lit: n } or { v: operand, adjust: n } (element units)
	function arrayIndex(objArray_a, arrIndex_a, intSlot_a)
	{
		var arrDims = dimsOf(objArray_a);
		var intAdjust = 0;
		var intI = 0;
		var intMul = 1;
		var objIndex = null;
		var objPart = null;

		if (arrIndex_a.length !== arrDims.length)
		{
			error(objArray_a.id + ' needs ' + arrDims.length + ' index' + ((arrDims.length > 1) ? 'es' : ''));
			return { lit: 0 };
		}
		for (intI = arrDims.length - 1; intI >= 0; intI--)
		{
			objPart = arrIndex_a[intI];
			if (objPart.k === 's')
			{
				error('string used as an index');
				objPart = lit(0);
			}
			if ((objPart.k === 'f') || (objPart.k === 'd'))
			{
				objPart = (objPart.lv !== undefined) ? lit(objPart.lv) : numVar(objPart, intSlot_a + intI);
			}
			if ((objPart.k === 'l') && ((objPart.v < arrDims[intI].lo) || (objPart.v >= arrDims[intI].lo + arrDims[intI].n)))
			{
				error('index out of range: ' + objArray_a.id + '(' + objPart.v + ')');
			}
			intAdjust += arrDims[intI].lo * intMul;
			if (intMul !== 1)
			{
				objPart = binaryOp('*', objPart, lit(intMul), intSlot_a + intI, null);
			}
			objIndex = (objIndex === null) ? objPart : binaryOp('+', objPart, objIndex, intSlot_a, null);
			intMul *= arrDims[intI].n;
		}
		if (objIndex.k === 'l')
		{
			return { lit: objIndex.v - intAdjust };
		}

		return { v: objIndex, adjust: intAdjust };
	}

	// element of an array parameter
	function paramArrayGet(objArray_a, arrArgs_a, intSlot_a, strTarget_a)
	{
		var strType = typeOfEl(objArray_a);
		var strIndex = '';
		var strIndex2 = '';
		var strDest = '';

		if ((arrArgs_a.length !== 1) && (arrArgs_a.length !== 2))
		{
			error(objArray_a.id + ': 1 or 2 indexes');
			return lit(0);
		}
		strIndex = numAddr(arrArgs_a[0], intSlot_a);
		if (arrArgs_a.length === 2)
		{
			strIndex2 = numAddr(arrArgs_a[1], intSlot_a + 1);
		}
		if (strType === 'str')
		{
			strDest = strTarget(strTarget_a) ? strTarget_a : stmp(intSlot_a);
			emit((strIndex2.length > 0) ? 'kw_pget2' : 'kw_pget', [descLabel(objArray_a), strIndex].concat((strIndex2.length > 0) ? [strIndex2] : []).concat([strDest]));
			return { k: 's', n: strDest, done: (strDest === strTarget_a) };
		}
		if (strType === 'long')
		{
			strDest = longTarget(strTarget_a) ? strTarget_a : ltmp(intSlot_a);
			emit((strIndex2.length > 0) ? 'kw_pget2' : 'kw_pget', [descLabel(objArray_a), strIndex].concat((strIndex2.length > 0) ? [strIndex2] : []).concat([strDest]));
			return { k: 'd', n: strDest, done: (strDest === strTarget_a) };
		}
		strDest = numTarget(strTarget_a) ? strTarget_a : tmp(intSlot_a);
		if (isByteArray(objArray_a))
		{
			emit('kw_ztov', [strDest]);		// kw_pget copies 1 byte: high byte 0
		}
		emit((strIndex2.length > 0) ? 'kw_pget2' : 'kw_pget', [descLabel(objArray_a), strIndex].concat((strIndex2.length > 0) ? [strIndex2] : []).concat([strDest]));

		return { k: 'v', n: strDest, done: (strDest === strTarget_a) };
	}

	function arrayGet(objArray_a, arrArgs_a, intSlot_a, strTarget_a)
	{
		var strBase = '';
		var objIndex = null;
		var blnStr = (typeOfEl(objArray_a) === 'str');
		var strDest = '';
		var objResult = null;

		if (isDescArray(objArray_a))
		{
			return paramArrayGet(objArray_a, arrArgs_a, intSlot_a, strTarget_a);
		}
		strBase = arrayLabel(objArray_a);
		objIndex = arrayIndex(objArray_a, arrArgs_a, intSlot_a);
		if (isByteArray(objArray_a))
		{
			strDest = numTarget(strTarget_a) ? strTarget_a : tmp(intSlot_a);
			if (objIndex.lit !== undefined)
			{
				emit('kw_lptrtov8', [offsetLabel(strBase, objIndex.lit), strDest]);
			}
			else
			{
				emit('kw_aget8', [offsetLabel(strBase, -objIndex.adjust), objIndex.v, strDest]);
			}
			return { k: 'v', n: strDest, done: (strDest === strTarget_a) };
		}

		if (typeOfEl(objArray_a) === 'long')
		{
			if (objIndex.lit !== undefined)
			{
				return { k: 'd', n: offsetLabel(strBase, objIndex.lit * 4) };
			}
			strDest = longTarget(strTarget_a) ? strTarget_a : ltmp(intSlot_a);
			emit('kw_l_aget', [offsetLabel(strBase, -objIndex.adjust * 4), objIndex.v, strDest]);
			return { k: 'd', n: strDest, done: (strDest === strTarget_a) };
		}
		if (objIndex.lit !== undefined)
		{
			return blnStr ? sv(offsetLabel(strBase, objIndex.lit * 41)) : vr(offsetLabel(strBase, objIndex.lit * 2));
		}
		if (blnStr)
		{
			strDest = stmp(intSlot_a);
			emit('kw_sget', [offsetLabel(strBase, -objIndex.adjust * 41), objIndex.v, strDest]);
			return sv(strDest);
		}
		strDest = numTarget(strTarget_a) ? strTarget_a : tmp(intSlot_a);
		emit('kw_aget', [offsetLabel(strBase, -objIndex.adjust * 2), objIndex.v, strDest]);
		objResult = vr(strDest);
		objResult.done = (strDest === strTarget_a);

		return objResult;
	}

	// ------------------------------------------------------------
	// procedures (Sub / Function / Property)
	// Call: dw p_x_c, arg address, ... - the stub copies the args into the
	// parameters, zeroes the locals, saves the return point (SP) and jumps
	// into the body. The body ends with dw p_x_r: copy ByRef params back,
	// load SP from the return point. No recursion: each procedure has one
	// set of parameters, locals and one return point.
	// ------------------------------------------------------------

	function procParams(objProc_a)
	{
		return objProc_a.params || [];
	}

	function paramEl(objProc_a, intIndex_a)
	{
		return objEl[objProc_a.full + '.' + objProc_a.params[intIndex_a].name];
	}

	// a ByRef parameter that its procedure writes is copied back at the end
	function copyBack(objProc_a, intIndex_a)
	{
		var objParam = objProc_a.params[intIndex_a];

		return !objParam.byval && (objWritten[objProc_a.full + '.' + objParam.name] === true);
	}

	// the argument may be written through its address: a ByRef parameter the
	// procedure writes, or any ByRef parameter of an asm keyword procedure
	function argBack(objProc_a, intIndex_a)
	{
		return objProc_a.asmkw ? !objProc_a.params[intIndex_a].byval : copyBack(objProc_a, intIndex_a);
	}

	function addrLabel(objProc_a, intIndex_a)
	{
		return procBase(objProc_a) + '_a' + intIndex_a;
	}

	// call a procedure. arrArgs_a: argument expression strings, or operands
	// when blnOps_a. Returns the result operand for a function.
	function procCall(objProc_a, arrArgs_a, blnOps_a, intSlot_a, strTarget_a)
	{
		var arrRefix = [];
		var arrParams = procParams(objProc_a);
		var arrAddr = [];
		var intI = 0;
		var objArg = null;
		var objParam = null;
		var objResult = null;
		var objRes = null;
		var strArg = '';
		var strType = '';
		var strDest = '';

		if (objProc_a.full === strProc)
		{
			error('recursion is not supported: ' + objProc_a.id);
		}
		if (arrArgs_a.length > arrParams.length)
		{
			error(objProc_a.id + ' takes ' + arrParams.length + ' argument' + ((arrParams.length === 1) ? '' : 's'));
		}

		for (intI = 0; intI < arrParams.length; intI++)
		{
			objParam = arrParams[intI];
			strType = typeOfEl(paramEl(objProc_a, intI));
			objArg = null;
			strArg = '';
			if (intI < arrArgs_a.length)
			{
				if (blnOps_a)
				{
					objArg = arrArgs_a[intI];
				}
				else
				{
					strArg = trim(arrArgs_a[intI]);
				}
			}
			if (objParam.isarray)
			{
				// an array: pass the address of its descriptor
				if ((objArg === null) && (strArg.length > 0))
				{
					objArg = /^[a-z_][\w.]*[$%&!#@]?$/i.test(strArg) ? resolve(strArg, false, false) : null;
					objArg = ((objArg !== null) && (objArg.etype === 'array')) ? { k: 'a', el: objArg } : null;
				}
				if ((objArg === null) || (objArg.k !== 'a'))
				{
					error(objProc_a.id + ': argument ' + (intI + 1) + ' (' + objParam.name + ') must be an array');
					arrAddr.push(litLabel(0));
					continue;
				}
				if (paramEl(objProc_a, intI).udt)
				{
					// an array of a Type: one descriptor per field array
					if (!objArg.el.udt || (objArg.el.datatype !== paramEl(objProc_a, intI).datatype))
					{
						error(objProc_a.id + ': argument ' + (intI + 1) + ' (' + objParam.name + ') must be an array of ' + paramEl(objProc_a, intI).datatype);
						continue;
					}
					udtLeaves(objArg.el.datatype, '').forEach(function(objLeaf_a)
					{
						arrAddr.push(arrayDesc(objEl[objArg.el.full + objLeaf_a.path]));
					});
					continue;
				}
				if (objArg.el.udt || (typeOfEl(objArg.el) !== typeOfEl(paramEl(objProc_a, intI))))
				{
					error(objProc_a.id + ': argument ' + (intI + 1) + ' (' + objParam.name + ') is an array of the wrong type');
				}
				arrAddr.push(arrayDesc(objArg.el));
				continue;
			}
			if (paramEl(objProc_a, intI).udt)
			{
				// a Type: the address of each field of the argument (a Type variable)
				if ((objArg === null) && (strArg.length > 0))
				{
					objArg = /^[a-z_][\w.]*$/i.test(strArg) ? resolve(strArg, false, false) : null;
					objArg = ((objArg !== null) && objArg.udt && (objArg.etype !== 'array')) ? { k: 'a', el: objArg } : null;
				}
				if ((objArg === null) || (objArg.k !== 'a') || !objArg.el.udt || (objArg.el.etype === 'array') || (objArg.el.datatype !== paramEl(objProc_a, intI).datatype))
				{
					error(objProc_a.id + ': argument ' + (intI + 1) + ' (' + objParam.name + ') must be a ' + paramEl(objProc_a, intI).datatype + ' variable');
					continue;
				}
				if (!objParam.byval)
				{
					noteWrite(objArg.el);		// passed on ByRef: may be written
				}
				udtLeaves(objArg.el.datatype, '').forEach(function(objLeaf_a)
				{
					arrAddr.push(varLabel(objEl[objArg.el.full + objLeaf_a.path]));
				});
				continue;
			}
			if ((objArg !== null) && (objArg.k === 'a'))
			{
				error(wholeMsg(objArg.el));
				objArg = lit(0);
			}
			if ((objArg === null) && (strArg.length === 0))
			{
				if (!objParam.optional)
				{
					error(objProc_a.id + ': argument ' + (intI + 1) + ' (' + objParam.name + ') is missing');
				}
				strArg = (objParam.def.length > 0) ? objParam.def : ((strType === 'str') ? '""' : '0');
			}
			if (objArg === null)
			{
				objArg = compileExpr(strArg, null, intSlot_a + intI);
				// pass 1: a plain variable passed ByRef may be written
				if ((intPass === 1) && objArg.el && !objParam.byval && (objArg.el.etype === 'param'))
				{
					objWritten[objArg.el.full] = true;
				}
			}

			if (strType === 'str')
			{
				objArg = strOf(objArg, intSlot_a + intI);
				if (argBack(objProc_a, intI) && objArg.el && (fixedLen(objArg.el) > 0))
				{
					arrRefix.push({ label: objArg.n, n: fixedLen(objArg.el) });	// String * n: pad again after
				}
				if (argBack(objProc_a, intI) && !objArg.el && !/^stmp\d+$/.test(objArg.n))
				{
					emit('kw_strcpy', [stmp(intSlot_a + intI), objArg.n]);	// a literal must not be written to
					objArg = sv(stmp(intSlot_a + intI));
				}
				arrAddr.push(objArg.n);
			}
			else if (strType === 'long')
			{
				if (argBack(objProc_a, intI) && (objArg.k === 'v') && objArg.el)
				{
					error(objProc_a.id + ': argument ' + (intI + 1) + ' is ByRef As Long - pass a Long variable or make it ByVal');
				}
				strArg = longAddr(objArg, intSlot_a + intI);
				if (argBack(objProc_a, intI) && /^llit_/.test(strArg))
				{
					emit('kw_l_mov', [strArg, ltmp(intSlot_a + intI)]);		// a literal must not be written to
					strArg = ltmp(intSlot_a + intI);
				}
				arrAddr.push(strArg);
			}
			else
			{
				if (argBack(objProc_a, intI) && (objArg.k === 'd') && objArg.el)
				{
					error(objProc_a.id + ': argument ' + (intI + 1) + ' is ByRef As Integer - pass an Integer variable or make it ByVal');
				}
				if (objArg.k === 's')
				{
					error(objProc_a.id + ': argument ' + (intI + 1) + ' must be a number');
					objArg = lit(0);
				}
				if (argBack(objProc_a, intI) && (objArg.k !== 'v'))
				{
					objArg = numVar(objArg, intSlot_a + intI);
				}
				arrAddr.push(numAddr(objArg, intSlot_a + intI));
			}
		}

		if (intPass === 1)
		{
			arrScanProcCalls.push({ from: strProc, to: objProc_a.full, mode: strMode, line: intLine, file: strFile });
		}
		if (objProc_a.asmkw)
		{
			// asm keyword: the result address goes last, the block stores into it
			if (objProc_a.kind === 'function')
			{
				// x = F(...): the block stores straight into x (not when x is an argument)
				objRes = objEl[objProc_a.full + '.' + objProc_a.id];
				strDest = (typeOfEl(objRes) === 'long') ? longTarget(strTarget_a) : ((typeOfEl(objRes) === 'str') ? null : numTarget(strTarget_a));
				if (strDest && (arrAddr.indexOf(strDest) < 0))
				{
					arrAddr.push(strDest);
					emit(asmKwLabel(objProc_a), arrAddr);
					return (typeOfEl(objRes) === 'long') ? { k: 'd', n: strDest, done: true } : { k: 'v', n: strDest, done: true };
				}
				arrAddr.push(varLabel(objRes));
			}
			emit(asmKwLabel(objProc_a), arrAddr);
		}
		else
		{
			emitRaw(procLabel(objProc_a, kwMode()) + '_c', arrAddr, false);
		}
		arrRefix.forEach(function(objFix_a)
		{
			emit('kw_strfix', [objFix_a.label, objFix_a.n]);
		});

		if ((objProc_a.kind === 'function') || (objProc_a.kind === 'propget'))
		{
			objRes = objEl[objProc_a.full + '.' + objProc_a.id];
			if (typeOfEl(objRes) === 'str')
			{
				objResult = sv(varLabel(objRes));
			}
			else if (typeOfEl(objRes) === 'long')
			{
				objResult = { k: 'd', n: varLabel(objRes) };
			}
			else
			{
				objResult = vr(varLabel(objRes));
			}
			objResult.fres = true;
		}

		return objResult;
	}

	// the call and return stubs of a procedure for a mode (once each)
	function procStubs(objProc_a, strMode_a)
	{
		var intBytes = 0;
		var arrCode = [];
		var arrParams = procParams(objProc_a);
		var intI = 0;
		var objLocal = null;
		var objParam = null;
		var strBody = procLabel(objProc_a, strMode_a);
		var strKey = '';
		var strLabel = '';
		var strRs = procBase(objProc_a) + '_rs';
		var strIndent = '\t\t\t';

		if (objProcStubDone[strBody] !== undefined)
		{
			return;
		}
		objProcStubDone[strBody] = true;
		declare(strRs, 'int', 0);

		arrCode.push(strBody + '_c:\t\t; call ' + objProc_a.id + ((strMode_a === 'n') ? ' (normal)' : ' (turbo)'));
		for (intI = 0; intI < arrParams.length; intI++)
		{
			objParam = paramEl(objProc_a, intI);
			if (arrParams[intI].isarray && objParam.udt)
			{
				udtLeaves(objParam.datatype, '').forEach(function(objLeaf_a)
				{
					arrCode.push(strIndent + 'pop hl\t\t\t; ' + arrParams[intI].name + '()' + objLeaf_a.path + ' descriptor');
					arrCode.push(strIndent + 'ld de, ' + descLabel(objEl[objParam.full + objLeaf_a.path]));
					arrCode.push(strIndent + 'ld bc, 12');
					arrCode.push(strIndent + 'ldir');
				});
				continue;
			}
			if (arrParams[intI].isarray)
			{
				arrCode.push(strIndent + 'pop hl\t\t\t; ' + arrParams[intI].name + '() descriptor');
				arrCode.push(strIndent + 'ld de, ' + descLabel(objParam));
				arrCode.push(strIndent + 'ld bc, 12');
				arrCode.push(strIndent + 'ldir');
				continue;
			}
			if (objParam.udt)
			{
				// a Type: one address per field
				udtLeaves(objParam.datatype, '').forEach(function(objLeaf_a, intLeaf_a)
				{
					arrCode.push(strIndent + 'pop hl\t\t\t; ' + arrParams[intI].name + objLeaf_a.path);
					if (copyBack(objProc_a, intI))
					{
						declare(addrLabel(objProc_a, intI) + '_' + intLeaf_a, 'int', 0);
						arrCode.push(strIndent + 'ld (' + addrLabel(objProc_a, intI) + '_' + intLeaf_a + '), hl');
					}
					arrCode.push(strIndent + 'ld de, ' + varLabel(objEl[objParam.full + objLeaf_a.path]));
					arrCode.push(strIndent + 'ld bc, ' + leafSize(typeOfEl({ datatype: objLeaf_a.type, full: '' })));
					arrCode.push(strIndent + 'ldir');
				});
				continue;
			}
			strLabel = varLabel(objParam);
			arrCode.push(strIndent + 'pop hl\t\t\t; ' + arrParams[intI].name);
			if (copyBack(objProc_a, intI))
			{
				declare(addrLabel(objProc_a, intI), 'int', 0);
				arrCode.push(strIndent + 'ld (' + addrLabel(objProc_a, intI) + '), hl');
			}
			if ((typeOfEl(objParam) === 'str') || (typeOfEl(objParam) === 'long'))
			{
				arrCode.push(strIndent + 'ld de, ' + strLabel);
				arrCode.push(strIndent + 'ld bc, ' + ((typeOfEl(objParam) === 'str') ? 41 : 4));
				arrCode.push(strIndent + 'ldir');
			}
			else
			{
				arrCode.push(strIndent + 'ld e, (hl)');
				arrCode.push(strIndent + 'inc hl');
				arrCode.push(strIndent + 'ld d, (hl)');
				arrCode.push(strIndent + 'ld (' + strLabel + '), de');
			}
		}

		// locals start at 0 / "" on every call (not Static)
		if (!objProc_a.isstatic)
		{
			for (strKey in objEl)
			{
				if (objEl.hasOwnProperty(strKey))
				{
					objLocal = objEl[strKey];
					// a local array (not Static) is cleared on every call, as in VB
					if ((objLocal.proc === objProc_a.full) && (objLocal.scope === 'local') && (objLocal.etype === 'array') && !objLocal.isstatic && !objLocal.udt && !isParamArray(objLocal) && !objLocal.pfield)
					{
						if (isDynArray(objLocal))
						{
							strLabel = descLabel(objLocal);
							intBytes = 12;
						}
						else
						{
							strLabel = arrayLabel(objLocal);
							intBytes = elementSize(objLocal);
							dimsOf(objLocal).forEach(function(objDim_a) { intBytes *= objDim_a.n; });
						}
						arrCode.push(strIndent + 'ld hl, ' + strLabel + '\t\t; clear ' + objLocal.id + '()');
						arrCode.push(strIndent + 'ld (hl), 0');
						if (intBytes > 1)
						{
							arrCode.push(strIndent + 'ld de, ' + strLabel + '+1');
							arrCode.push(strIndent + 'ld bc, ' + (intBytes - 1));
							arrCode.push(strIndent + 'ldir');
						}
						continue;
					}
					if ((objLocal.proc === objProc_a.full) && (objLocal.scope === 'local') && ((objLocal.etype === 'var') || (objLocal.etype === 'result')) && !objLocal.isstatic && !objLocal.udt && !objLocal.pfield)
					{
						strLabel = varLabel(objLocal);
						if (fixedLen(objLocal) > 0)
						{
							arrCode.push(strIndent + 'ld hl, ' + strLabel + '\t\t; String * ' + fixedLen(objLocal) + ': spaces');
							arrCode.push(strIndent + 'ld b, ' + fixedLen(objLocal));
							arrCode.push(strIndent + 'ld a, \' \'');
							arrCode.push(strIndent + 'ld (hl), a');
							arrCode.push(strIndent + 'inc hl');
							arrCode.push(strIndent + 'djnz $-2');
							arrCode.push(strIndent + 'ld (hl), 0');
						}
						else if (typeOfEl(objLocal) === 'str')
						{
							arrCode.push(strIndent + 'xor a');
							arrCode.push(strIndent + 'ld (' + strLabel + '), a');
						}
						else
						{
							arrCode.push(strIndent + 'ld hl, 0');
							arrCode.push(strIndent + 'ld (' + strLabel + '), hl');
							if (typeOfEl(objLocal) === 'long')
							{
								arrCode.push(strIndent + 'ld (' + strLabel + '+2), hl');
							}
						}
					}
				}
			}
		}
		arrCode.push(strIndent + 'ld (' + strRs + '), sp');
		arrCode.push(strIndent + 'ld sp, ' + strBody);
		arrCode.push(strIndent + exitCode(strMode_a));

		arrCode.push(strBody + '_r:\t\t; end of ' + objProc_a.id);
		for (intI = 0; intI < arrParams.length; intI++)
		{
			if (copyBack(objProc_a, intI) && paramEl(objProc_a, intI).udt)
			{
				objParam = paramEl(objProc_a, intI);
				udtLeaves(objParam.datatype, '').forEach(function(objLeaf_a, intLeaf_a)
				{
					arrCode.push(strIndent + 'ld de, (' + addrLabel(objProc_a, intI) + '_' + intLeaf_a + ')');
					arrCode.push(strIndent + 'ld hl, ' + varLabel(objEl[objParam.full + objLeaf_a.path]));
					arrCode.push(strIndent + 'ld bc, ' + leafSize(typeOfEl({ datatype: objLeaf_a.type, full: '' })));
					arrCode.push(strIndent + 'ldir');
				});
				continue;
			}
			if (copyBack(objProc_a, intI))
			{
				objParam = paramEl(objProc_a, intI);
				strLabel = varLabel(objParam);
				if ((typeOfEl(objParam) === 'str') || (typeOfEl(objParam) === 'long'))
				{
					arrCode.push(strIndent + 'ld de, (' + addrLabel(objProc_a, intI) + ')');
					arrCode.push(strIndent + 'ld hl, ' + strLabel);
					arrCode.push(strIndent + 'ld bc, ' + ((typeOfEl(objParam) === 'str') ? 41 : 4));
					arrCode.push(strIndent + 'ldir');
				}
				else
				{
					arrCode.push(strIndent + 'ld hl, (' + addrLabel(objProc_a, intI) + ')');
					arrCode.push(strIndent + 'ld de, (' + strLabel + ')');
					arrCode.push(strIndent + 'ld (hl), e');
					arrCode.push(strIndent + 'inc hl');
					arrCode.push(strIndent + 'ld (hl), d');
				}
			}
		}
		if ((objHookProcs[objProc_a.full] === true) && (strMode_a === 'n'))
		{
			arrCode.push(strIndent + 'ld a, (ntc_hookset)\t; Interrupt hook done: may run again');
			arrCode.push(strIndent + 'ld (ntc_hookon), a');
		}
		arrCode.push(strIndent + 'ld sp, (' + strRs + ')');
		arrCode.push(strIndent + exitCode(strMode_a));

		arrProcStubs = arrProcStubs.concat(arrCode);
	}

	// ------------------------------------------------------------
	// functions: built in, arrays, procedures
	// ------------------------------------------------------------

	// IIf(cond, a, b) / Choose(n, a, b, ...): the values are worked out first (as
	// in VB), then one is copied into the result by branches
	function chooseValue(strName_a, arrArgs_a, intSlot_a, strTarget_a)
	{
		var arrValues = arrArgs_a.slice(1);
		var blnLong = false;
		var blnStr = false;
		var intI = 0;
		var intId = newId();
		var objSel = arrArgs_a[0];
		var strDest = '';
		var strEnd = 'ch' + intId + '_e';
		var strNext = '';

		for (intI = 0; intI < arrValues.length; intI++)
		{
			blnStr = blnStr || (arrValues[intI].k === 's');
			blnLong = blnLong || (arrValues[intI].k === 'd');
		}
		if (objSel.k === 's')
		{
			error(strName_a + ': the first value must be a number');
			return lit(0);
		}
		// known now: just that value
		if (isConstNum(objSel))
		{
			intI = (strName_a === 'iif') ? ((constNum(objSel) !== 0) ? 0 : 1) : (constNum(objSel) - 1);
			if ((intI >= 0) && (intI < arrValues.length))
			{
				return keepSlot(arrValues[intI], intSlot_a);
			}
			return blnStr ? sv(stringLabel('')) : lit(0);
		}
		// the selector is only read before the one copy that happens, so the
		// result can use this slot (the values sit in the slots after it)
		objSel = numVar(objSel, intSlot_a);
		if (blnStr)
		{
			strDest = strTarget(strTarget_a) ? strTarget_a : stmp(intSlot_a);
		}
		else if (blnLong)
		{
			strDest = longTarget(strTarget_a) ? strTarget_a : ltmp(intSlot_a);
		}
		else
		{
			strDest = numTarget(strTarget_a) ? strTarget_a : tmp(intSlot_a);
		}
		for (intI = 0; intI < arrValues.length; intI++)
		{
			strNext = 'ch' + intId + '_' + intI;
			if (strName_a === 'iif')
			{
				if (intI === 0)
				{
					emit('kw_goto_ifzero', [objSel, strNext]);
				}
			}
			else
			{
				emitCompare('<>', objSel, lit(intI + 1));
				emit('kw_goto_iftrue', [strNext]);
			}
			if (blnStr)
			{
				emit('kw_strcpy', [strDest, strOf(arrValues[intI], intSlot_a + arrArgs_a.length + 1).n]);
			}
			else if (blnLong)
			{
				storeLong(arrValues[intI], strDest, intSlot_a + arrArgs_a.length + 1);
			}
			else
			{
				storeNum(arrValues[intI], strDest, intSlot_a + arrArgs_a.length + 2);
			}
			emit('kw_goto', [strEnd]);
			emitLabel(strNext);
		}
		// Choose out of range: 0 / ""
		if (blnStr)
		{
			emit('kw_strcpy', [strDest, stringLabel('')]);
		}
		else if (blnLong)
		{
			emit('kw_l_mov', [llitLabel(0), strDest]);
		}
		else
		{
			emit('kw_ztov', [strDest]);
		}
		emitLabel(strEnd);

		return blnStr ? { k: 's', n: strDest, done: (strDest === strTarget_a) } :
			(blnLong ? { k: 'd', n: strDest, done: (strDest === strTarget_a) } : { k: 'v', n: strDest, done: (strDest === strTarget_a) });
	}

	// Format$ number pattern: text before the first 0 / #, text after the last, the
	// number of 0s (least digits), a comma anywhere = groups of 3. null: no 0 / #
	function formatPattern(strPattern_a)
	{
		var intFirst = strPattern_a.search(/[0#]/);
		var intLast = Math.max(strPattern_a.lastIndexOf('0'), strPattern_a.lastIndexOf('#'));
		var strBody = '';

		if (intFirst < 0)
		{
			return null;
		}
		var strDec = '';

		strBody = strPattern_a.substring(intFirst, intLast + 1);
		// whole numbers only: ".00" prints as ".00"
		if (strBody.indexOf('.') > -1)
		{
			strDec = '.' + new Array((strBody.substr(strBody.indexOf('.') + 1).match(/0/g) || []).length + 1).join('0');
			strBody = strBody.substr(0, strBody.indexOf('.'));
		}

		return {
			pre: strPattern_a.substr(0, intFirst), suf: ((strDec === '.') ? '' : strDec) + strPattern_a.substr(intLast + 1),
			min: Math.max(1, (strBody.match(/0/g) || []).length), group: (strBody.indexOf(',') > -1)
		};
	}

	function formatNumber(int_a, objFmt_a)
	{
		var strDigits = String(Math.abs(int_a));
		var strResult = '';
		var intI = 0;

		while (strDigits.length < objFmt_a.min)
		{
			strDigits = '0' + strDigits;
		}
		if (objFmt_a.group)
		{
			for (intI = 0; intI < strDigits.length; intI++)
			{
				if ((intI > 0) && ((strDigits.length - intI) % 3 === 0))
				{
					strResult += ',';
				}
				strResult += strDigits.charAt(intI);
			}
			strDigits = strResult;
		}

		return ((int_a < 0) ? '-' : '') + objFmt_a.pre + strDigits + objFmt_a.suf;
	}

	function callFunction(strName_a, arrArgs_a, intSlot_a, strTarget_a)
	{
		var strName = strName_a.toLowerCase();
		var objBuiltin = BUILTINS[strName];
		var objElement = null;
		var objA = null;
		var objB = null;
		var objC = null;
		var objResult = null;
		var strDest = '';
		var strNum = '';
		var intI = 0;
		var arrDims = null;
		var objFmt = null;

		objElement = resolve(strName, false, false);
		if ((objElement === null) || (objElement.etype !== 'proc'))
		{
			for (intI = 0; intI < arrArgs_a.length; intI++)
			{
				if ((arrArgs_a[intI].k === 'a') && !((intI === 0) && ((strName === 'lbound') || (strName === 'ubound') || (strName === 'join') || (strName === 'join$'))))
				{
					error(wholeMsg(arrArgs_a[intI].el));
					return lit(0);
				}
			}
		}
		if (((strName === 'lbound') || (strName === 'ubound')) && ((objElement === null) || (objElement.etype !== 'proc')))
		{
			if ((arrArgs_a.length < 1) || (arrArgs_a[0].k !== 'a') || (arrArgs_a[0].el.etype !== 'array'))
			{
				error(strName + ' needs an array');
				return lit(0);
			}
			if (arrArgs_a[0].el.udt)
			{
				arrArgs_a[0] = { k: 'a', el: objEl[arrArgs_a[0].el.full + udtLeaves(arrArgs_a[0].el.datatype, '')[0].path] };
			}
			if (isDescArray(arrArgs_a[0].el))
			{
				intI = (arrArgs_a.length > 1) ? ((arrArgs_a[1].k === 'l') ? arrArgs_a[1].v : 0) : 1;
				if ((intI !== 1) && (intI !== 2))
				{
					error(strName + ': dimension must be 1 or 2');
					return lit(0);
				}
				strDest = numTarget(strTarget_a) ? strTarget_a : tmp(intSlot_a);
				emit('kw_' + strName, [offsetLabel(descLabel(arrArgs_a[0].el), 2 * (intI - 1)), strDest]);
				return { k: 'v', n: strDest, done: (strDest === strTarget_a) };
			}
			arrDims = dimsOf(arrArgs_a[0].el);
			intI = (arrArgs_a.length > 1) ? ((arrArgs_a[1].k === 'l') ? arrArgs_a[1].v : 0) : 1;
			if ((intI < 1) || (intI > arrDims.length))
			{
				error(strName + ': dimension must be a number from 1 to ' + arrDims.length);
				return lit(0);
			}
			return lit((strName === 'lbound') ? arrDims[intI - 1].lo : arrDims[intI - 1].lo + arrDims[intI - 1].n - 1);
		}
		if ((objElement !== null) && (objElement.etype === 'array'))
		{
			return arrayGet(objElement, arrArgs_a, intSlot_a, strTarget_a);
		}
		if ((objElement !== null) && (objElement.etype === 'proc'))
		{
			return procCall(objElement, arrArgs_a, true, intSlot_a, strTarget_a);
		}
		if ((objElement !== null) && (objElement.etype === 'result'))
		{
			error('recursion is not supported: ' + strName + ' calls itself');
			return lit(0);
		}
		if ((objElement !== null) && (objElement.etype !== 'const') && (objBuiltin === undefined))
		{
			error(strName + ' is not an array or function');
			return lit(0);
		}
		if (objBuiltin === undefined)
		{
			error('unknown function or array: ' + strName);
			return lit(0);
		}
		if ((arrArgs_a.length < objBuiltin[0]) || (arrArgs_a.length > objBuiltin[1]))
		{
			error(strName + ' needs ' + objBuiltin[0] + ((objBuiltin[1] > objBuiltin[0]) ? ' or ' + objBuiltin[1] : '') + ' argument' + ((objBuiltin[1] > 1) ? 's' : ''));
			return (objBuiltin[2] === 's') ? sv(stringLabel('')) : lit(0);
		}

		strName = strName.replace(/\$$/, '');
		objA = arrArgs_a[0];
		objB = arrArgs_a[1];
		objC = arrArgs_a[2];

		if ((strName === 'iif') || (strName === 'choose'))
		{
			return chooseValue(strName, arrArgs_a, intSlot_a, strTarget_a);
		}
		if (strName === 'strcomp')
		{
			// (a < b) - (a > b): -1, 0 or 1
			if ((objA.k !== 's') || (objB.k !== 's'))
			{
				error('StrComp needs strings');
				return lit(0);
			}
			binaryOp('<', objA, objB, intSlot_a, tmp(intSlot_a));
			binaryOp('>', objA, objB, intSlot_a + 1, tmp(intSlot_a + 1));
			return binaryOp('-', vr(tmp(intSlot_a)), vr(tmp(intSlot_a + 1)), intSlot_a, strTarget_a);
		}

		// string results: into the target if it is a string var, else stmp
		if (objBuiltin[2] === 's')
		{
			strDest = strTarget(strTarget_a) ? strTarget_a : stmp(intSlot_a);
			switch (strName)
			{
				case 'left':
				case 'right':
					emit('kw_str' + strName, [strDest, strArgOf(objA, intSlot_a), numAddr(objB, intSlot_a + 1)]);
					break;
				case 'mid':
					emit('kw_strmid', [strDest, strArgOf(objA, intSlot_a), numAddr(objB, intSlot_a + 1), (objC !== undefined) ? numAddr(objC, intSlot_a + 2) : litLabel(255)]);
					break;
				case 'chr':
					if (objA.k === 'l')
					{
						return sv(stringLabel(String.fromCharCode(objA.v & 255)));
					}
					emit('kw_strchr', [strDest, numAddr(objA, intSlot_a)]);
					break;
				case 'str':
				case 'cstr':
					if (objA.k === 's')
					{
						return objA;
					}
					if (isConstNum(objA))
					{
						return sv(stringLabel(((strName === 'str') && (constNum(objA) >= 0) ? ' ' : '') + String(constNum(objA))));
					}
					if (objA.k === 'd')
					{
						emit((strName === 'str') ? 'kw_l_str' : 'kw_l_cstr', [strDest, objA.n]);
						break;
					}
					emit((strName === 'str') ? 'kw_strstr' : 'kw_strcstr', [strDest, numAddr(objA, intSlot_a)]);
					break;
				case 'hex':
					if (objA.k === 'l')
					{
						return sv(stringLabel((objA.v & 0xffff).toString(16).toUpperCase()));
					}
					if ((objA.k === 'd') && (objA.lv !== undefined))
					{
						return sv(stringLabel((objA.lv >>> 0).toString(16).toUpperCase()));
					}
					if (objA.k === 'd')
					{
						emit('kw_l_hex', [strDest, objA.n]);
						break;
					}
					emit('kw_strhex', [strDest, numAddr(objA, intSlot_a)]);
					break;
				case 'space':
				case 'spc':
					emit('kw_strspace', [strDest, numAddr(objA, intSlot_a)]);
					break;
				case 'string':
					if (objB.k === 's')
					{
						emit('kw_strasc', [objB.n, tmp(intSlot_a + 1)]);
						objB = vr(tmp(intSlot_a + 1));
					}
					emit('kw_strstring', [strDest, numAddr(objA, intSlot_a), numAddr(objB, intSlot_a + 1)]);
					break;
				case 'ucase':
				case 'lcase':
				case 'ltrim':
				case 'rtrim':
				case 'trim':
					emit('kw_str' + strName, [strDest, strArgOf(objA, intSlot_a)]);
					break;
				case 'replace':
					emit('kw_strreplace', [strDest, strArgOf(objA, intSlot_a), strArgOf(objB, intSlot_a + 1), strArgOf(objC, intSlot_a + 2)]);
					break;
				case 'join':
					if ((objA.k !== 'a') || (objA.el.etype !== 'array') || objA.el.udt || (typeOfEl(objA.el) !== 'str'))
					{
						error('Join needs a String array');
						return sv(stringLabel(''));
					}
					if (!isDescArray(objA.el) && (dimsOf(objA.el).length !== 1))
					{
						error('Join: 1 dimension arrays only');
						return sv(stringLabel(''));
					}
					emit('kw_strjoin', [strDest, arrayDesc(objA.el), (objB !== undefined) ? strArgOf(objB, intSlot_a + 1) : stringLabel(' ')]);
					break;
				case 'format':
					if (objA.k === 's')
					{
						return objA;
					}
					if (objB === undefined)
					{
						return callFunction('cstr', [objA], intSlot_a, strTarget_a);
					}
					if ((objB.k !== 's') || !/^str\d+$/.test(objB.n))
					{
						error('Format$: the pattern must be a constant string');
						return sv(stringLabel(''));
					}
					objFmt = formatPattern(arrStrings[parseInt(objB.n.substr(3), 10)].text);
					if (objFmt === null)
					{
						return objB;		// no 0 / # in it: the text itself
					}
					if (isConstNum(objA))
					{
						return sv(stringLabel(formatNumber(constNum(objA), objFmt)));
					}
					emit((objA.k === 'd') ? 'kw_l_strfmt' : 'kw_strfmt', [strDest, (objA.k === 'd') ? objA.n : numAddr(objA, intSlot_a), objFmt.min, objFmt.group ? 1 : 0, stringLabel(objFmt.pre), stringLabel(objFmt.suf)]);
					break;
				case 'strreverse':
					emit('kw_strrev', [strDest, strArgOf(objA, intSlot_a)]);
					break;
				case 'oct':
					if (objA.k === 'l')
					{
						return sv(stringLabel((objA.v & 0xffff).toString(8)));
					}
					emit('kw_stroct', [strDest, numAddr(objA, intSlot_a)]);
					break;
				default:
					break;
			}
			return sv(strDest);
		}

		// number results
		strDest = numTarget(strTarget_a) ? strTarget_a : tmp(intSlot_a);

		switch (strName)
		{
			case 'len':
			case 'asc':
			case 'val':
				if (objA.k !== 's')
				{
					if ((strName === 'len') || (strName === 'asc'))
					{
						error(strName + ' needs a string');
						return lit(0);
					}
					return objA;
				}
				if ((strName === 'val') && longTarget(strTarget_a))
				{
					emit('kw_l_val', [objA.n, strTarget_a]);
					return { k: 'd', n: strTarget_a, done: true };
				}
				emit((strName === 'len') ? 'kw_strlen' : ((strName === 'asc') ? 'kw_strasc' : 'kw_strval'), [objA.n, strDest]);
				break;
			case 'instrrev':
				if ((objA.k !== 's') || (objB.k !== 's'))
				{
					error('InStrRev needs strings');
					return lit(0);
				}
				objA = foldStr(objA, intSlot_a);
				objB = foldStr(objB, intSlot_a + 1);
				emit('kw_strinstrrev', [objA.n, objB.n, (objC !== undefined) ? numAddr(objC, intSlot_a + 2) : litLabel(-1), strDest]);
				break;
			case 'sqr':
				if (objA.k === 'l')
				{
					return lit((objA.v < 0) ? 0 : Math.floor(Math.sqrt(objA.v)));
				}
				emit('kw_sqr', [numAddr(objA, intSlot_a), strDest]);
				break;
			case 'instr':
				if (arrArgs_a.length === 2)
				{
					objC = objB;
					objB = objA;
					objA = lit(1);
				}
				if ((objB.k !== 's') || (objC.k !== 's'))
				{
					error('InStr needs strings');
					return lit(0);
				}
				objB = foldStr(objB, intSlot_a + 1);
				objC = foldStr(objC, intSlot_a + 2);
				emit('kw_strinstr', [numAddr(objA, intSlot_a), objB.n, objC.n, strDest]);
				break;
			case 'clng':
				// to a Long: text with kw_l_val, an Integer sign extended
				if (isConstNum(objA))
				{
					return { k: 'd', n: llitLabel(constNum(objA)), lv: constNum(objA) | 0 };
				}
				if (objA.k === 'd')
				{
					return keepSlot(objA, intSlot_a);
				}
				strDest = longTarget(strTarget_a) ? strTarget_a : ltmp(intSlot_a);
				if (objA.k === 's')
				{
					emit('kw_l_val', [objA.n, strDest]);
				}
				else
				{
					emit('kw_l_itol', [numAddr(objA, intSlot_a), strDest]);
				}
				return { k: 'd', n: strDest, done: (strDest === strTarget_a) };
			case 'cint':
				if (objA.k === 'd')
				{
					return numVar(objA, intSlot_a);
				}
				if (objA.k === 's')
				{
					emit('kw_strval', [objA.n, strDest]);
					break;
				}
				return keepSlot(objA, intSlot_a);
			case 'int':
			case 'fix':
				if (objA.k === 's')
				{
					emit('kw_strval', [objA.n, strDest]);
					break;
				}
				return keepSlot(objA, intSlot_a);
			case 'cbool':
				if (isConstNum(objA))
				{
					return lit((constNum(objA) !== 0) ? -1 : 0);
				}
				if (objA.k === 'd')
				{
					return binaryOp('<>', objA, lit(0), intSlot_a, strTarget_a);
				}
				return binaryOp('<>', numVar(objA, intSlot_a), lit(0), intSlot_a, strTarget_a);
			case 'cbyte':
				return binaryOp('AND', objA, lit(255), intSlot_a, strTarget_a);
			default:
				if (objA.k === 's')
				{
					error('string used in a number expression');
					return lit(0);
				}
				if (objA.k === 'l')
				{
					if (strName === 'abs')
					{
						return lit(Math.abs(objA.v));
					}
					if (strName === 'sgn')
					{
						return lit((objA.v > 0) ? 1 : ((objA.v < 0) ? -1 : 0));
					}
				}
				if (objA.k === 'd')
				{
					if ((objA.lv !== undefined) && (strName === 'abs'))
					{
						return numLit(Math.abs(objA.lv));
					}
					if ((objA.lv !== undefined) && (strName === 'sgn'))
					{
						return lit((objA.lv > 0) ? 1 : ((objA.lv < 0) ? -1 : 0));
					}
					if (strName === 'abs')
					{
						strDest = longTarget(strTarget_a) ? strTarget_a : ltmp(intSlot_a);
						emit('kw_l_abs', [objA.n, strDest]);
						return { k: 'd', n: strDest, done: (strDest === strTarget_a) };
					}
					if (strName === 'sgn')
					{
						emit('kw_l_sgn', [objA.n, strDest]);
						objResult = vr(strDest);
						objResult.done = (strDest === strTarget_a);
						return objResult;
					}
					objA = numVar(objA, intSlot_a);
				}
				noteUse(objA, 'n');
				switch (strName)
				{
					case 'abs': emit('kw_absv', [numVar(objA, intSlot_a), strDest]); break;
					case 'sgn': emit('kw_sgnv', [numVar(objA, intSlot_a), strDest]); break;
					case 'peek': emit((objA.k === 'l') ? 'kw_lptrtov8' : 'kw_vptrtov8', [objA, strDest]); break;
					case 'deek': emit((objA.k === 'l') ? 'kw_lptrtov' : 'kw_vptrtov', [objA, strDest]); break;
					case 'rnd': emit((objA.k === 'l') ? 'kw_rndl' : 'kw_rndv', [objA, strDest]); break;
					case 'inp': emit('kw_inp', [numAddr(objA, intSlot_a), strDest]); break;
					default: error('function not supported: ' + strName); break;
				}
				break;
		}

		objResult = vr(strDest);
		objResult.done = (strDest === strTarget_a);

		return objResult;
	}

	function strArgOf(objOp_a, intSlot_a)
	{
		if (objOp_a.k !== 's')
		{
			return strOf(objOp_a, intSlot_a).n;
		}

		return objOp_a.n;
	}

	// AddressOf Proc: a read only word holding the address of the procedure's call
	// stub for the mode at this line (call it with CallAddr)
	function addressOf(strName_a)
	{
		var objProc = resolve(strName_a, false, false);
		var strLabel = '';

		if ((objProc === null) || (objProc.etype !== 'proc'))
		{
			error('AddressOf needs a Sub or Function: ' + strName_a);
			return lit(0);
		}
		if (intPass === 1)
		{
			arrScanProcCalls.push({ from: strProc, to: objProc.full, mode: strMode, line: intLine, file: strFile });
		}
		strLabel = 'ap_' + procLabel(objProc, kwMode()) + '_c';
		if (objLits[strLabel] === undefined)
		{
			objLits[strLabel] = procLabel(objProc, kwMode()) + '_c';
			arrLits.push(strLabel);
		}

		return vr(strLabel);
	}

	// a name on its own in an expression
	function operand(strToken_a, arrStack_a, intBase_a)
	{
		var strUpper = strToken_a.toUpperCase();
		var intValue = parseNumber(strToken_a);
		var objElement = null;
		var objResult = lit(0);
		var objConst = null;
		var strTemp = '';

		if (strToken_a.substr(0, 1) === '"')
		{
			return sv(stringLabel(tokenText(strToken_a)));
		}
		if (!isNaN(intValue))
		{
			if (intValue > 4294967295)
			{
				error('number too big: ' + strToken_a);
			}
			return numToken(strToken_a, intValue);
		}
		if (/^\d*\.\d+$/.test(strToken_a))
		{
			error('decimal numbers are not supported (16 bit integers): ' + strToken_a);
			return lit(0);
		}
		if (strUpper === 'TRUE')
		{
			return lit(-1);
		}
		if (strUpper === 'FALSE')
		{
			return lit(0);
		}
		if (!/^[a-z_][\w.]*[$%&!#@]?$/i.test(strToken_a))
		{
			error('bad value: ' + strToken_a);
			return lit(0);
		}

		objElement = resolve(strToken_a, false, false);
		if ((objElement === null) && /^__addressof_/i.test(strToken_a))
		{
			return addressOf(strToken_a.substr(12).replace(/__dot__/gi, '.'));
		}
		if ((objElement === null) && (strUpper === 'INKEY$'))
		{
			strTemp = stmp(intBase_a + arrStack_a.length);
			emit('kw_inkeys', [strTemp]);
			return sv(strTemp);
		}
		if ((objElement === null) && ((strUpper === 'INKEY') || (strUpper === 'TICKS') || (strUpper === 'TIMER')))
		{
			materialize(arrStack_a, intBase_a);
			strTemp = tmp(intBase_a + arrStack_a.length);
			emit((strUpper === 'INKEY') ? 'kw_inkey' : 'kw_ticks', [strTemp]);
			return vr(strTemp);
		}
		if (objElement === null)
		{
			objElement = resolve(strToken_a, true, false);
		}
		if (objElement === null)
		{
			error('not found: ' + strToken_a);
			return lit(0);
		}

		switch (objElement.etype)
		{
			case 'const':
				objConst = constValue(objElement);
				return (objConst.k === 'str') ? sv(stringLabel(objConst.text)) : objConst;
			case 'array':
				// a whole array: only as a procedure argument or in LBound / UBound
				return { k: 'a', el: objElement, n: '' };
			case 'proc':
				if ((objElement.kind === 'function') || (objElement.kind === 'propget'))
				{
					materialize(arrStack_a, intBase_a);
					return procCall(objElement, [], true, intBase_a + arrStack_a.length, null);
				}
				error(strToken_a + ' is a Sub, it has no value');
				return lit(0);
			case 'type':
				error(strToken_a + ' is a Type');
				return lit(0);
			default:
				if (objElement.udt)
				{
					return { k: 'a', el: objElement, n: '' };		// a whole Type: only as an argument
				}
				if (isClass(objElement.datatype || ''))
				{
					error(strToken_a + ' needs a .member');
					return lit(0);
				}
				if (typeOfEl(objElement) === 'str')
				{
					objResult = sv(varLabel(objElement));
				}
				else if (typeOfEl(objElement) === 'long')
				{
					objResult = { k: 'd', n: varLabel(objElement) };
				}
				else
				{
					objResult = vr(varLabel(objElement));
				}
				objResult.el = objElement;
				return objResult;
		}
	}

	// rewrite a(i).field -> a.field(i) (arrays of a Type)
	function rewriteFields(str_a)
	{
		var strResult = str_a;
		var strLast = '';

		while (strLast !== strResult)
		{
			strLast = strResult;
			strResult = strResult.replace(/([a-z_][\w.]*)\(([^()"]*)\)\.([a-z_]\w*)/gi, '$1.$3($2)');
		}

		return strResult;
	}

	function toPostfix(strExpr_a)
	{
		// AddressOf Name -> one operand token
		var strExpr = trim(strExpr_a).replace(/\baddressof\s+([a-z_][\w.]*)/gi, function(strAll_a, strName_a)
		{
			return '__addressof_' + strName_a.replace(/\./g, '__dot__');
		});
		var strPostfix = IFtoPF(rewriteFields(strExpr), []);

		return (strPostfix.length > 0) ? strPostfix.split(' ') : [];
	}

	// compile an expression. strTarget_a (optional) receives the last
	// operation directly. intBase_a = first temp number this may use.
	function compileExpr(strExpr_a, strTarget_a, intBase_a)
	{
		if (/^\s*$/.test(strExpr_a))
		{
			error('missing value');
			return lit(0);
		}

		return compilePostfix(toPostfix(strExpr_a), strTarget_a, intBase_a || 0, strExpr_a);
	}

	function compilePostfix(arrTokens_a, strTarget_a, intBase_a, strText_a)
	{
		var arrArgs = [];
		var arrMatch = null;
		var arrStack = [];
		var blnLast = false;
		var intBase = intBase_a || 0;
		var intCount = 0;
		var intI = 0;
		var objA = null;
		var objB = null;
		var objResult = null;
		var strToken = '';

		for (intI = 0; intI < arrTokens_a.length; intI++)
		{
			strToken = arrTokens_a[intI];
			blnLast = (intI === arrTokens_a.length - 1);

			if (strToken === '?')
			{
				error('bad expression: ' + strText_a);
				return lit(0);
			}
			else if (BINARY[strToken] !== undefined)
			{
				if (arrStack.length < 2)
				{
					error('bad expression: ' + strText_a);
					return lit(0);
				}
				materialize(arrStack, intBase);
				objB = arrStack.pop();
				objA = arrStack.pop();
				if ((objA.k === 'a') || (objB.k === 'a'))
				{
					error(wholeMsg(((objA.k === 'a') ? objA : objB).el));
					return lit(0);
				}
				arrStack.push(binaryOp(strToken, objA, objB, intBase + arrStack.length, blnLast ? strTarget_a : null));
			}
			else if ((strToken === 'NEG') || (strToken === 'NOT'))
			{
				if (arrStack.length < 1)
				{
					error('bad expression: ' + strText_a);
					return lit(0);
				}
				materialize(arrStack, intBase);
				objA = arrStack.pop();
				if (objA.k === 'a')
				{
					error(wholeMsg(objA.el));
					return lit(0);
				}
				arrStack.push(unaryOp(strToken, objA, intBase + arrStack.length, blnLast ? strTarget_a : null));
			}
			else if ((arrMatch = strToken.match(/^(.+)@(\d+)$/)))
			{
				intCount = parseInt(arrMatch[2], 10);
				if (arrStack.length < intCount)
				{
					error('bad expression: ' + strText_a);
					return lit(0);
				}
				materialize(arrStack, intBase);
				arrArgs = arrStack.splice(arrStack.length - intCount, intCount);
				objResult = callFunction(arrMatch[1], arrArgs, intBase + arrStack.length, blnLast ? strTarget_a : null);
				// a function result is overwritten by the next call: keep it
				if (objResult && objResult.fres && !blnLast)
				{
					if (objResult.k === 's')
					{
						emit('kw_strcpy', [stmp(intBase + arrStack.length), objResult.n]);
						objResult = sv(stmp(intBase + arrStack.length));
					}
					else if (objResult.k === 'd')
					{
						emit('kw_l_mov', [objResult.n, ltmp(intBase + arrStack.length)]);
						objResult = { k: 'd', n: ltmp(intBase + arrStack.length) };
					}
					else
					{
						emit('kw_vtov', [objResult, tmp(intBase + arrStack.length)]);
						objResult = vr(tmp(intBase + arrStack.length));
					}
				}
				arrStack.push(objResult || lit(0));
			}
			else
			{
				arrStack.push(operand(strToken, arrStack, intBase));
			}
		}

		if (arrStack.length !== 1)
		{
			error('bad expression: ' + strText_a);
			return lit(0);
		}
		if (arrStack[0].k === 'a')
		{
			error(wholeMsg(arrStack[0].el));
			return lit(0);
		}

		return arrStack[0];
	}

	// expression type without making code: 's' or 'n'
	function exprType(strExpr_a)
	{
		return typeOfTokens(toPostfix(strExpr_a));
	}

	function typeOfTokens(arrTokens_a)
	{
		var arrArgTypes = [];
		var arrTokens = arrTokens_a;
		var arrStack = [];
		var arrMatch = null;
		var intI = 0;
		var objElement = null;
		var objConst = null;
		var strA = '';
		var strB = '';
		var strName = '';
		var strToken = '';

		for (intI = 0; intI < arrTokens.length; intI++)
		{
			strToken = arrTokens[intI];
			if (BINARY[strToken] !== undefined)
			{
				strB = arrStack.pop() || 'n';
				strA = arrStack.pop() || 'n';
				if (strToken === '&')
				{
					arrStack.push('s');
				}
				else if (strToken === '+')
				{
					arrStack.push(((strA === 's') || (strB === 's')) ? 's' : 'n');
				}
				else
				{
					arrStack.push('n');
				}
			}
			else if ((strToken === 'NEG') || (strToken === 'NOT'))
			{
				arrStack.pop();
				arrStack.push('n');
			}
			else if ((arrMatch = strToken.match(/^(.+)@(\d+)$/)))
			{
				arrArgTypes = arrStack.splice(arrStack.length - parseInt(arrMatch[2], 10), parseInt(arrMatch[2], 10));
				strName = arrMatch[1].toLowerCase();
				if ((BUILTINS[strName] !== undefined) && (BUILTINS[strName][2] === '?'))
				{
					arrStack.push((arrArgTypes.slice(1).indexOf('s') > -1) ? 's' : 'n');	// IIf / Choose: like their values
					continue;
				}
				objElement = resolve(rewriteFields(strName), false, false);
				if ((objElement !== null) && ((objElement.etype === 'array') || (objElement.etype === 'proc')))
				{
					arrStack.push((objElement.etype === 'proc') ? ((typeOfEl(objEl[objElement.full + '.' + objElement.id] || { datatype: objElement.datatype, full: '' }) === 'str') ? 's' : 'n') : ((typeOfEl(objElement) === 'str') ? 's' : 'n'));
				}
				else if (BUILTINS[strName] !== undefined)
				{
					arrStack.push(BUILTINS[strName][2]);
				}
				else
				{
					arrStack.push('n');
				}
			}
			else if (strToken.substr(0, 1) === '"')
			{
				arrStack.push('s');
			}
			else
			{
				objElement = /^[a-z_][\w.]*[$%&!#@]?$/i.test(strToken) ? resolve(strToken, false, false) : null;
				if (objElement === null)
				{
					arrStack.push((strToken.substr(strToken.length - 1) === '$') ? 's' : 'n');
				}
				else if (objElement.etype === 'const')
				{
					objConst = constValue(objElement);
					arrStack.push((objConst.k === 'str') ? 's' : 'n');
				}
				else if (objElement.etype === 'proc')
				{
					arrStack.push((typeOfEl(objEl[objElement.full + '.' + objElement.id] || { datatype: objElement.datatype, full: '' }) === 'str') ? 's' : 'n');
				}
				else
				{
					arrStack.push((typeOfEl(objElement) === 'str') ? 's' : 'n');
				}
			}
		}

		return (arrStack.length > 0) ? arrStack[arrStack.length - 1] : 'n';
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
		else if (objResult.k === 'd')
		{
			objResult = (objResult.lv !== undefined) ? lit(objResult.lv) : numVar(objResult, intBase_a);
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
		return storeNum(compileExpr(strExpr_a, strDest_a, intBase_a), strDest_a, intBase_a || 0);
	}

	// put a number result into a Long variable
	function storeLong(objResult_a, strDest_a, intBase_a)
	{
		if (objResult_a.done)
		{
			return objResult_a;
		}
		switch (objResult_a.k)
		{
			case 'd':
				if (objResult_a.n !== strDest_a)
				{
					emit('kw_l_mov', [objResult_a.n, strDest_a]);
				}
				break;
			case 'l':
				emit('kw_l_mov', [llitLabel(constNum(objResult_a)), strDest_a]);
				break;
			case 'f':
				emit('kw_ftov', [tmp(intBase_a)]);
				emit('kw_l_itol', [tmp(intBase_a), strDest_a]);
				break;
			case 's':
				emit('kw_l_val', [objResult_a.n, strDest_a]);	// VB turns text into a number
				break;
			default:
				emit('kw_l_itol', [objResult_a.n, strDest_a]);
				break;
		}

		return objResult_a;
	}

	// put a result into a number variable (Integer or Long)
	function storeNum(objResult_a, strDest_a, intBase_a)
	{
		var objResult = objResult_a;

		if (isLongLabel(strDest_a))
		{
			return storeLong(objResult, strDest_a, intBase_a);
		}
		if (objResult.done)
		{
			return objResult;
		}
		if (objResult.k === 'd')
		{
			if (objResult.lv !== undefined)
			{
				emitAssignLiteral(s16(objResult.lv), strDest_a);
			}
			else
			{
				emit('kw_l_ltoi', [objResult.n, strDest_a]);
			}
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
			emit('kw_strval', [objResult.n, strDest_a]);	// VB turns text into a number
		}
		else if (objResult.n !== strDest_a)
		{
			emit('kw_vtov', [objResult, strDest_a]);
		}

		return objResult;
	}

	function compileStringAssign(strDest_a, strExpr_a)
	{
		var objResult = compileExpr(strExpr_a, strDest_a, 0);

		if (objResult.done)
		{
			return;
		}
		if ((objResult.k === 'd') && (objResult.lv === undefined))
		{
			emit('kw_l_cstr', [strDest_a, objResult.n]);
			return;
		}
		if (isConstNum(objResult))
		{
			objResult = strOf(objResult, 0);
		}
		if (objResult.k !== 's')
		{
			emit('kw_strcstr', [strDest_a, numAddr(objResult, 0)]);	// VB turns a number into text
			return;
		}
		if (objResult.n !== strDest_a)
		{
			emit('kw_strcpy', [strDest_a, objResult.n]);
		}
	}

	// branch to strLabel_a when the condition is true (or false)
	function compileCond(strCond_a, strLabel_a, blnJumpIfTrue_a)
	{
		var objResult = compileExpr(strCond_a, null, 0);

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
		else if (objResult.k === 'd')
		{
			if (objResult.lv !== undefined)
			{
				if ((objResult.lv !== 0) === blnJumpIfTrue_a)
				{
					emit('kw_goto', [strLabel_a]);
				}
				return;
			}
			emit('kw_l_cpne', [objResult.n, llitLabel(0)]);
			emit(blnJumpIfTrue_a ? 'kw_goto_iftrue' : 'kw_goto_iffalse', [strLabel_a]);
		}
		else
		{
			emit(blnJumpIfTrue_a ? 'kw_goto_ifnzero' : 'kw_goto_ifzero', [objResult, strLabel_a]);
		}
	}

	// ------------------------------------------------------------
	// control blocks (each keeps the mode it started in)
	// ------------------------------------------------------------

	function ctlTop(strType_a)
	{
		if ((arrCtl.length > 0) && (arrCtl[arrCtl.length - 1].type === strType_a))
		{
			return arrCtl[arrCtl.length - 1];
		}

		return null;
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

	// a branch / loop body must end in the mode it started in
	function modeCheck(objCtl_a, strWhere_a)
	{
		if (objCtl_a && (objCtl_a.mode !== strMode))
		{
			error('Turbo mode changes inside ' + strWhere_a + ' (line ' + objCtl_a.line + '): end it in the mode it started in');
			strMode = objCtl_a.mode;
		}
	}

	function ifBegin(strCond_a, blnSingle_a)
	{
		var intId = newId();
		var objCtl = { type: 'IF', line: intLine, single: blnSingle_a, id: intId, k: 1, next: 'if' + intId + '_1', end: 'if' + intId + '_e', usedend: false, haselse: false, mode: strMode };

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
		modeCheck(objCtl, 'If');
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
		modeCheck(objCtl, 'If');
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
				while ((arrCtl.length > 0) && ((ctlTop('IF') === null) || !ctlTop('IF').single))
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
		modeCheck(objCtl, 'If');
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

	// ------------------------------------------------------------
	// Select Case
	// ------------------------------------------------------------

	function selectBegin(strExpr_a)
	{
		var intId = newId();
		var objValue = compileExpr(strExpr_a, null, 0);
		var blnStr = (objValue.k === 's');
		var strType = blnStr ? 'str' : ((objValue.k === 'd') ? 'long' : 'int');
		var objCtl = { type: 'SELECT', line: intLine, id: intId, k: 0, next: '', end: 'sel' + intId + '_e', usedend: false, haselse: false, str: blnStr, mode: strMode, name: '__sel' + intId };
		var objSel = {
			etype: 'var', scope: (strProc.length > 0) ? 'local' : 'module',
			full: ((strProc.length > 0) ? strProc : strModule) + '.__sel' + intId,
			id: '__sel' + intId, module: strModule, proc: strProc,
			datatype: strType, typed: true, isstatic: true
		};
		var strLabel = '';

		objEl[objSel.full] = objSel;
		strLabel = varLabel(objSel);
		if (blnStr)
		{
			if (objValue.n !== strLabel)
			{
				emit('kw_strcpy', [strLabel, objValue.n]);
			}
		}
		else
		{
			storeNum(objValue, strLabel, 0);
		}
		arrCtl.push(objCtl);
	}

	function selectCase(arrItems_a)
	{
		var objCtl = ctlTop('SELECT');
		var arrMatch = null;
		var intI = 0;
		var intId = 0;
		var strBody = '';
		var strItem = '';
		var strSkip = '';

		if ((objCtl === null) || objCtl.haselse)
		{
			error('CASE without SELECT CASE');
			return;
		}
		if (objCtl.k > 0)
		{
			modeCheck(objCtl, 'Select Case');
			emit('kw_goto', [objCtl.end]);
			objCtl.usedend = true;
			emitLabel(objCtl.next);
		}
		objCtl.k++;
		objCtl.next = 'sel' + objCtl.id + '_' + objCtl.k;

		if (arrItems_a === null)
		{
			objCtl.haselse = true;
			objCtl.next = '';
			return;
		}

		strBody = 'sel' + objCtl.id + '_b' + objCtl.k;
		for (intI = 0; intI < arrItems_a.length; intI++)
		{
			strItem = trim(arrItems_a[intI]);
			intId = (intI === arrItems_a.length - 1) ? -1 : intI;
			if ((arrMatch = strItem.match(/^is\s*(<>|<=|>=|=|<|>)\s*(.+)$/i)))
			{
				caseTest(objCtl.name + ' ' + arrMatch[1] + ' (' + arrMatch[2] + ')', intId, strBody, objCtl.next);
			}
			else if ((arrMatch = strItem.match(/^(.+?)\s+to\s+(.+)$/i)))
			{
				strSkip = 'sel' + objCtl.id + '_s' + objCtl.k + '_' + intI;
				compileCond(objCtl.name + ' < (' + arrMatch[1] + ')', (intId < 0) ? objCtl.next : strSkip, true);
				caseTest(objCtl.name + ' <= (' + arrMatch[2] + ')', intId, strBody, objCtl.next);
				if (intId >= 0)
				{
					emitLabel(strSkip);
				}
			}
			else
			{
				caseTest(objCtl.name + ' = (' + strItem + ')', intId, strBody, objCtl.next);
			}
		}
		emitLabel(strBody);
	}

	// one test: last item jumps to the next case when false, others to the body when true
	function caseTest(strCond_a, intIndex_a, strBody_a, strNext_a)
	{
		if (intIndex_a < 0)
		{
			compileCond(strCond_a, strNext_a, false);
		}
		else
		{
			compileCond(strCond_a, strBody_a, true);
		}
	}

	function selectEnd()
	{
		var objCtl = ctlClose('SELECT', 'END SELECT');

		if (objCtl === null)
		{
			return;
		}
		modeCheck(objCtl, 'Select Case');
		if (objCtl.next.length > 0)
		{
			emitLabel(objCtl.next);
		}
		emitLabel(objCtl.end);
	}

	// ------------------------------------------------------------
	// PRINT / INPUT
	// ------------------------------------------------------------

	// top level & (or + with strings) of a postfix: the parts, in order
	function concatParts(arrTokens_a)
	{
		var arrLeft = null;
		var arrRight = null;
		var intI = 0;
		var intNeed = 1;
		var strLast = arrTokens_a[arrTokens_a.length - 1];
		var arrMatch = null;

		if ((arrTokens_a.length < 3) || ((strLast !== '&') && (strLast !== '+')))
		{
			return [arrTokens_a];
		}
		// find where the right operand starts
		for (intI = arrTokens_a.length - 2; intI >= 0; intI--)
		{
			if (BINARY[arrTokens_a[intI]] !== undefined)
			{
				intNeed += 1;
			}
			else if ((arrMatch = arrTokens_a[intI].match(/@(\d+)$/)))
			{
				intNeed += parseInt(arrMatch[1], 10) - 1;
			}
			else if ((arrTokens_a[intI] === 'NEG') || (arrTokens_a[intI] === 'NOT'))
			{
				intNeed += 0;
			}
			else
			{
				intNeed -= 1;
			}
			if (intNeed === 0)
			{
				break;
			}
		}
		if (intI <= 0)
		{
			return [arrTokens_a];
		}
		arrLeft = arrTokens_a.slice(0, intI);
		arrRight = arrTokens_a.slice(intI, arrTokens_a.length - 1);
		if ((strLast === '+') && (typeOfTokens(arrLeft) !== 's') && (typeOfTokens(arrRight) !== 's'))
		{
			return [arrTokens_a];	// a number sum
		}

		return concatParts(arrLeft).concat(concatParts(arrRight));
	}

	function compilePrint(strArgs_a)
	{
		var arrItems = splitTop(strArgs_a, ';,');
		var arrMatch = null;
		var blnVB = false;
		var arrParts = [];
		var arrPending = [];
		var blnNewline = true;
		var intI = 0;
		var intJ = 0;
		var objValue = null;
		var strItem = '';

		function flush()
		{
			if (arrPending.length > 0)
			{
				emitZoscii(arrPending);
				arrPending = [];
			}
		}

		for (intI = 0; intI < arrItems.length; intI++)
		{
			strItem = trim(arrItems[intI].text);

			if ((arrMatch = strItem.match(/^tab\s*\((.*)\)$/i)))
			{
				flush();
				emit('kw_printtab', [numAddr(compileValue(arrMatch[1], 0), 0)]);
			}
			else if (strItem.length > 0)
			{
				arrParts = concatParts(toPostfix(strItem));
				for (intJ = 0; intJ < arrParts.length; intJ++)
				{
					if ((arrParts[intJ].length === 1) && (arrParts[intJ][0].substr(0, 1) === '"'))
					{
						arrPending = arrPending.concat(textToBytes(tokenText(arrParts[intJ][0])));
						continue;
					}
					objValue = compilePostfix(arrParts[intJ], null, 0, strItem);
					if (objValue.k === 'f')
					{
						emit('kw_ftov', [tmp(0)]);
						objValue = vr(tmp(0));
					}
					blnVB = blnVBPrint && (arrParts.length === 1);		// a number on its own, not part of &
					if (isConstNum(objValue))
					{
						arrPending = arrPending.concat(textToBytes((blnVB && (constNum(objValue) >= 0) ? ' ' : '') + String(constNum(objValue)) + (blnVB ? ' ' : '')));
					}
					else if (objValue.k === 'd')
					{
						flush();
						emit(blnVB ? 'kw_l_printvb' : 'kw_l_print', [objValue.n]);
					}
					else if (objValue.k === 's')
					{
						if (/^str\d+$/.test(objValue.n))
						{
							arrPending = arrPending.concat(textToBytes(arrStrings[parseInt(objValue.n.substr(3), 10)].text));
						}
						else
						{
							flush();
							emit('kw_printstrvar', [objValue.n]);
						}
					}
					else
					{
						flush();
						emit(blnVB ? 'kw_printintvb' : 'kw_printint', [objValue]);
					}
				}
			}

			if ((arrItems[intI].sep === ',') && blnVBPrint)
			{
				flush();
				emit('kw_printzone', []);
			}
			else if (arrItems[intI].sep === ',')
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

	// a variable that can be written: { label, str } or null
	function writeTarget(strName_a)
	{
		var objElement = resolve(strName_a, true, true);

		if ((objElement === null) || ((objElement.etype !== 'var') && (objElement.etype !== 'param') && (objElement.etype !== 'result')) || objElement.udt)
		{
			return null;
		}

		return { label: varLabel(objElement), str: (typeOfEl(objElement) === 'str'), lng: (typeOfEl(objElement) === 'long'), el: objElement };
	}

	function noteWrite(objElement_a)
	{
		if ((intPass === 1) && objElement_a && (objElement_a.etype === 'param'))
		{
			objWritten[objElement_a.full] = true;
		}
		if ((intPass === 1) && objElement_a && objElement_a.pfield)
		{
			objWritten[objElement_a.pfield] = true;		// a field of a Type parameter
		}
	}

	// the scalar fields of a Type, in order: [{ path: '.a.b', type }]
	function udtLeaves(strType_a, strPrefix_a, arrOut_a)
	{
		var arrResult = arrOut_a || [];
		var intI = 0;
		var objField = null;
		var objType = objEl[strType_a];

		for (intI = 0; intI < objType.fields.length; intI++)
		{
			objField = objType.fields[intI];
			if (isUdt(objField.type))
			{
				udtLeaves(objField.type, strPrefix_a + '.' + objField.name, arrResult);
			}
			else
			{
				arrResult.push({ path: strPrefix_a + '.' + objField.name, type: objField.type, dims: objField.dims });
			}
		}

		return arrResult;
	}

	function leafSize(strType_a)
	{
		return (strType_a === 'str') ? 41 : ((strType_a === 'long') ? 4 : 2);
	}

	// message for a whole array / Type used as a value
	function wholeMsg(objEl_a)
	{
		return (objEl_a.etype === 'array') ? ('array needs an index: ' + objEl_a.id) : (objEl_a.id + ' needs a .member');
	}

	function compileInput(strArgs_a)
	{
		var arrMatch = strArgs_a.match(/^\s*"((?:[^"]|"")*)"\s*([;,])\s*(.*)$/);
		var arrVars = [];
		var intI = 0;
		var objTarget = null;
		var objElement = null;
		var strName = '';
		var strPrompt = '? ';
		var strRest = strArgs_a;

		if (arrMatch)
		{
			strPrompt = arrMatch[1].replace(/""/g, '"') + ((arrMatch[2] === ';') ? '? ' : '');
			strRest = arrMatch[3];
		}

		arrVars = splitTop(strRest, ',');
		for (intI = 0; intI < arrVars.length; intI++)
		{
			strName = trim(arrVars[intI].text);
			if (!/^[a-z_][\w.]*[$%&!#@]?$/i.test(strName))
			{
				error('INPUT needs a variable: ' + strName);
				continue;
			}
			objElement = resolve(strName, true, true);
			if ((intPass === 1) && objElement && !objElement.typed)
			{
				objScanInput[objElement.full] = true;
			}
			noteWrite(objElement);
			objTarget = writeTarget(strName);
			if (objTarget === null)
			{
				error('INPUT needs a variable: ' + strName);
				continue;
			}
			if (strPrompt.length > 0)
			{
				emitZoscii(textToBytes(strPrompt));
				strPrompt = '';
			}
			emit(objTarget.str ? 'kw_inputstr' : (objTarget.lng ? 'kw_l_input' : 'kw_inputint'), [objTarget.label]);
			if (fixedLen(objTarget.el) > 0)
			{
				emit('kw_strfix', [objTarget.label, fixedLen(objTarget.el)]);
			}
		}
	}

	// ------------------------------------------------------------
	// FOR / NEXT
	// ------------------------------------------------------------

	// FOR limit / step: literal stays literal, anything else gets its own var
	function forValue(strExpr_a, strLabel_a)
	{
		var objResult = compileExpr(strExpr_a, strLabel_a, 0);

		if (objResult.k === 'd')
		{
			objResult = (objResult.lv !== undefined) ? lit(objResult.lv) : numVar(objResult, 0);
		}
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
		var objCtl = { type: 'FOR', line: intLine, name: '', id: intId, top: 'for' + intId + '_t', end: 'for' + intId + '_e', varl: '', lim: null, step: null, mode: strMode };
		var objStart = null;
		var objTarget = null;
		var objValue = null;
		var objElement = resolve(strVar_a, true, true);

		if ((intPass === 1) && objElement && !objElement.typed)
		{
			objScanNumAssign[objElement.full] = true;
		}
		noteWrite(objElement);
		objTarget = writeTarget(strVar_a);
		if ((objTarget === null) || objTarget.str)
		{
			error('FOR needs a number variable');
			objTarget = { label: tmp(9), str: false };
		}
		objCtl.varl = objTarget.label;
		objCtl.name = objTarget.label;

		if (objTarget.lng)
		{
			compileLongFor(objCtl, strStart_a, strLimit_a, strStep_a);
			return;
		}

		objStart = compileAssign(objCtl.varl, strStart_a, 0);
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
				emit(((objCtl.step.v >= 0) ? 'kw_forup' : 'kw_fordn') + objCtl.lim.k, [objCtl.varl, objCtl.lim, objCtl.end]);
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
			emit('kw_forentry', [objCtl.varl, objCtl.step, objCtl.lim, objCtl.end]);
		}

		emitLabel(objCtl.top);
		arrCtl.push(objCtl);
	}

	// FOR with a Long counter: constant STEP, limit worked out once
	function compileLongFor(objCtl_a, strStart_a, strLimit_a, strStep_a)
	{
		var objStep = strStep_a ? evalConst(strStep_a) : lit(1);
		var objLimit = evalConst(strLimit_a);
		var strLimit = '';

		var strNeg = '';

		objCtl_a.lng = true;
		compileAssign(objCtl_a.varl, strStart_a, 0);
		if ((objLimit !== null) && isConstNum(objLimit))
		{
			strLimit = llitLabel(constNum(objLimit));
		}
		else
		{
			strLimit = declare('for' + objCtl_a.id + '_l', 'long', 0);
			compileAssign(strLimit, strLimit_a, 0);
		}
		objCtl_a.llim = strLimit;
		if ((objStep === null) || !isConstNum(objStep))
		{
			// step from a variable: worked out once, its sign picks the test
			objCtl_a.lstep = declare('for' + objCtl_a.id + '_s', 'long', 0);
			compileAssign(objCtl_a.lstep, strStep_a, 0);
			strNeg = 'for' + objCtl_a.id + '_n';
			emit('kw_l_cplt', [objCtl_a.lstep, llitLabel(0)]);
			emit('kw_goto_iftrue', [strNeg]);
			emit('kw_l_cpgt', [objCtl_a.varl, strLimit]);
			emit('kw_goto_iftrue', [objCtl_a.end]);
			emit('kw_goto', [objCtl_a.top]);
			emitLabel(strNeg);
			emit('kw_l_cplt', [objCtl_a.varl, strLimit]);
			emit('kw_goto_iftrue', [objCtl_a.end]);
			emitLabel(objCtl_a.top);
			arrCtl.push(objCtl_a);
			return;
		}
		objCtl_a.stepv = (objStep.k === 'l') ? objStep.v : objStep.lv;
		emit((objCtl_a.stepv >= 0) ? 'kw_l_cpgt' : 'kw_l_cplt', [objCtl_a.varl, strLimit]);
		emit('kw_goto_iftrue', [objCtl_a.end]);
		emitLabel(objCtl_a.top);
		arrCtl.push(objCtl_a);
	}

	// For Each x In arr (an array, 1 dimension): a hidden counter from LBound to
	// UBound, x = arr(counter) at the top of each pass. Next x closes it.
	function compileForEach(strVar_a, strArr_a)
	{
		var intId = newId();
		var objArray = resolve(strArr_a, false, false);
		var objCounter = null;
		var objCtl = null;
		var objTarget = null;
		var strCounter = '__fe' + intId;

		if ((objArray === null) || (objArray.etype !== 'array') || objArray.udt)
		{
			error('For Each needs an array (not an array of a Type): ' + strArr_a);
			return;
		}
		if (!isDescArray(objArray) && (dimsOf(objArray).length !== 1))
		{
			error('For Each: 1 dimension arrays only');
			return;
		}
		objCounter = {
			etype: 'var', scope: (strProc.length > 0) ? 'local' : 'module',
			full: ((strProc.length > 0) ? strProc : strModule) + '.' + strCounter,
			id: strCounter, module: strModule, proc: strProc,
			datatype: 'int', typed: true, isstatic: true
		};
		objEl[objCounter.full] = objCounter;
		compileFor(strCounter, 'lbound(' + strArr_a + ')', 'ubound(' + strArr_a + ')', null);
		objCtl = ctlTop('FOR');
		objTarget = writeTarget(strVar_a);
		if ((objCtl !== null) && (objTarget !== null))
		{
			objCtl.alias = objTarget.label;		// Next x
		}
		compileAssignRecord({ target: strVar_a, expr: strArr_a + '(' + strCounter + ')' });
	}

	function compileNext(arrVars_a)
	{
		var arrNames = (arrVars_a.length > 0) ? arrVars_a : [''];
		var intI = 0;
		var objCtl = null;
		var objTarget = null;
		var strName = '';

		for (intI = 0; intI < arrNames.length; intI++)
		{
			strName = trim(arrNames[intI]);
			objCtl = ctlTop('FOR');
			if ((objCtl !== null) && (strName.length > 0))
			{
				objTarget = writeTarget(strName);
				if ((objTarget === null) || ((objTarget.label !== objCtl.name) && (objTarget.label !== objCtl.alias)))
				{
					error('NEXT ' + strName + ' does not match FOR at line ' + objCtl.line);
					return;
				}
			}
			objCtl = ctlClose('FOR', 'NEXT');
			if (objCtl === null)
			{
				return;
			}
			modeCheck(objCtl, 'For');

			if (objCtl.lng && objCtl.lstep)
			{
				emit('kw_l_add', [objCtl.varl, objCtl.lstep, objCtl.varl]);
				emit('kw_l_cplt', [objCtl.lstep, llitLabel(0)]);
				emit('kw_goto_iftrue', ['for' + objCtl.id + '_m']);
				emit('kw_l_cple', [objCtl.varl, objCtl.llim]);
				emit('kw_goto_iftrue', [objCtl.top]);
				emit('kw_goto', [objCtl.end]);
				emitLabel('for' + objCtl.id + '_m');
				emit('kw_l_cpge', [objCtl.varl, objCtl.llim]);
				emit('kw_goto_iftrue', [objCtl.top]);
			}
			else if (objCtl.lng)
			{
				emit('kw_l_add', [objCtl.varl, llitLabel(objCtl.stepv), objCtl.varl]);
				emit((objCtl.stepv >= 0) ? 'kw_l_cple' : 'kw_l_cpge', [objCtl.varl, objCtl.llim]);
				emit('kw_goto_iftrue', [objCtl.top]);
			}
			else if (objCtl.step.k === 'l')
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

	// ------------------------------------------------------------
	// other statements
	// ------------------------------------------------------------

	function compileTwoValues(arrArgs_a, strWord_a)
	{
		if (arrArgs_a.length !== 2)
		{
			error(strWord_a + ' needs two values');
			return null;
		}

		return [compileValue(arrArgs_a[0], 0), compileValue(arrArgs_a[1], 1)];
	}

	function compilePoke(arrArgs_a, blnWord_a)
	{
		var arrValues = compileTwoValues(arrArgs_a, blnWord_a ? 'DOKE' : 'POKE');
		var strSize = blnWord_a ? '' : '8';

		if (arrValues === null)
		{
			return;
		}
		// arrValues[0] = address, arrValues[1] = value
		emit('kw_' + ((arrValues[1].k === 'l') ? 'l' : 'v') + 'to' + ((arrValues[0].k === 'l') ? 'l' : 'v') + 'ptr' + strSize, [arrValues[1], arrValues[0]]);
	}

	function compileLocate(arrArgs_a)
	{
		var arrValues = compileTwoValues(arrArgs_a, 'LOCATE');

		if (arrValues === null)
		{
			return;
		}
		if ((arrValues[0].k === 'l') && (arrValues[1].k === 'l'))
		{
			emit('kw_locatell', [arrValues[0], arrValues[1]]);
		}
		else
		{
			emit('kw_locatevv', [numVar(arrValues[0], 0), numVar(arrValues[1], 1)]);
		}
	}

	// target = expr
	function compileAssignRecord(objRec_a)
	{
		var objTarget = null;
		var objIndex2 = null;
		var arrMatch = null;
		var arrIndex = [];
		var intI = 0;
		var objElement = null;
		var objIndex = null;
		var objValue = null;
		var objSrc = null;
		var objType = null;
		var strBase = '';
		var strName = '';
		var strTarget = rewriteFields(objRec_a.target);

		// array element: name(index) = expr
		if ((arrMatch = strTarget.match(/^([a-z_][\w.]*[$%&!#@]?)\s*\((.*)\)$/i)))
		{
			// Mid$(s, start[, length]) = text: replace in place
			if (/^mid\$?$/i.test(arrMatch[1]) && (resolve(arrMatch[1], false, false) === null))
			{
				arrIndex = splitTop(arrMatch[2], ',');
				objTarget = (arrIndex.length >= 2) ? writeTarget(trim(arrIndex[0].text)) : null;
				if ((objTarget === null) || !objTarget.str || (arrIndex.length > 3))
				{
					error('Mid$ = needs a String variable, a start and maybe a length');
					return;
				}
				noteWrite(objTarget.el);
				objIndex = compileValue(arrIndex[1].text, 0);
				objValue = (arrIndex.length === 3) ? compileValue(arrIndex[2].text, 1) : lit(255);
				objIndex = keepSlot(numVar(objIndex, 0), 0);
				objValue = keepSlot(numVar(objValue, 1), 1);
				objSrc = strOf(compileExpr(objRec_a.expr, null, 2), 2);
				emit('kw_strmidset', [objTarget.label, numAddr(objIndex, 0), numAddr(objValue, 1), objSrc.n]);
				return;
			}
			objElement = resolve(arrMatch[1], false, true);
			if ((objElement === null) || (objElement.etype !== 'array'))
			{
				if ((objElement !== null) && (objElement.etype === 'proc') && ((objElement.kind === 'proplet') || (objElement.kind === 'propset')))
				{
					// Obj.Prop(i) = v: Property Let Prop(i, v)
					procCall(objElement, splitTop(arrMatch[2], ',').map(function(objPart_a) { return objPart_a.text; }).concat([objRec_a.expr]), false, 0, null);
					return;
				}
				error(arrMatch[1] + ' is not an array (Dim it first)');
				return;
			}
			arrIndex = splitTop(arrMatch[2], ',');
			for (intI = 0; intI < arrIndex.length; intI++)
			{
				arrIndex[intI] = compileValue(arrIndex[intI].text, intI);
			}
			if (isDescArray(objElement))
			{
				if ((arrIndex.length !== 1) && (arrIndex.length !== 2))
				{
					error(objElement.id + ': 1 or 2 indexes');
					return;
				}
				objIndex = keepSlot(arrIndex[0], 0);
				objIndex2 = (arrIndex.length === 2) ? keepSlot(arrIndex[1], 1) : null;
				objValue = compileExpr(objRec_a.expr, null, 2);
				if (typeOfEl(objElement) === 'str')
				{
					strName = strOf(objValue, 2).n;
				}
				else if (typeOfEl(objElement) === 'long')
				{
					strName = longAddr((objValue.k === 'f') ? numVar(objValue, 2) : objValue, 2);
				}
				else
				{
					if (objValue.k === 's')
					{
						emit('kw_strval', [objValue.n, tmp(2)]);
						objValue = vr(tmp(2));
					}
					strName = numAddr(objValue, 2);
				}
				if (objIndex2 !== null)
				{
					emit('kw_pset2', [descLabel(objElement), numAddr(objIndex, 0), numAddr(objIndex2, 1), strName]);
				}
				else
				{
					emit('kw_pset', [descLabel(objElement), numAddr(objIndex, 0), strName]);
				}
				return;
			}
			strBase = arrayLabel(objElement);
			objIndex = arrayIndex(objElement, arrIndex, 0);
			if (typeOfEl(objElement) === 'str')
			{
				if (objIndex.lit !== undefined)
				{
					compileStringAssign(offsetLabel(strBase, objIndex.lit * 41), objRec_a.expr);
					return;
				}
				objIndex.v = keepSlot(numVar(objIndex.v, 0), 0);
				objValue = strOf(compileExpr(objRec_a.expr, null, 1), 1);
				emit('kw_sset', [offsetLabel(strBase, -objIndex.adjust * 41), objIndex.v, objValue.n]);
				return;
			}
			if (isByteArray(objElement))
			{
				if (objIndex.lit === undefined)
				{
					objIndex.v = keepSlot(numVar(objIndex.v, 0), 0);
				}
				objValue = compileValue(objRec_a.expr, 1);
				if (objIndex.lit !== undefined)
				{
					emit((objValue.k === 'l') ? 'kw_ltolptr8' : 'kw_vtolptr8', [objValue, offsetLabel(strBase, objIndex.lit)]);
				}
				else
				{
					emit('kw_aset8', [offsetLabel(strBase, -objIndex.adjust), objIndex.v, numAddr(objValue, 1)]);
				}
				return;
			}
			if (typeOfEl(objElement) === 'long')
			{
				if (objIndex.lit !== undefined)
				{
					compileAssign(offsetLabel(strBase, objIndex.lit * 4), objRec_a.expr, 0);
					return;
				}
				objIndex.v = keepSlot(numVar(objIndex.v, 0), 0);
				objValue = compileExpr(objRec_a.expr, null, 1);
				if (objValue.k === 'f')
				{
					objValue = numVar(objValue, 1);
				}
				emit('kw_l_aset', [offsetLabel(strBase, -objIndex.adjust * 4), objIndex.v, longAddr(objValue, 1)]);
				return;
			}
			if (objIndex.lit !== undefined)
			{
				compileAssign(offsetLabel(strBase, objIndex.lit * 2), objRec_a.expr, 0);
				return;
			}
			objIndex.v = keepSlot(numVar(objIndex.v, 0), 0);
			objValue = compileValue(objRec_a.expr, 1);
			emit((objValue.k === 'l') ? 'kw_asetl' : 'kw_aset', [offsetLabel(strBase, -objIndex.adjust * 2), objIndex.v, objValue]);
			return;
		}

		objElement = resolve(strTarget, true, true);
		if (objElement === null)
		{
			error('cannot assign to ' + objRec_a.target);
			return;
		}

		switch (objElement.etype)
		{
			case 'const':
				error('cannot assign to the Const ' + objRec_a.target);
				return;
			case 'array':
				// a() = Split(text [, sep]): a dynamic String array
				if ((arrMatch = trim(objRec_a.expr).match(/^split\s*\((.*)\)$/i)) && isDynArray(objElement) && (typeOfEl(objElement) === 'str'))
				{
					compileSplit(objElement, splitTop(arrMatch[1], ','));
					return;
				}
				error('array needs an index: ' + objRec_a.target);
				return;
			case 'proc':
				if ((objElement.kind === 'proplet') || (objElement.kind === 'propset'))
				{
					procCall(objElement, [objRec_a.expr], false, 0, null);
					return;
				}
				error('cannot assign to ' + objRec_a.target);
				return;
			default:
				break;
		}

		// a whole Type: copy field by field
		if (objElement.udt)
		{
			objSrc = resolve(trim(objRec_a.expr), false, false);
			if ((objSrc === null) || !objSrc.udt || (objSrc.datatype !== objElement.datatype))
			{
				error('a ' + objElement.datatype + ' can only be set from another ' + objElement.datatype);
				return;
			}
			objType = objEl[objElement.datatype];
			for (intI = 0; intI < objType.fields.length; intI++)
			{
				compileAssignRecord({ target: objRec_a.target + '.' + objType.fields[intI].name, expr: objRec_a.expr + '.' + objType.fields[intI].name });
			}
			return;
		}

		if ((intPass === 1) && !objElement.typed)
		{
			if (exprType(objRec_a.expr) === 's')
			{
				objScanStrAssign[objElement.full] = true;
			}
			else
			{
				objScanNumAssign[objElement.full] = true;
			}
		}
		noteWrite(objElement);

		strName = varLabel(objElement);
		if (typeOfEl(objElement) === 'str')
		{
			compileStringAssign(strName, objRec_a.expr);
			if (fixedLen(objElement) > 0)
			{
				emit('kw_strfix', [strName, fixedLen(objElement)]);		// pad / cut to n
			}
		}
		else
		{
			compileAssign(strName, objRec_a.expr, 0);
		}
	}

	// a procedure call statement (or CALL address)
	function compileCallRecord(objRec_a)
	{
		var objElement = resolve(objRec_a.name, false, false);
		var objValue = null;
		var objValues = null;
		var strLabel = '';
		var strShow = '';
		var arrArgs = [];
		var intI = 0;

		if ((objElement !== null) && (objElement.etype === 'proc'))
		{
			if ((objElement.kind === 'proplet') || (objElement.kind === 'propset'))
			{
				error(objRec_a.name + ' is a property, use = to set it');
				return;
			}
			if (objElement.kind === 'function')
			{
				arrMatch = String(objElement.src || '').match(/\b(?:function)\s+([A-Za-z_]\w*)/i);
				warning('the result of ' + (arrMatch ? arrMatch[1] : objElement.id) + ' is not used (a status that is never checked?)');
			}
			procCall(objElement, objRec_a.args, false, 0, null);
			return;
		}
		if (objRec_a.explicit)
		{
			// CALL address: machine code run as a keyword
			objValue = compileValue(objRec_a.raw, 0);
			if (objValue.k === 'l')
			{
				arrOut.push({ t: 'bp', name: argText(objValue) });
			}
			else
			{
				emit('kw_callv', [objValue]);
			}
			return;
		}
		switch (objRec_a.name)
		{
			case 'lset':
			case 'rset':
				// LSet s = x / RSet s = x: x left / right in s's length, padded with spaces
				arrMatch = (objRec_a.args.length === 1) ? objRec_a.args[0].match(/^\s*([a-z_][\w.]*\$?)\s*=\s*(.+)$/i) : null;
				objTarget = (arrMatch !== null) ? writeTarget(arrMatch[1]) : null;
				if ((objTarget === null) || !objTarget.str)
				{
					error(objRec_a.name.toUpperCase() + ' needs: ' + objRec_a.name + ' stringvar = text');
					return;
				}
				noteWrite(objTarget.el);
				objValue = strOf(compileExpr(arrMatch[2], null, 0), 0);
				emit((objRec_a.name === 'lset') ? 'kw_strlset' : 'kw_strrset', [objTarget.label, objValue.n]);
				return;
			case 'doevents':
				// DoEvents: a safe point - normal mode lets interrupts in (turbo: nothing)
				if (kwMode() === 'n')
				{
					emit('kw_irq', []);
				}
				return;
			case 'interrupt':
				// Interrupt MySub / Interrupt Off - a Sub run after interrupts (normal mode)
				if ((objRec_a.args.length === 1) && (trim(objRec_a.args[0]) === 'off'))
				{
					emit('kw_hookoff', []);
					return;
				}
				objElement = (objRec_a.args.length === 1) ? resolve(trim(objRec_a.args[0]), false, false) : null;
				if ((objElement === null) || (objElement.etype !== 'proc') || (objElement.kind !== 'sub') || (procParams(objElement).length > 0))
				{
					error('Interrupt needs a Sub with no parameters (or Off)');
					return;
				}
				objHookProcs[objElement.full] = true;
				blnHookUsed = true;
				if (intPass === 1)
				{
					arrScanProcCalls.push({ from: strProc, to: objElement.full, mode: 'n', line: intLine, file: strFile });
				}
				emit('kw_hookon', [procLabel(objElement, 'n') + '_c']);
				return;
			case 'calladdr':
				// CallAddr ptr [, arg, ...] - call the procedure whose AddressOf is in ptr.
				// Arguments are passed by address; they must match its parameters
				if (objRec_a.args.length < 1)
				{
					error('CallAddr needs an address (from AddressOf)');
					return;
				}
				arrArgs = [];
				for (intI = 0; intI < objRec_a.args.length; intI++)
				{
					objValue = compileExpr(objRec_a.args[intI], null, intI);
					if (objValue.k === 's')
					{
						arrArgs.push(objValue.n);
					}
					else if (objValue.k === 'd')
					{
						arrArgs.push(objValue.n);
					}
					else
					{
						if ((intI > 0) && (objValue.k !== 'v'))
						{
							objValue = numVar(objValue, intI);
						}
						arrArgs.push(numAddr(objValue, intI));
					}
				}
				emit('kw_callp', arrArgs);
				return;
			case 'out':
				// Out port, value - a 16 bit port (B = high byte on the CPC)
				objValues = compileTwoValues(objRec_a.args, 'OUT');
				if (objValues !== null)
				{
					emit('kw_out', [numAddr(objValues[0], 0), numAddr(objValues[1], 1)]);
				}
				return;
			case 'error':
				// Error text - a diagnostic: print it with the place, then stop
				if (objRec_a.args.length !== 1)
				{
					error('Error needs one value (the message)');
					return;
				}
				emit('kw_printnl0', []);
				compilePrint('"Error: "; ' + objRec_a.args[0] + '; " (' + strFile + ' line ' + intLine + ')"');
				emit('kw_stop', []);
				blnLastTransfer = true;
				return;
			case 'debug.assert':
				// Debug.Assert condition - when false: print it with the place, then stop
				if (objRec_a.args.length !== 1)
				{
					error('Debug.Assert needs one condition');
					return;
				}
				strLabel = 'as' + newId() + '_ok';
				compileCond(objRec_a.args[0], strLabel, true);
				emit('kw_printnl0', []);
				// show the condition as written when the line is just this statement
				strShow = trim(objRec_a.args[0]);
				if (objRec_a.src && /^debug\.assert\s/i.test(objRec_a.src) && !/[:'"]/.test(objRec_a.src))
				{
					strShow = trim(objRec_a.src.substr(12));
				}
				compilePrint('"Assert failed: ' + strShow.replace(/"/g, '""') + ' (' + strFile + ' line ' + intLine + ')"');
				emit('kw_stop', []);
				emitLabel(strLabel);
				return;
			default:
				break;
		}
		error('unknown statement or procedure: ' + objRec_a.raw);
	}

	// On x GoTo a, b, c / On x GoSub a, b, c (x = 1 picks a; out of range goes on)
	function compileOnGoto(objRec_a)
	{
		var intI = 0;
		var intId = newId();
		var objValue = compileValue(objRec_a.expr, 0);
		var strLabel = '';
		var strSkip = '';

		if (objValue.k === 'l')
		{
			if ((objValue.v >= 1) && (objValue.v <= objRec_a.targets.length))
			{
				strLabel = trim(objRec_a.targets[objValue.v - 1]);
				if (objRec_a.gosub)
				{
					compileGosub(targetLabel(strLabel, 'gosub'));
				}
				else
				{
					emit('kw_goto', [targetLabel(strLabel) + strCopy]);
				}
			}
			return;
		}
		objValue = keepSlot(numVar(objValue, 0), 0);
		if (/^tmp\d+$/.test(objValue.n))
		{
			emit('kw_vtov', [objValue, declare('on' + intId + '_v', 'int', 0)]);	// GoSub may change temps
			objValue = vr('on' + intId + '_v');
		}
		for (intI = 0; intI < objRec_a.targets.length; intI++)
		{
			strLabel = trim(objRec_a.targets[intI]);
			emitCompare('=', objValue, lit(intI + 1));
			if (objRec_a.gosub)
			{
				strSkip = 'on' + intId + '_' + intI;
				emit('kw_goto_iffalse', [strSkip]);
				compileGosub(targetLabel(strLabel, 'gosub'));
				emit('kw_goto', ['on' + intId + '_e']);
				emitLabel(strSkip);
			}
			else
			{
				emit('kw_goto_iftrue', [targetLabel(strLabel) + strCopy]);
			}
		}
		if (objRec_a.gosub)
		{
			emitLabel('on' + intId + '_e');
		}
	}

	// GOSUB / RETURN (per procedure, labels belong to their procedure)
	function subOwner(strProc_a, intLine_a)
	{
		var intI = 0;
		var strResult = '';

		for (intI = 0; intI < arrSubs.length; intI++)
		{
			if ((arrSubs[intI].proc === strProc_a) && (arrSubs[intI].line <= intLine_a))
			{
				strResult = arrSubs[intI].label;
			}
		}

		return strResult;
	}

	function compileGosub(strLabel_a)
	{
		var strName = strLabel_a + strCopy;

		if (objFastSub[strLabel_a] === true)
		{
			emitRaw(strName + '_gs', [], false);
			if (objFastUse[strName] === undefined)
			{
				objFastUse[strName] = true;
				arrFastUse.push(strName);
			}
		}
		else
		{
			emit('kw_gosub', [strName]);
			blnGosub = true;
		}
	}

	function compileReturn()
	{
		var strOwner = '';

		if (intPass === 1)
		{
			arrScanReturns.push({ line: intLine, proc: strProc });
		}
		strOwner = subOwner(strProc, intLine);
		if ((strOwner.length > 0) && (objFastSub[strOwner] === true))
		{
			emitRaw(strOwner + strCopy + '_rt', [], true);
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

		for (intI = 0; intI < arrScanCalls.length; intI++)
		{
			strLabel = arrScanCalls[intI].label;
			if ((objLabels[strLabel] !== undefined) && (objSeen[strLabel] === undefined))
			{
				objSeen[strLabel] = true;
				arrSubs.push({ label: strLabel, line: objLabels[strLabel], proc: arrScanCalls[intI].proc });
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
				strFrom = subOwner(arrSubs[intI].proc, arrSubs[intI].line - 1);
				if (strFrom.length > 0)
				{
					objBad[strFrom] = true;
				}
			}
		}

		// needs a RETURN of its own
		for (intI = 0; intI < arrScanReturns.length; intI++)
		{
			strLabel = subOwner(arrScanReturns[intI].proc, arrScanReturns[intI].line);
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
				strFrom = subOwner(arrScanJumps[intI].proc, arrScanJumps[intI].line);
				strTo = subOwner(arrScanJumps[intI].proc, objLabels[arrScanJumps[intI].label]);
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
			strFrom = arrScanCalls[intI].proc + '|' + subOwner(arrScanCalls[intI].proc, arrScanCalls[intI].line);
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
			arrQueue = (objEdges[arrSubs[intI].proc + '|' + strLabel] !== undefined) ? objEdges[arrSubs[intI].proc + '|' + strLabel].slice(0) : [];
			while (arrQueue.length > 0)
			{
				strTo = arrQueue.pop();
				if (strTo === strLabel)
				{
					objBad[strLabel] = true;
					break;
				}
				if ((objSeen[strTo] === undefined) && (objEdges[arrSubs[intI].proc + '|' + strTo] !== undefined))
				{
					objSeen[strTo] = true;
					for (intJ = 0; intJ < objEdges[arrSubs[intI].proc + '|' + strTo].length; intJ++)
					{
						arrQueue.push(objEdges[arrSubs[intI].proc + '|' + strTo][intJ]);
					}
				}
			}
		}

		for (intI = 0; intI < arrSubs.length; intI++)
		{
			if (objBad[arrSubs[intI].label] !== true)
			{
				objFastSub[arrSubs[intI].label] = true;
			}
		}
	}

	// after pass 1: recursion check and the modes each procedure is needed in
	function decideProcs()
	{
		var arrQueue = [];
		var intI = 0;
		var objCall = null;
		var objEdges = {};
		var objItem = null;
		var objState = {};
		var strMode_ = '';

		for (intI = 0; intI < arrScanProcCalls.length; intI++)
		{
			objCall = arrScanProcCalls[intI];
			if (objEdges[objCall.from] === undefined)
			{
				objEdges[objCall.from] = [];
			}
			objEdges[objCall.from].push(objCall);
		}

		// recursion: depth first, a procedure seen again on the path
		function visit(strProc_a, arrPath_a)
		{
			var intJ = 0;
			var arrList = objEdges[strProc_a] || [];

			if (objState[strProc_a] === 2)
			{
				return;
			}
			objState[strProc_a] = 1;
			for (intJ = 0; intJ < arrList.length; intJ++)
			{
				if (objState[arrList[intJ].to] === 1)
				{
					arrErrors.push({ file: arrList[intJ].file, line: arrList[intJ].line, msg: 'recursion is not supported: ' + (objEl[arrList[intJ].to] ? objEl[arrList[intJ].to].id : arrList[intJ].to) + ' can call itself' });
				}
				else
				{
					visit(arrList[intJ].to, arrPath_a);
				}
			}
			objState[strProc_a] = 2;
		}
		visit('', []);
		for (intI = 0; intI < arrProcOrder.length; intI++)
		{
			visit(arrProcOrder[intI], []);
		}

		// modes: main runs in the start mode, a call passes its mode on
		objProcModes = {};
		arrQueue = [{ proc: '', mode: strStartMode }];
		while (arrQueue.length > 0)
		{
			objItem = arrQueue.shift();
			if (objEdges[objItem.proc] === undefined)
			{
				continue;
			}
			for (intI = 0; intI < objEdges[objItem.proc].length; intI++)
			{
				objCall = objEdges[objItem.proc][intI];
				strMode_ = (objCall.mode === 'E') ? objItem.mode : objCall.mode;
				if (objProcModes[objCall.to] === undefined)
				{
					objProcModes[objCall.to] = {};
				}
				if (objProcModes[objCall.to][strMode_] !== true)
				{
					objProcModes[objCall.to][strMode_] = true;
					arrQueue.push({ proc: objCall.to, mode: strMode_ });
				}
			}
		}
	}

	// {name} inside #asm: the label (or value) of a BASIC name
	function asmName(strName_a)
	{
		var objElement = null;
		var objConst = null;
		var strName = trim(strName_a).toLowerCase();

		if ((strName === 'result') && (strProc.length > 0) && objEl[strProc] && ((objEl[strProc].kind === 'function') || (objEl[strProc].kind === 'propget')))
		{
			return varLabel(objEl[strProc + '.' + objEl[strProc].id]);
		}
		objElement = resolve(strName, false, false);
		if ((objElement === null) && (baseLabel(strName).length > 0) && (objLabels[baseLabel(strName)] !== undefined))
		{
			return baseLabel(strName) + strCopy;		// a BASIC label / line number: ld sp, {label} / ret jumps there
		}
		if (objElement === null)
		{
			error('#asm: not found: {' + strName_a + '}');
			return '0';
		}
		switch (objElement.etype)
		{
			case 'const':
				objConst = constValue(objElement);
				if (objConst.k === 'str')
				{
					error('#asm: {' + strName_a + '} is a string Const');
					return '0';
				}
				return String(constNum(objConst));
			case 'array':
				return isDescArray(objElement) ? descLabel(objElement) : arrayLabel(objElement);
			case 'var':
			case 'param':
			case 'result':
				if (objElement.udt)
				{
					error('#asm: {' + strName_a + '} is a Type - use {' + strName_a + '.field}');
					return '0';
				}
				noteWrite(objElement);		// the block may write it (ByRef copy back)
				return varLabel(objElement);
			default:
				error('#asm: {' + strName_a + '} is not a variable, array or Const');
				return '0';
		}
	}

	// #asm ... #endasm: an inline keyword. The thread gets one word; the code
	// goes with the stubs. Labels in the block are local to it. A block that
	// moves SP (ld sp,) is a branch: its normal mode copy ends with jp ntc_xn.
	function compileAsm(objRec_a)
	{
		var blnNormal = (kwMode() === 'n');
		var strName = 'asm_' + (objRec_a.fileno || 0) + '_' + objRec_a.line + (blnNormal ? '_n' : '');

		asmBlock(objRec_a, strName, blnNormal, '#asm');
		emitRaw(strName, [], false);
	}

	// the code of a #asm block, kept once under strName_a
	function asmBlock(objRec_a, strName_a, blnNormal_a, strTitle_a)
	{
		var arrCode = [];
		var arrLines = objRec_a.lines;
		var arrMatch = null;
		var blnBranch = false;
		var blnNormal = blnNormal_a;
		var intCut = 0;
		var intI = 0;
		var objLocal = {};
		var strCode = '';
		var strComment = '';
		var strLine = '';
		var strName = strName_a;

		for (intI = 0; intI < arrLines.length; intI++)
		{
			strCode = arrLines[intI].substr(0, codePart(arrLines[intI]));
			if ((arrMatch = strCode.match(/^\s*([A-Za-z_]\w*):/)))
			{
				objLocal[arrMatch[1]] = true;
			}
			if (/^\s*ld\s+sp\s*,/i.test(strCode))
			{
				blnBranch = true;
			}
		}

		arrCode.push(strName + ':\t\t; ' + strTitle_a + ', ' + objRec_a.file + ' line ' + objRec_a.line + (blnNormal ? ' (normal)' : ''));
		for (intI = 0; intI < arrLines.length; intI++)
		{
			strLine = arrLines[intI];
			intCut = codePart(strLine);
			strCode = strLine.substr(0, intCut);
			strComment = strLine.substr(intCut);
			strCode = strCode.replace(/\{([^{}]+)\}/g, function(strAll_a, strInner_a)
			{
				return asmName(strInner_a);
			});
			if (blnNormal && blnBranch)
			{
				if ((arrMatch = strCode.match(/^(\s+)ret\s*$/i)))
				{
					strCode = arrMatch[1] + 'jp ntc_xn';
				}
				else if ((arrMatch = strCode.match(/^(\s+)ret\s+(n?z|n?c|po|pe|p|m)\s*$/i)))
				{
					strCode = arrMatch[1] + 'jp ' + arrMatch[2] + ', ntc_xn';
				}
			}
			strCode = strCode.replace(/[A-Za-z_]\w*/g, function(strWord_a)
			{
				if (objLocal[strWord_a] === true)
				{
					return strName + '_' + strWord_a;
				}
				if (blnNormal && blnBranch && (strWord_a === 'ntc_next'))
				{
					return 'ntc_xn';
				}
				return strWord_a;
			});
			// a label at the start of a line gets the usual indent for the rest
			if (/^\S/.test(strCode) && !/^[A-Za-z_]\w*:/.test(strCode) && (trim(strCode).length > 0))
			{
				strCode = '\t\t\t' + trim(strCode);
			}
			// the BASIC line, so an assembler error points back to the source
			if (objOptions.sourcecomments && (trim(strCode).length > 0))
			{
				strComment = (strComment.length > 0) ? (strComment + ' [' + (objRec_a.line + 1 + intI) + ']') : ('\t\t; ' + objRec_a.file + ' ' + (objRec_a.line + 1 + intI));
			}
			arrCode.push(strCode + strComment);
		}
		arrCode.push('\t\t\t' + ((blnNormal && blnBranch) ? 'jp ntc_xn' : 'ret') + '\t\t\t; end of #asm');

		if (objAsmDone[strName] === undefined)
		{
			objAsmDone[strName] = true;
			arrAsmBlocks.push({ name: strName, lines: arrCode, orig: arrLines, file: objRec_a.file, line: objRec_a.line, module: objRec_a.module, proc: objRec_a.proc });
		}
	}

	// keyword label of an asm keyword procedure
	function asmKwLabel(objProc_a)
	{
		return 'fn_' + procBase(objProc_a).substr(2);
	}

	// A Sub or Function whose whole body is one #asm block that does not use
	// {param} or {result} becomes a keyword: dw fn_x, arg address, ...
	// [, result address]. The block pops them itself and ends with ret.
	// No stubs, no body thread, no saved return point.
	function findAsmKeywords()
	{
		var objHooked = {};
		var intI = 0;
		var intJ = 0;
		var arrRecs = null;
		var objProc = null;
		var objNames = null;
		var blnOk = false;
		var strCode = '';

		// AddressOf / Interrupt need the call stub: those stay procedures
		for (intI = 0; intI < arrRecords.length; intI++)
		{
			String(arrRecords[intI].src || '').replace(/\b(?:addressof|interrupt)\s+([a-z_][\w.]*)/gi, function(strAll_a, strName_a)
			{
				objHooked[strName_a.toLowerCase().split('.').pop()] = true;
				return strAll_a;
			});
		}
		for (intI = 0; intI < arrProcOrder.length; intI++)
		{
			arrRecs = objProcRecs[arrProcOrder[intI]];
			objProc = objEl[arrProcOrder[intI]];
			if (!objProc || ((objProc.kind !== 'sub') && (objProc.kind !== 'function')) || (arrRecs.length !== 3) || (arrRecs[1].k !== 'asm') || (objHooked[objProc.id.toLowerCase()] === true))
			{
				continue;
			}
			objNames = { result: true };
			procParams(objProc).forEach(function(objParam_a)
			{
				objNames[objParam_a.name.toLowerCase()] = true;
			});
			blnOk = true;
			for (intJ = 0; intJ < arrRecs[1].lines.length; intJ++)
			{
				strCode = arrRecs[1].lines[intJ].substr(0, codePart(arrRecs[1].lines[intJ]));
				if (/^\s*ld\s+sp\s*,/i.test(strCode))
				{
					blnOk = false;		// moves SP: a branch, stays a procedure
				}
				strCode.replace(/\{([^{}]+)\}/g, function(strAll_a, strInner_a)
				{
					if (objNames[trim(strInner_a).toLowerCase().split('.')[0]] === true)
					{
						blnOk = false;		// reads parameters by name: stays a procedure
					}
					return strAll_a;
				});
			}
			if (blnOk)
			{
				objProc.asmkw = true;
			}
		}
	}

	// storage of a dynamic array: the most any ReDim of it asks for
	function dynLabel(objEl_a)
	{
		var strLabel = descLabel(objEl_a) + '_data';

		declare(strLabel, 'dyn', objDynMax[objEl_a.full] || 1);

		return strLabel;
	}

	// ReDim [Preserve] a(lo To hi): constant bounds (there is no heap), 1 dimension.
	// The storage is as big as the biggest ReDim of the array; the descriptor gets
	// the bounds. Without Preserve the elements are cleared.
	function compileRedim(objRec_a)
	{
		var arrTo = null;
		var intI = 0;
		var intLo = 0;
		var intCount = 0;
		var objElement = null;
		var objHi = null;
		var objLo = null;
		var objVar = null;

		for (intI = 0; intI < objRec_a.vars.length; intI++)
		{
			objVar = objRec_a.vars[intI];
			objElement = resolve(objVar.name, false, true);
			if ((objElement === null) || (objElement.etype !== 'array'))
			{
				error('ReDim: ' + objVar.name + ' is not a dynamic array (Dim ' + objVar.name + '() first)');
				continue;
			}
			if (isParamArray(objElement))
			{
				error('ReDim: ' + objVar.name + ' is an array parameter');
				continue;
			}
			if (!isDynArray(objElement))
			{
				error('ReDim: ' + objVar.name + ' already has its size (Dim ' + objVar.name + '() for a dynamic array)');
				continue;
			}
			if (objElement.udt)
			{
				// a dynamic array of a Type: every field array gets the same ReDim
				udtLeaves(objElement.datatype, '').forEach(function(objLeaf_a)
				{
					compileRedim({ preserve: objRec_a.preserve, vars: [{ name: objVar.name + objLeaf_a.path, dims: objVar.dims }] });
				});
				continue;
			}
			if (objVar.dims.length !== 1)
			{
				error('ReDim: 1 dimension only');
				continue;
			}
			arrTo = objVar.dims[0].toLowerCase().split(/\s+to\s+/);
			objLo = (arrTo.length > 1) ? evalConst(arrTo[0]) : lit(objBase[objElement.module] || 0);
			objHi = evalConst(arrTo[arrTo.length - 1]);
			if ((objLo === null) || (objHi === null) || (objLo.k !== 'l') || (objHi.k !== 'l'))
			{
				error('ReDim: the bounds must be constants (there is no heap): ' + objVar.name);
				continue;
			}
			intLo = objLo.v;
			intCount = objHi.v - objLo.v + 1;
			if (intCount < 0)
			{
				error('ReDim: upper bound below lower bound: ' + objVar.name);
				continue;
			}
			if ((objDynMax[objElement.full] || 0) < intCount * elementSize(objElement))
			{
				objDynMax[objElement.full] = intCount * elementSize(objElement);
			}
			emit('kw_redim', [descLabel(objElement), dynLabel(objElement), intLo, elementSize(objElement), intCount, objRec_a.preserve ? 0 : 1]);
		}
	}

	// a() = Split(text [, sep]) - there is no heap: the array holds at most the
	// biggest of its ReDims and SPLIT_MOST elements; more parts are dropped
	function compileSplit(objElement_a, arrArgs_a)
	{
		var intMost = 16;
		var objSep = null;
		var objText = null;

		if ((arrArgs_a.length < 1) || (arrArgs_a.length > 2))
		{
			error('Split needs the text and maybe a separator');
			return;
		}
		if ((objDynMax[objElement_a.full] || 0) < intMost * 41)
		{
			objDynMax[objElement_a.full] = intMost * 41;
		}
		intMost = Math.floor(objDynMax[objElement_a.full] / 41);
		objText = strOf(compileExpr(arrArgs_a[0].text, null, 0), 0);
		objSep = (arrArgs_a.length > 1) ? strOf(compileExpr(arrArgs_a[1].text, null, 1), 1) : sv(stringLabel(' '));
		emit('kw_strsplit', [descLabel(objElement_a), dynLabel(objElement_a), intMost, objText.n, objSep.n]);
	}

	// Erase a: a dynamic array has no elements after it, a fixed one is cleared
	function compileErase(objRec_a)
	{
		var arrDims = null;
		var intBytes = 0;
		var intI = 0;
		var intJ = 0;
		var objElement = null;
		var strKey = '';

		for (intI = 0; intI < objRec_a.names.length; intI++)
		{
			objElement = resolve(objRec_a.names[intI], false, true);
			if ((objElement === null) || (objElement.etype !== 'array') || isParamArray(objElement))
			{
				error('Erase needs an array: ' + objRec_a.names[intI]);
				continue;
			}
			if (objElement.udt)
			{
				// an array of a Type: clear each field array
				for (strKey in objEl)
				{
					if (objEl.hasOwnProperty(strKey) && (strKey.indexOf(objElement.full + '.') === 0) && (objEl[strKey].etype === 'array') && !objEl[strKey].udt)
					{
						compileErase({ names: [objRec_a.names[intI] + strKey.substr(objElement.full.length)] });
					}
				}
				continue;
			}
			if (isDynArray(objElement))
			{
				emit('kw_redim', [descLabel(objElement), dynLabel(objElement), 0, elementSize(objElement), 0, 0]);
				continue;
			}
			arrDims = dimsOf(objElement);
			intBytes = elementSize(objElement);
			for (intJ = 0; intJ < arrDims.length; intJ++)
			{
				intBytes *= arrDims[intJ].n;
			}
			emit('kw_erase', [arrayLabel(objElement), intBytes]);
		}
	}

	function compileRecord(objRec_a)
	{
		var objCtl = null;
		var objValue = null;
		var intId = 0;
		var intSave = 0;
		var strLabel = '';

		if (objRec_a.k === 'label')
		{
			declareLabel(baseLabel(objRec_a.name));
			return;
		}
		blnLastTransfer = false;

		switch (objRec_a.k)
		{
			case 'print':
				compilePrint(objRec_a.args);
				break;

			case 'input':
				compileInput(objRec_a.args);
				break;

			case 'assign':
				compileAssignRecord(objRec_a);
				break;

			case 'call':
				compileCallRecord(objRec_a);
				break;

			case 'callm':
				objValue = compileValue(objRec_a.expr, 0);
				if (objValue.k === 'l')
				{
					arrOut.push({ t: 'bp', name: argText(objValue) });
				}
				else
				{
					emit('kw_callv', [objValue]);
				}
				break;

			case 'if':
				ifBegin(objRec_a.cond, !!objRec_a.single);
				break;

			case 'elseif':
				ifElseIf(objRec_a.cond);
				break;

			case 'else':
				ifElse(!!objRec_a.single);
				break;

			case 'endif':
				ifEnd(!!objRec_a.single);
				break;

			case 'ifgoto':
				compileCond(objRec_a.cond, targetLabel(objRec_a.target) + strCopy, true);
				break;

			case 'select':
				selectBegin(objRec_a.expr);
				break;

			case 'case':
				selectCase(objRec_a.items);
				break;

			case 'caseelse':
				selectCase(null);
				break;

			case 'endselect':
				selectEnd();
				break;

			case 'while':
				intId = newId();
				objCtl = { type: 'WHILE', line: intLine, cond: objRec_a.cond, top: 'wh' + intId + '_t', test: 'wh' + intId + '_c', end: 'wh' + intId + '_e', mode: strMode };
				emit('kw_goto', [objCtl.test]);
				emitLabel(objCtl.top);
				arrCtl.push(objCtl);
				break;

			case 'wend':
				objCtl = ctlClose('WHILE', 'WEND');
				if (objCtl !== null)
				{
					modeCheck(objCtl, 'While');
					emitLabel(objCtl.test);
					intSave = intLine;
					intLine = objCtl.line;
					compileCond(objCtl.cond, objCtl.top, true);
					intLine = intSave;
					emitLabel(objCtl.end);
				}
				break;

			case 'do':
				intId = newId();
				objCtl = { type: 'DO', line: intLine, top: 'do' + intId + '_t', end: 'do' + intId + '_e', mode: strMode };
				emitLabel(objCtl.top);
				if (objRec_a.cond.length > 0)
				{
					compileCond(objRec_a.cond, objCtl.end, objRec_a.until);
				}
				arrCtl.push(objCtl);
				break;

			case 'loop':
				objCtl = ctlClose('DO', 'LOOP');
				if (objCtl !== null)
				{
					modeCheck(objCtl, 'Do');
					if (objRec_a.cond.length > 0)
					{
						compileCond(objRec_a.cond, objCtl.top, !objRec_a.until);
					}
					else
					{
						emit('kw_goto', [objCtl.top]);
					}
					emitLabel(objCtl.end);
				}
				break;

			case 'for':
				compileFor(objRec_a.v, objRec_a.start, objRec_a.limit, objRec_a.step);
				break;

			case 'next':
				compileNext(objRec_a.vars);
				break;

			case 'foreach':
				compileForEach(objRec_a.v, objRec_a.arr);
				break;

			case 'exit':
				if ((objRec_a.what === 'sub') || (objRec_a.what === 'function') || (objRec_a.what === 'property'))
				{
					if (strProc.length === 0)
					{
						error('Exit ' + objRec_a.what + ' outside a procedure');
						break;
					}
					if (strMode !== strProcEntry)
					{
						error('a procedure must end in the turbo mode it started in');
					}
					emitRaw(procLabel(objEl[strProc], kwMode()) + '_r', [], true);
					blnLastTransfer = true;
					break;
				}
				objCtl = ctlFind(objRec_a.what.toUpperCase());
				if (objCtl === null)
				{
					error('EXIT ' + objRec_a.what.toUpperCase() + ' outside ' + objRec_a.what.toUpperCase());
				}
				else
				{
					emit('kw_goto', [objCtl.end]);
				}
				break;

			case 'goto':
				emit('kw_goto', [targetLabel(objRec_a.target) + strCopy]);
				blnLastTransfer = true;
				break;

			case 'ongoto':
				compileOnGoto(objRec_a);
				break;

			case 'gosub':
				compileGosub(targetLabel(objRec_a.target, 'gosub'));
				break;

			case 'return':
				compileReturn();
				blnLastTransfer = true;
				break;

			case 'end':
				emit('kw_stop', []);
				blnLastTransfer = true;
				break;

			case 'turbo':
				if (objRec_a.on && (strMode !== 't'))
				{
					if (strMode === 'n')
					{
						emitRaw('kw_turbo_on', [], false);
					}
					else
					{
						arrOut.push({ t: 'turbo', on: true });	// pass 1: entry mode unknown
					}
					strMode = 't';
				}
				else if (!objRec_a.on && (strMode !== 'n'))
				{
					if (strMode === 't')
					{
						emitRaw('kw_turbo_off', [], false);
					}
					strMode = 'n';
				}
				break;

			case 'cls':
				emit('kw_cls', []);
				break;

			case 'frame':
				emit('kw_frame', []);
				break;

			case 'locate':
				compileLocate(objRec_a.args);
				break;

			case 'mode':
				objValue = compileValue(objRec_a.expr, 0);
				emit((objValue.k === 'l') ? 'kw_model' : 'kw_modev', [objValue]);
				break;

			case 'poke':
				compilePoke(objRec_a.args, objRec_a.word);
				break;

			case 'randomize':
				objValue = (objRec_a.expr.length > 0) ? compileValue(objRec_a.expr, 0) : null;
				if (objValue === null)
				{
					emit('kw_ticks', [tmp(0)]);
					objValue = vr(tmp(0));
				}
				emit((objValue.k === 'l') ? 'kw_seedl' : 'kw_seedv', [objValue]);
				break;

			case 'break':
				strLabel = 'bp_' + ((objRec_a.name.length > 0) ? objRec_a.name : ('line' + intLine)) + ((kwMode() === 'n') ? '_n' : '');
				if (objBreakpoints[strLabel] === undefined)
				{
					objBreakpoints[strLabel] = kwMode();
					arrBreakpoints.push(strLabel);
				}
				arrOut.push({ t: 'bp', name: strLabel });
				break;

			case 'asm':
				compileAsm(objRec_a);
				break;

			case 'redim':
				compileRedim(objRec_a);
				break;

			case 'erase':
				compileErase(objRec_a);
				break;

			case 'dim':
				checkDim(objRec_a);
				break;

			case 'const':
			case 'option':
			case 'type':
			case 'typeend':
				break;

			default:
				error('statement not supported here: ' + objRec_a.k);
				break;
		}
	}

	// declared types that are not there yet, dynamic arrays
	function checkDim(objRec_a)
	{
		var intI = 0;
		var objVar = null;
		var objElement = null;

		for (intI = 0; intI < objRec_a.vars.length; intI++)
		{
			objVar = objRec_a.vars[intI];
			if (['single', 'double', 'cur', 'object'].indexOf(objVar.type) > -1)
			{
				error(objVar.name + ': type ' + objVar.type + ' is not supported yet (Integer, Long, Byte, Boolean, String)');
			}
			else if ((objVar.type !== '') && (['int', 'long', 'byte', 'bool', 'str', 'variant'].indexOf(objVar.type) < 0) && !isUdt(objVar.type) && !isClass(objVar.type) && (objEl['#enum.' + objVar.type] === undefined))
			{
				error(objVar.name + ': unknown type ' + objVar.type);
			}
			if ((objVar.dims !== null) && (objVar.dims.length === 0) && (objEl[objVar.full] !== undefined))
			{
				if (!objEl[objVar.full].udt)
				{
					descLabel(objEl[objVar.full]);		// dynamic array: its descriptor (ReDim fills it)
				}
			}
			objElement = objEl[objVar.full];
			if ((objElement !== undefined) && (objElement.etype === 'array') && (objVar.dims !== null) && (objVar.dims.length > 0))
			{
				arrayLabel(objElement);
			}
		}
	}

	function setContext(objRec_a)
	{
		intLine = objRec_a.line;
		strFile = objRec_a.file;
		strModule = objRec_a.module;
		blnInClass = !!objRec_a.inclass;
	}

	function compileRecords(arrRecs_a)
	{
		var intI = 0;
		var objRec = null;

		for (intI = 0; intI < arrRecs_a.length; intI++)
		{
			objRec = arrRecs_a[intI];
			setContext(objRec);
			if (objOptions.sourcecomments && (intPass === 2) && (objRec.src !== undefined) && (objRec.src.length > 0) && ((objRec.line !== intLastComment) || (objRec.file !== strLastCommentFile)))
			{
				intLastComment = objRec.line;
				strLastCommentFile = objRec.file;
				emitComment(((arrFiles.length > 1) ? (objRec.file + ' ') : '') + objRec.line + ': ' + objRec.src);
			}
			compileRecord(objRec);
		}
	}

	function closeBlocks()
	{
		while (arrCtl.length > 0)
		{
			intLine = arrCtl[arrCtl.length - 1].line;
			error(arrCtl[arrCtl.length - 1].type + ' is not closed');
			arrCtl.pop();
		}
	}

	// one procedure in one mode
	function compileProc(strFull_a, strMode_a)
	{
		var arrRecs = objProcRecs[strFull_a] || [];
		var objProc = objEl[strFull_a];
		var objModes = objProcModes[strFull_a] || {};

		if ((objProc === undefined) || (arrRecs.length === 0))
		{
			return;
		}
		strProc = strFull_a;
		strMode = strMode_a;
		strProcEntry = strMode_a;
		if (objProc.asmkw)
		{
			// a keyword: the same code serves both modes
			strCopy = '';
			setContext(arrRecs[1]);
			if (intPass === 2)
			{
				asmBlock(arrRecs[1], asmKwLabel(objProc), false, objProc.kind + ' ' + objProc.id + ' (asm keyword)');
			}
			strProc = '';
			return;
		}
		strCopy = ((intPass === 2) && (strMode_a === 'n') && objModes.t && objModes.n) ? '_n' : '';
		setContext(arrRecs[0]);
		arrCtl = [];
		if (intPass === 2)
		{
			emitComment('');
			emitComment(objProc.kind + ' ' + objProc.id + ((strMode_a === 'n') ? ' (normal mode)' : ' (turbo mode)'));
			procStubs(objProc, strMode_a);
		}
		emitLabel(procLabel(objProc, (strMode_a === 'E') ? 't' : strMode_a));
		blnLastTransfer = false;
		compileRecords(arrRecs.slice(1, arrRecs.length - 1));
		setContext(arrRecs[arrRecs.length - 1]);
		closeBlocks();
		if (strMode !== strMode_a)
		{
			error(objProc.id + ' must end in the turbo mode it started in');
		}
		emitRaw(procLabel(objProc, kwMode()) + '_r', [], true);
		strProc = '';
		strCopy = '';
	}

	// a procedure nobody calls: compiled for its errors, the code is dropped
	function compileUnused(strFull_a)
	{
		var intOut = arrOut.length;
		var intStubs = arrProcStubs.length;
		var intDecl = arrDecl.length;
		var intFast = arrFastUse.length;
		var intBreak = arrBreakpoints.length;
		var intAsm = arrAsmBlocks.length;
		var blnSaveGosub = blnGosub;
		var intI = 0;
		var objSaveDone = {};
		var strKey = '';

		for (strKey in objProcStubDone)
		{
			if (objProcStubDone.hasOwnProperty(strKey))
			{
				objSaveDone[strKey] = true;
			}
		}
		objProcModes[strFull_a] = { t: true };
		compileProc(strFull_a, 't');
		delete objProcModes[strFull_a];
		arrOut.length = intOut;
		arrProcStubs.length = intStubs;
		for (intI = intDecl; intI < arrDecl.length; intI++)
		{
			delete objDecl[arrDecl[intI].label];
		}
		arrDecl.length = intDecl;
		objProcStubDone = objSaveDone;
		for (intI = intFast; intI < arrFastUse.length; intI++)
		{
			delete objFastUse[arrFastUse[intI]];
		}
		arrFastUse.length = intFast;
		for (intI = intBreak; intI < arrBreakpoints.length; intI++)
		{
			delete objBreakpoints[arrBreakpoints[intI]];
		}
		arrBreakpoints.length = intBreak;
		for (intI = intAsm; intI < arrAsmBlocks.length; intI++)
		{
			delete objAsmDone[arrAsmBlocks[intI].name];
		}
		arrAsmBlocks.length = intAsm;
		blnGosub = blnSaveGosub;
	}

	function resetPass(intPass_a)
	{
		intPass = intPass_a;
		arrOut = [];
		arrDecl = [];
		objDecl = {};
		arrStrings = [];
		objStrings = {};
		objLits = {};
		arrLits = [];
		arrCtl = [];
		arrBreakpoints = [];
		objBreakpoints = {};
		arrLabelRefs = [];
		intLabelId = 0;
		intMaxTemp = -1;
		intMaxSTemp = -1;
		intMaxLTemp = -1;
		blnGosub = false;
		objGlyphs = {};
		blnLastTransfer = false;
		objGotoStubs = {};
		arrGotoStubs = [];
		objLabelMode = {};
		arrGotoRefs = [];
		arrProcStubs = [];
		objProcStubDone = {};
		arrAsmBlocks = [];
		objAsmDone = {};
		objFastUse = {};
		arrFastUse = [];
		objConstCache = {};
	}

	function compilePass(intPass_a)
	{
		var intI = 0;
		var strMode_ = '';

		resetPass(intPass_a);

		// module level declarations
		if (intPass === 2)
		{
			strProc = '';
			for (intI = 0; intI < arrRecords.length; intI++)
			{
				if ((arrRecords[intI].k === 'dim') && (arrRecords[intI].proc === ''))
				{
					setContext(arrRecords[intI]);
					checkDim(arrRecords[intI]);
				}
			}
		}

		// main program
		strProc = '';
		strCopy = '';
		strMode = strStartMode;
		compileRecords(arrMainRecs);
		closeBlocks();
		emit('kw_stop', []);

		// procedures
		for (intI = 0; intI < arrProcOrder.length; intI++)
		{
			if (intPass === 1)
			{
				compileProc(arrProcOrder[intI], 'E');
			}
			else if (objProcModes[arrProcOrder[intI]] === undefined)
			{
				compileUnused(arrProcOrder[intI]);
			}
			else
			{
				for (strMode_ in objProcModes[arrProcOrder[intI]])
				{
					if (objProcModes[arrProcOrder[intI]].hasOwnProperty(strMode_))
					{
						compileProc(arrProcOrder[intI], strMode_);
					}
				}
			}
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
				while ((objTargets[strTarget] !== undefined) && (objTargets[strTarget] !== strTarget) && (intGuard < 50) && (objLabelMode[objTargets[strTarget]] === objLabelMode[strTarget]))
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
	// library linking (two modes)
	// Normal mode lets interrupts in at safe points: every branch
	// (a section that loads SP, or jumps into one) gets a normal mode
	// copy with ret -> jp ntc_xn, ntc_next -> ntc_xn and its labels
	// renamed _n. Everything else is the same code in both modes.
	// ------------------------------------------------------------

	function parseSections(strText_a, objInto_a, arrOrder_a)
	{
		var arrLines = strText_a.replace(/\r/g, '').split('\n');
		var arrMatch = null;
		var arrParts = [];
		var intI = 0;
		var intJ = 0;
		var objCurrent = null;

		for (intI = 0; intI < arrLines.length; intI++)
		{
			if ((arrMatch = arrLines[intI].match(/^;##\s+(\S+)(.*)$/)))
			{
				arrParts = trim(arrMatch[2]).length > 0 ? trim(arrMatch[2]).split(/\s+/) : [];
				objCurrent = { name: arrMatch[1], deps: [], shared: false, lines: [], labels: [], header: arrLines[intI] };
				for (intJ = 0; intJ < arrParts.length; intJ++)
				{
					if (arrParts[intJ] === '@shared')
					{
						objCurrent.shared = true;
					}
					else
					{
						objCurrent.deps.push(arrParts[intJ]);
					}
				}
				if (objInto_a[objCurrent.name] === undefined)
				{
					arrOrder_a.push(objCurrent.name);
				}
				objInto_a[objCurrent.name] = objCurrent;
			}
			else if (objCurrent !== null)
			{
				objCurrent.lines.push(arrLines[intI]);
				if ((arrMatch = arrLines[intI].match(/^([A-Za-z_]\w*):/)) || (arrMatch = arrLines[intI].match(/^([A-Za-z_]\w*)\s+equ\b/i)))
				{
					objCurrent.labels.push(arrMatch[1]);
				}
			}
		}
	}

	// code part of an asm line (before the ; comment, outside quotes)
	function codePart(strLine_a)
	{
		var blnInString = false;
		var intI = 0;
		var strChar = '';

		for (intI = 0; intI < strLine_a.length; intI++)
		{
			strChar = strLine_a.substr(intI, 1);
			if ((strChar === '"') || (strChar === "'"))
			{
				if (!blnInString)
				{
					blnInString = strChar;
				}
				else if (blnInString === strChar)
				{
					blnInString = false;
				}
			}
			else if ((strChar === ';') && !blnInString)
			{
				return intI;
			}
		}

		return strLine_a.length;
	}

	function markModeSections(objSections_a, arrOrder_a)
	{
		var blnChanged = true;
		var intI = 0;
		var intJ = 0;
		var objLabel = {};
		var objSection = null;
		var strCode = '';
		var arrWords = null;
		var intK = 0;

		for (intI = 0; intI < arrOrder_a.length; intI++)
		{
			objSection = objSections_a[arrOrder_a[intI]];
			objSection.mode = false;
			if (objSection.shared)
			{
				continue;
			}
			// a section that moves SP (a branch) is a safe point in normal mode
			for (intJ = 0; intJ < objSection.lines.length; intJ++)
			{
				strCode = objSection.lines[intJ].substr(0, codePart(objSection.lines[intJ]));
				if (/^\s+ld\s+sp\s*,/i.test(strCode))
				{
					objSection.mode = true;
					break;
				}
			}
		}

		while (blnChanged)
		{
			blnChanged = false;
			objLabel = {};
			for (intI = 0; intI < arrOrder_a.length; intI++)
			{
				objSection = objSections_a[arrOrder_a[intI]];
				if (objSection.mode)
				{
					for (intJ = 0; intJ < objSection.labels.length; intJ++)
					{
						objLabel[objSection.labels[intJ]] = true;
					}
				}
			}
			for (intI = 0; intI < arrOrder_a.length; intI++)
			{
				objSection = objSections_a[arrOrder_a[intI]];
				if (objSection.mode || objSection.shared)
				{
					continue;
				}
				for (intJ = 0; intJ < objSection.lines.length && !objSection.mode; intJ++)
				{
					strCode = objSection.lines[intJ].substr(0, codePart(objSection.lines[intJ]));
					if (/^\s+(jp|jr|ld)\b/i.test(strCode))
					{
						arrWords = strCode.match(/[A-Za-z_]\w*/g) || [];
						for (intK = 1; intK < arrWords.length; intK++)
						{
							if (objLabel[arrWords[intK]] === true)
							{
								objSection.mode = true;
								blnChanged = true;
								break;
							}
						}
					}
				}
			}
		}

		objLabel = {};
		for (intI = 0; intI < arrOrder_a.length; intI++)
		{
			objSection = objSections_a[arrOrder_a[intI]];
			if (objSection.mode)
			{
				for (intJ = 0; intJ < objSection.labels.length; intJ++)
				{
					objLabel[objSection.labels[intJ]] = true;
				}
			}
		}

		return objLabel;
	}

	// normal mode copy of a section
	function normalCopy(objSection_a, objModeLabels_a)
	{
		var arrResult = [];
		var arrMatch = null;
		var intCut = 0;
		var intI = 0;
		var strCode = '';
		var strComment = '';
		var strLine = '';

		for (intI = 0; intI < objSection_a.lines.length; intI++)
		{
			strLine = objSection_a.lines[intI];
			intCut = codePart(strLine);
			strCode = strLine.substr(0, intCut);
			strComment = strLine.substr(intCut);
			if ((arrMatch = strCode.match(/^(\s+)ret\s*$/i)))
			{
				strCode = arrMatch[1] + 'jp ntc_xn';
			}
			else if ((arrMatch = strCode.match(/^(\s+)ret\s+(n?z|n?c|po|pe|p|m)\s*$/i)))
			{
				strCode = arrMatch[1] + 'jp ' + arrMatch[2] + ', ntc_xn';
			}
			strCode = strCode.replace(/[A-Za-z_]\w*/g, function(strWord_a)
			{
				if (strWord_a === 'ntc_next')
				{
					return 'ntc_xn';
				}
				if (objModeLabels_a[strWord_a] === true)
				{
					return strWord_a + '_n';
				}
				return strWord_a;
			});
			arrResult.push(strCode + strComment);
		}

		return arrResult;
	}

	var objLibSections = {};
	var arrLibOrder = [];
	var objLibModeLabels = {};
	var blnLibLoaded = false;

	function loadLibrary()
	{
		var strLib = objOptions.libtext;
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
			arrErrors.push({ file: '', line: 0, msg: 'keyword library not loaded (ntc_lib.js)' });
			return '';
		}
		if ((strPlatform === null) || (strPlatform === undefined))
		{
			arrErrors.push({ file: '', line: 0, msg: 'unknown platform: ' + objOptions.platform });
			strPlatform = '';
		}

		parseSections(strLib, objLibSections, arrLibOrder);
		parseSections(strPlatform, objLibSections, arrLibOrder);
		objLibModeLabels = markModeSections(objLibSections, arrLibOrder);
		blnLibLoaded = true;
		return '';
	}

	// a keyword that has a normal mode copy (else one copy for both modes)
	function isModeKw(strKw_a)
	{
		if (strKw_a.substr(0, 3) === 'fn_')
		{
			return false;		// asm keyword procedure: one copy, a straight keyword
		}
		return (objLibSections[strKw_a] === undefined) || objLibSections[strKw_a].mode;
	}

	function linkLibrary(objUsedT_a, objUsedN_a, blnIrq_a)
	{
		var arrOrder = arrLibOrder;
		var arrQueue = [];
		var arrResult = [];
		var intI = 0;
		var objModeLabels = objLibModeLabels;
		var objNeeded = {};		// name -> { t, n, s }
		var objSections = objLibSections;
		var objSection = null;
		var objItem = null;
		var strName = '';
		var strMode_ = '';
		var blnNormal = false;

		if (!blnLibLoaded)
		{
			return '';
		}

		arrQueue = [{ name: 'ntc_data', mode: 't' }, { name: 'kw_stop', mode: 't' }];
		if (objOptions.library === 'all')
		{
			for (intI = 0; intI < arrOrder.length; intI++)
			{
				arrQueue.push({ name: arrOrder[intI], mode: 't' });
			}
		}
		for (strName in objUsedT_a)
		{
			if (objUsedT_a.hasOwnProperty(strName))
			{
				arrQueue.push({ name: strName, mode: 't' });
			}
		}
		for (strName in objUsedN_a)
		{
			if (objUsedN_a.hasOwnProperty(strName))
			{
				arrQueue.push({ name: strName, mode: 'n' });
				blnNormal = true;
			}
		}
		if (blnNormal)
		{
			arrQueue.push({ name: 'ntc_xn', mode: 't' });
		}
		if (blnIrq_a && (objSections['ntc_plat_irq'] !== undefined))
		{
			arrQueue.push({ name: 'ntc_plat_irq', mode: 't' });
		}

		while (arrQueue.length > 0)
		{
			objItem = arrQueue.pop();
			if (blnHookUsed && (objItem.name === 'ntc_xn'))
			{
				objItem.name = 'ntc_xnh';	// the window that also runs the Interrupt hook
			}
			objSection = objSections[objItem.name];
			if (objSection === undefined)
			{
				if (objNeeded[objItem.name] === undefined)
				{
					arrErrors.push({ file: '', line: 0, msg: 'not in library: ' + objItem.name });
					objNeeded[objItem.name] = {};
				}
				continue;
			}
			strMode_ = objSection.mode ? objItem.mode : 's';
			if (objNeeded[objItem.name] === undefined)
			{
				objNeeded[objItem.name] = {};
			}
			if (objNeeded[objItem.name][strMode_] === true)
			{
				continue;
			}
			objNeeded[objItem.name][strMode_] = true;
			for (intI = 0; intI < objSection.deps.length; intI++)
			{
				arrQueue.push({ name: objSection.deps[intI], mode: (strMode_ === 's') ? 't' : strMode_ });
			}
		}

		for (intI = 0; intI < arrOrder.length; intI++)
		{
			objItem = objNeeded[arrOrder[intI]];
			objSection = objSections[arrOrder[intI]];
			if (objItem === undefined)
			{
				continue;
			}
			if ((objItem.s === true) || (objItem.t === true))
			{
				arrResult.push(objSection.header);
				arrResult.push(objSection.lines.join('\n').replace(/\s+$/, ''));
				arrResult.push('');
			}
			if (objItem.n === true)
			{
				arrResult.push(objSection.header.replace(/^;##\s+(\S+)/, ';## $1 (normal mode copy)'));
				arrResult.push(normalCopy(objSection, objModeLabels).join('\n').replace(/\s+$/, ''));
				arrResult.push('');
			}
		}

		return arrResult.join('\n');
	}

	// ------------------------------------------------------------
	// main
	// ------------------------------------------------------------

	var arrFiles = (typeof input_a === 'string') ? [{ name: 'main.bas', text: input_a }] : input_a;
	var intI = 0;
	var intJ = 0;
	var objRec = null;
	var strCur = '';

	objParse = ntcParse(arrFiles);
	objEl = objParse.elements;
	arrRecords = objParse.records;
	for (intI = 0; intI < objParse.errors.length; intI++)
	{
		arrErrors.push(objParse.errors[intI]);
	}
	strStartMode = objOptions.turbo ? 't' : 'n';

	// split the records: main program and procedures
	for (intI = 0; intI < arrRecords.length; intI++)
	{
		objRec = arrRecords[intI];
		if ((objRec.k === 'module') && (strFirstModule.length === 0))
		{
			strFirstModule = objRec.name;
		}
		if (objRec.k === 'option')
		{
			if (objRec.what === 'explicit')
			{
				objExplicit[objRec.module] = true;
			}
			else if (objRec.what === 'turbo')
			{
				strStartMode = 't';
			}
			else if (objRec.what === 'normal')
			{
				strStartMode = 'n';
			}
			else if (objRec.what === 'comparetext')
			{
				objCompareText[objRec.module] = true;
			}
			else if (objRec.what === 'vbprint')
			{
				blnVBPrint = true;
			}
			else if (objRec.what === 'base')
			{
				objBase[objRec.module] = objRec.value;
			}
		}
		if (objRec.k === 'proc')
		{
			strCur = objRec.full;
			objProcRecs[strCur] = [objRec];
			arrProcOrder.push(strCur);
			continue;
		}
		if (strCur.length > 0)
		{
			objProcRecs[strCur].push(objRec);
			if (objRec.k === 'procend')
			{
				strCur = '';
			}
			continue;
		}
		if (DECLARATION_KINDS[objRec.k] === undefined)
		{
			arrMainRecs.push(objRec);
		}
	}

	// Sub Main runs after the top level code
	if (find('main') !== null && (find('main').etype === 'proc') && (find('main').kind === 'sub'))
	{
		arrMainRecs.push({ k: 'call', name: 'main', args: [], explicit: false, raw: 'main', file: arrFiles[0].name, line: 0, module: strFirstModule, proc: '', inclass: false });
	}
	findAsmKeywords();

	expandUdts();

	// pass 1 (twice, so types of undeclared variables settle)
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
		arrScanProcCalls = [];
		objScanFallIn = {};
		objWritten = {};
		objProcModes = {};
		compilePass(1);
		objTypes = {};

		// later rules win: INPUT, used in sums, compared with "text", assigned
		for (strKey in objScanInput)
		{
			if (objScanInput.hasOwnProperty(strKey))
			{
				objTypes[strKey] = 'str';
			}
		}
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
		objLabelNames = {};
		objLabelUsed = {};
	}

	// keep the pass 1 errors that only pass 1 can find (labels used twice etc.)
	decideSubs();
	decideProcs();

	// pass 2 - code
	compilePass(2);

	var arrGlyphCodes = [];
	var arrGlyphLine = [];
	var strText = '';
	var intBytes = 0;
	var intKeywords = 0;
	var arrAsm = [];
	var objItem = null;
	var objUsedT = {};
	var objUsedN = {};
	var blnNormalUsed = false;
	var strIndent = '\t\t\t';
	var strName = '';
	var strMode_ = '';
	var strFirstMode = '';
	var intStraight = 0;

	for (intI = 0; intI < arrLabelRefs.length; intI++)
	{
		if (objLabels[arrLabelRefs[intI].label] === undefined)
		{
			arrErrors.push({ file: arrLabelRefs[intI].file, line: arrLabelRefs[intI].line, msg: 'no such label: ' + arrLabelRefs[intI].label.replace(/^(ln|lbl)_/, '') });
		}
	}
	for (intI = 0; intI < arrGotoRefs.length; intI++)
	{
		if ((objLabelMode[arrGotoRefs[intI].label] !== undefined) && (objLabelMode[arrGotoRefs[intI].label] !== arrGotoRefs[intI].mode))
		{
			arrErrors.push({ file: arrGotoRefs[intI].file, line: arrGotoRefs[intI].line, msg: 'GOTO / GOSUB into a different turbo mode' });
		}
	}

	peephole();
	loadLibrary();

	for (intI = 0; intI < arrOut.length; intI++)
	{
		objItem = arrOut[intI];
		if (((objItem.t === 'kw') || (objItem.t === 'stub')) && (objItem.mode === 'n'))
		{
			blnNormalUsed = true;
		}
	}

	// header
	arrAsm.push('; ============================================================');
	arrAsm.push('; NTC program - generated by NTC BASIC (VB style BASIC to NTC)');
	arrAsm.push('; platform: ' + objOptions.platform + ', starts in ' + ((strStartMode === 't') ? 'turbo' : 'normal') + ' mode');
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
	if (strStartMode === 'n')
	{
		arrAsm.push(strIndent + 'ld a, 1');
		arrAsm.push(strIndent + 'ld (ntc_nmode), a\t\t; normal mode: waits let interrupts in');
	}
	if (blnNormalUsed && (objOptions.platform === 'cpc'))
	{
		arrAsm.push(strIndent + 'ld ix, ntc_go');
		arrAsm.push(strIndent + 'jp ntc_plat_irqon\t\t; interrupt handler for normal mode');
		arrAsm.push('ntc_go:');
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
			strName = 'kw_scrinit' + (((strStartMode === 'n') && isModeKw('kw_scrinit')) ? '_n' : '');
			arrAsm.push(strIndent + 'dw ' + strName + '\t\t; mode 1, ROMs off, clear screen');
			if (strStartMode === 'n')
			{
				objUsedN['kw_scrinit'] = true;
			}
			else
			{
				objUsedT['kw_scrinit'] = true;
			}
			intBytes += 2;
			break;
		}
	}

	for (intI = 0; intI < arrOut.length; intI++)
	{
		objItem = arrOut[intI];

		// normal mode: a long run without a branch gets a safe point
		if ((objItem.t === 'kw') || (objItem.t === 'stub'))
		{
			if ((objItem.mode === 'n') && (objItem.t === 'kw') && !isModeKw(objItem.kw) && (objItem.kw !== 'kw_goto'))
			{
				intStraight++;
				if (intStraight >= 32)
				{
					arrAsm.push(strIndent + 'dw kw_irq\t\t; let interrupts in');
					objUsedT['kw_irq'] = true;
					intBytes += 2;
					intStraight = 0;
				}
			}
			else
			{
				intStraight = 0;
			}
		}
		else if (objItem.t === 'label')
		{
			intStraight = 0;
		}

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
			strName = objItem.kw + (((objItem.mode === 'n') && isModeKw(objItem.kw)) ? '_n' : '');
			arrAsm.push(strIndent + 'dw ' + [strName].concat(objItem.args).join(', '));
			if (objItem.kw.substr(0, 3) === 'fn_')
			{
				// asm keyword procedure: its code is with the #asm blocks
			}
			else if (objItem.mode === 'n')
			{
				objUsedN[objItem.kw] = true;
			}
			else
			{
				objUsedT[objItem.kw] = true;
			}
			intBytes += (1 + objItem.args.length) * 2;
			intKeywords++;
		}
		else if (objItem.t === 'stub')
		{
			arrAsm.push(strIndent + 'dw ' + [objItem.name].concat(objItem.args).join(', '));
			if ((objItem.name === 'kw_turbo_on') || (objItem.name === 'kw_turbo_off'))
			{
				objUsedT[objItem.name] = true;
			}
			intBytes += (1 + objItem.args.length) * 2;
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
			if (objItem.text.length === 0)
			{
				arrAsm.push('');
				arrAsm.push('; ============================================================');
			}
			else if (/^(sub|function|propget|proplet|propset) /.test(objItem.text))
			{
				arrAsm.push('; ' + objItem.text);
				arrAsm.push('; ============================================================');
				arrAsm.push('');
			}
			else
			{
				arrAsm.push('');
				arrAsm.push(strIndent + '; ' + objItem.text);
			}
		}
	}
	objUsedT['kw_stop'] = true;
	if (blnGosub)
	{
		objUsedT['ntc_gstack'] = true;
	}

	if ((arrGotoStubs.length > 0) || (arrFastUse.length > 0) || (arrProcStubs.length > 0))
	{
		arrAsm.push('');
		arrAsm.push('; ============================================================');
		arrAsm.push('; Jump stubs (code, ROMable)');
		arrAsm.push(';   label_go: GOTO label');
		arrAsm.push(';   label_gs: GOSUB label, return point -> label_rs (RAM)');
		arrAsm.push(';   label_rt: RETURN from label');
		arrAsm.push(';   p_name_c: call a procedure, p_name_r: end of it');
		arrAsm.push(';   turbo mode ends with ret, normal mode with jp ntc_xn');
		arrAsm.push('; ============================================================');
		arrAsm.push('');
		for (intI = 0; intI < arrGotoStubs.length; intI++)
		{
			strMode_ = objLabelMode[arrGotoStubs[intI]] || 't';
			arrAsm.push(arrGotoStubs[intI] + '_go:' + strIndent + 'ld sp, ' + arrGotoStubs[intI]);
			arrAsm.push(strIndent + exitCode(strMode_));
		}
		for (intI = 0; intI < arrFastUse.length; intI++)
		{
			strMode_ = objLabelMode[arrFastUse[intI]] || 't';
			declare(arrFastUse[intI] + '_rs', 'int', 0);
			arrAsm.push(arrFastUse[intI] + '_gs:' + strIndent + 'ld (' + arrFastUse[intI] + '_rs), sp');
			arrAsm.push(strIndent + 'ld sp, ' + arrFastUse[intI]);
			arrAsm.push(strIndent + exitCode(strMode_));
			arrAsm.push(arrFastUse[intI] + '_rt:' + strIndent + 'ld sp, (' + arrFastUse[intI] + '_rs)');
			arrAsm.push(strIndent + exitCode(strMode_));
		}
		if (arrProcStubs.length > 0)
		{
			arrAsm.push('');
			arrAsm.push(arrProcStubs.join('\n'));
		}
	}

	if (arrAsmBlocks.length > 0)
	{
		arrAsm.push('');
		arrAsm.push('; ============================================================');
		arrAsm.push('; Inline assembly (#asm ... #endasm)');
		arrAsm.push('; ============================================================');
		arrAsm.push('');
		for (intI = 0; intI < arrAsmBlocks.length; intI++)
		{
			arrAsm.push(arrAsmBlocks[intI].lines.join('\n'));
			arrAsm.push('');
			// library routines a block uses by name are linked
			for (intJ = 0; intJ < arrAsmBlocks[intI].lines.length; intJ++)
			{
				(arrAsmBlocks[intI].lines[intJ].substr(0, codePart(arrAsmBlocks[intI].lines[intJ])).match(/[A-Za-z_]\w*/g) || []).forEach(function(strWord_a)
				{
					if ((objLibSections[strWord_a] !== undefined) && (strWord_a !== arrAsmBlocks[intI].name))
					{
						objUsedT[strWord_a] = true;
					}
				});
			}
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
			arrAsm.push(arrBreakpoints[intI] + ':' + strIndent + exitCode(objBreakpoints[arrBreakpoints[intI]]));
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
		else if (objItem.kind === 'strfix')
		{
			arrAsm.push(objItem.label + ':' + strIndent + 'db "' + new Array(objItem.size + 1).join(' ') + '", 0\t\t; String * ' + objItem.size);
			arrAsm.push(strIndent + 'ds ' + (40 - objItem.size));
		}
		else if (objItem.kind === 'arr')
		{
			arrAsm.push(objItem.label + ':' + strIndent + 'ds ' + (objItem.size * 2) + '\t\t; ' + objItem.size + ' words');
		}
		else if (objItem.kind === 'sarr')
		{
			arrAsm.push(objItem.label + ':' + strIndent + 'ds ' + (objItem.size * 41) + '\t\t; ' + objItem.size + ' strings');
		}
		else if (objItem.kind === 'desc')
		{
			arrAsm.push(objItem.label + ':' + strIndent + 'ds 12\t\t; array descriptor: base, lower bounds, counts, size');
		}
		else if (objItem.kind === 'adesc')
		{
			arrAsm.push(objItem.label + ':' + strIndent + 'dw ' + objItem.words.join(', ') + '\t\t; array as an argument');
		}
		else if (objItem.kind === 'dyn')
		{
			arrAsm.push(objItem.label + ':' + strIndent + 'ds ' + objItem.size + '\t\t; dynamic array, biggest ReDim');
		}
		else if (objItem.kind === 'barr')
		{
			arrAsm.push(objItem.label + ':' + strIndent + 'ds ' + objItem.size + '\t\t; ' + objItem.size + ' bytes');
		}
		else if (objItem.kind === 'larr')
		{
			arrAsm.push(objItem.label + ':' + strIndent + 'ds ' + (objItem.size * 4) + '\t\t; ' + objItem.size + ' Longs');
		}
		else if (objItem.kind === 'long')
		{
			arrAsm.push(objItem.label + ':' + strIndent + 'dw 0, 0');
		}
		else
		{
			arrAsm.push(objItem.label + ':' + strIndent + 'dw 0');
		}
	}
	for (intI = 0; intI <= intMaxTemp; intI++)
	{
		arrAsm.push('tmp' + intI + ':' + strIndent + 'dw 0');
	}
	for (intI = 0; intI <= intMaxSTemp; intI++)
	{
		arrAsm.push('stmp' + intI + ':' + strIndent + 'ds 41');
	}
	for (intI = 0; intI <= intMaxLTemp; intI++)
	{
		arrAsm.push('ltmp' + intI + ':' + strIndent + 'dw 0, 0');
	}

	if (arrLits.length > 0)
	{
		arrAsm.push('');
		arrAsm.push('; numbers passed by address (read only)');
		for (intI = 0; intI < arrLits.length; intI++)
		{
			arrAsm.push(arrLits[intI] + ':' + strIndent + 'dw ' + objLits[arrLits[intI]]);
		}
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
		arrAsm.push(linkLibrary(objUsedT, objUsedN, blnNormalUsed));
	}

	arrErrors.sort(function(objA_a, objB_a)
	{
		if (objA_a.file !== objB_a.file)
		{
			return (objA_a.file < objB_a.file) ? -1 : 1;
		}
		return objA_a.line - objB_a.line;
	});

	// cross reference: every label the compiler made, what it is, where it comes from.
	// Made fresh on every compile - #asm should use {name} so it never goes stale.
	var arrXref = [];
	var objXrefSeen = {};
	var objGenerated = {};
	function xrefAdd(strLabel_a, strKind_a, strName_a, strFile_a, intLine_a)
	{
		if ((strLabel_a === undefined) || (objXrefSeen[strLabel_a] !== undefined))
		{
			return;
		}
		objXrefSeen[strLabel_a] = true;
		objGenerated[strLabel_a] = true;
		arrXref.push({ label: strLabel_a, kind: strKind_a, name: strName_a, file: strFile_a || '', line: intLine_a || 0 });
	}
	for (strKey in objLabelNames)
	{
		if (objLabelNames.hasOwnProperty(strKey) && (objDecl[objLabelNames[strKey]] !== undefined))
		{
			objItem = objEl[strKey] || {};
			xrefAdd(objLabelNames[strKey], objDecl[objLabelNames[strKey]].kind, objItem.id || strKey, objItem.file, objItem.line);
		}
	}
	for (strKey in objDecl)
	{
		if (objDecl.hasOwnProperty(strKey) && !/^(tmp|stmp|ltmp)\d+$/.test(strKey))
		{
			xrefAdd(strKey, objDecl[strKey].kind, /_rs$/.test(strKey) ? 'return point' : (/_a\d+(_\d+)?$/.test(strKey) ? 'ByRef address' : (/^ad_/.test(strKey) ? 'array as an argument' : (/_data$/.test(strKey) ? 'dynamic array data' : ''))), '', 0);
		}
	}
	for (strKey in objEl)
	{
		if (objEl.hasOwnProperty(strKey) && (objEl[strKey].etype === 'proc'))
		{
			objItem = objEl[strKey];
			strName = procBase(objItem);
			if (objItem.asmkw)
			{
				continue;		// listed with the #asm blocks (fn_name)
			}
			if (objProcModes[objItem.full] !== undefined)
			{
				if (objProcModes[objItem.full].t || !objProcModes[objItem.full].n || (procLabel(objItem, 'n') === strName))
				{
					xrefAdd(strName, 'proc', objItem.id, objItem.file, objItem.line);
					xrefAdd(strName + '_c', 'call stub', objItem.id, objItem.file, objItem.line);
					xrefAdd(strName + '_r', 'return stub', objItem.id, objItem.file, objItem.line);
				}
				if (objProcModes[objItem.full].n && (procLabel(objItem, 'n') !== strName))
				{
					xrefAdd(strName + '_n', 'proc (normal)', objItem.id, objItem.file, objItem.line);
					xrefAdd(strName + '_n_c', 'call stub (normal)', objItem.id, objItem.file, objItem.line);
					xrefAdd(strName + '_n_r', 'return stub (normal)', objItem.id, objItem.file, objItem.line);
				}
			}
		}
	}
	for (strKey in objLabels)
	{
		if (objLabels.hasOwnProperty(strKey))
		{
			xrefAdd(strKey, 'label', strKey.replace(/^(ln|lbl)_/, ''), '', objLabels[strKey]);
		}
	}
	for (intI = 0; intI < arrAsmBlocks.length; intI++)
	{
		xrefAdd(arrAsmBlocks[intI].name, '#asm', '', arrAsmBlocks[intI].file, arrAsmBlocks[intI].line);
	}
	arrXref.sort(function(objA_a, objB_a)
	{
		return (objA_a.label < objB_a.label) ? -1 : ((objA_a.label > objB_a.label) ? 1 : 0);
	});
	// a generated label written by hand in #asm goes stale when the BASIC changes
	for (intI = 0; intI < arrAsmBlocks.length; intI++)
	{
		for (intJ = 0; intJ < arrAsmBlocks[intI].orig.length; intJ++)
		{
			(arrAsmBlocks[intI].orig[intJ].substr(0, codePart(arrAsmBlocks[intI].orig[intJ])).replace(/\{[^{}]*\}/g, '').match(/[A-Za-z_]\w*/g) || []).forEach(function(strWord_a)
			{
				var objFound = null;
				var intK = 0;

				if (objGenerated[strWord_a] === true)
				{
					for (intK = 0; intK < arrXref.length; intK++)
					{
						if (arrXref[intK].label === strWord_a)
						{
							objFound = arrXref[intK];
						}
					}
					strFile = arrAsmBlocks[intI].file;
					intLine = arrAsmBlocks[intI].line + 1 + intJ;
					warning('#asm uses the generated label ' + strWord_a + ((objFound && objFound.name) ? (' - write {' + objFound.name.replace(/^.*\./, '') + '} so it follows the BASIC') : ' - it can change when the BASIC changes'));
				}
			});
		}
	}
	var strMap = ['; NTC cross reference - label, what it is, BASIC name, file line', ';'].concat(arrXref.map(function(objX_a)
	{
		return objX_a.label + new Array(Math.max(2, 28 - objX_a.label.length)).join(' ') + objX_a.kind + new Array(Math.max(2, 22 - objX_a.kind.length)).join(' ') + objX_a.name + ((objX_a.file || objX_a.line) ? ('  (' + (objX_a.file ? (objX_a.file + ' ') : '') + (objX_a.line ? objX_a.line : '') + ')') : '');
	})).join('\n');

	var arrProcList = [];
	var arrMatch = null;
	for (intI = 0; intI < objParse.procs.length; intI++)
	{
		arrMatch = String(objParse.procs[intI].src || '').match(/\b(?:sub|function|property\s+(?:get|let|set))\s+([A-Za-z_]\w*)/i);
		arrProcList.push({ file: objParse.procs[intI].file, line: objParse.procs[intI].line, name: arrMatch ? arrMatch[1] : objParse.procs[intI].id, kind: objParse.procs[intI].kind, scope: objParse.procs[intI].scope, used: (objProcModes[objParse.procs[intI].full] !== undefined) });
	}

	return {
		asm: arrAsm.join('\n'),
		errors: arrErrors,
		warnings: arrWarnings,
		xref: arrXref,
		map: strMap,
		procs: arrProcList,
		stats: {
			threadbytes: intBytes,
			keywords: intKeywords,
			variables: arrDecl.length,
			temps: intMaxTemp + 1,
			stemps: intMaxSTemp + 1,
			normal: blnNormalUsed,
			start: strStartMode
		}
	};
}
