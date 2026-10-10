// ── Constants ────────────────────────────────────────────────────────────────

var HEX_DUMP_MAX_MB = 10;

// ── State ─────────────────────────────────────────────────────────────────────

var m_arrFiles           = [];
var m_objListRenderer    = null;
var m_strDeepRenderedID  = null;
var m_strSelID           = null;
var m_strSelTab          = 'summary';

var m_arrListFields = [
    { code: 'ID',    caption: 'ID',        type: 'STRING', visible: false, sortable: false },
    { code: 'EXT',   caption: 'Type',       type: 'STRING', visible: true,  sortable: true  },
    { code: 'NAME',  caption: 'File Name',  type: 'STRING', visible: true,  sortable: true  },
    { code: 'SIZE',  caption: 'Size',        type: 'STRING', visible: false,  sortable: false },
    { code: 'LINES', caption: 'Lines',       type: 'NUMBER', visible: true,  sortable: true  }
];

var m_objFileFieldIdx = { ID: 0, EXT: 1, NAME: 2, SIZE: 3, LINES: 4 };

// ── Binary extension list ─────────────────────────────────────────────────────

var m_arrBinaryExts = ['bin', 'exe', 'dll', 'pdf', 'zip', 'rar',
                        'bmp', 'gif', 'jpg', 'jpeg', 'png', 'ico', 'webp',
                        'mp3', 'mp4', 'wav', 'ogg', 'flac'];

function isBinaryExt(strExt_a)
{
    return m_arrBinaryExts.indexOf(strExt_a.toLowerCase()) >= 0;
}

function buildAllRows()
{
    return m_arrFiles.map(function(objF)
    {
        var intLines = objF.content ? objF.content.split('\n').length : 0;
        var strSize  = objF.size > 1024 ? (objF.size / 1024).toFixed(1) + ' KB' : objF.size + ' B';
        return [ objF.id, objF.ext.toUpperCase(), objF.name, strSize, intLines ];
    });
}

function calcFileListPageSize()
{
    var intH    = os.element('#ge-main', '.ge-filelist-container').height() || 400;
    var intRows = Math.floor((intH - 41 - 53) / 41);
    return Math.max(intRows, 5);
}

function clearFiles()
{
    m_arrFiles           = [];
    m_strSelID           = null;
    m_objListRenderer    = null;
    m_strDeepRenderedID  = null;
    showEmpty();
    renderFileList();
}

function deleteFile(strID_a)
{
    m_arrFiles = m_arrFiles.filter(function(objF) { return objF.id !== strID_a; });

    if (m_strSelID === strID_a)
    {
        m_strSelID = null;
        showEmpty();
    }

    m_objListRenderer.refresh();
}

function fileListBuildResponse(intOffset_a, intLimit_a, strSearch_a, arrOrder_a)
{
    var arrAll = buildAllRows();

    if (strSearch_a.length > 0)
    {
        var strLower = strSearch_a.toLowerCase();
        arrAll = arrAll.filter(function(arrR)
        {
            return String(arrR[1] || '').toLowerCase().indexOf(strLower) >= 0 ||
                   String(arrR[2] || '').toLowerCase().indexOf(strLower) >= 0 ||
                   String(arrR[3] || '').toLowerCase().indexOf(strLower) >= 0 ||
                   String(arrR[4] || '').toLowerCase().indexOf(strLower) >= 0;
        });
    }

    if (arrOrder_a.length > 0)
    {
        arrAll.sort(function(arrA, arrB)
        {
            var intResult = 0;
            for (var intS = 0; intS < arrOrder_a.length; intS++)
            {
                if (intResult === 0)
                {
                    var intIdx = m_objFileFieldIdx[arrOrder_a[intS].fieldname];
                    if (intIdx !== undefined)
                    {
                        var varA   = arrA[intIdx];
                        var varB   = arrB[intIdx];
                        var numA   = parseFloat(varA);
                        var numB   = parseFloat(varB);
                        var intCmp;
                        if (!isNaN(numA) && !isNaN(numB))
                        {
                            intCmp = numA - numB;
                        }
                        else
                        {
                            var strA = String(varA || '').toLowerCase();
                            var strB = String(varB || '').toLowerCase();
                            intCmp = strA < strB ? -1 : strA > strB ? 1 : 0;
                        }
                        if (intCmp !== 0) { intResult = arrOrder_a[intS].ascending ? intCmp : -intCmp; }
                    }
                }
            }
            return intResult;
        });
    }

    var intTotal = arrAll.length;
    var arrPaged = arrAll.slice(intOffset_a, intOffset_a + intLimit_a);
    var blnMore  = (intOffset_a + intLimit_a) < intTotal;

    return {
        control:    { offset: intOffset_a, limit: intLimit_a, more: blnMore, total: intTotal },
        operations: [{ code: 'DELETE', caption: '✕ Remove', requiresselection: true }],
        fields:     m_arrListFields,
        data:       arrPaged
    };
}

