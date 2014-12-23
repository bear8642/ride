log = do ->
  N = 50; T = 1000 # log no more than N log messages per T milliseconds
  n = t = 0
  (s) ->
    if (t1 = +new Date) - t > T then t = t1; n = 1
    if ++n < N then console.info process.uptime().toFixed(3) + ' ' + s
    else if n == N then console.info '... logging temporarily suppressed'

rm = (a, x) -> i = a.indexOf x; (if i != -1 then a.splice i, 1); return
b64 = (s) -> Buffer(s).toString 'base64'
b64d = (s) -> '' + Buffer s, 'base64'
getTag = (tagName, xml) -> (///^[^]*<#{tagName}>([^<]*)</#{tagName}>[^]*$///.exec xml)?[1]

WHIES = 'Invalid Descalc QuadInput LineEditor QuoteQuadInput Prompt'.split ' ' # constants used for ReplyAtInputPrompt

@Proxy = ->
  client = null # TCP connection to interpreter
  sockets = [] # list of socket.io connections to browsers

  toInterpreter = (s) ->
    if client
      log 'to interpreter: ' + JSON.stringify(s)[..1000]
      console.assert /[\x01-\x7f]*/.test s
      b = Buffer s.length + 8
      b.writeInt32BE b.length, 0
      b.write 'RIDE' + s, 4
      client.write b
    return

  cmd = (name, args) ->
    toInterpreter """<?xml version="1.0" encoding="utf-8"?><Command><cmd>#{name}</cmd><id>0</id><args><#{name}>#{args}</#{name}></args></Command>"""
    return

  toBrowser = (m...) ->
    log 'to browser: ' + JSON.stringify(m)[..1000]
    for socket in sockets then socket.emit m...
    return

  connectToInterpreter = (host, port) ->
    log "connecting to interpreter, host: #{host}, port: #{port}"
    client = require('net').connect {host, port}, -> log 'interpreter connected'
    queue = Buffer 0 # a buffer for data received from the server
    client.on 'end', -> log 'interpreter disconnected'; toBrowser 'end'; client = null; return
    client.on 'data', (data) ->
      queue = Buffer.concat [queue, data]
      while queue.length >= 4 and (n = queue.readInt32BE 0) <= queue.length
        m = '' + queue[8...n]; queue = queue[n..]
        log 'from interpreter: ' + JSON.stringify(m)[..1000]
        if !/^(?:SupportedProtocols|UsingProtocol)=1$/.test m # ignore these
          switch (/^<(\w+)>/.exec m)?[1] or ''
            when 'ReplyConnect', 'ReplyEdit', 'ReplySetLineAttributes' then ; # ignore
            when 'ReplySaveChanges'       then toBrowser 'ReplySaveChanges', win: +getTag('win', m), err: +getTag 'err', m
            when 'ReplyWindowTypeChanged' then toBrowser 'WindowTypeChanged', win: +getTag('Win', m), tracer: !!+getTag 'bugger', m
            when 'ReplyIdentify'      then toBrowser 'UpdateDisplayName', displayName: b64d getTag 'Project', m
            when 'ReplyUpdateWsid'
              s = b64d getTag 'wsid', m
              if s != (s1 = s.replace /\x00/g, '')
                log 'intepreter sent a wsid containing NUL characters, those will be ignored'
                s = s1
              toBrowser 'UpdateDisplayName', displayName: s
            when 'ReplyExecute'       then toBrowser 'AppendSessionOutput', result: b64d getTag 'result', m
            when 'ReplyEchoInput'     then toBrowser 'EchoInput', input: b64d(getTag 'input', m) + '\n'
            when 'ReplyGetLog'        then toBrowser 'AppendSessionOutput', result: b64d getTag 'Log', m
            when 'ReplyNotAtInputPrompt' then toBrowser 'NotAtInputPrompt'
            when 'ReplyAtInputPrompt' then toBrowser 'AtInputPrompt', why: WHIES.indexOf getTag 'why', m
            when 'ReplyOpenWindow'
              bs = []; m.replace /<row>(\d+)<\/row><value>1<\/value>/g, (_, l) -> bs.push +l
              toBrowser 'open', b64d(getTag 'name', m), b64d(getTag 'text', m), +getTag('token', m), +getTag('bugger', m), bs
            when 'ReplyUpdateWindow'
              bs = []; m.replace /<row>(\d+)<\/row><value>1<\/value>/g, (_, l) -> bs.push +l
              toBrowser 'update', b64d(getTag 'name', m), b64d(getTag 'text', m), +getTag('token', m), +getTag('bugger', m), bs
            when 'ReplyFocusWindow'   then toBrowser 'FocusWindow', win: +getTag 'win', m
            when 'ReplyCloseWindow'   then toBrowser 'CloseWindow', win: +getTag 'win', m
            when 'ReplyGetAutoComplete'
              o = b64d getTag 'options', m
              toBrowser 'autocomplete', +getTag('token', m), +getTag('skip', m), (if o then o.split '\n' else [])
            when 'ReplyHighlightLine' then toBrowser 'highlight', +getTag('win', m), +getTag 'line', m
            else log 'unrecognised'; toBrowser 'unrecognised', m
      return

    # Initial batch of commands sent to interpreter:
    toInterpreter 'SupportedProtocols=1'
    toInterpreter 'UsingProtocol=1'
    cmd 'Identify', '<Sender><Process>RIDE.EXE</Process><Proxy>0</Proxy></Sender>'
    cmd 'Connect', '<Token />'
    cmd 'GetWindowLayout', ''
    return

  (socket) -> # this function is the result from calling Proxy()
    log 'browser connected'
    sockets.push socket

    {onevent} = socket
    socket.onevent = (packet) ->
      log 'from browser: ' + JSON.stringify(packet.data)[..1000]
      onevent.apply socket, [packet]

    socket.on 'Execute', ({text, trace}) -> cmd 'Execute', "<Text>#{b64 text}</Text><Trace>#{+!!trace}</Trace>"
    socket.on 'Edit', ({win, pos, text}) -> cmd 'Edit', "<Text>#{b64 text}</Text><Pos>#{pos}</Pos><Win>#{win}</Win>"
    socket.on 'SaveChanges', ({win, text, attributes: {stop, monitor, trace}}) -> cmd 'SaveChanges', """
      <win>#{win}</win>
      <Text>#{b64 text}</Text>
      <attributes>
        <LineAttribute>
          <attribute>Stop</attribute>
          <values>
            #{
              (
                for i in [0...text.split('\n').length] by 1
                  "<LineAttributeValue><row>#{i}</row><value>#{+(i in (stop or []))}</value></LineAttributeValue>"
              ).join '\n'
            }
          </values>
        </LineAttribute>
      </attributes>
    """
    socket.on 'CloseWindow',    ({win}) -> cmd 'CloseWindow',         "<win>#{win}</win>"
    socket.on 'RunCurrentLine', ({win}) -> cmd 'DebugRunLine',        "<win>#{win}</win>"
    socket.on 'StepInto',       ({win}) -> cmd 'DebugStepInto',       "<win>#{win}</win>"
    socket.on 'TraceBackward',  ({win}) -> cmd 'DebugBackward',       "<win>#{win}</win>"
    socket.on 'TraceForward',   ({win}) -> cmd 'DebugForward',        "<win>#{win}</win>"
    socket.on 'ContinueTrace',  ({win}) -> cmd 'DebugContinueTrace',  "<win>#{win}</win>"
    socket.on 'Continue',       ({win}) -> cmd 'DebugContinue',       "<win>#{win}</win>"
    socket.on 'RestartThreads', ({win}) -> cmd 'DebugRestartThreads', "<win>#{win}</win>"
    socket.on 'Cutback',        ({win}) -> cmd 'DebugCutback',        "<win>#{win}</win>"
    socket.on 'WeakInterrupt', -> cmd 'WeakInterrupt'
    socket.on 'Autocomplete', ({line, pos, token}) -> cmd 'GetAutoComplete', "<line>#{b64 line}</line><pos>#{pos}</pos><token>#{token}</token>"

    socket.on 'connectToInterpreter', ({host, port}) -> connectToInterpreter host, port

    socket.on 'disconnect', -> log 'browser disconnected'; rm sockets, socket; return
    return
