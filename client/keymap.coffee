do ->
  CodeMirror.keyMap.dyalog =
    fallthrough: 'default'
    "'`'": (cm) -> cm.setOption 'keyMap', 'dyalogBackquote'
    F1: (cm) ->
      c = cm.getCursor(); s = cm.getLine(c.line).toLowerCase()
      u =
        if m = /^ *(\)[a-z]+).*$/.exec s
          Dyalog.helpURLs[m[1]] || 'lang/syscmds/intro'
        else if m = /^ *(\][a-z]+).*$/.exec s
          Dyalog.helpURLs[m[1]] || 'userguide/the-apl-environment/user-commands'
        else
          x = s[s[...c.ch].replace(/.[áa-z]*$/i, '').length..]
            .replace(/^([⎕:][áa-z]*|.).*$/i, '$1')
            .replace /^:end/, ':'
          Dyalog.helpURLs[x] ||
            if x[0] == '⎕' then 'lang/sysfns/sysfns-categorised'
            else if x[0] == ':' then 'lang/control-structures/control-structures-intro'
            else 'lang/intro/lang-elements'
      w = screen.width; h = screen.height
      popup = open "help/#{u}.html", 'help',
        "width=#{w / 2},height=#{h / 2},left=#{w / 4},top=#{h / 4}," +
        "scrollbars=1,location=1,toolbar=0,menubar=0,resizable=1"
      popup.focus?()
      return

  window.onhelp = -> false # prevent IE from being silly

  Dyalog.reverseKeyMap = {}
  CodeMirror.keyMap.dyalogBackquote =
    auto: 'dyalog', nofallthrough: true, disableInput: true

  ks = ''' `1234567890-=  ~!@#$%^&*()_+
           qwertyuiop[]   QWERTYUIOP{}
           asdfghjkl;\'\\ ASDFGHJKL:"|
           zxcvbnm,./     ZXCVBNM<>?    '''.split /\ */g

  vs = ''' `¨¯<≤=≥>≠∨∧×÷  ⋄⌶⍫⍒⍋⌽⍉⊖⍟⍱⍲!⌹
           ?⍵∊⍴~↑↓⍳○*←→   ?⍵⍷⍴⍨↑↓⍸⍥⍣⍞⍬
           ⍺⌈⌊_∇∆∘\'⎕⍎⍕⊢  ⍺⌈⌊_∇∆⍤⌸⌷≡≢⊣
           ⊂⊃∩∪⊥⊤|⍝⍀⌿     ⊂⊃∩∪⊥⊤|⍪⍙⍠    '''.split /\ */g

  for i in [0...ks.length] by 1
    Dyalog.reverseKeyMap[vs[i]] = ks[i]
    CodeMirror.keyMap.dyalogBackquote["'#{ks[i]}'"] = do (v = vs[i]) ->
      (cm) -> cm.replaceSelection v, 'end'
  return
