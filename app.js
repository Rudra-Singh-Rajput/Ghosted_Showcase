// =========================================================
// GHOSTED SHOWCASE & SIMULATOR JAVASCRIPT
// Handles: Theme Engine, Simulator Mechanics, Canvas Starfield, Matter.js Arena
// =========================================================

// --- 1. THEME ENGINE ---
let currentTheme = 'ghosted';

const themeConfigs = {
  ghosted: {
    name: 'Ghosted (Warm Ember)',
    primary: '#FF8700',
    secondary: '#BD00FF',
    primaryRgb: '255, 135, 0',
    dotClass: 'dot-ghosted'
  },
  cosmic: {
    name: 'Cosmic (Nebula Purple)',
    primary: '#BD00FF',
    secondary: '#00F3FF',
    primaryRgb: '189, 0, 255',
    dotClass: 'dot-cosmic'
  },
  aurora: {
    name: 'Aurora (Emerald Teal)',
    primary: '#00FFCC',
    secondary: '#0088FF',
    primaryRgb: '0, 255, 204',
    dotClass: 'dot-aurora'
  },
  comic: {
    name: 'Comic (Graphic Halftone)',
    primary: '#FFDE59',
    secondary: '#FF5757',
    primaryRgb: '255, 222, 89',
    dotClass: 'dot-comic'
  }
};

const themeBtn = document.getElementById('theme-btn');
const themeMenu = document.getElementById('theme-menu');

if (themeBtn && themeMenu) {
  themeBtn.addEventListener('click', (e) => {
    e.stopPropagation();
    themeMenu.classList.toggle('show');
  });

  document.addEventListener('click', () => {
    themeMenu.classList.remove('show');
  });
}

function setTheme(name) {
  if (!themeConfigs[name]) return;
  currentTheme = name;
  document.body.className = `theme-${name}`;

  const config = themeConfigs[name];
  const nameEl = document.querySelector('.theme-name');
  if (nameEl) nameEl.textContent = config.name;

  const dotEl = document.querySelector('.theme-color-dot');
  if (dotEl) {
    dotEl.style.background = config.primary;
    dotEl.style.boxShadow = `0 0 8px ${config.primary}`;
  }

  document.querySelectorAll('.theme-opt').forEach(opt => {
    if (opt.getAttribute('onclick').includes(name)) {
      opt.classList.add('active');
    } else {
      opt.classList.remove('active');
    }
  });

  if (themeMenu) themeMenu.classList.remove('show');
  updatePhysicsColors();
}

// --- 2. STARFIELD & PARTICLE BACKGROUND CANVAS ---
const fluidCanvas = document.getElementById('fluid-canvas');
const fluidCtx = fluidCanvas.getContext('2d');
let stars = [];
const maxStars = 75;

function resizeFluidCanvas() {
  fluidCanvas.width = window.innerWidth;
  fluidCanvas.height = window.innerHeight;
}
window.addEventListener('resize', resizeFluidCanvas);
resizeFluidCanvas();

class StarParticle {
  constructor() {
    this.reset();
    this.y = Math.random() * fluidCanvas.height;
  }
  reset() {
    this.x = Math.random() * fluidCanvas.width;
    this.y = fluidCanvas.height + 15;
    this.size = Math.random() * 2.4 + 0.6;
    this.speedY = Math.random() * 0.45 + 0.15;
    this.amplitude = Math.random() * 1.8 + 0.4;
    this.frequency = Math.random() * 0.005 + 0.001;
    this.phase = Math.random() * 100;
    this.alpha = Math.random() * 0.6 + 0.2;
  }
  update() {
    this.y -= this.speedY;
    this.phase += this.frequency;
    this.x += Math.sin(this.phase) * this.amplitude * 0.3;
    if (this.y < -15) this.reset();
  }
  draw() {
    fluidCtx.fillStyle = `rgba(255, 255, 255, ${this.alpha})`;
    fluidCtx.beginPath();
    fluidCtx.arc(this.x, this.y, this.size, 0, Math.PI * 2);
    fluidCtx.fill();
  }
}

