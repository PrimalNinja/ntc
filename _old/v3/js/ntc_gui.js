// tinyz80b GUI - realtime BASIC to NTC. ES5.
// (c) 2026 Cyborg Unicorn Pty Ltd - MIT License

var api = {
	element: function(strScope_a, strClass_a)
	{
		if (arguments.length === 1)
		{
			return $(strScope_a);
		}
		else
		{
			return $(strClass_a, strScope_a);
		}
	}
};

var NTC_EXAMPLES = [
	{
		name: 'Syntax guide',
		code: [
			"' tinyz80b - BASIC to NTC (Native Threaded Code) for Z80",
			"' type on the left, the NTC thread appears on the right",
			"'",
			"' numbers   16 bit signed, 123 &HFF &FF #FF &X101 TRUE FALSE",
			"' strings   name$ or any var given \"text\" / INPUT, 40 chars",
			"' operators - (unary)  * / \\ MOD  + -  = <> < <= > >=  NOT  AND  OR XOR",
			"'           true is -1, AND/OR/XOR/NOT are bitwise (work as logical too)",
			"' functions ABS() SGN() RND(n) PEEK() DEEK() LEN(s$) INKEY",
			"' arrays    DIM a(10) - 0 to 10, 16 bit",
			"' flow      IF/THEN/ELSE (one line), IF THEN / ELSEIF / ELSE / END IF",
			"'           WHILE/WEND  DO [WHILE|UNTIL]/LOOP [WHILE|UNTIL]  EXIT DO|FOR|WHILE",
			"'           FOR/TO/STEP/NEXT  GOTO  GOSUB/RETURN  END  STOP",
			"'           labels: name:  or line numbers",
			"' I/O       PRINT ; ,   INPUT [\"prompt\";] v   CLS  LOCATE x,y  MODE n  FRAME",
			"' memory    POKE a,v  DOKE a,v  RANDOMIZE n",
			"'           CALL addr - machine code run as a keyword: SP is the thread,",
			"'           no call/push, end with ret",
			"' screen    no firmware: mode 1 at start, MODE 0/1/2 clears, text is ZOSCII",
			"' debug     BREAK name - puts dw bp_name in the thread (bp_name: ret)",
			"' comments  REM or '",
			"",
			"CLS",
			"INPUT \"Your name\"; n$",
			"PRINT \"Hello \"; n$",
			"FOR i = 1 TO 10",
			"  IF i MOD 3 = 0 THEN PRINT \"fizz \"; ELSE PRINT i; \" \";",
			"NEXT",
			"PRINT",
			"BREAK done",
			"END"
		].join('\n')
	},
	{
		name: 'Original input.txt',
		code: [
			"CLS",
			"INPUT name",
			"PRINT \"Welcome\"",
			"PRINT name",
			"counter = 0",
			"a = 2",
			"WHILE counter * 2 < 3 * 3",
			"PRINT \"Looping\"",
			"counter = counter + 1",
			"WEND",
			"IF counter = 3 + a THEN PRINT \"Done\" ELSE PRINT \"Error\"",
			"END"
		].join('\n')
	},
	{
		name: 'Primes (sieve)',
		code: [
			"' sieve of Eratosthenes",
			"DIM s(1000)",
			"n = 1000",
			"FOR i = 2 TO n : s(i) = 1 : NEXT",
			"i = 2",
			"WHILE i * i <= n",
			"  IF s(i) THEN",
			"    FOR j = i * i TO n STEP i : s(j) = 0 : NEXT",
			"  END IF",
			"  i = i + 1",
			"WEND",
			"c = 0",
			"FOR i = 2 TO n",
			"  IF s(i) THEN PRINT i; \" \"; : c = c + 1",
			"NEXT",
			"PRINT : PRINT c; \" primes\"",
			"END"
		].join('\n')
	},
	{
		name: 'Guess the number',
		code: [
			"RANDOMIZE 1234",
			"again:",
			"t = RND(100) + 1 : tries = 0",
			"PRINT \"I picked 1 to 100\"",
			"DO",
			"  INPUT \"Guess\"; g",
			"  tries = tries + 1",
			"  IF g < t THEN",
			"    PRINT \"Higher\"",
			"  ELSEIF g > t THEN",
			"    PRINT \"Lower\"",
			"  END IF",
			"LOOP UNTIL g = t",
			"PRINT \"Got it in \"; tries",
			"INPUT \"Again (y/n)\"; a$",
			"IF a$ = \"y\" THEN GOTO again",
			"END"
		].join('\n')
	},
	{
		name: 'Numbered GOSUB',
		code: [
			"10 REM classic numbered style",
			"20 N = 1",
			"30 PRINT N;",
			"40 N = N * 2",
			"50 IF N < 100 THEN 30",
			"60 PRINT",
			"70 GOSUB 200",
			"80 END",
			"200 PRINT \"in sub\" : RETURN"
		].join('\n')
	}
];

