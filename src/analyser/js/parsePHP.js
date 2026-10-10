// ── PHP Parser (VB6 Contract) ────────────────────────────────────────────────

function scanPHPLine(strLine_a, blnInPhp_a)
{
    var objResult = { code: '', inPhp: blnInPhp_a, hasTag: false };
    var strQuote  = '';
    var intI      = 0;
    var intLen    = strLine_a.length;

    while (intI < intLen)
    {
        var strChar = strLine_a.charAt(intI);
        var strNext = strLine_a.charAt(intI + 1);

        if (!objResult.inPhp)
        {
            if (strLine_a.substr(intI, 5).toLowerCase() === '<?php')
            {
                objResult.inPhp  = true;
                objResult.hasTag = true;
                intI += 4;
            }
            else if (strLine_a.substr(intI, 3) === '<?=')
            {
                objResult.inPhp  = true;
                objResult.hasTag = true;
                intI += 2;
            }
        }
        else if (strQuote !== '')
        {
            if (strChar === '\\')
            {
                objResult.code += strChar;
                if (strNext !== '{' && strNext !== '}') { objResult.code += strNext; }
                intI++;
            }
            else
            {
                if (strChar === strQuote) { strQuote = ''; }
                if (strChar !== '{' && strChar !== '}') { objResult.code += strChar; }
            }
        }
        else if (strChar === '?' && strNext === '>')
        {
            objResult.inPhp  = false;
            objResult.hasTag = true;
            intI++;
        }
        else if ((strChar === '/' && strNext === '/') || strChar === '#')
        {
            // a line comment ends at the end of the line or at ?>
            var intClose = strLine_a.indexOf('?>', intI);
            if (intClose < 0) { intI = intLen; } else { intI = intClose - 1; }
        }
        else if (strChar === '/' && strNext === '*')
        {
            var intEnd = strLine_a.indexOf('*/', intI + 2);
            if (intEnd < 0) { intI = intLen; } else { intI = intEnd + 1; }
        }
        else
        {
            if (strChar === '"' || strChar === "'") { strQuote = strChar; }
            objResult.code += strChar;
        }

        intI++;
    }

    return objResult;
}

function getPHPArgs(strText_a)
{
    var strArgs  = '()';
    var intStart = strText_a.indexOf('(');
    var intDepth = 0;
    var blnDone  = false;
    var strQuote = '';

    if (intStart >= 0)
    {
        for (var intI = intStart; intI < strText_a.length && !blnDone; intI++)
        {
            var strChar = strText_a.charAt(intI);

            if (strQuote !== '')
            {
                if (strChar === '\\')        { intI++; }
                else if (strChar === strQuote) { strQuote = ''; }
            }
            else if (strChar === '"' || strChar === "'")
            {
                strQuote = strChar;
            }
            else if (strChar === '(')
            {
                intDepth++;
            }
            else if (strChar === ')')
            {
                intDepth--;
                if (intDepth === 0)
                {
                    strArgs = strText_a.substring(intStart, intI + 1);
                    blnDone = true;
                }
            }
        }

        if (!blnDone) { strArgs = strText_a.substring(intStart); }
    }

    return strArgs;
}

