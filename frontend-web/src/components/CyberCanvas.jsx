// components/CyberCanvas.jsx
//
// 🎬 Sinematik siber güvenlik Canvas animasyonu
//    Video dosyasına gerek yok — tamamen tarayıcıda render edilir.
//
// Efektler:
//   • Dark navy circuit board zemini (dinamik çizgiler)
//   • Glowing blue shield + padlock (pulse + electric arc)
//   • Neon cyan network nodes (sıralı ışıma)
//   • Holographic hexagonal grid overlay (shimmer)
//   • Particles & data streams (spiral)
//   • Lens flare sweep (soldan sağa)
//   • Yavaş zoom (scale animation)
//   • Loopable — kesintisiz döngü

import { useEffect, useRef } from 'react';

// ─────────────────────────────────────────────────────────────
// Utility helpers
// ─────────────────────────────────────────────────────────────

const TAU   = Math.PI * 2;
const lerp  = (a, b, t) => a + (b - a) * t;
const clamp = (v, lo, hi) => Math.max(lo, Math.min(hi, v));
const rand  = (min, max) => Math.random() * (max - min) + min;

// ─────────────────────────────────────────────────────────────
// Constants
// ─────────────────────────────────────────────────────────────

const COLORS = {
  bg:          '#050810',
  navy:        '#0a0f1e',
  blue:        '#3b82f6',
  cyan:        '#06b6d4',
  electric:    '#7dd3fc',
  dim:         'rgba(6,182,212,0.15)',
  nodeDim:     'rgba(59,130,246,0.4)',
  trace:       'rgba(59,130,246,0.08)',
};

// ─────────────────────────────────────────────────────────────
// Main component
// ─────────────────────────────────────────────────────────────

