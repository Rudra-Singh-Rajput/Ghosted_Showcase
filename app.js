// Ghosted Web Synchronizer (with Starfield, 3D Tilt, Liquid Lens, Matter.js Badges, and Visual Tweak Bar)
const urlParams = new URLSearchParams(window.location.search);
const serverParam = urlParams.get('server');

let socket;
let isOfflineMode = false;

// Check if socket.io is loaded, otherwise run in Offline Simulation Mode
if (typeof io !== 'undefined') {
    try {
        socket = io(serverParam || undefined);
    } catch (e) {
        console.warn("Socket.io connection failed. Initializing in Offline Simulation Mode.", e);
        isOfflineMode = true;
    }
} else {
    console.warn("Socket.io is not loaded. Initializing in Offline Simulation Mode.");
    isOfflineMode = true;
}

// State
let player;
let roomId = '';
let nickname = '';
let myId = 'spirit_' + Math.floor(Math.random() * 1000);
let isInternalChange = false;
let currentVideoId = 'J---aiyznGQ'; // Default: Ghosted Ambient Vibe
let queue = [];
let myRole = 'spirit';
let activeRooms = [
    { id: 'VOID-7', name: 'CAMPUS CORNER', genre: 'General Chat', pilots: [{ name: '@wraith-8' }, { name: '@phantom-2' }] },
    { id: 'DELTA-9', name: 'LATE NIGHT CODERS', genre: 'Sprints', pilots: [{ name: '@coder-x' }] }
];

// DOM Elements
const landingPage = document.getElementById('landing-page');
const appPage = document.getElementById('app-page');
const reactionsContainer = document.getElementById('reactions-container');
const reactionPanel = document.getElementById('reaction-panel');
const reactionToggle = document.getElementById('reaction-toggle');
const pilotsList = document.getElementById('pilots-list');
const searchResultsOverlay = document.getElementById('search-results-overlay');
const searchResultsList = document.getElementById('search-results-list');
const searchVideoBtn = document.getElementById('search-video-btn');
const copyLinkBtn = document.getElementById('copy-link-btn');

// Inputs
const nicknameInput = document.getElementById('nickname-input');
const roomIdInput = document.getElementById('room-id-input');
const spaceNameInput = document.getElementById('space-name-input');
const spaceGenreInput = document.getElementById('space-genre-input');
const spaceAccessSelect = document.getElementById('space-access-select');
const pinInputContainer = document.getElementById('pin-input-container');
const spacePinInput = document.getElementById('space-pin-input');
const videoUrlInput = document.getElementById('video-url-input');
const chatInput = document.getElementById('chat-input');

// Buttons
const createRoomBtn = document.getElementById('create-room-btn');
const joinRoomBtn = document.getElementById('join-room-btn');
const sendMsgBtn = document.getElementById('send-msg-btn');
const changeVideoBtn = document.getElementById('change-video-btn');
const addQueueBtn = document.getElementById('add-queue-btn');
const themeToggle = document.getElementById('theme-toggle');
const leaveRoomBtn = document.getElementById('leave-room-btn');
const discoverBtn = document.getElementById('discover-btn');

// Overlays & Badges
const currentRoomDisplay = document.getElementById('current-room-display');
const userDisplay = document.getElementById('user-display');
const chatMessages = document.getElementById('chat-messages');
const queueList = document.getElementById('queue-list');
const invitationBadge = document.getElementById('invitation-badge');
const invitationText = document.getElementById('invitation-text');
const discoverOverlay = document.getElementById('discover-overlay');
const closeDiscoverBtn = document.getElementById('close-discover-btn');
const activeRoomsList = document.getElementById('active-rooms-list');
const pinPromptOverlay = document.getElementById('pin-prompt-overlay');
const promptPinInput = document.getElementById('prompt-pin-input');
const pinErrorMsg = document.getElementById('pin-error-msg');
const submitPinBtn = document.getElementById('submit-pin-btn');
const cancelPinBtn = document.getElementById('cancel-pin-btn');
const toastNotification = document.getElementById('toast-notification');
const toastMessage = document.getElementById('toast-message');

