(** Server-side rendering utilities. *)

let reset () =
  Html.reset_hydration_keys ();
  State.reset ()

let to_string component =
  Solid_ml_server.Runtime.run (fun () ->
    reset ();
    let node = ref (Html.text "") in
    let dispose = Solid_ml_server.Owner.create_root (fun () ->
      node := component ()
    ) in
    let result = Html.to_string !node in
    dispose ();
    result
  )

let to_document component =
  Solid_ml_server.Runtime.run (fun () ->
    reset ();
    let node = ref (Html.text "") in
    let dispose = Solid_ml_server.Owner.create_root (fun () ->
      node := component ()
    ) in
    let result = Html.render_document !node in
    dispose ();
    result
  )

let to_string_stream ~emit component =
  emit (to_string component)

let to_document_stream ~emit component =
  emit (to_document component)

let get_state_script () =
  State.to_script ()

let get_event_replay_script () =
  "<script>(function(){if(window.__SOLID_ML_EVENT_REPLAY__)return;var queue=[];var types=['click','input','change','submit','keydown','keyup','pointerdown'];var esc=(window.CSS&&CSS.escape)?CSS.escape:function(s){return s.replace(/([^\\w-])/g,'\\\\$1');};var replay={queue:queue,types:types,handler:function(e){var target=e.target;if(!target)return;var selector=null;if(!target.id){var parts=[];var node=target;while(node&&node.nodeType===1&&node!==document.body){var name=node.tagName.toLowerCase();var parent=node.parentElement;if(!parent)break;var index=1;var siblings=parent.children;for(var i=0;i<siblings.length;i++){if(siblings[i]===node){index=i+1;break;}}parts.unshift(name+':nth-child('+index+')');node=parent;}selector=parts.length?parts.join('>'):null;}else{selector='#'+esc(target.id);}var item={type:e.type,target:target,selector:selector,value:null,checked:null,key:null,code:null,repeat:false,ctrlKey:false,shiftKey:false,altKey:false,metaKey:false,clientX:null,clientY:null,button:null,buttons:null,pointerId:null,pointerType:null,pressure:null,inputType:null};if(e.type==='input'||e.type==='change'){item.value=target.value;item.checked=target.checked;item.inputType=e.inputType||null;}if(e.type==='keydown'||e.type==='keyup'){item.key=e.key||null;item.code=e.code||null;item.repeat=!!e.repeat;item.ctrlKey=!!e.ctrlKey;item.shiftKey=!!e.shiftKey;item.altKey=!!e.altKey;item.metaKey=!!e.metaKey;}if(e.type==='click'||e.type==='pointerdown'){item.clientX=typeof e.clientX==='number'?e.clientX:null;item.clientY=typeof e.clientY==='number'?e.clientY:null;item.button=typeof e.button==='number'?e.button:null;item.buttons=typeof e.buttons==='number'?e.buttons:null;}if(e.type==='pointerdown'){item.pointerId=typeof e.pointerId==='number'?e.pointerId:null;item.pointerType=e.pointerType||null;item.pressure=typeof e.pressure==='number'?e.pressure:null;}queue.push(item);},listen:function(){types.forEach(function(t){document.addEventListener(t,replay.handler,true);});},stop:function(){types.forEach(function(t){document.removeEventListener(t,replay.handler,true);});},resolve:function(item){var target=item.target;if(target&&target.isConnected)return target;if(item.selector){var found=document.querySelector(item.selector);if(found)return found;}return target;},replay:function(){replay.stop();var items=queue.slice();queue.length=0;items.forEach(function(item){var target=replay.resolve(item);if(!target)return;if(item.value!==null){try{target.value=item.value;}catch(_e){}}if(item.checked!==null){try{target.checked=item.checked;}catch(_e){}}var evt;if(item.key!==null||item.code!==null){evt=new KeyboardEvent(item.type,{bubbles:true,cancelable:true,key:item.key||'',code:item.code||'',repeat:item.repeat,ctrlKey:item.ctrlKey,shiftKey:item.shiftKey,altKey:item.altKey,metaKey:item.metaKey});}else if(item.pointerId!==null&&typeof PointerEvent!=='undefined'){evt=new PointerEvent(item.type,{bubbles:true,cancelable:true,clientX:item.clientX||0,clientY:item.clientY||0,button:item.button||0,buttons:item.buttons||0,pointerId:item.pointerId,pointerType:item.pointerType||'mouse',pressure:item.pressure||0});}else if(item.clientX!==null){evt=new MouseEvent(item.type,{bubbles:true,cancelable:true,clientX:item.clientX||0,clientY:item.clientY||0,button:item.button||0,buttons:item.buttons||0});}else{evt=new Event(item.type,{bubbles:true,cancelable:true});}target.dispatchEvent(evt);});}};window.__SOLID_ML_EVENT_REPLAY__=replay;replay.listen();})();</script>"

let get_hydration_script () =
  get_state_script () ^ get_event_replay_script ()
