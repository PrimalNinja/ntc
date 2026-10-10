// tinyz80b GUI - realtime VB style BASIC to NTC, with a project explorer. ES5.
// (c) 2026 Cyborg Unicorn Pty Ltd - MIT License
//
// Left:   the project's files (listRenderer) - modules (.bas) and classes (.cls)
// Middle: the selected file in the editor (textEditor)
// Right:  the NTC output for the whole project, compiled as you type

var api = {
	element: function(strScope_a, strClass_a)
	{
		if (arguments.length === 1)
		{
			return $(strScope_a);
		}

		return $(strClass_a, strScope_a);
	}
};

var m_objInput = null;
var m_objOutput = null;
var m_objList = null;
var m_objProcList = null;
var m_arrProcs = [];			// from the last compile: { file, line, name, kind }
var m_strAsm = '';
var m_intTimer = 0;
var m_intNextId = 1;

// the project: files in order, the selected one, its name
var m_objProject = { name: 'project', files: [] };
var m_strSelId = '';

var m_arrListFields = [
	{ code: 'ID', caption: 'ID', type: 'STRING', visible: false, sortable: false },
	{ code: 'TYPE', caption: 'Type', type: 'STRING', visible: false, sortable: false },
	{ code: 'NAME', caption: 'File', type: 'STRING', visible: true, sortable: false },
	{ code: 'LINES', caption: 'Lines', type: 'NUMBER', visible: true, sortable: false }
];

var m_arrListOperations = [
	{ code: 'NEWMOD', caption: '+ Module', requiresselection: false },
	{ code: 'NEWCLS', caption: '+ Class', requiresselection: false },
	{ code: 'RENAME', caption: 'Rename', requiresselection: false },
	{ code: 'REMOVE', caption: '✕ Remove', requiresselection: false }
];

// ------------------------------------------------------------
// project
// ------------------------------------------------------------

function ntcNewFile(strName_a, strText_a)
{
	var objFile = { id: 'f' + m_intNextId, name: strName_a, text: strText_a || '' };

	m_intNextId++;
	m_objProject.files.push(objFile);

	return objFile;
}

function ntcFile(strId_a)
{
	var intI = 0;

	for (intI = 0; intI < m_objProject.files.length; intI++)
	{
		if (m_objProject.files[intI].id === strId_a)
		{
			return m_objProject.files[intI];
		}
	}

	return null;
}

function ntcFileByName(strName_a)
{
	var intI = 0;

	for (intI = 0; intI < m_objProject.files.length; intI++)
	{
		if (m_objProject.files[intI].name.toLowerCase() === strName_a.toLowerCase())
		{
			return m_objProject.files[intI];
		}
	}

	return null;
}

function ntcFileType(strName_a)
{
	return /\.cls$/i.test(strName_a) ? 'Class' : 'Module';
}

// a free name like Module1.bas / Class2.cls
function ntcFreeName(strBase_a, strExt_a)
{
	var intN = 1;

	while (ntcFileByName(strBase_a + intN + strExt_a) !== null)
	{
		intN++;
	}

	return strBase_a + intN + strExt_a;
}

function ntcSaveLocal()
{
	try
	{
		window.localStorage.setItem('tinyz80b_project', JSON.stringify({ name: m_objProject.name, files: m_objProject.files, sel: m_strSelId, mode: $('#ge-mode').val() }));
	}
	catch (objError)
	{
		// storage not available, nothing to do
	}
}

function ntcSetProject(strName_a, arrFiles_a)
{
	var intI = 0;

	m_objProject = { name: strName_a || 'project', files: [] };
	for (intI = 0; intI < arrFiles_a.length; intI++)
	{
		ntcNewFile(arrFiles_a[intI].name, arrFiles_a[intI].text);
	}
	if (m_objProject.files.length === 0)
	{
		ntcNewFile('Main.bas', '');
	}
	$('#ge-projectname').text(m_objProject.name);
	ntcSelect(m_objProject.files[0].id);
	ntcRefreshList();
	ntcSaveLocal();
	ntcRecompile();
}

// show a file in the editor
function ntcSelect(strId_a)
{
	var objFile = ntcFile(strId_a);

	if (objFile === null)
	{
		return;
	}
	m_strSelId = strId_a;
	m_objInput.setValue(objFile.text);
	$('#ge-filename').text('- ' + objFile.name);
	ntcMarkSelected();
	ntcRefreshProcs();
	ntcSaveLocal();
}

