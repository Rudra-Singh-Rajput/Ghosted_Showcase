// =========================================================
// GHOSTED SHOWCASE — INTERACTIVE PHONE SIMULATOR
// Minimal, clean, lightweight logic without external dependencies
// =========================================================

const tabDescriptions = {
  feed: "Whispers naturally fade over 24 hours to keep the board temporary. Tap 'Echo' to upvote or vote on the locked post to test.",
  confessions: "Hauwa Confession Board: Students shared honest campus thoughts, exam anxieties, or hostel moments categorized by tags.",
  chat: "Ephemeral Chat: All messages had a 24-hour TTL. Tap the View-Once message to see the 5-second self-destruct timer in action.",
  watch: "Happy Watch: A synchronized video room where friends could watch videos together in sync with live chat and emoji reactions.",
  yearbook: "Campus Yearbook: Anonymized student spirit profiles categorized by university department with daily active streaks."
};

function switchPhoneTab(tabId) {
  // Update sidebar selector buttons
  document.querySelectorAll('.selector-btn').forEach(btn => {
    if (btn.getAttribute('onclick') && btn.getAttribute('onclick').includes(tabId)) {
      btn.classList.add('active');
    } else {
      btn.classList.remove('active');
    }
  });

  // Update phone bottom nav buttons
  document.querySelectorAll('.phone-nav-btn').forEach(btn => {
    if (btn.getAttribute('onclick') && btn.getAttribute('onclick').includes(tabId)) {
      btn.classList.add('active');
    } else {
      btn.classList.remove('active');
    }
  });

  // Switch active phone screen
  document.querySelectorAll('.phone-screen').forEach(screen => {
    screen.classList.remove('active');
  });

  const targetScreen = document.getElementById(`screen-${tabId}`);
  if (targetScreen) {
    targetScreen.classList.add('active');
  }

  // Update description text
  const descEl = document.getElementById('feature-description');
  if (descEl && tabDescriptions[tabId]) {
    descEl.textContent = tabDescriptions[tabId];
  }
}

// 1. Echo interaction
function mockEcho(btn) {
  const countEl = btn.querySelector('.echo-count');
  if (countEl) {
    let current = parseInt(countEl.textContent, 10);
    countEl.textContent = current + 1;
    btn.style.color = '#FF8700';
  }
}

function mockComment() {
  alert("💬 Comment Thread: In the real app, classmates could reply anonymously to any whisper without revealing their identity.");
}

// 2. Locked Poll / Secret Payoff
let pollVotes = 48;
const pollGoal = 50;

function mockVote() {
  if (pollVotes < pollGoal) {
    pollVotes++;
    const countEl = document.getElementById('vote-count');
    const fillEl = document.getElementById('poll-fill');
    const btn = document.getElementById('vote-btn');

    if (countEl) countEl.textContent = `${pollVotes} / ${pollGoal}`;
    if (fillEl) fillEl.style.width = `${(pollVotes / pollGoal) * 100}%`;

    if (pollVotes >= pollGoal) {
      const pollBox = document.querySelector('.poll-box');
      if (pollBox) {
        pollBox.innerHTML = `
          <div style="padding: 8px; background: rgba(39, 201, 63, 0.15); border: 1px solid #27C93F; border-radius: 6px; text-align: center;">
            <strong style="color: #27C93F; font-size: 0.75rem; display: block;">🔓 Secret Unlocked!</strong>
            <p style="font-size: 0.72rem; color: #DDD; margin-top: 2px;">"Three professors ordered 30 pizzas to celebrate a research grant! 🍕"</p>
          </div>
        `;
      }
    }
  }
}

// 3. Confession alert
function mockConfessAlert() {
  alert("🕯️ Hauwa Board: Students could submit honest confessions with category tags (#Exams, #Hostel, #Crush) and lit candles replaced public likes.");
}

// 4. View-Once Self-Destruct
let viewOnceTriggered = false;
function mockViewOnce() {
  if (viewOnceTriggered) return;
  viewOnceTriggered = true;

  const box = document.getElementById('view-once-box');
  if (!box) return;

  box.innerHTML = `
    <div style="padding: 10px; background: rgba(0,0,0,0.6); border-radius: 8px; text-align: center;">
      <span style="font-size: 1.5rem; display: block; margin-bottom: 4px;">📸</span>
      <strong style="font-size: 0.75rem; color: #FFF; display: block;">Exam Study Notes Photo</strong>
      <span id="countdown-timer" style="font-size: 0.7rem; color: #FF5555; font-weight: bold;">Self-destructing in 5s...</span>
    </div>
  `;

  let timeLeft = 5;
  const timer = setInterval(() => {
    timeLeft--;
    const timerEl = document.getElementById('countdown-timer');
    if (timerEl) {
      timerEl.textContent = `Self-destructing in ${timeLeft}s...`;
    }

    if (timeLeft <= 0) {
      clearInterval(timer);
      box.innerHTML = `
        <div style="padding: 8px; text-align: center; color: #666; font-size: 0.72rem;">
          <span>💨 Photo deleted permanently.</span>
        </div>
      `;
      box.style.opacity = '0.5';
      box.style.pointerEvents = 'none';
    }
  }, 1000);
}

// 5. Chat Send & Auto-Reply
function mockSendChat() {
  const input = document.getElementById('chat-box');
  const stream = document.getElementById('chat-stream');
  if (!input || !stream) return;

  const text = input.value.trim();
  if (!text) return;

  // Add outgoing bubble
  const outBubble = document.createElement('div');
  outBubble.className = 'chat-bubble outgoing';
  outBubble.innerHTML = `<p>${escapeHtml(text)}</p><small>Just now</small>`;
  stream.appendChild(outBubble);
  input.value = '';

  const chatContainer = document.querySelector('.chat-content');
  if (chatContainer) chatContainer.scrollTop = chatContainer.scrollHeight;

  // Auto-reply after 800ms
  setTimeout(() => {
    const replies = [
      "Got it! See you in the library.",
      "Check the Happy Watch room tonight, we're watching the tech keynote.",
      "Totally agree with you.",
      "Catch you later!"
    ];
    const replyText = replies[Math.floor(Math.random() * replies.length)];
    const inBubble = document.createElement('div');
    inBubble.className = 'chat-bubble incoming';
    inBubble.innerHTML = `<p>${replyText}</p><small>Just now</small>`;
    stream.appendChild(inBubble);
    if (chatContainer) chatContainer.scrollTop = chatContainer.scrollHeight;
  }, 800);
}

// 6. Floating Video Reactions
function mockReaction(emoji) {
  const container = document.querySelector('.video-mock');
  if (!container) return;

  const el = document.createElement('div');
  el.textContent = emoji;
  el.style.position = 'absolute';
  el.style.bottom = '15px';
  el.style.left = `${Math.random() * 70 + 15}%`;
  el.style.fontSize = '1.4rem';
  el.style.pointerEvents = 'none';
  el.style.zIndex = '20';
  el.style.transition = 'all 1.4s cubic-bezier(0.2, 0.8, 0.4, 1)';
  el.style.opacity = '1';

  container.appendChild(el);

  setTimeout(() => {
    el.style.transform = 'translateY(-70px) scale(1.2)';
    el.style.opacity = '0';
  }, 20);

  setTimeout(() => {
    el.remove();
  }, 1400);
}

function escapeHtml(text) {
  const div = document.createElement('div');
  div.textContent = text;
  return div.innerHTML;
}
