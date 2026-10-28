/**
 * Minimal Text Editor - Metadata-driven text editor for Cyborg Designer forms
 * (c) 2026 Cyborg Unicorn Pty Ltd.
 * MIT License
 *
 * Design philosophy:
 * - Metadata-driven configuration
 * - Simple, deterministic behavior
 * - Works with existing jQuery/Bootstrap stack
 * - Can render to target or return HTML
 * - No hidden magic, no auto-save, no bloat
 *
 * Modes: TEXTAREA, INPUT, RICH, CODE
 */

function textEditor(objAPI_a, strFormID_a, objParameters_a)
{
    var m_objThis = this;
    var api = objAPI_a;
    var m_strFormID = strFormID_a;
    var m_objParameters = objParameters_a || {};

    // Generate unique GUID for this instance
    function getGUID()
    {
        return 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, function(strChar_a)
        {
            var intR = Math.random() * 16 | 0;
            var intV = strChar_a === 'x' ? intR : (intR & 0x3 | 0x8);
            return intV.toString(16);
        });
    }

    function htmlEncode(strValue_a)
    {
        var strResult = strValue_a || '';
        strResult = String(strResult).replace(/&/g, '&amp;');
        strResult = strResult.replace(/</g, '&lt;');
        strResult = strResult.replace(/>/g, '&gt;');
        strResult = strResult.replace(/"/g, '&quot;');
        strResult = strResult.replace(/'/g, '&#39;');
        return strResult;
    }

    var m_strInstanceGUID = getGUID();

    // Parameters
    var m_strTarget = m_objParameters.target || '';
    var m_strPlaceholder = m_objParameters.placeholder || 'Enter text here...';
    var m_intRows = m_objParameters.rows || 5;
    var m_blnReadOnly = m_objParameters.readonly || false;
    var m_blnAllowFormatting = m_objParameters.allowformatting || false;
    var m_strInitialValue = m_objParameters.initialvalue || '';
    var m_strMode = m_objParameters.mode || 'TEXTAREA'; // 'TEXTAREA', 'INPUT', 'RICH', 'CODE'
    var m_strLanguage = m_objParameters.language || 'javascript';
    var m_blnShowLineNumbers = m_objParameters.showlinenumbers !== false;

    // Callbacks
    var m_cbOnChange = m_objParameters.cbOnChange || null;
    var m_cbOnSave = m_objParameters.cbOnSave || null;
    var m_cbOnOperation = m_objParameters.cbOnOperation || null;

    // Operations toolbar (same pattern as listRenderer)
    var m_arrOperations = m_objParameters.operations || [];

    // File operation flags
    var m_blnAllowLoad = m_objParameters.allowload !== false;
    var m_blnAllowSave = m_objParameters.allowsave !== false;
    var m_blnShowStatus = m_objParameters.showstatus !== false;

    // State
    var m_strCurrentValue = m_strInitialValue;
    var m_objCurrentFileHandle = null;

    // ============================================
    // RENDERING
    // ============================================

    function renderToolbar()
    {
        var strHTML = '<div class="ge-texteditor-toolbar gs-texteditor-toolbar" style="display: flex; gap: 5px; margin-bottom: 8px; flex-wrap: wrap;">';

        // Code mode specific controls
        if (m_strMode === 'CODE' && !m_blnReadOnly)
        {
            strHTML += '<select class="form-select form-select-sm ge-texteditor-code-language" style="width: auto; font-size: 12px; padding: 4px 8px;">';
            strHTML += '<option value="javascript" ' + (m_strLanguage === 'javascript' ? 'selected' : '') + '>JavaScript</option>';
            strHTML += '<option value="html" ' + (m_strLanguage === 'html' ? 'selected' : '') + '>HTML</option>';
            strHTML += '<option value="css" ' + (m_strLanguage === 'css' ? 'selected' : '') + '>CSS</option>';
            strHTML += '<option value="json" ' + (m_strLanguage === 'json' ? 'selected' : '') + '>JSON</option>';
            strHTML += '<option value="python" ' + (m_strLanguage === 'python' ? 'selected' : '') + '>Python</option>';
            strHTML += '<option value="sql" ' + (m_strLanguage === 'sql' ? 'selected' : '') + '>SQL</option>';
            strHTML += '</select>';
            strHTML += '<button type="button" class="btn btn-sm btn-outline-secondary ge-texteditor-format-code" title="Format Code">\uD83D\uDD27 Format</button>';
        }

        // Rich text formatting
        if (m_blnAllowFormatting && m_strMode === 'RICH' && !m_blnReadOnly)
        {
            strHTML += '<button type="button" class="btn btn-sm btn-outline-secondary ge-texteditor-format-bold" title="Bold (Ctrl+B)"><strong>B</strong></button>';
            strHTML += '<button type="button" class="btn btn-sm btn-outline-secondary ge-texteditor-format-italic" title="Italic (Ctrl+I)"><em>I</em></button>';
        }

        // File operations (only if not read-only)
        if (!m_blnReadOnly)
        {
            if (m_blnAllowLoad)
            {
                strHTML += '<button type="button" class="btn btn-sm btn-outline-secondary ge-texteditor-load" title="Load from file">\uD83D\uDCC2 Load</button>';
            }
            if (m_blnAllowSave)
            {
                strHTML += '<button type="button" class="btn btn-sm btn-outline-secondary ge-texteditor-save" title="Save to file">\uD83D\uDCBE Save</button>';
            }
        }

        // Custom save callback button
        if (m_cbOnSave && !m_blnReadOnly)
        {
            strHTML += '<button type="button" class="btn btn-sm btn-outline-primary ge-texteditor-save-callback" title="Save (Ctrl+S)">\u2728 Save Callback</button>';
        }

        // Operation buttons (same pattern as listRenderer)
        if (m_arrOperations.length > 0 && !m_blnReadOnly)
        {
            var intOpIndex = 0;
            for (intOpIndex = 0; intOpIndex < m_arrOperations.length; intOpIndex++)
            {
                var objOp = m_arrOperations[intOpIndex];
                strHTML += '<button type="button" class="btn btn-sm ' + (objOp.style || 'btn-outline-secondary') + ' ge-texteditor-operation ge-texteditor-op-' + objOp.code + '" data-operation="' + objOp.code + '">' + objOp.caption + '</button>';
            }
        }

        strHTML += '</div>';
        return strHTML;
    }

    function renderTextarea()
    {
        var strValue = htmlEncode(m_strCurrentValue);
        var strReadOnly = m_blnReadOnly ? ' readonly' : '';
        var strPlaceholder = htmlEncode(m_strPlaceholder);

        return '<textarea class="ge-texteditor-textarea gs-texteditor-textarea form-control" ' +
               'rows="' + m_intRows + '"' +
               ' placeholder="' + strPlaceholder + '"' +
               strReadOnly + '>' +
               strValue +
               '</textarea>';
    }

    function renderInput()
    {
        var strValue = htmlEncode(m_strCurrentValue);
        var strReadOnly = m_blnReadOnly ? ' readonly' : '';
        var strPlaceholder = htmlEncode(m_strPlaceholder);

        return '<input type="text" class="ge-texteditor-input gs-texteditor-input form-control" ' +
               'value="' + strValue + '"' +
               ' placeholder="' + strPlaceholder + '"' +
               strReadOnly + ' />';
    }

    function renderRichEditor()
    {
        var strValue = htmlEncode(m_strCurrentValue);
        var strReadOnly = m_blnReadOnly ? ' contenteditable="false"' : ' contenteditable="true"';
        var strPlaceholderAttr = m_blnReadOnly ? '' : ' data-placeholder="' + htmlEncode(m_strPlaceholder) + '"';

        return '<div class="ge-texteditor-rich gs-texteditor-rich form-control" ' +
               'style="min-height: ' + (m_intRows * 24) + 'px; overflow: auto; padding: 8px;"' +
               strReadOnly + strPlaceholderAttr + '>' +
               (strValue || (m_blnReadOnly ? '&nbsp;' : '<br>')) +
               '</div>';
    }

    function renderCodeEditor()
    {
        var strValue = m_strCurrentValue;
        var strReadOnly = m_blnReadOnly ? ' readonly' : '';
        var strPlaceholder = htmlEncode(m_strPlaceholder);

        var strHTML = '<div class="ge-texteditor-code-wrapper" style="position: relative; border: 1px solid #dee2e6; border-radius: 4px; background: #1e1e1e;">';

        if (m_blnShowLineNumbers && !m_blnReadOnly)
        {
            strHTML += '<div class="ge-texteditor-code-gutter" style="position: absolute; left: 0; top: 0; width: 45px; background: #252526; color: #858585; font-family: monospace; font-size: 13px; line-height: 1.5; padding: 8px 0; text-align: right; border-right: 1px solid #3e3e42; overflow: hidden;">';
            strHTML += '<div style="padding-right: 8px;">1</div>';
            strHTML += '</div>';
        }

        var strPaddingLeft = (m_blnShowLineNumbers && !m_blnReadOnly) ? 'padding-left: 55px;' : 'padding-left: 8px;';

        strHTML += '<textarea class="ge-texteditor-code form-control" ' +
                   'style="font-family: monospace; font-size: 13px; line-height: 1.5; background: #1e1e1e; color: #d4d4d4; ' + strPaddingLeft + ' border: none; resize: vertical;" ' +
                   'rows="' + m_intRows + '"' +
                   ' placeholder="' + strPlaceholder + '"' +
                   ' spellcheck="false"' +
                   strReadOnly + '>' +
                   htmlEncode(strValue) +
                   '</textarea>';

        strHTML += '</div>';

        return strHTML;
    }

    function renderStatusBar()
    {
        var intLength = m_strCurrentValue.length;
        var intLines = m_strCurrentValue.split(/\r?\n/).length;

        return '<div class="ge-texteditor-status gs-texteditor-status" style="display: flex; gap: 15px; margin-top: 8px; font-size: 12px; color: #6c757d;">' +
               '<span>\uD83D\uDCDD Characters: ' + intLength + '</span>' +
               '<span>\uD83D\uDCC4 Lines: ' + intLines + '</span>' +
               '</div>';
    }

    function renderAll()
    {
        var strHTML = '';

        strHTML += '<div class="ge-texteditor-container gs-texteditor-container" style="display: flex; flex-direction: column;">';

        // Toolbar (skip for readonly)
        if (!m_blnReadOnly)
        {
            strHTML += renderToolbar();
        }

        // Editor based on mode
        switch (m_strMode)
        {
            case 'INPUT':
                strHTML += renderInput();
                break;
            case 'RICH':
                strHTML += renderRichEditor();
                break;
            case 'CODE':
                strHTML += renderCodeEditor();
                break;
            default:
                strHTML += renderTextarea();
                break;
        }

        // Status bar
        if (m_blnShowStatus)
        {
            strHTML += renderStatusBar();
        }

        strHTML += '</div>';

        return strHTML;
    }

    // ============================================
    // HELPER FUNCTIONS
    // ============================================

    function updateStatusBar()
    {
        if (m_blnShowStatus)
        {
            var intLength = m_strCurrentValue.length;
            var intLines = m_strCurrentValue.split(/\r?\n/).length;
            var strContainerSelector = '#' + m_strFormID;

            api.element(strContainerSelector + ' .ge-texteditor-status span:first-child').text('\uD83D\uDCDD Characters: ' + intLength);
            api.element(strContainerSelector + ' .ge-texteditor-status span:last-child').text('\uD83D\uDCC4 Lines: ' + intLines);
        }
    }

    function updateLineNumbers()
    {
        if (m_blnShowLineNumbers && m_strMode === 'CODE')
        {
            var strContainerSelector = '#' + m_strFormID;
            var objCodeEditor = api.element(strContainerSelector + ' .ge-texteditor-code');
            var strContent = objCodeEditor.val();
            var arrLines = strContent.split(/\r?\n/);
            var intLineCount = arrLines.length;

            var strLineNumbers = '';
            for (var intI = 1; intI <= intLineCount; intI++)
            {
                strLineNumbers += '<div style="padding-right: 8px;">' + intI + '</div>';
            }

            api.element(strContainerSelector + ' .ge-texteditor-code-gutter').html(strLineNumbers);
        }
    }

    function formatCode(strCode_a, strLanguage_a)
    {
        var strResult = strCode_a;
        try
        {
            switch (strLanguage_a)
            {
                case 'json':
                    var objParsed = JSON.parse(strCode_a);
                    strResult = JSON.stringify(objParsed, null, 2);
                    break;
                case 'javascript':
                case 'html':
                case 'css':
                    // Simple indentation fix
                    strResult = strCode_a.replace(/\{\s*/g, '{\n  ').replace(/\}\s*/g, '\n}\n').replace(/,\s*/g, ',\n  ').replace(/\n\s*\n/g, '\n');
                    break;
                default:
                    break;
            }
        }
        catch (objError)
        {
            strResult = strCode_a;
        }
        return strResult;
    }

    function saveAs()
    {
        var strContent = m_strCurrentValue;
        var strExtension = 'txt';
        if (m_strMode === 'CODE')
        {
            switch (m_strLanguage)
            {
                case 'javascript': strExtension = 'js';   break;
                case 'html':       strExtension = 'html'; break;
                case 'css':        strExtension = 'css';  break;
                case 'json':       strExtension = 'json'; break;
                case 'python':     strExtension = 'py';   break;
                case 'sql':        strExtension = 'sql';  break;
                default:           break;
            }
        }

        var strFilename = m_objParameters.filename || ('document.' + strExtension);
        var objBlob = new Blob([strContent], {type: 'text/plain'});
        var objLink = document.createElement('a');
        var strURL = URL.createObjectURL(objBlob);

        objLink.href = strURL;
        objLink.download = strFilename;
        document.body.appendChild(objLink);
        objLink.click();
        document.body.removeChild(objLink);
        URL.revokeObjectURL(strURL);
    }

    function smartSave()
    {
        if (m_objCurrentFileHandle && 'showSaveFilePicker' in window)
        {
            m_objCurrentFileHandle.createWritable().then(function(objWritable)
            {
                return objWritable.write(m_strCurrentValue).then(function()
                {
                    return objWritable.close();
                }).then(function()
                {
                    showTemporaryStatus('\u2713 Saved to ' + m_objCurrentFileHandle.name);
                });
            })['catch'](function(objError)
            {
                console.error('Save failed:', objError);
                saveAs();
            });
        }
        else
        {
            saveAs();
        }
    }

    function showTemporaryStatus(strMessage_a)
    {
        var strContainerSelector = '#' + m_strFormID;
        var objStatus = api.element(strContainerSelector + ' .ge-texteditor-status');
        if (objStatus.length && m_blnShowStatus)
        {
            var strOriginalHTML = objStatus.html();
            objStatus.html('<span>\u2713 ' + strMessage_a + '</span>');
            setTimeout(function()
            {
                objStatus.html(strOriginalHTML);
            }, 2000);
        }
    }

    // ============================================
    // EVENT BINDING
    // ============================================

    function bindEvents()
    {
        var strContainerSelector = '#' + m_strFormID;

        // Unbind existing events
        api.element(strContainerSelector + ' .ge-texteditor-textarea').off('input change keyup');
        api.element(strContainerSelector + ' .ge-texteditor-input').off('input change keyup');
        api.element(strContainerSelector + ' .ge-texteditor-rich').off('blur keyup input');
        api.element(strContainerSelector + ' .ge-texteditor-code').off('input change keyup scroll');
        api.element(strContainerSelector + ' .ge-texteditor-format-bold').off('click');
        api.element(strContainerSelector + ' .ge-texteditor-format-italic').off('click');
        api.element(strContainerSelector + ' .ge-texteditor-save').off('click');
        api.element(strContainerSelector + ' .ge-texteditor-load').off('click');
        api.element(strContainerSelector + ' .ge-texteditor-save-callback').off('click');
        api.element(strContainerSelector + ' .ge-texteditor-code-language').off('change');
        api.element(strContainerSelector + ' .ge-texteditor-format-code').off('click');
        api.element(strContainerSelector + ' .ge-texteditor-operation').off('click');

        // TEXTAREA mode
        if (m_strMode === 'TEXTAREA')
        {
            var objTextarea = api.element(strContainerSelector + ' .ge-texteditor-textarea');
            objTextarea.on('input change', function()
            {
                var strNewValue = objTextarea.val();
                if (strNewValue !== m_strCurrentValue)
                {
                    m_strCurrentValue = strNewValue;
                    updateStatusBar();
                    if (m_cbOnChange)
                    {
                        m_cbOnChange(m_strCurrentValue);
                    }
                }
            });
        }

        // INPUT mode
        if (m_strMode === 'INPUT')
        {
            var objInput = api.element(strContainerSelector + ' .ge-texteditor-input');
            objInput.on('input change', function()
            {
                var strNewValue = objInput.val();
                if (strNewValue !== m_strCurrentValue)
                {
                    m_strCurrentValue = strNewValue;
                    updateStatusBar();
                    if (m_cbOnChange)
                    {
                        m_cbOnChange(m_strCurrentValue);
                    }
                }
            });
        }

        // RICH mode
        if (m_strMode === 'RICH')
        {
            var objRichEditor = api.element(strContainerSelector + ' .ge-texteditor-rich');

            objRichEditor.on('blur keyup input', function()
            {
                var strNewValue = objRichEditor.html();
                if (strNewValue === '<br>')
                {
                    strNewValue = '';
                }
                if (strNewValue !== m_strCurrentValue)
                {
                    m_strCurrentValue = strNewValue;
                    updateStatusBar();
                    if (m_cbOnChange)
                    {
                        m_cbOnChange(m_strCurrentValue);
                    }
                }
            });

            if (!m_blnReadOnly && m_blnAllowFormatting)
            {
                api.element(strContainerSelector + ' .ge-texteditor-format-bold').on('click', function()
                {
                    document.execCommand('bold', false, null);
                    objRichEditor.focus();
                });

                api.element(strContainerSelector + ' .ge-texteditor-format-italic').on('click', function()
                {
                    document.execCommand('italic', false, null);
                    objRichEditor.focus();
                });
            }
        }

        // CODE mode
        if (m_strMode === 'CODE')
        {
            var objCodeEditor = api.element(strContainerSelector + ' .ge-texteditor-code');

            objCodeEditor.on('input change', function()
            {
                var strNewValue = objCodeEditor.val();
                if (strNewValue !== m_strCurrentValue)
                {
                    m_strCurrentValue = strNewValue;
                    updateStatusBar();
                    if (m_blnShowLineNumbers)
                    {
                        updateLineNumbers();
                    }
                    if (m_cbOnChange)
                    {
                        m_cbOnChange(m_strCurrentValue);
                    }
                }
            });

            if (m_blnShowLineNumbers && !m_blnReadOnly)
            {
                objCodeEditor.on('scroll', function()
                {
                    var intScrollTop = objCodeEditor.scrollTop();
                    api.element(strContainerSelector + ' .ge-texteditor-code-gutter').scrollTop(intScrollTop);
                });
            }

            if (!m_blnReadOnly)
            {
                api.element(strContainerSelector + ' .ge-texteditor-code-language').on('change', function()
                {
                    m_strLanguage = api.element(this).val();
                    if (m_cbOnChange)
                    {
                        m_cbOnChange(m_strCurrentValue);
                    }
                });

                api.element(strContainerSelector + ' .ge-texteditor-format-code').on('click', function()
                {
                    var strFormatted = formatCode(m_strCurrentValue, m_strLanguage);
                    if (strFormatted !== m_strCurrentValue)
                    {
                        m_objThis.setValue(strFormatted);
                        if (m_cbOnChange)
                        {
                            m_cbOnChange(m_strCurrentValue);
                        }
                    }
                });
            }
        }

        // File operations (only if not read-only)
        if (!m_blnReadOnly)
        {
            // Load button
            api.element(strContainerSelector + ' .ge-texteditor-load').on('click', function()
            {
                var objFileInput = api.element('<input type="file" style="display: none;">');
                objFileInput.on('change', function(objEvent)
                {
                    var objFile = objEvent.target.files[0];
                    if (objFile)
                    {
                        var objReader = new FileReader();
                        objReader.onload = function(objLoadEvent)
                        {
                            var strContent = objLoadEvent.target.result;
                            m_objThis.setValue(strContent);
                            if (m_cbOnChange)
                            {
                                m_cbOnChange(strContent);
                            }
                        };
                        objReader.readAsText(objFile);
                    }
                });
                objFileInput.click();
            });

            // Save button
            if (m_blnAllowSave)
            {
                api.element(strContainerSelector + ' .ge-texteditor-save').on('click', function()
                {
                    smartSave();
                });
            }

            // Save callback button
            if (m_cbOnSave)
            {
                api.element(strContainerSelector + ' .ge-texteditor-save-callback').on('click', function()
                {
                    m_cbOnSave(m_strCurrentValue);
                });
            }
        }

        // Operation buttons
        if (m_arrOperations.length > 0 && m_cbOnOperation && !m_blnReadOnly)
        {
            api.element(strContainerSelector + ' .ge-texteditor-operation').on('click', function()
            {
                var strCode = api.element(this).data('operation');
                m_cbOnOperation(strCode, m_strCurrentValue);
            });
        }

        // Keyboard shortcuts (only if not read-only)
        if (!m_blnReadOnly)
        {
            api.element(strContainerSelector).on('keydown', function(objEvent)
            {
                if (objEvent.ctrlKey || objEvent.metaKey)
                {
                    switch (objEvent.key)
                    {
                        case 's':
                            objEvent.preventDefault();
                            if (m_cbOnSave)
                            {
                                m_cbOnSave(m_strCurrentValue);
                            }
                            else if (m_blnAllowSave)
                            {
                                smartSave();
                            }
                            break;
                        case 'b':
                            if (m_strMode === 'RICH' && m_blnAllowFormatting)
                            {
                                objEvent.preventDefault();
                                document.execCommand('bold', false, null);
                            }
                            break;
                        case 'i':
                            if (m_strMode === 'RICH' && m_blnAllowFormatting)
                            {
                                objEvent.preventDefault();
                                document.execCommand('italic', false, null);
                            }
                            break;
                        default:
                            break;
                    }
                }
            });
        }
    }

    // ============================================
    // PUBLIC METHODS
    // ============================================

    this.render = function()
    {
        var strHTML = renderAll();

        if (m_strTarget.length > 0)
        {
            api.element('#' + m_strFormID, '.' + m_strTarget).html(strHTML);
        }
        else if (api.element('#' + m_strFormID).length > 0)
        {
            api.element('#' + m_strFormID).html(strHTML);
        }

        setTimeout(function()
        {
            bindEvents();
            if (m_strMode === 'CODE' && m_blnShowLineNumbers && !m_blnReadOnly)
            {
                updateLineNumbers();
            }
        }, 0);

        return strHTML;
    };

    this.getValue = function()
    {
        return m_strCurrentValue;
    };

    this.setValue = function(strValue_a)
    {
        m_strCurrentValue = strValue_a || '';

        var strContainerSelector = '#' + m_strFormID;

        if (m_strMode === 'RICH')
        {
            var objRich = api.element(strContainerSelector + ' .ge-texteditor-rich');
            if (objRich.length)
            {
                objRich.html(m_strCurrentValue || '<br>');
            }
        }
        else if (m_strMode === 'INPUT')
        {
            var objInput = api.element(strContainerSelector + ' .ge-texteditor-input');
            if (objInput.length)
            {
                objInput.val(m_strCurrentValue);
            }
        }
        else if (m_strMode === 'CODE')
        {
            var objCode = api.element(strContainerSelector + ' .ge-texteditor-code');
            if (objCode.length)
            {
                objCode.val(m_strCurrentValue);
                if (m_blnShowLineNumbers && !m_blnReadOnly)
                {
                    updateLineNumbers();
                }
            }
        }
        else
        {
            var objTextarea = api.element(strContainerSelector + ' .ge-texteditor-textarea');
            if (objTextarea.length)
            {
                objTextarea.val(m_strCurrentValue);
            }
        }

        updateStatusBar();
    };

    this.clear = function()
    {
        m_objThis.setValue('');
    };

    this.focus = function()
    {
        var strContainerSelector = '#' + m_strFormID;
        if (m_strMode === 'RICH')
        {
            api.element(strContainerSelector + ' .ge-texteditor-rich').focus();
        }
        else if (m_strMode === 'INPUT')
        {
            api.element(strContainerSelector + ' .ge-texteditor-input').focus();
        }
        else if (m_strMode === 'CODE')
        {
            api.element(strContainerSelector + ' .ge-texteditor-code').focus();
        }
        else
        {
            api.element(strContainerSelector + ' .ge-texteditor-textarea').focus();
        }
    };

    // ============================================
    // INITIALIZATION
    // ============================================

    if (m_objParameters.initialvalue !== undefined)
    {
        m_strCurrentValue = m_objParameters.initialvalue;
    }

    m_objThis.render();
}