function fileListLoadData(objRequest_a, cbResult_a)
{
    var intOffset = 0;
    var intLimit  = 20;
    var strSearch = '';
    var arrOrder  = [];

    for (var intI = 0; intI < objRequest_a.parameters.length; intI++)
    {
        var objParam = objRequest_a.parameters[intI];
        if (objParam.name === 'offset') { intOffset = parseInt(objParam.value, 10) || 0; }
        if (objParam.name === 'limit')  { intLimit  = parseInt(objParam.value, 10) || 20; }
        if (objParam.name === 'search') { strSearch = objParam.value || ''; }
        if (objParam.name === 'order')  { try { arrOrder = JSON.parse(objParam.value) || []; } catch(objE) {} }
    }

    cbResult_a(fileListBuildResponse(intOffset, intLimit, strSearch, arrOrder));
}

function handleFiles(objFileList_a)
{
    var arrNew     = Array.from(objFileList_a);
    var intTotal   = arrNew.length;
    var intPending = intTotal;

    if (intTotal > 0)
    {
        os.element('#ge-progress-bar').removeClass('gb-hidden');
        os.element('#ge-progress-bar', '.ge-progress-fill').css('width', '0%');

        arrNew.forEach(function(objFile)
        {
            var strExt    = objFile.name.split('.').pop().toLowerCase();
            var objReader = new FileReader();

            objReader.onload = function(objEvent)
            {
                var strID = 'f-' + Date.now() + '-' + Math.random().toString(36).substr(2, 6);

                m_arrFiles.push({
                    id:      strID,
                    name:    objFile.name,
                    ext:     strExt,
                    size:    objFile.size,
                    content: objEvent.target.result
                });

                intPending--;

                var intPct = Math.round(((intTotal - intPending) / intTotal) * 100);
                os.element('#ge-progress-bar', '.ge-progress-fill').css('width', intPct + '%');

                if (intPending === 0)
                {
                    setTimeout(function() { os.element('#ge-progress-bar').addClass('gb-hidden'); }, 400);
                    renderFileList();
                }
            };

            if (isBinaryExt(strExt))
            {
                objReader.readAsBinaryString(objFile);
            }
            else
            {
                objReader.readAsText(objFile);
            }
        });
    }
}

function parseCode(strType_a, strContent_a)
{
    var objP = null;

    if (isBinaryExt(strType_a))
    {
        objP = {
            totalLines:   0,
            codeLines:    0,
            commentLines: 0,
            blankLines:   0,
            headerLines:  0,
            dimCount:     0,
            constCount:   0,
            routines:     [],
            subCount:     0,
            funcCount:    0,
            propCount:    0
        };
    }
    else if (strType_a === 'js' || strType_a === 'mjs' || strType_a === 'cjs')
    {
        objP = parseJS(strContent_a);
    }
    else if (strType_a === 'php')
    {
        objP = parsePHP(strContent_a);
    }
    else
    {
        objP = parseVB6(strContent_a);
    }

    return objP;
}