// Tab links
const tabJoinLink = document.getElementById('tab-join-link');
const tabCreateLink = document.getElementById('tab-create-link');
const tabJoinContent = document.getElementById('tab-join-content');
const tabCreateContent = document.getElementById('tab-create-content');

// --- THEME MANAGEMENT ---
const savedTheme = localStorage.getItem('ghostedTheme') || 'dark';
if (savedTheme === 'light') {
    document.body.classList.add('light-mode');
    themeToggle.textContent = '☀️';
}

themeToggle.addEventListener('click', () => {
    document.body.classList.toggle('light-mode');
    const isLight = document.body.classList.contains('light-mode');
    themeToggle.textContent = isLight ? '☀️' : '🌙';
    localStorage.setItem('ghostedTheme', isLight ? 'light' : 'dark');
});

// --- TABS CONTROL ---
tabJoinLink.addEventListener('click', () => {
    tabJoinLink.classList.add('active');
    tabCreateLink.classList.remove('active');
    tabJoinContent.classList.add('active');
    tabCreateContent.classList.remove('active');
});

tabCreateLink.addEventListener('click', () => {
    tabCreateLink.classList.add('active');
    tabJoinLink.classList.remove('active');
    tabCreateContent.classList.add('active');
    tabJoinContent.classList.remove('active');
});

// --- INVITES ---
window.addEventListener('load', () => {
    const params = new URLSearchParams(window.location.search);
    const roomParam = params.get('room');
    const nameParam = params.get('name');
    
    if (nameParam) {
        nicknameInput.value = decodeURIComponent(nameParam);
    }
    
    if (roomParam) {
        roomIdInput.value = roomParam.trim().toUpperCase();
        invitationBadge.classList.remove('hidden');
        invitationText.textContent = `🚀 INVITATION DETECTED: ACCESSING ROOM CODE [ ${roomParam} ]`;
    }
});

// --- TOAST NOTIFICATIONS ---
function showToast(message) {
    toastMessage.textContent = message;
    toastNotification.classList.remove('hidden');
    setTimeout(() => {
        toastNotification.classList.add('hidden');
    }, 3000);
}

// --- ACCESS CONTROL GATES ---
spaceAccessSelect.addEventListener('change', (e) => {
    if (e.target.value === 'private') {
        pinInputContainer.classList.remove('hidden');
    } else {
        pinInputContainer.classList.add('hidden');
    }
});

// --- REACTION PANEL ---
reactionToggle.addEventListener('click', () => {
    reactionPanel.classList.toggle('collapsed');
    reactionToggle.textContent = reactionPanel.classList.contains('collapsed') ? '❯' : '❮';
});

document.querySelectorAll('.reaction-btn').forEach(btn => {
    btn.addEventListener('click', () => {
        const emoji = btn.getAttribute('data-emoji');
        sendReaction(emoji);
    });
});

function sendReaction(emoji) {
    if (isOfflineMode) {
        triggerFloatingEmoji(emoji);
    } else if (socket) {
        socket.emit('reaction', { roomId, emoji });
    }
}

function triggerFloatingEmoji(emoji) {
    const container = document.getElementById('reactions-container');
    const el = document.createElement('div');
    el.className = 'floating-emoji';
    el.textContent = emoji;
    
    const leftOffset = Math.random() * 80 + 10;
    el.style.left = `${leftOffset}%`;
    el.style.bottom = '10px';
    
    container.appendChild(el);
    setTimeout(() => el.remove(), 2500);
}

