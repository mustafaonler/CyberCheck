import React from 'react';

/**
 * App — CyberCheck Web Panelinin kök bileşeni.
 * İleride buraya Router ve global Provider'lar eklenecek.
 */
function App() {
    return (
        <div style={styles.container}>
            <div style={styles.card}>
                <h1 style={styles.title}>🛡️ CyberCheck</h1>
                <p style={styles.subtitle}>CyberCheck Web Paneline Hoş Geldiniz</p>
                <span style={styles.badge}>v1.0.0 — Geliştirme Modu</span>
            </div>
        </div>
    );
}

const styles = {
    container: {
        minHeight: '100vh',
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
        background: 'linear-gradient(135deg, #0f0c29, #302b63, #24243e)',
        fontFamily: "'Segoe UI', Tahoma, Geneva, Verdana, sans-serif",
    },
    card: {
        background: 'rgba(255, 255, 255, 0.05)',
        backdropFilter: 'blur(10px)',
        border: '1px solid rgba(255, 255, 255, 0.1)',
        borderRadius: '16px',
        padding: '48px 64px',
        textAlign: 'center',
        boxShadow: '0 8px 32px rgba(0, 0, 0, 0.4)',
    },
    title: {
        fontSize: '3rem',
        fontWeight: '700',
        color: '#ffffff',
        margin: '0 0 12px',
        letterSpacing: '-1px',
    },
    subtitle: {
        fontSize: '1.2rem',
        color: 'rgba(255, 255, 255, 0.75)',
        margin: '0 0 24px',
    },
    badge: {
        display: 'inline-block',
        padding: '6px 16px',
        borderRadius: '20px',
        background: 'rgba(99, 102, 241, 0.3)',
        color: '#a5b4fc',
        fontSize: '0.8rem',
        fontWeight: '500',
        border: '1px solid rgba(99, 102, 241, 0.4)',
    },
};

export default App;