function renderAnalysis()
{
    if (!m_strSelID)
    {
        showEmpty();
    }
    else
    {
        var objFile = null;
        for (var intI = 0; intI < m_arrFiles.length; intI++)
        {
            if (m_arrFiles[intI].id === m_strSelID) { objFile = m_arrFiles[intI]; }
        }

        if (!objFile)
        {
            showEmpty();
        }
        else
        {
            os.element('#ge-main', '.ge-tabs').removeClass('gb-hidden');
            showTabBody(m_strSelTab);

            if (m_strSelTab === 'summary') { renderSummary(objFile); }
            if (m_strSelTab === 'deep'    && m_strDeepRenderedID !== m_strSelID) { renderDeep(objFile); }
            if (m_strSelTab === 'raw')     { renderRaw(objFile);     }
            if (m_strSelTab === 'render')  { renderRender(objFile);  }
        }
    }
}

function renderDeep(objFile_a)
{
    m_strDeepRenderedID = objFile_a.id;

    var objP = parseCode(objFile_a.ext, objFile_a.content);

    if (objP.routines.length === 0)
    {
        os.element('#ge-main', '.ge-tab-body-deep').html(
            '<div class="gs-empty">' +
            '<div class="gs-empty-icon">📄</div>' +
            '<p>No Sub / Function / Property routines detected in this file.</p>' +
            '</div>');
    }
    else
    {
        var arrSorted = objP.routines.slice().sort(function(objA, objB)
        {
            return (objB.endLine - objB.startLine) - (objA.endLine - objA.startLine);
        });

        var strHTML = '<div class="gs-deep-output">';
        strHTML += '<p class="gs-deep-hint text-muted mb-3">Click a row to jump to that routine. Click the routine header to expand source.</p>';
        strHTML += '<div id="ge-deep-list-container" class="mb-3"></div>';

        arrSorted.forEach(function(objR, intIdx)
        {
            var intLineCount = objR.endLine - objR.startLine + 1;
            var strCode = objR.lines.map(function(strLine, intI)
            {
                return (objR.startLine + intI) + '\t' + strLine;
            }).join('\n');

            strHTML +=
                '<div class="gs-sub-block" id="ge-deep-anchor-' + intIdx + '">' +
                    '<div class="gs-sub-block-header">' +
                        '<span class="gs-sub-kind ' + objR.kind + '">' + objR.kind + '</span>' +
                        '<span class="gs-sub-name">' + htmlEncode(objR.name) + '</span>' +
                        '<span class="gs-sub-args">' + htmlEncode(objR.args) + '</span>' +
                        '<span class="gs-sub-lines">' +
                            '<strong>' + intLineCount + '</strong> lines &nbsp;|&nbsp; ' +
                            objR.access + ' &nbsp;|&nbsp; line ' + objR.startLine +
                        '</span>' +
                        '<button class="gs-toggle-btn">▾ source</button>' +
                    '</div>' +
                    '<pre class="gs-sub-block-code collapsed">' + htmlEncode(strCode) + '</pre>' +
                '</div>';
        });

        strHTML += '</div>';
        os.element('#ge-main', '.ge-tab-body-deep').html(strHTML);

        os.element('#ge-main', '.ge-tab-body-deep .gs-sub-block-header').bind('click', toggleBlock);

        var objListData = {
            control:    { offset: 0, limit: 9999, more: false, total: arrSorted.length },
            operations: [],
            fields: [
                { code: 'IDX',    caption: '#',           type: 'NUMBER', visible: true,  sortable: false },
                { code: 'KIND',   caption: 'Kind',         type: 'STRING', visible: true,  sortable: true  },
                { code: 'ACCESS', caption: 'Access',       type: 'STRING', visible: true,  sortable: true  },
                { code: 'NAME',   caption: 'Name',         type: 'STRING', visible: true,  sortable: true  },
                { code: 'ARGS',   caption: 'Arguments',    type: 'STRING', visible: true,  sortable: false },
                { code: 'START',  caption: 'Start Line',   type: 'NUMBER', visible: true,  sortable: true  },
                { code: 'COUNT',  caption: 'Line Count',   type: 'NUMBER', visible: true,  sortable: true  }
            ],
            data: arrSorted.map(function(objR, intIdx)
            {
                return [
                    intIdx + 1,
                    objR.kind.toUpperCase(),
                    objR.access,
                    objR.name,
                    objR.args,
                    objR.startLine,
                    objR.endLine - objR.startLine + 1
                ];
            })
        };

        var arrDeepRows   = objListData.data;
        var arrDeepFields = objListData.fields;
        var objDeepIdx    = { IDX: 0, KIND: 1, ACCESS: 2, NAME: 3, ARGS: 4, START: 5, COUNT: 6 };

        function deepLoadData(objRequest_a, cbResult_a)
        {
            var strSearch = '';
            var arrOrder  = [];

            for (var intI = 0; intI < objRequest_a.parameters.length; intI++)
            {
                var objParam = objRequest_a.parameters[intI];
                if (objParam.name === 'search') { strSearch = objParam.value || ''; }
                if (objParam.name === 'order')  { try { arrOrder = JSON.parse(objParam.value) || []; } catch(objE) {} }
            }

            var arrAll = arrDeepRows.slice();

            if (strSearch.length > 0)
            {
                var strLower = strSearch.toLowerCase();
                arrAll = arrAll.filter(function(arrR)
                {
                    return String(arrR[1] || '').toLowerCase().indexOf(strLower) >= 0 ||
                           String(arrR[2] || '').toLowerCase().indexOf(strLower) >= 0 ||
                           String(arrR[3] || '').toLowerCase().indexOf(strLower) >= 0 ||
                           String(arrR[4] || '').toLowerCase().indexOf(strLower) >= 0;
                });
            }

            if (arrOrder.length > 0)
            {
                arrAll.sort(function(arrA, arrB)
                {
                    var intResult = 0;
                    for (var intS = 0; intS < arrOrder.length; intS++)
                    {
                        if (intResult === 0)
                        {
                            var intIdx = objDeepIdx[arrOrder[intS].fieldname];
                            if (intIdx !== undefined)
                            {
                                var numA   = parseFloat(arrA[intIdx]);
                                var numB   = parseFloat(arrB[intIdx]);
                                var intCmp;
                                if (!isNaN(numA) && !isNaN(numB))
                                {
                                    intCmp = numA - numB;
                                }
                                else
                                {
                                    var strA = String(arrA[intIdx] || '').toLowerCase();
                                    var strB = String(arrB[intIdx] || '').toLowerCase();
                                    intCmp = strA < strB ? -1 : strA > strB ? 1 : 0;
                                }
                                if (intCmp !== 0) { intResult = arrOrder[intS].ascending ? intCmp : -intCmp; }
                            }
                        }
                    }
                    return intResult;
                });
            }

            cbResult_a({
                control:    { offset: 0, limit: 9999, more: false, total: arrAll.length },
                operations: [],
                fields:     arrDeepFields,
                data:       arrAll
            });
        }

        new listRenderer(api, 'ge-deep-list-container', {
            type:        'LIST',
            flow:        'EXPAND',
            target:      '',
            initialData: objListData,
            cbLoadData:  deepLoadData,
            cbOnClick:   function(arrRow)
            {
                var intIdx    = arrRow[0] - 1;
                var objAnchor = document.getElementById('ge-deep-anchor-' + intIdx);
                if (objAnchor)
                {
                    objAnchor.scrollIntoView({ behavior: 'instant', block: 'start' });
                }
            }
        });
    }
}

