// ── JS Parser (VB6 Contract) ────────────────────────────────────────────────

function stripJSLine(strLine_a)
{
    var strResult = '';
    var strQuote  = '';
    var intI      = 0;
    var intLen    = strLine_a.length;

    while (intI < intLen)
    {
        var strChar = strLine_a.charAt(intI);
        var strNext = strLine_a.charAt(intI + 1);

        if (strQuote !== '')
        {
            if (strChar === '\\')
            {
                strResult += strChar;
                if (strNext !== '{' && strNext !== '}') { strResult += strNext; }
                intI++;
            }
            else
            {
                if (strChar === strQuote) { strQuote = ''; }
                if (strChar !== '{' && strChar !== '}') { strResult += strChar; }
            }
        }
        else if (strChar === '/' && strNext === '/')
        {
            intI = intLen;
        }
        else if (strChar === '/' && strNext === '*')
        {
            var intEnd = strLine_a.indexOf('*/', intI + 2);
            if (intEnd < 0) { intI = intLen; } else { intI = intEnd + 1; }
        }
        else
        {
            if (strChar === '"' || strChar === "'" || strChar === '`') { strQuote = strChar; }
            strResult += strChar;
        }

        intI++;
    }

    return strResult;
}

function parseJS(strContent_a)
{
    var arrLines     = strContent_a.split('\n');
    var arrRoutines  = [];
    var arrStack     = [];

    var intCodeLines    = 0;
    var intCommentLines = 0;
    var intBlankLines   = 0;
    var intDimCount     = 0;      // var/let/const declarations
    var intConstCount   = 0;      // const declarations only

    var reFuncStart         = /^\s*(?:export\s+)?(?:async\s+)?function\s*\*?\s*(\w+)\s*\(([^)]*)\)?/i;
    var reArrowFunc         = /^\s*(?:const|let|var)\s+(\w+)\s*=\s*(?:async\s*)?\(?([^)=]*)\)?\s*=>/i;
    var reArrowOpenEnd      = /=>\s*$/;
    var reVarDeclare        = /^\s*(?:var|let|const)\s+/i;
    var reConstDeclare      = /^\s*const\s+/i;
    var reComment           = /^\s*\/\//;
    var reMultiCommentStart = /^\s*\/\*/;
    var reMultiCommentEnd   = /\*\/\s*$/;

    var blnInMultiComment = false;
    var intBraceDepth     = 0;

    function closeRoutine(intEndLine_a)
    {
        var objTop = arrStack.pop();
        objTop.routine.endLine = intEndLine_a;
        objTop.routine.lines   = arrLines.slice(objTop.routine.startLine - 1, intEndLine_a);
        arrRoutines.push(objTop.routine);
    }

    for (var intIdx = 0; intIdx < arrLines.length; intIdx++)
    {
        var strLine    = arrLines[intIdx];
        var strTrimmed = strLine.trim();

        if (reMultiCommentStart.test(strTrimmed))
        {
            blnInMultiComment = true;
            intCommentLines++;
            if (reMultiCommentEnd.test(strTrimmed)) { blnInMultiComment = false; }
        }
        else if (blnInMultiComment)
        {
            intCommentLines++;
            if (reMultiCommentEnd.test(strTrimmed)) { blnInMultiComment = false; }
        }
        else if (strTrimmed === '')
        {
            intBlankLines++;
        }
        else if (reComment.test(strTrimmed))
        {
            intCommentLines++;
        }
        else
        {
            intCodeLines++;

            if (reVarDeclare.test(strTrimmed))   { intDimCount++;   }
            if (reConstDeclare.test(strTrimmed))  { intConstCount++; }

            var objFuncMatch  = reFuncStart.exec(strTrimmed);
            var objArrowMatch = objFuncMatch ? null : reArrowFunc.exec(strTrimmed);
            var objMatch      = objFuncMatch || objArrowMatch;
            var strCode       = stripJSLine(strLine);

            if (objMatch)
            {
                arrStack.push({
                    openDepth: -1,
                    routine: {
                        name:      objMatch[1],
                        kind:      'func',
                        access:    'Public',
                        args:      '(' + (objMatch[2] || '') + ')',
                        startLine: intIdx + 1,
                        endLine:   intIdx + 1,
                        lines:     []
                    }
                });
            }

            for (var intI = 0; intI < strCode.length; intI++)
            {
                var strChar = strCode.charAt(intI);

                if (strChar === '{')
                {
                    if (arrStack.length > 0 && arrStack[arrStack.length - 1].openDepth < 0)
                    {
                        arrStack[arrStack.length - 1].openDepth = intBraceDepth;
                    }
                    intBraceDepth++;
                }
                else if (strChar === '}')
                {
                    intBraceDepth--;
                    if (arrStack.length > 0 && arrStack[arrStack.length - 1].openDepth === intBraceDepth)
                    {
                        closeRoutine(intIdx + 1);
                    }
                }
            }

            // arrow with an expression body (no brace) ends on its own line
            if (objArrowMatch && arrStack.length > 0 && arrStack[arrStack.length - 1].openDepth < 0 && !reArrowOpenEnd.test(strCode))
            {
                closeRoutine(intIdx + 1);
            }
        }
    }

    while (arrStack.length > 0)
    {
        closeRoutine(arrLines.length);
    }

    return {
        totalLines:   arrLines.length,
        codeLines:    intCodeLines,
        commentLines: intCommentLines,
        blankLines:   intBlankLines,
        headerLines:  0,
        dimCount:     intDimCount,
        constCount:   intConstCount,
        routines:     arrRoutines,
        subCount:     arrRoutines.filter(function(objR) { return objR.kind === 'sub';  }).length,
        funcCount:    arrRoutines.filter(function(objR) { return objR.kind === 'func'; }).length,
        propCount:    arrRoutines.filter(function(objR) { return objR.kind === 'prop'; }).length
    };
}
