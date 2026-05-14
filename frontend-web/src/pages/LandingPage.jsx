// LandingPage.jsx
// Public-facing landing page shown when user has no active session.
// Features: animated hero, 3-step process cards, stats bar, CTA.

import React, { useEffect, useRef } from 'react';
import { useNavigate }              from 'react-router-dom';
import {
    motion,
    useInView,
    useAnimation,
    AnimatePresence,
} from 'framer-motion';
import './LandingPage.css';

// ── Animation variants ──────────────────────────────────────────────────────

const fadeUp = {
    hidden:  { opacity: 0, y: 32 },
    visible: { opacity: 1, y: 0,  transition: { duration: 0.65, ease: [0.22, 1, 0.36, 1] } },
};

const stagger = {
    visible: { transition: { staggerChildren: 0.13 } },
};

const cardVariant = {
    hidden:  { opacity: 0, y: 40, scale: 0.97 },
    visible: { opacity: 1, y: 0,  scale: 1, transition: { duration: 0.55, ease: [0.22, 1, 0.36, 1] } },
};

// ── Animated section wrapper ────────────────────────────────────────────────

function AnimSection({ children, className = '', delay = 0 }) {
    const ref      = useRef(null);
    const inView   = useInView(ref, { once: true, margin: '-80px' });
    const controls = useAnimation();

    useEffect(() => {
        if (inView) controls.start('visible');
    }, [inView, controls]);

    return (
        <motion.div
            ref={ref}
            className={className}
            variants={stagger}
            initial="hidden"
            animate={controls}
            style={{ transitionDelay: `${delay}ms` }}
        >
            {children}
        </motion.div>
    );
}

// ── Particle background canvas ──────────────────────────────────────────────

function ParticleCanvas() {
    const canvasRef = useRef(null);

    useEffect(() => {
        const canvas = canvasRef.current;
        if (!canvas) return;
        const ctx = canvas.getContext('2d');

        const resize = () => {
            canvas.width  = window.innerWidth;
            canvas.height = window.innerHeight;
        };
        resize();
        window.addEventListener('resize', resize);

        const PARTICLE_COUNT = 55;
        const particles = Array.from({ length: PARTICLE_COUNT }, () => ({
            x:   Math.random() * canvas.width,
            y:   Math.random() * canvas.height,
            r:   Math.random() * 1.8 + 0.4,
            vx:  (Math.random() - 0.5) * 0.25,
            vy:  (Math.random() - 0.5) * 0.25,
            o:   Math.random() * 0.4 + 0.1,
        }));

        let raf;
        const draw = () => {
            ctx.clearRect(0, 0, canvas.width, canvas.height);
            particles.forEach(p => {
                p.x += p.vx;
                p.y += p.vy;
                if (p.x < 0) p.x = canvas.width;
                if (p.x > canvas.width) p.x = 0;
                if (p.y < 0) p.y = canvas.height;
                if (p.y > canvas.height) p.y = 0;

                ctx.beginPath();
                ctx.arc(p.x, p.y, p.r, 0, Math.PI * 2);
                ctx.fillStyle = `rgba(99, 102, 241, ${p.o})`;
                ctx.fill();
            });

            // Draw connection lines
            for (let i = 0; i < particles.length; i++) {
                for (let j = i + 1; j < particles.length; j++) {
                    const dx = particles[i].x - particles[j].x;
                    const dy = particles[i].y - particles[j].y;
                    const dist = Math.sqrt(dx * dx + dy * dy);
                    if (dist < 100) {
                        ctx.beginPath();
                        ctx.strokeStyle = `rgba(59, 130, 246, ${0.12 * (1 - dist / 100)})`;
                        ctx.lineWidth = 0.6;
                        ctx.moveTo(particles[i].x, particles[i].y);
                        ctx.lineTo(particles[j].x, particles[j].y);
                        ctx.stroke();
                    }
                }
            }

            raf = requestAnimationFrame(draw);
        };
        draw();

        return () => {
            cancelAnimationFrame(raf);
            window.removeEventListener('resize', resize);
        };
    }, []);

    return <canvas ref={canvasRef} className="lp-particle-canvas" />;
}

// ── Step card data ──────────────────────────────────────────────────────────