function parsePHP(strContent_a)
{
    var arrLines     = strContent_a.split('\n');
    var arrRoutines  = [];
    var arrStack     = [];
    var objGlobalSeen = {};
    var objSeen      = objGlobalSeen;

    var intCodeLines    = 0;
    var intCommentLines = 0;
    var intBlankLines   = 0;
    var intDimCount     = 0;      // distinct variables declared/first assigned per scope
    var intConstCount   = 0;      // const/define declarations

    var reFuncStart         = /^\s*((?:(?:public|private|protected|static|abstract|final)\s+)*)function\s+&?\s*(\w+)/i;
    var reAssign            = /\$(\w+)\s*=(?![=>])/g;
    var reDeclKeyword       = /^\s*(?:global|static|var|public|private|protected)\b/i;
    var reFunctionWord      = /\bfunction\b/i;
    var reVarName           = /\$(\w+)/g;
    var reForeach           = /\bas\s+\$(\w+)(?:\s*=>\s*&?\$(\w+))?/gi;
    var reConstDef          = /^\s*(?:define\s*\(|const\s+)/i;
    var reComment           = /^\s*\/\//;
    var reSingleComment     = /^\s*#/;
    var reMultiCommentStart = /^\s*\/\*/;
    var reMultiCommentEnd   = /\*\/\s*$/;
    var reEndsStatement     = /;\s*$/;

    var blnInMultiComment = false;
    var blnInPhpBlock     = false;
    var intBraceDepth     = 0;

    function countVar(strName_a)
    {
        // replace() passes the match offset (a number) after the groups - ignore it
        if (typeof strName_a === 'string' && strName_a !== '' && strName_a !== 'this' && !objSeen.hasOwnProperty(strName_a))
        {
            objSeen[strName_a] = true;
            intDimCount++;
        }
    }

    function countVarMatch(strAll_a, strName1_a, strName2_a)
    {
        countVar(strName1_a);
        countVar(strName2_a);
        return strAll_a;
    }

    function closeRoutine(intEndLine_a)
    {
        var objTop = arrStack.pop();
        objTop.routine.endLine = intEndLine_a;
        objTop.routine.lines   = arrLines.slice(objTop.routine.startLine - 1, intEndLine_a);
        arrRoutines.push(objTop.routine);
        objSeen = arrStack.length > 0 ? arrStack[arrStack.length - 1].seen : objGlobalSeen;
    }

    for (var intIdx = 0; intIdx < arrLines.length; intIdx++)
    {
        var strLine     = arrLines[intIdx];
        var strTrimmed  = strLine.trim();
        var blnWasInPhp = blnInPhpBlock;

        if (blnInMultiComment)
        {
            intCommentLines++;
            if (reMultiCommentEnd.test(strTrimmed)) { blnInMultiComment = false; }
        }
        else if (strTrimmed === '')
        {
            intBlankLines++;
        }
        else
        {
            var objScan = scanPHPLine(strLine, blnInPhpBlock);
            var strCode = objScan.code.trim();
            blnInPhpBlock = objScan.inPhp;

            if (blnWasInPhp && !objScan.hasTag && reMultiCommentStart.test(strTrimmed))
            {
                intCommentLines++;
                if (!reMultiCommentEnd.test(strTrimmed)) { blnInMultiComment = true; }
            }
            else if (blnWasInPhp && !objScan.hasTag && (reComment.test(strTrimmed) || reSingleComment.test(strTrimmed)))
            {
                intCommentLines++;
            }
            else if (strCode !== '')
            {
                intCodeLines++;

                if (reConstDef.test(strCode)) { intConstCount++; }

                var objFuncMatch = reFuncStart.exec(strCode);
                if (objFuncMatch)
                {
                    var strMods   = objFuncMatch[1].toLowerCase();
                    var strAccess = 'Public';
                    if (/\bprivate\b/.test(strMods))   { strAccess = 'Private';   }
                    if (/\bprotected\b/.test(strMods)) { strAccess = 'Protected'; }
                    if (/\bstatic\b/.test(strMods))    { strAccess += ' Static';  }

                    arrStack.push({
                        openDepth: -1,
                        seen:      {},
                        routine: {
                            name:      objFuncMatch[2],
                            kind:      'func',
                            access:    strAccess,
                            args:      getPHPArgs(strCode.substring(objFuncMatch[0].length)),
                            startLine: intIdx + 1,
                            endLine:   intIdx + 1,
                            lines:     []
                        }
                    });
                    objSeen = arrStack[arrStack.length - 1].seen;
                }

                if (reDeclKeyword.test(strCode) && !reFunctionWord.test(strCode))
                {
                    strCode.split('=')[0].replace(reVarName, countVarMatch);
                }
                strCode.replace(reAssign, countVarMatch);
                strCode.replace(reForeach, countVarMatch);

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

                // abstract / interface methods have no body
                if (objFuncMatch && arrStack.length > 0 && arrStack[arrStack.length - 1].openDepth < 0 && reEndsStatement.test(strCode))
                {
                    closeRoutine(intIdx + 1);
                }
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