function renderFileList()
{
    if (!m_objListRenderer)
    {
        var intPageSize = calcFileListPageSize();
        var objInitial  = fileListBuildResponse(0, intPageSize, '', []);

		var strGUID = getGUID();
		os.element('#ge-main', '.ge-filelist-container').attr('id', strGUID);
        m_objListRenderer = new listRenderer(api, strGUID, {
            type:             'LIST',
            flow:             'PAGED',
            target:           '',
            initialData:      objInitial,
            cbLoadData:       fileListLoadData,
            allowdragdrop:    true,
            cbOnDragDropItem: function(objFiles)
            {
                handleFiles(objFiles);
            },
            cbOnClick:        function(arrRow, strID)
            {
                m_strDeepRenderedID = null;
                m_strSelID = strID;
                renderAnalysis();
            },
            cbOnOperation:    function(strOperation, arrRow, strID)
            {
                if (strOperation === 'DELETE')
                {
                    deleteFile(strID);
                }
            }
        });
    }
    else
    {
        m_objListRenderer.refresh();
    }
}

function renderHexDump(objFile_a, strSize_a)
{
    var intMaxBytes    = HEX_DUMP_MAX_MB * 1024 * 1024;
    var strRaw         = objFile_a.content;
    var intTotal       = Math.min(strRaw.length, intMaxBytes);
    var blnTruncated   = strRaw.length > intMaxBytes;
    var intBytesPerRow = 16;
    var strRows        = '';

    for (var intOffset = 0; intOffset < intTotal; intOffset += intBytesPerRow)
    {
        var strHex   = '';
        var strAscii = '';
        var intEnd   = Math.min(intOffset + intBytesPerRow, intTotal);

        for (var intI = intOffset; intI < intEnd; intI++)
        {
            var intByte = strRaw.charCodeAt(intI) & 0xFF;
            var strByte = intByte.toString(16).toUpperCase();
            if (strByte.length === 1) { strByte = '0' + strByte; }
            strHex += strByte + ' ';

            if (intByte >= 32 && intByte < 127)
            {
                strAscii += String.fromCharCode(intByte);
            }
            else
            {
                strAscii += '.';
            }
        }

        while (strHex.length < intBytesPerRow * 3) { strHex += '   '; }

        var strOffsetHex = intOffset.toString(16).toUpperCase();
        while (strOffsetHex.length < 8) { strOffsetHex = '0' + strOffsetHex; }

        strRows += strOffsetHex + '  ' + strHex + ' ' + htmlEncode(strAscii) + '\n';
    }

    os.element('#ge-main', '.ge-tab-body-raw').html(
        '<div class="gs-raw-output">' +
            '<p class="gs-raw-info text-muted mb-2">' +
                htmlEncode(objFile_a.name) + ' &mdash; ' + strSize_a +
                (blnTruncated ? ' &mdash; <em>showing first ' + HEX_DUMP_MAX_MB + ' MB</em>' : '') +
            '</p>' +
            '<pre class="gs-hex-dump">' + strRows + '</pre>' +
        '</div>');
}