// listRenderer keeps its own selection; show ours
function ntcMarkSelected()
{
	setTimeout(function()
	{
		$('#ge-filelist .gscr-list-row-selected').removeClass('gscr-list-row-selected');
		$('#ge-filelist tr[data-id="' + m_strSelId + '"]').addClass('gscr-list-row-selected');
	}, 20);
}

// ------------------------------------------------------------
// file list (listRenderer)
// ------------------------------------------------------------

function ntcListData(strSearch_a)
{
	var arrData = [];
	var intI = 0;
	var objFile = null;
	var strLower = (strSearch_a || '').toLowerCase();

	for (intI = 0; intI < m_objProject.files.length; intI++)
	{
		objFile = m_objProject.files[intI];
		if ((strLower.length === 0) || (objFile.name.toLowerCase().indexOf(strLower) > -1))
		{
			arrData.push([objFile.id, ntcFileType(objFile.name), objFile.name, objFile.text.split('\n').length]);
		}
	}

	return {
		control: { offset: 0, limit: 9999, more: false, total: arrData.length },
		operations: m_arrListOperations,
		fields: m_arrListFields,
		data: arrData
	};
}

function ntcListLoad(objRequest_a, cbResult_a)
{
	var intI = 0;
	var strSearch = '';

	for (intI = 0; intI < objRequest_a.parameters.length; intI++)
	{
		if (objRequest_a.parameters[intI].name === 'search')
		{
			strSearch = objRequest_a.parameters[intI].value || '';
		}
	}
	cbResult_a(ntcListData(strSearch));
	ntcMarkSelected();
}

function ntcRefreshList()
{
	if (m_objList !== null)
	{
		m_objList.refresh();
		ntcMarkSelected();
	}
}

function ntcOperation(strOperation_a)
{
	var objFile = ntcFile(m_strSelId);
	var intI = 0;
	var strName = '';

	switch (strOperation_a)
	{
		case 'NEWMOD':
			objFile = ntcNewFile(ntcFreeName('Module', '.bas'), "' new module\n");
			ntcSelect(objFile.id);
			break;

		case 'NEWCLS':
			strName = ntcFreeName('Class', '.cls');
			objFile = ntcNewFile(strName, "' new class - use it with Dim x As New " + strName.replace(/\.cls$/i, '') + "\nPrivate mValue As Integer\n\nPublic Property Get Value() As Integer\n  Value = mValue\nEnd Property\n\nPublic Property Let Value(ByVal v As Integer)\n  mValue = v\nEnd Property\n");
			ntcSelect(objFile.id);
			break;

		case 'RENAME':
			if (objFile === null)
			{
				return;
			}
			strName = window.prompt('New name (.bas = module, .cls = class)', objFile.name);
			if ((strName === null) || (strName.replace(/\s/g, '').length === 0))
			{
				return;
			}
			if (!/\.(bas|cls)$/i.test(strName))
			{
				strName += /\.cls$/i.test(objFile.name) ? '.cls' : '.bas';
			}
			if ((ntcFileByName(strName) !== null) && (ntcFileByName(strName) !== objFile))
			{
				window.alert('There is already a file called ' + strName);
				return;
			}
			objFile.name = strName;
			$('#ge-filename').text('- ' + objFile.name);
			break;

		case 'REMOVE':
			if ((objFile === null) || (m_objProject.files.length < 2))
			{
				window.alert('A project needs at least one file');
				return;
			}
			if (!window.confirm('Remove ' + objFile.name + ' from the project?'))
			{
				return;
			}
			for (intI = 0; intI < m_objProject.files.length; intI++)
			{
				if (m_objProject.files[intI].id === objFile.id)
				{
					m_objProject.files.splice(intI, 1);
					break;
				}
			}
			ntcSelect(m_objProject.files[Math.max(0, intI - 1)].id);
			break;

		default:
			return;
	}

	ntcRefreshList();
	ntcSaveLocal();
	ntcRecompile();
}

// the files a VB project (.vbp) lists: [{ kind, file }] (file = name without the folder)
function ntcVbpFiles(strText_a)
{
	var arrLines = strText_a.split('\n');
	var arrMatch = null;
	var arrResult = [];
	var intI = 0;

	for (intI = 0; intI < arrLines.length; intI++)
	{
		// Module=Name; path\file.bas  Class=Name; file.cls  Form=file.frm
		if ((arrMatch = arrLines[intI].match(/^\s*(Module|Class|Form)\s*=\s*(?:[^;]*;\s*)?(.+?)\s*$/i)))
		{
			arrResult.push({ kind: arrMatch[1].toLowerCase(), file: arrMatch[2].replace(/^.*[\\\/]/, '') });
		}
	}

	return arrResult;
}

