// pages/AuthPage.jsx
// Login & Register UI backed by Supabase Auth.

import React, { useState } from 'react';
import { supabase } from '../lib/supabase.js';
import '../components/AuthPage.css';

// ── SVG icons ─────────────────────────────────────────────────

const ShieldIcon = (props) => (
    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor"
        strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round" {...props}>
        <path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z" />
    </svg>
);

const MailIcon = () => (
    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor"
        strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round"
        className="auth-form__input-icon">
        <path d="M4 4h16c1.1 0 2 .9 2 2v12c0 1.1-.9 2-2 2H4c-1.1 0-2-.9-2-2V6c0-1.1.9-2 2-2z" />
        <polyline points="22,6 12,13 2,6" />
    </svg>
);

const LockIcon = () => (
    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor"
        strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round"
        className="auth-form__input-icon">
        <rect x="3" y="11" width="18" height="11" rx="2" ry="2" />
        <path d="M7 11V7a5 5 0 0 1 10 0v4" />
    </svg>
);

const UserIcon = () => (
    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor"
        strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round"
        className="auth-form__input-icon">
        <path d="M20 21v-2a4 4 0 0 0-4-4H8a4 4 0 0 0-4 4v2" />
        <circle cx="12" cy="7" r="4" />
    </svg>
);

const EyeIcon = ({ off }) => (
    <svg width="16" height="16" viewBox="0 0 24 24" fill="none"
        stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
        {off ? (
            <>
                <path d="M17.94 17.94A10.07 10.07 0 0 1 12 20c-7 0-11-8-11-8a18.45 18.45 0 0 1 5.06-5.94" />
                <path d="M9.9 4.24A9.12 9.12 0 0 1 12 4c7 0 11 8 11 8a18.5 18.5 0 0 1-2.16 3.19" />
                <line x1="1" y1="1" x2="23" y2="23" />
            </>
        ) : (
            <>
                <path d="M1 12s4-8 11-8 11 8 11 8-4 8-11 8-11-8-11-8z" />
                <circle cx="12" cy="12" r="3" />
            </>
        )}
    </svg>
);

const CheckCircleIcon = (props) => (
    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor"
        strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"
        {...props}>
        <path d="M22 11.08V12a10 10 0 1 1-5.93-9.14" />
        <polyline points="22 4 12 14.01 9 11.01" />
    </svg>
);

const SmallLockIcon = () => (
    <svg width="13" height="13" viewBox="0 0 24 24" fill="none"
        stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
        <rect x="3" y="11" width="18" height="11" rx="2" ry="2" />
        <path d="M7 11V7a5 5 0 0 1 10 0v4" />
    </svg>
);

const ArrowLeftIcon = () => (
    <svg width="18" height="18" viewBox="0 0 24 24" fill="none"
        stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
        <line x1="19" y1="12" x2="5" y2="12"></line>
        <polyline points="12 19 5 12 12 5"></polyline>
    </svg>
);


// ── AuthPage ──────────────────────────────────────────────────

/**
 * Props:
 *   onAuthSuccess  — called with the Supabase session after successful login/register
 */
