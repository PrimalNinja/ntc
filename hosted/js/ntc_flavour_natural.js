// ============================================================
// NTC BASIC - the Natural flavour: a flavour preprocessor (ntcPrep)
// (c) 2026 Cyborg Unicorn Pty Ltd - MIT License
// ============================================================
// Near-English sentences turned into VB5 text for NTC's one parser and compiler. The compiler
// is not touched: a word nobody has written yet becomes a call the compiler reports as not
// found (docs/natural_flavour.md has the whole of it).
//
// A file whose first line is "Option Flavour Natural" (or named .nat) is natural all through:
//   #ntc ... #endntc     plain NTC BASIC, passed through as it is
//   #asm ... #endasm     assembler, passed through as it is
// In a plain NTC BASIC file it is the other way about: #natural ... #endnatural is the natural
// part and the rest is passed through.
//
//   words        separated by a space, a line break or a colon (all the same); case ignored
//   noise        the words in NTC_NATURAL_NOISE are dropped (add to the list)
//   ' ...        a comment to the end of the line
//   operands     a number (12, -3, &HFF), "a string", a name the file declares (Dim, Const,
//                a Sub's parameter, a count's counter), variable x (any name), ( a VB expression )
//   with sprite 1      the context: class Sprite, id 1. It lasts to the next with, or to the
//                      end of the block (if, loop) it was opened in
//   rotate 90          a word that is not built in: in a context Sprite.Rotate 1, 90; with no
//                      context, or when the file has a Sub of that name, Rotate 90
//   with turtle        a class with no ids: forward 10 is Turtle.Forward 10
//   name red door is door 3      "red door" from here on means class Door, id 3
//   the project's classes are the vocabulary: with a class of the project as the context, its
//   Public Subs are the verbs (turn left is TurnLeft: several words are joined, the longest
//   match wins, and each takes as many values as it has parameters), its Functions are values
//   (say balance) and state words (if overdrawn), and a word it has not got is an error here
//   say "Hi" score     Print "Hi"; " "; score
//   ask "Guess" into g           Input "Guess"; g
//   to square using size ... end     a word of your own (a Sub): square 5
//   a bare name that set / ask / pick / into writes to and nobody has declared is declared
//   for you (a String for "text", a Long for a big number, else an Integer)
//   pick t from 1 to 100         a number at random, 1 to 100
//   set x to 5, add 5 to x, subtract 1 from x, multiply x by 2, divide x by 10,
//   remainder of x by 10 into r
//   if <condition> ... [else ...] end
//   repeat 10 times ... end, count n from 1 to 8 ... end, count n from 8 down to 1 ... end,
//   while <condition> ... end, forever ... end, leave
//   conditions   a is above / is below / is equal to / is not equal to / is at least /
//                is at most b; a state word in a context (closed: Door.Closed(3) <> 0); not;
//                and, or
// Usage: ntcFlavourNatural({ name, text }, options) -> { text, lines, cls, errors, warnings }
// (options.files: the project's files [{ name, text }], for its classes; options.naturalBlocks:
// a plain file with #natural parts)
// ============================================================

// the words dropped wherever they are (a pure list: add to it)
var NTC_NATURAL_NOISE = ['the', 'a', 'an', 'then', 'please'];