// add files the user dropped or picked (.bas / .cls / a .json project /
// a .vbp with its files)
function ntcAddFiles(objFileList_a)
{
	var arrFiles = [];
	var blnVbp = false;
	var intI = 0;
	var intPending = 0;
	var objLast = null;
	var objTexts = {};			// with a .vbp: lower case file name -> { name, text }
	var objVbp = null;

	for (intI = 0; intI < objFileList_a.length; intI++)
	{
		arrFiles.push(objFileList_a[intI]);
		if (/\.vbp$/i.test(objFileList_a[intI].name))
		{
			blnVbp = true;
		}
	}
	intPending = arrFiles.length;

	// a .vbp: a new project with the files it lists, in its order
	function vbpProject()
	{
		var arrMissing = [];
		var arrForms = [];
		var arrProjectFiles = [];
		var intJ = 0;
		var objItem = null;

		for (intJ = 0; intJ < objVbp.list.length; intJ++)
		{
			objItem = objVbp.list[intJ];
			if (objItem.kind === 'form')
			{
				arrForms.push(objItem.file);
			}
			else if (objTexts[objItem.file.toLowerCase()] !== undefined)
			{
				arrProjectFiles.push(objTexts[objItem.file.toLowerCase()]);
			}
			else
			{
				arrMissing.push(objItem.file);
			}
		}
		ntcSetProject(objVbp.name, arrProjectFiles);
		if (arrMissing.length > 0)
		{
			window.alert(objVbp.name + '.vbp lists files that were not picked with it:\n' + arrMissing.join('\n') + '\n\nPick the .vbp and its files together.');
		}
		if (arrForms.length > 0)
		{
			window.alert('Forms are not supported yet, left out:\n' + arrForms.join('\n'));
		}
	}

	arrFiles.forEach(function(objFile_a)
	{
		var objReader = new FileReader();

		objReader.onload = function(objEvent_a)
		{
			var strText = String(objEvent_a.target.result).replace(/\r\n?/g, '\n');
			var objProject = null;
			var objExisting = null;

			if (/\.json$/i.test(objFile_a.name))
			{
				try
				{
					objProject = JSON.parse(strText);
				}
				catch (objError)
				{
					objProject = null;
				}
				if ((objProject !== null) && (objProject.files instanceof Array))
				{
					ntcSetProject(objProject.name || objFile_a.name.replace(/\.json$/i, ''), objProject.files);
					if (objProject.mode)
					{
						$('#ge-mode').val(objProject.mode);
					}
				}
				else
				{
					window.alert(objFile_a.name + ' is not a tinyz80b project');
				}
			}
			else if (/\.vbp$/i.test(objFile_a.name))
			{
				objVbp = { name: objFile_a.name.replace(/\.vbp$/i, ''), list: ntcVbpFiles(strText) };
			}
			else if (blnVbp)
			{
				objTexts[objFile_a.name.toLowerCase()] = { name: objFile_a.name, text: strText };
			}
			else
			{
				objExisting = ntcFileByName(objFile_a.name);
				if (objExisting !== null)
				{
					objExisting.text = strText;
					objLast = objExisting;
				}
				else
				{
					objLast = ntcNewFile(/\.(bas|cls)$/i.test(objFile_a.name) ? objFile_a.name : objFile_a.name.replace(/\.[^.]*$/, '') + '.bas', strText);
				}
			}

			intPending--;
			if (intPending === 0)
			{
				if (objVbp !== null)
				{
					vbpProject();
					return;
				}
				if (objLast !== null)
				{
					ntcSelect(objLast.id);
				}
				ntcRefreshList();
				ntcSaveLocal();
				ntcRecompile();
			}
		};
		objReader.readAsText(objFile_a);
	});
}

function ntcDownload(strName_a, strText_a)
{
	var objBlob = new Blob([strText_a], { type: 'text/plain' });
	var objLink = document.createElement('a');
	var strURL = URL.createObjectURL(objBlob);

	objLink.href = strURL;
	objLink.download = strName_a;
	document.body.appendChild(objLink);
	objLink.click();
	document.body.removeChild(objLink);
	URL.revokeObjectURL(strURL);
}

function ntcSaveProject()
{
	var arrFiles = [];
	var intI = 0;

	for (intI = 0; intI < m_objProject.files.length; intI++)
	{
		arrFiles.push({ name: m_objProject.files[intI].name, text: m_objProject.files[intI].text });
	}
	ntcDownload(m_objProject.name + '.json', JSON.stringify({ version: 1, name: m_objProject.name, mode: $('#ge-mode').val(), files: arrFiles }, null, '\t'));
}

