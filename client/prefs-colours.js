'use strict'
this.tabTitle='Colours'
var prefs=require('./prefs'),util=require('./util'),esc=util.esc
var G=[],H={} // G:syntax highlighting groups {t,s,c,ctrls}; H:reverse lookup dict for G
D.addSyntaxGroups=function(x){G=G.concat(x);H={};for(var i=0;i<G.length;i++)H[G[i].t]=i;SCMS&&updStyle()}
D.addSyntaxGroups([
  // t: token type, a short key for storing customisations in localStorage
  // s: string to display in the UI
  // c: css selector -- will be prefixed with "#col-cm" or ".ride-win" unless /*noprefix*/ is present
  // ctrls: what UI controls should be shown or hidden for this group (other than the default ones)
  {s:'assignment'      ,t:'asgn',c:'.cm-apl-asgn'},
  {s:'bracket'         ,t:'sqbr',c:'.cm-apl-sqbr'},
  {s:'comment'         ,t:'com' ,c:'.cm-apl-com' },
  {s:'cursor'          ,t:'cur' ,c:'div.CodeMirror-cursor',ctrls:{bc:1,fg:0,bg:0,BIU:0}},
  {s:'dfn level 1'     ,t:'dfn1',c:'.cm-apl-dfn1'},
  {s:'dfn level 2'     ,t:'dfn2',c:'.cm-apl-dfn2'},
  {s:'dfn level 3'     ,t:'dfn3',c:'.cm-apl-dfn3'},
  {s:'dfn level 4'     ,t:'dfn4',c:'.cm-apl-dfn4'},
  {s:'dfn level 5'     ,t:'dfn5',c:'.cm-apl-dfn5'},
  {s:'dfn'             ,t:'dfn' ,c:'.cm-apl-dfn' },
  {s:'diamond'         ,t:'diam',c:'.cm-apl-diam'},
  {s:'dyadic operator' ,t:'op2' ,c:'.cm-apl-op2' },
  {s:'error'           ,t:'err' ,c:'.cm-apl-err' },
  {s:'function'        ,t:'fn'  ,c:'.cm-apl-fn'  },
  {s:'global name'     ,t:'glb' ,c:'.cm-apl-glb' },
  {s:'idiom'           ,t:'idm' ,c:'.cm-apl-idm' },
  {s:'keyword'         ,t:'kw'  ,c:'.cm-apl-kw'  },
  {s:'label'           ,t:'lbl' ,c:'.cm-apl-lbl' },
  {s:'line number'     ,t:'lnum',c:'.CodeMirror-linenumber'},
  {s:'matching bracket',t:'mtch',c:'.CodeMirror-matchingbracket'},
  {s:'modified line'   ,t:'mod' ,c:'.modified'   },
  {s:'monadic operator',t:'op1' ,c:'.cm-apl-op1' },
  {s:'namespace'       ,t:'ns'  ,c:'.cm-apl-ns'  },
  {s:'name'            ,t:'var' ,c:'.cm-apl-var' },
  {s:'normal'          ,t:'norm',c:'.cm-s-default,.CodeMirror-gutters,/*noprefix*/#wse'},
  {s:'number'          ,t:'num' ,c:'.cm-apl-num' },
  {s:'parenthesis'     ,t:'par' ,c:'.cm-apl-par' },
  {s:'quad name'       ,t:'quad',c:'.cm-apl-quad'},
  {s:'search match'    ,t:'srch',c:'.cm-searching'},
  {s:'selection'       ,t:'sel' ,c:'.CodeMirror-selected,.CodeMirror-focused .CodeMirror-selected',ctrls:{fg:0,BIU:0}},
  {s:'semicolon'       ,t:'semi',c:'.cm-apl-semi'},
  {s:'string'          ,t:'str' ,c:'.cm-apl-str' },
  {s:'system command'  ,t:'scmd',c:'.cm-apl-scmd'},
  {s:'tracer'          ,t:'tc'  ,c:'.tracer .CodeMirror,.tracer .CodeMirror .CodeMirror-gutter-wrapper'},
  {s:'tradfn'          ,t:'trad',c:'.cm-apl-trad'},
  {s:'user command'    ,t:'ucmd',c:'.cm-apl-ucmd'},
  {s:'value tip target',t:'vtt' ,c:'/*noprefix*/#vtip-rect',ctrls:{bc:1,fg:0,BIU:0}},
  {s:'value tip'       ,t:'vtip',c:'/*noprefix*/#vtip-balloon,/*noprefix*/#vtip-triangle',ctrls:{bc:1}},
  {s:'zilde'           ,t:'zld' ,c:'.cm-apl-zld' }
])
// Colour schemes have two representations:
//   in memory                 in localStorage
//     {                         {
//       "name": "MyScheme",       "name": "MyScheme",
//       "group1": {               "styles": "group1=fg:f00,B group2=bg:f00 ..."
//         "fg": "f00",          }
//         "B": 1
//       },
//       "group2": {
//         "bg": "f00"
//       },
//       ...
//     }
// encodeScm() and decodeScm() convert between them
function encodeScm(x){
  var s=''
  for(var g in x)if(g!=='name'){
    var u='';for(var p in x[g]){var v=x[g][p];u+=','+p;if('BIU'.indexOf(p)<0||!v)u+=':'+v}
    u&&(s+=' '+g+'='+u.slice(1))
  }
  return{name:x.name,styles:s.slice(1)}
}
function decodeScm(x){              // x:for example "num=fg:345,bg:f,B,U,bgo:.5 str=fg:2,I com=U"
  var r={name:x.name}               // r:the result
  var a=(x.styles||'').split(/\s+/) // a:for example ["num=fg:345,bg:f,B,U,bgo:.5","str=fg:2,I","com=U"]
  for(var i=0;i<a.length;i++)if(a[i]){
    var b=a[i].split('='),g=b[0],c=b[1].split(','),h=r[g]={}  // b:["num","fg:345,bg:f,B,U,bgo:.5"]  g:"num" (the group)
    for(var j=0;j<c.length;j++){                              // c:["fg:345","bg:f","B","U","bgo:.5"]
      var pv=c[j].split(':'),p=pv[0],v=pv[1];h[p]=v!=null?v:1 // p:"fg" v:"345"  or  p:"B" v:undefined
    }
    h.bgo!=null&&(h.bgo=+h.bgo)     // if .bgo (background opacity) is present, convert it to a number
  }
  return r
}
var SCMS=[ // built-in schemes
  {name:'Default',styles:'asgn=fg:00f com=fg:088 dfn=fg:00f diam=fg:00f err=fg:f00 fn=fg:008 idm=fg:00f kw=fg:800 '+
    'lnum=fg:008,bg:f,bgo:1 mod=bg:e,bgo:1 mtch=bg:ff8,bgo:.5 norm=bg:f,bgo:1 ns=fg:8 num=fg:8 op1=fg:00f op2=fg:00f '+
    'par=fg:00f quad=fg:808 sel=bg:48e,bgo:.5 semi=fg:00f sqbr=fg:00f srch=bg:f80,bgo:.5 str=fg:088 tc=bg:d,bgo:1 '+
    'trad=fg:8 var=fg:8 zld=fg:008 scmd=fg:00f ucmd=fg:00f vtt=bg:ff0'},
  {name:'Francisco Goya',styles:'asgn=fg:ff0 com=fg:b,I:1 cur=bc:f00 dfn2=fg:eb4 dfn3=fg:c79 dfn4=fg:cd0 dfn5=fg:a0d '+
    'dfn=fg:a7b diam=fg:ff0 err=fg:f00,bg:822,bgo:.5,B:1,U:1 fn=fg:0f0 glob=B:1 idm=B:1 kw=fg:aa2 '+
    'lbl=U:1,bg:642,bgo:.5 lnum=fg:b94,bg:010,bgo:1 mod=bg:1,bgo:1 mtch=fg:0,bg:ff8,bgo:.75 norm=fg:9c7,bg:0,bgo:1 '+
    'num=fg:a8b op1=fg:d95 op2=fg:fd6 sel=bg:048,bgo:.5 semi=fg:8 sqbr=fg:8 srch=bg:b96,bgo:.75,fg:0 str=fg:dae '+
    'tc=bg:1,bgo:1 zld=fg:d9f,B:1 scmd=fg:0ff ucmd=fg:f80,B:1 vtip=bg:733,fg:ff0,bgo:1,bc:900 vtt=bc:f80'},
  {name:'Albrecht Dürer',styles:'com=I:1 diam=B:1 err=fg:f,bg:0,bgo:.5,B:1,I:1,U:1 glb=I:1 idm=U:1,bg:e,bgo:.5 kw=B:1 '+
    'lnum=bg:f,bgo:1 mod=bg:e,bgo:1 mtch=bg:c,bgo:.5 norm=bg:f,bgo:1 ns=fg:8 num=fg:8 quad=fg:8 srch=bg:c,bgo:.5 '+
    'str=fg:8 tc=bg:e,bgo:1 zld=fg:8 vtt=bc:aaa'},
  {name:'Kazimir Malevich',styles:''}
].map(decodeScm).map(function(x){x.frozen=1;return x})
var scms    // all schemes (built-in and user-defined) as objects
var scm     // the active scheme object
var $cm,cm  // DOM element and CodeMirror instance for displaying sample code
var sel     // the selected group's token type (.t)
function renderCSS(scm,isSample){
  var rp=isSample?'#col-cm':'.ride-win' // css rule prefix, ignored when there's a "/*noprefix*/"
  return G.map(function(g){var h=scm[g.t];return!h?'':
    g.c.split(',').map(function(x){return!/^\/\*noprefix\*\//.test(x)?rp+' '+x:isSample?'#nonexistent':x}).join(',')+'{'+
      (h.fg?'color:'+expandRGB(h.fg)+';'           :'')+
      (h.bg?'background-color:'+expandRGB(h.bg)+';':'')+
      (h.B ?'font-weight:bold;'                    :'')+
      (h.I ?'font-style:italic;'                   :'')+
      (h.U ?'text-decoration:underline;'           :'')+
      (h.bc?'border-color:'+expandRGB(h.bc)+';'    :'')+
      (h.bg?'background-color:'+expandRGBA(h.bg,h.bgo==null?.5:h.bgo):'')+'}'
  }).join('')
}
function expandRGB(s){var n=(s||'').length;return n===6?'#'+s:n===3?'#'+s.replace(/(.)/g,'$1$1'):n===1?'#'+s+s+s+s+s+s:s}
function expandRGBA(s,a){s=expandRGB(s);return'rgba('+[+('0x'+s.slice(1,3)),+('0x'+s.slice(3,5)),+('0x'+s.slice(5,7)),a]+')'}
function shrinkRGB(s){
  if(!/^#.{6}$/.test(s))return s
  var r=s[1],R=s[2],g=s[3],G=s[4],b=s[5],B=s[6];return r!==R||g!==G||b!==B?s.slice(1):r===g&&g===b?r:r+g+b
}
function updStyle(){ // update global style from what's in localStorage
  var name=prefs.colourScheme(),a=SCMS.concat(prefs.colourSchemes().map(decodeScm))
  for(var i=0;i<a.length;i++)if(a[i].name===name){$('#col-style').text(renderCSS(a[i]));break}
}
$(updStyle);prefs.colourScheme(updStyle);prefs.colourSchemes(updStyle)
function uniqScmName(s){ // s: suggested root
  var h={};for(var i=0;i<scms.length;i++)h[scms[i].name]=1
  var r=s;if(h[s]){s=s.replace(/ \(\d+\)$/,'');var i=1;while(h[r=s+' ('+i+')'])i++};return r
}
var SEARCH_MATCH='search match' // sample text to illustrate it
this.init=function($e){
  var u=[],fg;for(var g in scm)(fg=scm[g].fg)&&u.indexOf(fg)<0&&u.push(fg);u.sort() // u: unique colours
  $e.html(
    '<div id=col-top>'+
      '<label><u>S</u>cheme: <select id=col-scm></select></label>'+
      '<input id=col-new-name> '+
      '<button id=col-clone>C<u>l</u>one</button>  '+
      '<button id=col-rename><u>R</u>ename</button> '+
      '<button id=col-delete><u>D</u>elete</button> '+
    '</div>'+
    '<div id=col-cm></div>'+
    '<div id=col-settings>'+
      '<datalist id=col-list>'+u.map(function(c){return'<option value='+c+'>'}).join('')+'</datalist>'+
      '<select id=col-group>'+G.map(function(g,i){return'<option value='+i+'>'+g.s}).join('')+'</select>'+
      '<p id=col-fg-p><label><input type=checkbox id=col-fg-cb><u>F</u>oreground</label> <input type=color id=col-fg list=col-list>'+
      '<p id=col-bg-p><label><input type=checkbox id=col-bg-cb><u>B</u>ackground</label> <input type=color id=col-bg list=col-list>'+
      '<div id=col-bgo title=Transparency></div>'+
      '<p id=col-BIU-p>'+
        '<label><input type=checkbox id=col-B><b>B</b></label> '+
        '<label><input type=checkbox id=col-I><i>I</i></label> '+
        '<label><input type=checkbox id=col-U><u>U</u></label> '+
      '<p id=col-bc-p><label><input type=checkbox id=col-bc-cb>Border colour</label> <input type=color id=col-bc list=col-list>'+
    '</div>'
  )
  $('#col-scm').change(function(){
    scm=scms[+this.selectedIndex];updSampleStyle()
    $('#prefs-tab-colours').toggleClass('frozen',!!scm.frozen);cm.setSize($cm.width(),$cm.height())
  })
  $('#col-new-name').blur(function(){
    var newName=$(this).val();if(!newName)return
    scm.name='';scm.name=uniqScmName(newName)
    $('#prefs-tab-colours').removeClass('renaming');updScms()
  }).keydown(function(e){switch(e.which){ // todo
    /*enter*/case 13:$(this)              .blur();return!1
    /*esc  */case 27:$(this).val(scm.name).blur();return!1
  }})
  $('#col-clone').click(function(){
    var x={};scms.push(x);for(var k in scm)x[k]=$.extend({},scm[k]) // x:the new scheme
    x.name=uniqScmName(scm.name);delete x.frozen;scm=x;updScms()
  })
  $('#col-rename').click(function(){
    $('#col-new-name').width($('#col-scm').width()).val(scm.name).select()
    $('#prefs-tab-colours').addClass('renaming')
    setTimeout(function(){$('#col-new-name').focus()},0)
  })
  $('#col-delete').click(function(){
    var i=$('#col-scm')[0].selectedIndex;scms.splice(i,1)
    scm=scms[Math.min(i,scms.length-1)];updScms();return!1
  })
  $cm=$('#col-cm')
  cm=CodeMirror($cm[0],$.extend({},util.cmOpts,{
    lineNumbers:true,firstLineNumber:0,lineNumberFormatter:function(i){return'['+i+']'},
    indentUnit:4,scrollButtonHeight:12,matchBrackets:true,autoCloseBrackets:{pairs:'()[]{}',explode:'{}'}
  }))
  cm.addOverlay({token:function(stream){
    var i=stream.string.slice(stream.pos).indexOf(SEARCH_MATCH)
    if(!i){stream.pos+=SEARCH_MATCH.length;return'searching'}
    i>0?(stream.pos+=i):stream.skipToEnd()
  }})
  cm.on('gutterClick',function(){selGroup('lnum')})
  cm.on('cursorActivity',function(){
    var t;selGroup(
      cm.somethingSelected()?'sel':
      cm.getLine(cm.getCursor().line).indexOf(SEARCH_MATCH)>=0?'srch':
      (t=cm.getTokenTypeAt(cm.getCursor(),1))?
        (t=t.split(' ').sort(function(x,y){return y.length-x.length})[0].replace(/^apl-/,'')):
      'norm'
    )
  })
  $('#col-group').change(function(){selGroup(G[+this.value].t)})
  ;['fg','bg','bc'].forEach(function(p){
    $('#col-'+p).change(function(){(scm[sel]||(scm[sel]={}))[p]=this.value;updSampleStyle()})
    $('#col-'+p+'-cb').click(function(){
      $('#col-'+p).toggle(this.checked)
      var h=scm[sel]||(scm[sel]={});this.checked?h[p]=shrinkRGB($('#col-'+p).val()):delete h[p]
      updSampleStyle()
    })
  })
  $('#col-bg-cb').click(function(){$('#col-bgo').toggle(this.checked)})
  $('#col-bgo').slider({range:'min',value:.5,min:0,max:1,step:.25,animate:false,slide:function(e,ui){
    (scm[sel]||(scm[sel]={})).bgo=ui.value;updSampleStyle()
  }})
  ;['B','I','U'].forEach(function(p){
    $('#col-'+p).click(function(){var h=scm[sel]||(scm[sel]={});this.checked?h[p]=1:delete h[p];updSampleStyle()})
  })
  cm.setValue(
    '{R}←{X}tradfn(Y Z);local\n'+
    'dfn←{ ⍝ comment\n'+
    '  0 ¯1.2e¯3j¯.45 \'string\' ⍬\n'+
    '  +/-⍣(×A):⍺∇⍵[i;j]\n'+
    '  {{{{nested ⍺:∇⍵}⍺:∇⍵}⍺:∇⍵}⍺:∇⍵}\n'+
    '}\n'+
    'label:\n'+
    ':For i :In ⍳X ⋄ :EndFor\n'+
    ':If condition\n'+
    '  {⍵[⍋⍵]} ⋄ global←local←0\n'+
    '  ⎕error ) ] } :error \'unclosed\n'+
    ':EndIf\n'+
    SEARCH_MATCH+'\n'
  )
}
function updScms(){ // update schemes
  $('#col-scm').html(scms.map(function(x){x=esc(x.name);return'<option value="'+x+'">'+x}).join('')).val(scm.name)
  $('#prefs-tab-colours').toggleClass('frozen',!!scm.frozen);cm.setSize($cm.width(),$cm.height())
  updSampleStyle();selGroup('norm',1)
}
this.load=function(){
  var a=scms=SCMS.concat(prefs.colourSchemes().map(decodeScm)), s=prefs.colourScheme()
  scm=a[0];for(var i=0;i<a.length;i++)if(a[i].name===s){scm=a[i];break}
  updScms();$('#prefs-tab-colours').removeClass('renaming');cm.setSize($cm.width(),$cm.height())
}
this.save=function(){
  prefs.colourSchemes(scms.filter(function(x){return!x.frozen}).map(encodeScm));prefs.colourScheme(scm.name)
}
this.resize=function(){cm.setSize($cm.width(),$cm.height())}
function updSampleStyle(){$('#col-sample-style').text(renderCSS(scm,1))}
function selGroup(t,forceRefresh){
  if(!scm||sel===t&&!forceRefresh)return
  var i=H[t],h=scm[t]||{};$('#col-group').val(i)
  ;['fg','bg','bc'].forEach(function(p){
    $('#col-'+p+'-cb').prop('checked',!!h[p]);$('#col-'+p).val(expandRGB(h[p])||'#000000').toggle(!!h[p])
  })
  var ps='BIU';for(var j=0;j<ps.length;j++){var p=ps[j];$('#col-'+p).prop('checked',!!h[p])}
  $('#col-bgo').slider('value',h.bgo==null?.5:h.bgo)
  var c=(G[i]||G[0]).ctrls||{}
  $('#col-fg-p' ).toggle(c.fg==null||!!c.fg)
  $('#col-bg-p' ).toggle(c.bg==null||!!c.bg)
  $('#col-bgo'  ).toggle((c.bg==null||!!c.bg)&&!!h.bg)
  $('#col-BIU-p').toggle(c.BIU==null||!!c.BIU)
  $('#col-bc-p' ).toggle(!!c.bc)
  sel=t
}
