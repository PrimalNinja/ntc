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
	var objPlat = {};			// the platform file's ;@ settings (readPlatform)
	var objOwnClass = {};
	var objDefinesIn = {};		// predefined #Const values: NTC and NTC_<platform>
	var objMemory = { scheme: 'small', max: 257 };	// Option Memory
	var blnMemoryUsed = false;	// the project has a Memory class
	var objClassKind = {};		// Option Class: module -> { kind: 'overlay', file } / { kind: 'interrupt', rate, slot }
	var arrOvlOrder = [];		// overlay classes, in source order
	var objOvlAsm = {};			// overlay class -> its thread lines (built at #4000)
	var arrIslots = [];
	var objPagedLabel = {};		// label -> overlay class: a Private Paged variable (in the class's page)
	var strLibAsm = '';			// the linked library's text (genrom.js builds ROMs from it)
	var objPages = {};			// Option Page / Option Class Overlay: page id -> { name, file, id, blk, classes [modules], srcfile, line }
	var arrPageOrder = [];		// page ids, in source order
	var objClassPages = {};		// overlay class (module) -> the page ids it is in (the home page first)
	var objLocalCalled = {};	// procedure -> true: called from code in one of its own pages (its stub checks ntc_ovl_lc)
	var objStubClass = {};		// call stub body label (p_x / p_x_n) -> { module, proc } (overlay procedures)
	var objPageAsmUsed = {};	// keywords the page composition needs
	var objOvlVars = {};		// overlay class -> its paged variables (declarations)			// interrupt classes: { module, rate (0 = Frame), tick }
	var intStrMax = 40;			// the longest string in the program (findStrMax)
	var arrReserve = [];		// Option Reserve: { start, size, file, line }
	var arrRomEnable = null;	// Option RomEnable (cpcfw): null none, ['all'], or ROM numbers
	var objStack = null;		// Option Stack: { addr, file, line } - the real stack's start
	var strTerminal = 'none';	// Option Terminal (CP/M): none, vt52, ansi		// platform class names the project replaces with its own
	var objOptions = {
		org: null,				// null = the platform's (;@org)
		library: 'used',		// used, all, none
		platform: 'cpc',		// key into NTC_PLATFORMS: cpc, cpcmin, cpcfw, cpm, test
		sourcecomments: true,
		turbo: false,			// start in turbo mode (same as Option Turbo)
		libtext: null,
		platformtext: null,
		amsdos: ''				// a name: also write an AMSDOS file NAME.BIN (sjasmplus SAVEAMSDOS)
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
	var blnNoTurbo = false;		// Option NoTurbo: normal mode only (one copy of each procedure and keyword)
	var objNoTurboLine = null;
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
	var objTmpSize = {};		// pass 1: procedure ('' = main) -> temps it uses (slots, every kind)
	var objTmpBase = {};		// pass 2: procedure -> its first temp slot (above its callers' live temps)
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
		if (objEl_a.paged && (objMemory.scheme === 'cpcexpansion'))
		{
			objPagedLabel[strLabel] = objEl_a.module;		// lives in its overlay class's page
		}

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

	// String * n: n (1 .. 255), else 0
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
		if ((objValue === null) || (objValue.k !== 'l') || (objValue.v < 1) || (objValue.v > 255))
		{
			error('String * n: n must be a constant 1 .. 255 (' + objEl_a.id + ')');
			return 0;
		}

		return objValue.v;
	}

	// String Max n: n (1 .. 255), else 0
	function maxLen(objEl_a)
	{
		var objValue = null;
		var strSaveModule = strModule;
		var strSaveProc = strProc;

		if (!objEl_a || !objEl_a.strmax || (typeOfEl(objEl_a) !== 'str'))
		{
			return 0;
		}
		strModule = objEl_a.module;
		strProc = objEl_a.proc || '';
		objValue = evalConst(String(objEl_a.strmax));
		strModule = strSaveModule;
		strProc = strSaveProc;
		if ((objValue === null) || (objValue.k !== 'l') || (objValue.v < 1) || (objValue.v > 255))
		{
			error('String Max n: n must be a constant 1 .. 255 (' + objEl_a.id + ')');
			return 0;
		}

		return objValue.v;
	}

	// the most characters a string element holds. Every scalar string buffer
	// has this capacity in the byte before it ([cap][text...0]); array elements
	// are cap + 1 bytes each with no capacity byte (the stride says it).
	// Parameters, function results and Select values take the program's longest
	// (intStrMax), so nothing passed in is cut
	function strCap(objEl_a)
	{
		var intCap = fixedLen(objEl_a) || maxLen(objEl_a);

		if (intCap > 0)
		{
			return intCap;
		}
		if (objEl_a && ((objEl_a.etype === 'param') || (objEl_a.etype === 'result') || /^__sel\d+$/.test(objEl_a.id || '')))
		{
			return intStrMax;
		}

		return 40;
	}

	// the longest string the program declares (at least 40): temps, parameters,
	// results and the library's own buffers (NTC_STRMAX) are this long
	function findStrMax()
	{
		var intMax = 40;
		var strKey = '';
		var objItem = null;

		for (strKey in objEl)
		{
			if (objEl.hasOwnProperty(strKey))
			{
				objItem = objEl[strKey];
				if (((objItem.etype === 'var') || (objItem.etype === 'array')) && (typeOfEl(objItem) === 'str') && (objItem.fixed || objItem.strmax))
				{
					intMax = Math.max(intMax, fixedLen(objItem) || maxLen(objItem));
				}
			}
		}
		return intMax;
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
		declare(strLabel, (typeOfEl(objEl_a) === 'str') ? 'str' : ((typeOfEl(objEl_a) === 'long') ? 'long' : 'int'), (typeOfEl(objEl_a) === 'str') ? strCap(objEl_a) : 0);

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
					datatype: objField.type, typed: true, fixed: objField.fixed, strmax: objField.strmax,
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

	// a temp slot: pass 1 notes how many the procedure uses; pass 2 moves them above the
	// temps its callers still hold during the call (a Function in an expression), so a
	// call doesn't overwrite them
	function tmpSlot(intIndex_a)
	{
		if (intPass === 1)
		{
			if ((objTmpSize[strProc] || 0) < intIndex_a + 1)
			{
				objTmpSize[strProc] = intIndex_a + 1;
			}
			return intIndex_a;
		}

		return (objTmpBase[strProc] || 0) + intIndex_a;
	}

	// after pass 1: each procedure's first temp slot. A call made while slots 0 .. live-1
	// hold values puts the callee at least live slots above the caller's base. Interrupt
	// Ticks, Interrupt hooks and AddressOf targets can run at any point, so they (and what
	// they call) go above everything else.
	// pages: a procedure called from code in a page it is in too gets the local entry check
	function decideLocalCalls()
	{
		arrScanProcCalls.forEach(function(objCall_a)
		{
			var objFrom = objEl[objCall_a.from];
			var objTo = objEl[objCall_a.to];
			var arrFrom = null;
			var arrTo = null;

			if (objCall_a.root || !objFrom || !objTo)
			{
				return;
			}
			arrFrom = objClassPages[objFrom.module];
			arrTo = objClassPages[objTo.module];
			if (arrFrom && arrTo && arrFrom.some(function(str_a) { return arrTo.indexOf(str_a) > -1; }))
			{
				objLocalCalled[objCall_a.to] = true;
			}
		});
	}

	function decideTempBases()
	{
		var intRound = 0;
		var blnChanged = true;
		var intTop = 0;
		var strKey = '';

		objTmpBase = {};
		function raise(objCall_a, intFrom_a)
		{
			var intNew = intFrom_a + (objCall_a.live || 0);

			if ((objTmpBase[objCall_a.to] || 0) < intNew)
			{
				objTmpBase[objCall_a.to] = intNew;
				blnChanged = true;
			}
		}
		while (blnChanged && (intRound < 64))
		{
			blnChanged = false;
			intRound++;
			arrScanProcCalls.forEach(function(objCall_a)
			{
				if (!objCall_a.root)
				{
					raise(objCall_a, objTmpBase[objCall_a.from] || 0);
				}
			});
		}
		for (strKey in objTmpSize)
		{
			if (objTmpSize.hasOwnProperty(strKey) && ((objTmpBase[strKey] || 0) + objTmpSize[strKey] > intTop))
			{
				intTop = (objTmpBase[strKey] || 0) + objTmpSize[strKey];
			}
		}
		blnChanged = true;
		intRound = 0;
		while (blnChanged && (intRound < 64))
		{
			blnChanged = false;
			intRound++;
			arrScanProcCalls.forEach(function(objCall_a)
			{
				if (objCall_a.root)
				{
					raise({ to: objCall_a.to, live: 0 }, intTop);
				}
				else if ((objTmpBase[objCall_a.from] || 0) >= intTop)
				{
					raise(objCall_a, objTmpBase[objCall_a.from] || 0);
				}
			});
		}
	}

	function tmp(intIndex_a)
	{
		var intN = tmpSlot(intIndex_a);

		if (intN > intMaxTemp)
		{
			intMaxTemp = intN;
		}

		return 'tmp' + intN;
	}

	function stmp(intIndex_a)
	{
		var intN = tmpSlot(intIndex_a);

		if (intN > intMaxSTemp)
		{
			intMaxSTemp = intN;
		}

		return 'stmp' + intN;
	}

	function ltmp(intIndex_a)
	{
		var intN = tmpSlot(intIndex_a);

		if (intN > intMaxLTemp)
		{
			intMaxLTemp = intN;
		}

		return 'ltmp' + intN;
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
		var strText = '';

		if (objPlat.text === 'byte')
		{
			// a byte text platform: the text goes in the string pool, a new
			// line is kw_printnl
			for (intI = 0; intI <= arrBytes_a.length; intI++)
			{
				intCode = (intI < arrBytes_a.length) ? arrBytes_a[intI] : -2;
				if ((intCode === 13) || (intCode === 10) || (intCode === -2))
				{
					if (strText.length > 0)
					{
						emit('kw_printstrvar', [stringLabel(strText)]);
						strText = '';
					}
					if ((intCode === 13) && (arrBytes_a[intI + 1] === 10))
					{
						intI++;
					}
					if (intCode !== -2)
					{
						emit('kw_printnl', []);
					}
				}
				else
				{
					strText += String.fromCharCode(((intCode < 32) || (intCode > 126)) ? 63 : intCode);
				}
			}
			return;
		}

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

	// a string function may write straight into the target only when it is a
	// whole string variable (not an array element) as long as the longest string:
	// the library cuts at NTC_STRMAX, so nothing can run past it
	function strTarget(strTarget_a)
	{
		return (strScalar(strTarget_a) && (objDecl[strTarget_a].size >= intStrMax) && (objDecl[strTarget_a].kind === 'str')) ? strTarget_a : null;
	}

	// a whole string variable (has its capacity byte), not an array element
	function strScalar(strLabel_a)
	{
		return !!strLabel_a && (objDecl[strLabel_a] !== undefined) && ((objDecl[strLabel_a].kind === 'str') || (objDecl[strLabel_a].kind === 'strfix'));
	}

	// store a string: a whole variable through kw_strcpy (it cuts at the variable's
	// capacity byte), an array element through kw_strcpyn with the element's capacity
	function storeStr(strDest_a, strSrc_a)
	{
		var strBase = String(strDest_a).replace(/[+-]\d+$/, '');

		if (strDest_a === strSrc_a)
		{
			return;
		}
		if ((objDecl[strBase] !== undefined) && (objDecl[strBase].kind === 'sarr'))
		{
			emit('kw_strcpyn', [strDest_a, strSrc_a, (objDecl[strBase].stride || 41) - 1]);
			return;
		}
		emit('kw_strcpy', [strDest_a, strSrc_a]);
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
		var strDest = strScalar(strTarget_a) ? strTarget_a : stmp(intDest_a);

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
				return concat(objA, objB, intDest_a, strTarget_a);		// concat cuts at a variable's capacity
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

		return (strType === 'str') ? (strCap(objEl_a) + 1) : ((strType === 'long') ? 4 : 2);
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
		if (typeOfEl(objArray_a) === 'str')
		{
			objDecl[strLabel].stride = elementSize(objArray_a);
		}

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
			return blnStr ? sv(offsetLabel(strBase, objIndex.lit * elementSize(objArray_a))) : vr(offsetLabel(strBase, objIndex.lit * 2));
		}
		if (blnStr)
		{
			strDest = stmp(intSlot_a);
			emit('kw_sget', [offsetLabel(strBase, -objIndex.adjust * elementSize(objArray_a)), objIndex.v, strDest, elementSize(objArray_a)]);
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
			arrScanProcCalls.push({ from: strProc, to: objProc_a.full, mode: strMode, line: intLine, file: strFile, live: intSlot_a });
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
	// stub code: copy the 0 terminated string at HL into strDest_a (a label, or
	// '' for the address in DE), at most intCap_a chars (0: the destination's
	// capacity byte), always ending with a 0
	function stubStrCopy(arrCode_a, strDest_a, intCap_a, strLoop_a)
	{
		var strIndent = '\t\t\t';

		if (strDest_a.length > 0)
		{
			arrCode_a.push(strIndent + 'ld de, ' + strDest_a);
		}
		if (intCap_a > 0)
		{
			arrCode_a.push(strIndent + 'ld b, ' + intCap_a);
		}
		else
		{
			arrCode_a.push(strIndent + 'dec de');
			arrCode_a.push(strIndent + 'ld a, (de)\t\t; the destination\'s capacity');
			arrCode_a.push(strIndent + 'ld b, a');
			arrCode_a.push(strIndent + 'inc de');
		}
		arrCode_a.push(strLoop_a + ':');
		arrCode_a.push(strIndent + 'ld a, (hl)');
		arrCode_a.push(strIndent + 'ld (de), a');
		arrCode_a.push(strIndent + 'or a');
		arrCode_a.push(strIndent + 'jr z, ' + strLoop_a + '_e');
		arrCode_a.push(strIndent + 'inc hl');
		arrCode_a.push(strIndent + 'inc de');
		arrCode_a.push(strIndent + 'djnz ' + strLoop_a);
		arrCode_a.push(strIndent + 'xor a');
		arrCode_a.push(strIndent + 'ld (de), a');
		arrCode_a.push(strLoop_a + '_e:');
	}

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
					if (typeOfEl(objEl[objParam.full + objLeaf_a.path]) === 'str')
					{
						stubStrCopy(arrCode, varLabel(objEl[objParam.full + objLeaf_a.path]), strCap(objEl[objParam.full + objLeaf_a.path]), strBody + '_si' + intI + '_' + intLeaf_a);
						return;
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
			if (typeOfEl(objParam) === 'str')
			{
				stubStrCopy(arrCode, strLabel, strCap(objParam), strBody + '_si' + intI);
			}
			else if (typeOfEl(objParam) === 'long')
			{
				arrCode.push(strIndent + 'ld de, ' + strLabel);
				arrCode.push(strIndent + 'ld bc, 4');
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
		if (isOverlayProc(objProc_a))
		{
			// a class in a page: keep the caller's page, switch the class's in (loading it
			// first). A call from code in the same page (its local entry set ntc_ovl_lc) needs
			// no switch. A class in more than one page: the copy is picked (ntc_ovl_enterc)
			declare(procBase(objProc_a) + '_pg', 'int', 0);
			objStubClass[strBody] = { module: objProc_a.module, proc: objProc_a.full, mode: strMode_a };
			if (objLocalCalled[objProc_a.full])
			{
				arrCode.push(strIndent + 'ld a, (ntc_ovl_lc)\t; called from its own page?');
				arrCode.push(strIndent + 'or a');
				arrCode.push(strIndent + 'jr z, ' + strBody + '_far');
				arrCode.push(strIndent + 'xor a');
				arrCode.push(strIndent + 'ld (ntc_ovl_lc), a');
				arrCode.push(strIndent + 'dec a');
				arrCode.push(strIndent + 'ld (' + procBase(objProc_a) + '_pg), a\t; #FF..: no page back on return');
				arrCode.push(strIndent + 'ld (' + procBase(objProc_a) + '_pg+1), a');
				arrCode.push(strIndent + 'jr ' + strBody + '_in');
				arrCode.push(strBody + '_far:');
			}
			if (objClassKind[objProc_a.module].pages.length > 1)
			{
				arrCode.push(strIndent + 'ld hl, ' + strBody + '_ct\t; its copies (' + objClassKind[objProc_a.module].pages.map(function(str_a) { return objPages[str_a].name; }).join(', ') + ')');
				arrCode.push(strIndent + 'ld de, ' + procBase(objProc_a) + '_pg');
				arrCode.push(strIndent + 'ld ix, ' + strBody + '_in');
				arrCode.push(strIndent + 'jp ntc_ovl_enterc');
				arrCode.push(strBody + '_in:');
				arrCode.push(strIndent + 'ld sp, (ntc_ovl_body)');
			}
			else
			{
				arrCode.push(strIndent + 'ld hl, ' + objClassKind[objProc_a.module].blk + '\t; page ' + objClassKind[objProc_a.module].file);
				arrCode.push(strIndent + 'ld de, ' + procBase(objProc_a) + '_pg');
				arrCode.push(strIndent + 'ld ix, ' + strBody + '_in');
				arrCode.push(strIndent + 'jp ntc_ovl_enter');
				arrCode.push(strBody + '_in:');
				arrCode.push(strIndent + 'ld sp, ' + strBody);
			}
		}
		else
		{
			arrCode.push(strIndent + 'ld sp, ' + strBody);
		}
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
					if (typeOfEl(objEl[objParam.full + objLeaf_a.path]) === 'str')
					{
						stubStrCopy(arrCode, '', 0, strBody + '_so' + intI + '_' + intLeaf_a);
						return;
					}
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
					if (typeOfEl(objParam) === 'str')
					{
						stubStrCopy(arrCode, '', 0, strBody + '_so' + intI);		// cut at the caller's capacity
					}
					else
					{
						arrCode.push(strIndent + 'ld bc, 4');
						arrCode.push(strIndent + 'ldir');
					}
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
		if (isOverlayProc(objProc_a) && objLocalCalled[objProc_a.full])
		{
			arrCode.push(strIndent + 'ld hl, (' + procBase(objProc_a) + '_pg)');
			arrCode.push(strIndent + 'ld a, h');
			arrCode.push(strIndent + 'and l');
			arrCode.push(strIndent + 'inc a');
			arrCode.push(strIndent + 'jr z, ' + strBody + '_rb\t; a call from its own page: nothing to switch back');
		}
		if (isOverlayProc(objProc_a) && (objMemory.scheme === 'small'))
		{
			// one overlay area: the caller's page back in it, if another took its place
			arrCode.push(strIndent + 'ld hl, (' + procBase(objProc_a) + '_pg)\t; the caller\'s page back in the overlay area');
			arrCode.push(strIndent + 'ld ix, ' + strBody + '_rb');
			arrCode.push(strIndent + 'jp ntc_ovl_ret');
			arrCode.push(strBody + '_rb:');
		}
		else if (isOverlayProc(objProc_a))
		{
			arrCode.push(strIndent + 'ld sp, (ntc_csp)\t\t; the caller\'s page back');
			arrCode.push(strIndent + 'ld hl, (' + procBase(objProc_a) + '_pg)');
			arrCode.push(strIndent + 'call mem_sel');
			if (objLocalCalled[objProc_a.full])
			{
				arrCode.push(strBody + '_rb:');
			}
		}
		if (objClassKind[objProc_a.module] && objClassKind[objProc_a.module].isl && (objProc_a.id.toLowerCase() === 'tick'))
		{
			arrCode.push(strIndent + 'xor a\t\t\t; Tick done: it may run again');
			arrCode.push(strIndent + 'ld (ntc_isl + ' + (objClassKind[objProc_a.module].isl.slot * 8 + 4) + '), a');
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
			arrScanProcCalls.push({ from: strProc, to: objProc.full, mode: strMode, line: intLine, file: strFile, root: true });
		}
		strLabel = 'ap_' + procLabel(objProc, kwMode()) + '_c';
		if (objLits[strLabel] === undefined)
		{
			objLits[strLabel] = procLabel(objProc, kwMode()) + '_c';
			arrLits.push(strLabel);
		}

		return vr(strLabel);
	}

	// VarPtr(name): a read only word holding the address of a variable (its value; a
	// String: its first character) or of a fixed size array's first element
	function varPtr(strName_a)
	{
		var objElement = resolve(strName_a, false, false);
		var strTarget = '';
		var strLabel = '';

		if ((objElement !== null) && (objElement.etype === 'array') && !isDescArray(objElement) && !objElement.udt)
		{
			strTarget = arrayLabel(objElement);
		}
		else if ((objElement !== null) && ((objElement.etype === 'var') || (objElement.etype === 'param') || (objElement.etype === 'result')) && !objElement.udt)
		{
			strTarget = varLabel(objElement);
		}
		else
		{
			error('VarPtr needs a variable or a fixed size array: ' + strName_a);
			return lit(0);
		}
		noteWrite(objElement);		// memory behind it may be written (Load, #asm)
		strLabel = 'vp_' + strTarget;
		if (objLits[strLabel] === undefined)
		{
			objLits[strLabel] = strTarget;
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
		var objValue = null;
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
		if ((objElement === null) && /^__varptr_/i.test(strToken_a))
		{
			return varPtr(strToken_a.substr(9).replace(/__dot__/gi, '.'));
		}
		if ((objElement === null) && ((strUpper === 'INKEY$') || (strUpper === 'INKEY')) && consoleVia())
		{
			// the project's own StdIO: GetKey (Inkey$ = Chr$ of it, Chr$(0) = "")
			materialize(arrStack_a, intBase_a);
			objValue = consoleCall('GetKey', [], intBase_a + arrStack_a.length);
			if ((objValue === null) || (strUpper === 'INKEY'))
			{
				return (objValue === null) ? lit(0) : objValue;
			}
			strTemp = stmp(intBase_a + arrStack_a.length);
			emit('kw_strchr', [strTemp, numAddr(objValue, intBase_a + arrStack_a.length)]);
			return sv(strTemp);
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
		}).replace(/\bvarptr\s*\(\s*([a-z_][\w.]*[$%&]?)\s*\)/gi, function(strAll_a, strName_a)
		{
			// VarPtr(name) -> one operand token
			return '__varptr_' + strName_a.replace(/\$/g, '').replace(/\./g, '__dot__');
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
		var objResult = compileExpr(strExpr_a, strScalar(strDest_a) ? strDest_a : null, 0);

		if (objResult.done)
		{
			return;
		}
		if (isConstNum(objResult))
		{
			objResult = strOf(objResult, 0);
		}
		if (objResult.k !== 's')
		{
			// VB turns a number into text: straight in when the target is long enough,
			// else through a temp and a store that cuts
			if (strTarget(strDest_a))
			{
				emit((objResult.k === 'd') ? 'kw_l_cstr' : 'kw_strcstr', [strDest_a, (objResult.k === 'd') ? objResult.n : numAddr(objResult, 0)]);
				return;
			}
			objResult = strOf(objResult, 0);
		}
		storeStr(strDest_a, objResult.n);
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

	// a branch / loop body must end in the mode it started in: when it doesn't (Turbo On ...
	// Turbo Off in a program that started in turbo mode), the mode is switched back there,
	// with a warning, so the code after the block knows its mode
	function modeCheck(objCtl_a, strWhere_a)
	{
		if (objCtl_a && (objCtl_a.mode !== strMode))
		{
			if ((objCtl_a.mode === 't') && (strMode === 'n'))
			{
				emitRaw('kw_turbo_on', [], false);
			}
			else if ((objCtl_a.mode === 'n') && (strMode === 't'))
			{
				emitRaw('kw_turbo_off', [], false);
			}
			if (intPass === 2)
			{
				warning(strWhere_a + ' (line ' + objCtl_a.line + ') started in ' + ((objCtl_a.mode === 't') ? 'turbo' : 'normal') + ' mode and this part ends in ' + ((strMode === 't') ? 'turbo' : 'normal') + ' mode: switched back to ' + ((objCtl_a.mode === 't') ? 'turbo' : 'normal') + ' here (Option Turbo Off / Option Turbo sets the start mode)');
			}
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

	// ------------------------------------------------------------
	// the project's own StdIO class: console statements call its methods
	// (not inside StdIO itself, so it can use the built in ones)
	// ------------------------------------------------------------
	function consoleVia()
	{
		return (objOwnClass.stdio === true) && (strProc.substr(0, 6) !== 'stdio.');
	}

	function consoleCall(strMethod_a, arrOps_a, intSlot_a)
	{
		var objProc = objEl['stdio.' + strMethod_a.toLowerCase()];

		if ((objProc === undefined) || (objProc.etype !== 'proc'))
		{
			error('your StdIO class has no ' + strMethod_a + ' (the console statements use it)');
			return null;
		}
		return procCall(objProc, arrOps_a, true, intSlot_a, null);
	}

	// Print through StdIO: text and numbers -> PutStr, Tab(n) -> Tab, the end -> NewLine
	function compilePrintVia(strArgs_a)
	{
		var arrItems = splitTop(strArgs_a, ';,');
		var arrMatch = null;
		var blnNewline = true;
		var intI = 0;
		var objValue = null;
		var strItem = '';
		var strText = '';

		function flushText()
		{
			if (strText.length > 0)
			{
				consoleCall('PutStr', [sv(stringLabel(strText))], 0);
				strText = '';
			}
		}

		for (intI = 0; intI < arrItems.length; intI++)
		{
			strItem = trim(arrItems[intI].text);
			if ((arrMatch = strItem.match(/^tab\s*\((.*)\)$/i)))
			{
				flushText();
				consoleCall('Tab', [compileValue(arrMatch[1], 0)], 0);
			}
			else if (strItem.length > 0)
			{
				objValue = compileExpr(strItem, null, 0);
				if ((objValue.k === 's') && /^str\d+$/.test(objValue.n))
				{
					strText += arrStrings[parseInt(objValue.n.substr(3), 10)].text;
				}
				else if (isConstNum(objValue))
				{
					strText += String(constNum(objValue));
				}
				else
				{
					flushText();
					consoleCall('PutStr', [strOf(objValue, 0)], 1);
				}
			}
			if (arrItems[intI].sep === ',')
			{
				strText += ' ';
			}
			if ((intI === arrItems.length - 1) && (strItem.length === 0) && (intI > 0))
			{
				blnNewline = false;	// ended with ; or ,
			}
		}
		flushText();
		if (blnNewline)
		{
			consoleCall('NewLine', [], 0);
		}
	}

	function compilePrint(strArgs_a)
	{
		if (consoleVia())
		{
			compilePrintVia(strArgs_a);
			return;
		}

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
			if (consoleVia())
			{
				// the project's own StdIO: the prompt through PutStr, the line through GetLine
				if (strPrompt.length > 0)
				{
					consoleCall('PutStr', [sv(stringLabel(strPrompt))], 0);
					strPrompt = '';
				}
				if (objTarget.str)
				{
					consoleCall('GetLine', [{ k: 's', n: objTarget.label, el: objTarget.el }], 0);
				}
				else
				{
					consoleCall('GetLine', [sv(stmp(0))], 0);
					emit(objTarget.lng ? 'kw_l_val' : 'kw_strval', [stmp(0), objTarget.label]);
				}
			}
			else
			{
				if (strPrompt.length > 0)
				{
					emitZoscii(textToBytes(strPrompt));
					strPrompt = '';
				}
				emit(objTarget.str ? 'kw_inputstr' : (objTarget.lng ? 'kw_l_input' : 'kw_inputint'), [objTarget.label]);
			}
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
		var strKw = '';
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
				strKw = (typeOfEl(objElement) === 'str') ? 'kw_psets' : 'kw_pset';		// a string: cut at the element's size
				if (objIndex2 !== null)
				{
					emit(strKw + '2', [descLabel(objElement), numAddr(objIndex, 0), numAddr(objIndex2, 1), strName]);
				}
				else
				{
					emit(strKw, [descLabel(objElement), numAddr(objIndex, 0), strName]);
				}
				return;
			}
			strBase = arrayLabel(objElement);
			objIndex = arrayIndex(objElement, arrIndex, 0);
			if (typeOfEl(objElement) === 'str')
			{
				if (objIndex.lit !== undefined)
				{
					compileStringAssign(offsetLabel(strBase, objIndex.lit * elementSize(objElement)), objRec_a.expr);
					return;
				}
				objIndex.v = keepSlot(numVar(objIndex.v, 0), 0);
				objValue = strOf(compileExpr(objRec_a.expr, null, 1), 1);
				emit('kw_sset', [offsetLabel(strBase, -objIndex.adjust * elementSize(objElement)), objIndex.v, objValue.n, elementSize(objElement)]);
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
				if (!objPlat.irq)
				{
					error('Interrupt needs a CPC platform: cpc, cpcmin or cpcfw (not ' + objOptions.platform + ')');
					return;
				}
				objHookProcs[objElement.full] = true;
				blnHookUsed = true;
				if (intPass === 1)
				{
					arrScanProcCalls.push({ from: strProc, to: objElement.full, mode: 'n', line: intLine, file: strFile, root: true });
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
	// moves SP to a label or HL (ld sp, x) is a branch: its normal mode copy ends
	// with jp ntc_xn. ld sp, (var) - switching to the real stack and back - isn't.
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
			// ld sp, label / ld sp, hl moves the thread: a branch. ld sp, (var) is the
			// switch to the real stack and back (ld sp, (ntc_csp) ... ld sp, (saved)):
			// not a branch, so the block's own call / ret on the real stack stay as written
			if (/^\s*ld\s+sp\s*,\s*[^\s(]/i.test(strCode))
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
				if (/^\s*ld\s+sp\s*,\s*[^\s(]/i.test(strCode))
				{
					blnOk = false;		// moves SP to a label / HL: a branch, stays a procedure
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
		if ((objDynMax[objElement_a.full] || 0) < intMost * elementSize(objElement_a))
		{
			objDynMax[objElement_a.full] = intMost * elementSize(objElement_a);
		}
		intMost = Math.floor(objDynMax[objElement_a.full] / elementSize(objElement_a));
		objText = strOf(compileExpr(arrArgs_a[0].text, null, 0), 0);
		objSep = (arrArgs_a.length > 1) ? strOf(compileExpr(arrArgs_a[1].text, null, 1), 1) : sv(stringLabel(' '));
		emit('kw_strsplit', [descLabel(objElement_a), dynLabel(objElement_a), intMost, objText.n, objSep.n, elementSize(objElement_a)]);
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
		var objValues = null;
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
				if (blnNoTurbo)
				{
					if (intPass === 2)
					{
						warning((objRec_a.on ? 'Turbo On' : 'Turbo Off') + ' does nothing with Option NoTurbo (normal mode only)');
					}
					break;
				}
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
				if (consoleVia())
				{
					consoleCall('Cls', [], 0);
					break;
				}
				emit('kw_cls', []);
				break;

			case 'frame':
				emit('kw_frame', []);
				break;

			case 'locate':
				if (consoleVia())
				{
					objValues = compileTwoValues(objRec_a.args, 'LOCATE');
					if (objValues !== null)
					{
						consoleCall('Locate', objValues, 0);
					}
					break;
				}
				compileLocate(objRec_a.args);
				break;

			case 'mode':
				if (consoleVia())
				{
					consoleCall('Mode', [compileValue(objRec_a.expr, 0)], 0);
					break;
				}
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
			if (isOverlayProc(objProc))
			{
				arrOut.push({ t: 'ovl', name: objProc.module });	// its thread goes into the overlay
			}
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
		if ((intPass === 2) && isOverlayProc(objProc))
		{
			arrOut.push({ t: 'ovlend' });
		}
		strProc = '';
		strCopy = '';
	}

	// the pages' contents: for each page its classes' threads (copies of a class that is in
	// more than one page get every label they define renamed, label__page), calls between
	// classes of the same page through local entries (no page switch), GOTO / GOSUB stubs
	// for the renamed copies, the paged variables; the copy tables (main memory) and the
	// DISPLAY lines of the layout (sjasmplus prints them when assembling)
	function composePages()
	{
		var objOut = { pages: {}, vars: {}, display: {}, tables: [], layout: [] };
		var strIndent = '\t\t\t';

		function homeOf(strModule_a)
		{
			return objClassKind[strModule_a].home;
		}
		function sfxOf(strModule_a, strPage_a)
		{
			return (homeOf(strModule_a) === strPage_a) ? '' : '__' + strPage_a;
		}
		function codeEnd(str_a)
		{
			var intI = str_a.indexOf(';');

			return (intI < 0) ? str_a.length : intI;
		}

		arrPageOrder.forEach(function(strId_a)
		{
			var objPage = objPages[strId_a];
			var arrLines = [];
			var arrVars = [];
			var arrDisplay = [];
			var arrEntries = [];
			var objEntries = {};
			var arrStubs = [];
			var intVars = 0;
			var intEst = 0;
			var arrSizes = [];

			arrLines.push(strIndent + 'dw NTC_STAMP\t\t; the build stamp: the loader checks it against the program\'s');
			intEst += 2;
			objPage.classes.forEach(function(strModule_a, intClass_a)
			{
				var strSfx = sfxOf(strModule_a, strId_a);
				var arrDefs = [];
				var objStubUsed = {};
				var objRe = null;
				var strTag = 'ovl_' + strId_a + '__' + intClass_a;
				var intBytes = 0;

				(objOvlAsm[strModule_a] || []).forEach(function(str_a)
				{
					var arrMatch = str_a.match(/^([A-Za-z_]\w*):/);

					if (arrMatch)
					{
						arrDefs.push(arrMatch[1]);
					}
				});
				(objOvlVars[strModule_a] || []).forEach(function(objItem_a)
				{
					arrDefs.push(objItem_a.label);
				});
				if ((strSfx.length > 0) && (arrDefs.length > 0))
				{
					objRe = new RegExp('\\b(' + arrDefs.join('|') + ')(_go|_gs|_rt)?\\b', 'g');
					// #asm blocks are in main memory, shared by the copies: one that names a label
					// of the class's threads would reach the home copy from every page
					arrAsmBlocks.forEach(function(objBlock_a)
					{
						var objFound = null;

						if (objBlock_a.module !== strModule_a)
						{
							return;
						}
						objBlock_a.lines.forEach(function(str_a)
						{
							var arrWords = str_a.substr(0, codeEnd(str_a)).match(/[A-Za-z_]\w*/g) || [];

							arrWords.forEach(function(strWord_a)
							{
								if ((objFound === null) && (arrDefs.indexOf(strWord_a) > -1))
								{
									objFound = strWord_a;
								}
							});
						});
						if ((objFound !== null) && (intClass_a >= 0) && !objBlock_a.copyerr)
						{
							objBlock_a.copyerr = true;
							arrErrors.push({ file: objBlock_a.file, line: objBlock_a.line, msg: 'an #asm block in ' + strModule_a + ' names ' + objFound + ' (its threads): ' + strModule_a + ' is in more than one page, and the block (in main memory) would reach the home copy from every page' });
						}
					});
				}
				arrLines.push(strTag + '_s:\t\t; ' + strModule_a + ((strSfx.length > 0) ? ' (a copy: its labels end ' + strSfx + ')' : ''));
				(objOvlAsm[strModule_a] || []).forEach(function(str_a)
				{
					var intEnd = codeEnd(str_a);
					var strCode = str_a.substr(0, intEnd);
					var strRest = str_a.substr(intEnd);
					var arrMatch = strCode.match(/^(\s*dw\s+)([A-Za-z_]\w*)(.*)$/);
					var strWord = '';
					var objCallee = null;
					var strEntry = '';

					// a call to a class in this page: its local entry
					if (arrMatch && (arrMatch[2].length > 2) && (arrMatch[2].substr(arrMatch[2].length - 2) === '_c'))
					{
						strWord = arrMatch[2].substr(0, arrMatch[2].length - 2);
						objCallee = objStubClass[strWord];
						if (objCallee && (objPage.classes.indexOf(objCallee.module) > -1) && objLocalCalled[objCallee.proc])
						{
							strEntry = strWord + '_cl' + sfxOf(objCallee.module, strId_a);
							if (objEntries[strEntry] === undefined)
							{
								objEntries[strEntry] = true;
								arrEntries.push({ label: strEntry, body: strWord + sfxOf(objCallee.module, strId_a), stub: strWord + '_c', copied: objClassKind[objCallee.module].pages.length > 1 });
							}
							strCode = arrMatch[1] + strEntry + arrMatch[3];
						}
					}
					if (objRe !== null)
					{
						strCode = strCode.replace(objRe, function(strAll_a, strName_a, strKind_a)
						{
							if (strKind_a)
							{
								objStubUsed[strName_a + '|' + strKind_a] = { name: strName_a, kind: strKind_a };
							}
							return strName_a + strSfx + (strKind_a || '');
						});
					}
					arrMatch = strCode.match(/^\s*dw\s+(.*)$/);
					if (arrMatch)
					{
						intBytes += 2 * arrMatch[1].split(',').length;
					}
					arrLines.push(strCode + strRest);
				});
				// GOTO / GOSUB stubs for a copy's renamed labels (the program's point to the home copy)
				Object.keys(objStubUsed).forEach(function(strKey_a)
				{
					var objUse = objStubUsed[strKey_a];
					var strMode_ = objLabelMode[objUse.name] || 't';

					if (objUse.kind === '_go')
					{
						arrStubs.push(objUse.name + strSfx + '_go:' + strIndent + 'ld sp, ' + objUse.name + strSfx);
						arrStubs.push(strIndent + exitCode(strMode_));
					}
					else if (objUse.kind === '_gs')
					{
						arrStubs.push(objUse.name + strSfx + '_gs:' + strIndent + 'ld (' + objUse.name + '_rs), sp');
						arrStubs.push(strIndent + 'ld sp, ' + objUse.name + strSfx);
						arrStubs.push(strIndent + exitCode(strMode_));
					}
					else
					{
						arrStubs.push(objUse.name + strSfx + '_rt:' + strIndent + 'ld sp, (' + objUse.name + '_rs)');
						arrStubs.push(strIndent + exitCode(strMode_));
					}
					intBytes += 5;
				});
				arrLines.push(strTag + '_e:');
				arrSizes.push({ module: strModule_a, tag: strTag, copy: strSfx.length > 0, bytes: intBytes });
				intEst += intBytes;
			});
			if ((arrEntries.length > 0) || (arrStubs.length > 0))
			{
				arrLines.push('; calls from this page into it (no page switch), GOTO / GOSUB of copies');
				arrLines.push('ovl_' + strId_a + '__x_s:');
			}
			arrEntries.forEach(function(objEntry_a)
			{
				if (objEntry_a.copied)
				{
					arrLines.push(objEntry_a.label + ':' + strIndent + 'ld hl, ' + objEntry_a.body + '\t; this page\'s copy');
					arrLines.push(strIndent + 'ld (ntc_ovl_body), hl');
					arrLines.push(strIndent + 'ld a, 1');
					intEst += 6;
				}
				else
				{
					arrLines.push(objEntry_a.label + ':' + strIndent + 'ld a, 1');
				}
				arrLines.push(strIndent + 'ld (ntc_ovl_lc), a');
				arrLines.push(strIndent + 'jp ' + objEntry_a.stub);
				intEst += 8;
			});
			arrLines = arrLines.concat(arrStubs);
			if ((arrEntries.length > 0) || (arrStubs.length > 0))
			{
				arrLines.push('ovl_' + strId_a + '__x_e:');
			}
			arrLines.push(strIndent + 'dw 0\t\t\t; (never empty)');
			// Paged Strings: in the file (their capacity byte goes before them), each copy its own
			objPage.classes.forEach(function(strModule_a)
			{
				var strSfx = sfxOf(strModule_a, strId_a);

				(objOvlVars[strModule_a] || []).forEach(function(objItem_a)
				{
					if ((objItem_a.kind === 'str') || (objItem_a.kind === 'strfix'))
					{
						arrLines.push(strIndent + 'db ' + objItem_a.size + '\t\t\t; capacity');
						if (objItem_a.kind === 'str')
						{
							arrLines.push(objItem_a.label + strSfx + ':' + strIndent + 'ds ' + (objItem_a.size + 1));
						}
						else
						{
							arrLines.push(objItem_a.label + strSfx + ':' + strIndent + 'ds ' + objItem_a.size + ', 32');
							arrLines.push(strIndent + 'db 0');
						}
						intEst += objItem_a.size + 2;
					}
				});
			});
			objPage.classes.forEach(function(strModule_a)
			{
				var strSfx = sfxOf(strModule_a, strId_a);

				(objOvlVars[strModule_a] || []).forEach(function(objItem_a)
				{
					var intSize = (objItem_a.kind === 'long') ? 4 : (((objItem_a.kind === 'str') || (objItem_a.kind === 'strfix')) ? 0 : (bssSize(objItem_a) || 2));

					if (intSize > 0)
					{
						arrVars.push(objItem_a.label + strSfx + '\t\tequ ovl_' + strId_a + '_end + ' + intVars + '\t\t; ' + intSize + ' bytes (' + strModule_a + ')');
						intVars += intSize;
					}
				});
			});
			arrVars.push('ovl_' + strId_a + '_vsize\tequ ' + intVars + '\t\t; its page variables; its local memory is the rest, to #8000');
			// the layout, as the assembler counts it
			arrDisplay.push(strIndent + 'DISPLAY "page ' + objPage.name + ' (' + objPage.file + '):"');
			arrSizes.forEach(function(objSize_a)
			{
				arrDisplay.push(strIndent + 'DISPLAY "  ' + objSize_a.module + (objSize_a.copy ? ' (copy)' : (objClassKind[objSize_a.module].pages.length > 1 ? ' (home)' : '')) + ' ", /D, ' + objSize_a.tag + '_e - ' + objSize_a.tag + '_s');
			});
			if ((arrEntries.length > 0) || (arrStubs.length > 0))
			{
				arrDisplay.push(strIndent + 'DISPLAY "  (local entries, stubs) ", /D, ovl_' + strId_a + '__x_e - ovl_' + strId_a + '__x_s');
			}
			arrDisplay.push(strIndent + 'DISPLAY "  page variables ", /D, ovl_' + strId_a + '_vsize, ", free ", /D, #8000 - (ovl_' + strId_a + '_end + ovl_' + strId_a + '_vsize)');
			objOut.pages[strId_a] = arrLines;
			objOut.vars[strId_a] = arrVars;
			objOut.display[strId_a] = arrDisplay;
			if (intEst + intVars + 2 > 16384)
			{
				arrErrors.push({ file: objPage.srcfile, line: objPage.line, msg: 'page ' + objPage.name + ' (' + objPage.classes.join(', ') + ') is more than 16K: about ' + (intEst + intVars + 2) + ' bytes' });
			}
			objOut.layout.push({ page: objPage.name, file: objPage.file, classes: arrSizes.map(function(objSize_a) { return { module: objSize_a.module, copy: objSize_a.copy, home: !objSize_a.copy && (objClassKind[objSize_a.module].pages.length > 1), bytes: objSize_a.bytes }; }), vars: intVars, bytes: intEst + intVars + 2 });
		});
		// the copy tables: a procedure of a class in more than one page
		Object.keys(objStubClass).forEach(function(strBody_a)
		{
			var objStub = objStubClass[strBody_a];
			var arrIn = objClassKind[objStub.module].pages;
			var arrRows = [];

			if (arrIn.length < 2)
			{
				return;
			}
			// with Private Paged variables each copy keeps its own: calls from outside use the home copy
			arrRows = ((objOvlVars[objStub.module] || []).length > 0) ? [arrIn[0]] : arrIn;
			objOut.tables.push(strBody_a + '_ct:\tdb ' + arrRows.length + ((arrRows.length < arrIn.length) ? '\t\t; paged variables: the home copy only' : ''));
			arrRows.forEach(function(strPage_a)
			{
				objOut.tables.push(strIndent + 'dw ' + objPages[strPage_a].blk + ', ' + strBody_a + sfxOf(objStub.module, strPage_a));
			});
		});
		return objOut;
	}

	// a procedure of an overlay class (not an asm keyword: those stay in main memory)
	function isOverlayProc(objProc_a)
	{
		return !objProc_a.asmkw && (objClassKind[objProc_a.module] !== undefined) && (objClassKind[objProc_a.module].kind === 'overlay');
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
		if (intPass === 1)
		{
			arrIslots.forEach(function(objSlot_a)
			{
				var objTick = objEl[objSlot_a.module + '.tick'];

				if ((objTick === undefined) || (objTick.etype !== 'proc') || (objTick.kind !== 'sub') || (procParams(objTick).length > 0))
				{
					if (!objSlot_a.bad)
					{
						arrErrors.push({ file: objSlot_a.file, line: objSlot_a.line, msg: 'Option Class Interrupt: the class needs a Sub Tick() with no parameters' });
					}
					objSlot_a.bad = true;
					return;
				}
				objSlot_a.tick = objTick;
				blnHookUsed = true;
				arrScanProcCalls.push({ from: '', to: objTick.full, mode: 'n', line: objSlot_a.line, file: objSlot_a.file, root: true });
			});
		}
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
			if (!blnChanged || (objItem.t === 'comment') || (objItem.t === 'ovl') || (objItem.t === 'ovlend'))
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
		var blnSkip = false;

		for (intI = 0; intI < arrLines.length; intI++)
		{
			if ((arrMatch = arrLines[intI].match(/^;##\s+(\S+)(.*)$/)))
			{
				arrParts = trim(arrMatch[2]).length > 0 ? trim(arrMatch[2]).split(/\s+/) : [];
				objCurrent = { name: arrMatch[1], deps: [], shared: false, lines: [], labels: [], header: arrLines[intI] };
				blnSkip = false;
				for (intJ = 0; intJ < arrParts.length; intJ++)
				{
					if (arrParts[intJ] === '@shared')
					{
						objCurrent.shared = true;
					}
					else if (arrParts[intJ] === '@romram')
					{
						objCurrent.romram = true;		// in the keyword library ROM this runs from RAM (ntcRomAsm)
					}
					else if (arrParts[intJ] === '@ramonly')
					{
						objCurrent.ramonly = true;		// not in the keyword library ROM: a Library: ROM program has its own copy
					}
					else if (arrParts[intJ].substr(0, 4) === '@if:')
					{
						// only when that #Const is set (NTC_MEM_SMALL ...): else the section isn't there
						blnSkip = (objDefinesIn[arrParts[intJ].substr(4).toLowerCase()] === undefined);
						objCurrent.header = objCurrent.header.replace(/\s+@if:\S+/, '');
					}
					else
					{
						objCurrent.deps.push(arrParts[intJ]);
					}
				}
				if (blnSkip)
				{
					continue;		// its lines go to objCurrent, which is not kept
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
	var objLibLabelSection = {};

	// the platform file's ;@key value lines: what the compiler needs to know
	// about the target (org, text form, screen set up, interrupt handler ...)
	function platformText()
	{
		var strPlatform = objOptions.platformtext;

		if ((strPlatform === null) && (typeof NTC_PLATFORMS !== 'undefined'))
		{
			strPlatform = NTC_PLATFORMS[objOptions.platform];
		}
		return strPlatform;
	}

	function readPlatform()
	{
		var arrMatch = null;
		var strPlatform = platformText();

		objPlat = { name: objOptions.platform, org: '#4000', text: 'glyph', scrinit: 1, irq: 0, stack: '', cols: 40, rows: 25 };
		if ((strPlatform === null) || (strPlatform === undefined))
		{
			return;
		}
		String(strPlatform).split(/\r?\n/).forEach(function(strLine_a)
		{
			if ((arrMatch = strLine_a.match(/^;@(\w+)\s+(.*?)\s*$/)))
			{
				objPlat[arrMatch[1].toLowerCase()] = /^\d+$/.test(arrMatch[2]) ? parseInt(arrMatch[2], 10) : arrMatch[2];
			}
		});
	}

	// Option Terminal VT52 | ANSI | None (read before parsing: the platform classes
	// depend on it through #If NTC_TERM_POS)
	// Option Reserve start, size [, start, size] ...: memory the program must not reach
	// into (a screen, a load buffer, firmware RAM). Checked when assembling (ASSERT)
	function readReserve(objRec_a)
	{
		var arrParts = String(objRec_a.value).split(',').map(trim);
		var intI = 0;
		var intStart = 0;
		var intSize = 0;

		if ((arrParts.length < 2) || ((arrParts.length % 2) !== 0))
		{
			arrErrors.push({ file: objRec_a.file, line: objRec_a.line, msg: 'Option Reserve needs pairs: start, size [, start, size] ...' });
			return;
		}
		for (intI = 0; intI < arrParts.length; intI += 2)
		{
			intStart = parseNumber(arrParts[intI]);
			intSize = parseNumber(arrParts[intI + 1]);
			if (isNaN(intStart) || isNaN(intSize) || (intStart < 0) || (intStart > 65535) || (intSize < 1) || (intStart + intSize > 65536))
			{
				arrErrors.push({ file: objRec_a.file, line: objRec_a.line, msg: 'Option Reserve: bad range ' + arrParts[intI] + ', ' + arrParts[intI + 1] + ' (numbers: start 0-&HFFFF, size 1 or more, not past &HFFFF)' });
				continue;
			}
			if (((objOptions.platform === 'cpc') || (objOptions.platform === 'cpcmin')) && (intStart < 0xC100) && (intStart + intSize > 0xC000))
			{
				arrWarnings.push({ file: objRec_a.file, line: objRec_a.line, msg: 'Option Reserve covers #C000: the cpc platform puts its font copy code at #C000 for a moment when the screen is first used - load into that area only after the first Print / Cls / Mode' });
			}
			arrReserve.push({ start: intStart, size: intSize, file: objRec_a.file, line: objRec_a.line });
		}
	}

	// Option RomEnable All | n [, n] ...: the CPC firmware platform starts these ROMs (RUN"
	// of a binary resets the firmware and drops them - AMSDOS too)
	function readRomEnable(objRec_a)
	{
		var arrParts = String(objRec_a.value).split(',').map(trim);
		var intI = 0;
		var intRom = 0;

		if ((objOptions.platform !== 'cpcfw') && (objOptions.platform !== 'cpcmin'))
		{
			arrWarnings.push({ file: objRec_a.file, line: objRec_a.line, msg: 'Option RomEnable is for the CPC firmware platforms (cpcfw, cpcmin) - no effect on ' + objOptions.platform + ((objOptions.platform === 'cpc') ? ' (it uses no ROMs: cpcmin keeps the firmware for discs and ROMs)' : '') });
			return;
		}
		if ((arrParts.length === 1) && (arrParts[0] === 'all'))
		{
			arrRomEnable = ['all'];
			return;
		}
		arrRomEnable = [];
		for (intI = 0; intI < arrParts.length; intI++)
		{
			intRom = parseNumber(arrParts[intI]);
			if (isNaN(intRom) || (intRom < 0) || (intRom > 255))
			{
				arrErrors.push({ file: objRec_a.file, line: objRec_a.line, msg: 'Option RomEnable: All, or ROM numbers 0-255 (AMSDOS is 7): ' + arrParts[intI] });
				continue;
			}
			arrRomEnable.push(intRom);
		}
	}

	// bytes an array (or descriptor) takes after the program; 0 = it stays in the program
	function bssSize(objItem_a)
	{
		switch (objItem_a.kind)
		{
			case 'arr': return objItem_a.size * 2;
			case 'sarr': return objItem_a.size * (objItem_a.stride || 41);
			case 'desc': return 12;
			case 'dyn': return objItem_a.size;
			case 'barr': return objItem_a.size;
			case 'larr': return objItem_a.size * 4;
		}
		return 0;
	}

	// Option Memory Small | CPCExpansion [maxpages] - findMemory took the values; this checks them
	function readMemory(objRec_a)
	{
		var arrMatch = String(objRec_a.value).match(/^(small|cpcexpansion)\b[ \t,]*(.*)$/i);
		var blnCpc = (objOptions.platform === 'cpc') || (objOptions.platform === 'cpcmin') || (objOptions.platform === 'cpcfw');
		var intMax = 0;

		if (!arrMatch)
		{
			arrErrors.push({ file: objRec_a.file, line: objRec_a.line, msg: 'Option Memory Small | CPCExpansion [maxpages]: ' + objRec_a.value });
			return;
		}
		if ((arrMatch[1].toLowerCase() === 'cpcexpansion') && !blnCpc)
		{
			arrErrors.push({ file: objRec_a.file, line: objRec_a.line, msg: 'Option Memory CPCExpansion is for the CPC platforms (cpc, cpcmin, cpcfw), not ' + objOptions.platform });
		}
		if (trim(arrMatch[2]).length > 0)
		{
			intMax = parseNumber(trim(arrMatch[2]));
			if ((arrMatch[1].toLowerCase() !== 'cpcexpansion') || isNaN(intMax) || (intMax < 1) || (intMax > 257))
			{
				arrErrors.push({ file: objRec_a.file, line: objRec_a.line, msg: 'Option Memory: the most pages is for CPCExpansion, 1 - 257: ' + objRec_a.value });
			}
		}
	}

	function hex4(int_a)
	{
		return '#' + ('0000' + int_a.toString(16).toUpperCase()).slice(-4);
	}

	function findTerminal(arrFiles_a)
	{
		var strResult = 'none';

		arrFiles_a.forEach(function(objFile_a)
		{
			var arrMatch = String(objFile_a.text).match(/^[ \t]*option[ \t]+terminal[ \t]+(none|vt52|ansi)\b/im);

			if (arrMatch)
			{
				strResult = arrMatch[1].toLowerCase();
			}
		});
		return strResult;
	}

	// Option Memory: the Memory class's scheme (decided before parsing: it sets
	// NTC_MEM_SMALL / NTC_MEM_CPCEXPANSION). Default: the CPC expansion RAM on the
	// CPC platforms, Small (main RAM only) elsewhere
	function findMemory(arrFiles_a)
	{
		var objResult = { scheme: ((objOptions.platform === 'cpc') || (objOptions.platform === 'cpcmin') || (objOptions.platform === 'cpcfw')) ? 'cpcexpansion' : 'small', max: 257 };

		arrFiles_a.forEach(function(objFile_a)
		{
			var arrMatch = String(objFile_a.text).match(/^[ \t]*option[ \t]+memory[ \t]+(small|cpcexpansion)\b[ \t,]*(&h[0-9a-f]+|#[0-9a-f]+|\d+)?/im);

			if (arrMatch)
			{
				objResult.scheme = arrMatch[1].toLowerCase();
				if (arrMatch[2])
				{
					objResult.max = parseNumber(arrMatch[2]);
				}
			}
		});
		return objResult;
	}

	// the source lines a pre-pass may look at: #If / #ElseIf / #Else / #End If and #Const
	// followed (with the compile's predefined names), comments and strings kept as they are
	function activeLines(strText_a)
	{
		var arrOut = [];
		var arrSkip = [];
		var objDefs = {};
		var strKey = '';

		for (strKey in objDefinesIn)
		{
			if (objDefinesIn.hasOwnProperty(strKey))
			{
				objDefs[strKey] = objDefinesIn[strKey];
			}
		}
		function value(strExpr_a)
		{
			var arrStack = [];
			var arrTokens = [];
			var intA = 0;
			var intB = 0;

			try
			{
				arrTokens = IFtoPF(strExpr_a.replace(/\bthen\b/gi, ''), []).split(' ');
			}
			catch (e)
			{
				return 0;
			}
			arrTokens.forEach(function(strToken_a)
			{
				var strUpper = strToken_a.toUpperCase();

				if (strToken_a.length === 0)
				{
					return;
				}
				if (strUpper === 'NOT')
				{
					arrStack.push(~(arrStack.pop() || 0));
				}
				else if ((strUpper === 'AND') || (strUpper === 'OR') || (strUpper === 'XOR') || (strUpper === '=') || (strUpper === '<>'))
				{
					intB = arrStack.pop() || 0;
					intA = arrStack.pop() || 0;
					arrStack.push((strUpper === 'AND') ? (intA & intB) : ((strUpper === 'OR') ? (intA | intB) : ((strUpper === 'XOR') ? (intA ^ intB) : ((strUpper === '=') ? ((intA === intB) ? -1 : 0) : ((intA !== intB) ? -1 : 0)))));
				}
				else if (/^\d+$/.test(strToken_a))
				{
					arrStack.push(parseInt(strToken_a, 10));
				}
				else
				{
					arrStack.push((strUpper === 'TRUE') ? -1 : ((objDefs[strToken_a.toLowerCase()] !== undefined) ? objDefs[strToken_a.toLowerCase()] : 0));
				}
			});
			return (arrStack.length > 0) ? arrStack[arrStack.length - 1] : 0;
		}
		function skipping()
		{
			return arrSkip.some(function(objTop_a) { return objTop_a.skip; });
		}
		String(strText_a).split(/\r?\n/).forEach(function(strLine_a, intLine_a)
		{
			var strL = strLine_a.replace(/^\s+|\s+$/g, '').toLowerCase().replace(/\s+/g, ' ');
			var arrMatch = null;
			var objTop = null;

			if ((arrMatch = strL.match(/^#(?:const|define) ([a-z_]\w*) ?=? ?(.*)$/)))
			{
				if (!skipping())
				{
					objDefs[arrMatch[1]] = value(arrMatch[2] || '1');
				}
			}
			else if ((arrMatch = strL.match(/^#if (.+?)( then)?$/)))
			{
				objTop = { skip: skipping(), done: skipping() };
				if (!objTop.skip)
				{
					objTop.skip = (value(arrMatch[1]) === 0);
					objTop.done = !objTop.skip;
				}
				arrSkip.push(objTop);
			}
			else if ((arrMatch = strL.match(/^#elseif (.+?)( then)?$/)) && (arrSkip.length > 0))
			{
				objTop = arrSkip.pop();
				if (objTop.done || skipping())
				{
					objTop.skip = true;
				}
				else
				{
					objTop.skip = (value(arrMatch[1]) === 0);
					objTop.done = !objTop.skip;
				}
				arrSkip.push(objTop);
			}
			else if ((strL === '#else') && (arrSkip.length > 0))
			{
				objTop = arrSkip.pop();
				objTop.skip = objTop.done || skipping();
				objTop.done = true;
				arrSkip.push(objTop);
			}
			else if (((strL === '#end if') || (strL === '#endif')) && (arrSkip.length > 0))
			{
				arrSkip.pop();
			}
			else if (!skipping())
			{
				arrOut.push({ text: strLine_a, line: intLine_a + 1 });
			}
		});
		return arrOut;
	}

	// a file's module name (Attribute VB_Name, else the file name), lower case
	function fileModule(objFile_a)
	{
		var arrName = String(objFile_a.text).match(/Attribute\s+VB_Name\s*=\s*"([^"]+)"/i);

		return (arrName ? arrName[1] : String(objFile_a.name).replace(/^.*[\/\\]/, '').replace(/\.\w+$/, '')).toLowerCase();
	}

	// the program's name (up to 8 letters and digits): the name option (the GUI: the project's
	// name; genbuild: the program's), else the AMSDOS name, else the main file's name
	function programName(arrFiles_a)
	{
		var strName = String(objOptions.name || objOptions.amsdos || '');
		var objMain = null;

		if (strName.length === 0)
		{
			objMain = (arrFiles_a || []).filter(function(objFile_a) { return /\.bas$/i.test(String(objFile_a.name)); })[0] || (arrFiles_a || [])[0];
			strName = objMain ? String(objMain.name).replace(/^.*[\/\\]/, '').replace(/\.\w+$/, '') : '';
		}
		strName = strName.toUpperCase().replace(/[^A-Z0-9]/g, '').substr(0, 8);
		return (strName.length > 0) ? strName : 'PROGRAM';
	}

	// Option Page "NAME" = Class, Class ... (any file; the main file by custom), Option Class
	// Overlay ["NAME"] (in a class: that class joins page NAME, by default its own name) and
	// Option Home Class = "NAME" (which copy calls from outside its pages use): the pages,
	// read before parsing because the classes get members that name their page's block
	function scanPages(arrFiles_a)
	{
		var objModules = {};
		var objHome = {};
		var arrHomes = [];

		// a page: Name (a name for the source and the lists; its file is numbered, PROGRAM.001
		// ...) or "FILE.EXT" (that file; "NAME" in quotes with no extension is a name, as before)
		function pageId(str_a)
		{
			return String(str_a).toLowerCase().replace(/[^a-z0-9_.]/g, '').replace(/\./g, '_');
		}
		function addPage(strName_a, strFile_a, intLine_a, blnQuoted_a)
		{
			var strName = String(strName_a).replace(/^\s+|\s+$/g, '');
			var blnFile = blnQuoted_a && (strName.indexOf('.') > -1);
			var arrParts = strName.toUpperCase().split('.');
			var strFile = blnFile ? (arrParts[0].replace(/[^A-Z0-9]/g, '').substr(0, 8) + '.' + arrParts.slice(1).join('').replace(/[^A-Z0-9]/g, '').substr(0, 3)) : '';
			var strId = '';

			if (blnFile && (strFile.replace(/\..*$/, '').length === 0))
			{
				arrErrors.push({ file: strFile_a, line: intLine_a, msg: 'Option Page: no file name in "' + strName + '"' });
				return null;
			}
			if (!blnFile)
			{
				strName = strName.replace(/[^A-Za-z0-9_]/g, '');
				if (strName.length === 0)
				{
					arrErrors.push({ file: strFile_a, line: intLine_a, msg: 'Option Page: no name' });
					return null;
				}
			}
			strId = pageId(blnFile ? strFile : strName);
			if (objPages[strId] === undefined)
			{
				objPages[strId] = { name: blnFile ? strFile : strName, file: strFile, id: strId, blk: 'ovl_blk_' + strId, classes: [], srcfile: strFile_a, line: intLine_a };
				arrPageOrder.push(strId);
			}
			return objPages[strId];
		}
		function addClass(objPage_a, strModule_a, strFile_a, intLine_a, blnSugar_a)
		{
			if (objPage_a.classes.indexOf(strModule_a) > -1)
			{
				if (!blnSugar_a)
				{
					arrErrors.push({ file: strFile_a, line: intLine_a, msg: 'Option Page "' + objPage_a.name + '": ' + strModule_a + ' is in it twice' });
				}
				return;
			}
			objPage_a.classes.push(strModule_a);
			objClassPages[strModule_a] = (objClassPages[strModule_a] || []).concat([objPage_a.id]);
		}

		arrFiles_a.forEach(function(objFile_a)
		{
			objModules[fileModule(objFile_a)] = objFile_a;
		});
		// Option Page lines first (all files, in order), then Option Class Overlay
		arrFiles_a.forEach(function(objFile_a)
		{
			activeLines(objFile_a.text).forEach(function(objLine_a)
			{
				var strCode = objLine_a.text.replace(/'.*$/, '');
				var arrMatch = strCode.match(/^\s*option\s+page\s+(?:"([^"]*)"|([a-z_]\w*))\s*=\s*(.*?)\s*$/i);
				var objPage = null;

				if (arrMatch)
				{
					objPage = addPage((arrMatch[1] !== undefined) ? arrMatch[1] : arrMatch[2], objFile_a.name, objLine_a.line, arrMatch[1] !== undefined);
					if (objPage === null)
					{
						return;
					}
					if (objPage.declared)
					{
						arrErrors.push({ file: objFile_a.name, line: objLine_a.line, msg: 'Option Page "' + objPage.name + '" is declared twice (the first: ' + objPage.srcfile + ' line ' + objPage.line + ')' });
						return;
					}
					objPage.declared = true;
					objPage.srcfile = objFile_a.name;
					objPage.line = objLine_a.line;
					arrMatch[3].split(',').forEach(function(strClass_a)
					{
						var strModule = strClass_a.replace(/^\s+|\s+$/g, '').toLowerCase();

						if (strModule.length === 0)
						{
							return;
						}
						if ((objModules[strModule] === undefined) || !/\.cls$/i.test(String(objModules[strModule].name)))
						{
							arrErrors.push({ file: objFile_a.name, line: objLine_a.line, msg: 'Option Page "' + objPage.name + '": no class ' + strClass_a.replace(/^\s+|\s+$/g, '') + ' in the project' });
							return;
						}
						addClass(objPage, strModule, objFile_a.name, objLine_a.line, false);
					});
				}
				else if (/^\s*option\s+page\b/i.test(strCode))
				{
					arrErrors.push({ file: objFile_a.name, line: objLine_a.line, msg: 'Option Page Name = Class, Class ... (or Option Page "FILE.EXT" = ... for a file name of your own)' });
				}
				else if ((arrMatch = strCode.match(/^\s*option\s+home\s+([a-z_]\w*)\s*=\s*(?:"([^"]*)"|([a-z_]\w*))\s*$/i)))
				{
					arrHomes.push({ module: arrMatch[1].toLowerCase(), page: pageId((arrMatch[2] !== undefined) ? arrMatch[2] : arrMatch[3]), file: objFile_a.name, line: objLine_a.line });
				}
				else if (/^\s*option\s+home\b/i.test(strCode))
				{
					arrErrors.push({ file: objFile_a.name, line: objLine_a.line, msg: 'Option Home Class = Page' });
				}
			});
		});
		arrFiles_a.forEach(function(objFile_a)
		{
			var strModule = fileModule(objFile_a);

			if (!/\.cls$/i.test(String(objFile_a.name)))
			{
				return;
			}
			activeLines(objFile_a.text).forEach(function(objLine_a)
			{
				var arrMatch = objLine_a.text.replace(/'.*$/, '').match(/^\s*option\s+class\s+overlay\s*(?:"([^"]*)"|([a-z_]\w*))?\s*$/i);
				var objPage = null;

				if (arrMatch)
				{
					objPage = addPage((arrMatch[1] !== undefined) ? arrMatch[1] : (arrMatch[2] || strModule), objFile_a.name, objLine_a.line, arrMatch[1] !== undefined);
					if (objPage !== null)
					{
						addClass(objPage, strModule, objFile_a.name, objLine_a.line, true);
					}
				}
			});
		});
		arrPageOrder.forEach(function(strId_a)
		{
			if (objPages[strId_a].classes.length === 0)
			{
				arrErrors.push({ file: objPages[strId_a].srcfile, line: objPages[strId_a].line, msg: 'Option Page "' + objPages[strId_a].name + '": no classes in it' });
			}
		});
		arrHomes.forEach(function(objHome_a)
		{
			var arrIn = objClassPages[objHome_a.module];

			if (arrIn === undefined)
			{
				arrErrors.push({ file: objHome_a.file, line: objHome_a.line, msg: 'Option Home: ' + objHome_a.module + ' is in no Option Page' });
			}
			else if (arrIn.indexOf(objHome_a.page) < 0)
			{
				arrErrors.push({ file: objHome_a.file, line: objHome_a.line, msg: 'Option Home: ' + objHome_a.module + ' is not in page ' + objHome_a.page.toUpperCase().replace(/_/g, '.') });
			}
			else
			{
				objClassPages[objHome_a.module] = [objHome_a.page].concat(arrIn.filter(function(str_a) { return str_a !== objHome_a.page; }));
			}
		});
		// the files: a page named NAME.EXT is that file; the others are numbered in order,
		// PROGRAM.001 to PROGRAM.999 (PROGRAM: the program's name), so two programs on one
		// disc never write the same page file
		(function()
		{
			var intNum = 0;
			var strProg = programName(arrFiles_a);
			var objTaken = {};

			arrPageOrder.forEach(function(strId_a)
			{
				var objPage = objPages[strId_a];

				if (objPage.file.length === 0)
				{
					intNum++;
					objPage.file = strProg + '.' + ('00' + intNum).substr(-3);
				}
				if (objTaken[objPage.file] !== undefined)
				{
					arrErrors.push({ file: objPage.srcfile, line: objPage.line, msg: 'Option Page "' + objPage.name + '": its file ' + objPage.file + ' is also page ' + objTaken[objPage.file] + '\'s' });
				}
				objTaken[objPage.file] = objPage.name;
			});
			if (intNum > 999)
			{
				arrErrors.push({ file: objPages[arrPageOrder[0]].srcfile, line: objPages[arrPageOrder[0]].line, msg: 'more than 999 numbered pages' });
			}
		})();
		if ((arrPageOrder.length > 0) && !overlayPlatform())
		{
			arrErrors.push({ file: objPages[arrPageOrder[0]].srcfile, line: objPages[arrPageOrder[0]].line, msg: 'Option Page / Option Class Overlay needs a platform that can load files: cpcfw, cpcmin or cpm (not ' + objOptions.platform + ')' });
			objPages = {};
			arrPageOrder = [];
			objClassPages = {};
			return;
		}
		// the classes: overlay kind, their buffers
		arrPageOrder.forEach(function(strId_a)
		{
			objPages[strId_a].classes.forEach(function(strModule_a)
			{
				var objHomePage = null;

				if (objClassKind[strModule_a] !== undefined)
				{
					return;
				}
				objHomePage = objPages[objClassPages[strModule_a][0]];
				objClassKind[strModule_a] = { kind: 'overlay', pages: objClassPages[strModule_a], home: objHomePage.id, file: objHomePage.file, blk: objHomePage.blk, id: objHomePage.id };
				arrOvlOrder.push(strModule_a);
				objOvlAsm[strModule_a] = [];
				objOvlVars[strModule_a] = [];
			});
		});
	}

	// Option Class Overlay: the class gets Load / Unload / Loaded / Page members (asm
	// keywords, so they stay in main memory: they work when the class isn't loaded)
	function addOverlayMembers(arrFiles_a)
	{
		return arrFiles_a.map(function(objFile_a)
		{
			var strText = String(objFile_a.text);
			var strModule = fileModule(objFile_a);
			var strBlk = '';

			if (!/\.cls$/i.test(String(objFile_a.name)) || (objClassKind[strModule] === undefined) || (objClassKind[strModule].kind !== 'overlay'))
			{
				return objFile_a;		// not a class in a page
			}
			strBlk = objClassKind[strModule].blk;		// its (home) page's block
			strText += '\n' + [
				'\' ---- overlay class members (added by the compiler)',
				'Public Function Load() As Integer', '#asm', '\t\t\tpop hl', '\t\t\tld (ovl_kres), hl', '\t\t\tld hl, ' + strBlk, '\t\t\tjp ntc_ovl_kload', '#endasm', 'End Function',
				'Public Function Unload() As Integer', '#asm', '\t\t\tpop hl', '\t\t\tld (ovl_kres), hl', '\t\t\tld hl, ' + strBlk, '\t\t\tjp ntc_ovl_kunload', '#endasm', 'End Function',
				'Public Function Loaded() As Integer', '#asm', '\t\t\tpop hl', '\t\t\tld (ovl_kres), hl', '\t\t\tld hl, ' + strBlk, '\t\t\tjp ntc_ovl_kloaded', '#endasm', 'End Function',
				'Public Function Page() As Integer', '#asm', '\t\t\tpop hl', '\t\t\tld (ovl_kres), hl', '\t\t\tld hl, ' + strBlk, '\t\t\tjp ntc_ovl_kpage', '#endasm', 'End Function',
				'Public Function LocalStart() As Integer', '#asm', '\t\t\tpop hl', '\t\t\tld de, ' + strBlk.replace('ovl_blk_', 'ovl_') + '_end + ' + strBlk.replace('ovl_blk_', 'ovl_') + '_vsize', '\t\t\tld (hl), e', '\t\t\tinc hl', '\t\t\tld (hl), d', '#endasm', 'End Function',
				'Public Function LocalSize() As Integer', '#asm', '\t\t\tpop hl', '\t\t\tld de, (#8000 - (' + strBlk.replace('ovl_blk_', 'ovl_') + '_end + ' + strBlk.replace('ovl_blk_', 'ovl_') + '_vsize)) & #FFFE', '\t\t\tld (hl), e', '\t\t\tinc hl', '\t\t\tld (hl), d', '#endasm', 'End Function',
				'Public Function LocalAlloc(ByVal size As Integer) As Integer', '#asm', '\t\t\tpop hl', '\t\t\tld e, (hl)', '\t\t\tinc hl', '\t\t\tld d, (hl)', '\t\t\tld (mem_a1), de', '\t\t\tpop hl', '\t\t\tld (mem_res), hl', '\t\t\tld hl, ' + strBlk, '\t\t\tld (ovl_lblk), hl', '\t\t\tld hl, ntc_ovl_lalloc', '\t\t\tjp mem_go', '#endasm', 'End Function',
				'Public Function LocalFree(ByVal addr As Integer) As Integer', '#asm', '\t\t\tpop hl', '\t\t\tld e, (hl)', '\t\t\tinc hl', '\t\t\tld d, (hl)', '\t\t\tld (mem_a1), de', '\t\t\tpop hl', '\t\t\tld (mem_res), hl', '\t\t\tld hl, ' + strBlk, '\t\t\tld (ovl_lblk), hl', '\t\t\tld hl, ntc_ovl_lfree', '\t\t\tjp mem_go', '#endasm', 'End Function'
			].join('\n') + '\n';
			return { name: objFile_a.name, text: strText, platform: objFile_a.platform, lines: objFile_a.lines, orig: objFile_a.orig };
		});
	}

	// overlay classes need files: AMSDOS (cpcfw, cpcmin: in RAM pages with Option Memory
	// CPCExpansion, else one overlay area at #4000) or CP/M (the overlay area)
	function overlayPlatform()
	{
		return (objOptions.platform === 'cpcfw') || (objOptions.platform === 'cpcmin') || (objOptions.platform === 'cpm');
	}

	// Option Class Overlay ["FILE"] | Interrupt rate | Interrupt Frame - checked here
	function readClassOption(objRec_a)
	{
		var strValue = String(objRec_a.value).replace(/'.*$/, '');
		var arrMatch = null;
		var strFile = '';
		var intRate = 0;

		if (!objRec_a.inclass)
		{
			arrErrors.push({ file: objRec_a.file, line: objRec_a.line, msg: 'Option Class goes in a class (.cls) file' });
			return;
		}
		if ((arrMatch = strValue.match(/^\s*resident\s*$/i)))
		{
			return;
		}
		if ((arrMatch = strValue.match(/^\s*overlay\s*(?:"([^"]*)"|[a-z_]\w*)?\s*$/i)))
		{
			// read by the pre-pass (scanPages: the class joins its page); only the platform here
			if (!overlayPlatform())
			{
				arrErrors.push({ file: objRec_a.file, line: objRec_a.line, msg: 'Option Class Overlay needs a platform that can load files: cpcfw, cpcmin or cpm (not ' + objOptions.platform + ')' });
			}
			return;
		}
		if ((arrMatch = strValue.match(/^\s*interrupt\s+(frame|\d+|share\s+\d+)\s*$/i)))
		{
			if (!objPlat.irq)
			{
				arrErrors.push({ file: objRec_a.file, line: objRec_a.line, msg: 'Option Class Interrupt needs a CPC platform: cpc, cpcmin or cpcfw (not ' + objOptions.platform + ')' });
				return;
			}
			if ((objClassKind[objRec_a.module] !== undefined) && (objMemory.scheme === 'small'))
			{
				arrErrors.push({ file: objRec_a.file, line: objRec_a.line, msg: 'Option Class Interrupt: ' + objRec_a.module + ' is in a page, and with one overlay area (Option Memory Small, cpm) its Tick would load it from disc - keep it in main RAM' });
				return;
			}
			if ((objClassKind[objRec_a.module] !== undefined) && objClassKind[objRec_a.module].isl)
			{
				arrErrors.push({ file: objRec_a.file, line: objRec_a.line, msg: 'Option Class Interrupt: given twice' });
				return;
			}
			var intShare = 0;		// Share n: a shared class, weight n (turns in the interrupts no fixed class uses)
			if (/^share/i.test(arrMatch[1]))
			{
				intShare = parseInt(arrMatch[1].replace(/^share\s+/i, ''), 10);
				intRate = -1;
				if ((intShare < 1) || (intShare > 100))
				{
					arrErrors.push({ file: objRec_a.file, line: objRec_a.line, msg: 'Option Class Interrupt Share: a weight of 1 - 100' });
					return;
				}
			}
			else
			{
				intRate = (arrMatch[1].toLowerCase() === 'frame') ? 0 : parseInt(arrMatch[1], 10);
			}
			if ((intShare === 0) && (arrMatch[1].toLowerCase() !== 'frame') && ((intRate < 1) || (intRate > 300)))
			{
				arrErrors.push({ file: objRec_a.file, line: objRec_a.line, msg: 'Option Class Interrupt: a rate of 1 - 300 times a second, Frame, or Share n' });
				return;
			}
			if (arrIslots.length >= 16)
			{
				arrErrors.push({ file: objRec_a.file, line: objRec_a.line, msg: 'Option Class Interrupt: 16 interrupt classes at most' });
				return;
			}
			if (objClassKind[objRec_a.module] !== undefined)
			{
				// a class in a page with a Tick (a driver): the Tick's call switches its page in
				objClassKind[objRec_a.module].isl = { rate: intRate, slot: arrIslots.length };
			}
			else
			{
				objClassKind[objRec_a.module] = { kind: 'interrupt', rate: intRate, slot: arrIslots.length, isl: { rate: intRate, slot: arrIslots.length } };
			}
			arrIslots.push({ module: objRec_a.module, rate: intRate, share: intShare, file: objRec_a.file, line: objRec_a.line });
			return;
		}
		arrErrors.push({ file: objRec_a.file, line: objRec_a.line, msg: 'Option Class Resident | Overlay ["FILE"] | Interrupt rate | Interrupt Frame | Interrupt Share n: ' + strValue });
	}

	// the platform's own classes (StdIO, System ...) join the project when the
	// program names them and the project has no class of that name itself
	function addPlatformClasses(arrFiles_a)
	{
		var arrResult = arrFiles_a.slice(0);
		var objClasses = (typeof NTC_PLATFORM_CLASSES !== 'undefined') ? (NTC_PLATFORM_CLASSES[objOptions.platform] || {}) : {};
		var objOwn = {};
		var strAll = '';
		var strKey = '';
		var strName = '';

		arrFiles_a.forEach(function(objFile_a)
		{
			var arrMatch = String(objFile_a.text).match(/Attribute\s+VB_Name\s*=\s*"([^"]+)"/i);

			strName = (arrMatch ? arrMatch[1] : String(objFile_a.name).replace(/^.*[\/\\]/, '').replace(/\.\w+$/, '')).toLowerCase();
			objOwn[strName] = true;
			strAll += '\n' + String(objFile_a.text).replace(/"[^"\n]*"/g, '""').replace(/'.*$/gm, '');
		});
		for (strKey in objClasses)
		{
			if (objClasses.hasOwnProperty(strKey))
			{
				strName = strKey.replace(/\.\w+$/, '').toLowerCase();
				if ((objOwn[strName] === undefined) && new RegExp('\\b' + strName + '\\b', 'i').test(strAll))
				{
					arrResult.push({ name: strKey, text: objClasses[strKey], platform: true });
				}
				else if (objOwn[strName] !== undefined)
				{
					objOwnClass[strName] = true;		// the project's own: it replaces the platform's
				}
			}
		}
		return arrResult;
	}

	function loadLibrary()
	{
		var strLib = objOptions.libtext;
		var strPlatform = objOptions.platformtext;

		if ((strLib === null) && (typeof NTC_LIB_ASM !== 'undefined'))
		{
			strLib = NTC_LIB_ASM;
		}
		strPlatform = platformText();
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
		// label -> its section, so #asm naming any library label links that section
		objLibLabelSection = {};
		arrLibOrder.forEach(function(strName_a)
		{
			objLibSections[strName_a].labels.forEach(function(strLabel_a)
			{
				if (objLibLabelSection[strLabel_a] === undefined)
				{
					objLibLabelSection[strLabel_a] = strName_a;
				}
			});
		});
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

	// the platform's interrupt work is started in normal mode (;@irq 1), or only when the
	// program uses the Interrupt statement or interrupt classes (;@irq 2: cpcfw, where the
	// firmware does the rest and the fast ticker's block costs RAM)
	function irqNeeded()
	{
		if (!blnNormalUsed || !objPlat.irq)
		{
			return false;
		}
		return (objPlat.irq !== 2) || (arrIslots.length > 0) || (Object.keys(objHookProcs).length > 0);
	}

	function linkLibrary(objUsedT_a, objUsedN_a, blnIrq_a, blnRamOnly_a)
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
		if ((objOptions.library === 'all') || (objOptions.library === 'allmodes'))
		{
			for (intI = 0; intI < arrOrder.length; intI++)
			{
				arrQueue.push({ name: arrOrder[intI], mode: 't' });
				if (objOptions.library === 'allmodes')
				{
					arrQueue.push({ name: arrOrder[intI], mode: 'n' });		// both modes (measuring a ROM)
				}
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
			if ((objItem === undefined) || (blnRamOnly_a && !objSection.ramonly))
			{
				continue;		// (Library: ROM - only the sections the ROM hasn't got)
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

	// the flavour preprocessor first: every file as VB5 text (ntcPrep)
	var objPrep = ntcPrep(input_a, objOptions);
	var arrFiles = objPrep.files;
	var objOrigName = {};		// translated file name -> the name the user gave (messages)
	var intI = 0;
	var intJ = 0;
	var intValue = 0;
	var objRec = null;
	var strCur = '';

	arrFiles.forEach(function(objFile_a) { if (objFile_a.orig) { objOrigName[objFile_a.name] = objFile_a.orig; } });
	arrWarnings = arrWarnings.concat(objPrep.warnings);		// a flavour's (Locomotive: the lines left out)
	if (objPrep.errors.length > 0)
	{
		return { asm: '', libasm: '', layout: [], errors: objPrep.errors, warnings: objPrep.warnings, xref: [], map: '', procs: [], vbfiles: arrFiles, stats: { threadbytes: 0, keywords: 0, variables: 0, temps: 0, stemps: 0, normal: false, start: 'n' } };
	}
	readPlatform();
	if ((objOptions.org === null) || (objOptions.org === undefined))
	{
		objOptions.org = objPlat.org;
	}
	arrFiles = addPlatformClasses(arrFiles);
	objMemory = findMemory(arrFiles);
	objDefinesIn = { ntc: -1 };
	objDefinesIn['ntc_' + String(objOptions.platform).toLowerCase()] = -1;	// #If NTC_CPM Then ...
	strTerminal = findTerminal(arrFiles);
	objDefinesIn['ntc_mem_' + objMemory.scheme] = -1;		// #If NTC_MEM_SMALL Then ... (and @if: library sections)
	if (strTerminal !== 'none')
	{
		objDefinesIn['ntc_term_' + strTerminal] = -1;
		objDefinesIn.ntc_term_pos = -1;
	}
	scanPages(arrFiles);
	arrFiles = addOverlayMembers(arrFiles);
	objMemory = findMemory(arrFiles);
	blnMemoryUsed = arrFiles.some(function(objFile_a) { return /(^|[\/\\])(memory|list)\.cls$/i.test(String(objFile_a.name)); });
	if (strTerminal !== 'none')
	{
		objDefinesIn['ntc_term_' + strTerminal] = -1;		// #If NTC_TERM_VT52 Then ...
		objDefinesIn.ntc_term_pos = -1;						// a terminal that can position and clear
	}
	objParse = ntcParse(arrFiles, objDefinesIn);
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
			else if (objRec.what === 'noturbo')
			{
				blnNoTurbo = true;
				objNoTurboLine = objRec;
			}
			else if (objRec.what === 'comparetext')
			{
				objCompareText[objRec.module] = true;
			}
			else if (objRec.what === 'vbprint')
			{
				blnVBPrint = true;
			}
			else if ((objRec.what === 'terminal') && (objOptions.platform !== 'cpm'))
			{
				arrWarnings.push({ file: objRec.file, line: objRec.line, msg: 'Option Terminal is for CP/M - no effect on ' + objOptions.platform });
			}
			else if (objRec.what === 'base')
			{
				objBase[objRec.module] = objRec.value;
			}
			else if (objRec.what === 'reserve')
			{
				readReserve(objRec);
			}
			else if (objRec.what === 'memory')
			{
				readMemory(objRec);
			}
			else if (objRec.what === 'class')
			{
				readClassOption(objRec);
			}
			else if (objRec.what === 'library')
			{
				if (/^rom$/i.test(objRec.value))
				{
					objOptions.library = 'rom';		// the keywords in the platform's ROM (cpcfw: NTCFW.ROM)
				}
				else if (/^ram$/i.test(objRec.value))
				{
					if (objOptions.library === 'rom')
					{
						objOptions.library = 'used';
					}
				}
				else
				{
					arrErrors.push({ file: objRec.file, line: objRec.line, msg: 'Option Library: ROM or RAM - ' + objRec.value });
				}
			}
			else if (objRec.what === 'romenable')
			{
				readRomEnable(objRec);
			}
			else if (objRec.what === 'stack')
			{
				intValue = parseNumber(objRec.value);
				if (isNaN(intValue) || (intValue < 0) || (intValue > 65535))
				{
					arrErrors.push({ file: objRec.file, line: objRec.line, msg: 'Option Stack needs an address, 0-&HFFFF (the stack grows down from it): ' + objRec.value });
				}
				else
				{
					objStack = { addr: intValue, file: objRec.file, line: objRec.line };
					if (((objOptions.platform === 'cpcfw') || (objOptions.platform === 'cpcmin')) && (intValue > 0xA600) && (intValue < 0xC000))
					{
						arrWarnings.push({ file: objRec.file, line: objRec.line, msg: 'Option Stack ' + hex4(intValue) + ': on ' + objOptions.platform + ' #A600-#BFFF is the firmware\'s and AMSDOS\'s RAM' });
					}
				}
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

	// Private Paged: only in an overlay class
	for (strCur in objEl)
	{
		if (objEl.hasOwnProperty(strCur) && objEl[strCur].paged && (objOvlVars[objEl[strCur].module] === undefined))
		{
			arrErrors.push({ file: objEl[strCur].file || '', line: objEl[strCur].line || 0, msg: 'Paged variables (' + objEl[strCur].id + ') go in a class in a page (Option Page / Option Class Overlay)' });
		}
	}
	strCur = '';

	// Option NoTurbo: normal mode from the start, whatever Option Turbo / the turbo setting say
	if (blnNoTurbo)
	{
		if (strStartMode === 't')
		{
			arrWarnings.push({ file: objNoTurboLine.file, line: objNoTurboLine.line, msg: 'Option NoTurbo: the program starts in normal mode (Option Turbo / the turbo setting are ignored)' });
		}
		strStartMode = 'n';
	}

	// Sub Main runs after the top level code
	if (find('main') !== null && (find('main').etype === 'proc') && (find('main').kind === 'sub'))
	{
		arrMainRecs.push({ k: 'call', name: 'main', args: [], explicit: false, raw: 'main', file: arrFiles[0].name, line: 0, module: strFirstModule, proc: '', inclass: false });
	}
	findAsmKeywords();

	expandUdts();
	intStrMax = findStrMax();
	if (objOptions.library === 'rom')
	{
		intStrMax = 255;		// Library: ROM - the ROM's buffers are built for 255
	}

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
		objTmpSize = {};
		objTmpBase = {};
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
	decideTempBases();
	decideLocalCalls();

	// pass 2 - code
	compilePass(2);

	var arrGlyphCodes = [];
	var arrGlyphLine = [];
	var strText = '';
	var intBytes = 0;
	var intKeywords = 0;
	var arrAsm = [];
	var arrAsmMain = [];
	var arrBss = [];
	var intBss = 0;			// arrays: addresses after the program (ntc_end on), cleared at start
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
	arrAsm.push('; platform: ' + objOptions.platform + ((objPlat.name !== objOptions.platform) ? ' (' + objPlat.name + ')' : '') + ', starts in ' + ((strStartMode === 't') ? 'turbo' : 'normal') + ' mode');
	arrAsm.push('; ============================================================');
	arrAsm.push('');
	if (String(objOptions.amsdos || '').length > 0)
	{
		arrAsm.push(strIndent + 'DEVICE AMSTRADCPC6128\t\t; for SAVEAMSDOS at the end');
	}
	if (String(objOptions.org).replace(/\s/g, '').length > 0)
	{
		arrAsm.push(strIndent + 'org ' + objOptions.org);
		arrAsm.push('');
	}
	arrAsm.push('NTC_TERM\tequ ' + ({ none: 0, vt52: 1, ansi: 2 })[strTerminal] + '\t\t; Option Terminal: 0 none, 1 VT52, 2 ANSI (CP/M)');
	arrAsm.push('NTC_STRMAX\tequ ' + intStrMax + '\t\t; the longest string (library buffers, temps)');
	arrAsm.push('NTC_MEMBANKS\tequ ' + Math.max(0, Math.min(64, Math.floor((Math.min(257, Math.max(1, objMemory.max || 257)) - 1) / 4))) + '\t\t; Option Memory: the most 64K banks the Memory class looks for');
	arrAsm.push('NTC_ROMENABLE\tequ ' + ((arrRomEnable !== null) ? 1 : 0) + '\t\t; Option RomEnable (cpcfw, cpcmin): the start code starts the ROMs');
	arrAsm.push('NTC_ROMLIB\tequ ' + ((objOptions.library === 'rom') ? 1 : 0) + '\t\t; 1 = the library is the keyword ROM (Library: ROM; ntcRomAsm builds it)');
	arrAsm.push('');
	// the options in a fixed order, wherever they are in the source: the stack first (the
	// ROM start runs on it), then the ROMs, then the program
	arrAsm.push('ntc_start:');
	arrAsm.push(strIndent + 'di');
	if (objOptions.library === 'rom')
	{
		arrAsm.push(strIndent + 'call ntc_rj_find\t\t; Library: ROM - find the ROM, patch the jump block');
		arrAsm.push(strIndent + 'jr nc, ntc_rj_ok');
		arrAsm.push(strIndent + 'ei');
		arrAsm.push(strIndent + 'ret\t\t\t\t; no ROM (the message is shown): back to the caller');
		arrAsm.push('ntc_rj_ok:');
		arrAsm.push(strIndent + 'di\t\t\t\t; (KL ROM SELECT lets interrupts in again)');
		arrAsm.push(strIndent + 'ld hl, ntc_rj_exit');
		arrAsm.push(strIndent + 'push hl\t\t\t; End comes back here: the caller\'s ROM selection again');
	}
	if (objStack !== null)
	{
		arrAsm.push(strIndent + 'ld (ntc_ssp), sp\t\t; Option Stack: the caller\'s stack, for End');
		arrAsm.push(strIndent + 'ld sp, ' + objStack.addr + '\t\t; the stack from ' + hex4(objStack.addr) + ' down');
		arrAsm.push(strIndent + 'ld hl, ntc_sback');
		arrAsm.push(strIndent + 'push hl\t\t\t; End returns here, then to the caller');
		arrAsm.push(strIndent + 'ASSERT (' + objStack.addr + ' <= ntc_start) || (' + objStack.addr + ' >= ntc_free + 64), "Option Stack ' + hex4(objStack.addr) + ' is in the program or its arrays, or less than 64 bytes above their end (' + objStack.file + ' line ' + objStack.line + ')"');
	}
	else if (String(objPlat.stack).length > 0)
	{
		arrAsm.push(strIndent + 'ld sp, ' + objPlat.stack + '\t\t; the platform\'s own real stack');
	}
	arrAsm.push(strIndent + 'ld (ntc_csp), sp');
	if ((objOptions.platform === 'cpm') && (objProcModes['system.commandline'] !== undefined))
	{
		arrAsm.push(strIndent + 'call ntc_cmdsave\t\t; System.CommandLine: the command tail, before anything overwrites it');
	}
	if (arrRomEnable !== null)
	{
		// RUN" of a binary resets the firmware: the background ROMs (AMSDOS ...) are gone.
		// A program that was CALLed still has them (CAS IN OPEN is AMSDOS's far call, #DF)
		arrAsm.push(strIndent + 'ld a, (#BC77)\t\t; Option RomEnable: start the ROMs again');
		arrAsm.push(strIndent + 'cp #DF\t\t\t; AMSDOS has the cassette calls: they are running');
		arrAsm.push(strIndent + 'jr z, ntc_roms_on');
		arrAsm.push(strIndent + 'ei');
		arrAsm.push(strIndent + 'ld de, ntc_free\t\t; the lowest address the ROMs may use (above the arrays)');
		arrAsm.push(strIndent + 'ld hl, #ABFF\t\t; the highest (as usual for AMSDOS: it takes about #A700-#ABFF)');
		if (arrRomEnable[0] === 'all')
		{
			arrAsm.push(strIndent + 'call #BCCB\t\t; KL ROM WALK: every background ROM');
		}
		else
		{
			arrRomEnable.forEach(function(intRom_a)
			{
				arrAsm.push(strIndent + 'ld c, ' + intRom_a);
				arrAsm.push(strIndent + 'call #BCCE\t\t; KL INIT BACK: ROM ' + intRom_a + ' (DE / HL come back as the new limits)');
			});
		}
		arrAsm.push(strIndent + 'di');
		arrAsm.push(strIndent + 'ASSERT ntc_free <= #A600, "Option RomEnable: the program and its arrays must end below #A600 (the ROMs take their RAM from #ABFF down)"');
		arrAsm.push('ntc_roms_on:');
	}
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
	if (arrIslots.length > 0)
	{
		arrAsm.push(strIndent + '; Option Class Interrupt: the classes\' Tick subs, run at safe points (normal mode)');
		arrIslots.forEach(function(objSlot_a, intSlot_a)
		{
			if (objSlot_a.tick === undefined)
			{
				return;
			}
			if (objSlot_a.share)
			{
				arrAsm.push(strIndent + 'ld hl, #8000 + ' + objSlot_a.share + '\t\t; ' + objSlot_a.module + ': shared, weight ' + objSlot_a.share + ' (turns in the interrupts no fixed class uses)');
				arrAsm.push(strIndent + 'ld (ntc_isl + ' + (intSlot_a * 8 + 2) + '), hl');
				arrAsm.push(strIndent + 'ld hl, 0');
				arrAsm.push(strIndent + 'ld (ntc_isl + ' + (intSlot_a * 8) + '), hl');
				arrAsm.push(strIndent + 'ld hl, ' + procLabel(objSlot_a.tick, 'n') + '_c');
				arrAsm.push(strIndent + 'ld (ntc_isl + ' + (intSlot_a * 8 + 6) + '), hl');
				return;
			}
			arrAsm.push(strIndent + 'ld hl, ' + ((objSlot_a.rate === 0) ? 0 : Math.max(1, Math.round(300 / objSlot_a.rate))) + '\t\t; ' + objSlot_a.module + ': ' + ((objSlot_a.rate === 0) ? 'every frame' : ('every ' + Math.max(1, Math.round(300 / objSlot_a.rate)) + ' interrupts')));
			arrAsm.push(strIndent + 'ld (ntc_isl + ' + (intSlot_a * 8 + 2) + '), hl');
			arrAsm.push(strIndent + 'ld hl, ' + (((objSlot_a.rate === 0) ? 0 : Math.max(1, Math.round(300 / objSlot_a.rate))) + intSlot_a + 1) + '\t\t\t; the first after one period (+ the slot, so they take turns)');
			arrAsm.push(strIndent + 'ld (ntc_isl + ' + (intSlot_a * 8) + '), hl');
			arrAsm.push(strIndent + 'ld hl, ' + procLabel(objSlot_a.tick, 'n') + '_c');
			arrAsm.push(strIndent + 'ld (ntc_isl + ' + (intSlot_a * 8 + 6) + '), hl');
		});
		arrAsm.push(strIndent + 'ld a, ' + arrIslots.length);
		arrAsm.push(strIndent + 'ld (ntc_isln), a');
		if (arrIslots.some(function(o_a) { return o_a.share; }))
		{
			arrAsm.push(strIndent + 'ld a, ' + arrIslots.filter(function(o_a) { return o_a.share; }).length);
			arrAsm.push(strIndent + 'ld (ntc_islshn), a\t\t; shared classes');
		}
		arrAsm.push(strIndent + ((objOptions.library === 'rom') ? 'ld hl, (ntc_isl_tick + 1)\t; (Library: ROM: its address in the ROM - the jump block, low in RAM, is hidden by the lower ROM in the interrupt)' : 'ld hl, ntc_isl_tick'));
		arrAsm.push(strIndent + 'ld (ntc_irqv), hl\t\t; the interrupt handler counts for them');
		objUsedT['ntc_islots'] = true;
		if (strStartMode === 't')
		{
			arrWarnings.push({ file: arrIslots[0].file, line: arrIslots[0].line, msg: 'Option Class Interrupt: Tick only runs in normal mode, and this program starts in turbo mode' });
		}
	}
	if (irqNeeded())
	{
		arrAsm.push(strIndent + 'ld ix, ntc_go');
		arrAsm.push(strIndent + 'jp ntc_plat_irqon\t\t; interrupt handler for normal mode');
		arrAsm.push('ntc_go:');
	}
	arrAsm.push(strIndent + 'ld sp, main_thread');
	arrAsm.push(strIndent + 'ret');
	if (objStack !== null)
	{
		arrAsm.push('ntc_sback:\t\t\t; End with Option Stack: back to the caller\'s stack');
		arrAsm.push(strIndent + 'ld sp, (ntc_ssp)');
		arrAsm.push(strIndent + 'ret');
		arrAsm.push('ntc_ssp:\t\tdw 0');
	}
	arrAsm.push('');
	arrAsm.push('; ============================================================');
	arrAsm.push('; Main Thread');
	arrAsm.push('; ============================================================');
	arrAsm.push('');
	arrAsm.push('main_thread:');
	for (intI = 0; intI < arrOut.length; intI++)
	{
		if (objPlat.scrinit && (arrOut[intI].t === 'kw') && (NTC_SCREEN_KEYWORDS.indexOf(arrOut[intI].kw) > -1))
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

	if (arrDecl.some(function(objItem_a) { return bssSize(objItem_a) > 0; }))
	{
		arrAsm.push(strIndent + 'dw kw_bssinit, ntc_bss, ntc_bss_size\t\t; the arrays: do they fit, clear them');
		objUsedT['kw_bssinit'] = true;
		intBytes += 6;
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
		else if (objItem.t === 'ovl')
		{
			// an overlay class's procedure: its thread goes into the overlay (built at #4000)
			arrAsmMain = arrAsm;
			arrAsm = objOvlAsm[objItem.name];
		}
		else if (objItem.t === 'ovlend')
		{
			arrAsm = arrAsmMain;
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
					else if (objLibLabelSection[strWord_a] !== undefined)
					{
						objUsedT[objLibLabelSection[strWord_a]] = true;
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
		if ((objPagedLabel[objItem.label] !== undefined) && (objOvlVars[objPagedLabel[objItem.label]] !== undefined))
		{
			objOvlVars[objPagedLabel[objItem.label]].push(objItem);		// in the overlay's page
			continue;
		}
		if (objItem.kind === 'str')
		{
			arrAsm.push(strIndent + 'db ' + objItem.size + '\t\t\t; capacity');
			arrAsm.push(objItem.label + ':' + strIndent + 'ds ' + (objItem.size + 1));
		}
		else if (objItem.kind === 'strfix')
		{
			arrAsm.push(strIndent + 'db ' + objItem.size + '\t\t\t; capacity');
			arrAsm.push(objItem.label + ':' + strIndent + 'ds ' + objItem.size + ', 32\t\t; String * ' + objItem.size + ' (n spaces)');
			arrAsm.push(strIndent + 'db 0');
		}
		else if (bssSize(objItem) > 0)
		{
			arrBss.push(objItem);		// after the program, not in its file
		}
		else if (objItem.kind === 'adesc')
		{
			arrAsm.push(objItem.label + ':' + strIndent + 'dw ' + objItem.words.join(', ') + '\t\t; array as an argument');
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
		arrAsm.push(strIndent + 'db ' + intStrMax + '\t\t\t; capacity');
		arrAsm.push('stmp' + intI + ':' + strIndent + 'ds ' + (intStrMax + 1));
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
	var intRomAt = -1;		// Library: ROM - where the jump block goes (made when the program is complete)
	if (objOptions.library === 'rom')
	{
		intRomAt = arrAsm.length;
		arrAsm.push('');
		// sections marked @ramonly aren't in the ROM: the program has the ones it uses (the
		// ROM's routines and variables they use come through the jump block, as the program's)
		strLibAsm = linkLibrary(objUsedT, objUsedN, irqNeeded(), true);
		if (strLibAsm.replace(/\s/g, '').length > 0)
		{
			arrAsm.push('; (not in the ROM - the library sections this program uses that the ROM leaves out)');
			arrAsm.push(strLibAsm);
		}
	}
	else if (objOptions.library !== 'none')
	{
		if (arrOvlOrder.length > 0)
		{
			objUsedT['ntc_ovl'] = true;		// the overlay call stubs use it
		}
		strLibAsm = linkLibrary(objUsedT, objUsedN, irqNeeded());
		arrAsm.push(strLibAsm);
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

	var objPageOut = (arrPageOrder.length > 0) ? composePages() : null;
	if (objPageOut !== null)
	{
		arrAsm.push('');
		arrAsm.push('; pages (Option Page / Option Class Overlay): the RAM page each is loaded in (0 = not loaded),');
		arrAsm.push('; the end of its code and the size of its page variables, its file and its name');
		arrPageOrder.forEach(function(strId_a)
		{
			arrAsm.push(objPages[strId_a].blk + ':\tdw 0, ovl_' + strId_a + '_end, ovl_' + strId_a + '_vsize');
			arrAsm.push(strIndent + 'db "' + objPages[strId_a].file + '", 0, "' + ((objPages[strId_a].name !== objPages[strId_a].file) ? objPages[strId_a].name : '') + '", 0\t; its file, its name (for the messages)');
		});
		if (objPageOut.tables.length > 0)
		{
			arrAsm.push('; classes in more than one page: for each procedure, its copies (the home first): page, body');
			arrAsm = arrAsm.concat(objPageOut.tables);
			objUsedT['ntc_ovl'] = true;
		}
	}
	if ((arrOvlOrder.length > 0) && !arrReserve.some(function(objRes_a) { return (objRes_a.start <= 0x4000) && (objRes_a.start + objRes_a.size >= 0x8000); }))
	{
		arrReserve.push({ start: 0x4000, size: 0x4000, file: 'overlay classes', line: 0 });		// the window / overlay area
	}
	if ((blnMemoryUsed || (arrOvlOrder.length > 0)) && (objMemory.scheme === 'small'))
	{
		arrAsm.push('');
		arrAsm.push('ntc_rsvtab:\t\t\t\t; Option Reserve starts (the Memory class\'s heap stops at them), 0 ends');
		arrAsm.push(strIndent + 'dw ' + arrReserve.map(function(objRes_a) { return String(objRes_a.start); }).concat(['0']).join(', '));
	}
	arrAsm.push('');
	arrAsm.push('ntc_end:\t\t\t\t; the end of the program (and of its file)');
	arrAsm.push('; arrays: after the program, not in its file - kw_bssinit checks they fit and clears them');
	arrAsm.push('ntc_bss\t\tequ ntc_end');
	intBss = 0;
	arrBss.forEach(function(objItem_a)
	{
		arrAsm.push(objItem_a.label + '\t\tequ ntc_bss + ' + intBss + '\t\t; ' + bssSize(objItem_a) + ' bytes');
		intBss += bssSize(objItem_a);
	});
	arrAsm.push('ntc_bss_size\tequ ' + intBss);
	arrAsm.push('ntc_free\tequ ntc_bss + ntc_bss_size\t; the first free byte (heap, Memory tables)');
	if (arrReserve.length > 0)
	{
		arrAsm.push('; Option Reserve: the program and its arrays (ntc_start .. ntc_free) must stay out of these');
		arrReserve.forEach(function(objRes_a)
		{
			var strEnd = hex4(objRes_a.start + objRes_a.size - 1);

			arrAsm.push(strIndent + 'ASSERT (ntc_free <= ' + objRes_a.start + ') || (ntc_start >= ' + (objRes_a.start + objRes_a.size) + '), "the program (or its arrays) reaches into Option Reserve ' + hex4(objRes_a.start) + '-' + strEnd + ' (' + objRes_a.file + ' line ' + objRes_a.line + ')"');
		});
	}
	if (String(objOptions.amsdos || '').length > 0)
	{
		// an AMSDOS file (128 byte header): RUN"name loads it at the org and starts it
		arrAsm.push(strIndent + 'SAVEAMSDOS "' + String(objOptions.amsdos).toUpperCase().replace(/[^A-Z0-9]/g, '').substr(0, 8) + '.BIN", ntc_start, ntc_end - ntc_start, ntc_start');
	}
	var strLen = '';
	if (arrOvlOrder.length > 0)
	{
		arrAsm.push(strIndent + 'ASSERT (ntc_free <= #4000) || (ntc_start >= #8000), "overlay classes: the program and its arrays must stay out of #4000-#7FFF (the window they run in)"');
		arrPageOrder.forEach(function(strId_a)
		{
			var objKind = objPages[strId_a];

			arrAsm.push('');
			arrAsm.push('; ============================================================');
			arrAsm.push('; Page ' + objKind.name + ' -> ' + objKind.file + ': ' + objKind.classes.join(', ') + ' - threads built to run at #4000');
			arrAsm.push('; (a RAM page, or the overlay area); their variables are in the program, but for');
			arrAsm.push('; Private Paged ones (after the code). Written as its own file.');
			arrAsm.push('; ============================================================');
			// an AMSDOS build: a binary file with an AMSDOS header (AMSDOS takes a file without
			// one for ASCII text, and CAS IN DIRECT won't load it); else the plain bytes
			if ((String(objOptions.amsdos || '').length === 0) && (objOptions.platform !== 'cpm'))
			{
				// written here with its AMSDOS header: binary (type 2), loads at #4000
				strLen = '(ovl_' + objKind.id + '_end - ovl_' + objKind.id + '_start)';
				arrAsm.push(strIndent + 'OUTPUT "' + objKind.file + '"');
				arrAsm.push(strIndent + 'ORG #4000 - 128\t\t; the AMSDOS header');
				arrAsm.push(strIndent + 'ds 18');
				arrAsm.push(strIndent + 'db 2\t\t\t; binary');
				arrAsm.push(strIndent + 'dw 0, #4000\t\t; (block length), load address');
				arrAsm.push(strIndent + 'db 0');
				arrAsm.push(strIndent + 'dw ' + strLen + ', #4000\t; length, run address');
				arrAsm.push(strIndent + 'ds 36');
				arrAsm.push(strIndent + 'dw ' + strLen + '\t; the real length (3 bytes)');
				arrAsm.push(strIndent + 'db 0');
				arrAsm.push(strIndent + 'dw 2 + #40 + #40 + 2 * ((' + strLen + ' & 255) + (' + strLen + ' >> 8))\t; checksum of bytes 0-66');
				arrAsm.push(strIndent + 'ds 59');
			}
			if (objOptions.platform === 'cpm')
			{
				arrAsm.push(strIndent + 'OUTPUT "' + objKind.file + '"');		// CP/M: the plain bytes
			}
			arrAsm.push(strIndent + 'ORG #4000');
			arrAsm.push('ovl_' + objKind.id + '_start:');
			arrAsm = arrAsm.concat(objPageOut.pages[strId_a]);
			arrAsm.push('ovl_' + objKind.id + '_end:\t\t; the end of its file; page variables (cleared on loading) follow');
			arrAsm = arrAsm.concat(objPageOut.vars[strId_a]);
			arrAsm.push(strIndent + 'ASSERT ovl_' + objKind.id + '_end + ovl_' + objKind.id + '_vsize <= #8000, "page ' + objKind.name + ' (' + objKind.classes.join(', ') + ') is more than 16K (code and page variables)"');
			arrAsm = arrAsm.concat(objPageOut.display[strId_a]);
			if ((String(objOptions.amsdos || '').length === 0) || (objOptions.platform === 'cpm'))
			{
				arrAsm.push(strIndent + 'OUTEND');
			}
			else
			{
				arrAsm.push(strIndent + 'SAVEAMSDOS "' + objKind.file + '", ovl_' + objKind.id + '_start, ovl_' + objKind.id + '_end - ovl_' + objKind.id + '_start, #4000');
			}
		});
	}

	if (intRomAt >= 0)
	{
		arrAsm[intRomAt] = ntcRomJumpBlock(objOptions.platform, arrAsm, (objPageOut !== null), (arrRomEnable !== null), arrErrors).join('\n');
	}

	var arrLayout = [];
	if (objPageOut !== null)
	{
		// the build stamp: a hash of the whole program (same source, same stamp)
		(function()
		{
			var strAll = arrAsm.join('\n');
			var intHash = 0xFFFF;		// CRC-16 (CCITT) of the program's text
			var intI = 0;
			var intB = 0;

			for (intI = 0; intI < strAll.length; intI++)
			{
				intHash ^= (strAll.charCodeAt(intI) & 0xFF) << 8;
				for (intB = 0; intB < 8; intB++)
				{
					intHash = (intHash & 0x8000) ? (((intHash << 1) ^ 0x1021) & 0xFFFF) : ((intHash << 1) & 0xFFFF);
				}
			}
			arrAsm.push('');
			arrAsm.push('NTC_STAMP\tequ #' + ('000' + intHash.toString(16).toUpperCase()).substr(-4) + '\t\t; the build stamp: the first word of every page file');
		})();
		// the layout: what is in each page (sizes counted from the threads; the assembler's
		// DISPLAY lines give the exact ones), and the classes in main RAM that pages call
		objPageOut.layout.forEach(function(objPage_a)
		{
			arrLayout.push('Page ' + objPage_a.page + ' (' + objPage_a.file + '): ' + objPage_a.classes.map(function(objClass_a)
			{
				return objClass_a.module + ' ' + objClass_a.bytes + (objClass_a.copy ? ' (copy)' : (objClass_a.home ? ' (home)' : ''));
			}).join(', ') + (objPage_a.vars ? '; paged variables ' + objPage_a.vars : '') + '; about ' + Math.max(0, 16384 - objPage_a.bytes) + ' bytes free');
		});
		(function()
		{
			var objMain = {};

			arrScanProcCalls.forEach(function(objCall_a)
			{
				var objFrom = objEl[objCall_a.from];
				var objTo = objEl[objCall_a.to];

				if (objFrom && objTo && objClassPages[objFrom.module] && !objClassPages[objTo.module] && !objTo.asmkw && (objTo.module !== strFirstModule) && (objParse.procs.some(function(objP_a) { return objP_a.full === objTo.full; })))
				{
					objMain[objTo.module] = true;
				}
			});
			if (Object.keys(objMain).length > 0)
			{
				arrLayout.push('Main RAM, called from pages: ' + Object.keys(objMain).join(', '));
			}
		})();
	}

	// messages name the files the user gave (a JS file, not its VB5 text)
	[arrErrors, arrWarnings, arrXref].forEach(function(arrList_a)
	{
		arrList_a.forEach(function(objE_a) { if (objE_a.file && (objOrigName[objE_a.file] !== undefined)) { objE_a.file = objOrigName[objE_a.file]; } });
	});
	return {
		asm: arrAsm.join('\n'),
		libasm: strLibAsm,
		vbfiles: arrFiles,
		layout: arrLayout,
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

// ============================================================
// ntcRomAsm - the keyword library as a CPC ROM (Library: ROM). The whole library for
// the platform (both modes) goes into an upper ROM at #C000 with a standard background ROM
// header; its variables go to fixed RAM (initialised ones copied from the ROM by its patcher,
// the rest cleared). A program built with library 'rom' keeps a jump block of the library
// labels it uses, each "label: jp <number>", and at its start finds the ROM and calls the
// ROM's patcher with the block: the numbers become the ROM's addresses. Numbers come from
// the registry (src/asm/ntc_rom_<platform>.txt): permanent, append only - so a ROM can be
// rebuilt and changed inside as much as needed, and programs built before keep working.
// Variables and constants keep fixed addresses / values (the registry records them).
//   strPlatform_a: cpcfw (cpcmin, cpc later)
//   strReg_a: the registry text ('' = none yet)
// Returns { asm, errors, symbols: [ { name, kind } ] (in registry order, new ones last) }
// ============================================================
// library labels the compiler's own code uses (besides every section's name and what the
// platform classes' #asm blocks name): what a ROM must export
var NTC_ROM_RUNTIME = ['kw_absv', 'kw_aget', 'kw_aget8', 'kw_bssinit', 'kw_callp', 'kw_callv', 'kw_stop', 'kw_irq', 'kw_turbo_off', 'kw_turbo_on',
	'mem_a1', 'mem_go', 'mem_res', 'mem_sel', 'ntc_csp', 'ntc_font', 'ntc_irqv', 'ntc_isl', 'ntc_isl_tick', 'ntc_isln', 'ntc_islshn', 'ntc_next', 'ntc_ovl_body',
	'ntc_ovl_enter', 'ntc_ovl_enterc', 'ntc_ovl_ret', 'ntc_ovl_kload', 'ntc_ovl_kloaded', 'ntc_ovl_kpage', 'ntc_ovl_kunload', 'ntc_ovl_lalloc', 'ntc_ovl_lc',
	'ntc_ovl_lfree', 'ntc_plat_irqon', 'ntc_xn', 'ovl_kres', 'ovl_lblk', 'ntc_nmode', 'ntc_isldue', 'ntc_hookpend', 'ntc_hookon', 'ntc_hookset', 'ntc_hook',
	'ntc_ip', 'ntc_ticks', 'ntc_mode', 'ntc_ivar', 'ntc_v_free', 'ntc_v_start', 'ntc_v_stamp', 'ntc_v_romen', 'ntc_v_rom', 'ntc_v_romold', 'ntc_rampt',
	'ntc_plat_exit', 'ntc_plat_memtop', 'ntc_fwcall', 'ntc_smode', 'ntc_gsp', 'ntc_gstack_top', 'gfx_begin', 'gfx_end'];
var NTC_ROM_DATA = 0x8800;		// the ROM's initialised variables (and its RAM code): #8800 - #93FF
var NTC_ROM_BSS = 0x9400;		// the rest of its variables (cleared): #9400 - #A5EF
var NTC_ROM_END = 0xA5F0;		// (#A5F0: the cpcfw fast ticker block)

// ============================================================
// ntcPrep - the flavour preprocessor: every file as VB5 text for the one parser and compiler.
// input_a: one text or [{ name, text }] (as ntcCompile); objOptions_a.flavour: the default
// for files that don't say (a file's first line "Option Flavour JS" / "//# Option Flavour JS"
// wins; a .js name means js; else vb5). Returns { files: [{ name, text, lines, orig }], errors }:
// lines = the source line of each VB line (messages), orig = the name the user gave.
// The flavours come from a factory (ntcFlavours): one function each, (file, options) ->
// { text, lines, cls, errors }; vb5 passes the text through.
// ============================================================
function ntcFlavours()
{
	return {
		vb5: function(objFile_a)
		{
			// the Option Flavour line itself is the preprocessor's: blanked (the lines stay put)
			return { text: String(objFile_a.text).replace(/^(\s*)(?:'#\s*)?option\s+flavour\b.*$/im, '$1'), errors: [] };
		},
		js: (typeof ntcFlavourJs === 'function') ? ntcFlavourJs : undefined,
		locomotive: (typeof ntcFlavourLoco === 'function') ? ntcFlavourLoco : undefined
	};
}

function ntcPrep(input_a, objOptions_a)
{
	var objOptions = objOptions_a || {};
	var arrIn = (typeof input_a === 'string') ? [{ name: '', text: input_a }] : input_a;
	var objFlavours = ntcFlavours();
	var arrFiles = [];
	var arrErrors = [];
	var arrWarnings = [];

	arrIn.forEach(function(objFile_a)
	{
		var strText = String(objFile_a.text || '');
		var arrFirst = strText.match(/^\s*(?:\d+\s+)?(?:\/\/#\s*|'#\s*|rem\s*#\s*)?option\s+flavour\s+(\w+)/i);
		var strFlavour = arrFirst ? arrFirst[1].toLowerCase() : (/\.js$/i.test(objFile_a.name || '') ? 'js' : (/\.loc$/i.test(objFile_a.name || '') ? 'locomotive' : String(objOptions.flavour || 'vb5').toLowerCase()));
		var fnFlavour = objFlavours[strFlavour];
		var objR = null;
		var strStem = String(objFile_a.name || 'main').replace(/\.[^.\/\\]*$/, '');

		if (!objFile_a.name)
		{
			objFile_a = { name: (strFlavour === 'js') ? 'main.js' : 'main.bas', text: strText, platform: objFile_a.platform };		// one text: main.bas / main.js
		}

		if (typeof fnFlavour !== 'function')
		{
			arrErrors.push({ file: objFile_a.name, line: 1, msg: 'no such flavour: ' + strFlavour + ' (' + Object.keys(objFlavours).filter(function(k_a) { return typeof objFlavours[k_a] === 'function'; }).join(', ') + ')' });
			return;
		}
		if (strFlavour === 'vb5')
		{
			objR = fnFlavour(objFile_a, objOptions);
			arrFiles.push({ name: objFile_a.name, text: objR.text, platform: objFile_a.platform });
			return;
		}
		objR = fnFlavour(objFile_a, objOptions);
		arrErrors = arrErrors.concat(objR.errors);
		arrWarnings = arrWarnings.concat(objR.warnings || []);
		arrFiles.push({ name: strStem + (objR.cls ? '.cls' : '.bas'), text: objR.text, lines: objR.lines, orig: objFile_a.name, flavour: strFlavour, platform: objFile_a.platform });
	});
	return { files: arrFiles, errors: arrErrors, warnings: arrWarnings };
}

// the ROM's file name (8 letters): NTCFW, NTCMIN, NTCCPC
function ntcRomFile(strPlatform_a)
{
	return (strPlatform_a === 'cpc') ? 'NTCCPC' : ('NTC' + strPlatform_a.toUpperCase().replace('CPC', ''));
}

function ntcRomRegistry(strReg_a)
{
	var objReg = { list: [], byName: {}, order: [] };

	String(strReg_a || '').split(/\r?\n/).forEach(function(strLine_a)
	{
		var arrMatch = strLine_a.match(/^\s*(\d+|-)\s+(code|data|bss|const|gone)\s+([A-Za-z_]\w*)\s*(\S*)/);
		var objEntry = null;

		if (arrMatch)
		{
			objEntry = { num: (arrMatch[1] === '-') ? null : parseInt(arrMatch[1], 10), kind: arrMatch[2], name: arrMatch[3], value: arrMatch[4] ? parseInt(arrMatch[4].replace(/^#/, ''), 16) : null, order: objReg.order.length };
			if (objEntry.num !== null)
			{
				objReg.list[objEntry.num] = objEntry;
			}
			objReg.order.push(objEntry);
			objReg.byName[objEntry.name] = objEntry;
		}
	});
	return objReg;
}

function ntcRomAsm(strPlatform_a, strReg_a)
{
	var arrErrors = [];
	var objReg = ntcRomRegistry(strReg_a);
	var objRes = ntcCompile('Print\n', { platform: strPlatform_a, library: 'allmodes', sourcecomments: false });
	var arrSections = [];
	var objSec = null;
	var objDefined = {};
	var objKeep = {};
	var blnChanged = true;
	var Z80_WORDS = {};
	var arrCode = [];
	var arrInit = [];
	var arrBss = [];
	var arrConst = [];
	var objItems = {};		// label -> { kind, lines }
	var arrOrderNew = [];
	var arrOut = [];
	var arrSyms = [];
	var strIndent = '\t\t\t';
	var intNum = 0;
	var intRun = 0;
	var intIdx = 0;
	var strHex = '';

	'a b c d e h l af bc de hl ix iy sp ixh ixl iyh iyl i r nz z nc po pe p m high low not and or xor mod shl shr'.split(' ').forEach(function(str_a) { Z80_WORDS[str_a] = true; });
	if ((strPlatform_a !== 'cpcfw') && (strPlatform_a !== 'cpc') && (strPlatform_a !== 'cpcmin'))
	{
		arrErrors.push({ file: '', line: 0, msg: 'Library ROM: the CPC platforms only (not ' + strPlatform_a + ')' });
		return { asm: '', errors: arrErrors, symbols: [] };
	}
	objRes.errors.forEach(function(objErr_a)
	{
		if (!/^not in library/.test(objErr_a.msg))
		{
			arrErrors.push(objErr_a);
		}
	});

	// the sections: header ;## name deps ..., then lines
	String(objRes.libasm).split('\n').forEach(function(strLine_a)
	{
		var arrMatch = strLine_a.match(/^;##\s+(\S+)/);

		if (arrMatch)
		{
			objSec = { name: arrMatch[1], header: strLine_a, lines: [] };
			arrSections.push(objSec);
			return;
		}
		if (objSec !== null)
		{
			objSec.lines.push(strLine_a);
		}
	});
	// @ramonly sections stay out of the ROM (a program has its own copy); what they name of
	// the ROM's is exported (registry entries) for that copy
	var arrRamOnlyUses = [];
	arrSections = arrSections.filter(function(objSec_a)
	{
		if (!/\s@ramonly\b/.test(objSec_a.header))
		{
			return true;
		}
		objSec_a.lines.forEach(function(str_a) { arrRamOnlyUses = arrRamOnlyUses.concat(str_a.replace(/"[^"]*"|'[^']*'/g, '').replace(/;.*$/, '').match(/[A-Za-z_]\w*/g) || []); });
		return false;
	});
	// one Interrupt-hook window for both: ntc_xnh (it is a superset of ntc_xn)
	arrSections = arrSections.filter(function(objSec_a) { return !((objSec_a.name === 'ntc_xn') && !/\(normal mode copy\)/.test(objSec_a.header) && (objSec_a.lines.join('\n').indexOf('ntc_hookpend') < 0)); });

	// IF NTC_ROMLIB ... [ELSE ...] ENDIF in the platform files: the ROM's version kept (without
	// the IF), the RAM version dropped; other IFs pass through
	arrSections.forEach(function(objSec_a)
	{
		var arrStack = [];
		var arrKept = [];

		function keeping()
		{
			return arrStack.every(function(objF_a) { return !objF_a.romlib || objF_a.keep; });
		}
		objSec_a.lines.forEach(function(strLine_a)
		{
			var strCode = strLine_a.replace(/;.*$/, '');

			if (/^\s*IF\s+NTC_ROMLIB\b/i.test(strCode))
			{
				arrStack.push({ romlib: true, keep: true });
				return;
			}
			if (/^\s*IF(N?DEF|N?USED)?\b/i.test(strCode))
			{
				arrStack.push({ romlib: false });
			}
			else if (/^\s*ELSE\b/i.test(strCode) && (arrStack.length > 0) && arrStack[arrStack.length - 1].romlib)
			{
				arrStack[arrStack.length - 1].keep = false;
				return;
			}
			else if (/^\s*ENDIF\b/i.test(strCode) && (arrStack.length > 0))
			{
				if (arrStack.pop().romlib)
				{
					return;
				}
			}
			if (keeping())
			{
				arrKept.push(strLine_a);
			}
		});
		objSec_a.lines = arrKept;
	});

	// the program's symbols the library uses become variables the program's start sets (or
	// fixed values for the ROM)
	function adapt(strLine_a)
	{
		var str = strLine_a;

		str = str.replace(/^(\s+)ld\s+(hl|de),\s*ntc_free\s*\+\s*256\b/i, '$1ld $2, (ntc_v_free)\n$1inc ' + '$2'.charAt(0));
		str = str.replace(/^(\s+ld\s+(?:hl|de)\s*,\s*)ntc_free\b/i, '$1(ntc_v_free)');
		str = str.replace(/^(\s+ld\s+(?:hl|de)\s*,\s*)ntc_start\b/i, '$1(ntc_v_start)');
		str = str.replace(/^(\s+ld\s+(?:hl|de)\s*,\s*)NTC_STAMP\b/i, '$1(ntc_v_stamp)');
		if (/^\s*ASSERT\b.*\bntc_free\b/i.test(str))
		{
			str = '\t\t\t; (ROM: the program checks it)';
		}
		return str;
	}
	arrSections.forEach(function(objSec_a)
	{
		var arrOut2 = [];
		var intSkip = 0;
		var intRomEn = 0;

		objSec_a.lines.forEach(function(strLine_a)
		{
			var strCode = strLine_a.replace(/;.*$/, '');

			if (/^\s*IF\s+NTC_STRMAX\s*<\s*255/i.test(strCode))
			{
				intSkip = 1;
				return;
			}
			if (/^\s*IF\s+MEM_BANKS\s*>\s*0/i.test(strCode))
			{
				intSkip = 2;		// true in the ROM (64 banks): the block stays, without IF / ENDIF
				return;
			}
			if (/^\s*IF\s+NTC_ROMENABLE\b/i.test(strCode))
			{
				intRomEn++;
				arrOut2.push(strIndent + 'ld a, (ntc_v_romen)\t; (ROM: Option RomEnable, set by the program)');
				arrOut2.push(strIndent + 'or a');
				arrOut2.push(strIndent + 'jr z, ' + objSec_a.name + '_nre' + intRomEn);
				intSkip = 3;
				return;
			}
			if (/^\s*ENDIF\b/i.test(strCode) && (intSkip > 0))
			{
				if (intSkip === 3)
				{
					arrOut2.push(objSec_a.name + '_nre' + intRomEn + ':');
				}
				intSkip = 0;
				return;
			}
			if (intSkip === 1)
			{
				return;
			}
			arrOut2 = arrOut2.concat(adapt(strLine_a).split('\n'));
		});
		objSec_a.lines = arrOut2;
	});
	// cpcfw: the fast ticker event calls into this ROM (ROM select = its number), and Top stays
	// below the ROM's RAM
	arrSections.forEach(function(objSec_a)
	{
		if (objSec_a.name === 'ntc_plat_irq')
		{
			objSec_a.lines = objSec_a.lines.map(function(str_a)
			{
				if (/^\s+ld\s+c\s*,\s*#FF\b/i.test(str_a))
				{
					return strIndent + 'ld a, (ntc_v_rom)\t; (ROM: the event runs in this ROM)\n' + strIndent + 'ld c, a';
				}
				if (/^\s+ld\s+\(ntc_fwtop\)\s*,\s*hl/i.test(str_a))
				{
					return strIndent + '; (ROM: Top stays below the ROM\'s RAM)';
				}
				return str_a;
			}).join('\n').split('\n');
		}
		if (objSec_a.name === 'ntc_plat_data')
		{
			objSec_a.lines = objSec_a.lines.map(function(str_a) { return str_a.replace(/^(ntc_fwtop:\s+dw\s+)#A600\b/i, '$1NTC_ROMDATA'); });
		}
	});

	// sections that use a label nothing defines (a platform's unused parts) are left out,
	// and so on until all is defined
	function labelsOf(objSec_a)
	{
		var arrLabels = [];

		objSec_a.lines.forEach(function(str_a)
		{
			var arrMatch = str_a.match(/^([A-Za-z_]\w*)(?::|\s+equ\b|\s+(?:db|dw|ds|defb|defw|defs)\b)/i);

			if (arrMatch)
			{
				arrLabels.push(arrMatch[1]);
			}
		});
		return arrLabels;
	}
	function usesOf(objSec_a)
	{
		var arrUses = [];

		objSec_a.lines.forEach(function(str_a)
		{
			var strCode = str_a.replace(/"[^"]*"|'[^']*'/g, '""').replace(/;.*$/, '').replace(/^[A-Za-z_]\w*:?/, '');
			var arrParts = strCode.replace(/^\s+/, '').split(/\s+/);

			if ((arrParts.length < 2) || /^(equ)$/i.test(arrParts[0]))
			{
				arrParts = (strCode.match(/\bequ\b(.*)$/i) || ['', ''])[1].match(/[A-Za-z_]\w*/g) || [];
			}
			else
			{
				arrParts = arrParts.slice(1).join(' ').match(/[A-Za-z_]\w*/g) || [];
			}
			arrParts.forEach(function(strWord_a)
			{
				if ((Z80_WORDS[strWord_a.toLowerCase()] === undefined) && !/^#?[0-9A-Fa-f]+h?$/.test(strWord_a))
				{
					arrUses.push(strWord_a);
				}
			});
		});
		return arrUses;
	}
	arrSections.forEach(function(objSec_a) { objKeep[objSec_a.header + '|' + arrSections.indexOf(objSec_a)] = true; objSec_a.keep = true; });
	while (blnChanged)
	{
		blnChanged = false;
		objDefined = { NTC_ROMDATA: 1, NTC_ROMBSS: 1, NTC_STRMAX: 1, NTC_MEMBANKS: 1, ntc_v_free: 1, ntc_v_start: 1, ntc_v_stamp: 1, ntc_v_romen: 1, ntc_v_rom: 1, ntc_v_romold: 1 };
		arrSections.forEach(function(objSec_a)
		{
			if (objSec_a.keep)
			{
				labelsOf(objSec_a).forEach(function(str_a) { objDefined[str_a] = 1; });
			}
		});
		arrSections.forEach(function(objSec_a)
		{
			if (objSec_a.keep && usesOf(objSec_a).some(function(str_a) { return objDefined[str_a] === undefined; }))
			{
				objSec_a.keep = false;
				blnChanged = true;
			}
		});
	}
	arrSections = arrSections.filter(function(objSec_a) { return objSec_a.keep; });

	// split: code (the ROM), initialised variables (RAM, copied from the ROM), the rest (RAM,
	// cleared), constants. A label with data after it is a variable; unlabelled data between
	// instructions is code (inline opcodes). The Graphics section runs from RAM: it reads the
	// screen, which the upper ROM hides
	arrSections.forEach(function(objSec_a)
	{
		var objItem = null;
		var arrPending = [];		// labels on their own lines: the next line decides
		var arrPrefix = [];			// unlabelled data after a buffer (ds): the next variable's (a capacity byte)
		var blnRam = (objSec_a.name === 'ntc_gfx') || /\s@romram\b/.test(objSec_a.header);

		intRun++;		// a run: variables one after another in the source - kept together, in order
		var arrTo = blnRam ? arrInit : arrCode;		// the code that runs from RAM goes into the image

		function prefixBack()
		{
			// no variable followed: the lines stay with the one before
			arrPrefix.forEach(function(str_a) { objItem.lines.push(str_a); objItem.ds = false; });
			arrPrefix = [];
		}
		function alias(str_a, objOf_a)
		{
			objItem.lines.push(str_a + ':');		// another name in the same variable
			objItems[str_a] = { kind: 'alias', of: objOf_a };
		}
		arrTo.push(objSec_a.header + (blnRam ? '  (ROM: runs from RAM)' : ''));
		objSec_a.lines.forEach(function(strLine_a)
		{
			var strCode = strLine_a.replace(/"[^"]*"/g, '""').replace(/;.*$/, '');
			var arrLabel = strCode.match(/^([A-Za-z_]\w*):?(\s+(.*))?$/);
			var strBody = arrLabel ? (arrLabel[3] || '') : strCode.replace(/^\s+/, '');
			var blnData = /^(db|dw|ds|defb|defw|defs|dm|byte|word)\b/i.test(strBody);
			var blnDs = /^(ds|defs)\b/i.test(strBody);
			var strLabel = arrLabel ? arrLabel[1] : null;

			if (strCode.replace(/\s+/g, '').length === 0)
			{
				return;		// comments and blank lines stay out of the ROM text
			}
			if (strLabel && /^equ\b/i.test(strBody))
			{
				if (objItem !== null) { prefixBack(); }
				arrConst.push(strLine_a);
				objItems[strLabel] = { kind: 'const' };
				objItem = null;
				intRun++;
				return;
			}
			if (strLabel && (strBody.length === 0))
			{
				arrPending.push(strLabel);
				return;
			}
			if (blnData && (strLabel || (arrPending.length > 0)))
			{
				var strMain = strLabel || arrPending.pop();
				var arrBefore = arrPrefix;

				arrPrefix = [];
				if ((objItem !== null) && strLabel && (arrPending.length > 0))
				{
					// labels alone between two variables: the end of the first (ntc_pgstk_top)
					prefixBack();
					arrPending.forEach(function(str_a) { alias(str_a, objItem); });
					arrPending = [];
				}
				objItem = { label: strMain, lines: arrBefore.slice(0), ds: blnDs && (arrBefore.length === 0), run: intRun, idx: intIdx++ };
				arrPending.forEach(function(str_a) { alias(str_a, objItem); });
				objItem.lines.push(strLabel ? strLine_a : (strMain + ':' + strLine_a));
				objItems[strMain] = objItem;
				arrPending = [];
				return;
			}
			if (blnData && (objItem !== null) && (arrPending.length === 0))
			{
				if (objItem.ds && !blnDs)
				{
					arrPrefix.push(strLine_a);		// after a buffer: wait and see
					return;
				}
				prefixBack();
				objItem.lines.push(strLine_a);
				objItem.ds = objItem.ds && blnDs;
				return;
			}
			if (objItem !== null)
			{
				prefixBack();
			}
			objItem = null;
			intRun++;
			arrPending.forEach(function(str_a)
			{
				arrTo.push(ntcRomHook(strPlatform_a, objSec_a.name, str_a, str_a + ':'));
				objItems[str_a] = { kind: 'code' };
			});
			arrPending = [];
			if (strLabel)
			{
				objItems[strLabel] = { kind: 'code' };
			}
			arrTo.push(ntcRomHook(strPlatform_a, objSec_a.name, strLabel, strLine_a));
		});
		if (objItem !== null)
		{
			// labels at the end of a section after a variable: its end (ntc_gstack_top)
			prefixBack();
			arrPending.forEach(function(str_a) { alias(str_a, objItem); });
			arrPending = [];
		}
		arrPending.forEach(function(str_a)
		{
			arrTo.push(str_a + ':');
			objItems[str_a] = { kind: 'code' };
		});
	});
	// the values the program's start sets (its own symbols the library needs)
	[['ntc_v_free', 'dw 0', 'the first free byte (the program\'s ntc_free)'], ['ntc_v_start', 'dw 0', 'the program\'s start (ntc_start)'],
		['ntc_v_stamp', 'dw 0', 'the build stamp of its page files (NTC_STAMP)'], ['ntc_v_romen', 'db 0', 'Option RomEnable (NTC_ROMENABLE)'],
		['ntc_v_rom', 'db 0', 'this ROM\'s number'], ['ntc_v_romold', 'db 0', 'the ROM selection before the program']].forEach(function(arrV_a)
	{
		objItems[arrV_a[0]] = { label: arrV_a[0], lines: [arrV_a[0] + ':\t' + arrV_a[1] + '\t\t\t; ' + arrV_a[2]], ds: false, run: ++intRun, idx: intIdx++ };
	});
	if (strPlatform_a === 'cpcfw')
	{
		// the code in RAM switches the upper ROM off while it reads the screen (the firmware's
		// own calls, so its interrupts keep the state)
		arrInit.push('ntc_urom_off:');
		arrInit.push(strIndent + 'push af\n' + strIndent + 'push bc\n' + strIndent + 'push de\n' + strIndent + 'push hl');
		arrInit.push(strIndent + 'call #B903\t\t; KL U ROM DISABLE');
		arrInit.push(strIndent + 'pop hl\n' + strIndent + 'pop de\n' + strIndent + 'pop bc\n' + strIndent + 'pop af\n' + strIndent + 'ret');
		arrInit.push('ntc_urom_on:');
		arrInit.push(strIndent + 'push af\n' + strIndent + 'push bc\n' + strIndent + 'push de\n' + strIndent + 'push hl');
		arrInit.push(strIndent + 'call #B900\t\t; KL U ROM ENABLE');
		arrInit.push(strIndent + 'pop hl\n' + strIndent + 'pop de\n' + strIndent + 'pop bc\n' + strIndent + 'pop af\n' + strIndent + 'ret');
	}
	else
	{
		// cpc, cpcmin: the gate array directly (NTC's interrupt handler turns the ROM on for
		// its calls while ntc_uroff is 1)
		arrInit.push('ntc_urom_off:');
		arrInit.push(strIndent + 'push af\n' + strIndent + 'push bc');
		arrInit.push(strIndent + 'ld a, 1\n' + strIndent + 'ld (ntc_uroff), a');
		arrInit.push(strIndent + 'ld a, (ntc_smode)\n' + strIndent + 'or #8C\t\t\t\t; both ROMs off');
		arrInit.push(strIndent + 'ld b, #7F\n' + strIndent + 'out (c), a');
		arrInit.push(strIndent + 'pop bc\n' + strIndent + 'pop af\n' + strIndent + 'ret');
		arrInit.push('ntc_urom_on:');
		arrInit.push(strIndent + 'push af\n' + strIndent + 'push bc');
		arrInit.push(strIndent + 'ld a, (ntc_smode)\n' + strIndent + 'or #84\t\t\t\t; the upper ROM (this one) on');
		arrInit.push(strIndent + 'ld b, #7F\n' + strIndent + 'out (c), a');
		arrInit.push(strIndent + 'xor a\n' + strIndent + 'ld (ntc_uroff), a');
		arrInit.push(strIndent + 'pop bc\n' + strIndent + 'pop af\n' + strIndent + 'ret');
	}
	objItems.ntc_urom_off = { kind: 'code' };
	objItems.ntc_urom_on = { kind: 'code' };

	// the data items in registry order (known ones), then the new ones in source order
	var arrData = [];
	Object.keys(objItems).forEach(function(strName_a)
	{
		var objItem = objItems[strName_a];

		if (objItem.lines)
		{
			objItem.kind = objItem.ds ? 'bss' : 'data';
			arrData.push(strName_a);
		}
	});
	Object.keys(objItems).forEach(function(strName_a)
	{
		if (objItems[strName_a].kind === 'alias')
		{
			objItems[strName_a] = { kind: objItems[strName_a].of.kind };		// a name inside a variable: a variable too
		}
	});
	// what programs may name: every section's name, what the compiler's code and the platform
	// classes use, and the normal mode copies of those (label_n). Only these get registry
	// entries; the rest of the ROM's labels are its own and may change freely
	var objExport = {};
	arrSections.forEach(function(objSec_a) { objExport[objSec_a.name] = true; });
	NTC_ROM_RUNTIME.forEach(function(str_a) { objExport[str_a] = true; });
	arrRamOnlyUses.forEach(function(str_a) { objExport[str_a] = true; });
	if (typeof NTC_PLATFORM_CLASSES !== 'undefined')
	{
		Object.keys(NTC_PLATFORM_CLASSES[strPlatform_a] || {}).forEach(function(strFile_a)
		{
			(String(NTC_PLATFORM_CLASSES[strPlatform_a][strFile_a]).match(/[A-Za-z_]\w*/g) || []).forEach(function(str_a) { objExport[str_a] = true; });
		});
	}
	function exported(strName_a)
	{
		return (objExport[strName_a] === true) || ((strName_a.substr(-2) === '_n') && (objExport[strName_a.substr(0, strName_a.length - 2)] === true)) || (objReg.byName[strName_a] !== undefined);
	}
	// code: numbered (known numbers kept, new ones appended); variables and constants: by name
	intNum = objReg.list.length;
	objReg.list.forEach(function(objEntry_a)
	{
		if (objEntry_a)
		{
			arrSyms.push({ num: objEntry_a.num, name: objEntry_a.name, kind: ((objItems[objEntry_a.name] !== undefined) && (objItems[objEntry_a.name].kind === 'code')) ? 'code' : 'gone', known: true });
		}
	});
	Object.keys(objItems).forEach(function(strName_a)
	{
		if ((objItems[strName_a].kind === 'code') && exported(strName_a) && (objReg.byName[strName_a] === undefined))
		{
			arrSyms.push({ num: intNum++, name: strName_a, kind: 'code', known: false });
		}
	});
	var arrVars = [];
	objReg.order.forEach(function(objEntry_a)
	{
		if (objEntry_a.num === null)
		{
			arrVars.push({ name: objEntry_a.name, kind: (objItems[objEntry_a.name] !== undefined) ? objItems[objEntry_a.name].kind : 'gone', known: true });
		}
	});
	Object.keys(objItems).forEach(function(strName_a)
	{
		var strKind = objItems[strName_a].kind;

		if (((strKind === 'data') || (strKind === 'bss') || (strKind === 'const')) && exported(strName_a) && (objReg.byName[strName_a] === undefined))
		{
			arrVars.push({ name: strName_a, kind: strKind, known: false });
		}
	});
	// the data items: exported ones first (registry order, new ones appended), then the ROM's own
	// (a run moves as a whole: code may count on one variable following another, as
	// ntc_plat_mode's copy into ntc_sbpc ... ntc_sshift does)
	var objRunRank = {};
	function rank(str_a)
	{
		var objE = objReg.byName[str_a];

		if (objE) { return objE.order; }
		return exported(str_a) ? 100000 : 200000;
	}
	arrData.forEach(function(str_a)
	{
		var intR = objItems[str_a].run;

		objRunRank[intR] = (objRunRank[intR] === undefined) ? rank(str_a) : Math.min(objRunRank[intR], rank(str_a));
	});
	arrData.sort(function(strA_a, strB_a)
	{
		var objA = objItems[strA_a];
		var objB = objItems[strB_a];

		return (objRunRank[objA.run] - objRunRank[objB.run]) || (objA.run - objB.run) || (objA.idx - objB.idx);
	});

	function hex4(int_a)
	{
		return '#' + ('000' + (int_a & 0xFFFF).toString(16).toUpperCase()).substr(-4);
	}
	// the ROM
	arrOut.push('; ============================================================');
	arrOut.push('; NTC BASIC keyword library ROM - ' + strPlatform_a + ' (generated by ntcRomAsm, ntc_compiler.js)');
	arrOut.push('; A background ROM: standard header, no BASIC commands (yet). Programs built with');
	arrOut.push('; Library: ROM find it at their start and call ntc_rom_patch with their jump block.');
	arrOut.push('; ============================================================');
	arrOut.push(strIndent + 'DEVICE AMSTRADCPC6128');
	arrOut.push('NTC_ROMDATA\tequ ' + hex4(NTC_ROM_DATA) + '\t\t; its initialised variables (and RAM code), copied by ntc_rom_patch');
	arrOut.push('NTC_ROMBSS\tequ ' + hex4(NTC_ROM_BSS) + '\t\t; its other variables, cleared');
	arrOut.push('NTC_STRMAX\tequ 255\t\t\t; strings up to 255 characters (programs built for the ROM use 255)');
	arrOut.push('NTC_MEMBANKS\tequ 64\t\t\t; the Memory class: up to 4MB');
	arrOut.push('NTC_ROM_N\tequ ' + arrSyms.length + '\t\t\t; numbers in the index');
	arrOut.push(arrConst.join('\n'));
	arrOut.push(strIndent + 'OUTPUT "' + ntcRomFile(strPlatform_a) + '.ROM"');
	strHex = '#4000';
	arrOut.push(strIndent + 'ORG #C000 - 128\t\t; an AMSDOS header (WinAPE and ROM tools take it): binary, #C000, 16K');
	var strRomName = (ntcRomFile(strPlatform_a) + '        ').substr(0, 8);
	var intSum = 2 + 0xC0 + 0x40 + 0xC0 + 0x40;
	for (var intI = 0; intI < 8; intI++) { intSum += strRomName.charCodeAt(intI); }
	intSum += 0x52 + 0x4F + 0x4D;
	arrOut.push(strIndent + 'db 0, "' + strRomName + '", "ROM"\t; user 0, the file name');
	arrOut.push(strIndent + 'ds 6');
	arrOut.push(strIndent + 'db 2');
	arrOut.push(strIndent + 'dw 0, #C000');
	arrOut.push(strIndent + 'db 0');
	arrOut.push(strIndent + 'dw #4000, #C000');
	arrOut.push(strIndent + 'ds 36');
	arrOut.push(strIndent + 'dw #4000');
	arrOut.push(strIndent + 'db 0');
	arrOut.push(strIndent + 'dw ' + hex4(intSum) + '\t\t\t; checksum of bytes 0-66');
	arrOut.push(strIndent + 'ds 59');
	arrOut.push(strIndent + 'ORG #C000');
	arrOut.push('ntc_rom_start:');
	arrOut.push(strIndent + 'db 1\t\t\t\t; a background ROM');
	arrOut.push(strIndent + 'db 1, 0, 0\t\t\t; mark, version, modification');
	arrOut.push(strIndent + 'dw ntc_rom_names');
	arrOut.push(strIndent + 'jp ntc_rom_init\t\t; (and one jp per BASIC command, later)');
	arrOut.push('ntc_rom_names:');
	var strNm = 'NTC ' + strPlatform_a.toUpperCase();
	arrOut.push(strIndent + 'db "' + strNm.substr(0, strNm.length - 1) + '", "' + strNm.substr(-1) + '" + #80\t; the ROM\'s name (one per platform: they can all be fitted)');
	arrOut.push(strIndent + 'db 0\t\t\t\t; (no BASIC commands yet)');
	arrOut.push('ntc_rom_block:\t\t\t\t; NTC\'s part: the program\'s start code reads it');
	arrOut.push(strIndent + 'db "NTC", 1\t\t\t; mark, format of this block');
	arrOut.push(strIndent + 'db "' + strPlatform_a.toUpperCase() + '", 0\t\t; the platform it is for');
	arrOut.push(strIndent + 'dw ntc_rom_patch\t\t; HL = jump block, BC = entries, A = this ROM\'s number');
	arrOut.push(strIndent + 'dw ntc_rom_index, NTC_ROM_N');
	arrOut.push('; the firmware starts background ROMs at power on: nothing to do (no RAM claimed)');
	arrOut.push('ntc_rom_init:');
	arrOut.push(strIndent + 'scf');
	arrOut.push(strIndent + 'ret');
	arrOut.push('; ntc_rom_patch - (call, from the program, this ROM selected) HL = the program\'s jump');
	arrOut.push('; block (3 bytes each: jp <number>), BC = its entries, A = this ROM\'s number. Sets up');
	arrOut.push('; the ROM\'s RAM (initialised variables copied, the rest cleared), then each number becomes');
	arrOut.push('; the ROM\'s address. NC = done. C = a number this ROM hasn\'t got: DE = it.');
	arrOut.push('ntc_rom_patch:');
	arrOut.push(strIndent + 'push hl');
	arrOut.push(strIndent + 'push bc');
	arrOut.push(strIndent + 'push af');
	arrOut.push(strIndent + 'ld hl, ntc_rom_img');
	arrOut.push(strIndent + 'ld de, NTC_ROMDATA');
	arrOut.push(strIndent + 'ld bc, ntc_rom_imgend - ntc_rom_img');
	arrOut.push(strIndent + 'ldir');
	arrOut.push(strIndent + 'ld hl, NTC_ROMBSS');
	arrOut.push(strIndent + 'ld de, NTC_ROMBSS + 1');
	arrOut.push(strIndent + 'ld bc, ntc_rom_bssend - NTC_ROMBSS - 1');
	arrOut.push(strIndent + 'ld (hl), 0');
	arrOut.push(strIndent + 'ldir');
	arrOut.push(strIndent + 'pop af');
	arrOut.push(strIndent + 'ld (ntc_v_rom), a');
	arrOut.push(strIndent + 'pop bc');
	arrOut.push(strIndent + 'pop hl');
	arrOut.push('ntc_rp_lp:');
	arrOut.push(strIndent + 'ld a, b');
	arrOut.push(strIndent + 'or c');
	arrOut.push(strIndent + 'ret z\t\t\t\t; all done (NC)');
	arrOut.push(strIndent + 'inc hl\t\t\t\t; past the jp');
	arrOut.push(strIndent + 'ld e, (hl)');
	arrOut.push(strIndent + 'inc hl');
	arrOut.push(strIndent + 'ld d, (hl)\t\t\t; DE = the number, HL at its high byte');
	arrOut.push(strIndent + 'push hl');
	arrOut.push(strIndent + 'push bc');
	arrOut.push(strIndent + 'ld hl, NTC_ROM_N - 1');
	arrOut.push(strIndent + 'or a');
	arrOut.push(strIndent + 'sbc hl, de');
	arrOut.push(strIndent + 'jr c, ntc_rp_bad\t\t; beyond this ROM\'s numbers');
	arrOut.push(strIndent + 'ld hl, ntc_rom_index');
	arrOut.push(strIndent + 'add hl, de');
	arrOut.push(strIndent + 'add hl, de');
	arrOut.push(strIndent + 'ld e, (hl)');
	arrOut.push(strIndent + 'inc hl');
	arrOut.push(strIndent + 'ld d, (hl)\t\t\t; DE = its address');
	arrOut.push(strIndent + 'ld a, d');
	arrOut.push(strIndent + 'or e');
	arrOut.push(strIndent + 'jr z, ntc_rp_bad\t\t; 0: no longer in this ROM');
	arrOut.push(strIndent + 'pop bc');
	arrOut.push(strIndent + 'pop hl');
	arrOut.push(strIndent + 'ld (hl), d');
	arrOut.push(strIndent + 'dec hl');
	arrOut.push(strIndent + 'ld (hl), e');
	arrOut.push(strIndent + 'inc hl');
	arrOut.push(strIndent + 'inc hl\t\t\t\t; the next entry');
	arrOut.push(strIndent + 'dec bc');
	arrOut.push(strIndent + 'jr ntc_rp_lp');
	arrOut.push('ntc_rp_bad:');
	arrOut.push(strIndent + 'pop bc');
	arrOut.push(strIndent + 'pop hl');
	arrOut.push(strIndent + 'ld d, (hl)\t\t\t; DE = the number it hasn\'t got');
	arrOut.push(strIndent + 'dec hl');
	arrOut.push(strIndent + 'ld e, (hl)');
	arrOut.push(strIndent + 'scf');
	arrOut.push(strIndent + 'ret');
	arrOut.push('; the index: number -> address (0: no longer in this ROM)');
	arrOut.push('ntc_rom_index:');
	arrSyms.sort(function(objA_a, objB_a) { return objA_a.num - objB_a.num; }).forEach(function(objSym_a)
	{
		arrOut.push(strIndent + 'dw ' + ((objSym_a.kind === 'gone') ? '0' : objSym_a.name) + '\t\t; ' + objSym_a.num + ((objSym_a.kind === 'gone') ? ' (no longer here)' : ''));
	});
	arrOut.push('; ---- the library (code)');
	arrOut = arrOut.concat(arrCode);
	arrOut.push('; ---- initialised variables and the code that runs from RAM: assembled for NTC_ROMDATA, copied there');
	arrOut.push('ntc_rom_img:');
	arrOut.push(strIndent + 'DISP NTC_ROMDATA');
	arrData.forEach(function(strName_a)
	{
		if (objItems[strName_a].kind === 'data')
		{
			arrOut = arrOut.concat(objItems[strName_a].lines);
		}
	});
	arrOut.push('; ---- code that runs from RAM (addresses may change between ROMs: programs reach it through their jump block)');
	arrOut = arrOut.concat(arrInit);
	arrOut.push('ntc_rom_imgend_r:');
	arrOut.push(strIndent + 'ENT');
	arrOut.push('ntc_rom_imgend:');
	arrOut.push(strIndent + 'ASSERT ntc_rom_imgend_r <= NTC_ROMBSS, "the ROM\'s initialised variables reach #9400"');
	arrOut.push(strIndent + 'ASSERT $ <= #10000, "the ROM is more than 16K"');
	arrOut.push(strIndent + 'ds #10000 - $, 0\t\t; to 16K');
	arrOut.push(strIndent + 'OUTEND');
	arrOut.push('; ---- the other variables: RAM from NTC_ROMBSS, not in the ROM');
	arrOut.push(strIndent + 'ORG NTC_ROMBSS');
	arrData.forEach(function(strName_a)
	{
		if (objItems[strName_a].kind === 'bss')
		{
			arrOut = arrOut.concat(objItems[strName_a].lines);
		}
	});
	arrOut.push('ntc_rom_bssend:');
	arrOut.push(strIndent + 'ASSERT ntc_rom_bssend <= ' + hex4(NTC_ROM_END) + ', "the ROM\'s variables reach #A5F0"');
	// known variables and constants must not move: the registry has their addresses / values
	arrVars.forEach(function(objSym_a)
	{
		var objEntry = objReg.byName[objSym_a.name];

		if (objEntry && (objEntry.value !== null) && ((objSym_a.kind === 'data') || (objSym_a.kind === 'bss') || (objSym_a.kind === 'const')))
		{
			arrOut.push(strIndent + 'ASSERT (' + objSym_a.name + ' & #FFFF) == ' + hex4(objEntry.value) + ', "' + objSym_a.name + ' moved: variables and constants keep their place (a new size or value needs a new name)"');
		}
	});
	return { asm: arrOut.join('\n') + '\n', errors: arrErrors, symbols: arrSyms, vars: arrVars };
}

// ROM build: the code that runs from RAM switches the upper ROM off while it reads the
// screen (cpcfw: around gfx_begin / gfx_end, and the screen copies)
function ntcRomHook(strPlatform_a, strSection_a, strLabel_a, strLine_a)
{
	if ((strSection_a !== 'ntc_gfx') || !strLabel_a)
	{
		return strLine_a;
	}
	if ((strLabel_a === 'gfx_begin') || (strLabel_a === 'gfx_end'))
	{
		return strLine_a + '\n\t\t\tcall ' + ((strLabel_a === 'gfx_begin') ? 'ntc_urom_off' : 'ntc_urom_on') + '\t; (ROM: the upper ROM hides the screen)';
	}
	if ((strLabel_a === 'gfx_double') || (strLabel_a === 'gfx_copyrows') || (strLabel_a === 'gfx_line'))
	{
		return strLabel_a + ':\t\t\t\t; (ROM: the upper ROM off around it)\n\t\t\tcall ntc_urom_off\n\t\t\tcall ' + strLabel_a + '_r\n\t\t\tjp ntc_urom_on\n' + strLine_a.replace(new RegExp('^' + strLabel_a + '\\b'), strLabel_a + '_r');
	}
	return strLine_a;
}

// ============================================================
// Library: ROM - the program's side. In place of the library: a jump block of the ROM
// routines the program names ("label: jp <number>", numbers from the registry), the ROM's
// variables and constants as equ (their fixed addresses), and the start code that finds the
// ROM (KL ROM SELECT on each slot, its header, the "NTC" block and platform after its names),
// calls the ROM's patcher with the jump block (each number becomes the ROM's address), and
// gives the ROM the program's own values (ntc_free ...). End comes back through ntc_rj_exit,
// which puts the caller's ROM selection back.
//   arrAsm_a: the program's text (everything but the library); arrErrors_a: errors go here
// Returns the lines that go where the library would be
// ============================================================
function ntcRomJumpBlock(strPlatform_a, arrAsm_a, blnStamp_a, blnRomEnable_a, arrErrors_a)
{
	var strIndent = '\t\t\t';
	var strReg = (typeof NTC_ROM_REG !== 'undefined') ? NTC_ROM_REG[strPlatform_a] : undefined;
	var objReg = null;
	var objDefined = {};
	var objUsed = {};
	var arrCode = [];
	var arrVars = [];
	var arrMissing = [];
	var arrOut = [];

	if (strReg === undefined)
	{
		arrErrors_a.push({ file: '', line: 0, msg: 'Library: ROM - there is no keyword library ROM for ' + strPlatform_a + ' (the CPC platforms have one: cpc, cpcmin, cpcfw)' });
		return [];
	}
	objReg = ntcRomRegistry(strReg);
	arrAsm_a.forEach(function(strText_a)
	{
		String(strText_a).split('\n').forEach(function(strLine_a)
		{
			var strCode = strLine_a.replace(/"[^"]*"/g, '""').replace(/'[^']*'/g, "''").replace(/;.*$/, '');
			var arrDef = strCode.match(/^([A-Za-z_]\w*)(:|\s+equ\b|\s*=)/i);
			var arrWords = strCode.replace(/^([A-Za-z_]\w*):?/, '').match(/[A-Za-z_]\w*/g) || [];

			if (arrDef)
			{
				objDefined[arrDef[1]] = true;
			}
			arrWords.forEach(function(str_a) { objUsed[str_a] = true; });
		});
	});
	// the start code's own
	['ntc_v_free', 'ntc_v_start', 'ntc_v_stamp', 'ntc_v_romen', 'ntc_v_romold'].forEach(function(str_a) { objUsed[str_a] = true; });
	Object.keys(objUsed).sort().forEach(function(strName_a)
	{
		var objEntry = objReg.byName[strName_a];

		if (objDefined[strName_a])
		{
			return;
		}
		if (objEntry === undefined)
		{
			if (/^(kw|ntc|mem|ovl|gfx|fs|lst)_/.test(strName_a) && !/^ntc_rj_/.test(strName_a))
			{
				arrMissing.push(strName_a);
			}
			return;
		}
		if (objEntry.kind === 'gone')
		{
			arrMissing.push(strName_a);
		}
		else if (objEntry.kind === 'code')
		{
			arrCode.push(objEntry);
		}
		else
		{
			arrVars.push(objEntry);
		}
	});
	if (arrMissing.length > 0)
	{
		arrErrors_a.push({ file: '', line: 0, msg: 'Library: ROM - the ' + strPlatform_a + ' ROM has no ' + arrMissing.join(', ') + ' (build with the library in RAM)' });
	}
	arrCode.sort(function(objA_a, objB_a) { return objA_a.num - objB_a.num; });

	function hex4(int_a)
	{
		return '#' + ('000' + (int_a & 0xFFFF).toString(16).toUpperCase()).substr(-4);
	}
	arrOut.push('; Library: ROM - the keyword library is in the ROM NTC ' + strPlatform_a.toUpperCase() + ' (' + ntcRomFile(strPlatform_a) + '.ROM).');
	arrOut.push('; Its routines: this jump block, the numbers made into addresses by the ROM at the start.');
	arrOut.push('; Its variables and constants: fixed addresses (RAM #8800 - #A5EF is the ROM\'s).');
	arrOut.push('ntc_rj_block:');
	arrCode.forEach(function(objE_a)
	{
		arrOut.push(objE_a.name + ':' + ((objE_a.name.length < 8) ? '\t' : '') + '\tjp ' + objE_a.num);
	});
	arrOut.push('NTC_RJ_N\tequ ' + arrCode.length + '\t\t; entries');
	arrVars.forEach(function(objE_a)
	{
		arrOut.push(objE_a.name + '\tequ ' + hex4(objE_a.value) + '\t\t; ROM ' + objE_a.kind);
	});
	arrOut.push(strIndent + 'ASSERT ntc_free <= #8800, "Library: ROM - the program and its arrays must end below #8800 (the ROM\'s RAM)"');
	arrOut.push('');
	arrOut.push('; the start: find the ROM in slots 0 - 31, have it patch the jump block. NC = ready;');
	arrOut.push('; C = not there / too old (the message is shown, the caller\'s ROM selection is back)');
	arrOut.push('ntc_rj_find:');
	arrOut.push(strIndent + 'ld c, 0');
	arrOut.push(strIndent + 'call #B90F\t\t; KL ROM SELECT: B / C = the caller\'s state and selection');
	arrOut.push(strIndent + 'ld (ntc_rj_old), bc');
	arrOut.push(strIndent + 'ld c, 0');
	arrOut.push('ntc_rj_next:');
	arrOut.push(strIndent + 'push bc');
	arrOut.push(strIndent + 'call #B90F\t\t; KL ROM SELECT: ROM C');
	arrOut.push(strIndent + 'pop bc');
	arrOut.push(strIndent + 'ld a, (#C000)');
	arrOut.push(strIndent + 'cp 1\t\t\t\t; a background ROM?');
	arrOut.push(strIndent + 'jr nz, ntc_rj_skip');
	arrOut.push(strIndent + 'ld hl, (#C004)\t\t; its names');
	arrOut.push(strIndent + 'ld a, h');
	arrOut.push(strIndent + 'cp #C0');
	arrOut.push(strIndent + 'jr c, ntc_rj_skip');
	arrOut.push('ntc_rj_name:');
	arrOut.push(strIndent + 'ld a, (hl)');
	arrOut.push(strIndent + 'inc hl');
	arrOut.push(strIndent + 'or a');
	arrOut.push(strIndent + 'jr nz, ntc_rj_name\t\t; to the 0 after the names');
	arrOut.push(strIndent + 'ld de, ntc_rj_sig');
	arrOut.push(strIndent + 'ld b, ntc_rj_sige - ntc_rj_sig');
	arrOut.push('ntc_rj_cmp:');
	arrOut.push(strIndent + 'ld a, (de)');
	arrOut.push(strIndent + 'cp (hl)');
	arrOut.push(strIndent + 'jr nz, ntc_rj_skip');
	arrOut.push(strIndent + 'inc de');
	arrOut.push(strIndent + 'inc hl');
	arrOut.push(strIndent + 'djnz ntc_rj_cmp');
	arrOut.push(strIndent + 'ld e, (hl)');
	arrOut.push(strIndent + 'inc hl');
	arrOut.push(strIndent + 'ld d, (hl)\t\t\t; its patcher');
	arrOut.push(strIndent + 'ld (ntc_rj_call + 1), de');
	arrOut.push(strIndent + 'ld a, c\t\t\t\t; its slot');
	arrOut.push(strIndent + 'ld hl, ntc_rj_block');
	arrOut.push(strIndent + 'ld bc, NTC_RJ_N');
	arrOut.push('ntc_rj_call:');
	arrOut.push(strIndent + 'call 0\t\t\t\t; HL = jump block, BC = entries, A = slot; C: DE = a number it hasn\'t got');
	arrOut.push(strIndent + 'jr c, ntc_rj_lacks');
	arrOut.push(strIndent + 'ld hl, ntc_free');
	arrOut.push(strIndent + 'ld (ntc_v_free), hl');
	arrOut.push(strIndent + 'ld hl, ntc_start');
	arrOut.push(strIndent + 'ld (ntc_v_start), hl');
	arrOut.push(strIndent + 'ld hl, ' + (blnStamp_a ? 'NTC_STAMP' : '0'));
	arrOut.push(strIndent + 'ld (ntc_v_stamp), hl');
	arrOut.push(strIndent + 'ld a, ' + (blnRomEnable_a ? 1 : 0));
	arrOut.push(strIndent + 'ld (ntc_v_romen), a');
	arrOut.push(strIndent + 'ld a, (ntc_rj_old)');
	arrOut.push(strIndent + 'ld (ntc_v_romold), a');
	arrOut.push(strIndent + 'or a\t\t\t\t; NC: ready');
	arrOut.push(strIndent + 'ret');
	arrOut.push('ntc_rj_skip:');
	arrOut.push(strIndent + 'inc c');
	arrOut.push(strIndent + 'ld a, c');
	arrOut.push(strIndent + 'cp 32');
	arrOut.push(strIndent + 'jr c, ntc_rj_next');
	arrOut.push(strIndent + 'ld hl, ntc_rj_tnf');
	arrOut.push(strIndent + 'jr ntc_rj_fail');
	arrOut.push('ntc_rj_lacks:');
	arrOut.push(strIndent + 'ld (ntc_rj_num), de');
	arrOut.push(strIndent + 'ld hl, ntc_rj_tlk');
	arrOut.push('ntc_rj_fail:');
	arrOut.push(strIndent + 'push hl');
	arrOut.push(strIndent + 'ld bc, (ntc_rj_old)');
	arrOut.push(strIndent + 'call #B918\t\t; KL ROM DESELECT: the caller\'s selection again');
	arrOut.push(strIndent + 'pop hl');
	arrOut.push(strIndent + 'call ntc_rj_puts');
	arrOut.push(strIndent + 'ld hl, ntc_rj_tlk');
	arrOut.push(strIndent + 'or a');
	arrOut.push(strIndent + 'sbc hl, de\t\t\t; (DE: past the message shown)');
	arrOut.push(strIndent + 'jr nz, ntc_rj_nl');
	arrOut.push(strIndent + 'ld a, (ntc_rj_num + 1)');
	arrOut.push(strIndent + 'call ntc_rj_hex');
	arrOut.push(strIndent + 'ld a, (ntc_rj_num)');
	arrOut.push(strIndent + 'call ntc_rj_hex');
	arrOut.push('ntc_rj_nl:');
	arrOut.push(strIndent + 'ld hl, ntc_rj_tnl');
	arrOut.push(strIndent + 'call ntc_rj_puts');
	arrOut.push(strIndent + 'ei');
	arrOut.push(strIndent + 'call #BB06\t\t; KM WAIT CHAR: a key first (a RUN" program\'s return resets the machine)');
	arrOut.push(strIndent + 'di');
	arrOut.push(strIndent + 'scf');
	arrOut.push(strIndent + 'ret');
	arrOut.push('ntc_rj_puts:\t\t\t\t; HL = text, 0 ends; DE = its start');
	arrOut.push(strIndent + 'ld d, h');
	arrOut.push(strIndent + 'ld e, l');
	arrOut.push('ntc_rj_pl:');
	arrOut.push(strIndent + 'ld a, (hl)');
	arrOut.push(strIndent + 'or a');
	arrOut.push(strIndent + 'ret z');
	arrOut.push(strIndent + 'call #BB5A\t\t; TXT OUTPUT');
	arrOut.push(strIndent + 'inc hl');
	arrOut.push(strIndent + 'jr ntc_rj_pl');
	arrOut.push('ntc_rj_hex:');
	arrOut.push(strIndent + 'push af');
	arrOut.push(strIndent + 'rrca');
	arrOut.push(strIndent + 'rrca');
	arrOut.push(strIndent + 'rrca');
	arrOut.push(strIndent + 'rrca');
	arrOut.push(strIndent + 'call ntc_rj_dig');
	arrOut.push(strIndent + 'pop af');
	arrOut.push('ntc_rj_dig:');
	arrOut.push(strIndent + 'and 15');
	arrOut.push(strIndent + 'add a, #90');
	arrOut.push(strIndent + 'daa');
	arrOut.push(strIndent + 'adc a, #40');
	arrOut.push(strIndent + 'daa');
	arrOut.push(strIndent + 'jp #BB5A');
	arrOut.push('; End: the caller\'s ROM selection again, then back to the caller');
	arrOut.push('ntc_rj_exit:');
	arrOut.push(strIndent + 'ld bc, (ntc_rj_old)');
	arrOut.push(strIndent + 'call #B918\t\t; KL ROM DESELECT');
	arrOut.push(strIndent + 'ret');
	arrOut.push('ntc_rj_old:\t\tdw 0\t\t\t; the caller\'s ROM selection (C) and state (B)');
	arrOut.push('ntc_rj_num:\t\tdw 0');
	arrOut.push('ntc_rj_sig:\t\tdb "NTC", 1, "' + strPlatform_a.toUpperCase() + '", 0\t; the ROM\'s NTC block');
	arrOut.push('ntc_rj_sige:');
	arrOut.push('ntc_rj_tnf:\t\tdb "ROM NTC ' + strPlatform_a.toUpperCase() + ' (' + ntcRomFile(strPlatform_a) + '.ROM) not found", 0');
	arrOut.push('ntc_rj_tlk:\t\tdb "ROM NTC ' + strPlatform_a.toUpperCase() + ' too old: no routine #", 0');
	arrOut.push('ntc_rj_tnl:\t\tdb 13, 10, "Press a key", 13, 10, 0');
	return arrOut;
}