const STEPS = [
    {
        number: '01',
        title:  'Şüpheliyi Yakala',
        desc:   'Şüpheli linki, PDF dosyasını veya ekran görüntüsünü güvenli ortama sürükleyin.',
        icon: (
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.7" strokeLinecap="round" strokeLinejoin="round">
                <path d="M10 13a5 5 0 007.54.54l3-3a5 5 0 00-7.07-7.07l-1.72 1.71" />
                <path d="M14 11a5 5 0 00-7.54-.54l-3 3a5 5 0 007.07 7.07l1.71-1.71" />
            </svg>
        ),
        accent: '#3b82f6',
        glow:   'rgba(59, 130, 246, 0.25)',
    },
    {
        number: '02',
        title:  'Çift Motorlu Analiz',
        desc:   'Gemini AI ve VirusTotal istihbaratı aynı anda çalışarak bağlamsal ve statik analiz yapar.',
        icon: (
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.7" strokeLinecap="round" strokeLinejoin="round">
                <path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z" />
                <path d="M9 12l2 2 4-4" />
            </svg>
        ),
        accent: '#6366f1',
        glow:   'rgba(99, 102, 241, 0.25)',
    },
    {
        number: '03',
        title:  'Güvende Kal',
        desc:   '0–100 risk skoru ve PDF formatındaki detaylı siber istihbarat raporunuzla güvende kalın.',
        icon: (
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.7" strokeLinecap="round" strokeLinejoin="round">
                <path d="M14 2H6a2 2 0 00-2 2v16a2 2 0 002 2h12a2 2 0 002-2V8z" />
                <polyline points="14 2 14 8 20 8" />
                <line x1="16" y1="13" x2="8" y2="13" />
                <line x1="16" y1="17" x2="8" y2="17" />
                <polyline points="10 9 9 9 8 9" />
            </svg>
        ),
        accent: '#06b6d4',
        glow:   'rgba(6, 182, 212, 0.25)',
    },
];

// ── Stat data ───────────────────────────────────────────────────────────────

const STATS = [
    { value: '99.8%', label: 'Tespit Doğruluğu' },
    { value: '<3sn',  label: 'Ortalama Analiz Süresi' },
    { value: '70+',   label: 'Tehdit İstihbarat Kaynağı' },
    { value: '7/24',  label: 'Kesintisiz Koruma' },
];

// ── Main component ──────────────────────────────────────────────────────────

