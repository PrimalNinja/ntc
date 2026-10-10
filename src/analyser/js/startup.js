// ── API/OS ───────────────────────────────────────────────────────────────────

var api = {
    element: function(strScope_a, strClass_a) {
        if (arguments.length === 1) { return $(strScope_a); }
        return $(strClass_a, strScope_a);
    }
};

var os = api;

os.element(document).ready(function()
{
    // ── Prevent browser from opening dropped files anywhere on the page ──────
    os.element(document).on('dragover drop', function(objEvent)
    {
        objEvent.preventDefault();
        objEvent.stopPropagation();
    });

    // ── Clear All button ─────────────────────────────────────────────────────
    os.element('#ge-main', '.ge-btn-clear').bind('click', clearFiles);

    // ── Save / Load bundle buttons ───────────────────────────────────────────
    os.element('#ge-button-bar', '.ge-btn-save').bind('click', saveBundle);

    os.element('#ge-button-bar', '.ge-btn-load').bind('click', function()
    {
        os.element('#ge-button-bar', '.ge-bundle-input').trigger('click');
    });

    os.element('#ge-button-bar', '.ge-bundle-input').bind('change', function()
    {
        if (this.files.length > 0)
        {
            loadBundle(this.files[0]);
            this.value = '';
        }
    });

    // ── Tab buttons ──────────────────────────────────────────────────────────
    os.element('#ge-main', '.ge-tab-summary').bind('click', function()
    {
        switchTab('summary');
    });

    os.element('#ge-main', '.ge-tab-deep').bind('click', function()
    {
        switchTab('deep');
    });

    os.element('#ge-main', '.ge-tab-raw').bind('click', function()
    {
        switchTab('raw');
    });

    os.element('#ge-main', '.ge-tab-render').bind('click', function()
    {
        switchTab('render');
    });

    // ── Analysis body drop zone (active only when empty state is shown) ──────
    var objAnalysisBody = os.element('#ge-main', '.ge-analysis-body');

    objAnalysisBody.on('dragover dragenter', function(objEvent)
    {
        objEvent.preventDefault();
        objEvent.stopPropagation();
        os.element('#ge-main', '.ge-analysis-dropzone').addClass('gs-drag-over');
    });

    objAnalysisBody.on('dragleave', function(objEvent)
    {
        if (!objAnalysisBody[0].contains(objEvent.relatedTarget))
        {
            os.element('#ge-main', '.ge-analysis-dropzone').removeClass('gs-drag-over');
        }
    });

    objAnalysisBody.on('drop', function(objEvent)
    {
        objEvent.preventDefault();
        objEvent.stopPropagation();
        os.element('#ge-main', '.ge-analysis-dropzone').removeClass('gs-drag-over');
        if (os.element('#ge-main', '.ge-analysis-dropzone:visible').length > 0)
        {
            handleFiles(objEvent.originalEvent.dataTransfer.files);
        }
    });

    showEmpty();
    renderFileList();
});