function renderRaw(objFile_a)
{
    var strSize   = objFile_a.size > 1024 ? (objFile_a.size / 1024).toFixed(1) + ' KB' : objFile_a.size + ' B';
    var blnBinary = isBinaryExt(objFile_a.ext);

    if (blnBinary)
    {
        renderHexDump(objFile_a, strSize);
    }
    else
    {
        var arrLines    = objFile_a.content.split('\n');
        var intLines    = arrLines.length;
        var intPadWidth = String(intLines).length;
        var strNumbered = arrLines.map(function(strLine, intI)
        {
            var strNum = String(intI + 1);
            while (strNum.length < intPadWidth) { strNum = ' ' + strNum; }
            return strNum + '\t' + strLine;
        }).join('\n');

        os.element('#ge-main', '.ge-tab-body-raw').html(
            '<div class="gs-raw-output">' +
                '<p class="gs-raw-info text-muted mb-2">' +
                    htmlEncode(objFile_a.name) + ' &mdash; ' + intLines + ' lines &mdash; ' + strSize +
                '</p>' +
                '<pre>' + htmlEncode(strNumbered) + '</pre>' +
            '</div>');
    }
}

function renderRender(objFile_a)
{
    var arrImageExts = ['jpg', 'jpeg', 'png', 'gif', 'bmp', 'ico', 'webp', 'svg'];
    var strExt       = objFile_a.ext.toLowerCase();
    var strBody      = '';

    if (arrImageExts.indexOf(strExt) >= 0)
    {
        var strSrc = '';

        if (strExt === 'svg')
        {
            strSrc = 'data:image/svg+xml;charset=utf-8,' + encodeURIComponent(objFile_a.content);
        }
        else if (strExt === 'ico')
        {
            strSrc = 'data:image/x-icon;base64,' + btoa(objFile_a.content);
        }
        else
        {
            strSrc = 'data:image/' + (strExt === 'jpg' ? 'jpeg' : strExt) + ';base64,' + btoa(objFile_a.content);
        }

        strBody  = '<div class="gs-render-wrap">';
        strBody += '<img class="ge-render-img gs-render-img" src="' + strSrc + '">';
        strBody += '<p class="ge-render-error gs-render-error gb-hidden">Could not render image.</p>';
        strBody += '</div>';
    }
    else
    {
        strBody  = '<div class="gs-empty">';
        strBody += '<div class="gs-render-none-icon">🚫</div>';
        strBody += '<p class="gs-render-none-text">No render available for .' + htmlEncode(objFile_a.ext) + ' files.</p>';
        strBody += '</div>';
    }

    os.element('#ge-main', '.ge-tab-body-render').html(strBody);

    if (arrImageExts.indexOf(strExt) >= 0)
    {
        os.element('#ge-main', '.ge-render-img').bind('error', function()
        {
            os.element(this).addClass('gb-hidden');
            os.element('#ge-main', '.ge-render-error').removeClass('gb-hidden');
        });
    }
}

