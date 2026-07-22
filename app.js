// Ghosted Experimental High-Impact 3D UI Showcase Engine

// --- SECTION 1: 3D ASCII TORUS KNOT MATH RENDERER (Terminal Style) ---
const asciiContainer = document.getElementById('ascii-canvas-container');
const preElement = document.createElement('pre');
preElement.className = 'ascii-pre';
asciiContainer.appendChild(preElement);

let asciiA = 0;
let asciiB = 0;
let asciiMouseX = 0;
let asciiMouseY = 0;

// Track cursor movement on ascii card to rotate the torus
document.getElementById('ascii-showcase').addEventListener('mousemove', (e) => {
    const rect = e.currentTarget.getBoundingClientRect();
    asciiMouseX = ((e.clientX - rect.left) / rect.width) * 4 - 2;
    asciiMouseY = ((e.clientY - rect.top) / rect.height) * 4 - 2;
});

function renderAsciiFrame() {
    const width = 60;
    const height = 24;
    const buffer = Array(width * height).fill(" ");
    const zBuffer = Array(width * height).fill(0);

    // Torus knot mathematical geometry calculations
    // R1 = major radius, R2 = minor radius
    const R1 = 1.3;
    const R2 = 0.5;

    // Shift angles over time and cursor values
    asciiA += 0.02 + (asciiMouseX * 0.01);
    asciiB += 0.01 + (asciiMouseY * 0.01);

    const cosA = Math.cos(asciiA);
    const sinA = Math.sin(asciiA);
    const cosB = Math.cos(asciiB);
    const sinB = Math.sin(asciiB);

    for (let theta = 0; theta < 2 * Math.PI; theta += 0.07) {
        const cosTheta = Math.cos(theta);
        const sinTheta = Math.sin(theta);

        for (let phi = 0; phi < 2 * Math.PI; phi += 0.02) {
            const cosPhi = Math.cos(phi);
            const sinPhi = Math.sin(phi);

            // Compute torus coordinates
            const circleX = R1 + R2 * cosTheta;
            const circleY = R2 * sinTheta;

            // 3D rotations
            const x = circleX * (cosB * cosPhi + sinA * sinB * sinPhi) - circleY * cosA * sinB;
            const y = circleX * (sinB * cosPhi - sinA * cosB * sinPhi) + circleY * cosA * cosB;
            const z = cosA * circleX * sinPhi + circleY * sinA;
            const ooz = 1 / (z + 4); // one over z

            // Screen projection coordinates
            const xp = Math.floor(width / 2 + 30 * ooz * x * 1.5);
            const yp = Math.floor(height / 2 + 15 * ooz * y);

            if (xp >= 0 && xp < width && yp >= 0 && yp < height) {
                const idx = xp + yp * width;
                // Luminance/brightness computation for character mapping
                const L = cosPhi * cosTheta * sinB - cosA * cosTheta * sinPhi - sinA * sinTheta + cosB * (cosA * sinTheta - sinA * cosTheta * sinPhi);
                
                if (ooz > zBuffer[idx]) {
                    zBuffer[idx] = ooz;
                    const charIndex = Math.floor(Math.max(0, L) * 8);
                    const chars = ".,-~:;=!*#$@";
                    buffer[idx] = chars[charIndex] || " ";
                }
            }
        }
    }

    // Convert flat buffer array to multiline text string
    let output = "";
    for (let k = 0; k < width * height; k++) {
        output += buffer[k];
        if (k % width === width - 1) output += "\n";
    }
    preElement.textContent = output;
    requestAnimationFrame(renderAsciiFrame);
}
renderAsciiFrame();


// --- SECTION 2: MATTER.JS INTERACTIVE 2D PHYSICS SYSTEM ---
const physicsContainer = document.getElementById('physics-canvas-container');
const Engine = Matter.Engine,
      Render = Matter.Render,
      Runner = Matter.Runner,
      Bodies = Matter.Bodies,
      Composite = Matter.Composite,
      Mouse = Matter.Mouse,
      MouseConstraint = Matter.MouseConstraint;

// Create Matter engine
const engine = Engine.create({ gravity: { y: 0.8 } });
const world = engine.world;

// Create Renderer
const renderWidth = physicsContainer.clientWidth || 440;
const renderHeight = 280;

const render = Render.create({
    element: physicsContainer,
    engine: engine,
    options: {
        width: renderWidth,
        height: renderHeight,
        background: 'transparent',
        wireframes: false,
        showAngleIndicator: false
    }
});
Render.run(render);

// Create runner
const runner = Runner.create();
Runner.run(runner, engine);

// Add boundary walls
const wallOptions = { isStatic: true, render: { visible: false } };
const floor = Bodies.rectangle(renderWidth / 2, renderHeight + 10, renderWidth + 100, 20, wallOptions);
const leftWall = Bodies.rectangle(-10, renderHeight / 2, 20, renderHeight + 100, wallOptions);
const rightWall = Bodies.rectangle(renderWidth + 10, renderHeight / 2, 20, renderHeight + 100, wallOptions);
const ceiling = Bodies.rectangle(renderWidth / 2, -10, renderWidth + 100, 20, wallOptions);
Composite.add(world, [floor, leftWall, rightWall, ceiling]);

// Callsign pill labels mapping
const pillData = [
    { text: "@spectre", color: "#BD00FF" },
    { text: "@seer-88", color: "#FF8700" },
    { text: "@wraith", color: "#00FFFF" },
    { text: "Level 12", color: "#FF8700" },
    { text: "@phantom", color: "#BD00FF" },
    { text: "VOID", color: "#00FFFF" }
];

