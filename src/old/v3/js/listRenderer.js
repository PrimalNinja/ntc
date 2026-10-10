// listRenderer.js
// Metadata-driven list and gallery renderer for CyborgDesktop
// Supports pagination, sorting, searching, and custom operations

function listRenderer(objAPI_a, strFormID_a, objParameters_a)
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

	// Debug output function
	function debugOutput(strMessage_a)
	{
		if (m_blnEnableDebug)
		{
			var strTimestamp = new Date().toISOString().substr(11, 12);

			// Append to the existing output div
			var objOutput = api.element('#output');
			if (objOutput.length > 0)
			{
				objOutput.show();
				var strCurrentText = objOutput.text();
				if (strCurrentText.length > 0)
				{
					objOutput.text(strCurrentText + '\n[' + strTimestamp + '] [' + m_strFormID + '] ' + strMessage_a);
				}
				else
				{
					objOutput.text('[' + strTimestamp + '] [' + m_strFormID + '] ' + strMessage_a);
				}
			}
		}
	}

	// Parameters
	var m_strDataSource = m_objParameters.dataSource || '';
	var m_strType = m_objParameters.type || 'LIST'; // 'LIST' or 'GALLERY'
	var m_strFlow = m_objParameters.flow || 'PAGED'; // 'PAGED', 'CONTINUOUS', or 'EXPAND'
	var m_objThumbSize = m_objParameters.thumbsize || {X: 100, Y: 100};
	var m_strImageField = m_objParameters.imagefield || '';
	var m_blnAllowMultiSelect = m_objParameters.allowmultiselect || false;
	var m_strTarget = m_objParameters.target || '';

	// Editing parameters
	var m_blnAllowEdit = m_objParameters.allowedit || false;
	var m_blnAllowAddNew = m_objParameters.allowaddnew || false;
	var m_blnAllowDelete = m_objParameters.allowdelete || false;
	var m_blnReadOnly = m_objParameters.readonly || false; // Override all editing

	// Debug
	var m_blnEnableDebug = m_objParameters.enabledebug || false;

	// Check if this is an editable grid config (before readonly override)
	var m_blnIsEditableConfig = m_blnAllowEdit || m_blnAllowAddNew || m_blnAllowDelete;

	// If readonly, disable all editing
	if (m_blnReadOnly)
	{
		m_blnAllowEdit = false;
		m_blnAllowAddNew = false;
		m_blnAllowDelete = false;
	}

	// Toolbar parameters
	var m_blnAllowSearch = m_objParameters.allowsearch !== false; // Default true

	// Force search OFF if editable config OR readonly
	if (m_blnIsEditableConfig || m_blnReadOnly)
	{
		m_blnAllowSearch = false;
	}

	// Force EXPAND mode if this is an editable config (even if readonly)
	if (m_blnIsEditableConfig)
	{
		m_strFlow = 'EXPAND';
	}

	// Drag-drop parameters
	var m_blnAllowDragDrop = m_objParameters.allowdragdrop || false;

	// Callbacks
	var m_cbOnClick = m_objParameters.cbOnClick || null;
	var m_cbOnDblClick = m_objParameters.cbOnDblClick || null;
	var m_cbOnOperation = m_objParameters.cbOnOperation || null;
	var m_cbGetDescription = m_objParameters.cbGetDescription || null;
	var m_cbLoadData = m_objParameters.cbLoadData || null;
	var m_cbOnRowUpdate = m_objParameters.onRowUpdate || null;
	var m_cbOnRowDelete = m_objParameters.onRowDelete || null;
	var m_cbOnRowAddNew = m_objParameters.onRowAddNew || null;
	var m_cbOnDragDropItem = m_objParameters.cbOnDragDropItem || null;

	// State
	var m_intOffset = 0;
	var m_intLimit = 100;
	var m_strSearch = '';
	var m_arrOrder = m_objParameters.defaultorder || [];
	var m_strSelectedID = null;
	var m_arrSelectedIDs = [];
	var m_blnLoading = false;

	// Editing state
	var m_intEditRow = -1;
	var m_intEditCol = -1;
	var m_objFloatingEditor = null;
	var m_arrBlankRowData = null; // Temporary data for blank row being edited

	// Data from server
	var m_objControl = null;
	var m_arrOperations = [];
	var m_arrFields = [];
	var m_arrData = [];

	// Helper functions

	function calculatePageSize()
	{
		// Don't calculate for EXPAND
		if (m_strFlow === 'EXPAND')
		{
			return 9999; // Return large number for expand
		}

		// Get container height
		var intContainerHeight = api.element('#' + m_strFormID).height();
		var intRows = 0;
		var intColumns = 0;
		var intItemHeight = 0;
		var intAvailableHeight = 0;
		var intPaginationHeight = 0;
		var intHeaderHeight = 0;
		var intRowHeight = 0;

		if (intContainerHeight && intContainerHeight !== 0)
		{
			// Subtract toolbar (~70px) and pagination (~60px for PAGED, 0 for CONTINUOUS)
			intPaginationHeight = m_strFlow === 'PAGED' ? 60 : 0;
			intAvailableHeight = intContainerHeight - 70 - intPaginationHeight;

			if (m_strType === 'GALLERY')
			{
				// Gallery: each item is thumb height + caption + gap
				intItemHeight = m_objThumbSize.Y + 40; // thumb + caption + padding/gap
				intColumns = Math.floor((api.element('#' + m_strFormID).width() - 40) / (m_objThumbSize.X + 10)) || 4;
				intRows = Math.floor(intAvailableHeight / intItemHeight) || 3;

				// For CONTINUOUS flow, add extra rows to guarantee overflow and trigger scrollbar
				if (m_strFlow === 'CONTINUOUS')
				{
					intRows += 2; // Add 2 extra rows to ensure overflow
				}

				return intRows * intColumns;
			}
			else
			{
				// List: each row is approximately 40px (with header ~40px)
				intRowHeight = 40;
				intHeaderHeight = 40;
				intRows = Math.floor((intAvailableHeight - intHeaderHeight) / intRowHeight);

				// For CONTINUOUS flow, add extra rows to guarantee overflow and trigger scrollbar
				if (m_strFlow === 'CONTINUOUS')
				{
					intRows += 5; // Add 5 extra rows to ensure overflow
				}

				return Math.max(intRows, 5); // Minimum 5 rows
			}
		}
		else
		{
			// Fallback to default if can't measure
			return m_strType === 'GALLERY' ? 24 : 20;
		}
	}

	function getFieldIndexByCode(strCode_a)
	{
		var intIndex = 0;
		var intFoundIndex = -1;

		for (intIndex = 0; intIndex < m_arrFields.length; intIndex++)
		{
			if (m_arrFields[intIndex].code === strCode_a)
			{
				intFoundIndex = intIndex;
				break;
			}
		}

		return intFoundIndex;
	}

	function getFieldByCode(strCode_a)
	{
		var intIndex = getFieldIndexByCode(strCode_a);
		var objField = null;

		if (intIndex >= 0)
		{
			objField = m_arrFields[intIndex];
		}

		return objField;
	}

	function formatValue(value_a, strType_a)
	{
		var strResult = '';

		if (value_a !== null && value_a !== undefined && value_a !== '')
		{
			switch (strType_a)
			{
				case 'BOOLEAN':
					strResult = value_a ? 'Yes' : 'No';
					break;

				case 'DATE':
					// Basic date formatting - can be enhanced
					strResult = new Date(value_a).toLocaleDateString();
					break;

				case 'NUMBER':
					strResult = value_a.toString();
					break;

				default:
					strResult = value_a.toString();
					break;
			}
		}

		strResult = htmlEncode(strResult);

		return strResult;
	}

	function clearSelection()
	{
		m_strSelectedID = null;
		m_arrSelectedIDs = [];
		// Remove selection highlight from DOM
		api.element('#' + m_strFormID, '.gscr-list-row-selected').removeClass('gscr-list-row-selected');
		updateOperationButtons();
	}

	function setSelection(strID_a)
	{
		if (m_blnAllowMultiSelect)
		{
			// Future: multi-select logic
			m_arrSelectedIDs = [strID_a];
		}
		else
		{
			m_strSelectedID = strID_a;
		}

		updateOperationButtons();
	}

	function updateOperationButtons()
	{
		var intIndex = 0;
		var objOperation = null;
		var blnHasSelection = m_strSelectedID !== null || m_arrSelectedIDs.length > 0;

		for (intIndex = 0; intIndex < m_arrOperations.length; intIndex++)
		{
			objOperation = m_arrOperations[intIndex];

			if (objOperation.requiresselection && !blnHasSelection)
			{
				api.element('#' + m_strFormID, '.ge-operation-' + objOperation.code).prop('disabled', true);
			}
			else
			{
				api.element('#' + m_strFormID, '.ge-operation-' + objOperation.code).prop('disabled', false);
			}
		}
	}

	// Server communication

	function createJSONRequest()
	{
		// Using qriOS pattern
		var arrParameters = [
			{name: 'offset', value: m_intOffset.toString()},
			{name: 'limit', value: m_intLimit.toString()},
			{name: 'search', value: m_strSearch},
			{name: 'order', value: JSON.stringify(m_arrOrder)}
		];

		return {parameters: arrParameters};
	}

	function loadData(cb_a)
	{
		var objRequest = createJSONRequest();
		var cbExecuted = false;

		// Use callback if provided (for custom server communication)
		if (m_cbLoadData && typeof m_cbLoadData === 'function')
		{
			m_cbLoadData(objRequest, function(objResponse_a)
			{
				cbExecuted = true;
				if (objResponse_a && objResponse_a.control)
				{
					processServerResponse(objResponse_a);

					if (cb_a && typeof cb_a === 'function')
					{
						cb_a();
					}
				}
			});
		}
		// Fallback: Call server using qriOS pattern (if api has callServer method)
		else if (api.callServer)
		{
			api.callServer(m_strDataSource, objRequest, function(objResponse_a)
			{
				cbExecuted = true;
				if (objResponse_a && objResponse_a.control)
				{
					processServerResponse(objResponse_a);

					if (cb_a && typeof cb_a === 'function')
					{
						cb_a();
					}
				}
			});
		}

		// No server communication method available
		if (!cbExecuted && cb_a && typeof cb_a === 'function')
		{
			cb_a();
		}
	}

	function processServerResponse(objResponse_a)
	{
		// Update state from server
		m_objControl = objResponse_a.control || {};

		// Server can override client values
		if (m_objControl.offset !== undefined)
		{
			m_intOffset = m_objControl.offset;
		}
		if (m_objControl.limit !== undefined)
		{
			m_intLimit = m_objControl.limit;
		}

		m_arrOperations = objResponse_a.operations || [];
		m_arrFields = objResponse_a.fields || [];
		m_arrData = objResponse_a.data || [];

		// Add STATUS column if editing is enabled
		if (m_blnAllowEdit || m_blnAllowAddNew || m_blnAllowDelete)
		{
			addStatusColumn();
		}
	}

	function addStatusColumn()
	{
		// Check if STATUS column already exists
		var blnHasStatus = false;
		var intIndex = 0;

		for (intIndex = 0; intIndex < m_arrFields.length; intIndex++)
		{
			if (m_arrFields[intIndex].code === 'STATUS')
			{
				blnHasStatus = true;
				break;
			}
		}

		// Add STATUS field if it doesn't exist
		if (!blnHasStatus)
		{
			m_arrFields.unshift({
				code: 'STATUS',
				caption: 'Status',
				type: 'STRING',
				visible: false,
				sortable: false,
				editable: false
			});

			// Add STATUS value (empty string) to each data row
			for (intIndex = 0; intIndex < m_arrData.length; intIndex++)
			{
				m_arrData[intIndex].unshift('');
			}
		}
	}

	// Status tracking helper functions

	function getRowStatus(intRowIndex_a)
	{
		var strStatus = null;

		if (intRowIndex_a >= 0 && intRowIndex_a < m_arrData.length)
		{
			strStatus = m_arrData[intRowIndex_a][0]; // STATUS is always first column
		}

		return strStatus;
	}

	function setRowStatus(intRowIndex_a, strStatus_a)
	{
		if (intRowIndex_a >= 0 && intRowIndex_a < m_arrData.length)
		{
			m_arrData[intRowIndex_a][0] = strStatus_a;
		}
	}

	function markRowEdited(intRowIndex_a)
	{
		var strCurrentStatus = getRowStatus(intRowIndex_a);
		var blnSuccess = true;

		// If interim row, just keep it interim (callback fires when leaving row)
		if (strCurrentStatus === 'I')
		{
			blnSuccess = true;
		}
		// If new row, keep it 'N'
		else if (strCurrentStatus === 'N')
		{
			blnSuccess = true;
		}
		// If not deleted, mark as updated
		else if (strCurrentStatus !== 'D')
		{
			var intIDIndex = (m_blnAllowEdit || m_blnAllowAddNew || m_blnAllowDelete) ? 1 : 0;
			var arrRow = m_arrData[intRowIndex_a];
			var strID = arrRow[intIDIndex];

			// Call callback if it exists
			if (m_cbOnRowUpdate)
			{
				blnSuccess = m_cbOnRowUpdate(arrRow, strID);
			}

			// Only set status if callback succeeded
			if (blnSuccess)
			{
				setRowStatus(intRowIndex_a, 'U');
			}
		}

		return blnSuccess; // Rejected or not
	}

	function markRowDeleted(intRowIndex_a)
	{
		var arrRow;
		var blnSuccess = true;
		var blnRemoved = false;
		var intIDIndex;
		var strCurrentStatus = getRowStatus(intRowIndex_a);
		var strID;

		// If interim row, promote to 'N' first, then mark as deleted
		if (strCurrentStatus === 'I')
		{
			debugOutput('markRowDeleted: interim row, promoting to N first');
			setRowStatus(intRowIndex_a, 'N');
			strCurrentStatus = 'N'; // Update for logic below
		}

		// If new row, mark as 'ND' (new-deleted) instead of removing
		if (strCurrentStatus === 'N')
		{
			intIDIndex = 1;
			arrRow = m_arrData[intRowIndex_a];
			strID = arrRow[intIDIndex];

			// Call callback if it exists
			if (m_cbOnRowDelete)
			{
				blnSuccess = m_cbOnRowDelete(arrRow, strID);
			}

			// Only mark deleted if callback succeeded
			if (blnSuccess)
			{
				setRowStatus(intRowIndex_a, 'ND');
			}

			blnRemoved = false; // Not removed, just marked
		}
		else
		{
			intIDIndex = (m_blnAllowEdit || m_blnAllowAddNew || m_blnAllowDelete) ? 1 : 0;
			arrRow = m_arrData[intRowIndex_a];
			strID = arrRow[intIDIndex];

			// Call callback if it exists
			if (m_cbOnRowDelete)
			{
				blnSuccess = m_cbOnRowDelete(arrRow, strID);
			}

			// Only mark deleted if callback succeeded
			if (blnSuccess)
			{
				// If row was updated, mark as 'DU' (deleted-updated)
				// Otherwise mark as 'D' (deleted)
				if (strCurrentStatus === 'U')
				{
					setRowStatus(intRowIndex_a, 'DU');
				}
				else
				{
					setRowStatus(intRowIndex_a, 'D');
				}
			}

			blnRemoved = false; // Not removed, just marked
		}

		return blnRemoved;
	}

	function toggleRowDeleted(intRowIndex_a)
	{
		var strCurrentStatus = getRowStatus(intRowIndex_a);
		var blnDeleted = false;

		// If deleted, undelete it
		if (strCurrentStatus === 'D')
		{
			setRowStatus(intRowIndex_a, ''); // Back to unchanged
			blnDeleted = false; // Undeleted
		}
		// If deleted-updated, undelete back to updated
		else if (strCurrentStatus === 'DU')
		{
			setRowStatus(intRowIndex_a, 'U'); // Back to updated
			blnDeleted = false; // Undeleted
		}
		// If new-deleted, undelete back to new
		else if (strCurrentStatus === 'ND')
		{
			setRowStatus(intRowIndex_a, 'N'); // Back to new
			blnDeleted = false; // Undeleted
		}
		// Otherwise delete it
		else
		{
			blnDeleted = markRowDeleted(intRowIndex_a);
		}

		return blnDeleted;
	}

	function addNewRow()
	{
		debugOutput('addNewRow: creating new interim row');

		// Create new row with STATUS='I' (interim) and empty values
		var arrNewRow = ['I']; // STATUS = Interim (not yet committed)
		var intIndex = 0;

		// Generate temporary ID
		var strTempID = 'NEW_' + Date.now();
		arrNewRow.push(strTempID); // ID at position 1

		// Add empty values for remaining fields
		for (intIndex = 2; intIndex < m_arrFields.length; intIndex++)
		{
			arrNewRow.push('');
		}

		// Add row (will become 'N' when leaving the row)
		m_arrData.push(arrNewRow);
		var intRowIndex = m_arrData.length - 1;
		debugOutput('addNewRow: row added at index ' + intRowIndex + ' with ID ' + strTempID);
		return intRowIndex; // Return new row index
	}

	function commitInterimRow(intRowIndex_a)
	{
		debugOutput('commitInterimRow: rowIndex=' + intRowIndex_a);
		var blnSuccess = true;

		if (intRowIndex_a >= 0 && intRowIndex_a < m_arrData.length)
		{
			var strStatus = getRowStatus(intRowIndex_a);
			debugOutput('commitInterimRow: status=' + strStatus);

			// Only commit if it's interim
			if (strStatus === 'I')
			{
				var intIDIndex = 1;
				var arrRow = m_arrData[intRowIndex_a];
				var strID = arrRow[intIDIndex];

				debugOutput('commitInterimRow: calling onRowAddNew callback');

				// Call callback if it exists
				if (m_cbOnRowAddNew)
				{
					blnSuccess = m_cbOnRowAddNew(arrRow, strID);
					debugOutput('commitInterimRow: callback returned ' + blnSuccess);
				}
				else
				{
					debugOutput('commitInterimRow: no callback, defaulting to true');
				}

				// If accepted, promote to 'N' (new)
				if (blnSuccess)
				{
					setRowStatus(intRowIndex_a, 'N');
					debugOutput('commitInterimRow: accepted, promoted to N');
				}
				else
				{
					// If rejected, remove the row
					m_arrData.splice(intRowIndex_a, 1);
					debugOutput('commitInterimRow: rejected, row removed');
				}
			}
			else
			{
				debugOutput('commitInterimRow: not interim, returning true');
			}
		}
		else
		{
			debugOutput('commitInterimRow: rowIndex out of bounds, returning true');
		}

		return blnSuccess;
	}

	// Floating editor functions

	function updateRowStatus(intRowIndex_a)
	{
		if (intRowIndex_a >= 0 && intRowIndex_a < m_arrData.length)
		{
			var strStatus = m_arrData[intRowIndex_a][0];
			var objRow = api.element('#' + m_strFormID + ' .ge-list-row[data-row-index="' + intRowIndex_a + '"]');

			// Remove all status classes
			objRow.removeClass('gscr-row-new gscr-row-updated gscr-row-deleted');

			// Add appropriate status class
			if (strStatus === 'N')
			{
				objRow.addClass('gscr-row-new');
			}
			else if (strStatus === 'U')
			{
				objRow.addClass('gscr-row-updated');
			}
			else if (strStatus === 'D' || strStatus === 'DU' || strStatus === 'ND')
			{
				objRow.addClass('gscr-row-deleted');
			}
		}
	}

	function commitCurrentEdit()
	{
		if (m_intEditRow >= 0 && m_intEditCol >= 0 && m_objFloatingEditor)
		{
			var strNewValue = m_objFloatingEditor.val();
			var strOldValue = m_arrData[m_intEditRow][m_intEditCol] || ''; // Save old value
			var blnAccepted = true;

			m_arrData[m_intEditRow][m_intEditCol] = strNewValue;

			// Only try to mark row as edited if value actually changed
			if (String(strNewValue) !== String(strOldValue))
			{
				blnAccepted = markRowEdited(m_intEditRow);

				// If callback rejected (only for existing rows)
				if (!blnAccepted)
				{
					// Restore old value
					m_arrData[m_intEditRow][m_intEditCol] = strOldValue;
					strNewValue = strOldValue;
				}
			}

			// Update the cell value in the DOM
			var objCell = api.element('#' + m_strFormID + ' .ge-list-row[data-row-index="' + m_intEditRow + '"] td[data-field-index="' + m_intEditCol + '"]');
			if (objCell.length > 0)
			{
				var objField = m_arrFields[m_intEditCol];
				objCell.html(formatValue(strNewValue, objField.type));
			}

			// Update row status color without full render
			updateRowStatus(m_intEditRow);

			hideFloatingEditor();
		}

		m_intEditRow = -1;
		m_intEditCol = -1;
	}

	function hideFloatingEditor()
	{
		if (m_objFloatingEditor)
		{
			m_objFloatingEditor.hide();
		}
	}

	function createFloatingEditor()
	{
		var intBlankRowIndex;
		var intCol;
		var intColFound;
		var intCurrentCol;
		var intCurrentRow;

		if (!m_objFloatingEditor)
		{
			var strEditorID = 'ge-floating-editor-' + m_strInstanceGUID;
			var strEditorHTML = '<input type="text" id="' + strEditorID + '" class="ge-floating-editor gscr-floating-editor form-control" style="position: absolute; z-index: 1000; display: none;" />';
			api.element('body').append(strEditorHTML);
			m_objFloatingEditor = api.element('#' + strEditorID);

			m_objFloatingEditor.on('blur', function()
			{
				setTimeout(function()
				{
					commitCurrentEdit();
					// Don't render - the floating textbox just hides, data is already updated
					// We'll render when CommitRows() is called to show status colors
				}, 100);
			});

			m_objFloatingEditor.on('keydown', function(objEvent_a)
			{
				if (objEvent_a.keyCode === 13 || objEvent_a.keyCode === 40) // Enter or Down Arrow
				{
					objEvent_a.preventDefault();

					// Save position
					intCurrentRow = m_intEditRow;
					intCurrentCol = m_intEditCol;

					// Let startEdit handle committing

					// Move down to same column in next row
					if (intCurrentRow < m_arrData.length - 1)
					{
						startEdit(intCurrentRow + 1, intCurrentCol);
					}
					else if (m_blnAllowAddNew)
					{
						// Move to blank row at bottom
						intBlankRowIndex = m_arrData.length;
						startEdit(intBlankRowIndex, intCurrentCol);
					}
					else
					{
						// allowaddnew is false and we're at the last row - stay at current cell
						startEdit(intCurrentRow, intCurrentCol);
					}
				}
				else if (e.keyCode === 38) // Up Arrow
				{
					e.preventDefault();

					// Save position
					intCurrentRow = m_intEditRow;
					intCurrentCol = m_intEditCol;

					// Let startEdit handle committing

					// Move up to same column in previous row
					if (intCurrentRow > 0)
					{
						startEdit(intCurrentRow - 1, intCurrentCol);
					}
					else
					{
						// Already at first row - stay at current cell
						startEdit(intCurrentRow, intCurrentCol);
					}
				}
				else if (e.keyCode === 27) // Escape
				{
					e.preventDefault();
					hideFloatingEditor();
					m_intEditRow = -1;
					m_intEditCol = -1;
					// No render needed - just hide the editor
				}
				else if (e.keyCode === 9) // Tab (or Shift+Tab)
				{
					e.preventDefault();

					// Save position
					var intCurrentRow = m_intEditRow;
					var intCurrentCol = m_intEditCol;

					// Let startEdit handle committing

					if (e.shiftKey)
					{
						// Shift+Tab: Move backward
						var intPrevCol = intCurrentCol - 1;
						var intPrevColFound = false;

						// Find previous editable column in current row
						while (intPrevCol >= 1 && !intPrevColFound)
						{
							if (m_arrFields[intPrevCol].visible)
							{
								startEdit(intCurrentRow, intPrevCol);
								intPrevColFound = true;
							}
							intPrevCol--;
						}

						// No previous column, move to last editable column of previous row
						if (!intPrevColFound && intCurrentRow > 0)
						{
							for (intPrevCol = m_arrFields.length - 1; intPrevCol >= 1 && !intPrevColFound; intPrevCol--)
							{
								if (m_arrFields[intPrevCol].visible)
								{
									startEdit(intCurrentRow - 1, intPrevCol);
									intPrevColFound = true;
								}
							}
						}
						else if (!intPrevColFound)
						{
							// Already at first row - stay at first cell
							for (intPrevCol = 1; intPrevCol < m_arrFields.length && !intPrevColFound; intPrevCol++)
							{
								if (m_arrFields[intPrevCol].visible)
								{
									startEdit(0, intPrevCol);
									intPrevColFound = true;
								}
							}
						}
					}
					else
					{
						// Tab: Move forward
						var intNextCol = intCurrentCol + 1;
						var intNextColFound = false;

						// Find next editable column in current row
						while (intNextCol < m_arrFields.length && !intNextColFound)
						{
							if (m_arrFields[intNextCol].visible)
							{
								startEdit(intCurrentRow, intNextCol);
								intNextColFound = true;
							}
							intNextCol++;
						}

						// No more columns, move to first editable column of next row
						if (!intNextColFound && intCurrentRow < m_arrData.length - 1)
						{
							for (intNextCol = 1; intNextCol < m_arrFields.length && !intNextColFound; intNextCol++)
							{
								if (m_arrFields[intNextCol].visible)
								{
									startEdit(intCurrentRow + 1, intNextCol);
									intNextColFound = true;
								}
							}
						}
						else if (!intNextColFound && m_blnAllowAddNew)
						{
							// Move to blank row
							intBlankRowIndex = m_arrData.length;
							for (intNextCol = 1; intNextCol < m_arrFields.length && !intNextColFound; intNextCol++)
							{
								if (m_arrFields[intNextCol].visible)
								{
									startEdit(intBlankRowIndex, intNextCol);
									intNextColFound = true;
								}
							}
						}
						else if (!intNextColFound)
						{
							// allowaddnew is false and we're at the last row - stay at current cell
							startEdit(intCurrentRow, intCurrentCol);
							intNextColFound = true;
						}
					}
				}
				else if (e.keyCode === 36) // Home
				{
					e.preventDefault();

					// Find first editable column in first row
					intCol = 0;
					intColFound = false;
					for (intCol = 1; intCol < m_arrFields.length && !intColFound; intCol++)
					{
						if (m_arrFields[intCol].visible)
						{
							startEdit(0, intCol);
							intColFound = true;
						}
					}
				}
				else if (e.keyCode === 35) // End
				{
					e.preventDefault();

					// Find last editable column in last DATA row (not blank row)
					var intLastRow = m_arrData.length - 1;
					intCol = 0;
					intColFound = false;
					if (intLastRow >= 0)
					{
						for (intCol = m_arrFields.length - 1; intCol >= 1 && !intColFound; intCol--)
						{
							if (m_arrFields[intCol].visible)
							{
								startEdit(intLastRow, intCol);
								intColFound = true;
							}
						}
					}
				}
			});
		}
	}

	function startEdit(intRow_a, intCol_a)
	{
		debugOutput('startEdit: row=' + intRow_a + ', col=' + intCol_a);

		var blnCanEdit = m_blnAllowEdit || m_blnAllowAddNew;
		var objField = null;

		if (blnCanEdit)
		{
			objField = m_arrFields[intCol_a];
			if (objField && intCol_a !== 0)
			{
				// Hide editor immediately to prevent visual glitch during position changes
				hideFloatingEditor();

				// Track previous row before committing
				var intPreviousRow = m_intEditRow;
				debugOutput('startEdit: previousRow=' + intPreviousRow);

				if (m_intEditRow >= 0)
				{
					debugOutput('startEdit: committing current edit');
					commitCurrentEdit();
				}

				// If moving to a different row, commit any interim row
				if (intPreviousRow >= 0 && intPreviousRow !== intRow_a)
				{
					debugOutput('startEdit: moving to different row, committing interim row ' + intPreviousRow);
					var blnSuccess = commitInterimRow(intPreviousRow);

					// If interim row was rejected and removed, adjust target row index
					if (!blnSuccess)
					{
						debugOutput('startEdit: interim rejected and removed, re-rendering');
						m_objThis.render(); // Re-render to remove row from DOM

						if (intRow_a > intPreviousRow)
						{
							debugOutput('startEdit: adjusting target row from ' + intRow_a + ' to ' + (intRow_a - 1));
							intRow_a--;
						}
					}
				}

				// Check if editing blank row (for allowaddnew)
				if (intRow_a >= m_arrData.length && m_blnAllowAddNew)
				{
					debugOutput('startEdit: editing blank row, adding new row');
					// Create new row when starting to edit blank row
					intRow_a = addNewRow();

					// Re-render to show new blank row at bottom
					m_objThis.render();
				}

				m_intEditRow = intRow_a;
				m_intEditCol = intCol_a;
				createFloatingEditor();

				// Find the cell by field index (not TD index)
				var strSelector = '#' + m_strFormID + ' .ge-list-row[data-row-index="' + intRow_a + '"] td[data-field-index="' + intCol_a + '"]';
				var objCell = api.element(strSelector);

				if (objCell.length > 0)
				{
					var objOffset = objCell.offset();
					var intWidth = objCell.outerWidth();
					var intHeight = objCell.outerHeight();

					m_objFloatingEditor.css({
						left: objOffset.left + 'px',
						top: objOffset.top + 'px',
						width: intWidth + 'px',
						height: intHeight + 'px'
					});

					var strValue = '';
					if (intRow_a < m_arrData.length)
					{
						strValue = m_arrData[intRow_a][intCol_a] || '';
					}
					m_objFloatingEditor.val(strValue);

					// Set readonly attribute based on field.editable property
					if (objField.editable === false)
					{
						m_objFloatingEditor.attr('readonly', 'readonly');
						debugOutput('startEdit: field is readonly, editor set to readonly');
					}
					else
					{
						m_objFloatingEditor.removeAttr('readonly');
					}

					m_objFloatingEditor.show(); // Show only after positioning
					m_objFloatingEditor.focus();
					m_objFloatingEditor.select();
				}
			}
			else
			{
				debugOutput('startEdit: field not valid or is row selector, returning');
			}
		}
		else
		{
			debugOutput('startEdit: editing not allowed, returning');
		}
	}

	// Rendering

	function renderToolbar()
	{
		// No toolbar if search is disabled
		var strHTML = '';

		if (m_blnAllowSearch)
		{
			var intIndex = 0;
			var objOperation = null;
			var blnHasSelection = m_strSelectedID !== null || m_arrSelectedIDs.length > 0;

			strHTML += '<div class="gscr-list-toolbar">';

			// Search box and controls - wrap on mobile
			strHTML += '<div class="gscr-toolbar-search">';
			strHTML += '<input type="text" class="ge-list-search form-control" placeholder="Search..." value="' + m_strSearch + '">';
			strHTML += '<button class="ge-list-clear btn btn-secondary" title="Clear search">×</button>';
			strHTML += '<button class="ge-list-refresh btn btn-secondary" title="Refresh">⟳</button>';
			strHTML += '</div>';

			// Operation buttons - wrap on mobile
			strHTML += '<div class="gscr-toolbar-operations">';
			for (intIndex = 0; intIndex < m_arrOperations.length; intIndex++)
			{
				objOperation = m_arrOperations[intIndex];
				strHTML += '<button class="ge-operation ge-operation-' + objOperation.code + ' btn btn-primary" data-operation="' + objOperation.code + '"';

				// Disable if requires selection and no selection
				if (objOperation.requiresselection && !blnHasSelection)
				{
					strHTML += ' disabled';
				}

				strHTML += '>';
				strHTML += objOperation.caption;
				strHTML += '</button>';
			}
			strHTML += '</div>';

			strHTML += '</div>';
		}

		return strHTML;
	}

	function renderListHeader()
	{
		var strHTML = '';
		var intIndex = 0;
		var objField = null;

		strHTML += '<thead class="gscr-list-header">';
		strHTML += '<tr>';

		// Add row selector column header when editing is enabled
		if (m_blnAllowEdit || m_blnAllowAddNew || m_blnAllowDelete)
		{
			strHTML += '<th class="gscr-list-header-cell gscr-row-selector">&nbsp;</th>';
		}

		for (intIndex = 0; intIndex < m_arrFields.length; intIndex++)
		{
			objField = m_arrFields[intIndex];

			if (objField.visible)
			{
				strHTML += '<th class="gscr-list-header-cell';
				if (objField.sortable)
				{
					strHTML += ' gscr-list-sortable gscr-sortable-active ge-list-sort';
				}
				else
				{
					strHTML += ' gscr-list-sortable gscr-sortable-inactive';
				}
				strHTML += '" data-field="' + objField.code + '">';
				strHTML += objField.caption;

				// Sort indicator
				if (objField.sortable)
				{
					var objSort = null;
					var intSortIndex = 0;

					for (intSortIndex = 0; intSortIndex < m_arrOrder.length; intSortIndex++)
					{
						if (m_arrOrder[intSortIndex].fieldname === objField.code)
						{
							objSort = m_arrOrder[intSortIndex];
							break;
						}
					}

					if (objSort)
					{
						strHTML += ' <span class="gscr-sort-indicator">';
						strHTML += objSort.ascending ? '▲' : '▼';
						if (m_arrOrder.length > 1)
						{
							strHTML += '<sup>' + (intSortIndex + 1) + '</sup>';
						}
						strHTML += '</span>';
					}
				}

				strHTML += '</th>';
			}
		}

		strHTML += '</tr>';
		strHTML += '</thead>';

		return strHTML;
	}

	function renderListBody()
	{
		var strHTML = '';
		var intRowIndex = 0;
		var intFieldIndex = 0;
		var arrRow = null;
		var objField = null;
		var strID = '';
		var strValue = null;

		strHTML += '<tbody class="gscr-list-body">';

		for (intRowIndex = 0; intRowIndex < m_arrData.length; intRowIndex++)
		{
			arrRow = m_arrData[intRowIndex];

			// ID position depends on whether editing is enabled (STATUS column present)
			var intIDIndex = (m_blnAllowEdit || m_blnAllowAddNew || m_blnAllowDelete) ? 1 : 0;
			strID = arrRow[intIDIndex] || '';

			// Get STATUS if editing enabled
			var strStatus = '';
			if (m_blnAllowEdit || m_blnAllowAddNew || m_blnAllowDelete)
			{
				strStatus = arrRow[0] || '';
			}

			strHTML += '<tr class="ge-list-row gscr-list-row';
			if (strID === m_strSelectedID)
			{
				strHTML += ' gscr-list-row-selected';
			}
			if (strStatus === 'N')
			{
				strHTML += ' gscr-row-new';
			}
			else if (strStatus === 'U')
			{
				strHTML += ' gscr-row-updated';
			}
			else if (strStatus === 'D' || strStatus === 'DU' || strStatus === 'ND')
			{
				strHTML += ' gscr-row-deleted';
			}
			strHTML += '" data-id="' + strID + '" data-row-index="' + intRowIndex + '">';

			// Add row selector cell when editing is enabled
			if (m_blnAllowEdit || m_blnAllowAddNew || m_blnAllowDelete)
			{
				strHTML += '<td class="gscr-list-cell gscr-row-selector" data-row-index="' + intRowIndex + '">' + (intRowIndex + 1) + '</td>';
			}

			for (intFieldIndex = 0; intFieldIndex < m_arrFields.length; intFieldIndex++)
			{
				objField = m_arrFields[intFieldIndex];

				if (objField.visible)
				{
					strValue = arrRow[intFieldIndex];

					strHTML += '<td class="gscr-list-cell';
					if ((m_blnAllowEdit || m_blnAllowAddNew) && intFieldIndex > 0)
					{
						strHTML += ' gscr-editable-cell';

						// Add readonly class if field is not editable
						if (objField.editable === false)
						{
							strHTML += ' gscr-readonly-cell';
						}
					}
					strHTML += '" data-field-index="' + intFieldIndex + '">';
					strHTML += formatValue(strValue, objField.type);
					strHTML += '</td>';
				}
			}

			strHTML += '</tr>';
		}

		if (m_arrData.length === 0)
		{
			strHTML += '<tr><td colspan="' + m_arrFields.filter(function(fn_a) { return fn_a.visible; }).length + '" class="gscr-empty-state">No records found</td></tr>';
		}

		// Add blank row at bottom for allowaddnew
		if (m_blnAllowAddNew)
		{
			var intBlankRowIndex = m_arrData.length;
			strHTML += '<tr class="ge-list-row gscr-list-row gscr-blank-row" data-id="" data-row-index="' + intBlankRowIndex + '">';

			// Add row selector with "*" for blank row
			if (m_blnAllowEdit || m_blnAllowAddNew || m_blnAllowDelete)
			{
				strHTML += '<td class="gscr-list-cell gscr-row-selector">*</td>';
			}

			for (intFieldIndex = 0; intFieldIndex < m_arrFields.length; intFieldIndex++)
			{
				objField = m_arrFields[intFieldIndex];

				if (objField.visible)
				{
					strHTML += '<td class="gscr-list-cell';
					if (intFieldIndex > 0)
					{
						strHTML += ' gscr-editable-cell';

						// Add readonly class if field is not editable
						if (objField.editable === false)
						{
							strHTML += ' gscr-readonly-cell';
						}
					}
					strHTML += '" data-field-index="' + intFieldIndex + '"><span class="gscr-placeholder">...</span></td>';
				}
			}

			strHTML += '</tr>';
		}

		strHTML += '</tbody>';

		return strHTML;
	}

	function renderListView()
	{
		var strHTML = '';
		var strOverflow = 'auto';
		var strHeight = '100%';

		// PAGED = no scrollbars (fixed height), CONTINUOUS = scrollable (fixed height), EXPAND = no scrollbars (auto height)
		if (m_strFlow === 'PAGED')
		{
			strOverflow = 'hidden';
		}
		else if (m_strFlow === 'EXPAND')
		{
			strOverflow = 'visible';
			strHeight = 'auto';
		}

		strHTML += '<div class="gscr-list-container" style="height: ' + strHeight + ';">';

		// Toolbar
		strHTML += renderToolbar();

		// List table
		strHTML += '<div class="gscr-list-scroll" style="overflow: ' + strOverflow + ';">';
		strHTML += '<table class="gscr-list-table table">';
		strHTML += renderListHeader();
		strHTML += renderListBody();
		strHTML += '</table>';
		strHTML += '</div>';

		// Pagination footer (not for EXPAND)
		if (m_strFlow !== 'EXPAND')
		{
			strHTML += renderPagination();
		}

		strHTML += '</div>';

		return strHTML;
	}

	function renderGalleryView()
	{
		var strHTML = '';
		var intRowIndex = 0;
		var arrRow = null;
		var strID = '';
		var strImageURL = '';
		var strDescription = '';
		var intImageFieldIndex = getFieldIndexByCode(m_strImageField);
		var strOverflow = 'auto';
		var strHeight = '100%';

		// PAGED = no scrollbars (fixed height), CONTINUOUS = scrollable (fixed height), EXPAND = no scrollbars (auto height)
		if (m_strFlow === 'PAGED')
		{
			strOverflow = 'hidden';
		}
		else if (m_strFlow === 'EXPAND')
		{
			strOverflow = 'visible';
			strHeight = 'auto';
		}

		strHTML += '<div class="gscr-gallery-container" style="height: ' + strHeight + ';">';

		// Toolbar
		strHTML += renderToolbar();

		// Gallery grid
		strHTML += '<div class="gscr-gallery-scroll" style="overflow: ' + strOverflow + ';">';
		strHTML += '<div class="gscr-gallery-grid" style="grid-template-columns: repeat(auto-fill, minmax(' + m_objThumbSize.X + 'px, 1fr));">';

		for (intRowIndex = 0; intRowIndex < m_arrData.length; intRowIndex++)
		{
			arrRow = m_arrData[intRowIndex];
			strID = arrRow[0] || '';

			if (intImageFieldIndex >= 0)
			{
				strImageURL = arrRow[intImageFieldIndex] || '';
			}

			if (m_cbGetDescription && typeof m_cbGetDescription === 'function')
			{
				strDescription = m_cbGetDescription(arrRow);
			}
			else
			{
				strDescription = strID;
			}

			strHTML += '<div class="ge-gallery-item gscr-gallery-item';
			if (strID === m_strSelectedID)
			{
				strHTML += ' gscr-gallery-item-selected';
			}
			strHTML += '" data-id="' + strID + '" data-row-index="' + intRowIndex + '">';

			strHTML += '<div class="gscr-gallery-thumb" style="width: ' + m_objThumbSize.X + 'px; height: ' + m_objThumbSize.Y + 'px;">';

			if (strImageURL)
			{
				strHTML += '<img src="' + strImageURL + '" />';
			}
			else
			{
				strHTML += '<span class="gscr-gallery-no-image">No image</span>';
			}

			strHTML += '</div>';

			strHTML += '<div class="gscr-gallery-caption">';
			strHTML += strDescription;
			strHTML += '</div>';

			strHTML += '</div>';
		}

		if (m_arrData.length === 0)
		{
			strHTML += '<div class="gscr-empty-state" style="grid-column: 1 / -1;">No items found</div>';
		}

		strHTML += '</div>';
		strHTML += '</div>';

		// Pagination footer (not for EXPAND)
		if (m_strFlow !== 'EXPAND')
		{
			strHTML += renderPagination();
		}

		strHTML += '</div>';

		return strHTML;
	}

	function renderPagination()
	{
		var strHTML = '';

		if (m_strFlow === 'PAGED')
		{
			var blnHasPrevious = m_intOffset > 0;
			var blnHasNext = m_objControl && m_objControl.more;
			var intTotal = m_objControl && m_objControl.total ? m_objControl.total : 0;
			var intStart = m_intOffset + 1;
			var intEnd = m_intOffset + m_arrData.length;

			strHTML += '<div class="gscr-list-pagination">';

			// Info - takes full width on mobile
			strHTML += '<div class="gscr-pagination-info">';
			if (intTotal > 0)
			{
				strHTML += 'Showing ' + intStart + ' to ' + intEnd + ' of ' + intTotal;
			}
			else if (m_arrData.length > 0)
			{
				strHTML += 'Showing ' + intStart + ' to ' + intEnd;
			}
			else
			{
				strHTML += 'No records';
			}
			strHTML += '</div>';

			// Buttons - wrap on mobile
			strHTML += '<div class="gscr-pagination-buttons">';
			strHTML += '<button class="ge-list-first btn btn-secondary"' + (!blnHasPrevious ? ' disabled' : '') + '>&lt;&lt; First</button>';
			strHTML += '<button class="ge-list-previous btn btn-secondary"' + (!blnHasPrevious ? ' disabled' : '') + '>‹ Previous</button>';
			strHTML += '<button class="ge-list-next btn btn-secondary"' + (!blnHasNext ? ' disabled' : '') + '>Next ›</button>';
				if (m_strFlow === 'PAGED')
				{
					strHTML += '<button class="ge-list-last btn btn-secondary"' + (!blnHasNext ? ' disabled' : '') + '>Last &gt;&gt;</button>';
				}
			strHTML += '</div>';

			strHTML += '</div>';
		}

		return strHTML;
	}

	// Event binding

	function bindEvents()
	{
		// Unbind all events first to prevent double-binding
		api.element('#' + m_strFormID, '.ge-list-search').off('keyup');
		api.element('#' + m_strFormID, '.ge-list-clear').off('click');
		api.element('#' + m_strFormID, '.ge-list-refresh').off('click');
		api.element('#' + m_strFormID, '.ge-list-sort').off('click');
		api.element('#' + m_strFormID, '.ge-list-row').off('click');
		api.element('#' + m_strFormID, '.ge-list-row').off('dblclick');
		api.element('#' + m_strFormID, '.ge-gallery-item').off('click');
		api.element('#' + m_strFormID, '.ge-gallery-item').off('dblclick');
		api.element('#' + m_strFormID, '.ge-operation').off('click');
		api.element('#' + m_strFormID, '.ge-list-first').off('click');
		api.element('#' + m_strFormID, '.ge-list-previous').off('click');
		api.element('#' + m_strFormID, '.ge-list-next').off('click');
		// Unbind editing-related events
		api.element('#' + m_strFormID).off('click', '.gscr-editable-cell');
		api.element('#' + m_strFormID).off('click', '.gscr-row-selector');
		api.element('#' + m_strFormID).off('keydown');
		api.element('#' + m_strFormID).off('focus');
		// Unbind drag-drop events
		api.element('#' + m_strFormID).off('dragover').off('dragenter').off('dragleave').off('drop');

		// Search
		api.element('#' + m_strFormID, '.ge-list-search').on('keyup', function(objEvent_a)
		{
			if (objEvent_a.keyCode === 13) // Enter
			{
				m_strSearch = api.element(this).val();
				m_intOffset = 0;
				clearSelection();
				m_objThis.refresh(true);
			}
		});

		api.element('#' + m_strFormID, '.ge-list-clear').on('click', function()
		{
			api.element('#' + m_strFormID, '.ge-list-search').val('');
			m_strSearch = '';
			m_intOffset = 0;
			clearSelection();
			m_objThis.refresh(true);
		});

		api.element('#' + m_strFormID, '.ge-list-refresh').on('click', function()
		{
			m_objThis.refresh(true);
		});

		// Sorting
		api.element('#' + m_strFormID, '.ge-list-sort').on('click', function(objEvent_a)
		{
			var strFieldCode = api.element(this).data('field');
			var blnShiftKey = objEvent_a.shiftKey;
			var intIndex = 0;
			var objExisting = null;

			// Find existing sort for this field
			for (intIndex = 0; intIndex < m_arrOrder.length; intIndex++)
			{
				if (m_arrOrder[intIndex].fieldname === strFieldCode)
				{
					objExisting = m_arrOrder[intIndex];
					break;
				}
			}

			if (!blnShiftKey)
			{
				// Single sort - clear others
				m_arrOrder = [];
			}

			if (objExisting)
			{
				// Toggle direction
				if (!blnShiftKey)
				{
					m_arrOrder = [{fieldname: strFieldCode, ascending: !objExisting.ascending}];
				}
				else
				{
					objExisting.ascending = !objExisting.ascending;
				}
			}
			else
			{
				// Add new sort
				m_arrOrder.push({fieldname: strFieldCode, ascending: true});
			}

			m_intOffset = 0;
			clearSelection();
			m_objThis.refresh();
		});

		// Row selection (only for non-editable grids)
		if (!m_blnAllowEdit && !m_blnAllowAddNew && !m_blnAllowDelete)
		{
			api.element('#' + m_strFormID, '.ge-list-row').on('click', function()
			{
				var objThis = api.element(this);
				var strID = objThis.data('id');
				var intRowIndex = objThis.data('row-index');
				var arrRow = m_arrData[intRowIndex];

				// Remove previous selection class
				api.element('#' + m_strFormID, '.gscr-list-row-selected').removeClass('gscr-list-row-selected');

				// Add selection class to clicked row
				objThis.addClass('gscr-list-row-selected');

				setSelection(strID);

				if (m_cbOnClick && typeof m_cbOnClick === 'function')
				{
					m_cbOnClick(arrRow, strID);
				}
			});
		}
		else
		{
			// Row selection for EDITABLE grids via row selector cells only
			api.element('#' + m_strFormID).on('click', '.gscr-row-selector', function(objEvent_a)
			{
				objEvent_a.stopPropagation();
				var objRow = api.element(this).closest('tr');
				var strID = objRow.data('id');
				var intRowIndex = objRow.data('row-index');

				// Don't select blank row
				if (!objRow.hasClass('gscr-blank-row'))
				{
					var arrRow = m_arrData[intRowIndex];

					// If selecting an interim row, commit it first
					var strStatus = getRowStatus(intRowIndex);
					if (strStatus === 'I')
					{
						debugOutput('Row selector: committing interim row ' + intRowIndex);
						var blnSuccess = commitInterimRow(intRowIndex);

						// If commit was rejected, row was removed - don't select it
						if (!blnSuccess)
						{
							debugOutput('Row selector: interim row rejected and removed');
							m_objThis.render();
						}
						else
						{
							// Row was committed successfully, continue with selection
							m_objThis.render(); // Re-render to show 'N' status

							// Remove previous selection class
							api.element('#' + m_strFormID, '.gscr-list-row-selected').removeClass('gscr-list-row-selected');

							// Add selection class to clicked row
							objRow.addClass('gscr-list-row-selected');

							setSelection(strID);

							// Focus container so Delete key works
							api.element('#' + m_strFormID + ' .gscr-list-container, #' + m_strFormID + ' .gscr-gallery-container').focus();

							if (m_cbOnClick && typeof m_cbOnClick === 'function')
							{
								m_cbOnClick(arrRow, strID);
							}
						}
					}
					else
					{
						// Remove previous selection class
						api.element('#' + m_strFormID, '.gscr-list-row-selected').removeClass('gscr-list-row-selected');

						// Add selection class to clicked row
						objRow.addClass('gscr-list-row-selected');

						setSelection(strID);

						// Focus container so Delete key works
						api.element('#' + m_strFormID + ' .gscr-list-container, #' + m_strFormID + ' .gscr-gallery-container').focus();

						if (m_cbOnClick && typeof m_cbOnClick === 'function')
						{
							m_cbOnClick(arrRow, strID);
						}
					}
				}
			});
		}

		api.element('#' + m_strFormID, '.ge-list-row').on('dblclick', function()
		{
			var strID = api.element(this).data('id');
			var intRowIndex = api.element(this).data('row-index');
			var arrRow = m_arrData[intRowIndex];

			if (m_cbOnDblClick && typeof m_cbOnDblClick === 'function')
			{
				m_cbOnDblClick(arrRow, strID);
			}
		});

		// Gallery item selection
		api.element('#' + m_strFormID, '.ge-gallery-item').on('click', function()
		{
			var objThis = api.element(this);
			var strID = objThis.data('id');
			var intRowIndex = objThis.data('row-index');
			var arrRow = m_arrData[intRowIndex];

			// Remove previous selection class
			api.element('#' + m_strFormID, '.gscr-gallery-item-selected').removeClass('gscr-gallery-item-selected');

			// Add selection class to clicked item
			objThis.addClass('gscr-gallery-item-selected');

			setSelection(strID);

			if (m_cbOnClick && typeof m_cbOnClick === 'function')
			{
				m_cbOnClick(arrRow, strID);
			}
		});

		api.element('#' + m_strFormID, '.ge-gallery-item').on('dblclick', function()
		{
			var strID = api.element(this).data('id');
			var intRowIndex = api.element(this).data('row-index');
			var arrRow = m_arrData[intRowIndex];

			if (m_cbOnDblClick && typeof m_cbOnDblClick === 'function')
			{
				m_cbOnDblClick(arrRow, strID);
			}
		});

		// Operation buttons
		api.element('#' + m_strFormID, '.ge-operation').on('click', function()
		{
			var strOperation = api.element(this).data('operation');
			var arrRow = null;
			var intRowIndex = 0;

			// Find selected row data
			if (m_strSelectedID)
			{
				for (intRowIndex = 0; intRowIndex < m_arrData.length; intRowIndex++)
				{
					if (m_arrData[intRowIndex][0] === m_strSelectedID)
					{
						arrRow = m_arrData[intRowIndex];
						break;
					}
				}
			}

			if (m_cbOnOperation && typeof m_cbOnOperation === 'function')
			{
				m_cbOnOperation(strOperation, arrRow, m_strSelectedID);
			}
		});

		// Pagination
		api.element('#' + m_strFormID, '.ge-list-first').on('click', function()
		{
			m_intOffset = 0;
			m_objThis.refresh();
		});

		api.element('#' + m_strFormID, '.ge-list-previous').on('click', function()
		{
			m_intOffset = Math.max(0, m_intOffset - m_intLimit);
			m_objThis.refresh();
		});

		api.element('#' + m_strFormID, '.ge-list-next').on('click', function()
		{
			m_intOffset = m_intOffset + m_intLimit;
			m_objThis.refresh();
		});

		if (m_strFlow === 'PAGED')
		{
			api.element('#' + m_strFormID, '.ge-list-last').on('click', function()
			{
				var intTotal = m_objControl && m_objControl.total ? m_objControl.total : 0;

				m_intOffset = intTotal - m_intLimit;
				m_objThis.refresh();
			});
		}

		// Continuous scroll (infinite scroll)
		if (m_strFlow === 'CONTINUOUS')
		{
			var strScrollSelector = m_strType === 'LIST' ? '.gscr-list-scroll' : '.gscr-gallery-scroll';
			var objScrollContainer = api.element('#' + m_strFormID, strScrollSelector);

			objScrollContainer.on('scroll', function()
			{
				// Don't trigger if already loading
				if (!m_blnLoading)
				{
					var intScrollTop = api.element(this).scrollTop();
					var intScrollHeight = api.element(this)[0].scrollHeight;
					var intClientHeight = api.element(this).height();

					// Near bottom (within 100px)
					if (intScrollTop + intClientHeight >= intScrollHeight - 100)
					{
						// Check if more data available
						if (m_objControl && m_objControl.more)
						{
							m_blnLoading = true;
							m_intOffset = m_intOffset + m_intLimit;

							// Load more data and append
							loadData(function()
							{
								// Append new rows to existing tbody/grid
								if (m_strType === 'LIST')
								{
									var strNewRows = renderListBody();
									// Extract just the rows (skip tbody wrapper)
									var objTemp = api.element('<div>').html(strNewRows);
									var strRows = objTemp.find('tr').parent().html();
									api.element('#' + m_strFormID, '.gscr-list-body').append(strRows);
								}
								else
								{
									// Append new gallery items
									var intRowIndex = 0;
									var arrRow = null;
									var strID = '';
									var strImageURL = '';
									var strDescription = '';
									var intImageFieldIndex = getFieldIndexByCode(m_strImageField);
									var strNewItems = '';

									for (intRowIndex = 0; intRowIndex < m_arrData.length; intRowIndex++)
									{
										arrRow = m_arrData[intRowIndex];
										strID = arrRow[0] || '';

										if (intImageFieldIndex >= 0)
										{
											strImageURL = arrRow[intImageFieldIndex] || '';
										}

										if (m_cbGetDescription && typeof m_cbGetDescription === 'function')
										{
											strDescription = m_cbGetDescription(arrRow);
										}
										else
										{
											strDescription = strID;
										}

										strNewItems += '<div class="ge-gallery-item gscr-gallery-item" data-id="' + strID + '" data-row-index="' + intRowIndex + '">';
										strNewItems += '<div class="gscr-gallery-thumb" style="width: ' + m_objThumbSize.X + 'px; height: ' + m_objThumbSize.Y + 'px;">';

										if (strImageURL)
										{
											strNewItems += '<img src="' + strImageURL + '" />';
										}
										else
										{
											strNewItems += '<span class="gscr-gallery-no-image">No image</span>';
										}

										strNewItems += '</div>';
										strNewItems += '<div class="gscr-gallery-caption">' + strDescription + '</div>';
										strNewItems += '</div>';
									}

									api.element('#' + m_strFormID, '.gscr-gallery-grid').append(strNewItems);
								}

								bindEvents();
								m_blnLoading = false;
							});
						}
					}
				}
			});
		}

		// Cell editing for editable grids
		if (m_blnAllowEdit || m_blnAllowAddNew)
		{
			// Single click on editable cells to edit (using proper event delegation)
			api.element('#' + m_strFormID).on('click', '.gscr-editable-cell', function(objEvent_a)
			{
				objEvent_a.stopPropagation();
				var objCell = api.element(this);
				var objRow = objCell.closest('tr');
				var intRowIndex = objRow.data('row-index');
				var intFieldIndex = objCell.data('field-index'); // Use field index from data attribute
				clearSelection(); // Clear row selection when starting to edit
				startEdit(intRowIndex, intFieldIndex);
			});
		}

		if (m_blnAllowEdit || m_blnAllowAddNew || m_blnAllowDelete)
		{
			// Make internal container tabbable so you can Tab into the grid
			api.element('#' + m_strFormID + ' .gscr-list-container, #' + m_strFormID + ' .gscr-gallery-container').attr('tabindex', '0');

			var m_blnClickInProgress = false;

			// When container gets focus, start editing first cell (but only for Tab navigation)
			api.element('#' + m_strFormID + ' .gscr-list-container, #' + m_strFormID + ' .gscr-gallery-container').on('focus', function(objEvent_a)
			{
				// Don't auto-edit if a click is in progress
				if (!m_blnClickInProgress)
				{
					// Only auto-edit if nothing is currently being edited
					if (m_intEditRow < 0 && m_arrData.length > 0)
					{
						// Find first editable column
						var intCol = 0;
						for (intCol = 1; intCol < m_arrFields.length; intCol++)
						{
							if (m_arrFields[intCol].visible)
							{
								startEdit(0, intCol);
								break;
							}
						}
					}
				}
			});

			// Set flag on mousedown to prevent focus handler
			api.element('#' + m_strFormID).on('mousedown', function(objEvent_a)
			{
				m_blnClickInProgress = true;
			});

			// Clear flag after click completes
			api.element('#' + m_strFormID).on('mouseup', function(objEvent_a)
			{
				setTimeout(function()
				{
					m_blnClickInProgress = false;
				}, 100);
			});
		}

		if (m_blnAllowDelete)
		{
			api.element('#' + m_strFormID).on('keydown', function(objEvent_a)
			{
				if (objEvent_a.keyCode === 46 && !objEvent_a.ctrlKey && m_intEditRow < 0 && m_strSelectedID)
				{
					objEvent_a.preventDefault();
					var intIDIndex = (m_blnAllowEdit || m_blnAllowAddNew || m_blnAllowDelete) ? 1 : 0;
					var intI = 0;
					for (intI = 0; intI < m_arrData.length; intI++)
					{
						if (m_arrData[intI][intIDIndex] === m_strSelectedID)
						{
							// Ignore delete on interim rows - they haven't been committed yet
							var strStatus = getRowStatus(intI);
							if (strStatus !== 'I')
							{
								toggleRowDeleted(intI);
								clearSelection();
								m_objThis.render();
							}
							else
							{
								debugOutput('Delete key: ignoring interim row (not yet committed)');
							}
							break;
						}
					}
				}
			});
		}

		// Drag-drop files onto the list/gallery container
		if (m_blnAllowDragDrop && m_cbOnDragDropItem)
		{
			var strContainerSelector = '#' + m_strFormID + ' .gscr-list-container, #' + m_strFormID + ' .gscr-gallery-container';

			api.element('#' + m_strFormID).on('dragover dragenter', function(objEvent_a)
			{
				objEvent_a.preventDefault();
				objEvent_a.stopPropagation();
				api.element(strContainerSelector).addClass('gscr-dragover');
			});

			api.element('#' + m_strFormID).on('dragleave', function(objEvent_a)
			{
				// Only remove highlight when leaving the list entirely
				if (!api.element('#' + m_strFormID)[0].contains(objEvent_a.relatedTarget))
				{
					api.element(strContainerSelector).removeClass('gscr-dragover');
				}
			});

			api.element('#' + m_strFormID).on('drop', function(objEvent_a)
			{
				objEvent_a.preventDefault();
				objEvent_a.stopPropagation();
				api.element(strContainerSelector).removeClass('gscr-dragover');

				var objFiles = objEvent_a.originalEvent.dataTransfer.files;

				if (objFiles && objFiles.length > 0 && typeof m_cbOnDragDropItem === 'function')
				{
					m_cbOnDragDropItem(objFiles);
				}
			});
		}
	}

	// Public methods

	this.render = function(blnRefocusSearch_a)
	{
		var strHTML = '';

		if (m_strType === 'GALLERY')
		{
			strHTML = renderGalleryView();
		}
		else
		{
			strHTML = renderListView();
		}

		// Update DOM if target is set
		if (m_strTarget.length > 0)
		{
			api.element('#' + m_strFormID, '.' + m_strTarget).html(strHTML);
		}
		// Or update the formID container itself
		else if (api.element('#' + m_strFormID).length > 0)
		{
			api.element('#' + m_strFormID).html(strHTML);
		}

		// Always bind events after render (defer to next tick to ensure DOM is ready)
		setTimeout(function()
		{
			bindEvents();
			updateOperationButtons();

			// Refocus search box if requested
			if (blnRefocusSearch_a)
			{
				var objSearchBox = api.element('#' + m_strFormID, '.ge-list-search');
				if (objSearchBox.length > 0)
				{
					objSearchBox.focus();
					// Optional: move cursor to end
					var strVal = objSearchBox.val();
					objSearchBox.val('').val(strVal);
				}
			}
		}, 0);

		return strHTML;
	};

	this.refresh = function(blnRefocusSearch_a)
	{
		loadData(function()
		{
			m_objThis.render(blnRefocusSearch_a);
		});
	};

	this.getSelectedID = function()
	{
		return m_strSelectedID;
	};

	this.getSelectedRow = function()
	{
		var intRowIndex = 0;
		var intIDIndex = (m_blnAllowEdit || m_blnAllowAddNew || m_blnAllowDelete) ? 1 : 0;
		var arrSelectedRow = null;

		if (m_strSelectedID)
		{
			for (intRowIndex = 0; intRowIndex < m_arrData.length; intRowIndex++)
			{
				if (m_arrData[intRowIndex][intIDIndex] === m_strSelectedID)
				{
					arrSelectedRow = m_arrData[intRowIndex];
					break;
				}
			}
		}

		return arrSelectedRow;
	};

	this.setData = function(objData_a)
	{
		processServerResponse(objData_a);
		m_objThis.render();
	};

	this.getData = function()
	{
		return m_arrData;
	};

	this.getDataChanges = function()
	{
		debugOutput('getDataChanges: checking ' + m_arrData.length + ' rows');

		var arrChanges = [];
		var intIndex = 0;
		var strStatus = '';

		for (intIndex = 0; intIndex < m_arrData.length; intIndex++)
		{
			strStatus = m_arrData[intIndex][0];
			debugOutput('getDataChanges: row ' + intIndex + ' status=' + strStatus);

			// Include ALL statuses except '' (empty) and 'I' (interim/uncommitted)
			// This includes: N, U, D, DU, ND
			if (strStatus !== '' && strStatus !== 'I')
			{
				debugOutput('getDataChanges: including row ' + intIndex);
				arrChanges.push(m_arrData[intIndex]);
			}
			else
			{
				debugOutput('getDataChanges: excluding row ' + intIndex + ' (status=' + strStatus + ')');
			}
		}

		debugOutput('getDataChanges: returning ' + arrChanges.length + ' rows');
		return arrChanges;
	};

	this.CommitRows = function()
	{
		debugOutput('CommitRows: starting');

		// Flush any uncommitted edits
		if (m_intEditRow >= 0)
		{
			debugOutput('CommitRows: committing current edit at row ' + m_intEditRow);
			commitCurrentEdit();
		}

		// Commit ALL interim rows (not just the one being edited)
		var intIndex = 0;
		while (intIndex < m_arrData.length)
		{
			var strStatus = getRowStatus(intIndex);
			if (strStatus === 'I')
			{
				debugOutput('CommitRows: found interim row at ' + intIndex + ', committing');
				var blnSuccess = commitInterimRow(intIndex);

				// If row was rejected and removed, don't increment index
				if (!blnSuccess)
				{
					debugOutput('CommitRows: interim row ' + intIndex + ' was rejected and removed');
					continue; // Don't increment, next row shifted down
				}
			}
			intIndex++;
		}

		debugOutput('CommitRows: re-rendering');
		// Re-render to update display
		m_objThis.render();
	};

	// Initialize
	if (m_objParameters.initialData)
	{
		processServerResponse(m_objParameters.initialData);

		// Calculate proper page size based on container (overrides server limit)
		// This ensures CONTINUOUS mode gets enough items to overflow
		var intCalculatedLimit = calculatePageSize();

		// If calculated limit is larger than what we have, load more data
		if (intCalculatedLimit > m_arrData.length && m_cbLoadData)
		{
			m_intLimit = intCalculatedLimit;
			loadData(function()
			{
				m_objThis.render();
				updateOperationButtons();
			});
		}
		else
		{
			m_intLimit = intCalculatedLimit;
			m_objThis.render();
			updateOperationButtons();
		}
	}
	else if (m_strDataSource)
	{
		// Calculate page size before loading data
		m_intLimit = calculatePageSize();

		loadData(function()
		{
			m_objThis.render();
			updateOperationButtons();
		});
	}
}