function renderSummary(objFile_a)
{
    var objP    = parseCode(objFile_a.ext, objFile_a.content);
    var strSize = objFile_a.size > 1024 ? (objFile_a.size / 1024).toFixed(1) + ' KB' : objFile_a.size + ' B';

    var strLongest = '—';
    var intMax = 0;
    objP.routines.forEach(function(objR)
    {
        var intLen = objR.endLine - objR.startLine + 1;
        if (intLen > intMax) { intMax = intLen; strLongest = objR.name + ' (' + intLen + ' lines)'; }
    });

    var strCards1 =
        '<div class="gs-stat-grid">' +
            statCard(objP.totalLines,   'Total Lines')   +
            statCard(objP.codeLines,    'Code Lines')    +
            statCard(objP.commentLines, 'Comment Lines') +
            statCard(objP.blankLines,   'Blank Lines')   +
            statCard(strSize,           'File Size')     +
        '</div>';

    var strCards2 =
        '<div class="gs-stat-grid">' +
            statCard(objP.routines.length, 'Total Routines') +
            statCard(objP.subCount,        'Subs')           +
            statCard(objP.funcCount,       'Functions')      +
            statCard(objP.propCount,       'Properties')     +
            statCard(objP.dimCount,        'Declarations')   +
        '</div>';

    var arrSections = [
        {
            id: 'sec-file', caption: 'File Information',
            containers: [{
                id: 'con-file', type: 'verticalcontainer', name: 'FILEINFO', caption: '',
                children: [
                    { id: 'f1', type: 'textbox', name: 'FILENAME', label: 'File Name', value: objFile_a.name,               readonly: true },
                    { id: 'f2', type: 'textbox', name: 'FILETYPE', label: 'File Type', value: objFile_a.ext.toUpperCase(),  readonly: true },
                    { id: 'f3', type: 'textbox', name: 'FILESIZE', label: 'File Size', value: strSize,                      readonly: true }
                ]
            }]
        },
        {
            id: 'sec-code', caption: 'Code Metrics',
            containers: [{
                id: 'con-code', type: 'verticalcontainer', name: 'CODEMETRICS', caption: '',
                children: [
                    { id: 'g1', type: 'number', name: 'TOTALLINES',   label: 'Total Lines',           value: objP.totalLines,   readonly: true },
                    { id: 'g2', type: 'number', name: 'CODELINES',    label: 'Code Lines',            value: objP.codeLines,    readonly: true },
                    { id: 'g3', type: 'number', name: 'COMMENTLINES', label: 'Comment Lines',         value: objP.commentLines, readonly: true },
                    { id: 'g4', type: 'number', name: 'BLANKLINES',   label: 'Blank Lines',           value: objP.blankLines,   readonly: true },
                    { id: 'g7', type: 'number', name: 'HEADERLINES',  label: 'Form Header Lines',     value: objP.headerLines,  readonly: true },
                    { id: 'g5', type: 'number', name: 'DIMCOUNT',     label: 'Variable Declarations', value: objP.dimCount,     readonly: true },
                    { id: 'g6', type: 'number', name: 'CONSTCOUNT',   label: 'Constants',             value: objP.constCount,   readonly: true }
                ]
            }]
        },
        {
            id: 'sec-routines', caption: 'Routines',
            containers: [{
                id: 'con-routines', type: 'verticalcontainer', name: 'ROUTINES', caption: '',
                children: [
                    { id: 'h1', type: 'number',  name: 'TOTALROUTINES',  label: 'Total Routines',  value: objP.routines.length, readonly: true },
                    { id: 'h2', type: 'number',  name: 'SUBCOUNT',       label: 'Subs',            value: objP.subCount,        readonly: true },
                    { id: 'h3', type: 'number',  name: 'FUNCCOUNT',      label: 'Functions',       value: objP.funcCount,       readonly: true },
                    { id: 'h4', type: 'number',  name: 'PROPCOUNT',      label: 'Properties',      value: objP.propCount,       readonly: true },
                    { id: 'h5', type: 'textbox', name: 'LONGESTROUTINE', label: 'Largest Routine', value: strLongest,           readonly: true }
                ]
            }]
        }
    ];

    var strTargetClass = 'ge-summary-form-target';

    os.element('#ge-main', '.ge-tab-body-summary').html(
        strCards1 + strCards2 +
        '<div id="ge-summary-handler" class="gscr-formrenderer-handler">' +
            '<div class="' + strTargetClass + '"></div>' +
        '</div>');

    new formRenderer(os, 'ge-summary-handler', {
        layoutSections: arrSections,
        target:         strTargetClass,
        readonly:       true
    });
}

