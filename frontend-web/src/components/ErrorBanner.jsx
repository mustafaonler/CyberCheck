// components/ErrorBanner.jsx
// Dismissible error banner with an icon and message.

import React from 'react';

const AlertIcon = () => (
    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2"
        strokeLinecap="round" strokeLinejoin="round" className="error-banner__icon">
        <circle cx="12" cy="12" r="10" />
        <line x1="12" y1="8" x2="12" y2="12" />
        <line x1="12" y1="16" x2="12.01" y2="16" />
    </svg>
);

/**
 * Props:
 *   title   {string}    — short error label
 *   message {string}    — detailed error text
 *   onDismiss {()=>void}
 */
export default function ErrorBanner({ title = 'Bir hata oluştu', message, onDismiss }) {
    if (!message) return null;
    return (
        <div className="error-banner" role="alert" aria-live="assertive">
            <AlertIcon />
            <div className="error-banner__body">
                <div className="error-banner__title">{title}</div>
                <div className="error-banner__message">{message}</div>
            </div>
            {onDismiss && (
                <button
                    className="error-banner__dismiss"
                    onClick={onDismiss}
                    aria-label="Hatayı kapat"
                >
                    ✕
                </button>
            )}
        </div>
    );
}