for (let i = 0; i < maxStars; i++) {
  stars.push(new StarParticle());
}

function animateFluidBackground() {
  fluidCtx.clearRect(0, 0, fluidCanvas.width, fluidCanvas.height);
  
  for (let i = 0; i < stars.length; i++) {
    stars[i].update();
    stars[i].draw();

    for (let j = i + 1; j < stars.length; j++) {
      const dist = Math.hypot(stars[i].x - stars[j].x, stars[i].y - stars[j].y);
      if (dist < 110) {
        const alpha = (1 - dist / 110) * 0.12;
        const config = themeConfigs[currentTheme];
        const grad = fluidCtx.createLinearGradient(stars[i].x, stars[i].y, stars[j].x, stars[j].y);
        grad.addColorStop(0, `rgba(${config.primaryRgb}, ${alpha})`);
        grad.addColorStop(1, `rgba(255, 255, 255, ${alpha * 0.5})`);
        
        fluidCtx.strokeStyle = grad;
        fluidCtx.lineWidth = 0.7;
        fluidCtx.beginPath();
        fluidCtx.moveTo(stars[i].x, stars[i].y);
        fluidCtx.lineTo(stars[j].x, stars[j].y);
        fluidCtx.stroke();
      }
    }
  }
  requestAnimationFrame(animateFluidBackground);
}
animateFluidBackground();

// --- 3. INTERACTIVE SPARK BURST ENGINE ---
const sparkCanvas = document.getElementById('spark-canvas');
const sparkCtx = sparkCanvas.getContext('2d');
let sparks = [];

function resizeSparkCanvas() {
  sparkCanvas.width = window.innerWidth;
  sparkCanvas.height = window.innerHeight;
}
window.addEventListener('resize', resizeSparkCanvas);
resizeSparkCanvas();

class Spark {
  constructor(x, y) {
    this.x = x;
    this.y = y;
    this.size = Math.random() * 3 + 1.5;
    this.speedX = Math.random() * 7 - 3.5;
    this.speedY = Math.random() * -7 - 2;
    this.gravity = 0.14;
    const config = themeConfigs[currentTheme];
    this.color = Math.random() > 0.4 ? config.primary : config.secondary;
    this.alpha = 1.0;
    this.decay = Math.random() * 0.02 + 0.012;
  }
  update() {
    this.x += this.speedX;
    this.y += this.speedY;
    this.speedY += this.gravity;
    this.alpha -= this.decay;
  }
  draw() {
    sparkCtx.save();
    sparkCtx.globalAlpha = Math.max(0, this.alpha);
    sparkCtx.fillStyle = this.color;
    sparkCtx.shadowColor = this.color;
    sparkCtx.shadowBlur = 10;
    sparkCtx.beginPath();
    sparkCtx.arc(this.x, this.y, this.size, 0, Math.PI * 2);
    sparkCtx.fill();
    sparkCtx.restore();
  }
}

function spawnBurst(x, y, count = 25) {
  for (let i = 0; i < count; i++) {
    sparks.push(new Spark(x, y));
  }
}

function animateSparks() {
  sparkCtx.clearRect(0, 0, sparkCanvas.width, sparkCanvas.height);
  sparks = sparks.filter(s => s.alpha > 0);
  for (let s of sparks) {
    s.update();
    s.draw();
  }
  requestAnimationFrame(animateSparks);
}
animateSparks();

// --- 4. SMARTPHONE SIMULATOR LOGIC ---
const hints = {
  feed: "Whispers gradually blur and vaporize as their 24h decay countdown elapses. Tap 'Echo' or vote on locked payoffs to test.",
  seance: "Accessible on mobile by tapping the Ghost icon. An encrypted altar where confessions are sealed in digital wax.",
  chat: "Vapor Bubbles dissolve automatically. Tap the View-Once message to see the 5-second self-destruct timer in action!",
  watch: "Happy Watch allows dorms to watch YouTube videos in frame-accurate sync. Click reactions to float emojis across the room.",
  yearbook: "Student spirit profiles with department tags and resonance XP tiers. Level up from Phantom to Void Sovereign."
};