// --- OFFLINE SIMULATION FUNCTIONS ---
function runOfflineModeInit() {
    nickname = nicknameInput.value.trim() || 'Spirit_' + Math.floor(Math.random() * 100);
    landingPage.classList.add('hidden');
    appPage.classList.remove('hidden');
    
    roomId = roomIdInput.value.trim().toUpperCase() || 'DEMO-VOID';
    currentRoomDisplay.textContent = roomId;
    userDisplay.textContent = nickname;

    showToast("CONNECTED IN SIMULATION MODE");
    setupYoutubePlayer(currentVideoId);
    updatePilotsList([{ id: myId, name: nickname, role: 'host' }]);
}

// --- YouTube Player Config ---
function setupYoutubePlayer(videoId) {
    if (player && typeof player.loadVideoById === 'function') {
        player.loadVideoById(videoId);
        return;
    }
    
    player = new YT.Player('player', {
        height: '100%',
        width: '100%',
        videoId: videoId,
        playerVars: {
            'playsinline': 1,
            'controls': 1,
            'autoplay': 1,
            'rel': 0
        },
        events: {
            'onReady': onPlayerReady,
            'onStateChange': onPlayerStateChange
        }
    });
}

function onPlayerReady(event) {
    event.target.playVideo();
}

function onPlayerStateChange(event) {
    if (isOfflineMode) return;
    
    if (!isInternalChange && socket) {
        const state = event.data;
        const time = player.getCurrentTime();
        socket.emit('state-change', { roomId, state, time });
    }
}

// --- BUTTON TRIGGERS ---
joinRoomBtn.addEventListener('click', () => {
    if (isOfflineMode) {
        runOfflineModeInit();
        return;
    }
    
    nickname = nicknameInput.value.trim();
    const targetRoom = roomIdInput.value.trim().toUpperCase();
    if (!nickname || !targetRoom) return alert("Nickname and Target Room ID are required!");

    socket.emit('join-room', { roomId: targetRoom, nickname }, (res) => {
        if (res.status === 'success') {
            roomId = targetRoom;
            landingPage.classList.add('hidden');
            appPage.classList.remove('hidden');
            currentRoomDisplay.textContent = roomId;
            userDisplay.textContent = nickname;
            setupYoutubePlayer(res.videoId || currentVideoId);
        } else if (res.status === 'pin-required') {
            pinPromptOverlay.classList.remove('hidden');
        } else {
            alert(res.message);
        }
    });
});

createRoomBtn.addEventListener('click', () => {
    if (isOfflineMode) {
        runOfflineModeInit();
        return;
    }

    nickname = nicknameInput.value.trim();
    const spaceName = spaceNameInput.value.trim() || 'Void Galaxy';
    const access = spaceAccessSelect.value;
    const pin = spacePinInput.value.trim();

    if (!nickname) return alert("Nickname callsign is required!");

    socket.emit('create-room', { nickname, spaceName, access, pin }, (res) => {
        if (res.status === 'success') {
            roomId = res.roomId;
            landingPage.classList.add('hidden');
            appPage.classList.remove('hidden');
            currentRoomDisplay.textContent = roomId;
            userDisplay.textContent = nickname;
            setupYoutubePlayer(currentVideoId);
        } else {
            alert(res.message);
        }
    });
});

sendMsgBtn.addEventListener('click', sendMsg);
chatInput.addEventListener('keypress', (e) => {
    if (e.key === 'Enter') sendMsg();
});

function sendMsg() {
    const text = chatInput.value.trim();
    if (!text) return;

    if (isOfflineMode) {
        appendMessage(nickname, text, true);
        chatInput.value = '';
        
        setTimeout(() => {
            const replies = [
                "I agree, that fits the vibe perfectly.",
                "Wait, is this video decaying too?",
                "This synchronization is super fluid!",
                "Spectral mode feels amazing."
            ];
            const rand = replies[Math.floor(Math.random() * replies.length)];
            appendMessage("@wraith-8", rand, false);
        }, 1200);
    } else if (socket) {
        socket.emit('chat-message', { roomId, message: text });
        chatInput.value = '';
    }
}