var m_objInput = null;
var m_objOutput = null;
var m_strAsm = '';
var m_intTimer = 0;

function ntcOptions()
{
	return {
		platform: $('#ge-platform').val(),
		org: $('#ge-org').val(),
		library: $('#ge-library').val(),
		sourcecomments: $('#ge-comments').is(':checked')
	};
}

function ntcShowErrors(arrErrors_a)
{
	var objErrors = $('#ge-errors');
	var intI = 0;
	var objRow = null;

	objErrors.empty();
	for (intI = 0; intI < arrErrors_a.length; intI++)
	{
		objRow = $('<div></div>');
		objRow.text('ERROR: ' + arrErrors_a[intI].msg + ((arrErrors_a[intI].line > 0) ? (' at line ' + arrErrors_a[intI].line) : ''));
		objRow.attr('data-line', arrErrors_a[intI].line);
		objErrors.append(objRow);
	}
}

// select a line in the BASIC editor
function ntcGotoLine(intLine_a)
{
	var objText = $('#ge-input .ge-texteditor-code');
	var arrLines = objText.val().split('\n');
	var intI = 0;
	var intStart = 0;
	var intLineHeight = 0;
	var objNode = objText.get(0);

	if (intLine_a < 1 || !objNode)
	{
		return;
	}

	for (intI = 0; (intI < intLine_a - 1) && (intI < arrLines.length); intI++)
	{
		intStart += arrLines[intI].length + 1;
	}

	objNode.focus();
	objNode.setSelectionRange(intStart, intStart + ((intLine_a - 1 < arrLines.length) ? arrLines[intLine_a - 1].length : 0));
	intLineHeight = parseFloat(objText.css('line-height')) || 19;
	objNode.scrollTop = Math.max(0, (intLine_a - 5) * intLineHeight);
}

function ntcCompileNow()
{
	var dblStart = new Date().getTime();
	var objResult = ntcCompile(m_objInput.getValue(), ntcOptions());
	var strView = objResult.asm;
	var intCut = 0;
	var objCode = $('#ge-output .ge-texteditor-code');
	var intScroll = objCode.scrollTop();

	m_strAsm = objResult.asm;

	if ($('#ge-hidelib').is(':checked'))
	{
		intCut = strView.indexOf('; Keyword library');
		if (intCut > -1)
		{
			strView = strView.substr(0, strView.lastIndexOf('\n', intCut - 2)) + '\n\n; (library hidden - included in Copy / Save)';
		}
	}

	m_objOutput.setValue(strView);
	objCode.scrollTop(intScroll);

	ntcShowErrors(objResult.errors);
	$('#ge-stats').text(objResult.stats.threadbytes + ' thread bytes, ' + objResult.stats.keywords + ' keywords, ' +
		objResult.stats.variables + ' vars, ' + objResult.stats.temps + ' temps');
	$('#ge-time').text('compiled in ' + (new Date().getTime() - dblStart) + ' ms');
}