// ------------------------------------------------------------
// procedure list of the selected file
// ------------------------------------------------------------

var m_arrProcFields = [
	{ code: 'ID', caption: 'ID', type: 'STRING', visible: false, sortable: false },
	{ code: 'KIND', caption: 'Kind', type: 'STRING', visible: true, sortable: false },
	{ code: 'NAME', caption: 'Name', type: 'STRING', visible: true, sortable: false },
	{ code: 'LINE', caption: 'Line', type: 'NUMBER', visible: true, sortable: false }
];

var NTC_KIND_NAMES = { 'sub': 'Sub', 'function': 'Function', 'propget': 'Prop Get', 'proplet': 'Prop Let', 'propset': 'Prop Set' };

function ntcProcData()
{
	var arrData = [];
	var intI = 0;
	var objFile = ntcFile(m_strSelId);

	for (intI = 0; (objFile !== null) && (intI < m_arrProcs.length); intI++)
	{
		if (m_arrProcs[intI].file === objFile.name)
		{
			arrData.push(['p' + m_arrProcs[intI].line, (NTC_KIND_NAMES[m_arrProcs[intI].kind] || m_arrProcs[intI].kind) + (m_arrProcs[intI].used ? '' : ' -'), m_arrProcs[intI].name, m_arrProcs[intI].line]);
		}
	}

	return {
		control: { offset: 0, limit: 9999, more: false, total: arrData.length },
		operations: [],
		fields: m_arrProcFields,
		data: arrData
	};
}

function ntcRefreshProcs()
{
	var objFile = ntcFile(m_strSelId);

	$('#ge-procfile').text((objFile !== null) ? ('- ' + objFile.name) : '');
	if (m_objProcList !== null)
	{
		m_objProcList.setData(ntcProcData());
	}
}

// ------------------------------------------------------------
// compile
// ------------------------------------------------------------

function ntcOptions()
{
	return {
		platform: $('#ge-platform').val(),
		org: $('#ge-org').val(),
		library: $('#ge-library').val(),
		sourcecomments: $('#ge-comments').is(':checked'),
		turbo: ($('#ge-mode').val() === 'turbo')
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
		objRow.text('ERROR: ' + (arrErrors_a[intI].file ? (arrErrors_a[intI].file + ' ') : '') + ((arrErrors_a[intI].line > 0) ? ('line ' + arrErrors_a[intI].line + ': ') : '') + arrErrors_a[intI].msg);
		objRow.attr('data-line', arrErrors_a[intI].line);
		objRow.attr('data-file', arrErrors_a[intI].file || '');
		objErrors.append(objRow);
	}
}

// select a line in the editor
function ntcGotoLine(intLine_a)
{
	var objText = $('#ge-input .ge-texteditor-code');
	var arrLines = objText.val().split('\n');
	var intI = 0;
	var intStart = 0;
	var intLineHeight = 0;
	var objNode = objText.get(0);

	if ((intLine_a < 1) || !objNode)
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
	var arrFiles = [];
	var intI = 0;
	var objResult = null;
	var strView = '';
	var intCut = 0;
	var objCode = $('#ge-output .ge-texteditor-code');
	var intScroll = objCode.scrollTop();

	for (intI = 0; intI < m_objProject.files.length; intI++)
	{
		arrFiles.push({ name: m_objProject.files[intI].name, text: m_objProject.files[intI].text });
	}
	objResult = ntcCompile(arrFiles, ntcOptions());
	strView = objResult.asm;
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
	m_arrProcs = objResult.procs || [];
	ntcRefreshProcs();
	$('#ge-stats').text(objResult.stats.threadbytes + ' thread bytes, ' + objResult.stats.keywords + ' keywords, ' +
		objResult.stats.variables + ' vars' + (objResult.stats.normal ? ', normal mode used' : ', turbo only'));
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
	}, 40);
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

// ------------------------------------------------------------
// start up
// ------------------------------------------------------------

