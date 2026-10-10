// ── VB6 Parser ────────────────────────────────────────────────────────────────

function getVB6Args(strText_a)
{
    var strArgs  = '()';
    var intStart = strText_a.indexOf('(');
    var intDepth = 0;
    var blnDone  = false;
    var blnInStr = false;

    if (intStart >= 0)
    {
        for (var intI = intStart; intI < strText_a.length && !blnDone; intI++)
        {
            var strChar = strText_a.charAt(intI);

            if (strChar === '"')
            {
                blnInStr = !blnInStr;
            }
            else if (!blnInStr && strChar === '(')
            {
                intDepth++;
            }
            else if (!blnInStr && strChar === ')')
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

function getVB6HeaderEnd(arrLines_a)
{
    var intHeaderEnd  = -1;
    var intBeginDepth = 0;
    var blnHeader     = true;
    var reBegin       = /^(Begin|BeginProperty)(\s|$)/i;
    var reEnd         = /^(End|EndProperty)$/i;
    var reHeaderLine  = /^(VERSION\s|Object\s*=|Attribute\s+VB_)/i;

    for (var intH = 0; intH < arrLines_a.length && blnHeader; intH++)
    {
        var strH = arrLines_a[intH].trim();

        if (intBeginDepth > 0)
        {
            if (reBegin.test(strH))    { intBeginDepth++; }
            else if (reEnd.test(strH)) { intBeginDepth--; }
            intHeaderEnd = intH;
        }
        else if (reBegin.test(strH))
        {
            intBeginDepth++;
            intHeaderEnd = intH;
        }
        else if (reHeaderLine.test(strH))
        {
            intHeaderEnd = intH;
        }
        else
        {
            blnHeader = false;
        }
    }

    return intHeaderEnd;
}

function parseVB6(strContent_a)
{
    var arrLines     = strContent_a.split('\n');
    var arrRoutines  = [];
    var objCurrent   = null;
    var intHeaderEnd = getVB6HeaderEnd(arrLines);

    var intCodeLines    = 0;
    var intCommentLines = 0;
    var intBlankLines   = 0;
    var intHeaderLines  = 0;
    var intDimCount     = 0;
    var intConstCount   = 0;

    var reSubStart = /^\s*(Public\s+|Private\s+|Friend\s+)?(Static\s+)?(Sub|Function|Property\s+(?:Get|Let|Set))\s+(\w+)/i;
    var reSubEnd   = /^\s*End\s+(Sub|Function|Property)\s*$/i;
    var reDim      = /^\s*(?:Dim|ReDim|Static(?!\s+(?:Sub|Function|Property)\b)|(?:Public|Private|Global)(?!\s+(?:Static\s+)?(?:Sub|Function|Property|Const|Declare|Event|Enum|Type)\b))\s+/i;
    var reConst    = /^\s*(?:(?:Public|Private|Global)\s+)?Const\s+/i;
    var reComment  = /^\s*'/;
    var reContinue = /\s_$/;

    arrLines.forEach(function(strLine, intIdx)
    {
        var strTrimmed = strLine.trim();

        if (intIdx <= intHeaderEnd)
        {
            intHeaderLines++;
        }
        else if (strTrimmed === '')
        {
            intBlankLines++;
        }
        else
        {
            if (reComment.test(strTrimmed)) { intCommentLines++; } else { intCodeLines++; }
            if (reDim.test(strTrimmed))     { intDimCount++;   }
            if (reConst.test(strTrimmed))   { intConstCount++; }

            var objMatch = reSubStart.exec(strTrimmed);
            if (objMatch)
            {
                if (objCurrent)
                {
                    objCurrent.endLine = intIdx;
                    objCurrent.lines   = arrLines.slice(objCurrent.startLine - 1, intIdx);
                    arrRoutines.push(objCurrent);
                }

                var strJoined = strTrimmed;
                var intJ      = intIdx;
                while (reContinue.test(strJoined) && intJ + 1 < arrLines.length)
                {
                    intJ++;
                    strJoined = strJoined.replace(reContinue, ' ') + arrLines[intJ].trim();
                }

                var strAccess = (objMatch[1] || '').trim() || 'Public';
                var strKind   = objMatch[3].replace(/\s+/g, ' ').toLowerCase();
                var strName   = objMatch[4];
                var strArgs   = getVB6Args(strJoined.substring(objMatch[0].length));

                if (strKind.indexOf('property') >= 0) { strKind = 'prop'; }
                else if (strKind === 'function')       { strKind = 'func'; }
                else                                   { strKind = 'sub';  }

                objCurrent = {
                    name:      strName,
                    kind:      strKind,
                    access:    strAccess,
                    args:      strArgs,
                    startLine: intIdx + 1,
                    endLine:   intIdx + 1,
                    lines:     []
                };
            }
            else if (reSubEnd.test(strTrimmed) && objCurrent)
            {
                objCurrent.endLine = intIdx + 1;
                objCurrent.lines   = arrLines.slice(objCurrent.startLine - 1, intIdx + 1);
                arrRoutines.push(objCurrent);
                objCurrent = null;
            }
        }
    });

    if (objCurrent)
    {
        objCurrent.endLine = arrLines.length;
        objCurrent.lines   = arrLines.slice(objCurrent.startLine - 1);
        arrRoutines.push(objCurrent);
    }

    return {
        totalLines:   arrLines.length,
        codeLines:    intCodeLines,
        commentLines: intCommentLines,
        blankLines:   intBlankLines,
        headerLines:  intHeaderLines,
        dimCount:     intDimCount,
        constCount:   intConstCount,
        routines:     arrRoutines,
        subCount:     arrRoutines.filter(function(objR) { return objR.kind === 'sub';  }).length,
        funcCount:    arrRoutines.filter(function(objR) { return objR.kind === 'func'; }).length,
        propCount:    arrRoutines.filter(function(objR) { return objR.kind === 'prop'; }).length
    };
}
