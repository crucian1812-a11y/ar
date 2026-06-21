/* =========================================================================
   Бодо Бородо — Путешествие за буквами
   Образовательная игра-бродилка про русские буквы.
   Полностью офлайн, без внешних ресурсов. Рендер на Canvas.
   Персонаж Бодо нарисован векторно (оригинальный, "по мотивам").
   ========================================================================= */

(() => {
'use strict';

const VW = 1000, VH = 600;            // виртуальное разрешение
const canvas = document.getElementById('game');
const ctx = canvas.getContext('2d');

/* ---------- Палитра в стиле тёплого детского мультика ---------- */
const C = {
  sky1:'#7ec8f0', sky2:'#cdeeff',
  sun:'#ffd34e', grass1:'#8fd24a', grass2:'#5fae33',
  bodoCoat:'#e8552e', bodoCoatDk:'#c63f1e', bodoHat:'#b6863f', bodoHatDk:'#8c6326',
  beard:'#f1e2c4', beardSh:'#dcc79b', skin:'#ffd9b0',
  panel:'#fff7e6', panelEdge:'#e6c97a',
  ink:'#3a2a18', good:'#4caf50', bad:'#e25141',
  btn:'#ffb13b', btnDk:'#e8901a', btnTxt:'#5a3410',
  star:'#ffd34e', lock:'#9aa3ad',
};

/* ---------- Звук (WebAudio, без файлов) ---------- */
let actx = null;
function audio(){ if(!actx){ try{ actx = new (window.AudioContext||window.webkitAudioContext)(); }catch(e){} } return actx; }
function beep(freq, dur, type='sine', vol=0.18){
  const a = audio(); if(!a) return;
  const o = a.createOscillator(), g = a.createGain();
  o.type = type; o.frequency.value = freq;
  g.gain.value = vol;
  o.connect(g); g.connect(a.destination);
  const t = a.currentTime;
  o.start(t);
  g.gain.setValueAtTime(vol, t);
  g.gain.exponentialRampToValueAtTime(0.0001, t+dur);
  o.stop(t+dur);
}
const SFX = {
  tap:   () => beep(520, 0.07, 'triangle', 0.12),
  good:  () => { beep(660,0.12,'sine',0.2); setTimeout(()=>beep(880,0.16,'sine',0.2),90); },
  win:   () => { [523,659,784,1046].forEach((f,i)=>setTimeout(()=>beep(f,0.18,'sine',0.2), i*120)); },
  bad:   () => beep(150, 0.22, 'sawtooth', 0.14),
  star:  () => beep(1175, 0.18, 'sine', 0.2),
};

/* ---------- Сохранение прогресса ---------- */
const SAVE_KEY = 'bodo_progress_v1';
function loadSave(){
  try { return JSON.parse(localStorage.getItem(SAVE_KEY)) || {}; } catch(e){ return {}; }
}
function writeSave(s){ try{ localStorage.setItem(SAVE_KEY, JSON.stringify(s)); }catch(e){} }
let progress = loadSave();            // { stars: {levelId: 0..3}, unlocked: n }
if(!progress.stars) progress.stars = {};
if(progress.unlocked == null) progress.unlocked = 1;

/* =========================================================================
   КОНТЕНТ УРОВНЕЙ — 6 этапов путешествия (по числу серий мультика)
   ========================================================================= */
const LEVELS = [
  {
    id:'meadow', name:'Полянка Букв', tag:'🌼', sky:['#aee6ff','#e8fbff'],
    intro:'Привет! Я — Бодо Бородо. Отправляемся в путь за буквами! С какой буквы начинается слово?',
    tasks:[
      { kind:'pick', prompt:'С какой буквы начинается слово?', emoji:'🐱', cap:'КОТ',  answer:'К', wrong:['М','Т'] },
      { kind:'pick', prompt:'С какой буквы начинается слово?', emoji:'🏠', cap:'ДОМ',  answer:'Д', wrong:['Б','О'] },
      { kind:'pick', prompt:'С какой буквы начинается слово?', emoji:'🐟', cap:'РЫБА', answer:'Р', wrong:['Л','Ы'] },
      { kind:'pick', prompt:'С какой буквы начинается слово?', emoji:'☀️', cap:'СОЛНЦЕ', answer:'С', wrong:['З','Ц'] },
      { kind:'pick', prompt:'С какой буквы начинается слово?', emoji:'🌙', cap:'ЛУНА', answer:'Л', wrong:['Н','У'] },
    ],
  },
  {
    id:'train', name:'Поезд Слогов', tag:'🚂', sky:['#ffe6b0','#fff7e0'],
    intro:'Садимся в поезд! Собери слово из букв по порядку — нажимай нужные буквы.',
    tasks:[
      { kind:'spell', word:'КОТ',  emoji:'🐱' },
      { kind:'spell', word:'ДОМ',  emoji:'🏠' },
      { kind:'spell', word:'ШАР',  emoji:'🎈' },
      { kind:'spell', word:'МАМА', emoji:'👩' },
      { kind:'spell', word:'ЛУНА', emoji:'🌙' },
    ],
  },
  {
    id:'mountain', name:'Гора Гласных', tag:'⛰️', sky:['#cdb4ff','#efe6ff'],
    intro:'Высоко в горах прячутся гласные буквы. Поймай все гласные — а согласные не трогай!',
    tasks:[
      { kind:'multi', prompt:'Найди все ГЛАСНЫЕ', letters:['А','Б','О','К','И','Т'], correct:['А','О','И'] },
      { kind:'multi', prompt:'Найди все ГЛАСНЫЕ', letters:['М','У','Р','Е','С','Ы'], correct:['У','Е','Ы'] },
      { kind:'multi', prompt:'Найди все ГЛАСНЫЕ', letters:['Э','Н','Ю','Л','Я','Д'], correct:['Э','Ю','Я'] },
    ],
  },
  {
    id:'river', name:'Река Загадок', tag:'🌊', sky:['#a8e6cf','#e3fff4'],
    intro:'У реки Бодо загадывает загадки. Отгадай слово!',
    tasks:[
      { kind:'pick', prompt:'Мохнатый, мяукает, ловит мышей. Кто это?', answer:'КОТ',    wrong:['СЛОН','РЫБА'] },
      { kind:'pick', prompt:'Светит днём, греет, живёт на небе.',        answer:'СОЛНЦЕ', wrong:['ЛУНА','ДОМ'] },
      { kind:'pick', prompt:'Плавает в реке, молчит, блестит чешуёй.',   answer:'РЫБА',   wrong:['КОТ','ПТИЦА'] },
      { kind:'pick', prompt:'В нём живут люди, есть окна и крыша.',       answer:'ДОМ',    wrong:['ЛЕС','МОСТ'] },
    ],
  },
  {
    id:'forest', name:'Лес Слов', tag:'🌲', sky:['#bfe9a0','#eaffd9'],
    intro:'В лесу ветер унёс по букве из каждого слова. Какой буквы не хватает?',
    tasks:[
      { kind:'pick', prompt:'Какой буквы не хватает?', big:'К_Т',  emoji:'🐱', answer:'О', wrong:['А','У'] },
      { kind:'pick', prompt:'Какой буквы не хватает?', big:'Д_М',  emoji:'🏠', answer:'О', wrong:['Ы','И'] },
      { kind:'pick', prompt:'Какой буквы не хватает?', big:'СЛО_', emoji:'🐘', answer:'Н', wrong:['М','Л'] },
      { kind:'pick', prompt:'Какой буквы не хватает?', big:'ША_',  emoji:'🎈', answer:'Р', wrong:['К','Л'] },
      { kind:'pick', prompt:'Какой буквы не хватает?', big:'М_МА', emoji:'👩', answer:'А', wrong:['О','Я'] },
    ],
  },
  {
    id:'castle', name:'Замок Азбуки', tag:'🏰', sky:['#ffc1d6','#ffe9f1'],
    intro:'Вот и Замок Азбуки! Последнее испытание — задания со всех уровней. Ты справишься!',
    tasks:[
      { kind:'pick',  prompt:'С какой буквы начинается слово?', emoji:'🐘', cap:'СЛОН', answer:'С', wrong:['Л','О'] },
      { kind:'multi', prompt:'Найди все ГЛАСНЫЕ', letters:['О','Г','А','П','Я','Ж'], correct:['О','А','Я'] },
      { kind:'spell', word:'РЫБА', emoji:'🐟' },
      { kind:'pick',  prompt:'Отгадай: круглый, катится, на нём играют.', answer:'МЯЧ', wrong:['ДОМ','КОТ'] },
      { kind:'pick',  prompt:'Какой буквы не хватает?', big:'ЛУН_', emoji:'🌙', answer:'А', wrong:['О','Ы'] },
    ],
  },
];

/* =========================================================================
   ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ РИСОВАНИЯ
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
  ctx.fillStyle = color;
  ctx.font = `${weight} ${size}px "Comic Sans MS", "Segoe UI", sans-serif`;
  ctx.textAlign = align; ctx.textBaseline='middle';
  ctx.fillText(str,x,y);
}
function wrapText(str,x,y,maxW,size,color,lh){
  ctx.fillStyle=color;
  ctx.font=`bold ${size}px "Comic Sans MS","Segoe UI",sans-serif`;
  ctx.textAlign='center'; ctx.textBaseline='middle';
  const words=str.split(' '); let line=''; const lines=[];
  for(const w of words){
    const t=line?line+' '+w:w;
    if(ctx.measureText(t).width>maxW && line){ lines.push(line); line=w; }
    else line=t;
  }
  if(line) lines.push(line);
  const startY=y-(lines.length-1)*lh/2;
  lines.forEach((l,i)=>ctx.fillText(l,x,startY+i*lh));
}

/* ---------- Иммедиэйт-режим кнопок ---------- */
let clickables = [];
function button(x,y,w,h,label,opts={}){
  const o = Object.assign({size:30, fill:C.btn, edge:C.btnDk, txt:C.btnTxt, emoji:false, press:0}, opts);
  ctx.save();
  ctx.translate(0, o.press||0);
  // тень
  ctx.fillStyle='rgba(0,0,0,0.15)'; rr(x+3,y+5,w,h,16); ctx.fill();
  ctx.fillStyle=o.edge; rr(x,y+5,w,h,16); ctx.fill();
  ctx.fillStyle=o.fill; rr(x,y,w,h,16); ctx.fill();
  ctx.strokeStyle='rgba(255,255,255,0.5)'; ctx.lineWidth=2; rr(x+3,y+3,w-6,h*0.42,12); ctx.stroke();
  text(label, x+w/2, y+h/2, o.size, o.txt, 'center');
  ctx.restore();
  if(opts.onClick) clickables.push({x,y,w,h,cb:opts.onClick});
}

/* =========================================================================
   ПЕРСОНАЖ БОДО БОРОДО (оригинальный, "по мотивам")
   mood: 'idle' | 'happy' | 'cheer'
   ========================================================================= */
function drawBodo(cx, cy, scale, mood='idle', t=0){
  ctx.save();
  ctx.translate(cx, cy);
  const bob = Math.sin(t/420)*4*scale;
  ctx.translate(0, bob);
  ctx.scale(scale, scale);

  // тень
  ctx.fillStyle='rgba(0,0,0,0.12)';
  ctx.beginPath(); ctx.ellipse(0, 96, 62, 14, 0, 0, Math.PI*2); ctx.fill();

  // тело — куртка путешественника
  ctx.fillStyle=C.bodoCoat;
  rr(-46, 8, 92, 92, 26); ctx.fill();
  ctx.fillStyle=C.bodoCoatDk;
  rr(-46, 70, 92, 30, 22); ctx.fill();
  // ремень
  ctx.fillStyle='#5a3a1c'; rr(-46, 60, 92, 12, 4); ctx.fill();
  ctx.fillStyle=C.bodoHat; rr(-9, 60, 18, 12, 3); ctx.fill();
  // руки
  ctx.fillStyle=C.bodoCoat;
  ctx.beginPath(); ctx.ellipse(-50, 40, 14, 24, 0.2, 0, Math.PI*2); ctx.fill();
  ctx.beginPath(); ctx.ellipse(50, 40, 14, 24, -0.2, 0, Math.PI*2); ctx.fill();
  ctx.fillStyle=C.skin;
  ctx.beginPath(); ctx.arc(-55, 60, 9, 0, Math.PI*2); ctx.fill();
  if(mood==='cheer'){ ctx.beginPath(); ctx.arc(58, 12, 9, 0, Math.PI*2); ctx.fill(); }
  else { ctx.beginPath(); ctx.arc(55, 60, 9, 0, Math.PI*2); ctx.fill(); }

  // голова
  ctx.fillStyle=C.skin;
  ctx.beginPath(); ctx.arc(0, -36, 40, 0, Math.PI*2); ctx.fill();

  // БОРОДА (главная черта Бодо Бородо)
  ctx.fillStyle=C.beard;
  ctx.beginPath();
  ctx.moveTo(-38,-40);
  ctx.quadraticCurveTo(-50,-2,-30,28);
  ctx.quadraticCurveTo(-16,48,0,50);
  ctx.quadraticCurveTo(16,48,30,28);
  ctx.quadraticCurveTo(50,-2,38,-40);
  ctx.quadraticCurveTo(20,-20,0,-18);
  ctx.quadraticCurveTo(-20,-20,-38,-40);
  ctx.closePath(); ctx.fill();
  // кудряшки бороды
  ctx.fillStyle=C.beardSh;
  for(const [bx,by] of [[-28,12],[-12,30],[8,30],[26,12],[0,40]]){
    ctx.beginPath(); ctx.arc(bx,by,9,0,Math.PI*2); ctx.fill();
  }
  ctx.fillStyle=C.beard;
  for(const [bx,by] of [[-20,18],[0,22],[18,18]]){
    ctx.beginPath(); ctx.arc(bx,by,8,0,Math.PI*2); ctx.fill();
  }

  // усы
  ctx.fillStyle=C.beardSh;
  ctx.beginPath(); ctx.ellipse(-13,-12,12,7,0.3,0,Math.PI*2); ctx.fill();
  ctx.beginPath(); ctx.ellipse(13,-12,12,7,-0.3,0,Math.PI*2); ctx.fill();

  // нос
  ctx.fillStyle='#f0b88a';
  ctx.beginPath(); ctx.arc(0,-18,8,0,Math.PI*2); ctx.fill();

  // глаза
  const blink = (Math.floor(t/2600)%1===0 && (t%2600)>2450);
  ctx.fillStyle='#fff';
  ctx.beginPath(); ctx.ellipse(-14,-34,9,blink?2:11,0,0,Math.PI*2); ctx.fill();
  ctx.beginPath(); ctx.ellipse(14,-34,9,blink?2:11,0,0,Math.PI*2); ctx.fill();
  if(!blink){
    ctx.fillStyle=C.ink;
    const lx = mood==='idle'? Math.sin(t/900)*2 : 0;
    ctx.beginPath(); ctx.arc(-14+lx,-33,5,0,Math.PI*2); ctx.fill();
    ctx.beginPath(); ctx.arc(14+lx,-33,5,0,Math.PI*2); ctx.fill();
  }
  // брови
  ctx.strokeStyle=C.beardSh; ctx.lineWidth=4; ctx.lineCap='round';
  ctx.beginPath();
  if(mood==='happy'||mood==='cheer'){
    ctx.moveTo(-24,-48); ctx.quadraticCurveTo(-14,-52,-6,-48);
    ctx.moveTo(6,-48); ctx.quadraticCurveTo(14,-52,24,-48);
  } else {
    ctx.moveTo(-23,-47); ctx.lineTo(-6,-46);
    ctx.moveTo(6,-46); ctx.lineTo(23,-47);
  }
  ctx.stroke();

  // улыбка (видна сквозь бороду)
  ctx.strokeStyle='#c0392b'; ctx.lineWidth=3;
  ctx.beginPath();
  if(mood==='cheer'){ ctx.arc(0,-6,12,0.15*Math.PI,0.85*Math.PI); }
  else { ctx.arc(0,-8,9,0.1*Math.PI,0.9*Math.PI); }
  ctx.stroke();

  // ШЛЯПА путешественника
  ctx.fillStyle=C.bodoHatDk;
  ctx.beginPath(); ctx.ellipse(0,-66,52,14,0,0,Math.PI*2); ctx.fill();
  ctx.fillStyle=C.bodoHat;
  rr(-30,-96,60,34,12); ctx.fill();
  ctx.fillStyle=C.bodoHatDk; rr(-30,-74,60,10,4); ctx.fill();
  ctx.fillStyle=C.bodoCoat; rr(-30,-78,60,6,3); ctx.fill();

  ctx.restore();
}

/* =========================================================================
   ФОНЫ / СЦЕНЕРИЯ
   ========================================================================= */
function skyBg(c1,c2){
  const g=ctx.createLinearGradient(0,0,0,VH);
  g.addColorStop(0,c1); g.addColorStop(1,c2);
  ctx.fillStyle=g; ctx.fillRect(0,0,VW,VH);
}
function sun(x,y,r,t){
  ctx.save();
  ctx.translate(x,y); ctx.rotate(t/4000);
  ctx.fillStyle='rgba(255,211,78,0.5)';
  for(let i=0;i<12;i++){ ctx.rotate(Math.PI/6); ctx.fillRect(r,-4,r*0.5,8); }
  ctx.restore();
  ctx.fillStyle=C.sun; ctx.beginPath(); ctx.arc(x,y,r,0,Math.PI*2); ctx.fill();
}
function ground(color1,color2){
  ctx.fillStyle=color2;
  ctx.beginPath(); ctx.moveTo(0,470);
  ctx.quadraticCurveTo(250,440,500,470);
  ctx.quadraticCurveTo(750,500,1000,460);
  ctx.lineTo(1000,VH); ctx.lineTo(0,VH); ctx.closePath(); ctx.fill();
  ctx.fillStyle=color1;
  ctx.beginPath(); ctx.moveTo(0,500);
  ctx.quadraticCurveTo(300,475,600,505);
  ctx.quadraticCurveTo(800,525,1000,495);
  ctx.lineTo(1000,VH); ctx.lineTo(0,VH); ctx.closePath(); ctx.fill();
}
function cloud(x,y,s){
  ctx.fillStyle='rgba(255,255,255,0.85)';
  for(const [dx,dy,r] of [[0,0,26],[26,6,20],[-26,6,20],[0,10,30]]){
    ctx.beginPath(); ctx.arc(x+dx*s,y+dy*s,r*s,0,Math.PI*2); ctx.fill();
  }
}

/* ---------- Конфетти ---------- */
let confetti=[];
function spawnConfetti(){
  confetti=[];
  for(let i=0;i<90;i++){
    confetti.push({x:Math.random()*VW,y:-Math.random()*VH,
      vx:(Math.random()-0.5)*60, vy:80+Math.random()*120,
      c:['#ff5a5a','#ffd34e','#5ad15a','#5a9dff','#d35aff'][i%5],
      r:Math.random()*Math.PI, s:5+Math.random()*6});
  }
}
function drawConfetti(dt){
  for(const p of confetti){
    p.x+=p.vx*dt; p.y+=p.vy*dt; p.r+=dt*5;
    if(p.y>VH+10){ p.y=-10; p.x=Math.random()*VW; }
    ctx.save(); ctx.translate(p.x,p.y); ctx.rotate(p.r);
    ctx.fillStyle=p.c; ctx.fillRect(-p.s/2,-p.s/2,p.s,p.s); ctx.restore();
  }
}

/* ---------- Звёзды результата ---------- */
function star(x,y,r,fill){
  ctx.beginPath();
  for(let i=0;i<5;i++){
    const a=-Math.PI/2 + i*2*Math.PI/5;
    ctx.lineTo(x+Math.cos(a)*r, y+Math.sin(a)*r);
    const a2=a+Math.PI/5;
    ctx.lineTo(x+Math.cos(a2)*r*0.45, y+Math.sin(a2)*r*0.45);
  }
  ctx.closePath();
  ctx.fillStyle=fill; ctx.fill();
  ctx.lineWidth=3; ctx.strokeStyle='#e0a92e'; ctx.stroke();
}

/* =========================================================================
   ДВИЖОК СЦЕН
   ========================================================================= */
let scene = null, sceneT = 0, fade = 1, fadeDir = -1, pendingScene = null;
function setScene(factory){ pendingScene = factory; fadeDir = 1; }
function _swap(){
  scene = pendingScene(); pendingScene=null; sceneT=0; fadeDir=-1;
  if(scene.enter) scene.enter();
}

/* ---------- Утилита перемешивания ---------- */
function shuffle(a){ a=a.slice(); for(let i=a.length-1;i>0;i--){const j=(Math.random()*(i+1))|0;[a[i],a[j]]=[a[j],a[i]];} return a; }

/* =========================================================================
   СЦЕНА: ТИТУЛ
   ========================================================================= */
function TitleScene(){
  return {
    update(){},
    draw(t){
      skyBg('#8ed0f5','#dff3ff');
      sun(840,110,46,t);
      cloud(180,120,1.1); cloud(700,90,0.9); cloud(420,170,0.7);
      ground(C.grass1,C.grass2);
      // холмы-домики на фоне
      ctx.fillStyle='#f4c95d'; rr(120,420,70,60,8); ctx.fill();
      ctx.fillStyle='#e8552e'; ctx.beginPath(); ctx.moveTo(112,422); ctx.lineTo(155,392); ctx.lineTo(198,422); ctx.closePath(); ctx.fill();

      drawBodo(500, 350, 1.5, 'happy', t);

      // заголовок
      ctx.save();
      ctx.shadowColor='rgba(0,0,0,0.25)'; ctx.shadowBlur=8; ctx.shadowOffsetY=4;
      text('Бодо Бородо', 500, 90, 64, '#ffffff');
      ctx.restore();
      text('Путешествие за буквами', 500, 145, 30, '#fff3d0');

      const totalStars = LEVELS.reduce((s,l)=>s+(progress.stars[l.id]||0),0);
      text('⭐ '+totalStars+' / '+(LEVELS.length*3), 500, 185, 26, '#7a4a12');

      button(370, 470, 260, 70, '▶  ИГРАТЬ', {size:34, onClick:()=>{ SFX.tap(); setScene(MapScene); }});
      button(665, 478, 200, 54, 'Сбросить', {size:24, fill:'#cfd6dd', edge:'#aab2bb', txt:'#445',
        onClick:()=>{ SFX.tap(); progress={stars:{},unlocked:1}; writeSave(progress); }});
    }
  };
}

/* =========================================================================
   СЦЕНА: КАРТА ПУТЕШЕСТВИЯ (бродилка)
   ========================================================================= */
function MapScene(){
  // позиции узлов на извилистой дороге
  const nodes = [
    {x:140,y:430},{x:300,y:300},{x:470,y:420},
    {x:640,y:280},{x:800,y:410},{x:900,y:230},
  ];
  return {
    update(){},
    draw(t){
      skyBg('#bfe5ff','#eaf8ff');
      sun(90,90,38,t);
      cloud(760,90,1.0); cloud(500,60,0.7);
      ground('#9bd84f','#76bd38');

      // дорога
      ctx.strokeStyle='#e7c987'; ctx.lineWidth=26; ctx.lineCap='round'; ctx.lineJoin='round';
      ctx.beginPath(); ctx.moveTo(nodes[0].x,nodes[0].y);
      for(let i=1;i<nodes.length;i++) ctx.lineTo(nodes[i].x,nodes[i].y);
      ctx.stroke();
      ctx.strokeStyle='#fff'; ctx.lineWidth=3; ctx.setLineDash([14,14]);
      ctx.beginPath(); ctx.moveTo(nodes[0].x,nodes[0].y);
      for(let i=1;i<nodes.length;i++) ctx.lineTo(nodes[i].x,nodes[i].y);
      ctx.stroke(); ctx.setLineDash([]);

      text('Выбери этап путешествия', 500, 40, 30, '#1c4a6e');

      LEVELS.forEach((lv,i)=>{
        const n=nodes[i];
        const unlocked = (i+1)<=progress.unlocked;
        const stars = progress.stars[lv.id]||0;
        // кружок узла
        ctx.fillStyle= unlocked? C.panel : '#cfd6dd';
        ctx.strokeStyle= unlocked? C.panelEdge : '#a7b0b9'; ctx.lineWidth=5;
        ctx.beginPath(); ctx.arc(n.x,n.y,40,0,Math.PI*2); ctx.fill(); ctx.stroke();
        text(unlocked? lv.tag : '🔒', n.x, n.y-2, 34);
        text((i+1)+'. '+lv.name, n.x, n.y+58, 19, '#23415c');
        // звёзды
        if(unlocked){
          for(let s=0;s<3;s++) star(n.x-22+s*22, n.y-54, 9, s<stars? C.star : 'rgba(255,255,255,0.4)');
        }
        if(unlocked) clickables.push({x:n.x-44,y:n.y-44,w:88,h:88,cb:()=>{ SFX.tap(); setScene(()=>LevelScene(i)); }});
      });

      // Бодо рядом с последним открытым узлом
      const cur = Math.min(progress.unlocked, LEVELS.length)-1;
      drawBodo(nodes[cur].x, nodes[cur].y-78, 0.55, 'happy', t);

      button(30, 30, 150, 52, '⟵ Назад', {size:24, onClick:()=>{ SFX.tap(); setScene(TitleScene); }});
    }
  };
}

/* =========================================================================
   СЦЕНА: УРОВЕНЬ
   ========================================================================= */
function LevelScene(idx){
  const lv = LEVELS[idx];
  let phase = 'intro';      // intro | play | done
  let ti = 0;               // индекс задания
  let mistakes = 0;
  let shake = 0;
  let flash = null;         // {color,t}
  let st = null;            // состояние текущего задания

  function startTask(){
    const task = lv.tasks[ti];
    if(task.kind==='pick'){
      const opts = shuffle([task.answer, ...task.wrong]);
      st = {opts};
    } else if(task.kind==='spell'){
      st = {built:'', pool: shuffle(task.word.split(''))};
    } else if(task.kind==='multi'){
      st = {picked:new Set()};
    }
  }
  function correctFx(){ SFX.good(); flash={color:'rgba(120,220,120,0.35)',t:0.5}; }
  function wrongFx(){ SFX.bad(); mistakes++; shake=0.45; flash={color:'rgba(230,90,80,0.3)',t:0.4}; }

  function nextTask(){
    ti++;
    if(ti>=lv.tasks.length){ finish(); }
    else startTask();
  }
  function finish(){
    phase='done';
    let stars = mistakes===0?3 : mistakes<=2?2 : 1;
    progress.stars[lv.id] = Math.max(progress.stars[lv.id]||0, stars);
    if(idx+1>=progress.unlocked && idx+1<LEVELS.length) progress.unlocked = idx+2;
    writeSave(progress);
    spawnConfetti(); SFX.win();
    st = {stars};
  }

  return {
    enter(){ startTask(); },
    update(dt){
      if(shake>0) shake=Math.max(0,shake-dt);
      if(flash){ flash.t-=dt; if(flash.t<=0) flash=null; }
    },
    draw(t,dt){
      const dx = shake>0? (Math.random()-0.5)*14 : 0;
      ctx.save(); ctx.translate(dx,0);
      skyBg(lv.sky[0], lv.sky[1]);
      sun(880,80,34,t);
      cloud(220,80,0.8); cloud(640,60,0.6);
      ground('#9bd84f','#76bd38');
      ctx.restore();

      // прогресс-бар сверху
      text(lv.tag+' '+lv.name, 500, 34, 26, '#23415c');
      const segW=70, gap=8, totW=lv.tasks.length*(segW+gap)-gap, sx=500-totW/2;
      for(let i=0;i<lv.tasks.length;i++){
        ctx.fillStyle = i<ti? C.good : i===ti? C.btn : 'rgba(255,255,255,0.6)';
        rr(sx+i*(segW+gap), 56, segW, 12, 6); ctx.fill();
      }

      if(phase==='intro'){
        drawBodo(200, 360, 1.15, 'happy', t);
        // облако реплики
        ctx.fillStyle=C.panel; ctx.strokeStyle=C.panelEdge; ctx.lineWidth=4;
        rr(360, 150, 590, 230, 28); ctx.fill(); ctx.stroke();
        ctx.beginPath(); ctx.moveTo(360,300); ctx.lineTo(320,340); ctx.lineTo(372,330); ctx.closePath();
        ctx.fillStyle=C.panel; ctx.fill();
        wrapText(lv.intro, 655, 255, 540, 28, C.ink, 38);
        button(640, 480, 260, 66, 'Начать!  ▶', {size:30, onClick:()=>{ SFX.tap(); phase='play'; }});
        button(30, 540, 150, 48, '⟵ Карта', {size:22, fill:'#cfd6dd',edge:'#aab2bb',txt:'#445',
          onClick:()=>{ SFX.tap(); setScene(MapScene); }});
      }
      else if(phase==='play'){
        const task = lv.tasks[ti];
        drawBodo(110, 470, 0.7, mistakes>0?'idle':'happy', t);
        if(task.kind==='pick')  drawPick(task, t);
        if(task.kind==='spell') drawSpell(task, t);
        if(task.kind==='multi') drawMulti(task, t);
        button(30, 30, 130, 46, '⟵ Карта', {size:20, fill:'#cfd6dd',edge:'#aab2bb',txt:'#445',
          onClick:()=>{ SFX.tap(); setScene(MapScene); }});
      }
      else if(phase==='done'){
        drawConfetti(dt);
        drawBodo(500, 330, 1.5, 'cheer', t);
        text('Уровень пройден!', 500, 110, 46, '#fff', 'center');
        text(lv.name, 500, 155, 26, '#fff3d0');
        const stars=st.stars;
        for(let s=0;s<3;s++){
          const big = s<stars;
          star(420+s*80, 235, big?34:26, big? C.star : 'rgba(255,255,255,0.45)');
        }
        button(300, 500, 180, 64, '↻ Снова', {size:26, fill:'#cfd6dd',edge:'#aab2bb',txt:'#445',
          onClick:()=>{ SFX.tap(); setScene(()=>LevelScene(idx)); }});
        if(idx+1<LEVELS.length)
          button(520, 500, 200, 64, 'Дальше ▶', {size:26,
            onClick:()=>{ SFX.tap(); setScene(()=>LevelScene(idx+1)); }});
        else
          button(520, 500, 200, 64, 'На карту', {size:24,
            onClick:()=>{ SFX.tap(); setScene(MapScene); }});
      }

      // вспышка обратной связи
      if(flash){ ctx.fillStyle=flash.color; ctx.fillRect(0,0,VW,VH); }
    },
  };

  /* --- рендер задания PICK --- */
  function drawPick(task, t){
    // карточка вопроса
    ctx.fillStyle=C.panel; ctx.strokeStyle=C.panelEdge; ctx.lineWidth=4;
    rr(250, 95, 700, 230, 24); ctx.fill(); ctx.stroke();
    if(task.emoji && !task.big) text(task.emoji, 600, 175, 92);
    if(task.big){
      text(task.big, 600, task.emoji?150:185, 76, C.ink);
      if(task.emoji) text(task.emoji, 600, 250, 56);
    }
    if(task.cap) text(task.cap, 600, 255, 34, C.bodoCoatDk);
    wrapText(task.prompt, 600, task.emoji||task.big?300:200, 640, 26, '#5a3410', 34);

    // варианты
    const opts=st.opts, n=opts.length;
    const bw=200, bh=92, gap=30, totW=n*bw+(n-1)*gap, sx=500-totW/2;
    opts.forEach((opt,i)=>{
      button(sx+i*(bw+gap), 400, bw, bh, opt, {size:opt.length>4?34:46,
        onClick:()=>{
          if(opt===task.answer){ correctFx(); nextTask(); }
          else wrongFx();
        }});
    });
  }

  /* --- рендер задания SPELL --- */
  function drawSpell(task, t){
    ctx.fillStyle=C.panel; ctx.strokeStyle=C.panelEdge; ctx.lineWidth=4;
    rr(250, 95, 700, 150, 24); ctx.fill(); ctx.stroke();
    text(task.emoji, 340, 170, 86);
    text('Собери слово', 640, 140, 28, '#5a3410');
    // ячейки слова
    const w=task.word, cw=64, gap=12, totW=w.length*cw+(w.length-1)*gap, sx=560-totW/2+90;
    for(let i=0;i<w.length;i++){
      const x=sx+i*(cw+gap);
      ctx.fillStyle='#fff'; ctx.strokeStyle=C.panelEdge; ctx.lineWidth=3;
      rr(x,180,cw,cw,10); ctx.fill(); ctx.stroke();
      if(i<st.built.length) text(st.built[i], x+cw/2, 180+cw/2, 40, C.good);
    }
    // буквы-плитки в пуле
    const pool=st.pool, pw=72, pgap=16, ptot=pool.length*pw+(pool.length-1)*pgap, psx=500-ptot/2;
    pool.forEach((ltr,i)=>{
      if(ltr===null) return;
      button(psx+i*(pw+pgap), 400, pw, pw, ltr, {size:40,
        onClick:()=>{
          const need = task.word[st.built.length];
          if(ltr===need){
            SFX.tap(); st.built+=ltr; st.pool[i]=null;
            if(st.built===task.word){ correctFx(); setTimeout(()=>nextTask(), 350); }
          } else wrongFx();
        }});
    });
    text('Подсказка: нажимай буквы по порядку', 500, 520, 22, '#5a3410');
  }

  /* --- рендер задания MULTI --- */
  function drawMulti(task, t){
    ctx.fillStyle=C.panel; ctx.strokeStyle=C.panelEdge; ctx.lineWidth=4;
    rr(300, 95, 600, 90, 24); ctx.fill(); ctx.stroke();
    text(task.prompt, 600, 140, 30, C.bodoCoatDk);

    const letters=task.letters, n=letters.length;
    const cols=Math.min(n,6), bw=120, bh=110, gap=18;
    const totW=cols*bw+(cols-1)*gap, sx=500-totW/2;
    letters.forEach((ltr,i)=>{
      const picked=st.picked.has(ltr);
      button(sx+i*(bw+gap), 250, bw, bh, ltr, {size:54,
        fill: picked? C.good : C.btn, edge: picked? '#3a8f3e' : C.btnDk,
        onClick:()=>{
          if(picked) return;
          if(task.correct.includes(ltr)){
            SFX.tap(); st.picked.add(ltr);
            if(task.correct.every(c=>st.picked.has(c))){ correctFx(); setTimeout(()=>nextTask(),300); }
          } else wrongFx();
        }});
    });
    text(`Найдено: ${[...st.picked].length} из ${task.correct.length}`, 500, 430, 26, '#5a3410');
  }
}

/* =========================================================================
   ГЛАВНЫЙ ЦИКЛ
   ========================================================================= */
scene = TitleScene();
let last = performance.now();
function loop(now){
  let dt = Math.min(0.05, (now-last)/1000); last=now;
  sceneT += dt*1000;

  clickables = [];
  if(scene.update) scene.update(dt);
  scene.draw(sceneT, dt);

  // переход (фейд)
  fade += fadeDir*dt*3.2;
  if(fade<0) fade=0; if(fade>1) fade=1;
  if(fadeDir>0 && fade>=1 && pendingScene){ _swap(); }
  if(fade>0){ ctx.fillStyle=`rgba(20,30,55,${fade})`; ctx.fillRect(0,0,VW,VH); }

  requestAnimationFrame(loop);
}
requestAnimationFrame(loop);

/* =========================================================================
   ВВОД (мышь + тач), маппинг координат в виртуальное пространство
   ========================================================================= */
function toVirtual(clientX, clientY){
  const r = canvas.getBoundingClientRect();
  return { x:(clientX-r.left)/r.width*VW, y:(clientY-r.top)/r.height*VH };
}
let lastClickT = 0;
function handleClick(cx, cy){
  if(fade>0.4) return;                 // не кликаем во время перехода
  const now = performance.now();
  if(now - lastClickT < 120) return;   // защита от двойного срабатывания
  lastClickT = now;
  audio();                             // разблокировать звук на первом тапе
  const p = toVirtual(cx, cy);
  for(let i=clickables.length-1;i>=0;i--){
    const b=clickables[i];
    if(p.x>=b.x && p.x<=b.x+b.w && p.y>=b.y && p.y<=b.y+b.h){ b.cb(); return; }
  }
}
// pointerup покрывает мышь, тач и стилус на Android WebView (API 26+)
canvas.addEventListener('pointerup', e=>{ e.preventDefault(); handleClick(e.clientX,e.clientY); }, {passive:false});

})();
