// App.jsx
// Root component — manages auth session and renders the correct screen.
//
// Flow:
//   initializing → (Supabase session check) →
//     ├─ not logged in  → Router → /       → <LandingPage>
//     │                             /login  → <AuthPage>
//     └─ logged in      → Router → /        → redirect → /dashboard
//                                  /dashboard → <AppHeader> + <Dashboard>
//                                  /scan      → <AppHeader> + <ScanPage>
//                                  /report/:id → <ReportPage> (standalone)

import React, { useState, useEffect, useCallback, useRef } from 'react';
import {
    BrowserRouter,
    Routes,
    Route,
    Navigate,
    useNavigate,
    useLocation,
} from 'react-router-dom';
import { supabase }    from './lib/supabase.js';
import AuthPage        from './pages/AuthPage.jsx';
import LandingPage     from './pages/LandingPage.jsx';
import ScanPage        from './pages/ScanPage.jsx';
import Dashboard       from './pages/Dashboard.jsx';
import ReportPage      from './pages/ReportPage.jsx';
import AppHeader       from './components/AppHeader.jsx';
import CyberCanvas     from './components/CyberCanvas.jsx';
import { Toaster }     from 'react-hot-toast';

// ── Hareketli Arka Plan ───────────────────────────────────────────────────────────
// Öncelik: /public/cyber-bg.mp4 (gerçek video)
// Fallback: CyberCanvas (Canvas animasyonu) — video hatalıysa devreye girer

function CyberVideoBackground() {
    const videoRef   = useRef(null);
    const [showCanvas, setShowCanvas] = useState(false);

    // Video yüklenemezse Canvas animasyonuna düş
    const handleError = () => setShowCanvas(true);

    // Video oynayınca Canvas'ı kapat (performans için)
    const handlePlaying = () => setShowCanvas(false);

    return (
        <>
            {/* Katman 1a: Gerçek MP4 video — fixed, tüm ekran */}
            <video
                ref={videoRef}
                className="cyber-video-bg"
                autoPlay
                loop
                muted
                playsInline
                onError={handleError}
                onPlaying={handlePlaying}
                aria-hidden="true"
            >
                <source src="/cyber-bg.mp4" type="video/mp4" />
            </video>

            {/* Katman 1b: Canvas fallback — sadece video çalışmazsa görünür */}
            {showCanvas && <CyberCanvas />}

            {/* Katman 2: Karartma + blur overlay — metinler okunabilir kalır */}
            <div className="cyber-video-overlay" aria-hidden="true" />
        </>
    );
}

// ── Shared Toaster config ─────────────────────────────────────────────────────

const TOASTER_OPTS = {
    duration: 4000,
    style: {
        background: 'var(--bg-elevated, #1e293b)',
        color:      'var(--text-primary, #f1f5f9)',
        border:     '1px solid var(--border-subtle, rgba(255,255,255,0.08))',
        borderRadius: '12px',
        fontSize:   '0.9rem',
        boxShadow:  '0 8px 32px rgba(0,0,0,0.4)',
        maxWidth:   '400px',
    },
    success: { iconTheme: { primary: '#10b981', secondary: '#fff' } },
    error:   { iconTheme: { primary: '#ef4444', secondary: '#fff' } },
};

// ── Bootstrap spinner ─────────────────────────────────────────────────────────

function BootSpinner() {
    return (
        <div style={{
            minHeight: '100vh', display: 'flex',
            flexDirection: 'column', alignItems: 'center',
            justifyContent: 'center', gap: 16,
        }}>
            <div style={{
                width: 44, height: 44,
                border: '3px solid rgba(59,130,246,0.2)',
                borderTopColor: '#3b82f6',
                borderRadius: '50%',
                animation: 'spin 0.9s linear infinite',
            }} />
            <p style={{ fontSize: '0.82rem', color: 'var(--text-muted)' }}>
                Oturum kontrol ediliyor…
            </p>
        </div>
    );
}

// ── Authenticated layout (header + view routing) ──────────────────────────────

function AuthenticatedApp({ userEmail, onLogout }) {
    const navigate  = useNavigate();
    const location  = useLocation();

    // Derive currentView from pathname for header active state
    const currentView = location.pathname.startsWith('/dashboard') ? 'dashboard' : 'scan';

    const handleViewChange = (view) => {
        navigate(view === 'dashboard' ? '/dashboard' : '/scan');
    };

    return (
        <>
            {/* Hide header on /report/:id pages */}
            {!location.pathname.startsWith('/report/') && (
                <AppHeader
                    email={userEmail}
                    onLogout={onLogout}
                    currentView={currentView}
                    onViewChange={handleViewChange}
                />
            )}
            <Routes>
                {/* Authenticated root → dashboard */}
                <Route path="/"            element={<Navigate to="/dashboard" replace />} />
                <Route path="/login"       element={<Navigate to="/dashboard" replace />} />
                <Route path="/scan"        element={<ScanPage headerOffset />} />
                <Route path="/dashboard"   element={<Dashboard headerOffset />} />
                <Route path="/report/:id"  element={<ReportPage />} />
                <Route path="*"            element={<Navigate to="/dashboard" replace />} />
            </Routes>
        </>
    );
}

// ── Public layout (landing + auth pages) ─────────────────────────────────────

function PublicApp({ onAuthSuccess }) {
    return (
        <Routes>
            <Route path="/"      element={<LandingPage />} />
            <Route path="/login" element={<AuthPage onAuthSuccess={onAuthSuccess} />} />
            <Route path="*"      element={<Navigate to="/" replace />} />
        </Routes>
    );
}

// ── App (session gate) ────────────────────────────────────────────────────────

export default function App() {
    const [session,      setSession]      = useState(null);
    const [initializing, setInitializing] = useState(true);

    useEffect(() => {
        supabase.auth.getSession().then(({ data }) => {
            setSession(data.session ?? false);
            setInitializing(false);
        });

        const { data: { subscription } } = supabase.auth.onAuthStateChange(
            (_event, newSession) => setSession(newSession ?? false)
        );
        return () => subscription.unsubscribe();
    }, []);

    const handleAuthSuccess = useCallback((s) => setSession(s), []);
    const handleLogout      = useCallback(async () => {
        await supabase.auth.signOut();
    }, []);

    if (initializing) return <BootSpinner />;

    return (
        <BrowserRouter>
            {/* ── Hareketli arka plan — tüm sayfalarda görünür ── */}
            <CyberVideoBackground />

            <Toaster position="bottom-right" toastOptions={TOASTER_OPTS} />

            {!session ? (
                <PublicApp onAuthSuccess={handleAuthSuccess} />
            ) : (
                <AuthenticatedApp
                    userEmail={session.user?.email ?? ''}
                    onLogout={handleLogout}
                />
            )}
        </BrowserRouter>
    );
}