function ntcInit()
{
	var intI = 0;
	var objSaved = null;
	var objSelect = $('#ge-example');
	var arrStart = [];

	objSelect.append($('<option></option>').val('').text('(pick one)'));
	for (intI = 0; intI < NTC_EXAMPLES.length; intI++)
	{
		objSelect.append($('<option></option>').val(intI).text(NTC_EXAMPLES[intI].name));
	}

	try
	{
		objSaved = JSON.parse(window.localStorage.getItem('tinyz80b_project') || 'null');
	}
	catch (objError)
	{
		objSaved = null;
	}

	m_objInput = new textEditor(api, 'ge-input',
	{
		mode: 'CODE',
		language: 'sql',
		rows: 20,
		placeholder: 'Type BASIC here...',
		initialvalue: '',
		showlinenumbers: true,
		allowload: false,
		allowsave: true,
		filename: 'module.bas',
		cbOnChange: function(strValue_a)
		{
			var objFile = ntcFile(m_strSelId);
			var intLines = 0;

			if (objFile !== null)
			{
				intLines = objFile.text.split('\n').length;
				objFile.text = strValue_a;
				if (strValue_a.split('\n').length !== intLines)
				{
					ntcRefreshList();
				}
			}
			ntcSaveLocal();
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

	m_objList = new listRenderer(api, 'ge-filelist',
	{
		type: 'LIST',
		flow: 'EXPAND',
		target: '',
		initialData: ntcListData(''),
		cbLoadData: ntcListLoad,
		allowdragdrop: true,
		cbOnDragDropItem: function(objFiles_a)
		{
			ntcAddFiles(objFiles_a);
		},
		cbOnClick: function(arrRow_a, strId_a)
		{
			ntcSelect(strId_a);
		},
		cbOnOperation: function(strOperation_a)
		{
			ntcOperation(strOperation_a);
		}
	});

	m_objProcList = new listRenderer(api, 'ge-proclist',
	{
		type: 'LIST',
		flow: 'EXPAND',
		target: '',
		allowsearch: false,
		initialData: ntcProcData(),
		cbLoadData: function(objRequest_a, cbResult_a)
		{
			cbResult_a(ntcProcData());
		},
		cbOnClick: function(arrRow_a)
		{
			ntcGotoLine(arrRow_a[3]);
		}
	});

	if ((objSaved !== null) && (objSaved.files instanceof Array) && (objSaved.files.length > 0))
	{
		if (objSaved.mode)
		{
			$('#ge-mode').val(objSaved.mode);
		}
		ntcSetProject(objSaved.name, objSaved.files);
		for (intI = 0; intI < objSaved.files.length; intI++)
		{
			if (objSaved.files[intI].id === objSaved.sel)
			{
				ntcSelect(m_objProject.files[intI].id);
			}
		}
	}
	else
	{
		arrStart = NTC_EXAMPLES[0].files;
		ntcSetProject('guide', arrStart);
	}

	objSelect.on('change', function()
	{
		var objExample = NTC_EXAMPLES[parseInt(objSelect.val(), 10)];

		if ((objExample !== undefined) && window.confirm('Open the example "' + objExample.name + '"? It replaces the project in the editor (save it first if you need it).'))
		{
			ntcSetProject(objExample.name.toLowerCase().replace(/[^\w]+/g, '_').replace(/^_|_$/g, ''), objExample.files);
		}
		objSelect.val('');
	});

	$('#ge-new').on('click', function()
	{
		if (window.confirm('Start a new project? The one in the editor is replaced (save it first if you need it).'))
		{
			ntcSetProject('project', [{ name: 'Main.bas', text: "Option Explicit\n\nPrint \"Hello\"\n" }]);
		}
	});
	$('#ge-open').on('click', function()
	{
		$('#ge-openfile').trigger('click');
	});
	$('#ge-openfile').on('change', function()
	{
		if (this.files.length > 0)
		{
			ntcAddFiles(this.files);
			this.value = '';
		}
	});
	$('#ge-saveproject').on('click', ntcSaveProject);

	$('#ge-platform, #ge-library, #ge-comments, #ge-hidelib').on('change', ntcRecompile);
	$('#ge-mode').on('change', function()
	{
		ntcSaveLocal();
		ntcRecompile();
	});
	$('#ge-org').on('input change', ntcRecompile);
	$('#ge-save').on('click', function()
	{
		ntcDownload(m_objProject.name + '.asm', m_strAsm);
	});
	$('#ge-copy').on('click', ntcCopy);
	$('#ge-errors').on('click', 'div', function()
	{
		var objFile = ntcFileByName($(this).attr('data-file') || '');
		var intLine = parseInt($(this).attr('data-line'), 10);

		if ((objFile !== null) && (objFile.id !== m_strSelId))
		{
			ntcSelect(objFile.id);
		}
		ntcGotoLine(intLine);
	});

	// the browser must not open files dropped outside the list
	$(document).on('dragover drop', function(objEvent_a)
	{
		objEvent_a.preventDefault();
	});

	// tab key inserts a tab in the editor
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