function ntcRecompile()
{
	if (m_intTimer)
	{
		clearTimeout(m_intTimer);
	}
	m_intTimer = setTimeout(function()
	{
		m_intTimer = 0;
		ntcCompileNow();
	}, 30);
}

function ntcSave()
{
	var objBlob = new Blob([m_strAsm], { type: 'text/plain' });
	var objLink = document.createElement('a');
	var strURL = URL.createObjectURL(objBlob);

	objLink.href = strURL;
	objLink.download = 'ntc.asm';
	document.body.appendChild(objLink);
	objLink.click();
	document.body.removeChild(objLink);
	URL.revokeObjectURL(strURL);
}

function ntcCopy()
{
	var objTemp = null;

	if (navigator.clipboard && navigator.clipboard.writeText)
	{
		navigator.clipboard.writeText(m_strAsm);
	}
	else
	{
		objTemp = $('<textarea></textarea>').val(m_strAsm).appendTo('body');
		objTemp.get(0).select();
		document.execCommand('copy');
		objTemp.remove();
	}
}

function ntcInit()
{
	var intI = 0;
	var strSaved = null;
	var objSelect = $('#ge-example');

	for (intI = 0; intI < NTC_EXAMPLES.length; intI++)
	{
		objSelect.append($('<option></option>').val(intI).text(NTC_EXAMPLES[intI].name));
	}

	try
	{
		strSaved = window.localStorage.getItem('tinyz80b_source');
	}
	catch (objError)
	{
		strSaved = null;
	}

	m_objInput = new textEditor(api, 'ge-input',
	{
		mode: 'CODE',
		language: 'sql',
		rows: 20,
		placeholder: 'Type BASIC here...',
		initialvalue: (strSaved !== null) ? strSaved : NTC_EXAMPLES[0].code,
		showlinenumbers: true,
		allowload: true,
		allowsave: true,
		filename: 'program.bas',
		cbOnChange: function(strValue_a)
		{
			try
			{
				window.localStorage.setItem('tinyz80b_source', strValue_a);
			}
			catch (objError)
			{
				// storage not available, nothing to do
			}
			ntcRecompile();
		}
	});

	m_objOutput = new textEditor(api, 'ge-output',
	{
		mode: 'CODE',
		readonly: true,
		rows: 20,
		showstatus: false,
		showlinenumbers: false,
		initialvalue: ''
	});

	objSelect.on('change', function()
	{
		m_objInput.setValue(NTC_EXAMPLES[parseInt(objSelect.val(), 10)].code);
		try
		{
			window.localStorage.setItem('tinyz80b_source', m_objInput.getValue());
		}
		catch (objError)
		{
			// storage not available, nothing to do
		}
		ntcRecompile();
	});

	$('#ge-platform, #ge-library, #ge-comments, #ge-hidelib').on('change', ntcRecompile);
	$('#ge-org').on('input change', ntcRecompile);
	$('#ge-save').on('click', ntcSave);
	$('#ge-copy').on('click', ntcCopy);
	$('#ge-errors').on('click', 'div', function()
	{
		ntcGotoLine(parseInt($(this).attr('data-line'), 10));
	});

	// tab key inserts a tab in the BASIC editor
	$('#ge-input').on('keydown', '.ge-texteditor-code', function(objEvent_a)
	{
		var objNode = this;
		var intStart = 0;
		var intEnd = 0;

		if (objEvent_a.key === 'Tab')
		{
			objEvent_a.preventDefault();
			intStart = objNode.selectionStart;
			intEnd = objNode.selectionEnd;
			objNode.value = objNode.value.substring(0, intStart) + '\t' + objNode.value.substring(intEnd);
			objNode.selectionStart = objNode.selectionEnd = intStart + 1;
			$(objNode).trigger('input');
		}
	});

	ntcRecompile();
}

$(ntcInit);