function setSimulatorTab(tabId) {
  // Update sidebar controller buttons
  document.querySelectorAll('.sim-nav-btn').forEach(btn => {
    if (btn.getAttribute('onclick').includes(tabId)) {
      btn.classList.add('active');
    } else {
      btn.classList.remove('active');
    }
  });

  // Update phone bottom nav buttons
  document.querySelectorAll('.phone-nav-item').forEach(item => {
    if (item.getAttribute('onclick').includes(tabId)) {
      item.classList.add('active');
    } else {
      item.classList.remove('active');
    }
  });

  // Switch phone panes
  document.querySelectorAll('.phone-tab-pane').forEach(pane => {
    pane.classList.remove('active');
  });
  const targetPane = document.getElementById(`pane-${tabId}`);
  if (targetPane) targetPane.classList.add('active');

  // Update explanation hint
  const noteEl = document.getElementById('sim-feature-note');
  if (noteEl && hints[tabId]) {
    noteEl.textContent = hints[tabId];
  }
}

// SIMULATOR MICRO-INTERACTIONS
function simEcho(btn, event) {
  const countEl = btn.querySelector('.count');
  let current = parseInt(countEl.textContent);
  countEl.textContent = current + 1;
  btn.style.color = themeConfigs[currentTheme].primary;
  
  const rect = btn.getBoundingClientRect();
  spawnBurst(rect.left + rect.width / 2, rect.top + rect.height / 2, 20);
}

function simComment(btn) {
  alert("💬 Comment Thread: Tap into anonymous replies. In the production app, users could comment without exposing any user handle!");
}

function simShare(event) {
  spawnBurst(event.clientX, event.clientY, 15);
  alert("🔗 Whisper link copied to clipboard!");
}

// Locked Payoff Mechanism
let payoffVotes = 46;
const payoffGoal = 50;

function votePayoff() {
  if (payoffVotes < payoffGoal) {
    payoffVotes++;
    document.getElementById('payoff-counter').textContent = `${payoffVotes} / ${payoffGoal}`;
    const percent = (payoffVotes / payoffGoal) * 100;
    document.getElementById('demo-payoff-bar').style.width = `${percent}%`;

    if (payoffVotes >= payoffGoal) {
      document.getElementById('demo-payoff-box').innerHTML = `
        <div style="padding:10px; background:rgba(39, 201, 63, 0.15); border:1px solid #27C93F; border-radius:10px; text-align:center;">
          <h5 style="color:#27C93F; font-size:0.85rem; margin-bottom:4px;">🔓 PAYOFF UNLOCKED!</h5>
          <p style="font-size:0.75rem; color:#DDD;">"It was 3 professors celebrating getting their research grant approved! 🍕🎓"</p>
        </div>
      `;
    }
  }
}

// View-Once Photo Self-Destruct Mechanic
let viewOnceRevealed = false;
function revealViewOncePhoto() {
  if (viewOnceRevealed) return;
  viewOnceRevealed = true;

  const msg = document.getElementById('demo-view-once');
  const status = document.getElementById('view-once-status');
  
  msg.innerHTML = `
    <div style="padding: 10px; background: rgba(0,0,0,0.7); border-radius: 10px; text-align:center;">
      <div style="font-size: 2rem; margin-bottom: 4px;">🖼️</div>
      <p style="font-size: 0.75rem; color:#FFF; font-weight:700;">Secret Midterm Notes Photo</p>
      <span id="destruct-countdown" style="font-size:0.7rem; color:#FF5555; font-weight:bold;">🔥 Destructing in 5s...</span>
    </div>
  `;

  let seconds = 5;
  const timer = setInterval(() => {
    seconds--;
    const countdownEl = document.getElementById('destruct-countdown');
    if (countdownEl) {
      countdownEl.textContent = `🔥 Destructing in ${seconds}s...`;
    }
    if (seconds <= 0) {
      clearInterval(timer);
      msg.innerHTML = `
        <div style="padding: 10px; text-align:center; color:#777; font-size:0.75rem;">
          <span>💨 Message vaporized into ash.</span>
        </div>
      `;
      msg.style.opacity = '0.5';
      msg.style.pointerEvents = 'none';
    }
  }, 1000);
}