function ntcFlavourNatural(objFile_a, objOptions_a)
{
	var strFile = objFile_a.name || 'main.bas';
	var arrSrc = String(objFile_a.text || '').replace(/\r\n?/g, '\n').split('\n');
	var blnWhole = !(objOptions_a && objOptions_a.naturalBlocks);	// the whole file is natural (#ntc for the rest)
	var arrErrors = [];
	var arrOut = [];			// the VB lines
	var arrMap = [];			// each one's source line
	var arrItems = [];			// the natural text as tokens { k: 'w' | 'n' | 's' | 'g', v, line }, and { k: 'raw' } where plain lines were
	var objNoise = {};
	var objNames = {};			// names the file declares (lower case -> as written)
	var objSubs = {};			// Subs and Functions the file has (lower case -> as written)
	var objEntities = {};		// "red door" -> { cls, id }
	var objClasses = {};		// the project's classes: lower case name -> { name, members: { lower case name -> { name, fn, params, id } } }
	var intEntityWords = 1;		// the most words in an entity's name
	var arrBlocks = [];			// open blocks { kind: 'if' | 'for' | 'do', close, line, ctx }
	var objCtx = null;			// the context { cls, id }
	var intHidden = 0;			// hidden counters made
	var objDimmed = {};			// counters this pass has declared since the last Sub line
	var arrParams = [];			// the open Sub's parameters (seen by the sentences inside it only)
	var objHidden = {};			// the names the pass declared: declared again in each Sub
	var arrLocals = null;		// inside a "to": the names made in it (gone at its end)
	var objOuterDimmed = null;	// inside a "to": what was declared outside it
	var intPos = 0;
	var intI = 0;
	var strMode = blnWhole ? 'nat' : 'vb';
	var arrM = null;
	var strLine = '';
	var objBuiltIn = { 'with': 1, 'name': 1, 'say': 1, 'set': 1, 'add': 1, 'subtract': 1, 'multiply': 1, 'divide': 1, 'remainder': 1,
		'if': 1, 'else': 1, 'end': 1, 'repeat': 1, 'count': 1, 'while': 1, 'forever': 1, 'leave': 1, 'variable': 1, 'not': 1,
		'ask': 1, 'pick': 1, 'using': 1, 'is': 1, 'to': 1, 'from': 1, 'by': 1, 'into': 1, 'of': 1, 'times': 1, 'down': 1, 'and': 1, 'or': 1 };

	var objNaming = { 'set': 1, 'count': 1, 'into': 1, 'pick': 1, 'variable': 1, 'using': 1 };	// a name is given after these
	var objKept = {};			// noise words the file uses as names
	var objFiller = { 'to': 1, 'from': 1, 'by': 1, 'into': 1, 'of': 1, 'at': 1 };
	var objStarts = { 'with': 1, 'name': 1, 'say': 1, 'set': 1, 'add': 1, 'subtract': 1, 'multiply': 1, 'divide': 1, 'remainder': 1,
		'if': 1, 'else': 1, 'end': 1, 'repeat': 1, 'count': 1, 'while': 1, 'forever': 1, 'leave': 1, 'ask': 1, 'pick': 1 };

	NTC_NATURAL_NOISE.forEach(function(str_a) { objNoise[str_a] = 1; });

	// the project's other files: a class's Public Subs and Functions are its words; a module's
	// Subs are words anywhere
	((objOptions_a && objOptions_a.files) || []).forEach(function(objOther_a)
	{
		var strName = String(objOther_a.name || '');
		var strText = String(objOther_a.text || '');
		var blnCls = /\.cls$/i.test(strName);
		var strStem = strName.replace(/^.*[\/\\]/, '').replace(/\.[^.]*$/, '');
		var objC = null;

		if (objOther_a === objFile_a || strName === objFile_a.name || !/\.(cls|bas)$/i.test(strName)) { return; }
		if (/^\s*(?:'#\s*)?option\s+flavour\s+(?!vb5)/i.test(strText)) { return; }
		if (blnCls)
		{
			objC = { name: strStem, members: {} };
			objClasses[strStem.toLowerCase()] = objC;
		}
		strText.replace(/\r\n?/g, '\n').split('\n').forEach(function(strL_a)
		{
			var arrS = strL_a.match(/^\s*(Public\s+)?(Sub|Function)\s+(\w+)\s*(?:\(([^)]*)\))?/i);
			var arrP = [];

			if (!arrS) { return; }
			arrP = (arrS[4] || '').split(',').map(function(str_a) { return (str_a.match(/^\s*(?:Optional\s+)?(?:ByVal\s+|ByRef\s+)?(\w+)/i) || ['', ''])[1]; }).filter(function(str_a) { return str_a !== ''; });
			if (blnCls)
			{
				if (arrS[1]) { objC.members[arrS[3].toLowerCase()] = { name: arrS[3], fn: /^function$/i.test(arrS[2]), params: arrP.length, id: arrP.length > 0 && arrP[0].toLowerCase() === 'id' }; }
			}
			else if (!/^main$/i.test(arrS[3]))
			{
				objSubs[arrS[3].toLowerCase()] = arrS[3];
			}
		});
	});

	function error(intLine_a, strMsg_a)
	{
		arrErrors.push({ file: strFile, line: intLine_a, msg: 'natural: ' + strMsg_a });
	}

	function out(strText_a, intLine_a)
	{
		arrOut.push(strText_a);
		arrMap.push(intLine_a);
	}

	// a plain NTC BASIC line: the names it declares are seen by the sentences
	function noteVb(strLine_a)
	{
		var strCode = strLine_a.replace(/"[^"]*"/g, '""').replace(/'.*$/, '');
		var arrD = strCode.match(/^\s*(?:Public\s+|Private\s+)?(?:Dim|Const|Static|Global)\s+(.*)$/i);
		var arrS = strCode.match(/^\s*(?:Public\s+|Private\s+)?(Sub|Function)\s+(\w+)\s*(?:\(([^)]*)\))?/i);

		if (/^\s*(?:Public\s+|Private\s+)?(?:Dim|Const|Static|Global)\b/i.test(strCode) && !arrD) { return; }
		if (arrD)
		{
			arrD[1].split(',').forEach(function(strPart_a)
			{
				var arrN = strPart_a.match(/^\s*(\w+)/);

				if (arrN) { objNames[arrN[1].toLowerCase()] = arrN[1]; }
			});
		}
		if (arrS)
		{
			objSubs[arrS[2].toLowerCase()] = arrS[2];
			objDimmed = {};
			(arrS[3] || '').split(',').forEach(function(strPart_a)
			{
				var arrN = strPart_a.match(/^\s*(?:Optional\s+)?(?:ByVal\s+|ByRef\s+)?(\w+)/i);

				if (arrN && !Object.prototype.hasOwnProperty.call(objNames, arrN[1].toLowerCase()))
				{
					objNames[arrN[1].toLowerCase()] = arrN[1];
					arrParams.push(arrN[1].toLowerCase());
				}
			});
		}
		if (/^\s*End\s+(Sub|Function)\b/i.test(strCode))
		{
			// its parameters are its own
			objDimmed = {};
			arrParams.forEach(function(str_a) { delete objNames[str_a]; });
			arrParams = [];
		}
	}

	// a natural line to tokens
	function tokens(strLine_a, intLine_a)
	{
		var intP = 0;
		var intQ = 0;
		var intDepth = 0;
		var strC = '';
		var arrT = null;
		var intFirst = arrItems.length;
		var objT = null;
		var objN = null;
		var objP = null;

		while (intP < strLine_a.length)
		{
			strC = strLine_a.charAt(intP);
			if (strC === ' ' || strC === '\t' || strC === ':' || strC === ',' ) { intP++; continue; }
			if (strC === "'") { break; }
			if (strC === '"')
			{
				intQ = strLine_a.indexOf('"', intP + 1);
				if (intQ < 0) { error(intLine_a, 'a string is not closed'); break; }
				arrItems.push({ k: 's', v: strLine_a.substring(intP, intQ + 1), line: intLine_a });
				intP = intQ + 1;
				continue;
			}
			if (strC === '(')
			{
				intDepth = 0;
				for (intQ = intP; intQ < strLine_a.length; intQ++)
				{
					if (strLine_a.charAt(intQ) === '"')
					{
						intQ = strLine_a.indexOf('"', intQ + 1);
						if (intQ < 0) { intQ = strLine_a.length; break; }
						continue;
					}
					if (strLine_a.charAt(intQ) === '(') { intDepth++; }
					if (strLine_a.charAt(intQ) === ')') { intDepth--; if (intDepth === 0) { break; } }
				}
				if (intQ >= strLine_a.length) { error(intLine_a, 'a ( is not closed on its line'); break; }
				arrItems.push({ k: 'g', v: strLine_a.substring(intP, intQ + 1), line: intLine_a });
				intP = intQ + 1;
				continue;
			}
			arrT = strLine_a.substr(intP).match(/^(-?\d+|&H[0-9A-F]+&?)(?![\w.])/i);
			if (arrT)
			{
				arrItems.push({ k: 'n', v: arrT[1], line: intLine_a });
				intP += arrT[1].length;
				continue;
			}
			arrT = strLine_a.substr(intP).match(/^[A-Za-z_][\w$%&]*(?:\.[A-Za-z_]\w*)*/);
			if (arrT)
			{
				arrItems.push({ k: 'w', v: arrT[0], lc: arrT[0].toLowerCase(), line: intLine_a, z: !!objNoise[arrT[0].toLowerCase()] });
				intP += arrT[0].length;
				continue;
			}
			arrT = strLine_a.substr(intP).match(/^\S+/);
			error(intLine_a, 'what is ' + arrT[0] + '? (a sum goes in brackets: ( x * 2 + 1 ))');
			intP += arrT[0].length;
		}
		// the noise words go - but one can be a name: where a name is being given (set a to 0,
		// count a from ..., into a, variable a) and no other name follows it, and from then on
		for (intQ = intFirst; intQ < arrItems.length; intQ++)
		{
			objT = arrItems[intQ];
			if (!objT.z) { continue; }
			objN = arrItems[intQ + 1];
			objP = arrItems[intQ - 1];
			if (objKept[objT.lc] || Object.prototype.hasOwnProperty.call(objNames, objT.lc)) { objT.z = false; continue; }
			if (objP && objP.k === 'w' && !objP.z && objNaming[objP.lc] && (objP.lc === 'variable' || !objN || objN.k !== 'w' || (!objN.z && objBuiltIn[objN.lc])))
			{
				objKept[objT.lc] = 1;
				objT.z = false;
			}
		}
		for (intQ = arrItems.length - 1; intQ >= intFirst; intQ--)
		{
			if (arrItems[intQ].z) { arrItems.splice(intQ, 1); }
		}
	}

	// ---------------------------------------------------------------- the sentences
	function peek(intAhead_a)
	{
		var objT = arrItems[intPos + (intAhead_a || 0)];

		return (objT && objT.k !== 'raw') ? objT : null;
	}

	function isWord(strWord_a, intAhead_a)
	{
		var objT = peek(intAhead_a);

		return !!objT && objT.k === 'w' && objT.lc === strWord_a;
	}

	function shown(objT_a)
	{
		return objT_a ? '"' + String(objT_a.v).replace(/^"|"$/g, '') + '"' : 'the end of the sentences';
	}

	// a marker word that must be next
	function marker(strWord_a, strOf_a, intLine_a)
	{
		if (isWord(strWord_a)) { intPos++; return true; }
		error(peek() ? peek().line : intLine_a, strOf_a + ' expects "' + strWord_a + '", got ' + shown(peek()));
		return false;
	}

	// an entity's name here? -> its length in words (0: none; the longest wins)
	function entityAt()
	{
		var intN = 0;
		var intK = 0;
		var arrW = [];

		for (intN = intEntityWords; intN >= 1; intN--)
		{
			arrW = [];
			for (intK = 0; intK < intN; intK++)
			{
				if (!peek(intK) || peek(intK).k !== 'w') { arrW = null; break; }
				arrW.push(peek(intK).lc);
			}
			if (arrW && Object.prototype.hasOwnProperty.call(objEntities, arrW.join(' '))) { return intN; }
		}
		return 0;
	}

	function entityTake(intN_a)
	{
		var arrW = [];
		var intK = 0;

		for (intK = 0; intK < intN_a; intK++) { arrW.push(arrItems[intPos + intK].lc); }
		intPos += intN_a;
		return objEntities[arrW.join(' ')];
	}

	// the context's class, when the project has it (null: none, or a class from elsewhere)
	function ctxClass()
	{
		return objCtx ? (objClasses[objCtx.cls.toLowerCase()] || null) : null;
	}

	// a word of the context's class at intPos + intFrom_a: up to four words joined (turn left is
	// TurnLeft), the longest match winning. blnFn_a: true a Function, false a Sub.
	// -> { m: the member, n: its words } or null
	function memberAt(intFrom_a, blnFn_a)
	{
		var objC = ctxClass();
		var intN = 0;
		var intK = 0;
		var strJ = '';
		var objT = null;

		if (!objC) { return null; }
		for (intN = 4; intN >= 1; intN--)
		{
			strJ = '';
			for (intK = 0; intK < intN; intK++)
			{
				objT = arrItems[intPos + intFrom_a + intK];
				if (!objT || objT.k !== 'w') { strJ = ''; break; }
				strJ += objT.lc;
			}
			if (strJ !== '' && Object.prototype.hasOwnProperty.call(objC.members, strJ) && objC.members[strJ].fn === blnFn_a)
			{
				return { m: objC.members[strJ], n: intN };
			}
		}
		return null;
	}

	// TurnLeft -> turn left
	function spoken(strName_a)
	{
		return strName_a.replace(/([a-z0-9])([A-Z])/g, '$1 $2').toLowerCase();
	}

	// the class's words, for a message
	function wordsOf(objC_a)
	{
		return Object.keys(objC_a.members).map(function(str_a) { return spoken(objC_a.members[str_a].name); }).join(', ');
	}

	// the values a member of the context's class takes after its words, with the id in front
	// when it has one (null: a mistake, told)
	function memberArgs(objM_a, intLine_a)
	{
		var arrA = [];
		var intNeed = objM_a.params - (objM_a.id ? 1 : 0);
		var strV = '';

		if (objM_a.id)
		{
			if (objCtx.id === null) { error(intLine_a, spoken(objM_a.name) + ' needs which ' + objCtx.cls.toLowerCase() + ' (with ' + objCtx.cls.toLowerCase() + ' 1)'); return null; }
			arrA.push(objCtx.id);
		}
		while (intNeed > 0)
		{
			// (to, from, by, into, of, at between a word's values read well and mean nothing: transfer 100 to savings)
			while (peek() && peek().k === 'w' && objFiller[peek().lc] && !memberAt(0, true)) { intPos++; }
			if (!operandNext())
			{
				error(intLine_a, spoken(objM_a.name) + ' expects ' + (objM_a.params - (objM_a.id ? 1 : 0)) + ' value' + ((objM_a.params - (objM_a.id ? 1 : 0) === 1) ? '' : 's') + ', got ' + shown(peek()));
				return null;
			}
			strV = operand(spoken(objM_a.name), intLine_a, false);
			if (strV === null) { return null; }
			arrA.push(strV);
			intNeed--;
		}
		return arrA;
	}

	// the context's id as the first argument, when it has one
	function idArgs()
	{
		return (objCtx && objCtx.id !== null) ? [objCtx.id] : [];
	}

	// is the next thing an operand? (not taken)
	function operandNext()
	{
		var objT = peek();

		if (!objT) { return false; }
		if (objT.k !== 'w') { return true; }
		if (objT.lc === 'variable') { return true; }
		if (objBuiltIn[objT.lc]) { return false; }
		if (Object.prototype.hasOwnProperty.call(objNames, objT.lc)) { return true; }
		if (entityAt() > 0) { return true; }
		return memberAt(0, true) !== null;
	}

	// an operand as VB text (null: there is none - strOf_a says who wanted it, for the message)
	function operand(strOf_a, intLine_a, blnAnyName_a)
	{
		var objT = peek();
		var objE = null;
		var objM = null;
		var arrA = null;

		if (!objT)
		{
			error(intLine_a, strOf_a + ' expects a value, got ' + shown(null));
			return null;
		}
		if (objT.k === 'n' || objT.k === 's' || objT.k === 'g')
		{
			intPos++;
			return objT.v;
		}
		if (objT.lc === 'variable')
		{
			intPos++;
			objT = peek();
			if (!objT || objT.k !== 'w') { error(intLine_a, 'variable expects a name, got ' + shown(objT)); return null; }
			intPos++;
			return objT.v;
		}
		if (Object.prototype.hasOwnProperty.call(objNames, objT.lc))
		{
			intPos++;
			return objNames[objT.lc];
		}
		if (entityAt() > 0)
		{
			objE = entityTake(entityAt());
			return objE.id;
		}
		if (blnAnyName_a && !objBuiltIn[objT.lc])
		{
			intPos++;
			return objT.v;
		}
		objM = memberAt(0, true);
		if (objM)
		{
			// a Function of the context's class: a value
			intPos += objM.n;
			arrA = memberArgs(objM.m, intLine_a);
			return (arrA === null) ? null : objCtx.cls + '.' + objM.m.name + '(' + arrA.join(', ') + ')';
		}
		error(intLine_a, strOf_a + ' expects a value, got ' + shown(objT) + ((objT.k === 'w' && !objBuiltIn[objT.lc]) ? ' (a name the file does not declare is written: variable ' + objT.v + ')' : ''));
		return null;
	}

	function proper(str_a)
	{
		return str_a.charAt(0).toUpperCase() + str_a.substr(1);
	}

	// one comparison or state word
	function condOne(intLine_a)
	{
		var objT = peek();
		var strA = '';
		var strB = '';
		var strOp = '';
		var blnNot = false;

		if (isWord('not'))
		{
			intPos++;
			strA = condOne(intLine_a);
			return (strA === null) ? null : 'Not (' + strA + ')';
		}
		if (!objT) { error(intLine_a, 'a condition is missing'); return null; }
		// a state word: a word that is not a value
		if (objT.k === 'w' && !operandNext())
		{
			if (objBuiltIn[objT.lc]) { error(objT.line, 'a condition is missing before ' + shown(objT)); return null; }
			if (isWord('is', 1)) { error(objT.line, shown(objT) + ' is not a name the file declares (written: variable ' + objT.v + ')'); return null; }
			intPos++;
			if (Object.prototype.hasOwnProperty.call(objSubs, objT.lc)) { return '(' + objSubs[objT.lc] + '() <> 0)'; }
			if (!objCtx) { error(objT.line, shown(objT) + ' needs a with before it (with door 3 ... ' + objT.v + ')'); return null; }
			if (ctxClass()) { error(objT.line, shown(objT) + ' is not a ' + objCtx.cls.toLowerCase() + ' word (' + objCtx.cls.toLowerCase() + ' has: ' + wordsOf(ctxClass()) + ')'); return null; }
			return '(' + objCtx.cls + '.' + proper(objT.v) + '(' + idArgs().join(', ') + ') <> 0)';
		}
		strA = operand('a condition', intLine_a, false);
		if (strA === null) { return null; }
		if (!isWord('is')) { return '(' + strA + ' <> 0)'; }		// a value by itself: true when it is not 0
		intPos++;
		if (isWord('not')) { intPos++; blnNot = true; }
		if (isWord('above')) { intPos++; strOp = '>'; }
		else if (isWord('below')) { intPos++; strOp = '<'; }
		else if (isWord('equal')) { intPos++; strOp = '='; if (!marker('to', 'is equal', intLine_a)) { return null; } }
		else if (isWord('at') && isWord('least', 1)) { intPos += 2; strOp = '>='; }
		else if (isWord('at') && isWord('most', 1)) { intPos += 2; strOp = '<='; }
		else
		{
			error(peek() ? peek().line : intLine_a, 'is expects above, below, equal to, at least or at most, got ' + shown(peek()));
			return null;
		}
		strB = operand('is ' + strOp, intLine_a, false);
		if (strB === null) { return null; }
		return blnNot ? 'Not (' + strA + ' ' + strOp + ' ' + strB + ')' : '(' + strA + ' ' + strOp + ' ' + strB + ')';
	}

	function condition(intLine_a)
	{
		var strC = condOne(intLine_a);
		var strD = '';
		var strJoin = '';

		while (strC !== null && (isWord('and') || isWord('or')))
		{
			strJoin = isWord('and') ? ' And ' : ' Or ';
			intPos++;
			strD = condOne(intLine_a);
			if (strD === null) { return null; }
			strC = '(' + strC + strJoin + strD + ')';
		}
		return strC;
	}

	// a name the sentences make (a count's counter, the target of set / ask / pick / into):
	// declared where it is first used unless the file declares it. blnShow_a: the sentences
	// see it by its name from here on. One made inside a "to" is that word's own.
	function declare(strName_a, strType_a, intLine_a, blnShow_a)
	{
		var strKey = strName_a.toLowerCase();

		if (Object.prototype.hasOwnProperty.call(objNames, strKey) && !objHidden[strKey]) { return objNames[strKey]; }
		if (blnShow_a && !Object.prototype.hasOwnProperty.call(objNames, strKey))
		{
			objHidden[strKey] = 1;
			objNames[strKey] = strName_a;
			if (arrLocals) { arrLocals.push(strKey); }
		}
		if (!objDimmed[strKey])
		{
			objDimmed[strKey] = 1;
			out('Dim ' + strName_a + ' As ' + strType_a, intLine_a);
		}
		return strName_a;
	}

	function counter(strName_a, intLine_a, blnShow_a)
	{
		return declare(strName_a, 'Integer', intLine_a, blnShow_a);
	}

	// the name a sentence is about to write to (set x, ask ... into x): a bare name nobody has
	// declared is declared for you - a String for "text", a Long for a number past an Integer,
	// else an Integer. (variable x and a dotted or $ name are left as they are.)
	function target(strOf_a, intLine_a)
	{
		var objT = peek();
		var blnNew = !!objT && objT.k === 'w' && !objBuiltIn[objT.lc] && !Object.prototype.hasOwnProperty.call(objNames, objT.lc) && entityAt() === 0 && !/[.$%&]/.test(objT.v);
		var strN = operand(strOf_a, intLine_a, true);

		return (strN === null) ? null : { name: strN, isNew: blnNew };
	}

	function made(objTarget_a, strValue_a, intLine_a)
	{
		var strType = 'Integer';

		if (!objTarget_a.isNew) { return; }
		if (/^"/.test(strValue_a)) { strType = 'String'; }
		else if (/^-?\d+$/.test(strValue_a) && (parseInt(strValue_a, 10) > 32767 || parseInt(strValue_a, 10) < -32768)) { strType = 'Long'; }
		declare(objTarget_a.name, strType, intLine_a, true);
	}

	function openBlock(strKind_a, strClose_a, intLine_a)
	{
		arrBlocks.push({ kind: strKind_a, close: strClose_a, line: intLine_a, ctx: objCtx });
	}

	// a thing: a class's name and, when it has ids, the id -> { cls, id } (id null: a class with
	// no ids), or null. A class of the project says whether it has ids (a first parameter named
	// id); one from elsewhere has an id when a value follows its name.
	function thing(strOf_a, intLine_a, blnNeedId_a)
	{
		var objT = peek();
		var objC = objClasses[objT.lc] || null;
		var strCls = objC ? objC.name : proper(objT.v);
		var blnIds = false;
		var strId = null;

		intPos++;
		objCtx = null;			// (the id is not a word of the last context's)
		if (objC) { Object.keys(objC.members).forEach(function(str_a) { if (objC.members[str_a].id) { blnIds = true; } }); }
		if (objC ? blnIds : (blnNeedId_a || operandNext()))
		{
			strId = operand(strOf_a + ' ' + strCls.toLowerCase(), intLine_a, false);
			if (strId === null) { return null; }
		}
		else if (blnNeedId_a)
		{
			error(intLine_a, strCls.toLowerCase() + ' has no ids to give a name to');
			return null;
		}
		return { cls: strCls, id: strId };
	}

	function sentence()
	{
		var objT = arrItems[intPos];
		var intLine = objT.line;
		var strA = '';
		var strB = '';
		var strC = '';
		var arrOps = [];
		var arrW = [];
		var objB = null;
		var objE = null;
		var intK = 0;
		var blnDown = false;
		var objM = null;

		if (objT.k !== 'w')
		{
			error(intLine, 'a sentence starts with a word, not ' + shown(objT));
			intPos++;
			return;
		}
		intPos++;
		switch (objT.lc)
		{
			case 'with':
				if (entityAt() > 0)
				{
					objE = entityTake(entityAt());
					objCtx = { cls: objE.cls, id: objE.id };
					return;
				}
				if (!peek() || peek().k !== 'w' || objBuiltIn[peek().lc]) { error(intLine, 'with expects a thing (with sprite 1), got ' + shown(peek())); return; }
				objE = thing('with', intLine, false);
				if (objE) { objCtx = objE; }
				return;

			case 'name':
				while (peek() && peek().k === 'w' && peek().lc !== 'is')
				{
					arrW.push(peek().lc);
					intPos++;
				}
				if (arrW.length === 0) { error(intLine, 'name expects the name (name red door is door 3)'); return; }
				if (!marker('is', 'name', intLine)) { return; }
				if (!peek() || peek().k !== 'w') { error(intLine, 'name ... is expects a thing (door 3), got ' + shown(peek())); return; }
				objE = thing('name', intLine, true);
				if (!objE) { return; }
				strA = objE.cls;
				strB = objE.id;
				if (Object.prototype.hasOwnProperty.call(objEntities, arrW.join(' '))) { error(intLine, 'the name "' + arrW.join(' ') + '" is given twice'); return; }
				if (arrW.length === 1 && (objBuiltIn[arrW[0]] || Object.prototype.hasOwnProperty.call(objNames, arrW[0]))) { error(intLine, 'the name "' + arrW[0] + '" is already a word or a variable'); return; }
				objEntities[arrW.join(' ')] = { cls: strA, id: strB };
				if (arrW.length > intEntityWords) { intEntityWords = arrW.length; }
				return;

			case 'say':
				while (operandNext())
				{
					strA = operand('say', intLine, false);
					if (strA === null) { return; }
					arrOps.push(strA);
				}
				out('Print ' + arrOps.join('; " "; '), intLine);		// (a space between the things said)
				return;

			case 'ask':
				if (peek() && peek().k === 's') { strA = peek().v; intPos++; }
				if (!marker('into', 'ask', intLine)) { return; }
				objE = target('ask ... into', intLine);
				if (objE === null) { return; }
				made(objE, '0', intLine);
				out('Input ' + ((strA !== '') ? strA + '; ' : '') + objE.name, intLine);
				return;

			case 'pick':
				objE = target('pick', intLine);
				if (objE === null || !marker('from', 'pick', intLine)) { return; }
				strC = objE.name;
				strA = operand('pick ... from', intLine, false);
				if (strA === null || !marker('to', 'pick', intLine)) { return; }
				strB = operand('pick ... to', intLine, false);
				if (strB === null) { return; }
				made(objE, '0', intLine);
				if (/^-?\d+$/.test(strA) && /^-?\d+$/.test(strB)) { out(strC + ' = Rnd(' + (parseInt(strB, 10) - parseInt(strA, 10) + 1) + ') + ' + strA, intLine); }
				else { out(strC + ' = Rnd(' + strB + ' - ' + strA + ' + 1) + ' + strA, intLine); }
				return;

			case 'set':
				objE = target('set', intLine);
				if (objE === null || !marker('to', 'set', intLine)) { return; }
				strB = operand('set ... to', intLine, false);
				if (strB === null) { return; }
				made(objE, strB, intLine);
				out(objE.name + ' = ' + strB, intLine);
				return;

			case 'add':
			case 'subtract':
				strA = operand(objT.lc, intLine, false);
				if (strA === null || !marker((objT.lc === 'add') ? 'to' : 'from', objT.lc, intLine)) { return; }
				strB = operand(objT.lc, intLine, true);
				if (strB !== null) { out(strB + ' = ' + strB + ((objT.lc === 'add') ? ' + ' : ' - ') + strA, intLine); }
				return;

			case 'multiply':
			case 'divide':
				strA = operand(objT.lc, intLine, true);
				if (strA === null || !marker('by', objT.lc, intLine)) { return; }
				strB = operand(objT.lc + ' ... by', intLine, false);
				if (strB !== null) { out(strA + ' = ' + strA + ((objT.lc === 'multiply') ? ' * ' : ' \\ ') + strB, intLine); }
				return;

			case 'remainder':
				if (!marker('of', 'remainder', intLine)) { return; }
				strA = operand('remainder of', intLine, true);
				if (strA === null || !marker('by', 'remainder', intLine)) { return; }
				strB = operand('remainder ... by', intLine, false);
				if (strB === null || !marker('into', 'remainder', intLine)) { return; }
				objE = target('remainder ... into', intLine);
				if (objE === null) { return; }
				made(objE, '0', intLine);
				out(objE.name + ' = ' + strA + ' Mod ' + strB, intLine);
				return;

			case 'to':
				// a word of your own: to square using size ... end
				if (arrBlocks.length > 0) { error(intLine, 'to ... starts a word of your own: it can\'t be inside an if, a loop or another to'); openBlock('if', '', intLine); return; }
				if (!peek() || peek().k !== 'w' || objBuiltIn[peek().lc]) { error(intLine, 'to expects the new word (to square using size ... end), got ' + shown(peek())); openBlock('sub', 'End Sub', intLine); return; }
				strA = proper(peek().v);
				intPos++;
				objOuterDimmed = objDimmed;
				objDimmed = {};
				Object.keys(objOuterDimmed).forEach(function(str_a) { objDimmed[str_a] = 1; });
				arrLocals = [];
				if (isWord('using'))
				{
					intPos++;
					while (peek() && peek().k === 'w' && !objBuiltIn[peek().lc] && !Object.prototype.hasOwnProperty.call(objSubs, peek().lc) && !memberAt(0, false) && !memberAt(0, true) && !Object.prototype.hasOwnProperty.call(objNames, peek().lc))
					{
						arrW.push('ByVal ' + peek().v + ' As Integer');
						objNames[peek().lc] = peek().v;
						arrLocals.push(peek().lc);
						intPos++;
					}
					if (arrW.length === 0) { error(intLine, 'using expects the names of the values (to square using size), got ' + shown(peek())); }
				}
				objSubs[strA.toLowerCase()] = strA;
				out('Sub ' + strA + '(' + arrW.join(', ') + ')', intLine);
				openBlock('sub', 'End Sub', intLine);
				return;

			case 'if':
				strA = condition(intLine);
				out('If ' + ((strA === null) ? '0' : strA) + ' Then', intLine);
				openBlock('if', 'End If', intLine);
				return;

			case 'else':
				objB = arrBlocks[arrBlocks.length - 1];
				if (!objB || objB.kind !== 'if' || objB.elsed) { error(intLine, 'else without an if'); return; }
				objB.elsed = true;
				objCtx = objB.ctx;
				out('Else', intLine);
				return;

			case 'end':
				objB = arrBlocks.pop();
				if (!objB) { error(intLine, 'end without an if or a loop'); return; }
				objCtx = objB.ctx;
				out(objB.close, intLine);
				if (objB.kind === 'sub' && arrLocals)
				{
					// its names were its own
					arrLocals.forEach(function(str_a) { delete objNames[str_a]; delete objHidden[str_a]; });
					arrLocals = null;
					objDimmed = objOuterDimmed;
				}
				return;

			case 'repeat':
				strA = operand('repeat', intLine, false);
				if (strA === null || !marker('times', 'repeat', intLine)) { strA = '0'; }
				intHidden++;
				strB = counter('nat_n' + intHidden, intLine, false);
				out('For ' + strB + ' = 1 To ' + strA, intLine);
				openBlock('for', 'Next ' + strB, intLine);
				return;

			case 'count':
				if (!peek() || peek().k !== 'w' || objBuiltIn[peek().lc])
				{
					error(intLine, 'count expects a counter\'s name (count n from 1 to 8), got ' + shown(peek()));
					openBlock('for', 'Next', intLine);
					return;
				}
				strC = peek().v;
				intPos++;
				strC = counter(strC, intLine, true);
				openBlock('for', 'Next ' + strC, intLine);
				if (!marker('from', 'count', intLine)) { return; }
				strA = operand('count ... from', intLine, false);
				if (strA === null) { return; }
				if (isWord('down')) { intPos++; blnDown = true; }
				if (!marker('to', 'count', intLine)) { return; }
				strB = operand('count ... to', intLine, false);
				if (strB === null) { return; }
				out('For ' + strC + ' = ' + strA + ' To ' + strB + (blnDown ? ' Step -1' : ''), intLine);
				return;

			case 'while':
				strA = condition(intLine);
				out('Do While ' + ((strA === null) ? '0' : strA), intLine);
				openBlock('do', 'Loop', intLine);
				return;

			case 'forever':
				out('Do', intLine);
				openBlock('do', 'Loop', intLine);
				return;

			case 'leave':
				for (intK = arrBlocks.length - 1; intK >= 0; intK--)
				{
					if (arrBlocks[intK].kind !== 'if') { break; }
				}
				if (intK < 0 || arrBlocks[intK].kind === 'sub') { error(intLine, 'leave is not inside a loop'); return; }
				out((arrBlocks[intK].kind === 'for') ? 'Exit For' : 'Exit Do', intLine);
				return;

			default:
				if (objBuiltIn[objT.lc])
				{
					error(intLine, shown(objT) + ' is not the start of a sentence');
					return;
				}
				// a word of the program's: a Sub of the project, a verb of the context's class, or a
				// Sub from elsewhere (the compiler says when there is none)
				if (!Object.prototype.hasOwnProperty.call(objSubs, objT.lc) && objT.v.indexOf('.') < 0 && ctxClass())
				{
					objM = memberAt(-1, false);
					if (!objM)
					{
						if (memberAt(-1, true)) { error(intLine, shown(objT) + ' is a value of the ' + objCtx.cls.toLowerCase() + '\'s, not something to do (say ' + objT.v + ')'); }
						else { error(intLine, shown(objT) + ' is not a ' + objCtx.cls.toLowerCase() + ' word (' + objCtx.cls.toLowerCase() + ' has: ' + wordsOf(ctxClass()) + ')'); }
						return;
					}
					intPos += objM.n - 1;
					arrOps = memberArgs(objM.m, intLine);
					if (arrOps !== null) { out((objCtx.cls + '.' + objM.m.name + ' ' + arrOps.join(', ')).replace(/\s+$/, ''), intLine); }
					return;
				}
				while (operandNext())
				{
					strA = operand(objT.lc, intLine, false);
					if (strA === null) { return; }
					arrOps.push(strA);
				}
				if (Object.prototype.hasOwnProperty.call(objSubs, objT.lc) || objT.v.indexOf('.') >= 0)
				{
					out(((objSubs[objT.lc] || objT.v) + ' ' + arrOps.join(', ')).replace(/\s+$/, ''), intLine);
				}
				else if (objCtx)
				{
					out((objCtx.cls + '.' + proper(objT.v) + ' ' + idArgs().concat(arrOps).join(', ')).replace(/\s+$/, ''), intLine);
				}
				else
				{
					out((proper(objT.v) + ' ' + arrOps.join(', ')).replace(/\s+$/, ''), intLine);
				}
				return;
		}
	}

	// the natural text gathered so far, as VB lines
	function flush()
	{
		var intWas = 0;

		intPos = 0;
		while (intPos < arrItems.length)
		{
			intWas = arrErrors.length;
			sentence();
			if (arrErrors.length > intWas)
			{
				// after a mistake: on to the next word that starts a sentence (one message a mistake)
				// (a "to" counts when it is the first word of its line: a word of your own being made)
				while (intPos < arrItems.length && !(arrItems[intPos].k === 'w' && (objStarts[arrItems[intPos].lc] || (arrItems[intPos].lc === 'to' && (intPos === 0 || arrItems[intPos - 1].line !== arrItems[intPos].line))))) { intPos++; }
			}
		}
		arrItems = [];
	}

	// ---------------------------------------------------------------- the file, line by line
	for (intI = 0; intI < arrSrc.length; intI++)
	{
		strLine = arrSrc[intI];
		if (strMode === 'asm')
		{
			out(strLine, intI + 1);
			if (/^\s*#endasm\b/i.test(strLine)) { strMode = 'nat'; }
			continue;
		}
		if (strMode === 'vb')
		{
			if (blnWhole && /^\s*#endntc\b/i.test(strLine)) { strMode = 'nat'; out('', intI + 1); continue; }
			if (!blnWhole && /^\s*#natural\b/i.test(strLine)) { strMode = 'nat'; out('', intI + 1); continue; }
			if (blnWhole && /^\s*#ntc\b/i.test(strLine)) { error(intI + 1, '#ntc inside #ntc'); }
			if (!blnWhole && /^\s*#endnatural\b/i.test(strLine)) { error(intI + 1, '#endnatural without #natural'); }
			if (/^\s*(?:'#\s*)?option\s+flavour\b/i.test(strLine)) { out('', intI + 1); continue; }
			noteVb(strLine);
			out(strLine, intI + 1);
			continue;
		}
		// natural
		arrM = strLine.match(/^\s*#(\w+)\b/);
		if (arrM)
		{
			flush();
			switch (arrM[1].toLowerCase())
			{
				case 'ntc':
					if (!blnWhole) { error(intI + 1, '#ntc is for a file that is natural all through (Option Flavour Natural): here #endnatural ends the natural part'); }
					strMode = 'vb';
					out('', intI + 1);
					break;
				case 'endnatural':
					if (blnWhole) { error(intI + 1, '#endnatural without #natural (the file is natural all through: #ntc ... #endntc is the plain part)'); }
					strMode = 'vb';
					out('', intI + 1);
					break;
				case 'asm':
					strMode = 'asm';
					out(strLine, intI + 1);
					break;
				case 'endntc':
				case 'endasm':
				case 'natural':
					error(intI + 1, '#' + arrM[1] + ' is out of place here');
					break;
				default:
					out(strLine, intI + 1);		// #If, #Const ...: the compiler's
					break;
			}
			continue;
		}
		if (/^\s*(?:'#\s*)?option\s+flavour\b/i.test(strLine)) { out('', intI + 1); continue; }
		if (/^\s*(?:'#\s*)?option\s+\w+/i.test(strLine))
		{
			flush();
			out(strLine.replace(/^(\s*)'#\s*/, '$1'), intI + 1);		// an NTC option, as it is
			continue;
		}
		tokens(strLine, intI + 1);
	}
	flush();
	if (strMode === 'asm') { error(arrSrc.length, '#asm is not closed (#endasm)'); }
	if (strMode === 'vb' && blnWhole) { error(arrSrc.length, '#ntc is not closed (#endntc)'); }
	if (strMode === 'nat' && !blnWhole) { error(arrSrc.length, '#natural is not closed (#endnatural)'); }
	arrBlocks.forEach(function(objB_a)
	{
		error(objB_a.line, 'this ' + ((objB_a.kind === 'if') ? 'if' : ((objB_a.kind === 'sub') ? 'to' : 'loop')) + ' has no end');
	});

	return { text: arrOut.join('\n'), lines: arrMap, cls: false, errors: arrErrors, warnings: [] };
}
