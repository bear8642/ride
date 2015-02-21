about = require './about.coffee'
prefs = require './prefs.coffee'
Editor = require './editor.coffee'
Session = require './session.coffee'
keymap = require './keymap.coffee'

module.exports = (opts = {}) ->
  $('body').html """
    <div class="ide">
      <div class="lbar ui-layout-north" style="display:none">
        <a class="lbar-prefs" title="Preferences" href="#"></a>
        #{D.lbarHTML}
      </div>
      <div class="lbar-tip" style="display:none"><div class="lbar-tip-desc"></div><pre class="lbar-tip-text"></pre></div>
      <div class="lbar-tip-triangle" style="display:none"></div>
      <div class="ui-layout-center"></div>
      <div class="ui-layout-east" ><ul></ul></div>
      <div class="ui-layout-south"><ul></ul></div>
    </div>
  """

  isDead = 0
  pending = [] # pending lines to execute: AtInputPrompt consumes one item from the queue, HadError empties it

  # "wins" maps window ids, as they appear in the RIDE protocol, to window information objects that have the following properties:
  #   widget: a session or an editor
  #   id: the key in "wins"
  D.wins = wins =
    0: id: 0, widget: session = Session $('.ui-layout-center'),
      edit: (s, i) -> D.socket.emit 'Edit', win: 0, pos: i, text: s
      autocomplete: (s, i) -> D.socket.emit 'Autocomplete', line: s, pos: i, token: 0
      exec: (lines, trace) ->
        if lines && lines.length
          if !trace then pending = lines[1..]
          D.socket.emit 'Execute', {trace, text: lines[0] + '\n'}
        return

  # Tab management
  tabOpts = activate: (_, ui) -> (widget = wins[+ui.newTab.attr('id').replace /\D+/, ''].widget).updateSize(); widget.focus(); return
  $tabs = $('.ui-layout-east, .ui-layout-south').tabs tabOpts
  refreshTabs = ->
    $tabs.each -> $t = $ @; if !$('li', $t).length then ['east', 'south'].forEach (d) -> (if $t.is '.ui-layout-' + d then layout.close d); return
         .tabs 'refresh'
    return
  $(document).on 'keydown', '*', 'ctrl+tab ctrl+shift+tab', (e) ->
    for id, {widget} of wins when widget.hasFocus() then id = +id; break # id: id of old focused window
    wo = [0].concat $('li[role=tab]').map(-> +$(@).attr('id').replace /\D+/, '').toArray() # wo: window order
    u = wo[(wo.indexOf(id) + if e.shiftKey then wo.length - 1 else 1) % wo.length] # u: id of new focused window
    $("#wintab#{u} a").click(); wins[u]?.widget?.focus()
    false

  ($uls = $tabs.find 'ul').each ->
    $(@).sortable
      cursor: 'move', containment: 'parent', tolerance: 'pointer', axis: 'x', revert: true
      receive: (_, ui) ->
        $(@).closest('.ui-tabs').append $ '#win' + ui.item.attr('id').replace /\D+/, ''
        $tabs.tabs('destroy').tabs tabOpts
        return
      stop: (_, ui) ->
        refreshTabs()
        $('[role=tab]', $tabs).attr 'style', '' # clean up tabs' z-indices after dragging, $().sortable screws them up
        return
    .data('ui-sortable').floating = true # workaround for a jQueryUI bug, see http://bugs.jqueryui.com/ticket/6702#comment:20
    return

  popWindow = (w) ->
    if !opener && !isDead
      fwis = try JSON.parse localStorage.floatingWindowInfos catch then {}
      {width, height, x, y} = fwis[w] || width: 500, height: 400
      spec = "width=#{width},height=#{height},resizable=1"; if x? then spec += ",left=#{x},top=#{y},screenX=#{x},screenY=#{y}"
      if pw = open "?win=#{w}", '_blank', spec
        if x? then pw.moveTo x, y
        $("#wintab#{w},#win#{w}").remove(); $tabs.tabs('destroy').tabs tabOpts; refreshTabs(); session.scrollCursorIntoView()
        # wins[w].widget will be replaced a bit later by code running in the popup
      else
        $.alert 'Popups are blocked.'
    return

  D.socket
    .on '*identify', (i) -> D.remoteIdentification = i; return
    .on '*disconnected', -> $('.ide').addClass 'disconnected'; (for _, {widget} of wins then widget.die()); isDead = 1; return
    .on 'UpdateDisplayName', ({displayName}) ->
      s = displayName; if opts.host then s += ' - ' + opts.host; if opts.port then s += ':' + opts.port
      $('title').text s; return
    .on 'EchoInput', ({input}) -> session.add input
    .on 'AppendSessionOutput', ({result}) -> session.add result
    .on 'NotAtInputPrompt', -> session.noPrompt()
    .on 'AtInputPrompt', ({why}) ->
      if pending.length then D.socket.emit 'Execute', trace: 0, text: pending.shift() + '\n' else session.prompt why
      return
    .on 'HadError', -> pending.splice 0, pending.length; return
    .on 'FocusWindow', ({win}) -> $("#wintab#{win} a").click(); wins[win].widget.focus(); return
    .on 'WindowTypeChanged', ({win, tracer}) -> wins[win].widget.setDebugger tracer
    .on 'autocomplete', (token, skip, options) -> wins[token].widget.autocomplete skip, options
    .on 'highlight', (win, line) -> wins[win].widget.highlight line
    .on 'UpdateWindow', (ee) -> # "ee" for EditableEntity
      $("#wintab#{ee.token} a").text ee.name; wins[ee.token].widget.open ee; session.scrollCursorIntoView(); return
    .on 'ReplySaveChanges', ({win, err}) -> wins[win]?.widget?.saved err
    .on 'CloseWindow', ({win}) ->
      $("#wintab#{win},#win#{win}").remove(); $tabs.tabs('destroy').tabs tabOpts; refreshTabs()
      wins[win].widget.closePopup?(); delete wins[win]; session.scrollCursorIntoView(); session.focus(); return
    .on 'OpenWindow', (ee) -> # "ee" for EditableEntity
      layout.open dir = if ee.debugger then 'south' else 'east'
      w = ee.token
      $("<li id='wintab#{w}'><a href='#win#{w}'></a></li>").appendTo('.ui-layout-' + dir + ' ul').find('a').text ee.name
      $tabContent = $("<div class='win' id='win#{w}'></div>").appendTo('.ui-layout-' + dir)
      wins[w] = id: w, name: ee.name, widget: Editor $tabContent,
        debugger: ee.debugger
        save: (s, bs)   -> D.socket.emit 'SaveChanges',    win: w, text: s, attributes: stop: bs
        close:          -> D.socket.emit 'CloseWindow',    win: w
        over:           -> D.socket.emit 'RunCurrentLine', win: w
        into:           -> D.socket.emit 'StepInto',       win: w
        back:           -> D.socket.emit 'TraceBackward',  win: w
        skip:           -> D.socket.emit 'TraceForward',   win: w
        continueTrace:  -> D.socket.emit 'ContinueTrace',  win: w
        continueExec:   -> D.socket.emit 'Continue',       win: w
        restartThreads: -> D.socket.emit 'RestartThreads', win: w
        edit:    (s, p) -> D.socket.emit 'Edit',           win: w, text: s, pos: p
        interrupt:      -> D.socket.emit 'WeakInterrupt'
        cutback:        -> D.socket.emit 'Cutback',        win: w
        autocomplete: (s, i) -> D.socket.emit 'Autocomplete', line: s, pos: i, token: w
        pop: -> popWindow w
        openInExternalEditor: D.openInExternalEditor
      wins[w].widget.open ee
      $('.ui-layout-' + dir).tabs('refresh').tabs(active: -1)
        .data('ui-tabs').panels.off 'keydown' # prevent jQueryUI tabs from hijacking our keystrokes, <C-Up> in particular
      session.scrollCursorIntoView()
      if +localStorage.floatNewEditors then popWindow w
      return

  # language bar
  $('.lbar-prefs').click prefs
  $tip = $ '.lbar-tip'; $tipDesc = $ '.lbar-tip-desc'; $tipText = $ '.lbar-tip-text'; $tipTriangle = $ '.lbar-tip-triangle'
  ttid = null # tooltip timeout id
  $ '.lbar'
    .on 'mousedown', -> false
    .on 'mousedown', 'b', (e) -> (for _, {widget} of wins when widget.hasFocus() then widget.insert $(e.target).text()); false
    .on 'mouseout', 'b', -> clearTimeout ttid; ttid = null; $tip.add($tipTriangle).hide(); return
    .on 'mouseover', 'b', (e) ->
      clearTimeout ttid; $t = $ e.target; p = $t.position(); x = $t.text()
      ttid = setTimeout(
        ->
          ttid = null; key = keymap.reverse[x]
          keyText = if key && x.charCodeAt(0) > 127 then "Keyboard: #{keymap.getPrefixKey()}#{key}\n\n" else ''
          h = D.lbarTips[x] or [x, '']; $tipDesc.text h[0]; $tipText.text keyText + h[1]
          $tipTriangle.css(left: 3 + p.left + ($t.width() - $tipTriangle.width()) / 2, top: p.top + $t.height() + 2).show()
          x0 = p.left - 21; x1 = x0 + $tip.width(); y0 = p.top + $t.height()
          if x1 > $(document).width() then $tip.css(left: '', right: 0, top: y0).show()
          else $tip.css(left: Math.max(0, x0), right: '', top: y0).show()
          return
        200
      )
      return

  layout = $('.ide').layout
    defaults: enableCursorHotkey: 0
    north: spacing_closed: 0, spacing_open: 0, resizable: 0, togglerLength_open: 0
    east:  spacing_closed: 0, size: '0%', resizable: 1, togglerLength_open: 0
    south: spacing_closed: 0, size: '0%', resizable: 1, togglerLength_open: 0
    center: onresize: -> (for _, {widget} of wins then widget.updateSize()); session.scrollCursorIntoView(); return
    fxName: ''
  for d in ['east', 'south'] then layout.close d; layout.sizePane d, '50%'
  localStorage.showLanguageBar ?= 1; if !+localStorage.showLanguageBar then layout.hide 'north'
  session.updateSize()

  themes = ['Modern', 'Redmond', 'Cupertino', 'Freedom'] # default is set in init.coffee to prevent FOUC
  themeClasses = themes.map (x) -> 'theme-' + x.toLowerCase()
  allThemeClasses = themeClasses.join ' '

  # menu
  $('<div class="menu"></div>').prependTo('body').dyalogmenu [
    (
      if D.nwjs
        {'': '_File', items: [
          {'': '_Quit', key: 'Ctrl+Q', action: D.quit}
        ]}
    )
    {'': '_Edit', items: [
      {'': '_Keyboard Preferences', action: prefs}
    ]}
    {'': '_View', items:
      [
        {'': 'Show Language Bar', checked: +localStorage.showLanguageBar, action: (x) ->
          localStorage.showLanguageBar = +x; layout[['hide', 'show'][+x]] 'north'; return}
        {'': 'Float New Editors', checked: +localStorage.floatNewEditors || 0, action: (x) ->
          localStorage.floatNewEditors = +x; return}
        {'': 'Session Line Wrapping', checked: session.getLineWrapping(), action: (x) ->
          session.setLineWrapping x; return}
      ]
        .concat(
          if D.nwjs then [
            '-'
            {'': 'Zoom _In',    key: 'Ctrl+=', dontBindKey: 1, action: D.zoomIn}
            {'': 'Zoom _Out',   key: 'Ctrl+-', dontBindKey: 1, action: D.zoomOut}
            {'': '_Reset Zoom', key: 'Ctrl+0', dontBindKey: 1, action: D.resetZoom}
          ] else []
        )
        .concat [
          '-'
          {'': 'Theme', items: themes.map (x, i) ->
            '': x, group: 'themes', checked: $('body').hasClass(themeClasses[i]), action: ->
              localStorage.theme = x.toLowerCase(); $('body').removeClass(allThemeClasses).addClass themeClasses[i]; return
          }
        ]
    }
    {'': '_Help', items: [
      {'': '_About', key: 'Shift+F1', dontBindKey: 1, action: about}
    ]}
  ]
  return