export default function LandingPage() {
    const navigate = useNavigate();

    return (
        <div className="lp-root">
            {/* Particle background */}
            <ParticleCanvas />

            {/* ── Navbar ── */}
            <motion.nav
                className="lp-nav"
                initial={{ opacity: 0, y: -20 }}
                animate={{ opacity: 1, y: 0 }}
                transition={{ duration: 0.5, ease: 'easeOut' }}
            >
                <div className="lp-nav__inner">
                    <div className="lp-nav__logo">
                        <div className="lp-nav__logo-icon">
                            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
                                <path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z" />
                            </svg>
                        </div>
                        <span>Cyber<span className="lp-accent">Check</span></span>
                    </div>
                    <div className="lp-nav__actions">
                        <button
                            className="lp-btn lp-btn--ghost"
                            onClick={() => navigate('/login')}
                        >
                            Giriş Yap
                        </button>
                        <button
                            className="lp-btn lp-btn--primary"
                            onClick={() => navigate('/login')}
                        >
                            Ücretsiz Başla
                        </button>
                    </div>
                </div>
            </motion.nav>

            {/* ── Hero ── */}
            <section className="lp-hero">
                {/* Glowing orbs */}
                <div className="lp-orb lp-orb--1" />
                <div className="lp-orb lp-orb--2" />
                <div className="lp-orb lp-orb--3" />

                <AnimSection className="lp-hero__content">
                    <motion.div className="lp-hero__badge" variants={fadeUp}>
                        <span className="lp-badge-dot" />
                        Yapay Zeka Destekli Siber Tehdit Analizi
                    </motion.div>

                    <motion.h1 className="lp-hero__title" variants={fadeUp}>
                        Siber Tehditleri
                        <br />
                        <span className="lp-gradient-text">Saniyeler İçinde</span>
                        <br />
                        Yok Edin.
                    </motion.h1>

                    <motion.p className="lp-hero__sub" variants={fadeUp}>
                        Yapay zeka ve küresel istihbarat motorlarıyla oltalama sitelerini,
                        zararlı belgeleri ve sosyal mühendislik tuzaklarını cihazınıza
                        bulaşmadan tespit edin.
                    </motion.p>

                    <motion.div className="lp-hero__cta" variants={fadeUp}>
                        <button
                            id="lp-cta-primary"
                            className="lp-btn lp-btn--primary lp-btn--lg"
                            onClick={() => navigate('/login')}
                        >
                            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" width="18" height="18">
                                <path d="M15 3h4a2 2 0 012 2v14a2 2 0 01-2 2h-4M10 17l5-5-5-5M15 12H3" />
                            </svg>
                            Sisteme Giriş Yap
                        </button>
                        <a
                            href="#how-it-works"
                            className="lp-btn lp-btn--outline lp-btn--lg"
                        >
                            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" width="18" height="18">
                                <circle cx="12" cy="12" r="10" />
                                <polyline points="8 12 12 16 16 12" />
                                <line x1="12" y1="8" x2="12" y2="16" />
                            </svg>
                            Nasıl Çalışır?
                        </a>
                    </motion.div>

                    {/* Trust bar */}
                    <motion.div className="lp-hero__trust" variants={fadeUp}>
                        <span>Desteklenen motorlar:</span>
                        <div className="lp-trust__badges">
                            <span className="lp-trust__badge">
                                <svg viewBox="0 0 24 24" fill="currentColor" width="14" height="14"><path d="M12 2a10 10 0 100 20A10 10 0 0012 2z"/></svg>
                                Gemini AI
                            </span>
                            <span className="lp-trust__badge">
                                <svg viewBox="0 0 24 24" fill="currentColor" width="14" height="14"><path d="M12 2a10 10 0 100 20A10 10 0 0012 2z"/></svg>
                                VirusTotal
                            </span>
                            <span className="lp-trust__badge">
                                <svg viewBox="0 0 24 24" fill="currentColor" width="14" height="14"><path d="M12 2a10 10 0 100 20A10 10 0 0012 2z"/></svg>
                                Supabase
                            </span>
                        </div>
                    </motion.div>
                </AnimSection>

                {/* Hero visual */}
                <motion.div
                    className="lp-hero__visual"
                    initial={{ opacity: 0, scale: 0.9, x: 40 }}
                    animate={{ opacity: 1, scale: 1, x: 0 }}
                    transition={{ duration: 0.8, delay: 0.3, ease: [0.22, 1, 0.36, 1] }}
                >
                    <div className="lp-hero__terminal">
                        <div className="lp-terminal__header">
                            <span className="lp-dot lp-dot--red"   />
                            <span className="lp-dot lp-dot--yellow"/>
                            <span className="lp-dot lp-dot--green" />
                            <span className="lp-terminal__title">CyberCheck — Threat Analysis</span>
                        </div>
                        <div className="lp-terminal__body">
                            <TerminalLines />
                        </div>
                    </div>
                </motion.div>
            </section>

            {/* ── Stats bar ── */}
            <section className="lp-stats">
                <div className="lp-stats__inner">
                    {STATS.map((s, i) => (
                        <motion.div
                            key={s.label}
                            className="lp-stat"
                            initial={{ opacity: 0, y: 20 }}
                            whileInView={{ opacity: 1, y: 0 }}
                            viewport={{ once: true }}
                            transition={{ duration: 0.5, delay: i * 0.1 }}
                        >
                            <span className="lp-stat__value">{s.value}</span>
                            <span className="lp-stat__label">{s.label}</span>
                        </motion.div>
                    ))}
                </div>
            </section>

            {/* ── How It Works ── */}
            <section id="how-it-works" className="lp-steps">
                <AnimSection className="lp-steps__header">
                    <motion.p className="lp-overline" variants={fadeUp}>Süreç</motion.p>
                    <motion.h2 className="lp-section-title" variants={fadeUp}>
                        Nasıl Çalışır?
                    </motion.h2>
                    <motion.p className="lp-section-sub" variants={fadeUp}>
                        Üç adımda kurumsal düzey siber tehdit analizi — hiçbir kurulum gerektirmez.
                    </motion.p>
                </AnimSection>

                <div className="lp-steps__grid">
                    {STEPS.map((step, i) => (
                        <motion.div
                            key={step.number}
                            className="lp-step-card"
                            variants={cardVariant}
                            initial="hidden"
                            whileInView="visible"
                            viewport={{ once: true, margin: '-60px' }}
                            whileHover={{ y: -6, transition: { duration: 0.25 } }}
                            style={{ '--card-accent': step.accent, '--card-glow': step.glow }}
                            transition={{ delay: i * 0.12 }}
                        >
                            <div className="lp-step-card__top">
                                <div className="lp-step-card__icon" style={{ color: step.accent }}>
                                    {step.icon}
                                </div>
                                <span className="lp-step-card__num">{step.number}</span>
                            </div>
                            <h3 className="lp-step-card__title">{step.title}</h3>
                            <p className="lp-step-card__desc">{step.desc}</p>
                            <div className="lp-step-card__glow" />
                        </motion.div>
                    ))}
                </div>
            </section>

            {/* ── CTA Banner ── */}
            <section className="lp-cta-banner">
                <motion.div
                    className="lp-cta-banner__inner"
                    initial={{ opacity: 0, y: 30 }}
                    whileInView={{ opacity: 1, y: 0 }}
                    viewport={{ once: true }}
                    transition={{ duration: 0.65, ease: [0.22, 1, 0.36, 1] }}
                >
                    <div className="lp-cta-banner__orb" />
                    <p className="lp-overline" style={{ textAlign: 'center' }}>Hemen Başlayın</p>
                    <h2 className="lp-cta-banner__title">
                        Dijital Güvenliğinizi<br />
                        <span className="lp-gradient-text">Bir Üst Seviyeye</span> Taşıyın
                    </h2>
                    <p className="lp-cta-banner__sub">
                        Ücretsiz hesabınızı oluşturun ve saniyeler içinde ilk analizinizi yapın.
                    </p>
                    <button
                        id="lp-cta-banner-btn"
                        className="lp-btn lp-btn--primary lp-btn--lg"
                        onClick={() => navigate('/login')}
                    >
                        Ücretsiz Hesap Oluştur →
                    </button>
                </motion.div>
            </section>

            {/* ── Footer ── */}
            <footer className="lp-footer">
                <div className="lp-footer__inner">
                    <div className="lp-nav__logo">
                        <div className="lp-nav__logo-icon">
                            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
                                <path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z" />
                            </svg>
                        </div>
                        <span>Cyber<span className="lp-accent">Check</span></span>
                    </div>
                    <p className="lp-footer__copy">
                        © 2025 CyberCheck — Siber Tehdit İstihbarat Platformu
                    </p>
                </div>
            </footer>
        </div>
    );
}