function appendMessage(sender, text, isMe) {
    const bubble = document.createElement('div');
    bubble.className = `message-bubble ${isMe ? 'outgoing' : 'incoming'}`;
    bubble.innerText = text;

    const meta = document.createElement('div');
    meta.className = 'msg-meta';
    meta.innerText = `${sender.toUpperCase()} • JUST NOW`;

    chatMessages.appendChild(bubble);
    chatMessages.appendChild(meta);
    chatMessages.scrollTop = chatMessages.scrollHeight;
}

changeVideoBtn.addEventListener('click', () => {
    const url = videoUrlInput.value.trim();
    if (!url) return;
    
    const match = url.match(/(?:youtube\.com\/(?:[^\/]+\/.+\/|(?:v|e(?:mbed)?)\/|.*[?&]v=)|youtu\.be\/)([^"&?\/ ]{11})/);
    const videoId = match ? match[1] : url;

    if (isOfflineMode) {
        setupYoutubePlayer(videoId);
        videoUrlInput.value = '';
        showToast("PLAYING YOUTUBE VIDEO LINK");
    } else if (socket) {
        socket.emit('change-video', { roomId, videoId });
        videoUrlInput.value = '';
    }
});

searchVideoBtn.addEventListener('click', () => {
    const query = videoUrlInput.value.trim();
    if (!query) return;

    const mockResults = [
        { id: 'J---aiyznGQ', title: 'Ghosted Ambient Lofi Vibe', duration: '3:45', author: 'Lofi Records' },
        { id: 'dQw4w9WgXcQ', title: 'Rick Astley - Never Gonna Give You Up', duration: '3:32', author: 'RickAstleyVEVO' },
        { id: 'kJQP7kiw5Fk', title: 'Luis Fonsi - Despacito ft. Daddy Yankee', duration: '4:41', author: 'LuisFonsiVEVO' }
    ];

    displaySearchResults(mockResults);
});

function displaySearchResults(results) {
    searchResultsList.innerHTML = '';
    results.forEach(res => {
        const item = document.createElement('div');
        item.className = 'search-item';
        item.innerHTML = `
            <img class="search-thumb" src="https://img.youtube.com/vi/${res.id}/mqdefault.jpg">
            <div class="search-info">
                <h5>${res.title}</h5>
                <p>${res.author} • ${res.duration}</p>
            </div>
        `;
        item.addEventListener('click', () => {
            if (isOfflineMode) {
                setupYoutubePlayer(res.id);
                searchResultsOverlay.classList.add('hidden');
                videoUrlInput.value = '';
            } else if (socket) {
                socket.emit('change-video', { roomId, videoId: res.id });
                searchResultsOverlay.classList.add('hidden');
                videoUrlInput.value = '';
            }
        });
        searchResultsList.appendChild(item);
    });
    searchResultsOverlay.classList.remove('hidden');
}

document.addEventListener('click', (e) => {
    if (!searchResultsOverlay.contains(e.target) && e.target !== searchVideoBtn && e.target !== videoUrlInput) {
        searchResultsOverlay.classList.add('hidden');
    }
});

copyLinkBtn.addEventListener('click', () => {
    const link = `${window.location.origin}${window.location.pathname}?room=${roomId}`;
    navigator.clipboard.writeText(link).then(() => {
        showToast("INVITATION LINK COPIED TO CLIPBOARD");
    });
});

leaveRoomBtn.addEventListener('click', () => {
    location.reload();
});

discoverBtn.addEventListener('click', () => {
    activeRoomsList.innerHTML = '';
    activeRooms.forEach(room => {
        const row = document.createElement('div');
        row.className = 'room-card';
        row.innerHTML = `
            <div class="room-card-info">
                <h4>${room.name} (${room.id})</h4>
                <p>GENRE: ${room.genre} • SPIRITS: ${room.pilots.length}</p>
            </div>
            <button class="btn btn-secondary" style="width: auto; padding: 0.5rem 1rem; margin:0;" onclick="joinDirect('${room.id}')">CONNECT</button>
        `;
        activeRoomsList.appendChild(row);
    });
    discoverOverlay.classList.remove('hidden');
});

closeDiscoverBtn.addEventListener('click', () => {
    discoverOverlay.classList.add('hidden');
});

window.joinDirect = function(id) {
    roomIdInput.value = id;
    discoverOverlay.classList.add('hidden');
    joinRoomBtn.click();
};

document.querySelectorAll('.tab-link').forEach(link => {
    link.addEventListener('click', (e) => {
        document.querySelectorAll('.tab-link').forEach(l => l.classList.remove('active'));
        document.querySelectorAll('.tab-content').forEach(c => c.classList.add('hidden'));

        link.classList.add('active');
        const tabId = link.getAttribute('data-tab');
        document.getElementById(`${tabId}-tab`).classList.remove('hidden');
    });
});

function updatePilotsList(pilots) {
    pilotsList.innerHTML = '';
    pilots.forEach(p => {
        const row = document.createElement('div');
        row.className = 'pilot-row';
        row.innerHTML = `
            <span class="pilot-name">${p.name.toUpperCase()}</span>
            <span class="pilot-role">${p.role === 'host' ? 'Host' : 'Viewer'}</span>
        `;
        pilotsList.appendChild(row);
    });
}

// --- 1. INTERACTIVE BACKGROUND STARS ENGINE ---
const canvas = document.getElementById('particles-canvas');
const ctx = canvas.getContext('2d');
let stars = [];
let starsCount = 60;

function resizeCanvas() {
    canvas.width = window.innerWidth;
    canvas.height = window.innerHeight;
}
window.addEventListener('resize', resizeCanvas);
resizeCanvas();

class Star {
    constructor() {
        this.x = Math.random() * canvas.width;
        this.y = Math.random() * canvas.height;
        this.size = Math.random() * 2 + 0.5;
        this.speedX = Math.random() * 0.4 - 0.2;
        this.speedY = Math.random() * 0.4 - 0.2;
    }
    update() {
        this.x += this.speedX;
        this.y += this.speedY;
        if (this.x < 0 || this.x > canvas.width) this.speedX *= -1;
        if (this.y < 0 || this.y > canvas.height) this.speedY *= -1;
    }
    draw() {
        ctx.fillStyle = 'rgba(0, 255, 255, 0.5)';
        ctx.beginPath();
        ctx.arc(this.x, this.y, this.size, 0, Math.PI * 2);
        ctx.fill();
    }
}

function initStars() {
    stars = [];
    for (let i = 0; i < starsCount; i++) {
        stars.push(new Star());
    }
}
initStars();

function animateStars() {
    ctx.clearRect(0, 0, canvas.width, canvas.height);
    stars.forEach((star, index) => {
        star.update();
        star.draw();
        
        for (let j = index + 1; j < stars.length; j++) {
            const other = stars[j];
            const dist = Math.hypot(star.x - other.x, star.y - other.y);
            if (dist < 100) {
                ctx.strokeStyle = `rgba(189, 0, 255, ${0.15 - (dist / 100) * 0.15})`;
                ctx.lineWidth = 0.5;
                ctx.beginPath();
                ctx.moveTo(star.x, star.y);
                ctx.lineTo(other.x, other.y);
                ctx.stroke();
            }
        }
    });
    requestAnimationFrame(animateStars);
}
animateStars();

// --- 2. 3D TILT EFFECT ON CARD ELEMENTS ---
const tiltCard = document.getElementById('3d-hero-card');
const wrapper = document.getElementById('hero-card-wrapper');

if (wrapper && tiltCard) {
    wrapper.addEventListener('mousemove', (e) => {
        const rect = wrapper.getBoundingClientRect();
        const x = e.clientX - rect.left - rect.width / 2;
        const y = e.clientY - rect.top - rect.height / 2;
        
        const rotateX = -(y / rect.height) * 15;
        const rotateY = (x / rect.width) * 15;
        
        tiltCard.style.transform = `rotateX(${rotateX}deg) rotateY(${rotateY}deg) scale(1.01)`;
    });
    
    wrapper.addEventListener('mouseleave', () => {
        tiltCard.style.transform = 'rotateX(0deg) rotateY(0deg) scale(1)';
    });
}

document.querySelectorAll('.3d-tilt-hover').forEach(btn => {
    btn.addEventListener('mousemove', (e) => {
        const rect = btn.getBoundingClientRect();
        const x = e.clientX - rect.left - rect.width / 2;
        const y = e.clientY - rect.top - rect.height / 2;
        btn.style.transform = `scale(1.05) translate(${x*0.1}px, ${y*0.1}px)`;
    });
    btn.addEventListener('mouseleave', () => {
        btn.style.transform = '';
    });
});

// --- 3. MATTER.JS PHYSICS PILLS ---
function initLandingPhysics() {
    const holder = document.getElementById('physics-canvas-holder');
    if (!holder) return;

    holder.innerHTML = ''; // clear

    const width = holder.clientWidth || 800;
    const height = holder.clientHeight || 140;

    const Engine = Matter.Engine,
          Render = Matter.Render,
          Runner = Matter.Runner,
          Bodies = Matter.Bodies,
          Composite = Matter.Composite,
          Mouse = Matter.Mouse,
          MouseConstraint = Matter.MouseConstraint;

    const engine = Engine.create({ gravity: { y: 0.4 } });
    
    const render = Render.create({
        element: holder,
        engine: engine,
        options: {
            width: width,
            height: height,
            background: 'transparent',
            wireframes: false
        }
    });

    Render.run(render);
    const runner = Runner.create();
    Runner.run(runner, engine);

    const ground = Bodies.rectangle(width/2, height + 15, width, 30, { isStatic: true });
    const leftWall = Bodies.rectangle(-15, height/2, 30, height, { isStatic: true });
    const rightWall = Bodies.rectangle(width + 15, height/2, 30, height, { isStatic: true });
    Composite.add(engine.world, [ground, leftWall, rightWall]);

    const tags = ["GHOSTED", "THE VOID", "HAPPY WATCH", "SOULMATCH", "RESONANCE", "ANONYMOUS"];
    const colors = ['#BD00FF', '#00FFFF', '#FF8700', '#FF007F'];

    for (let i = 0; i < tags.length; i++) {
        const x = (width / tags.length) * i + 50;
        const y = Math.random() * -100 - 30;
        const color = colors[i % colors.length];
        const tag = tags[i];

        const pill = Bodies.rectangle(x, y, 110, 32, {
            chamfer: { radius: 16 },
            restitution: 0.6,
            friction: 0.1,
            render: {
                fillStyle: 'rgba(255, 255, 255, 0.02)',
                strokeStyle: color,
                lineWidth: 1.5
            }
        });

        pill.customRender = (context) => {
            context.fillStyle = color;
            context.font = '800 10px Outfit';
            context.textAlign = 'center';
            context.textBaseline = 'middle';
            context.fillText(tag, pill.position.x, pill.position.y);
        };

        Composite.add(engine.world, pill);
    }

    Matter.Events.on(render, 'afterRender', () => {
        const context = render.context;
        const bodies = Composite.allBodies(engine.world);
        bodies.forEach(b => {
            if (b.customRender) b.customRender(context);
        });
    });

    const mouse = Mouse.create(render.canvas);
    const constraint = MouseConstraint.create(engine, {
        mouse: mouse,
        constraint: { stiffness: 0.2, render: { visible: false } }
    });
    Composite.add(engine.world, constraint);
}
window.addEventListener('load', initLandingPhysics);

// --- 4. LIQUID GLASS REFRACTION LENS ---
const playerBox = document.getElementById('player-box-card');
const refractionLens = document.getElementById('refraction-lens');

if (playerBox && refractionLens) {
    playerBox.addEventListener('mousemove', (e) => {
        const rect = playerBox.getBoundingClientRect();
        const x = e.clientX - rect.left;
        const y = e.clientY - rect.top;

        refractionLens.style.display = 'block';
        refractionLens.style.left = `${x}px`;
        refractionLens.style.top = `${y}px`;
    });

    playerBox.addEventListener('mouseleave', () => {
        refractionLens.style.display = 'none';
    });
}

// --- 5. VISUAL TWEAK BAR EVENTS & LOGIC ---
const tweakBar = document.getElementById('tweak-bar');
const tweakBarToggle = document.getElementById('tweak-bar-toggle');

tweakBarToggle.addEventListener('click', () => {
    tweakBar.classList.toggle('collapsed');
});

// Preset Taste Configs
const presets = {
    ghosted: {
        primary: '#BD00FF',
        accent: '#FF8700',
        cyan: '#00FFFF',
        bg: '#050508'
    },
    cyber: {
        primary: '#FF007F',
        accent: '#00FFFF',
        cyan: '#FFFF00',
        bg: '#0a000a'
    },
    matrix: {
        primary: '#00FF00',
        accent: '#008000',
        cyan: '#00FF66',
        bg: '#000800'
    },
    mono: {
        primary: '#FFFFFF',
        accent: '#888888',
        cyan: '#CCCCCC',
        bg: '#0f0f0f'
    }
};

window.setPreset = function(name) {
    document.querySelectorAll('.preset-btn').forEach(btn => {
        btn.classList.remove('active');
        if (btn.getAttribute('onclick').includes(name)) btn.classList.add('active');
    });

    const p = presets[name];
    if (p) {
        document.documentElement.style.setProperty('--primary', p.primary);
        document.documentElement.style.setProperty('--accent', p.accent);
        document.documentElement.style.setProperty('--cyan', p.cyan);
        document.documentElement.style.setProperty('--bg', p.bg);
        showToast(`LOADED ${name.toUpperCase()} PRESET`);
    }
};

window.updateTweakFont = function(fontFamily) {
    document.body.style.fontFamily = fontFamily;
};

window.updateGlow = function(val) {
    document.getElementById('tweak-glow-val').innerText = val + 'px';
    document.documentElement.style.setProperty('--primary-glow', `rgba(189, 0, 255, ${val/100})`);
    document.documentElement.style.setProperty('--cyan-glow', `rgba(0, 255, 255, ${val/100})`);
};

window.updateBlur = function(val) {
    document.getElementById('tweak-blur-val').innerText = val + 'px';
    document.documentElement.style.setProperty('--backdrop-blur', val + 'px');
};

window.updateRadius = function(val) {
    document.getElementById('tweak-radius-val').innerText = val + 'px';
    document.documentElement.style.setProperty('--border-radius', val + 'px');
};

window.updateStarsCount = function(val) {
    document.getElementById('tweak-stars-val').innerText = val;
    starsCount = parseInt(val);
    initStars();
};

// --- SOCKET EVENTS ---
if (socket) {
    socket.on('room-update', (data) => {
        updatePilotsList(data.pilots);
    });
    socket.on('state-change', (data) => {
        if (!player) return;
        isInternalChange = true;
        const myTime = player.getCurrentTime();
        if (Math.abs(myTime - data.time) > 1.5) {
            player.seekTo(data.time, true);
        }
        if (data.state === YT.PlayerState.PLAYING) {
            player.playVideo();
        } else if (data.state === YT.PlayerState.PAUSED) {
            player.pauseVideo();
        }
        isInternalChange = false;
    });
    socket.on('chat-message', (data) => {
        appendMessage(data.sender, data.message, data.sender === nickname);
    });
    socket.on('reaction', (data) => {
        triggerFloatingEmoji(data.emoji);
    });
    socket.on('change-video', (data) => {
        setupYoutubePlayer(data.videoId);
        showToast("SYNCED NEW VIDEO IN SPACE");
    });
}
