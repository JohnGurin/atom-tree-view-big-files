fsStat = require('fs').stat
{CompositeDisposable} = require 'atom'

getHumanSizeFromBytes = (bytes) ->
  if bytes < 1024 then return ' ' + bytes + ' Bytes'
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

module.exports = TreeViewBigFiles =
  config:
    filesizeThreshold:
      title: 'File size threshold (bytes)'
      type: 'integer'
      default: 204800
      minimum: 0

  activate: ->
    @subscriptions = new CompositeDisposable

    atom.packages.activatePackage('tree-view').then (treeViewPkg) =>
      @treeView = treeViewPkg.mainModule.createView()
      @treeView.originalEntryClicked = @treeView.entryClicked
      treeView = @treeView
      @subscriptions.add atom.workspace.observeTextEditors (editor) =>
        @subscriptions.add editor.onDidSave ->
          entry = treeView.entryForPath(editor.getPath())
          setEntrySizeDataAttr entry, ''
          modifiyFilenameSuffix entry, ''
      atom.config.observe 'tree-view-big-files', (value) ->
        treeView.filesizeThreshold = value.filesizeThreshold

      @treeView.entryClicked = (e) ->
        entry = e.currentTarget
        if entry.constructor.name == 'tree-view-file'
          size = getEntrySizeDataAttr entry
          if size
            if size < @filesizeThreshold then @originalEntryClicked(e)
          else
            setEntrySizeDataAttr entry, 0
            fsStat entry.getPath(), (err, stat) =>
              setEntrySizeDataAttr entry, stat.size
              if stat.size < @filesizeThreshold then @originalEntryClicked(e)
              else addSuffixToFilename entry, getHumanSizeFromBytes(stat.size)
          false
        else
          @originalEntryClicked(e)

      @treeView.on 'dblclick', '.entry', (e) =>
        @treeView.openSelectedEntry.call @treeView
        false

  deactivate: ->
    @treeView.entryClicked = @treeView.originalEntryClicked
    delete @treeView.originalEntryClicked
    delete @treeView.filesizeThreshold
    @treeView.off 'dblclick', '.entry'
    @subscriptions.dispose()

  entryDoubleClicked: (e) ->
    @originalEntryClicked(e)