// Spawn dynamic pills with collision bodies
pillData.forEach((pill, idx) => {
    const x = Math.random() * (renderWidth - 100) + 50;
    const y = Math.random() * 100 + 30;
    
    // Create box body
    const pBody = Bodies.rectangle(x, y, 90, 36, {
        chamfer: { radius: 18 },
        restitution: 0.7,
        friction: 0.05,
        render: {
            fillStyle: 'rgba(20, 20, 25, 0.85)',
            strokeStyle: pill.color,
            lineWidth: 1.5,
            text: {
                content: pill.text,
                color: '#ffffff',
                size: 11,
                family: 'Outfit'
            }
        }
    });
    Composite.add(world, pBody);
});

// Custom text rendering pass for Matter.js shapes
const canvasElement = physicsContainer.querySelector('canvas');
const ctx2d = canvasElement.getContext('2d');

Matter.Events.on(render, 'afterRender', () => {
    const bodies = Composite.allBodies(world);
    ctx2d.save();
    bodies.forEach(body => {
        if (body.render.text) {
            ctx2d.translate(body.position.x, body.position.y);
            ctx2d.rotate(body.angle);
            ctx2d.fillStyle = "#ffffff";
            ctx2d.font = "800 11px Outfit";
            ctx2d.textAlign = "center";
            ctx2d.textBaseline = "middle";
            ctx2d.fillText(body.render.text.content, 0, 0);
            ctx2d.rotate(-body.angle);
            ctx2d.translate(-body.position.x, -body.position.y);
        }
    });
    ctx2d.restore();
});

// Add cursor dragging/tossing constraint
const mouse = Mouse.create(render.canvas);
const mouseConstraint = MouseConstraint.create(engine, {
    mouse: mouse,
    constraint: {
        stiffness: 0.2,
        render: { visible: false }
    }
});
Composite.add(world, mouseConstraint);
render.mouse = mouse;

// Let users click inside canvas to drop new pills
physicsContainer.addEventListener('click', (e) => {
    // Avoid spawning pills if dragging an existing body
    if (mouseConstraint.body) return;
    
    const rect = physicsContainer.getBoundingClientRect();
    const x = e.clientX - rect.left;
    const y = e.clientY - rect.top;

    if (x >= 0 && x <= renderWidth && y >= 0 && y <= renderHeight) {
        const labels = ["RESONANCE", "ANONYMOUS", "@ghoul", "@veil", "SOUL", "GHOSTED"];
        const colors = ["#BD00FF", "#00FFFF", "#FF8700"];
        
        const randomLabel = labels[Math.floor(Math.random() * labels.length)];
        const randomColor = colors[Math.floor(Math.random() * colors.length)];
        
        const newPill = Bodies.rectangle(x, y, 90, 36, {
            chamfer: { radius: 18 },
            restitution: 0.75,
            friction: 0.05,
            render: {
                fillStyle: 'rgba(20, 20, 25, 0.85)',
                strokeStyle: randomColor,
                lineWidth: 1.5,
                text: {
                    content: randomLabel,
                    color: '#ffffff',
                    size: 11,
                    family: 'Outfit'
                }
            }
        });
        Composite.add(world, newPill);
    }
});


// --- SECTION 3: LIQUID GLASS DISTORTION EFFECT ---
const refractionCard = document.querySelector('.refraction-target');
const displacementMap = document.querySelector('#liquid-refraction-filter feDisplacementMap');
const turbulence = document.querySelector('#liquid-refraction-filter feTurbulence');

let targetScale = 0;
let currentScale = 0;

refractionCard.addEventListener('mousemove', (e) => {
    const rect = refractionCard.getBoundingClientRect();
    const x = e.clientX - rect.left;
    const y = e.clientY - rect.top;
    
    // Scale intensity based on distance to center
    const dx = x - rect.width / 2;
    const dy = y - rect.height / 2;
    const distance = Math.hypot(dx, dy);
    
    targetScale = Math.min(60, distance * 0.4);
    
    // Shift baseFrequency slightly for liquid dynamic ripple wave look
    const freq = 0.015 + (distance * 0.0001);
    turbulence.setAttribute('baseFrequency', freq.toFixed(4));
    refractionCard.style.filter = "url(#liquid-refraction-filter)";
});

refractionCard.addEventListener('mouseleave', () => {
    targetScale = 0;
    refractionCard.style.filter = "none";
});

// Smoothly interpolate the scale of refraction map
function animateLiquidRefraction() {
    currentScale += (targetScale - currentScale) * 0.1;
    displacementMap.setAttribute('scale', currentScale.toFixed(2));
    requestAnimationFrame(animateLiquidRefraction);
}
animateLiquidRefraction();


// --- SECTION 4: 3D PERSPECTIVE CARD COVER FLOW CYCLE ---
let stackIndex = 1;
function cycleStack() {
    const deck = document.getElementById('deck-wrapper');
    const cards = deck.querySelectorAll('.stack-card');
    
    stackIndex = (stackIndex + 1) % 3;
    
    cards.forEach((card, idx) => {
        // Cycle active classes
        card.className = 'stack-card';
        
        const pos = (idx - stackIndex + 3) % 3;
        if (pos === 0) {
            card.classList.add('card-1');
        } else if (pos === 1) {
            card.classList.add('card-2');
        } else {
            card.classList.add('card-3');
        }
    });
}