// ── Terminal animation ──────────────────────────────────────────────────────

const TERMINAL_LINES = [
    { delay: 0.4,  type: 'cmd',     text: '$ cybercheck analyze --url "phishing-site.ru"' },
    { delay: 0.9,  type: 'info',    text: '  [*] Initializing dual-engine scan...' },
    { delay: 1.3,  type: 'info',    text: '  [*] Querying VirusTotal (70 engines)...' },
    { delay: 1.8,  type: 'info',    text: '  [*] Running Gemini AI contextual analysis...' },
    { delay: 2.3,  type: 'warn',    text: '  [!] Phishing indicators detected: 14/70' },
    { delay: 2.7,  type: 'danger',  text: '  [✗] MALICIOUS — Risk Score: 94/100' },
    { delay: 3.1,  type: 'success', text: '  [✓] Threat report generated → report_2025.pdf' },
    { delay: 3.5,  type: 'muted',   text: '  ─────────────────────────────────────────' },
    { delay: 3.8,  type: 'cmd',     text: '$ _' },
];

function TerminalLines() {
    return (
        <div className="lp-terminal__lines">
            {TERMINAL_LINES.map((line, i) => (
                <motion.div
                    key={i}
                    className={`lp-tline lp-tline--${line.type}`}
                    initial={{ opacity: 0, x: -8 }}
                    animate={{ opacity: 1, x: 0 }}
                    transition={{ duration: 0.35, delay: line.delay }}
                >
                    {line.text}
                </motion.div>
            ))}
        </div>
    );
}