// Chat Mock Send
function sendMockMessage() {
  const input = document.getElementById('chat-input-box');
  const text = input.value.trim();
  if (!text) return;

  const stream = document.getElementById('chat-stream');
  
  // User bubble
  const userBubble = document.createElement('div');
  userBubble.className = 'msg-bubble outgoing';
  userBubble.innerHTML = `<p>${text}</p><small>Just now</small>`;
  stream.appendChild(userBubble);
  input.value = '';
  stream.scrollTop = stream.scrollHeight;

  // Bot auto-reply after 1 second
  setTimeout(() => {
    const replies = [
      "Agreed, let's meet near the library atrium.",
      "That whisper on the Ghost Board earlier was hilarious.",
      "Did you check Happy Watch room #145 tonight?",
      "Catch you later in the void!"
    ];
    const replyText = replies[Math.floor(Math.random() * replies.length)];
    const replyBubble = document.createElement('div');
    replyBubble.className = 'msg-bubble incoming';
    replyBubble.innerHTML = `<p>${replyText}</p><small>Just now</small>`;
    stream.appendChild(replyBubble);
    stream.scrollTop = stream.scrollHeight;
  }, 900);
}

// Happy Watch Floating Reactions
function spawnWatchReaction(emoji) {
  const container = document.querySelector('.watch-video-container');
  if (!container) return;

  const el = document.createElement('div');
  el.textContent = emoji;
  el.style.position = 'absolute';
  el.style.bottom = '15px';
  el.style.left = `${Math.random() * 80 + 10}%`;
  el.style.fontSize = '1.8rem';
  el.style.pointerEvents = 'none';
  el.style.zIndex = '30';
  el.style.transition = 'all 1.8s cubic-bezier(0.2, 0.8, 0.4, 1)';
  el.style.opacity = '1';

  container.appendChild(el);

  setTimeout(() => {
    el.style.transform = `translateY(-110px) scale(${Math.random() * 0.4 + 1.1})`;
    el.style.opacity = '0';
  }, 20);

  setTimeout(() => {
    el.remove();
  }, 1800);
}

// Story Modal
function triggerStoryModal() {
  const modal = document.getElementById('story-modal');
  if (modal) modal.classList.add('show');
}

function closeStoryModal(e) {
  const modal = document.getElementById('story-modal');
  if (modal) modal.classList.remove('show');
}

function openConfessionModal() {
  alert("🕯️ The Sacred Confession Altar: In Ghosted, students could type any thought, pick a mood stamp (#crush, #exams, #faculty), and melt a digital wax seal before whispering it to campus.");
}

// --- 5. MATTER.JS PHYSICS PILLS ARENA ---
let physicsEngine = null;
let physicsRunner = null;
let physicsBodies = [];