function showEmpty()
{
    os.element('#ge-main', '.ge-tabs').addClass('gb-hidden');
    os.element('#ge-main', '.ge-tab-body-empty').html(
        '<div class="ge-analysis-dropzone gs-empty-dropzone">' +
        '<div class="gs-empty-icon">📂</div>' +
        '<p><strong>Drop files here to analyse</strong></p>' +
        '<p class="gs-empty-sub">or use the bar above — then click a file to begin</p>' +
        '</div>');
    os.element('#ge-main', '.ge-tab-body').addClass('gb-hidden');
    os.element('#ge-main', '.ge-tab-body-empty').removeClass('gb-hidden');
}

function showTabBody(strTab_a)
{
    os.element('#ge-main', '.ge-tab-body').addClass('gb-hidden');
    os.element('#ge-main', '.ge-tab-body-' + strTab_a).removeClass('gb-hidden');
}

function statCard(varValue_a, strLabel_a)
{
    return '<div class="gs-stat-card">' +
               '<div class="gs-stat-value">' + varValue_a + '</div>' +
               '<div class="gs-stat-label">' + strLabel_a + '</div>' +
           '</div>';
}

function switchTab(strTab_a)
{
    m_strSelTab = strTab_a;
    os.element('#ge-main', '.ge-tab-btn').removeClass('gs-active');
	os.element('#ge-main', '.ge-tab-' + m_strSelTab).addClass('gs-active');
    renderAnalysis();
}