export default function AuthPage({ onAuthSuccess }) {
    const [tab,         setTab]         = useState('login');    // 'login' | 'register'
    const [fullName,    setFullName]    = useState('');
    const [email,       setEmail]       = useState('');
    const [password,    setPassword]    = useState('');
    const [confirmPw,   setConfirmPw]   = useState('');
    const [showPw,      setShowPw]      = useState(false);
    const [loading,     setLoading]     = useState(false);
    const [error,       setError]       = useState(null);
    const [regSuccess,  setRegSuccess]  = useState(false);

    const switchTab = (t) => {
        setTab(t);
        setError(null);
    };

    const resetToLogin = () => {
        setRegSuccess(false);
        setTab('login');
        setPassword('');
        setConfirmPw('');
    };

    const handleSubmit = async (e) => {
        e.preventDefault();
        setError(null);

        if (tab === 'register') {
            if (!fullName.trim()) return setError('Ad Soyad gereklidir.');
        }
        if (!email.trim()) return setError('E-posta adresi gereklidir.');
        if (password.length < 6) return setError('Şifre en az 6 karakter olmalıdır.');

        if (tab === 'register' && password !== confirmPw) {
            return setError('Şifreler eşleşmiyor.');
        }

        setLoading(true);

        try {
            if (tab === 'login') {
                // ── Sign in ──────────────────────────────────
                const { data, error: supaErr } = await supabase.auth.signInWithPassword({
                    email:    email.trim(),
                    password,
                });
                if (supaErr) throw supaErr;
                onAuthSuccess(data.session);

            } else {
                // ── Register ─────────────────────────────────
                const { data, error: supaErr } = await supabase.auth.signUp({
                    email:    email.trim(),
                    password,
                    options: {
                        data: {
                            full_name: fullName.trim(),
                        }
                    }
                });
                if (supaErr) throw supaErr;

                // Supabase sends a confirmation email
                setRegSuccess(true);
            }
        } catch (err) {
            console.error('[AuthPage]', err.message);
            setError(mapSupabaseError(err.message));
        } finally {
            setLoading(false);
        }
    };

    return (
        <div className="auth-page">
            {/* Logo */}
            <header className="auth-page__header">
                <div className="auth-page__logo">
                    <ShieldIcon className="auth-page__logo-icon" />
                    <span className="auth-page__logo-text">CyberCheck</span>
                </div>
                <p className="auth-page__tagline">Dosya Güvenlik Tarama Sistemi</p>
            </header>

            {/* Card */}
            <div className="auth-card" role="main">
                {regSuccess ? (
                    // ── Registration Success Screen ───────────
                    <div className="auth-success-screen">
                        <CheckCircleIcon className="auth-success-screen__icon" />
                        <h2 className="auth-success-screen__title">Kayıt Başarılı!</h2>
                        <p className="auth-success-screen__text">
                            Lütfen e-posta adresinize gelen doğrulama linkine tıklayarak hesabınızı onaylayın.
                        </p>
                        <button className="btn-secondary" onClick={resetToLogin} style={{ marginTop: '8px' }}>
                            <ArrowLeftIcon />
                            Giriş Ekranına Dön
                        </button>
                    </div>
                ) : (
                    <>
                        {/* Tab switcher */}
                        <div className="auth-tabs" role="tablist" aria-label="Kimlik doğrulama seçenekleri">
                            <button
                                id="tab-login"
                                role="tab"
                                aria-selected={tab === 'login'}
                                className={`auth-tab ${tab === 'login' ? 'auth-tab--active' : ''}`}
                                onClick={() => switchTab('login')}
                            >
                                Giriş Yap
                            </button>
                            <button
                                id="tab-register"
                                role="tab"
                                aria-selected={tab === 'register'}
                                className={`auth-tab ${tab === 'register' ? 'auth-tab--active' : ''}`}
                                onClick={() => switchTab('register')}
                            >
                                Kayıt Ol
                            </button>
                        </div>

                        {/* Form */}
                        <form
                            className="auth-form"
                            onSubmit={handleSubmit}
                            aria-label={tab === 'login' ? 'Giriş formu' : 'Kayıt formu'}
                            noValidate
                        >
                            {/* Full Name (Register only) */}
                            {tab === 'register' && (
                                <div className="auth-form__group">
                                    <label htmlFor="auth-fullname" className="auth-form__label">
                                        Ad Soyad
                                    </label>
                                    <div className="auth-form__input-wrap">
                                        <input
                                            id="auth-fullname"
                                            type="text"
                                            className="auth-form__input"
                                            placeholder="Adınız Soyadınız"
                                            value={fullName}
                                            onChange={(e) => setFullName(e.target.value)}
                                            autoComplete="name"
                                            required
                                            aria-required="true"
                                        />
                                        <UserIcon />
                                    </div>
                                </div>
                            )}

                            {/* Email */}
                            <div className="auth-form__group">
                                <label htmlFor="auth-email" className="auth-form__label">
                                    E-Posta
                                </label>
                                <div className="auth-form__input-wrap">
                                    <input
                                        id="auth-email"
                                        type="email"
                                        className="auth-form__input"
                                        placeholder="ornek@domain.com"
                                        value={email}
                                        onChange={(e) => setEmail(e.target.value)}
                                        autoComplete="email"
                                        required
                                        aria-required="true"
                                    />
                                    <MailIcon />
                                </div>
                            </div>

                            {/* Password */}
                            <div className="auth-form__group">
                                <label htmlFor="auth-password" className="auth-form__label">
                                    Şifre
                                </label>
                                <div className="auth-form__input-wrap">
                                    <input
                                        id="auth-password"
                                        type={showPw ? 'text' : 'password'}
                                        className="auth-form__input"
                                        placeholder={tab === 'register' ? 'En az 6 karakter' : '••••••••'}
                                        value={password}
                                        onChange={(e) => setPassword(e.target.value)}
                                        autoComplete={tab === 'login' ? 'current-password' : 'new-password'}
                                        required
                                        aria-required="true"
                                    />
                                    <LockIcon />
                                    <button
                                        type="button"
                                        className="auth-form__pw-toggle"
                                        onClick={() => setShowPw((v) => !v)}
                                        aria-label={showPw ? 'Şifreyi gizle' : 'Şifreyi göster'}
                                    >
                                        <EyeIcon off={showPw} />
                                    </button>
                                </div>
                            </div>

                            {/* Confirm Password (Register only) */}
                            {tab === 'register' && (
                                <div className="auth-form__group">
                                    <label htmlFor="auth-confirm-password" className="auth-form__label">
                                        Şifre Tekrarı
                                    </label>
                                    <div className="auth-form__input-wrap">
                                        <input
                                            id="auth-confirm-password"
                                            type={showPw ? 'text' : 'password'}
                                            className="auth-form__input"
                                            placeholder="Şifrenizi tekrar girin"
                                            value={confirmPw}
                                            onChange={(e) => setConfirmPw(e.target.value)}
                                            autoComplete="new-password"
                                            required
                                            aria-required="true"
                                        />
                                        <LockIcon />
                                    </div>
                                </div>
                            )}

                            {/* Error */}
                            {error && (
                                <div role="alert" aria-live="assertive"
                                    style={{
                                        padding: '10px 14px',
                                        borderRadius: '8px',
                                        background: 'rgba(239,68,68,0.1)',
                                        border: '1px solid rgba(239,68,68,0.28)',
                                        fontSize: '0.8rem',
                                        color: '#fca5a5',
                                        lineHeight: 1.5,
                                        animation: 'fadeInUp 0.25s ease both',
                                    }}
                                >
                                    {error}
                                </div>
                            )}

                            {/* Submit */}
                            <button
                                id={tab === 'login' ? 'btn-login' : 'btn-register'}
                                type="submit"
                                className="auth-form__submit"
                                disabled={loading}
                                aria-busy={loading}
                            >
                                {loading ? (
                                    <>
                                        <span className="auth-form__submit-spinner" aria-hidden="true" />
                                        {tab === 'login' ? 'Giriş yapılıyor…' : 'Kayıt oluşturuluyor…'}
                                    </>
                                ) : (
                                    tab === 'login' ? 'Giriş Yap' : 'Kayıt Ol'
                                )}
                            </button>
                        </form>
                    </>
                )}
            </div>

            {/* Footer */}
            <p className="auth-page__footer">
                <SmallLockIcon />
                Verileriniz Supabase ile şifreli olarak saklanır.
            </p>
        </div>
    );
}

// ── Error message localisation ────────────────────────────────

function mapSupabaseError(msg) {
    if (!msg) return 'Bilinmeyen bir hata oluştu.';
    const m = msg.toLowerCase();
    if (m.includes('invalid login credentials') || m.includes('invalid email or password'))
        return 'E-posta veya şifre hatalı. Lütfen tekrar deneyin.';
    if (m.includes('email not confirmed'))
        return 'E-posta adresiniz henüz doğrulanmamış. Gelen kutunuzu kontrol edin.';
    if (m.includes('user already registered') || m.includes('already been registered'))
        return 'Bu e-posta adresiyle zaten bir hesap mevcut. Giriş yapmayı deneyin.';
    if (m.includes('password should be at least'))
        return 'Şifre en az 6 karakter olmalıdır.';
    if (m.includes('rate limit') || m.includes('too many requests'))
        return 'Çok fazla deneme yapıldı. Lütfen birkaç dakika bekleyin.';
    if (m.includes('network') || m.includes('fetch'))
        return 'Sunucuya bağlanılamadı. İnternet bağlantınızı kontrol edin.';
    return msg;
}
