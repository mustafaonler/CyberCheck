// App.jsx
// Root component — manages auth session and renders the correct screen.
//
// Flow:
//   initializing → (Supabase session check) →
//     ├─ not logged in  → <AuthPage>
//     └─ logged in      → <AppHeader> + <ScanPage>

import React, { useState, useEffect, useCallback } from 'react';
import { supabase }   from './lib/supabase.js';
import AuthPage       from './pages/AuthPage.jsx';
import ScanPage       from './pages/ScanPage.jsx';
import Dashboard      from './pages/Dashboard.jsx';
import AppHeader      from './components/AppHeader.jsx';

// ── Bootstrap spinner (shown only during the initial session check) ──

function BootSpinner() {
    return (
        <div style={{
            minHeight: '100vh',
            display: 'flex',
            flexDirection: 'column',
            alignItems: 'center',
            justifyContent: 'center',
            gap: 16,
        }}>
            <div style={{
                width: 44,
                height: 44,
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

// ── App ────────────────────────────────────────────────────────

export default function App() {
    const [session,      setSession]      = useState(null);
    const [initializing, setInitializing] = useState(true);
    const [currentView,  setCurrentView]  = useState('scan'); // 'scan' | 'dashboard'

    // ── On mount: read existing session & subscribe to auth events ──
    useEffect(() => {
        // 1. Check for an existing session immediately
        supabase.auth.getSession().then(({ data }) => {
            setSession(data.session ?? false);
            setInitializing(false);
        });

        // 2. Subscribe to future auth state changes
        //    (login, logout, token refresh, etc.)
        const { data: { subscription } } = supabase.auth.onAuthStateChange(
            (_event, newSession) => {
                setSession(newSession ?? false);
            }
        );

        return () => subscription.unsubscribe();
    }, []);

    // ── Auth success callback from <AuthPage> ─────────────────
    const handleAuthSuccess = useCallback((newSession) => {
        setSession(newSession);
    }, []);

    // ── Logout ────────────────────────────────────────────────
    const handleLogout = useCallback(async () => {
        await supabase.auth.signOut();
        // onAuthStateChange will fire → session becomes null/false
    }, []);

    // ── Render ────────────────────────────────────────────────

    // Still reading the stored session
    if (initializing) return <BootSpinner />;

    // Not authenticated → show Login / Register
    if (!session) return <AuthPage onAuthSuccess={handleAuthSuccess} />;

    // Authenticated → show scanning interface with header
    const userEmail = session.user?.email ?? '';

    return (
        <>
            <AppHeader 
                email={userEmail} 
                onLogout={handleLogout} 
                currentView={currentView}
                onViewChange={setCurrentView}
            />
            {currentView === 'scan' ? (
                <ScanPage headerOffset />
            ) : (
                <Dashboard headerOffset />
            )}
        </>
    );
}
