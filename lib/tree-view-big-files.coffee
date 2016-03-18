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
    span = document.createElement('span');
    span.className = 'tree-view-big-files-size'
    span.textContent  = suffix
    el.appendChild span
  else
    spans[0].textContent = suffix

modifiyFilenameSuffix = (el, suffix) ->
  spans = el.getElementsByClassName 'tree-view-big-files-size'
  if spans.length then spans[0].textContent = suffix

isFileOpened = (path) ->
  atom.project.getBuffers().map((i) -> i.file.path).indexOf(path) != -1

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

      @treeView.entryClicked = (e) =>
        if isFileOpened @treeView.selectedPath then return @openSelectedEntryOriginal.call @treeView
        if getEntrySizeDataAttr(e.currentTarget) >= @filesizeThreshold then return false
        @entryClickedOriginal.call @treeView, e

      @treeView.openSelectedEntry = (options={}, expandDirectory=false) =>
        entry = @treeView.selectedEntry()
        if getEntrySizeDataAttr(entry) or isFileOpened(@treeView.selectedPath)
          @openSelectedEntryOriginal.call @treeView, options, expandDirectory
        else
          setEntrySizeDataAttr entry, 0
          fsStat @treeView.selectedPath, (err, stat) =>
            setEntrySizeDataAttr entry, stat.size
            if stat.size < @filesizeThreshold
              @openSelectedEntryOriginal.call @treeView, options, expandDirectory
            else
              addSuffixToFilename entry, getHumanSizeFromBytes(stat.size)

      @treeView.on 'dblclick', '.file.entry', (e) =>
        @openSelectedEntryOriginal.call @treeView
        false

  deactivate: ->
    @treeView.openSelectedEntry = @openSelectedEntryOriginal
    @treeView.entryClicked = @entryClickedOriginal
    @treeView.off 'dblclick', '.file.entry'
    @subscriptions.dispose()
