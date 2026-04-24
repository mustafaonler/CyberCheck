// components/AppHeader.jsx
// Fixed top bar shown only when user is authenticated.

import React from 'react';

const ShieldIcon = () => (
    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor"
        strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round"
        className="app-header__brand-icon">
        <path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z" />
    </svg>
);

const LogoutIcon = () => (
    <svg width="14" height="14" viewBox="0 0 24 24" fill="none"
        stroke="currentColor" strokeWidth="2.2"
        strokeLinecap="round" strokeLinejoin="round">
        <path d="M9 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h4" />
        <polyline points="16 17 21 12 16 7" />
        <line x1="21" y1="12" x2="9" y2="12" />
    </svg>
);

/**
 * Props:
 *   email     {string}    — logged-in user's email
 *   onLogout  {()=>void}  — called when Çıkış Yap is clicked
 */
export default function AppHeader({ email, onLogout }) {
    // Two-letter initials for the avatar
    const initials = email
        ? email.slice(0, 2).toUpperCase()
        : '??';

    return (
        <header className="app-header" role="banner">
            {/* Brand */}
            <div className="app-header__brand">
                <ShieldIcon />
                <span className="app-header__brand-name">CyberCheck</span>
            </div>

            {/* User info + logout */}
            <div className="app-header__user">
                <span className="app-header__email" title={email}>
                    {email}
                </span>
                <div
                    className="app-header__avatar"
                    aria-label={`Kullanıcı: ${email}`}
                    title={email}
                >
                    {initials}
                </div>
                <button
                    id="btn-logout"
                    className="btn-logout"
                    onClick={onLogout}
                    aria-label="Çıkış yap"
                >
                    <LogoutIcon />
                    Çıkış Yap
                </button>
            </div>
        </header>
    );
}
