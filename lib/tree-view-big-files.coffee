fsStat = require('fs').stat
{CompositeDisposable} = require 'atom'

getHumanSizeFromBytes = (bytes) ->
	if bytes < 1048576 then return ' ' + (bytes/1024).toFixed(1) + ' KB'
	if bytes < 1073741824 then return ' ' + (bytes/1048576).toFixed(1) + ' MB'
	' ' + (bytes/1073741824).toFixed(1) + ' GB'

getEntrySizeDataAttr = (el) ->
	el.getAttribute 'data-size-bytes'

setEntrySizeDataAttr = (el, bytes) ->
	el.setAttribute 'data-size-bytes', bytes

addSuffixToFilename = (el, suffix) ->
	spans = el.getElementsByClassName 'tree-view-big-files-size'
	if not spans.length
		span = document.createElement 'span'
		span.className = 'tree-view-big-files-size'
		span.textContent	= suffix
		el.appendChild span
	else
		spans[0].textContent = suffix

modifiyFilenameSuffix = (el, suffix) ->
	spans = el.getElementsByClassName 'tree-view-big-files-size'
	if spans.length then spans[0].textContent = suffix

isDirectory = (entry) ->
	entry.getAttribute('is') == 'tree-view-directory'

isFileOpened = (path) ->
	for buf in atom.project.getBuffers()
		if buf.file?.path == path then return true
	false

doOriginalAction = (cb, cbArgs) ->
	cb and cb.apply TreeViewBigFiles.treeView, cbArgs
	return

doPluginAction = (entry, cb, cbArgs) ->
	setEntrySizeDataAttr entry, '-'
	addSuffixToFilename entry, ' •'
	fsStat entry.getPath(), (err, stat) ->
		setTimeout(( ()->
			setEntrySizeDataAttr entry, stat.size
			if stat.size < TreeViewBigFiles.filesizeThreshold
				doOriginalAction cb, cbArgs
				addSuffixToFilename entry, ''
			else
				addSuffixToFilename entry, getHumanSizeFromBytes(stat.size)
		),0)
	return

doOriginalOrPluginAction = (entry, cb, cbArgs, size) ->
	if isDirectory(entry)
		doOriginalAction cb, cbArgs
		return
	if isFileOpened(entry.getPath())
		doOriginalAction cb, cbArgs
		cb = null
	size = size or getEntrySizeDataAttr(entry)
	if size == '-' then return
	if size
		doOriginalAction cb, cbArgs
	else
		doPluginAction entry, cb, cbArgs
	return

clickHandlerFactory = (isDoubleClickNeeded) ->
	if isDoubleClickNeeded
		return (e) ->
			size = getEntrySizeDataAttr e.currentTarget
			if size >= TreeViewBigFiles.filesizeThreshold
				return false
			doOriginalOrPluginAction e.currentTarget,
				TreeViewBigFiles.entryClickedOriginal, [e],
				size
			false
	else
		return (e) ->
			doOriginalOrPluginAction e.currentTarget,
				TreeViewBigFiles.entryClickedOriginal, [e]
			false
	return

module.exports = TreeViewBigFiles =
	config:
		filesizeThreshold:
			title: 'File size threshold (bytes)'
			type: 'integer'
			default: 102400
			minimum: 0

	activate: ->
		atom.packages.activatePackage('tree-view').then (treeViewPkg) =>
			@treeView = treeViewPkg.mainModule.createView()
			@openSelectedEntryOriginal = @treeView.openSelectedEntry
			@entryClickedOriginal = @treeView.entryClicked
			@subscriptions = new CompositeDisposable
			@subscriptions.add atom.workspace.observeTextEditors (editor) =>
				@subscriptions.add editor.onDidSave =>
					entry = @treeView.entryForPath editor.getPath()
					if not entry then return
					setEntrySizeDataAttr entry, ''
					modifiyFilenameSuffix entry, ''
			atom.config.observe 'tree-view-big-files', (value) =>
				@filesizeThreshold = value.filesizeThreshold

			@treeView.entryClicked = clickHandlerFactory(true)

			@treeView.openSelectedEntry = (options={}, expandDirectory = false) =>
				doOriginalOrPluginAction @treeView.selectedEntry(),
					TreeViewBigFiles.openSelectedEntryOriginal,	[options, expandDirectory]
				false

			@treeView.on 'dblclick', '.file.entry', (e) ->
				if not isFileOpened(e.currentTarget.getPath())
					e.type = 'click'
					e.originalEvent = null
				doOriginalOrPluginAction e.currentTarget,
					TreeViewBigFiles.entryClickedOriginal, [e]
				false

	deactivate: ->
		@treeView.openSelectedEntry = @openSelectedEntryOriginal
		@treeView.entryClicked = @entryClickedOriginal
		@treeView.off 'dblclick', '.file.entry'
		@subscriptions.dispose()