function toggleBlock(objEvent_a)
{
    var objPre = os.element(this).siblings('.gs-sub-block-code');
    var objBtn = os.element(this, '.gs-toggle-btn');

    if (objPre.hasClass('collapsed'))
    {
        objPre.removeClass('collapsed');
        objBtn.text('▴ source');
    }
    else
    {
        objPre.addClass('collapsed');
        objBtn.text('▾ source');
    }
}

function loadBundle(objFile_a)
{
    var objReader = new FileReader();

    objReader.onload = function(objEvent)
    {
        var objBundle = null;
        var strError  = '';

        try
        {
            objBundle = JSON.parse(objEvent.target.result);
        }
        catch (objE)
        {
            strError = 'Invalid bundle file.';
        }

        if (strError === '' && (!objBundle || !Array.isArray(objBundle.files)))
        {
            strError = 'Invalid bundle format.';
        }

        if (strError !== '')
        {
            alert(strError);
        }
        else
        {
            var intTotal  = objBundle.files.length;
            var arrLoaded = [];

            os.element('#ge-progress-bar').removeClass('gb-hidden');
            os.element('#ge-progress-bar', '.ge-progress-fill').css('width', '0%');

            for (var intI = 0; intI < intTotal; intI++)
            {
                var objF = objBundle.files[intI];

                arrLoaded.push({
                    id:      objF.id,
                    name:    objF.name,
                    ext:     objF.ext,
                    size:    objF.size,
                    content: decodeURIComponent(escape(atob(objF.content)))
                });

                var intPct = Math.round(((intI + 1) / intTotal) * 100);
                os.element('#ge-progress-bar', '.ge-progress-fill').css('width', intPct + '%');
            }

            m_arrFiles           = arrLoaded;
            m_strSelID           = null;
            m_objListRenderer    = null;
            m_strDeepRenderedID  = null;

            setTimeout(function()
            {
                os.element('#ge-progress-bar').addClass('gb-hidden');
                showEmpty();
                renderFileList();
            }, 400);
        }
    };

    objReader.readAsText(objFile_a);
}

function saveBundle()
{
    var intTotal  = m_arrFiles.length;
    var arrBundle = [];

    os.element('#ge-progress-bar').removeClass('gb-hidden');
    os.element('#ge-progress-bar', '.ge-progress-fill').css('width', '0%');

    for (var intI = 0; intI < intTotal; intI++)
    {
        var objF = m_arrFiles[intI];

        arrBundle.push({
            id:      objF.id,
            name:    objF.name,
            ext:     objF.ext,
            size:    objF.size,
            content: btoa(unescape(encodeURIComponent(objF.content)))
        });

        var intPct = Math.round(((intI + 1) / intTotal) * 100);
        os.element('#ge-progress-bar', '.ge-progress-fill').css('width', intPct + '%');
    }

    var strJSON = JSON.stringify({ version: 1, files: arrBundle }, null, 2);
    var objBlob = new Blob([strJSON], { type: 'application/json' });
    var strURL  = URL.createObjectURL(objBlob);

    var objA    = document.createElement('a');
    objA.href     = strURL;
    objA.download = 'bundle.json';
    document.body.appendChild(objA);
    objA.click();
    document.body.removeChild(objA);
    URL.revokeObjectURL(strURL);

    setTimeout(function() { os.element('#ge-progress-bar').addClass('gb-hidden'); }, 400);
}

