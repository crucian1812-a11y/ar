/* =========================================================================
   Бодо Бородо — Путешествие за буквами
   Аркадно-образовательная игра-бродилка.
   Персонаж перерисован по референсу: оранжевое «бородатое» тело-купол,
   голубая маска-лицо, большие глаза, брови, волнистый рот, ручки и ножки.
   Полностью офлайн, рендер на Canvas.
   ========================================================================= */

(() => {
'use strict';

const VW = 1000, VH = 600;
const canvas = document.getElementById('game');
const ctx = canvas.getContext('2d');

/* ---------- Палитра ---------- */
const C = {
  orange:'#F26A28', orangeDk:'#D14E18', stripe:'#E0561C',
  blue:'#A6DCEA', blueDk:'#7FC2D6', blueLt:'#C6ECF5',
  white:'#ffffff', ink:'#2b2b2b', tongue:'#E2574C',
  panel:'#fff7e6', panelEdge:'#e6c97a',
  good:'#4caf50', bad:'#e25141', star:'#ffd34e',
  btn:'#ffb13b', btnDk:'#e8901a', btnTxt:'#5a3410',
};

/* ---------- Звук ---------- */
let actx = null;
function audio(){ if(!actx){ try{ actx = new (window.AudioContext||window.webkitAudioContext)(); }catch(e){} } return actx; }
function beep(freq, dur, type='sine', vol=0.18){
  const a = audio(); if(!a) return;
  const o = a.createOscillator(), g = a.createGain();
  o.type=type; o.frequency.value=freq; g.gain.value=vol;
  o.connect(g); g.connect(a.destination);
  const t=a.currentTime; o.start(t);
  g.gain.setValueAtTime(vol,t);
  g.gain.exponentialRampToValueAtTime(0.0001,t+dur);
  o.stop(t+dur);
}
const SFX = {
  tap:  ()=>beep(520,0.07,'triangle',0.12),
  good: ()=>{ beep(660,0.12,'sine',0.2); setTimeout(()=>beep(880,0.16,'sine',0.2),90); },
  win:  ()=>{ [523,659,784,1046].forEach((f,i)=>setTimeout(()=>beep(f,0.18,'sine',0.2),i*120)); },
  bad:  ()=>beep(150,0.22,'sawtooth',0.14),
  star: ()=>beep(1100,0.14,'sine',0.18),
  jump: ()=>beep(440,0.1,'square',0.12),
};

/* ---------- Сохранение ---------- */
const SAVE_KEY='bodo_progress_v2';
function loadSave(){ try{ return JSON.parse(localStorage.getItem(SAVE_KEY))||{}; }catch(e){ return {}; } }
function writeSave(s){ try{ localStorage.setItem(SAVE_KEY, JSON.stringify(s)); }catch(e){} }
let progress = loadSave();
if(!progress.stars) progress.stars={};
if(progress.unlocked==null) progress.unlocked=1;

/* =========================================================================
   УРОВНИ — 6 остановок путешествия.
   Только 2 уровня про буквы; остальные — путешествие + аркада.
   ========================================================================= */
const LEVELS = [
  { id:'meadow', name:'Полянка Букв', tag:'🌼', type:'quest', sky:['#aee6ff','#e8fbff'],
    intro:'Привет! Я — Бодо Бородо! Перед дорогой разомнёмся: с какой буквы начинается слово?',
    tasks:[
      {kind:'pick', emoji:'🐱', cap:'КОТ',  answer:'К', wrong:['М','Т']},
      {kind:'pick', emoji:'🏠', cap:'ДОМ',  answer:'Д', wrong:['Б','О']},
      {kind:'pick', emoji:'🐟', cap:'РЫБА', answer:'Р', wrong:['Л','Ы']},
      {kind:'pick', emoji:'🌙', cap:'ЛУНА', answer:'Л', wrong:['Н','У']},
    ] },

  { id:'balloon', name:'Воздушный Шар', tag:'🎈', type:'fly', sky:['#bfe9ff','#eafaff'], goal:12,
    intro:'Полетели на воздушном шаре! Нажимай на экран, чтобы подниматься. Собирай ⭐, не влетай в тучи!' },

  { id:'train', name:'Поезд Слогов', tag:'🚂', type:'quest', sky:['#ffe6b0','#fff7e0'],
    intro:'Поезд везёт нас дальше! Собери слово из букв по порядку — нажимай буквы.',
    tasks:[
      {kind:'spell', word:'КОТ',  emoji:'🐱'},
      {kind:'spell', word:'ДОМ',  emoji:'🏠'},
      {kind:'spell', word:'ШАР',  emoji:'🎈'},
      {kind:'spell', word:'ЛУНА', emoji:'🌙'},
    ] },

  { id:'mountain', name:'Горная Тропа', tag:'⛰️', type:'run', sky:['#cdb4ff','#efe6ff'], goal:10,
    intro:'Горная тропа! Нажимай на экран, чтобы Бодо прыгал через камни. Собирай 🍎!' },

  { id:'sea', name:'Морская Ловля', tag:'🌊', type:'catch', sky:['#a8e6cf','#e3fff4'], goal:12,
    good:['🐟','🦀','🐙','⭐','💎'], bad:['💣','🥾'],
    intro:'Плывём по морю! Двигай Бодо пальцем влево-вправо и лови рыбку и сокровища. Берегись бомб!' },

  { id:'festival', name:'Праздник Друзей', tag:'🎉', type:'catch', sky:['#ffc1d6','#ffe9f1'], goal:15,
    good:['🎈','🍭','🧁','⭐','🎁','🌟'], bad:['💣'],
    intro:'Мы дошли до праздника друзей! Лови шарики и сладости, чтобы устроить весёлый салют!' },
];

/* =========================================================================
   ПОМОЩНИКИ РИСОВАНИЯ
   ========================================================================= */
function rr(x,y,w,h,r){
  ctx.beginPath();
  ctx.moveTo(x+r,y);
  ctx.arcTo(x+w,y,x+w,y+h,r);
  ctx.arcTo(x+w,y+h,x,y+h,r);
  ctx.arcTo(x,y+h,x,y,r);
  ctx.arcTo(x,y,x+w,y,r);
  ctx.closePath();
}
function text(str,x,y,size,color,align='center',weight='bold'){
  ctx.fillStyle=color;
  ctx.font=`${weight} ${size}px "Comic Sans MS","Segoe UI",sans-serif`;
  ctx.textAlign=align; ctx.textBaseline='middle';
  ctx.fillText(str,x,y);
}
function wrapText(str,x,y,maxW,size,color,lh){
  ctx.fillStyle=color;
  ctx.font=`bold ${size}px "Comic Sans MS","Segoe UI",sans-serif`;
  ctx.textAlign='center'; ctx.textBaseline='middle';
  const words=str.split(' '); let line=''; const lines=[];
  for(const w of words){
    const tt=line?line+' '+w:w;
    if(ctx.measureText(tt).width>maxW && line){ lines.push(line); line=w; } else line=tt;
  }
  if(line) lines.push(line);
  const startY=y-(lines.length-1)*lh/2;
  lines.forEach((l,i)=>ctx.fillText(l,x,startY+i*lh));
}
function shuffle(a){ a=a.slice(); for(let i=a.length-1;i>0;i--){const j=(Math.random()*(i+1))|0;[a[i],a[j]]=[a[j],a[i]];} return a; }

/* ---------- Кнопки (immediate-mode) ---------- */
let clickables=[];
function button(x,y,w,h,label,opts={}){
  const o=Object.assign({size:30,fill:C.btn,edge:C.btnDk,txt:C.btnTxt},opts);
  ctx.fillStyle='rgba(0,0,0,0.15)'; rr(x+3,y+5,w,h,16); ctx.fill();
  ctx.fillStyle=o.edge; rr(x,y+5,w,h,16); ctx.fill();
  ctx.fillStyle=o.fill; rr(x,y,w,h,16); ctx.fill();
  ctx.strokeStyle='rgba(255,255,255,0.5)'; ctx.lineWidth=2; rr(x+3,y+3,w-6,h*0.42,12); ctx.stroke();
  text(label,x+w/2,y+h/2,o.size,o.txt);
  if(opts.onClick) clickables.push({x,y,w,h,cb:opts.onClick});
}

/* =========================================================================
   ПЕРСОНАЖ БОДО БОРОДО  (по референсу)
   mood: 'idle' | 'happy' | 'cheer'
   ========================================================================= */
function drawBodo(cx, cy, scale, mood='idle', t=0){
  ctx.save();
  ctx.translate(cx,cy);
  ctx.translate(0, Math.sin(t/430)*3*scale);
  ctx.scale(scale,scale);

  // контур тела-купола («борода»)
  function dome(){
    ctx.beginPath();
    ctx.moveTo(-92,58);
    ctx.bezierCurveTo(-106,8,-86,-58,-30,-66);
    ctx.bezierCurveTo(-8,-70, 8,-70, 30,-66);
    ctx.bezierCurveTo(86,-58,106,8,92,58);
    ctx.quadraticCurveTo(72,70,54,58);
    ctx.quadraticCurveTo(36,70,18,58);
    ctx.quadraticCurveTo(0,70,-18,58);
    ctx.quadraticCurveTo(-36,70,-54,58);
    ctx.quadraticCurveTo(-74,70,-92,58);
    ctx.closePath();
  }

  // тень
  ctx.fillStyle='rgba(0,0,0,0.12)';
  ctx.beginPath(); ctx.ellipse(0,86,80,13,0,0,Math.PI*2); ctx.fill();

  // НОЖКИ
  ctx.fillStyle=C.blue;
  rr(-30,66,28,22,9); ctx.fill();
  rr(4,66,28,22,9); ctx.fill();
  ctx.fillStyle=C.blueDk; rr(-30,82,28,6,3); ctx.fill(); rr(4,82,28,6,3); ctx.fill();

  // РУЧКИ
  const armUp = mood==='cheer';
  ctx.fillStyle=C.blue;
  // левая
  ctx.beginPath(); ctx.ellipse(-88, armUp?-30:34, 16,14, 0.2, 0, Math.PI*2); ctx.fill();
  // правая
  const rw = mood==='cheer'? -40 : 34 + Math.sin(t/500)*4;
  ctx.beginPath(); ctx.ellipse(88, rw, 16,14, -0.2, 0, Math.PI*2); ctx.fill();

  // ТЕЛО (оранжевый купол)
  dome(); ctx.fillStyle=C.orange; ctx.fill();
  // полоски-«ворсинки» с обрезкой по телу
  ctx.save(); dome(); ctx.clip();
  ctx.strokeStyle=C.stripe; ctx.lineWidth=4; ctx.lineCap='round';
  for(let i=-5;i<=5;i++){
    const x=i*17;
    ctx.beginPath(); ctx.moveTo(x,-48);
    ctx.quadraticCurveTo(x+5,4,x,66); ctx.stroke();
  }
  ctx.restore();
  dome(); ctx.strokeStyle=C.orangeDk; ctx.lineWidth=3; ctx.stroke();

  // БРОВИ (толстые чёрные палочки)
  ctx.strokeStyle=C.ink; ctx.lineWidth=6; ctx.lineCap='round';
  const browUp = (mood==='happy'||mood==='cheer')? -6 : 0;
  ctx.beginPath();
  ctx.moveTo(-32,-60+browUp); ctx.quadraticCurveTo(-17,-69+browUp,-3,-63+browUp);
  ctx.moveTo(4,-63+browUp);   ctx.quadraticCurveTo(19,-71+browUp,33,-61+browUp);
  ctx.stroke();

  // ГОЛУБАЯ МАСКА-ЛИЦО
  ctx.save();
  ctx.translate(0,-34); ctx.rotate(-0.05);
  ctx.fillStyle=C.blue;
  ctx.beginPath(); ctx.ellipse(0,0,62,24,0,0,Math.PI*2); ctx.fill();
  ctx.fillStyle=C.blueLt;
  ctx.beginPath(); ctx.ellipse(-6,-7,40,9,0,0,Math.PI*2); ctx.fill();
  ctx.restore();

  // ГЛАЗА
  const blink = (t%2800)>2650;
  const lx = mood==='idle'? Math.sin(t/900)*2 : 0;
  for(const ex of [-16,12]){
    ctx.fillStyle=C.white;
    ctx.beginPath(); ctx.ellipse(ex,-38,14,blink?2:17,0,0,Math.PI*2); ctx.fill();
    if(!blink){
      ctx.fillStyle=C.ink;
      ctx.beginPath(); ctx.arc(ex+lx,-33,6.5,0,Math.PI*2); ctx.fill();
      ctx.fillStyle='#fff';
      ctx.beginPath(); ctx.arc(ex+lx-2,-35,2,0,Math.PI*2); ctx.fill();
    }
  }

  // РОТ
  ctx.lineCap='round';
  if(mood==='cheer'){
    ctx.fillStyle=C.ink;
    ctx.beginPath(); ctx.ellipse(0,4,28,22,0,0,Math.PI*2); ctx.fill();
    ctx.fillStyle=C.white; rr(-22,-15,44,8,4); ctx.fill();
    ctx.fillStyle=C.tongue; ctx.beginPath(); ctx.ellipse(0,16,14,9,0,0,Math.PI*2); ctx.fill();
    // слёзки радости
    ctx.fillStyle=C.blueLt;
    for(const tx of [-34,30]){ ctx.beginPath(); ctx.ellipse(tx,-26,5,8,0,0,Math.PI*2); ctx.fill(); }
  } else if(mood==='happy'){
    ctx.fillStyle=C.ink;
    ctx.beginPath(); ctx.moveTo(-22,-4);
    ctx.quadraticCurveTo(0,22,22,-4); ctx.closePath(); ctx.fill();
    ctx.fillStyle=C.tongue; ctx.beginPath(); ctx.ellipse(0,3,11,6,0,0,Math.PI); ctx.fill();
  } else {
    // волнистый ротик
    ctx.strokeStyle=C.ink; ctx.lineWidth=4.5;
    ctx.beginPath();
    let mx=-32; ctx.moveTo(mx,-6);
    ctx.quadraticCurveTo(mx+11,-15,mx+22,-7);
    ctx.quadraticCurveTo(mx+33,1,mx+44,-7);
    ctx.quadraticCurveTo(mx+54,-13,mx+64,-6);
    ctx.stroke();
  }

  ctx.restore();
}

/* =========================================================================
   ФОНЫ
   ========================================================================= */
function skyBg(c1,c2){
  const g=ctx.createLinearGradient(0,0,0,VH);
  g.addColorStop(0,c1); g.addColorStop(1,c2);
  ctx.fillStyle=g; ctx.fillRect(0,0,VW,VH);
}
function sun(x,y,r,t){
  ctx.save(); ctx.translate(x,y); ctx.rotate(t/4000);
  ctx.fillStyle='rgba(255,211,78,0.5)';
  for(let i=0;i<12;i++){ ctx.rotate(Math.PI/6); ctx.fillRect(r,-4,r*0.5,8); }
  ctx.restore();
  ctx.fillStyle=C.star; ctx.beginPath(); ctx.arc(x,y,r,0,Math.PI*2); ctx.fill();
}
function cloud(x,y,s,col='rgba(255,255,255,0.9)'){
  ctx.fillStyle=col;
  for(const [dx,dy,r] of [[0,0,26],[26,6,20],[-26,6,20],[0,10,30]]){
    ctx.beginPath(); ctx.arc(x+dx*s,y+dy*s,r*s,0,Math.PI*2); ctx.fill();
  }
}
function ground(c1,c2,y=480){
  ctx.fillStyle=c2;
  ctx.beginPath(); ctx.moveTo(0,y-10);
  ctx.quadraticCurveTo(250,y-40,500,y-10);
  ctx.quadraticCurveTo(750,y+20,1000,y-20);
  ctx.lineTo(1000,VH); ctx.lineTo(0,VH); ctx.closePath(); ctx.fill();
  ctx.fillStyle=c1;
  ctx.beginPath(); ctx.moveTo(0,y+20);
  ctx.quadraticCurveTo(300,y-5,600,y+25);
  ctx.quadraticCurveTo(800,y+45,1000,y+15);
  ctx.lineTo(1000,VH); ctx.lineTo(0,VH); ctx.closePath(); ctx.fill();
}
function star(x,y,r,fill){
  ctx.beginPath();
  for(let i=0;i<5;i++){
    const a=-Math.PI/2+i*2*Math.PI/5;
    ctx.lineTo(x+Math.cos(a)*r,y+Math.sin(a)*r);
    const a2=a+Math.PI/5;
    ctx.lineTo(x+Math.cos(a2)*r*0.45,y+Math.sin(a2)*r*0.45);
  }
  ctx.closePath(); ctx.fillStyle=fill; ctx.fill();
  ctx.lineWidth=3; ctx.strokeStyle='#e0a92e'; ctx.stroke();
}
let confetti=[];
function spawnConfetti(){
  confetti=[];
  for(let i=0;i<90;i++) confetti.push({x:Math.random()*VW,y:-Math.random()*VH,
    vx:(Math.random()-0.5)*60, vy:80+Math.random()*120,
    c:['#ff5a5a','#ffd34e','#5ad15a','#5a9dff','#d35aff'][i%5], r:Math.random()*6, s:5+Math.random()*6});
}
function drawConfetti(dt){
  for(const p of confetti){
    p.x+=p.vx*dt; p.y+=p.vy*dt; p.r+=dt*5;
    if(p.y>VH+10){ p.y=-10; p.x=Math.random()*VW; }
    ctx.save(); ctx.translate(p.x,p.y); ctx.rotate(p.r);
    ctx.fillStyle=p.c; ctx.fillRect(-p.s/2,-p.s/2,p.s,p.s); ctx.restore();
  }
}

/* =========================================================================
   ДВИЖОК СЦЕН + переход
   ========================================================================= */
let scene=null, sceneT=0, fade=1, fadeDir=-1, pendingScene=null;
function setScene(factory){ pendingScene=factory; fadeDir=1; }
function _swap(){ scene=pendingScene(); pendingScene=null; sceneT=0; fadeDir=-1; if(scene.enter) scene.enter(); }

/* ---------- Ввод (мышь/тач) ---------- */
const Input = { x:VW/2, y:VH/2, down:false, pressed:false };
let _pressQueued=false;
function toVirtual(cx,cy){ const r=canvas.getBoundingClientRect(); return {x:(cx-r.left)/r.width*VW, y:(cy-r.top)/r.height*VH}; }

/* =========================================================================
   СЦЕНА: ТИТУЛ
   ========================================================================= */
function TitleScene(){
  return { update(){}, draw(t){
    skyBg('#8ed0f5','#dff3ff');
    sun(850,110,46,t);
    cloud(180,120,1.1); cloud(680,90,0.9); cloud(420,170,0.7);
    ground('#8fd24a','#5fae33');

    drawBodo(500, 360, 1.5, 'happy', t);

    ctx.save(); ctx.shadowColor='rgba(0,0,0,0.25)'; ctx.shadowBlur=8; ctx.shadowOffsetY=4;
    text('Бодо Бородо', 500, 80, 64, '#ffffff'); ctx.restore();
    text('Путешествие за буквами', 500, 135, 30, '#fff3d0');

    const tot=LEVELS.reduce((s,l)=>s+(progress.stars[l.id]||0),0);
    text('⭐ '+tot+' / '+(LEVELS.length*3), 500, 175, 26, '#7a4a12');

    button(370,470,260,70,'▶  ИГРАТЬ',{size:34,onClick:()=>{SFX.tap();setScene(MapScene);}});
    button(665,478,210,54,'Сначала',{size:24,fill:'#cfd6dd',edge:'#aab2bb',txt:'#445',
      onClick:()=>{SFX.tap();progress={stars:{},unlocked:1};writeSave(progress);}});
  }};
}

/* =========================================================================
   СЦЕНА: КАРТА ПУТЕШЕСТВИЯ
   ========================================================================= */
function MapScene(){
  const nodes=[{x:130,y:440},{x:300,y:300},{x:470,y:430},{x:650,y:285},{x:810,y:420},{x:910,y:240}];
  return { update(){}, draw(t){
    skyBg('#bfe5ff','#eaf8ff');
    sun(90,90,38,t); cloud(760,90,1.0); cloud(520,60,0.7);
    ground('#9bd84f','#76bd38');

    ctx.strokeStyle='#e7c987'; ctx.lineWidth=26; ctx.lineCap='round'; ctx.lineJoin='round';
    ctx.beginPath(); ctx.moveTo(nodes[0].x,nodes[0].y);
    for(let i=1;i<nodes.length;i++) ctx.lineTo(nodes[i].x,nodes[i].y); ctx.stroke();
    ctx.strokeStyle='#fff'; ctx.lineWidth=3; ctx.setLineDash([14,14]);
    ctx.beginPath(); ctx.moveTo(nodes[0].x,nodes[0].y);
    for(let i=1;i<nodes.length;i++) ctx.lineTo(nodes[i].x,nodes[i].y); ctx.stroke(); ctx.setLineDash([]);

    text('Выбери этап путешествия', 500, 38, 30, '#1c4a6e');

    LEVELS.forEach((lv,i)=>{
      const n=nodes[i], unlocked=(i+1)<=progress.unlocked, stars=progress.stars[lv.id]||0;
      ctx.fillStyle=unlocked?C.panel:'#cfd6dd';
      ctx.strokeStyle=unlocked?C.panelEdge:'#a7b0b9'; ctx.lineWidth=5;
      ctx.beginPath(); ctx.arc(n.x,n.y,40,0,Math.PI*2); ctx.fill(); ctx.stroke();
      text(unlocked?lv.tag:'🔒', n.x, n.y-2, 34);
      text((i+1)+'. '+lv.name, n.x, n.y+58, 18, '#23415c');
      if(unlocked){ for(let s=0;s<3;s++) star(n.x-22+s*22, n.y-54, 9, s<stars?C.star:'rgba(255,255,255,0.4)');
        clickables.push({x:n.x-44,y:n.y-44,w:88,h:88,cb:()=>{SFX.tap();setScene(()=>LevelScene(i));}}); }
    });

    const cur=Math.min(progress.unlocked,LEVELS.length)-1;
    drawBodo(nodes[cur].x, nodes[cur].y-74, 0.5, 'happy', t);

    button(30,30,150,52,'⟵ Назад',{size:24,onClick:()=>{SFX.tap();setScene(TitleScene);}});
  }};
}

/* =========================================================================
   СЦЕНА: УРОВЕНЬ (quest | fly | run | catch)
   ========================================================================= */
function LevelScene(idx){
  const lv=LEVELS[idx];
  let phase='intro', mistakes=0, shake=0, flash=null, doneStars=0;
  let ti=0, st=null;     // quest
  let A=null;            // arcade state

  function fGood(){ SFX.good(); flash={c:'rgba(120,220,120,0.35)',t:0.4}; }
  function fCollect(){ SFX.star(); flash={c:'rgba(255,220,120,0.22)',t:0.18}; }
  function fBad(){ SFX.bad(); mistakes++; shake=0.4; flash={c:'rgba(230,90,80,0.3)',t:0.4}; }

  function begin(){
    phase='play';
    if(lv.type==='quest') startTask();
    else initArcade();
  }
  function finish(){
    phase='done';
    doneStars = mistakes===0?3 : mistakes<=2?2 : 1;
    progress.stars[lv.id]=Math.max(progress.stars[lv.id]||0, doneStars);
    if(idx+1>=progress.unlocked && idx+1<LEVELS.length) progress.unlocked=idx+2;
    writeSave(progress); spawnConfetti(); SFX.win();
  }

  /* ---------- QUEST ---------- */
  function startTask(){
    const task=lv.tasks[ti];
    if(task.kind==='pick') st={opts:shuffle([task.answer,...task.wrong])};
    else if(task.kind==='spell') st={built:'',pool:shuffle(task.word.split(''))};
  }
  function nextTask(){ ti++; if(ti>=lv.tasks.length) finish(); else startTask(); }

  /* ---------- ARCADE ---------- */
  function initArcade(){
    if(lv.type==='fly')   A={by:300,vy:0,items:[],haz:[],si:0.6,sh:1.0,got:0};
    if(lv.type==='run')   A={by:0,vy:0,onG:true,obs:[],ap:[],so:1.0,sa:0.8,scroll:0,got:0};
    if(lv.type==='catch') A={bx:500,items:[],sp:0.4,got:0};
  }
  function updateArcade(dt){
    if(lv.type==='fly') updFly(dt);
    if(lv.type==='run') updRun(dt);
    if(lv.type==='catch') updCatch(dt);
  }
  function updFly(dt){
    A.vy += 900*dt;
    if(Input.pressed){ A.vy=-330; SFX.jump(); }
    A.by += A.vy*dt;
    if(A.by<80){A.by=80;A.vy=0;} if(A.by>520){A.by=520;A.vy=0;}
    A.si-=dt; if(A.si<=0){ A.si=0.85+Math.random()*0.6; A.items.push({x:1060,y:110+Math.random()*360}); }
    A.sh-=dt; if(A.sh<=0){ A.sh=1.2+Math.random()*0.9; A.haz.push({x:1060,y:90+Math.random()*420,s:0.8+Math.random()*0.5}); }
    A.items.forEach(o=>o.x-=250*dt); A.haz.forEach(o=>o.x-=225*dt);
    const bx=240;
    A.items=A.items.filter(o=>{ if(Math.hypot(o.x-bx,o.y-A.by)<46){A.got++;fCollect();if(A.got>=lv.goal)finish();return false;} return o.x>-60; });
    A.haz=A.haz.filter(o=>{ if(Math.hypot(o.x-bx,o.y-A.by)<52*o.s+8){fBad();A.vy=-140;return false;} return o.x>-120; });
  }
  function updRun(dt){
    const groundY=470;
    if(Input.pressed && A.onG){ A.vy=-640; A.onG=false; SFX.jump(); }
    A.vy+=1700*dt; A.by+=A.vy*dt;
    if(A.by>=0){A.by=0;A.vy=0;A.onG=true;}
    A.scroll+=320*dt;
    A.so-=dt; if(A.so<=0){A.so=0.95+Math.random()*0.8; A.obs.push({x:1060});}
    A.sa-=dt; if(A.sa<=0){A.sa=0.8+Math.random()*0.7; A.ap.push({x:1060,y:groundY-110-Math.random()*120});}
    A.obs.forEach(o=>o.x-=320*dt); A.ap.forEach(o=>o.x-=320*dt);
    const bx=180;
    A.obs=A.obs.filter(o=>{ if(o.x>bx-42 && o.x<bx+42 && A.by>-66){fBad();return false;} return o.x>-60; });
    A.ap=A.ap.filter(o=>{ if(Math.hypot(o.x-bx,o.y-(groundY-50+A.by))<46){A.got++;fCollect();if(A.got>=lv.goal)finish();return false;} return o.x>-50; });
  }
  function updCatch(dt){
    A.bx += (Input.x-A.bx)*Math.min(1,dt*12);
    A.bx=Math.max(90,Math.min(910,A.bx));
    A.sp-=dt;
    if(A.sp<=0){ A.sp=0.5+Math.random()*0.45; const good=Math.random()<0.72; const arr=good?lv.good:lv.bad;
      A.items.push({x:120+Math.random()*760,y:-40,vy:150+Math.random()*130,e:arr[(Math.random()*arr.length)|0],good}); }
    const cy=478;
    A.items=A.items.filter(o=>{ o.y+=o.vy*dt;
      if(o.y>cy-34 && o.y<cy+44 && Math.abs(o.x-A.bx)<74){ if(o.good){A.got++;fCollect();if(A.got>=lv.goal)finish();} else fBad(); return false; }
      return o.y<660; });
  }

  /* ---------- ОБЩЕЕ ---------- */
  return {
    enter(){},
    update(dt){
      if(shake>0) shake-=dt;
      if(flash){ flash.t-=dt; if(flash.t<=0) flash=null; }
      if(phase==='play' && lv.type!=='quest') updateArcade(dt);
    },
    draw(t,dt){
      const dx = shake>0? (Math.random()-0.5)*14 : 0;
      ctx.save(); ctx.translate(dx,0);
      skyBg(lv.sky[0],lv.sky[1]); sun(880,80,32,t);
      cloud(220,80,0.8); cloud(640,60,0.6);
      ctx.restore();

      text(lv.tag+' '+lv.name, 500, 32, 26, '#23415c');

      if(phase==='intro') drawIntro(t);
      else if(phase==='play'){
        if(lv.type==='quest') drawQuest(t);
        else drawArcade(t,dt);
      }
      else drawDone(t,dt);

      if(flash){ ctx.fillStyle=flash.c; ctx.fillRect(0,0,VW,VH); }
    },
  };

  function drawIntro(t){
    drawBodo(195, 365, 1.15, 'happy', t);
    ctx.fillStyle=C.panel; ctx.strokeStyle=C.panelEdge; ctx.lineWidth=4;
    rr(360,150,600,230,28); ctx.fill(); ctx.stroke();
    ctx.beginPath(); ctx.moveTo(360,300); ctx.lineTo(318,338); ctx.lineTo(372,328); ctx.closePath();
    ctx.fillStyle=C.panel; ctx.fill();
    wrapText(lv.intro, 660, 255, 550, 27, C.ink, 37);
    button(640,480,270,66, lv.type==='quest'?'Начать!  ▶':'Поехали!  ▶', {size:30,onClick:()=>{SFX.tap();begin();}});
    button(30,540,150,48,'⟵ Карта',{size:22,fill:'#cfd6dd',edge:'#aab2bb',txt:'#445',onClick:()=>{SFX.tap();setScene(MapScene);}});
  }

  function hud(extra){
    if(lv.type!=='quest'){
      ctx.fillStyle='rgba(255,255,255,0.85)'; rr(770,58,200,44,12); ctx.fill();
      text('⭐ '+A.got+' / '+lv.goal, 845, 80, 26, '#23415c');
    }
    button(30,30,130,46,'⟵ Карта',{size:20,fill:'#cfd6dd',edge:'#aab2bb',txt:'#445',onClick:()=>{SFX.tap();setScene(MapScene);}});
  }

  /* ----- QUEST draw ----- */
  function drawQuest(t){
    ground('#9bd84f','#76bd38');
    const task=lv.tasks[ti];
    // прогресс
    const segW=70,gap=8,totW=lv.tasks.length*(segW+gap)-gap,sx=500-totW/2;
    for(let i=0;i<lv.tasks.length;i++){ ctx.fillStyle=i<ti?C.good:i===ti?C.btn:'rgba(255,255,255,0.6)'; rr(sx+i*(segW+gap),52,segW,12,6); ctx.fill(); }
    drawBodo(110, 470, 0.66, mistakes>0?'idle':'happy', t);
    if(task.kind==='pick') drawPick(task);
    if(task.kind==='spell') drawSpell(task);
    button(30,30,130,46,'⟵ Карта',{size:20,fill:'#cfd6dd',edge:'#aab2bb',txt:'#445',onClick:()=>{SFX.tap();setScene(MapScene);}});
  }
  function drawPick(task){
    ctx.fillStyle=C.panel; ctx.strokeStyle=C.panelEdge; ctx.lineWidth=4; rr(250,95,700,210,24); ctx.fill(); ctx.stroke();
    text('С какой буквы начинается слово?', 600, 130, 26, '#5a3410');
    text(task.emoji, 600, 200, 86);
    text(task.cap, 600, 268, 34, C.orangeDk);
    const opts=st.opts,n=opts.length,bw=200,bh=92,gp=30,tw=n*bw+(n-1)*gp,bx=500-tw/2;
    opts.forEach((o,i)=>button(bx+i*(bw+gp),400,bw,bh,o,{size:46,onClick:()=>{ if(o===task.answer){fGood();nextTask();} else fBad(); }}));
  }
  function drawSpell(task){
    ctx.fillStyle=C.panel; ctx.strokeStyle=C.panelEdge; ctx.lineWidth=4; rr(250,95,700,150,24); ctx.fill(); ctx.stroke();
    text(task.emoji, 340, 170, 80);
    text('Собери слово', 650, 135, 28, '#5a3410');
    const w=task.word,cw=64,gp=12,tw=w.length*(cw+gp)-gp,sx=650-tw/2;
    for(let i=0;i<w.length;i++){ const x=sx+i*(cw+gp); ctx.fillStyle='#fff'; ctx.strokeStyle=C.panelEdge; ctx.lineWidth=3; rr(x,178,cw,cw,10); ctx.fill(); ctx.stroke();
      if(i<st.built.length) text(st.built[i],x+cw/2,178+cw/2,40,C.good); }
    const pool=st.pool,pw=72,pg=16,pt=pool.length*(pw+pg)-pg,px=500-pt/2;
    pool.forEach((l,i)=>{ if(l===null) return; button(px+i*(pw+pg),400,pw,pw,l,{size:40,onClick:()=>{
      const need=task.word[st.built.length];
      if(l===need){ SFX.tap(); st.built+=l; st.pool[i]=null; if(st.built===task.word){ fGood(); setTimeout(nextTask,320); } }
      else fBad();
    }}); });
    text('Нажимай буквы по порядку', 500, 520, 22, '#5a3410');
  }

  /* ----- ARCADE draw ----- */
  function drawArcade(t,dt){
    if(lv.type==='fly') drawFly(t);
    if(lv.type==='run') drawRun(t);
    if(lv.type==='catch') drawCatch(t);
    text('Нажимай на экран!', 500, VH-26, 22, 'rgba(40,60,90,0.6)');
    hud();
  }
  function drawFly(t){
    cloud(120,140,0.9,'rgba(255,255,255,0.5)'); cloud(560,110,0.7,'rgba(255,255,255,0.5)');
    A.haz.forEach(o=>cloud(o.x,o.y,o.s*1.1,'rgba(120,140,170,0.92)'));
    A.items.forEach(o=>{ star(o.x,o.y,16,C.star); });
    // шар + Бодо
    const bx=240,by=A.by;
    ctx.strokeStyle='#b06a2a'; ctx.lineWidth=3; ctx.beginPath(); ctx.moveTo(bx,by-30); ctx.lineTo(bx-14,by-78); ctx.moveTo(bx,by-30); ctx.lineTo(bx+14,by-78); ctx.stroke();
    ctx.fillStyle='#e8552e'; ctx.beginPath(); ctx.ellipse(bx,by-104,40,46,0,0,Math.PI*2); ctx.fill();
    ctx.fillStyle='rgba(255,255,255,0.3)'; ctx.beginPath(); ctx.ellipse(bx-12,by-116,10,16,0,0,Math.PI*2); ctx.fill();
    drawBodo(bx, by, 0.5, 'happy', t);
  }
  function drawRun(t){
    const groundY=470;
    ctx.fillStyle='#7d5a3a'; ctx.fillRect(0,groundY+30,VW,VH-groundY-30);
    ctx.fillStyle='#9bd84f'; ctx.fillRect(0,groundY+10,VW,24);
    ctx.strokeStyle='rgba(255,255,255,0.4)'; ctx.lineWidth=4; ctx.setLineDash([30,26]); ctx.lineDashOffset=-A.scroll;
    ctx.beginPath(); ctx.moveTo(0,groundY+50); ctx.lineTo(VW,groundY+50); ctx.stroke(); ctx.setLineDash([]);
    A.ap.forEach(o=>text('🍎',o.x,o.y,46));
    A.obs.forEach(o=>text('🪨',o.x,groundY-2,52));
    drawBodo(180, groundY-40+A.by, 0.6, A.onG?'happy':'cheer', t);
  }
  function drawCatch(t){
    // вода
    ctx.fillStyle='rgba(120,200,230,0.4)'; ctx.fillRect(0,500,VW,VH-500);
    A.items.forEach(o=>text(o.e,o.x,o.y,46));
    drawBodo(A.bx, 500, 0.62, 'cheer', t);
    // ручки-«корзинка» подсветка
    ctx.fillStyle='rgba(255,255,255,0.25)'; rr(A.bx-72,470,144,10,5); ctx.fill();
  }

  /* ----- DONE ----- */
  function drawDone(t,dt){
    drawConfetti(dt);
    drawBodo(500, 340, 1.45, 'cheer', t);
    text(lv.type==='quest'?'Уровень пройден!':'Получилось!', 500, 105, 46, '#fff');
    text(lv.name, 500, 152, 26, '#fff3d0');
    for(let s=0;s<3;s++) star(420+s*80,232, s<doneStars?34:26, s<doneStars?C.star:'rgba(255,255,255,0.45)');
    button(300,500,180,64,'↻ Снова',{size:26,fill:'#cfd6dd',edge:'#aab2bb',txt:'#445',onClick:()=>{SFX.tap();setScene(()=>LevelScene(idx));}});
    if(idx+1<LEVELS.length) button(520,500,200,64,'Дальше ▶',{size:26,onClick:()=>{SFX.tap();setScene(()=>LevelScene(idx+1));}});
    else button(520,500,200,64,'На карту',{size:24,onClick:()=>{SFX.tap();setScene(MapScene);}});
  }
}

/* =========================================================================
   ГЛАВНЫЙ ЦИКЛ
   ========================================================================= */
scene=TitleScene();
let last=performance.now();
function loop(now){
  let dt=Math.min(0.05,(now-last)/1000); last=now; sceneT+=dt*1000;
  Input.pressed=_pressQueued; _pressQueued=false;

  clickables=[];
  if(scene.update) scene.update(dt);
  scene.draw(sceneT,dt);

  fade+=fadeDir*dt*3.2; if(fade<0)fade=0; if(fade>1)fade=1;
  if(fadeDir>0 && fade>=1 && pendingScene) _swap();
  if(fade>0){ ctx.fillStyle=`rgba(20,30,55,${fade})`; ctx.fillRect(0,0,VW,VH); }

  requestAnimationFrame(loop);
}
requestAnimationFrame(loop);

/* =========================================================================
   ОБРАБОТКА ВВОДА
   ========================================================================= */
let lastClickT=0;
function doClick(cx,cy){
  if(fade>0.4) return;
  const now=performance.now(); if(now-lastClickT<120) return; lastClickT=now;
  const p=toVirtual(cx,cy);
  for(let i=clickables.length-1;i>=0;i--){ const b=clickables[i];
    if(p.x>=b.x&&p.x<=b.x+b.w&&p.y>=b.y&&p.y<=b.y+b.h){ b.cb(); return; } }
}
canvas.addEventListener('pointerdown', e=>{
  e.preventDefault(); audio();
  const p=toVirtual(e.clientX,e.clientY); Input.x=p.x; Input.y=p.y; Input.down=true; _pressQueued=true;
}, {passive:false});
canvas.addEventListener('pointermove', e=>{
  const p=toVirtual(e.clientX,e.clientY); Input.x=p.x; Input.y=p.y;
}, {passive:false});
canvas.addEventListener('pointerup', e=>{
  e.preventDefault(); Input.down=false; doClick(e.clientX,e.clientY);
}, {passive:false});

})();
