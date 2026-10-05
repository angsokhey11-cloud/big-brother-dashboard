/* BIG BROTHER — clean system dialogs for dashboard + same-origin workspaces. */
(function(){
'use strict';
if(window.BBSystemDialog)return;

const queue=[];
let active=false;

function ensure(){
 let root=document.getElementById('bbSystemDialogRoot');
 if(root)return root;
 root=document.createElement('div');
 root.id='bbSystemDialogRoot';
 root.hidden=true;
 root.innerHTML=
  '<div class="bb-dialog-backdrop" data-bb-dialog-backdrop></div>'+
  '<section class="bb-dialog-card" role="alertdialog" aria-modal="true" aria-labelledby="bbDialogTitle">'+
   '<div class="bb-dialog-icon" id="bbDialogIcon">!</div>'+
   '<div class="bb-dialog-title" id="bbDialogTitle">BIG BROTHER</div>'+
   '<div class="bb-dialog-message" id="bbDialogMessage"></div>'+
   '<div class="bb-dialog-actions" id="bbDialogActions"></div>'+
  '</section>';
 const style=document.createElement('style');
 style.id='bbSystemDialogStyle';
 style.textContent=
  '#bbSystemDialogRoot{position:fixed;inset:0;z-index:2147483647;display:flex;align-items:center;justify-content:center;padding:18px;font-family:Arial,"Noto Sans Khmer",sans-serif}'+
  '#bbSystemDialogRoot[hidden]{display:none!important}.bb-dialog-backdrop{position:absolute;inset:0;background:rgba(8,24,43,.58);backdrop-filter:blur(2px)}'+
  '.bb-dialog-card{position:relative;width:min(430px,100%);background:#fff;border:1px solid #d9e4ef;border-radius:17px;padding:24px 22px 20px;color:#17385e;text-align:center;box-shadow:0 25px 70px #0a274555}'+
  '.bb-dialog-icon{width:50px;height:50px;display:grid;place-items:center;margin:0 auto 13px;border-radius:50%;background:#eef5fd;color:#174979;font-size:25px;font-weight:900}'+
  '.bb-dialog-title{font-size:20px;font-weight:900;color:#17457a;margin-bottom:10px}.bb-dialog-message{white-space:pre-wrap;overflow-wrap:anywhere;font-size:14px;line-height:1.55;color:#465e75;max-height:45vh;overflow:auto}'+
  '.bb-dialog-actions{display:flex;gap:10px;justify-content:center;margin-top:20px}.bb-dialog-btn{min-width:110px;min-height:43px;border:0;border-radius:10px;padding:10px 16px;font:inherit;font-size:14px;font-weight:800;cursor:pointer}'+
  '.bb-dialog-btn-primary{background:#174979;color:#fff}.bb-dialog-btn-secondary{background:#edf2f7;color:#36536f}';
 document.head.appendChild(style);
 document.body.appendChild(root);
 return root;
}
function next(){
 if(active||!queue.length)return;
 active=true;
 const job=queue.shift(),root=ensure();
 root.hidden=false;
 const title=root.querySelector('#bbDialogTitle');
 const message=root.querySelector('#bbDialogMessage');
 const icon=root.querySelector('#bbDialogIcon');
 const actions=root.querySelector('#bbDialogActions');
 title.textContent=job.title||'BIG BROTHER';
 message.textContent=String(job.message??'');
 icon.textContent=job.kind==='confirm'?'?':job.kind==='success'?'✓':'!';
 icon.style.background=job.kind==='success'?'#e9f7ef':job.kind==='confirm'?'#fff4df':'#eef5fd';
 icon.style.color=job.kind==='success'?'#187044':job.kind==='confirm'?'#a7670a':'#174979';
 actions.replaceChildren();
 const close=value=>{
   root.hidden=true;active=false;
   document.removeEventListener('keydown',onKey,true);
   job.resolve(value);
   setTimeout(next,0);
 };
 const onKey=e=>{
   if(e.key==='Escape'){e.preventDefault();e.stopPropagation();close(job.kind==='confirm'?false:true)}
   if(e.key==='Enter'&&job.kind!=='confirm'){e.preventDefault();e.stopPropagation();close(true)}
 };
 document.addEventListener('keydown',onKey,true);
 if(job.kind==='confirm'){
   const no=document.createElement('button');no.type='button';no.className='bb-dialog-btn bb-dialog-btn-secondary';no.textContent=job.cancelText||'Cancel';no.onclick=()=>close(false);
   const yes=document.createElement('button');yes.type='button';yes.className='bb-dialog-btn bb-dialog-btn-primary';yes.textContent=job.okText||'Confirm';yes.onclick=()=>close(true);
   actions.append(no,yes);yes.focus({preventScroll:true});
 }else{
   const ok=document.createElement('button');ok.type='button';ok.className='bb-dialog-btn bb-dialog-btn-primary';ok.textContent=job.okText||'OK';ok.onclick=()=>close(true);
   actions.append(ok);ok.focus({preventScroll:true});
 }
}
function enqueue(kind,message,opts={}){
 return new Promise(resolve=>{queue.push({kind,message,resolve,...opts});next()});
}
const api={
 alert(message,opts={}){return enqueue(opts.kind||'alert',message,opts)},
 success(message,opts={}){return enqueue('success',message,opts)},
 confirm(message,opts={}){return enqueue('confirm',message,opts)},
 installWindow(target){
   if(!target||target.__bbSystemDialogInstalled)return;
   try{
     target.__bbSystemDialogInstalled=true;
     target.bbAlert=(message,opts)=>api.alert(message,opts);
     target.bbConfirm=(message,opts)=>api.confirm(message,opts);
     target.alert=(message)=>{void api.alert(message);};
   }catch(_){}
 }
};
window.BBSystemDialog=api;
api.installWindow(window);
})();