function initPhysicsArena() {
  const container = document.getElementById('physics-canvas-container');
  if (!container || physicsEngine) return;

  const width = container.clientWidth || 800;
  const height = container.clientHeight || 440;

  const Engine = Matter.Engine,
        Render = Matter.Render,
        Runner = Matter.Runner,
        Bodies = Matter.Bodies,
        Composite = Matter.Composite,
        Mouse = Matter.Mouse,
        MouseConstraint = Matter.MouseConstraint;

  physicsEngine = Engine.create({ gravity: { y: 0.7 } });

  const render = Render.create({
    element: container,
    engine: physicsEngine,
    options: {
      width: width,
      height: height,
      background: 'transparent',
      wireframes: false,
      showVelocity: false
    }
  });

  Render.run(render);
  physicsRunner = Runner.create();
  Runner.run(physicsRunner, physicsEngine);

  // Boundaries
  const ground = Bodies.rectangle(width / 2, height + 25, width, 50, { isStatic: true });
  const leftWall = Bodies.rectangle(-25, height / 2, 50, height, { isStatic: true });
  const rightWall = Bodies.rectangle(width + 25, height / 2, 50, height, { isStatic: true });
  Composite.add(physicsEngine.world, [ground, leftWall, rightWall]);

  // Pill Labels
  const tagLabels = [
    "#ADANI_UNI", "#GHOSTED", "#SEANCE", "#HAPPY_WATCH",
    "#ICT_MIDTERMS", "#VOID_SOVEREIGN", "#RESONANCE_XP",
    "#LIBRARY_3RD_FLOOR", "#WAX_SEAL", "#CONFESSIONS",
    "#VAPOR_BUBBLE", "#HOSTEL_NIGHTS", "#CAMPUS_VOICE"
  ];

  tagLabels.forEach((label, i) => {
    const x = Math.random() * (width - 180) + 90;
    const y = -50 - (i * 35);
    const pill = Bodies.rectangle(x, y, 140, 42, {
      chamfer: { radius: 21 },
      restitution: 0.65,
      friction: 0.1,
      render: {
        fillStyle: 'rgba(255, 255, 255, 0.04)',
        strokeStyle: themeConfigs[currentTheme].primary,
        lineWidth: 2
      }
    });
    pill.tagLabel = label;
    physicsBodies.push(pill);
    Composite.add(physicsEngine.world, pill);
  });

  // Render text on bodies
  Matter.Events.on(render, 'afterRender', () => {
    const ctx = render.context;
    ctx.font = 'bold 12px Outfit, sans-serif';
    ctx.textAlign = 'center';
    ctx.textBaseline = 'middle';
    ctx.fillStyle = '#FFFFFF';

    physicsBodies.forEach(body => {
      if (body.tagLabel) {
        ctx.save();
        ctx.translate(body.position.x, body.position.y);
        ctx.rotate(body.angle);
        ctx.fillText(body.tagLabel, 0, 0);
        ctx.restore();
      }
    });
  });

  // Mouse Drag Constraint
  const mouse = Mouse.create(render.canvas);
  const mouseConstraint = MouseConstraint.create(physicsEngine, {
    mouse: mouse,
    constraint: {
      stiffness: 0.25,
      render: { visible: false }
    }
  });
  Composite.add(physicsEngine.world, mouseConstraint);
  render.mouse = mouse;

  // Click to spawn
  container.addEventListener('click', (e) => {
    const rect = container.getBoundingClientRect();
    const x = e.clientX - rect.left;
    const y = e.clientY - rect.top;
    
    // Spawn if not clicking a body
    const extraPill = Bodies.rectangle(x, y, 120, 38, {
      chamfer: { radius: 19 },
      restitution: 0.7,
      render: {
        fillStyle: 'rgba(255, 255, 255, 0.06)',
        strokeStyle: themeConfigs[currentTheme].secondary,
        lineWidth: 2
      }
    });
    extraPill.tagLabel = "#WHISPER";
    physicsBodies.push(extraPill);
    Composite.add(physicsEngine.world, extraPill);
    spawnBurst(e.clientX, e.clientY, 15);
  });
}

function updatePhysicsColors() {
  if (!physicsBodies.length) return;
  const config = themeConfigs[currentTheme];
  physicsBodies.forEach((body, idx) => {
    body.render.strokeStyle = idx % 2 === 0 ? config.primary : config.secondary;
  });
}

function resetPhysicsArena() {
  const container = document.getElementById('physics-canvas-container');
  if (container) {
    container.innerHTML = '';
    physicsEngine = null;
    physicsRunner = null;
    physicsBodies = [];
    initPhysicsArena();
  }
}

// Initialize Physics Arena when scrolled near
window.addEventListener('load', () => {
  initPhysicsArena();
});