export default function CyberCanvas({ style = {} }) {
  const canvasRef = useRef(null);
  const rafRef    = useRef(null);

  useEffect(() => {
    const canvas = canvasRef.current;
    if (!canvas) return;

    const ctx    = canvas.getContext('2d');
    let   W = 0, H = 0, CX = 0, CY = 0;

    // ── Resize handler ─────────────────────────────────────────
    const resize = () => {
      W  = canvas.width  = canvas.offsetWidth;
      H  = canvas.height = canvas.offsetHeight;
      CX = W / 2;
      CY = H / 2;
      // Rebuild any size-dependent structures
      buildCircuit();
      buildHex();
      buildNodes();
    };

    // ══════════════════════════════════════════════════════════
    // Circuit Board Traces
    // ══════════════════════════════════════════════════════════

    let circuitLines = [];

    function buildCircuit() {
      circuitLines = [];
      const count  = 40;
      for (let i = 0; i < count; i++) {
        const startX = rand(0, W);
        const startY = rand(0, H);
        const segs   = [];
        let   x = startX, y = startY;
        for (let s = 0; s < rand(3, 7); s++) {
          const dir  = Math.floor(rand(0, 4)); // 0=right 1=left 2=down 3=up
          const dist = rand(40, 180);
          let   nx = x, ny = y;
          if      (dir === 0) nx += dist;
          else if (dir === 1) nx -= dist;
          else if (dir === 2) ny += dist;
          else                ny -= dist;
          segs.push({ x1: x, y1: y, x2: nx, y2: ny });
          x = nx; y = ny;
        }
        circuitLines.push({
          segs,
          color: Math.random() > 0.5 ? COLORS.blue : COLORS.cyan,
          alpha: rand(0.04, 0.14),
          pulse: rand(0, TAU),
          pulseSpeed: rand(0.3, 1.2),
          dotAt: Math.floor(rand(0, segs.length)),
          dotProgress: rand(0, 1),
        });
      }
    }

    function drawCircuit(t) {
      circuitLines.forEach(line => {
        line.pulse += line.pulseSpeed * 0.016;
        const brightness = line.alpha + Math.sin(line.pulse) * 0.06;

        ctx.strokeStyle = line.color;
        ctx.lineWidth   = 1;
        ctx.globalAlpha = clamp(brightness, 0, 1);

        line.segs.forEach(seg => {
          ctx.beginPath();
          ctx.moveTo(seg.x1, seg.y1);
          ctx.lineTo(seg.x2, seg.y2);
          ctx.stroke();

          // Junction dot
          ctx.beginPath();
          ctx.arc(seg.x2, seg.y2, 2, 0, TAU);
          ctx.fillStyle = line.color;
          ctx.fill();
        });

        // Moving data dot
        const seg = line.segs[line.dotAt];
        if (seg) {
          line.dotProgress += 0.008;
          if (line.dotProgress > 1) {
            line.dotProgress = 0;
            line.dotAt = (line.dotAt + 1) % line.segs.length;
          }
          const dx = seg.x1 + (seg.x2 - seg.x1) * line.dotProgress;
          const dy = seg.y1 + (seg.y2 - seg.y1) * line.dotProgress;
          ctx.globalAlpha = 0.9;
          ctx.shadowColor = line.color;
          ctx.shadowBlur  = 8;
          ctx.beginPath();
          ctx.arc(dx, dy, 2.5, 0, TAU);
          ctx.fillStyle = line.color === COLORS.cyan ? '#fff' : COLORS.electric;
          ctx.fill();
          ctx.shadowBlur = 0;
        }
      });
      ctx.globalAlpha = 1;
    }

    // ══════════════════════════════════════════════════════════
    // Hexagonal Grid
    // ══════════════════════════════════════════════════════════

    let hexCells = [];

    function buildHex() {
      hexCells = [];
      const size = 48;
      const w    = size * Math.sqrt(3);
      const h    = size * 1.5;
      for (let row = -1; row < H / h + 2; row++) {
        for (let col = -1; col < W / w + 2; col++) {
          const offset = row % 2 === 0 ? 0 : w / 2;
          hexCells.push({
            x:      col * w + offset,
            y:      row * h,
            size,
            phase:  rand(0, TAU),
            speed:  rand(0.2, 0.8),
          });
        }
      }
    }

    function hexPath(ctx, x, y, size) {
      ctx.beginPath();
      for (let i = 0; i < 6; i++) {
        const angle = (Math.PI / 180) * (60 * i - 30);
        const px    = x + size * Math.cos(angle);
        const py    = y + size * Math.sin(angle);
        i === 0 ? ctx.moveTo(px, py) : ctx.lineTo(px, py);
      }
      ctx.closePath();
    }

    function drawHex(t) {
      hexCells.forEach(cell => {
        cell.phase += cell.speed * 0.008;
        const alpha = (Math.sin(cell.phase) * 0.5 + 0.5) * 0.06 + 0.01;
        hexPath(ctx, cell.x, cell.y, cell.size);
        ctx.strokeStyle = COLORS.cyan;
        ctx.lineWidth   = 0.6;
        ctx.globalAlpha = alpha;
        ctx.stroke();
      });
      ctx.globalAlpha = 1;
    }

    // ══════════════════════════════════════════════════════════
    // Network Nodes
    // ══════════════════════════════════════════════════════════

    let nodes = [];

    function buildNodes() {
      nodes = [];
      const count = 14;
      for (let i = 0; i < count; i++) {
        const angle  = (TAU / count) * i + rand(-0.2, 0.2);
        const radius = rand(180, Math.min(W, H) * 0.42);
        nodes.push({
          x:       CX + Math.cos(angle) * radius,
          y:       CY + Math.sin(angle) * radius,
          radius,
          angle,
          phase:   rand(0, TAU),
          speed:   rand(0.4, 1.2),
          size:    rand(3, 6),
          lit:     false,
          litTime: rand(0, TAU),
        });
      }
    }

    function drawNodes(t) {
      // Draw edges from center to node
      nodes.forEach((node, i) => {
        node.litTime += node.speed * 0.012;
        node.lit = Math.sin(node.litTime) > 0.2;

        const alpha = node.lit ? 0.5 : 0.12;

        // Line to center
        const grad = ctx.createLinearGradient(CX, CY, node.x, node.y);
        grad.addColorStop(0, `rgba(59,130,246,${alpha})`);
        grad.addColorStop(1, `rgba(6,182,212,${alpha * 0.3})`);
        ctx.strokeStyle = grad;
        ctx.lineWidth   = 1;
        ctx.globalAlpha = 1;
        ctx.beginPath();
        ctx.moveTo(CX, CY);
        ctx.lineTo(node.x, node.y);
        ctx.stroke();

        // Cross-node edges (nearest 2 neighbours)
        nodes.forEach((other, j) => {
          if (j <= i) return;
          const dx   = other.x - node.x;
          const dy   = other.y - node.y;
          const dist = Math.sqrt(dx * dx + dy * dy);
          if (dist < 240) {
            ctx.globalAlpha = (1 - dist / 240) * 0.08;
            ctx.strokeStyle = COLORS.cyan;
            ctx.lineWidth   = 0.5;
            ctx.beginPath();
            ctx.moveTo(node.x, node.y);
            ctx.lineTo(other.x, other.y);
            ctx.stroke();
          }
        });

        // Node dot
        ctx.globalAlpha = node.lit ? 1 : 0.3;
        ctx.shadowColor = COLORS.cyan;
        ctx.shadowBlur  = node.lit ? 16 : 4;
        ctx.beginPath();
        ctx.arc(node.x, node.y, node.size, 0, TAU);
        ctx.fillStyle = node.lit ? COLORS.electric : COLORS.nodeDim;
        ctx.fill();

        // Outer ring when lit
        if (node.lit) {
          ctx.globalAlpha = 0.4;
          ctx.strokeStyle = COLORS.cyan;
          ctx.lineWidth   = 1;
          ctx.beginPath();
          ctx.arc(node.x, node.y, node.size + 5, 0, TAU);
          ctx.stroke();
        }

        ctx.shadowBlur  = 0;
      });
      ctx.globalAlpha = 1;
    }

    // ══════════════════════════════════════════════════════════
    // Shield
    // ══════════════════════════════════════════════════════════

    function drawShield(t) {
      const pulse  = Math.sin(t * 0.0018) * 0.12 + 1; // slow breathe
      const glow   = (Math.sin(t * 0.003) * 0.5 + 0.5); // 0–1
      const sz     = Math.min(W, H) * 0.18 * pulse;

      ctx.save();
      ctx.translate(CX, CY);

      // ── Outer glow rings ─────────────────────────────────────
      for (let r = 3; r >= 1; r--) {
        const ringR = sz * (1.2 + r * 0.25);
        const alpha = glow * (0.12 / r);
        const grd   = ctx.createRadialGradient(0, 0, ringR * 0.6, 0, 0, ringR);
        grd.addColorStop(0, `rgba(59,130,246,${alpha})`);
        grd.addColorStop(1, 'rgba(59,130,246,0)');
        ctx.fillStyle   = grd;
        ctx.globalAlpha = 1;
        ctx.beginPath();
        ctx.arc(0, 0, ringR, 0, TAU);
        ctx.fill();
      }

      // ── Electric arcs ────────────────────────────────────────
      const arcCount = 3;
      for (let a = 0; a < arcCount; a++) {
        const arcAngle = (TAU / arcCount) * a + t * 0.001;
        const arcLen   = rand(sz * 0.8, sz * 1.4);
        ctx.globalAlpha = glow * 0.5;
        ctx.strokeStyle = COLORS.electric;
        ctx.lineWidth   = 0.8;
        ctx.shadowColor = COLORS.cyan;
        ctx.shadowBlur  = 6;
        ctx.beginPath();
        ctx.moveTo(Math.cos(arcAngle) * sz * 0.5, Math.sin(arcAngle) * sz * 0.5);
        // Zigzag arc
        for (let s = 1; s <= 4; s++) {
          const r     = sz * 0.5 + (arcLen - sz * 0.5) * (s / 4);
          const angle = arcAngle + rand(-0.3, 0.3);
          ctx.lineTo(Math.cos(angle) * r, Math.sin(angle) * r);
        }
        ctx.stroke();
        ctx.shadowBlur = 0;
      }

      // ── Shield path ──────────────────────────────────────────
      const shield = new Path2D();
      shield.moveTo(0, -sz);
      shield.bezierCurveTo( sz * 1.1, -sz * 0.7,  sz * 1.1,  sz * 0.2,  0,  sz * 1.15);
      shield.bezierCurveTo(-sz * 1.1,  sz * 0.2, -sz * 1.1, -sz * 0.7,  0, -sz);
      shield.closePath();

      // Shield fill (glassmorphism)
      const fillGrad = ctx.createRadialGradient(-sz * 0.2, -sz * 0.3, 0, 0, 0, sz * 1.2);
      fillGrad.addColorStop(0, `rgba(59,130,246,${0.22 + glow * 0.12})`);
      fillGrad.addColorStop(0.6, `rgba(6,182,212,${0.1 + glow * 0.06})`);
      fillGrad.addColorStop(1, 'rgba(5,8,16,0.05)');
      ctx.fillStyle   = fillGrad;
      ctx.globalAlpha = 1;
      ctx.fill(shield);

      // Shield stroke (outer edge glow)
      ctx.strokeStyle = COLORS.cyan;
      ctx.lineWidth   = 2.5;
      ctx.globalAlpha = 0.7 + glow * 0.3;
      ctx.shadowColor = COLORS.cyan;
      ctx.shadowBlur  = 20 + glow * 20;
      ctx.stroke(shield);
      ctx.shadowBlur = 0;

      // Shield inner highlight
      ctx.strokeStyle = COLORS.electric;
      ctx.lineWidth   = 0.8;
      ctx.globalAlpha = 0.25;
      ctx.stroke(shield);

      // ── Padlock ──────────────────────────────────────────────
      const lkW = sz * 0.32, lkH = sz * 0.38;
      const lkX = -lkW / 2, lkY = -lkH * 0.4;

      // Lock shackle (arch)
      ctx.globalAlpha = 0.9 + glow * 0.1;
      ctx.strokeStyle = COLORS.electric;
      ctx.lineWidth   = sz * 0.055;
      ctx.lineCap     = 'round';
      ctx.shadowColor = COLORS.cyan;
      ctx.shadowBlur  = 12 + glow * 8;
      ctx.beginPath();
      ctx.arc(0, lkY, lkW * 0.3, Math.PI, 0, false);
      ctx.stroke();

      // Lock body
      ctx.shadowBlur  = 0;
      ctx.globalAlpha = 0.95;
      ctx.fillStyle   = `rgba(59,130,246,${0.7 + glow * 0.3})`;
      ctx.strokeStyle = COLORS.electric;
      ctx.lineWidth   = 1.5;
      const bodyY = lkY + lkH * 0.1;
      const bodyH = lkH * 0.55;
      roundRect(ctx, lkX, bodyY, lkW, bodyH, sz * 0.04);
      ctx.fill();
      ctx.shadowColor = COLORS.cyan;
      ctx.shadowBlur  = 10 + glow * 6;
      ctx.stroke();
      ctx.shadowBlur  = 0;

      // Keyhole
      ctx.globalAlpha = 1;
      ctx.fillStyle   = '#050810';
      ctx.beginPath();
      ctx.arc(0, bodyY + bodyH * 0.35, sz * 0.055, 0, TAU);
      ctx.fill();
      ctx.fillRect(-sz * 0.025, bodyY + bodyH * 0.35, sz * 0.05, bodyH * 0.35);

      ctx.lineCap = 'butt';
      ctx.restore();
    }

    // ── roundRect polyfill ──────────────────────────────────────
    function roundRect(ctx, x, y, w, h, r) {
      ctx.beginPath();
      ctx.moveTo(x + r, y);
      ctx.lineTo(x + w - r, y);
      ctx.quadraticCurveTo(x + w, y, x + w, y + r);
      ctx.lineTo(x + w, y + h - r);
      ctx.quadraticCurveTo(x + w, y + h, x + w - r, y + h);
      ctx.lineTo(x + r, y + h);
      ctx.quadraticCurveTo(x, y + h, x, y + h - r);
      ctx.lineTo(x, y + r);
      ctx.quadraticCurveTo(x, y, x + r, y);
      ctx.closePath();
    }

    // ══════════════════════════════════════════════════════════
    // Particles / Data Streams
    // ══════════════════════════════════════════════════════════

    const particles = [];

    function spawnParticles() {
      for (let i = 0; i < 80; i++) {
        const angle  = rand(0, TAU);
        const radius = rand(60, Math.min(W, H) * 0.5);
        particles.push({
          x:      CX + Math.cos(angle) * radius,
          y:      CY + Math.sin(angle) * radius,
          angle,
          radius,
          speed:  rand(0.001, 0.004) * (Math.random() > 0.5 ? 1 : -1),
          drift:  rand(-0.3, 0.3),
          life:   rand(0, 1),
          decay:  rand(0.003, 0.008),
          size:   rand(0.8, 2.5),
          isCyan: Math.random() > 0.5,
        });
      }
    }

    function drawParticles(t) {
      particles.forEach((p, idx) => {
        p.angle  += p.speed;
        p.radius += p.drift * 0.1;
        p.life   -= p.decay;

        if (p.life <= 0) {
          // Respawn
          p.angle  = rand(0, TAU);
          p.radius = rand(60, Math.min(W, H) * 0.5);
          p.life   = 1;
          p.drift  = rand(-0.3, 0.3);
        }

        p.x = CX + Math.cos(p.angle) * p.radius;
        p.y = CY + Math.sin(p.angle) * p.radius;

        ctx.globalAlpha = p.life * 0.7;
        ctx.shadowColor = p.isCyan ? COLORS.cyan : COLORS.blue;
        ctx.shadowBlur  = 4;
        ctx.fillStyle   = p.isCyan ? COLORS.cyan : COLORS.electric;
        ctx.beginPath();
        ctx.arc(p.x, p.y, p.size, 0, TAU);
        ctx.fill();
      });
      ctx.shadowBlur  = 0;
      ctx.globalAlpha = 1;
    }

    // ══════════════════════════════════════════════════════════
    // Lens Flare (sweeps L→R every ~8 seconds)
    // ══════════════════════════════════════════════════════════

    const FLARE_PERIOD = 8000;

    function drawLensFlare(t) {
      const cycle   = t % FLARE_PERIOD;
      const progress = cycle / FLARE_PERIOD;

      // Flare is only visible during first 30% of cycle
      if (progress > 0.3) return;

      const ease = Math.sin(progress / 0.3 * Math.PI);
      const fx   = lerp(-W * 0.1, W * 1.1, progress / 0.3);
      const fy   = CY * 0.6;

      // Main streak
      const streak = ctx.createLinearGradient(fx - 300, fy, fx + 300, fy);
      streak.addColorStop(0,   'rgba(125,211,252,0)');
      streak.addColorStop(0.4, `rgba(125,211,252,${0.3 * ease})`);
      streak.addColorStop(0.5, `rgba(255,255,255,${0.5 * ease})`);
      streak.addColorStop(0.6, `rgba(125,211,252,${0.3 * ease})`);
      streak.addColorStop(1,   'rgba(125,211,252,0)');

      ctx.globalAlpha = ease;
      ctx.fillStyle   = streak;
      ctx.fillRect(fx - 300, fy - 4, 600, 8);

      // Halo
      const halo = ctx.createRadialGradient(fx, fy, 0, fx, fy, 80);
      halo.addColorStop(0, `rgba(125,211,252,${0.35 * ease})`);
      halo.addColorStop(1, 'rgba(125,211,252,0)');
      ctx.fillStyle = halo;
      ctx.beginPath();
      ctx.ellipse(fx, fy, 80, 30, 0, 0, TAU);
      ctx.fill();

      // Ghost flares (opposite direction)
      [-0.2, 0.15, -0.35].forEach((offset, i) => {
        const gx = CX + (fx - CX) * (-offset);
        const gy = CY + (fy - CY) * (-offset);
        const gr = ctx.createRadialGradient(gx, gy, 0, gx, gy, 20 + i * 15);
        gr.addColorStop(0, `rgba(59,130,246,${0.25 * ease})`);
        gr.addColorStop(1, 'rgba(59,130,246,0)');
        ctx.fillStyle = gr;
        ctx.beginPath();
        ctx.arc(gx, gy, 20 + i * 15, 0, TAU);
        ctx.fill();
      });

      ctx.globalAlpha = 1;
    }

    // ══════════════════════════════════════════════════════════
    // Background (radial gradient + vignette)
    // ══════════════════════════════════════════════════════════

    function drawBg() {
      // Base fill
      ctx.fillStyle = COLORS.bg;
      ctx.fillRect(0, 0, W, H);

      // Center ambient glow
      const cg = ctx.createRadialGradient(CX, CY, 0, CX, CY, Math.min(W, H) * 0.55);
      cg.addColorStop(0,   'rgba(59,130,246,0.07)');
      cg.addColorStop(0.5, 'rgba(6,182,212,0.04)');
      cg.addColorStop(1,   'rgba(5,8,16,0)');
      ctx.fillStyle = cg;
      ctx.fillRect(0, 0, W, H);

      // Vignette
      const vg = ctx.createRadialGradient(CX, CY, Math.min(W, H) * 0.3, CX, CY, Math.max(W, H) * 0.75);
      vg.addColorStop(0, 'rgba(5,8,16,0)');
      vg.addColorStop(1, 'rgba(5,8,16,0.85)');
      ctx.fillStyle = vg;
      ctx.fillRect(0, 0, W, H);
    }

    // ══════════════════════════════════════════════════════════
    // Slow zoom (camera effect)
    // ══════════════════════════════════════════════════════════

    const ZOOM_PERIOD = 16000; // 16s full cycle
    const ZOOM_MIN    = 1.0;
    const ZOOM_MAX    = 1.08;

    function applyZoom(t) {
      const cycle   = (t % ZOOM_PERIOD) / ZOOM_PERIOD;
      const zoom    = lerp(ZOOM_MIN, ZOOM_MAX, (Math.sin(cycle * TAU - Math.PI / 2) + 1) / 2);
      ctx.save();
      ctx.translate(CX, CY);
      ctx.scale(zoom, zoom);
      ctx.translate(-CX, -CY);
    }

    // ══════════════════════════════════════════════════════════
    // Main render loop
    // ══════════════════════════════════════════════════════════

    let startTime = null;

    function render(timestamp) {
      if (!startTime) startTime = timestamp;
      const t = timestamp - startTime;

      ctx.clearRect(0, 0, W, H);

      applyZoom(t);
      drawBg();
      drawHex(t);
      drawCircuit(t);
      drawNodes(t);
      drawParticles(t);
      drawShield(t);
      ctx.restore(); // restore zoom
      drawLensFlare(t);

      rafRef.current = requestAnimationFrame(render);
    }

    // ── Init ────────────────────────────────────────────────────
    const ro = new ResizeObserver(resize);
    ro.observe(canvas);
    resize();
    spawnParticles();
    rafRef.current = requestAnimationFrame(render);

    return () => {
      cancelAnimationFrame(rafRef.current);
      ro.disconnect();
    };
  }, []);

  return (
    <canvas
      ref={canvasRef}
      aria-hidden="true"
      style={{
        position: 'fixed',
        inset: 0,
        width: '100%',
        height: '100%',
        display: 'block',
        zIndex: -10,
        pointerEvents: 'none',
        ...style,
      }}
    />
  );
}
