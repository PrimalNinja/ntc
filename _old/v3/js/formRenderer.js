// formRenderer.js
// Modern form renderer for Cyborg Designer forms
// (c) 2025 Cyborg Unicorn Pty Ltd.

function formRenderer(objOS_a, strFormID_a, objParameters_a)
{
    var m_objThis = this;
    var m_strFormID = strFormID_a;
    var os = objOS_a;
    var m_objParameters = objParameters_a || {};

    // Configuration
    var m_arrLayoutSections = m_objParameters.layoutSections || [];
    var m_blnReadOnly = m_objParameters.readonly || false;
    var m_strMode = m_objParameters.mode || 'edit'; // add, edit, view
	var m_strTarget = m_objParameters.target || '';
    var m_cbOnChange = m_objParameters.onChange || null;
    var m_cbOnValidate = m_objParameters.onValidate || null;
    var m_cbOnOperation = m_objParameters.onOperation || null;

    // State
    var m_objData = {};
    var m_blnDirty = false;
    var m_arrDataSources = [];

    // ====================================================================================
    // HELPERS ============================================================================

	// Helper to collect all data fields from layout sections
	function collectDataFields()
	{
		var arrFields = [];

		for (var intS = 0; intS < m_arrLayoutSections.length; intS++)
		{
			var objSection = m_arrLayoutSections[intS];
			if (objSection.containers)
			{
				for (var intC = 0; intC < objSection.containers.length; intC++)
				{
					var objContainer = objSection.containers[intC];
					if (objContainer.children)
					{
						for (var intF = 0; intF < objContainer.children.length; intF++)
						{
							var objField = objContainer.children[intF];
							// Only include data fields (not buttons, headings, etc.)
							if (objField.type !== 'button' && objField.type !== 'heading')
							{
								arrFields.push({
									containerName: objContainer.name,
									fieldName: objField.name,
									fieldType: objField.type,
									fieldClass: makeFieldClass(objContainer.name, objField.name),
									fullName: getFullName(objContainer.name, objField.name)
								});
							}
						}
					}
				}
			}
		}

		return arrFields;
	}

    function doNothing()
    {
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

	function toBoolean(strValue_a)
	{
		return (strValue_a === 'yes' || strValue_a === 'true' || strValue_a === '1' || strValue_a === true);
	}

    function makeFieldClass(strContainerName_a, strFieldName_a)
    {
		var strFullName = getFullName(strContainerName_a, strFieldName_a);

        // Create a consistent field class from field name
        return 'ge-field-' + strFullName.replace(/[^A-Za-z0-9_]/g, '-');
    }

    function getFullName(strContainerName_a, strFieldName_a)
    {
		return strContainerName_a.toUpperCase() + getNameSeparator() + strFieldName_a.toUpperCase();
    }

	function getNameSeparator()
	{
		return '__';
	}

    function setDirty(blnDirty_a)
    {
        m_blnDirty = blnDirty_a;

        if (m_cbOnChange && typeof m_cbOnChange === 'function')
        {
            m_cbOnChange(m_blnDirty);
        }
    }

    // ====================================================================================
    // FIELD RENDERERS ====================================================================

    function renderField_Textbox(objField_a, strContainerName_a)
    {
        var strHTML = '';
        var strFieldClass = makeFieldClass(strContainerName_a, objField_a.name);
        var strValue = objField_a.value || '';
        var strLabel = htmlEncode(objField_a.label || objField_a.caption);
        var blnRequired = objField_a.required;
        var blnReadOnly = objField_a.readonly || m_blnReadOnly;
        var strClasses = objField_a.classes || '';

        strHTML += '<div class="gscr-form-group">';
        strHTML += '  <label class="gscr-form-label">';
        strHTML += htmlEncode(strLabel);
        if (blnRequired) { strHTML += ' <span class="gscr-text-danger">*</span>'; }
        strHTML += '  </label>';
        strHTML += '  <input type="text" ';
        strHTML += '    class="ge-input ge-textbox ' + strFieldClass + ' form-control ' + strClasses + '" ';
        strHTML += '    name="' + htmlEncode(getFullName(strContainerName_a, objField_a.name)) + '" ';
        strHTML += '    value="' + htmlEncode(strValue) + '" ';
        strHTML += '    data-fieldname="' + htmlEncode(objField_a.name) + '" ';
        strHTML += '    data-containername="' + htmlEncode(strContainerName_a) + '" ';
        if (blnReadOnly) { strHTML += '    readonly '; }
        if (objField_a.length) { strHTML += '    maxlength="' + objField_a.length + '" '; }
        strHTML += '  />';
        strHTML += '</div>';

        return strHTML;
    }

    function renderField_Number(objField_a, strContainerName_a)
    {
        var strHTML = '';
        var strFieldClass = makeFieldClass(strContainerName_a, objField_a.name);
        var strValue = objField_a.value || '';
        var strLabel = htmlEncode(objField_a.label || objField_a.caption);
        var blnRequired = objField_a.required;
        var blnReadOnly = objField_a.readonly || m_blnReadOnly;
        var strClasses = objField_a.classes || '';

        strHTML += '<div class="gscr-form-group">';
        strHTML += '  <label class="gscr-form-label">';
        strHTML += htmlEncode(strLabel);
        if (blnRequired) { strHTML += ' <span class="gscr-text-danger">*</span>'; }
        strHTML += '  </label>';
        strHTML += '  <input type="number" ';
        strHTML += '    class="ge-input ge-number ' + strFieldClass + ' form-control ' + strClasses + '" ';
        strHTML += '    name="' + htmlEncode(getFullName(strContainerName_a, objField_a.name)) + '" ';
        strHTML += '    value="' + htmlEncode(strValue) + '" ';
        strHTML += '    data-fieldname="' + htmlEncode(objField_a.name) + '" ';
        strHTML += '    data-containername="' + htmlEncode(strContainerName_a) + '" ';
        if (blnReadOnly) { strHTML += '    readonly '; }
        strHTML += '  />';
        strHTML += '</div>';

        return strHTML;
    }

    function renderField_Date(objField_a, strContainerName_a)
    {
        var strHTML = '';
        var strFieldClass = makeFieldClass(strContainerName_a, objField_a.name);
        var strValue = objField_a.value || '';
        var strLabel = htmlEncode(objField_a.label || objField_a.caption);
        var blnRequired = objField_a.required;
        var blnReadOnly = objField_a.readonly || m_blnReadOnly;
        var strClasses = objField_a.classes || '';

        strHTML += '<div class="gscr-form-group">';
        strHTML += '  <label class="gscr-form-label">';
        strHTML += htmlEncode(strLabel);
        if (blnRequired) { strHTML += ' <span class="gscr-text-danger">*</span>'; }
        strHTML += '  </label>';
        strHTML += '  <input type="date" ';
        strHTML += '    class="ge-input ge-date ' + strFieldClass + ' form-control ' + strClasses + '" ';
        strHTML += '    name="' + htmlEncode(getFullName(strContainerName_a, objField_a.name)) + '" ';
        strHTML += '    value="' + htmlEncode(strValue) + '" ';
        strHTML += '    data-fieldname="' + htmlEncode(objField_a.name) + '" ';
        strHTML += '    data-containername="' + htmlEncode(strContainerName_a) + '" ';
        if (blnReadOnly) { strHTML += '    readonly '; }
        strHTML += '  />';
        strHTML += '</div>';

        return strHTML;
    }

    function renderField_Checkbox(objField_a, strContainerName_a)
    {
        var strHTML = '';
        var strFieldClass = makeFieldClass(strContainerName_a, objField_a.name);
        var strValue = objField_a.value || '';
        var blnChecked = toBoolean(strValue);
        var strLabel = htmlEncode(objField_a.label || objField_a.caption);
        var blnRequired = objField_a.required;
        var blnReadOnly = objField_a.readonly || m_blnReadOnly;
        var strClasses = objField_a.classes || '';

        strHTML += '<div class="gscr-form-group gscr-form-check">';
        strHTML += '  <input type="checkbox" ';
        strHTML += '    class="ge-input ge-checkbox ' + strFieldClass + ' form-check-input ' + strClasses + '" ';
        strHTML += '    name="' + htmlEncode(getFullName(strContainerName_a, objField_a.name)) + '" ';
        strHTML += '    value="yes" ';
        strHTML += '    data-fieldname="' + htmlEncode(objField_a.name) + '" ';
        strHTML += '    data-containername="' + htmlEncode(strContainerName_a) + '" ';
        if (blnChecked) { strHTML += '    checked '; }
        if (blnReadOnly) { strHTML += '    disabled '; }
        strHTML += '  />';
        strHTML += '  <label class="gscr-form-label gscr-form-check-label">';
        strHTML += htmlEncode(strLabel);
        if (blnRequired) { strHTML += ' <span class="gscr-text-danger">*</span>'; }
        strHTML += '  </label>';
        strHTML += '</div>';

        return strHTML;
    }

    function renderField_MultilineTextbox(objField_a, strContainerName_a)
    {
        var strHTML = '';
        var strFieldClass = makeFieldClass(strContainerName_a, objField_a.name);
        var strValue = objField_a.value || '';
        var strLabel = htmlEncode(objField_a.label || objField_a.caption);
        var blnRequired = objField_a.required;
        var blnReadOnly = objField_a.readonly || m_blnReadOnly;
        var strClasses = objField_a.classes || '';
        var intRows = objField_a.lines || 4;

        strHTML += '<div class="gscr-form-group">';
        strHTML += '  <label class="gscr-form-label">';
        strHTML += htmlEncode(strLabel);
        if (blnRequired) { strHTML += ' <span class="gscr-text-danger">*</span>'; }
        strHTML += '  </label>';
        strHTML += '  <textarea ';
        strHTML += '    class="ge-input ge-textarea ' + strFieldClass + ' form-control ' + strClasses + '" ';
        strHTML += '    name="' + htmlEncode(getFullName(strContainerName_a, objField_a.name)) + '" ';
        strHTML += '    rows="' + intRows + '" ';
        strHTML += '    data-fieldname="' + htmlEncode(objField_a.name) + '" ';
        strHTML += '    data-containername="' + htmlEncode(strContainerName_a) + '" ';
        if (blnReadOnly) { strHTML += '    readonly '; }
        if (objField_a.length) { strHTML += '    maxlength="' + objField_a.length + '" '; }
        strHTML += '  >';
        strHTML += htmlEncode(strValue);
        strHTML += '</textarea>';
        strHTML += '</div>';

        return strHTML;
    }

	function renderField_List(objField_a, strContainerName_a)
	{
		var strHTML = '';
		var strFieldClass = makeFieldClass(strContainerName_a, objField_a.name);
		var strValue = objField_a.value || '';
		var strLabel = htmlEncode(objField_a.label || objField_a.caption);
		var blnRequired = objField_a.required;
		var blnReadOnly = objField_a.readonly || m_blnReadOnly;
		var strClasses = objField_a.classes || '';
		var arrOptions = objField_a.options || [];

		// If read-only, render as textbox instead of dropdown
		if (blnReadOnly)
		{
			strHTML += '<div class="gscr-form-group">';
			strHTML += '  <label class="gscr-form-label">';
			strHTML += htmlEncode(strLabel);
			if (blnRequired) { strHTML += ' <span class="gscr-text-danger">*</span>'; }
			strHTML += '  </label>';
			strHTML += '  <input type="text" ';
			strHTML += '    class="ge-input ge-textbox ' + strFieldClass + ' form-control ' + strClasses + '" ';
			strHTML += '    name="' + htmlEncode(getFullName(strContainerName_a, objField_a.name)) + '" ';
			strHTML += '    value="' + htmlEncode(strValue) + '" ';
			strHTML += '    data-fieldname="' + htmlEncode(objField_a.name) + '" ';
			strHTML += '    data-containername="' + htmlEncode(strContainerName_a) + '" ';
			strHTML += '    readonly ';
			strHTML += '  />';
			strHTML += '</div>';
		}
		else
		{
			// Register datasource if provided
			if (objField_a.datasource)
			{
				m_arrDataSources.push({
					fieldName: objField_a.name,
					source: objField_a.datasource,
					filter: objField_a.datafilter || ''
				});
			}

			strHTML += '<div class="gscr-form-group">';
			strHTML += '  <label class="gscr-form-label">';
			strHTML += htmlEncode(strLabel);
			if (blnRequired) { strHTML += ' <span class="gscr-text-danger">*</span>'; }
			strHTML += '  </label>';
			strHTML += '  <select ';
			strHTML += '    class="ge-input ge-select ' + strFieldClass + ' form-control ' + strClasses + '" ';
			strHTML += '    name="' + htmlEncode(getFullName(strContainerName_a, objField_a.name)) + '" ';
			strHTML += '    data-fieldname="' + htmlEncode(objField_a.name) + '" ';
			strHTML += '    data-containername="' + htmlEncode(strContainerName_a) + '" ';
			strHTML += '  >';

			// Add blank option
			strHTML += '<option value="">-- Select --</option>';

			// Add options
			for (var intI = 0; intI < arrOptions.length; intI++)
			{
				var objOption = arrOptions[intI];
				var strOptionValue = objOption.value || objOption.code || '';
				var strOptionText = objOption.description || objOption.value || '';
				var blnSelected = (strOptionValue === strValue);

				strHTML += '<option value="' + htmlEncode(strOptionValue) + '"';
				if (blnSelected) { strHTML += ' selected'; }
				strHTML += '>';
				strHTML += htmlEncode(strOptionText);
				strHTML += '</option>';
			}

			strHTML += '  </select>';
			strHTML += '</div>';
		}

		return strHTML;
	}

    function renderField_Button(objField_a, strContainerName_a)
    {
        var strHTML = '';
        var strFieldClass = makeFieldClass(strContainerName_a, objField_a.name);
        var strLabel = htmlEncode(objField_a.label || objField_a.caption);
        var strClasses = objField_a.classes || '';

        strHTML += '<div class="gscr-form-group">';
        strHTML += '  <button type="button" ';
        strHTML += '    class="btn btn-primary ' + strFieldClass + ' ' + strClasses + '" ';
        strHTML += '    name="' + htmlEncode(getFullName(strContainerName_a, objField_a.name)) + '" ';
        strHTML += '    data-fieldname="' + htmlEncode(objField_a.name) + '" ';
        strHTML += '    data-containername="' + htmlEncode(strContainerName_a) + '" ';
        strHTML += '  >';
        strHTML += htmlEncode(strLabel);
        strHTML += '  </button>';
        strHTML += '</div>';

        return strHTML;
    }

    function renderField_Heading(objField_a, strContainerName_a)
    {
        var strHTML = '';
        var strLabel = htmlEncode(objField_a.label || objField_a.caption);
        var strClasses = objField_a.classes || '';

        strHTML += '<div class="gscr-form-group">';
        strHTML += '  <h4 class="gscr-heading ' + strClasses + '">';
        strHTML += htmlEncode(strLabel);
        strHTML += '  </h4>';
        strHTML += '</div>';

        return strHTML;
    }

    function renderField_URL(objField_a, strContainerName_a)
    {
        var strHTML = '';
        var strFieldClass = makeFieldClass(strContainerName_a, objField_a.name);
        var strValue = objField_a.value || '';
        var strLabel = htmlEncode(objField_a.label || objField_a.caption);
        var blnRequired = objField_a.required;
        var blnReadOnly = objField_a.readonly || m_blnReadOnly;
        var strClasses = objField_a.classes || '';

        strHTML += '<div class="gscr-form-group">';
        strHTML += '  <label class="gscr-form-label">';
        strHTML += htmlEncode(strLabel);
        if (blnRequired) { strHTML += ' <span class="gscr-text-danger">*</span>'; }
        strHTML += '  </label>';
        strHTML += '  <input type="url" ';
        strHTML += '    class="ge-input ge-url ' + strFieldClass + ' form-control ' + strClasses + '" ';
        strHTML += '    name="' + htmlEncode(getFullName(strContainerName_a, objField_a.name)) + '" ';
        strHTML += '    value="' + htmlEncode(strValue) + '" ';
        strHTML += '    data-fieldname="' + htmlEncode(objField_a.name) + '" ';
        strHTML += '    data-containername="' + htmlEncode(strContainerName_a) + '" ';
        if (blnReadOnly) { strHTML += '    readonly '; }
        strHTML += '  />';
        strHTML += '</div>';

        return strHTML;
    }

    function renderField_GPS(objField_a, strContainerName_a)
    {
        var strHTML = '';
        var strFieldClass = makeFieldClass(strContainerName_a, objField_a.name);
        var strValue = objField_a.value || '';
        var strLabel = htmlEncode(objField_a.label || objField_a.caption);
        var blnRequired = objField_a.required;
        var blnReadOnly = objField_a.readonly || m_blnReadOnly;
        var strClasses = objField_a.classes || '';

        strHTML += '<div class="gscr-form-group">';
        strHTML += '  <label class="gscr-form-label">';
        strHTML += htmlEncode(strLabel);
        if (blnRequired) { strHTML += ' <span class="gscr-text-danger">*</span>'; }
        strHTML += '  </label>';
        strHTML += '  <div class="gscr-input-group">';
        strHTML += '    <input type="text" ';
        strHTML += '      class="ge-input ge-gps ' + strFieldClass + ' form-control ' + strClasses + '" ';
        strHTML += '      name="' + htmlEncode(getFullName(strContainerName_a, objField_a.name)) + '" ';
        strHTML += '      value="' + htmlEncode(strValue) + '" ';
        strHTML += '      placeholder="latitude,longitude" ';
        strHTML += '      data-fieldname="' + htmlEncode(objField_a.name) + '" ';
        strHTML += '      data-containername="' + htmlEncode(strContainerName_a) + '" ';
        if (blnReadOnly) { strHTML += '      readonly '; }
        strHTML += '    />';
        strHTML += '    <div class="gscr-input-group-append">';
        strHTML += '      <button class="ge-gps-button btn btn-outline-secondary ' + strFieldClass + '-gps" type="button" data-fieldclass="' + strFieldClass + '">Get Location</button>';
        strHTML += '    </div>';
        strHTML += '  </div>';
        strHTML += '</div>';

        return strHTML;
    }

    function renderField_Document(objField_a, strContainerName_a)
    {
        var strHTML = '';
        var strFieldClass = makeFieldClass(strContainerName_a, objField_a.name);
        var strValue = objField_a.value || '';
        var strLabel = htmlEncode(objField_a.label || objField_a.caption);
        var blnRequired = objField_a.required;
        var blnReadOnly = objField_a.readonly || m_blnReadOnly;
        var strClasses = objField_a.classes || '';

        strHTML += '<div class="gscr-form-group">';
        strHTML += '  <label class="gscr-form-label">';
        strHTML += htmlEncode(strLabel);
        if (blnRequired)
        {
            strHTML += ' <span class="gscr-text-danger">*</span>';
        }
        strHTML += '  </label>';
        strHTML += '  <div class="gscr-input-group">';
        strHTML += '    <input type="text" ';
        strHTML += '      class="ge-input ge-document ' + strFieldClass + ' form-control ' + strClasses + '" ';
        strHTML += '      name="' + htmlEncode(getFullName(strContainerName_a, objField_a.name)) + '" ';
        strHTML += '      value="' + htmlEncode(strValue) + '" ';
        strHTML += '      placeholder="File path..." ';
        strHTML += '      data-fieldname="' + htmlEncode(objField_a.name) + '" ';
        strHTML += '      data-containername="' + htmlEncode(strContainerName_a) + '" ';
        if (blnReadOnly)
        {
            strHTML += '      readonly ';
        }
        strHTML += '    />';
        strHTML += '    <div class="gscr-input-group-append">';
        strHTML += '      <button class="ge-document-browse btn btn-outline-secondary" type="button" data-fieldclass="' + strFieldClass + '" data-classes="' + htmlEncode(strClasses) + '">Browse</button>';
        strHTML += '    </div>';
        strHTML += '    <input type="file" class="ge-document-fileinput ' + strFieldClass + '-fileinput" style="display:none;" data-fieldclass="' + strFieldClass + '">';
        strHTML += '  </div>';
        strHTML += '</div>';

        return strHTML;
    }

    function renderField_ToolbarButton(objField_a)
    {
        var strHTML      = '';
        var strCaption   = htmlEncode(objField_a.caption || objField_a.label || '');
        var strOperation = objField_a.operation || '';
        var strClasses   = objField_a.classes || '';

        strHTML += '<button type="button" ';
        strHTML += '  class="ge-toolbar-btn btn btn-primary ' + strClasses + '" ';
        strHTML += '  data-operation="' + htmlEncode(strOperation) + '" ';
        strHTML += '>';
        strHTML += strCaption;
        strHTML += '</button>';

        return strHTML;
    }

    function renderField(objField_a, strContainerName_a)
    {
        var strHTML = '';
        var strType = objField_a.type || 'textbox';

        // Route to appropriate field renderer
        switch (strType)
        {
            case 'textbox':
                strHTML = renderField_Textbox(objField_a, strContainerName_a);
                break;
            case 'number':
                strHTML = renderField_Number(objField_a, strContainerName_a);
                break;
            case 'date':
                strHTML = renderField_Date(objField_a, strContainerName_a);
                break;
            case 'checkbox':
                strHTML = renderField_Checkbox(objField_a, strContainerName_a);
                break;
            case 'multilinetextbox':
                strHTML = renderField_MultilineTextbox(objField_a, strContainerName_a);
                break;
            case 'list':
                strHTML = renderField_List(objField_a, strContainerName_a);
                break;
            case 'button':
                strHTML = renderField_Button(objField_a, strContainerName_a);
                break;
            case 'heading':
                strHTML = renderField_Heading(objField_a, strContainerName_a);
                break;
            case 'url':
                strHTML = renderField_URL(objField_a, strContainerName_a);
                break;
            case 'gps':
                strHTML = renderField_GPS(objField_a, strContainerName_a);
                break;
            case 'document':
                strHTML = renderField_Document(objField_a, strContainerName_a);
                break;
            case 'toolbarbutton':
                strHTML = renderField_ToolbarButton(objField_a);
                break;
            default:
                // Unsupported field type - render as textbox for now
                strHTML = renderField_Textbox(objField_a, strContainerName_a);
                break;
        }

        return strHTML;
    }

    // ====================================================================================
    // CONTAINER RENDERERS ================================================================

    function renderContainer(objContainer_a)
    {
        var strHTML = '';
        var strType = objContainer_a.type || 'verticalcontainer';
        var strCaption = htmlEncode(objContainer_a.caption || objContainer_a.label || '');
        var arrChildren = objContainer_a.children || [];
        var strContainerName = objContainer_a.name || '';
        var strClasses = 'gscr-container';
        var strStyleClasses = 'gscr-container';

        if (strType === 'horizontalcontainer')
        {
            strClasses += ' gscr-containerHorizontal';
            strStyleClasses += ' gscr-containerHorizontal';
            strHTML += '<div class="' + strClasses + ' ' + strStyleClasses + '">';

            if (strCaption.length > 0)
            {
                strHTML += '<div class="gscr-container-caption">' + strCaption + '</div>';
            }

            strHTML += '<div class="gscr-row">';

            for (var intI = 0; intI < arrChildren.length; intI++)
            {
                var objChild = arrChildren[intI];
                strHTML += '<div class="gscr-col">';

                if (objChild.children)
                {
                    // Nested container
                    strHTML += renderContainer(objChild);
                }
                else
                {
                    // Field
                    strHTML += renderField(objChild, strContainerName);
                }

                strHTML += '</div>';
            }

            strHTML += '</div>';
            strHTML += '</div>';
        }
        else // verticalcontainer
        {
            strClasses += ' gscr-containerVertical';
            strStyleClasses += ' gscr-containerVertical';
            strHTML += '<div class="' + strClasses + ' ' + strStyleClasses + '">';

            if (strCaption.length > 0)
            {
                strHTML += '<div class="gscr-container-caption">' + strCaption + '</div>';
            }

            for (var intJ = 0; intJ < arrChildren.length; intJ++)
            {
                var objChild2 = arrChildren[intJ];

                if (objChild2.children)
                {
                    // Nested container
                    strHTML += renderContainer(objChild2);
                }
                else
                {
                    // Field
                    strHTML += renderField(objChild2, strContainerName);
                }
            }

            strHTML += '</div>';
        }

        return strHTML;
    }

    // ====================================================================================
    // SECTION RENDERERS ==================================================================

    function renderToolbar(objSection_a)
    {
        var strHTML      = '';
        var arrContainers = objSection_a.containers || [];

        strHTML += '<div class="gscr-toolbar">';

        for (var intI = 0; intI < arrContainers.length; intI++)
        {
            var arrChildren = arrContainers[intI].children || [];
            for (var intJ = 0; intJ < arrChildren.length; intJ++)
            {
                var objBtn = arrChildren[intJ];
                if (objBtn.type === 'toolbarbutton')
                {
                    strHTML += renderField_ToolbarButton(objBtn);
                }
            }
        }

        strHTML += '</div>';

        return strHTML;
    }

    function renderSection(objSection_a)
    {
        var strHTML       = '';
        var strCaption    = htmlEncode(objSection_a.caption || '');
        var arrContainers = objSection_a.containers || [];

        strHTML += '<div class="gscr-section gscr-card gscr-mb-3">';

        if (strCaption.length > 0)
        {
            strHTML += '<div class="gscr-section-header gscr-card-header">';
            strHTML += '  <h5 class="gsMb-0">' + strCaption + '</h5>';
            strHTML += '</div>';
        }

        strHTML += '<div class="gscr-section-content gscr-card-body">';

        for (var intI = 0; intI < arrContainers.length; intI++)
        {
            var objContainer = arrContainers[intI];
            strHTML += renderContainer(objContainer);
        }

        strHTML += '</div>';
        strHTML += '</div>';

        return strHTML;
    }

    // ====================================================================================
    // MAIN RENDERER ======================================================================

    function renderForm()
    {
        var strHTML        = '';
        var strToolbarHTML = '';
        var strBodyHTML    = '';

        for (var intI = 0; intI < m_arrLayoutSections.length; intI++)
        {
            var objSection = m_arrLayoutSections[intI];
            if (objSection.type === 'toolbar')
            {
                strToolbarHTML += renderToolbar(objSection);
            }
            else
            {
                strBodyHTML += renderSection(objSection);
            }
        }

        strHTML += '<div class="gscr-formrenderer">';
        if (strToolbarHTML.length > 0)
        {
            strHTML += strToolbarHTML;
        }
        strHTML += '<div class="gscr-formbody">';
        strHTML += strBodyHTML;
        strHTML += '</div>';
        strHTML += '</div>';

        return strHTML;
    }

    // ====================================================================================
    // EVENT HANDLERS =====================================================================

    function bindEvents()
    {
        // Bind change events to all inputs
        os.element('#' + m_strFormID, '.ge-input').on('change', function()
        {
            setDirty(true);
        });

        // Bind toolbar button clicks
        os.element('#' + m_strFormID, '.ge-toolbar-btn').on('click', function()
        {
            var strOperation = os.element(this).attr('data-operation');
            if (m_cbOnOperation && typeof m_cbOnOperation === 'function')
            {
                m_cbOnOperation(strOperation);
            }
        });

        // Bind GPS button clicks
        os.element('#' + m_strFormID, '.ge-gps-button').on('click', function()
        {
            var strFieldClass = os.element(this).attr('data-fieldclass');
            getGPSLocation(strFieldClass);
        });

        // Bind Document browse button clicks
        os.element('#' + m_strFormID, '.ge-document-browse').on('click', function()
        {
            var strFieldClass = os.element(this).attr('data-fieldclass');
            var strClasses = os.element(this).attr('data-classes') || '';

            if (m_cbOnBrowse && typeof m_cbOnBrowse === 'function')
            {
                var strPath = m_cbOnBrowse(strFieldClass, strClasses);
                if (strPath && strPath.length > 0)
                {
                    os.element('#' + m_strFormID, '.' + strFieldClass).val(strPath);
                    setDirty(true);
                }
            }
            else
            {
                var objFileInput = os.element('#' + m_strFormID, '.' + strFieldClass + '-fileinput');
                objFileInput.val('');
                objFileInput.trigger('click');
            }
        });

        // Bind Document file input change (fallback when no onBrowse callback)
        os.element('#' + m_strFormID, '.ge-document-fileinput').on('change', function()
        {
            var strFieldClass = os.element(this).attr('data-fieldclass');
            var arrFiles = this.files;
            if (arrFiles.length > 0)
            {
                os.element('#' + m_strFormID, '.' + strFieldClass).val(arrFiles[0].name);
                setDirty(true);
            }
        });
    }

    function getGPSLocation(strFieldClass_a)
    {
        if (navigator.geolocation)
        {
            navigator.geolocation.getCurrentPosition(
                function(objPosition)
                {
                    var strCoords = objPosition.coords.latitude + ',' + objPosition.coords.longitude;
                    os.element('#' + m_strFormID, '.' + strFieldClass_a).val(strCoords);
                    setDirty(true);
                },
                function(objError)
                {
                    alert('Error getting location: ' + objError.message);
                }
            );
        }
        else
        {
            alert('Geolocation is not supported by this browser.');
        }
    }

    // ====================================================================================
    // PUBLIC API =========================================================================

    this.render = function()
    {
        var strHTML = renderForm();
		if (m_strTarget.length > 0)
		{
			os.element('#' + m_strFormID, '.' + m_strTarget).html(strHTML);
			bindEvents();
		}
    };

	this.getData = function()
	{
		var objData = {};
		var arrFields = collectDataFields();

		for (var intI = 0; intI < arrFields.length; intI++)
		{
			var objField = arrFields[intI];
			var objElement = os.element('#' + m_strFormID, '.' + objField.fieldClass);

			if (objElement.length > 0)
			{
				var strValue = '';

				if (objField.fieldType === 'checkbox')
				{
					strValue = objElement.is(':checked');
				}
				else
				{
					strValue = objElement.val();
				}

				objData[objField.fullName] = strValue;
			}
		}

		return objData;
	};

	this.setData = function(objData_a)
	{
		var arrFields = collectDataFields();

		for (var intI = 0; intI < arrFields.length; intI++)
		{
			var objField = arrFields[intI];

			if (objData_a.hasOwnProperty(objField.fullName))
			{
				var strValue = objData_a[objField.fullName];
				var objInput = os.element('#' + m_strFormID, '.' + objField.fieldClass);

				if (objInput.length > 0)
				{
					if (objField.fieldType === 'checkbox')
					{
						objInput.prop('checked', toBoolean(strValue));
					}
					else
					{
						objInput.val(strValue);
					}
				}
			}
		}

		setDirty(false);
	};

	this.validate = function()
	{
		var arrErrors = [];
		var strLabel;

		// Helper to find DOM element for a field using its class
		function findFieldElement(strContainerName_a, strFieldName_a)
		{
			var strClass = makeFieldClass(strContainerName_a, strFieldName_a);
			return os.element('#' + m_strFormID, '.' + strClass);
		}

		// Helper to get field value based on its type
		function getFieldValue(objField_a, objElement_a)
		{
			if (objField_a.type === 'checkbox')
			{
				return objElement_a.is(':checked');
			}
			else
			{
				return $.trim(objElement_a.val());
			}
		}

		// Loop through all sections
		for (var intS = 0; intS < m_arrLayoutSections.length; intS++)
		{
			var objSection = m_arrLayoutSections[intS];
			if (!objSection.containers) continue;

			// Loop through all containers
			for (var intC = 0; intC < objSection.containers.length; intC++)
			{
				var objContainer = objSection.containers[intC];
				if (!objContainer.children) continue;

				// Recursive function to traverse nested containers
				function traverseChildren(arrChildren)
				{
					for (var intF = 0; intF < arrChildren.length; intF++)
					{
						var objField = arrChildren[intF];

						// If this is a nested container, traverse its children
						if (objField.children)
						{
							traverseChildren(objField.children);
							continue;
						}

						// Skip non-data fields
						if (objField.type === 'button' || objField.type === 'heading')
						{
							continue;
						}

						// Check if field is required
						if (!objField.required)
						{
							continue;
						}

						// Get the DOM element
						var objElement = findFieldElement(objContainer.name, objField.name);
						if (objElement.length === 0)
						{
							// Field not found in DOM — could be hidden or not rendered
							continue;
						}

						// Get the value
						var strValue = getFieldValue(objField, objElement);

						// Validate based on field type
						if (objField.type === 'checkbox')
						{
							if (strValue !== true && strValue !== 'yes' && strValue !== 'true' && strValue !== 1)
							{
								strLabel = objField.label || objField.caption || objField.name;
								arrErrors.push(strLabel + ' must be checked.');
							}
						}
						else
						{
							if (strValue === null || strValue === undefined || strValue === '')
							{
								strLabel = objField.label || objField.caption || objField.name;
								arrErrors.push(strLabel + ' is required.');
							}
						}
					}
				}

				traverseChildren(objContainer.children);
			}
		}

		// Custom validation callback
		if (m_cbOnValidate && typeof m_cbOnValidate === 'function')
		{
			var arrCustomErrors = m_cbOnValidate(m_objThis.getData());
			if (arrCustomErrors && arrCustomErrors.length > 0)
			{
				arrErrors = arrErrors.concat(arrCustomErrors);
			}
		}

		return arrErrors;
	};

    this.isDirty = function()
    {
        return m_blnDirty;
    };

    this.clearDirty = function()
    {
        setDirty(false);
    };

    this.getDataSources = function()
    {
        return m_arrDataSources;
    };

    // ====================================================================================
    // INITIALISATION =====================================================================

    function initialise()
    {
        // Render form on load
        m_objThis.render();
    }

    initialise();
}
