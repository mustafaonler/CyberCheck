// components/DropZone.jsx
// Drag-and-drop / click-to-select file input area.

import React, { useRef, useState, useCallback } from 'react';

/** Formats bytes into a human-readable string, e.g. "2.4 MB" */
const formatBytes = (bytes) => {
    if (bytes === 0) return '0 B';
    const k = 1024;
    const sizes = ['B', 'KB', 'MB', 'GB'];
    const i = Math.floor(Math.log(bytes) / Math.log(k));
    return `${parseFloat((bytes / Math.pow(k, i)).toFixed(2))} ${sizes[i]}`;
};

/** SVG icon: cloud upload */
const UploadIcon = () => (
    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.6"
        strokeLinecap="round" strokeLinejoin="round" className="dropzone__icon">
        <polyline points="16 16 12 12 8 16" />
        <line x1="12" y1="12" x2="12" y2="21" />
        <path d="M20.39 18.39A5 5 0 0 0 18 9h-1.26A8 8 0 1 0 3 16.3" />
    </svg>
);

/** SVG icon: document / file */
const FileIcon = () => (
    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8"
        strokeLinecap="round" strokeLinejoin="round" className="file-preview__icon">
        <path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z" />
        <polyline points="14 2 14 8 20 8" />
        <line x1="9" y1="13" x2="15" y2="13" />
        <line x1="9" y1="17" x2="13" y2="17" />
    </svg>
);

const ACCEPTED_TYPES = ['image/png', 'image/jpeg', 'image/gif', 'image/webp', 'image/bmp', 'application/pdf'];
const ACCEPTED_LABEL = ['.png', '.jpg', '.gif', '.webp', '.bmp', '.pdf'];

/**
 * DropZone — handles drag-over, drop, and click-to-open-dialog.
 *
 * Props:
 *   file    {File|null}    — currently selected file
 *   onFile  {(File)=>void} — called when a new file is picked
 *   onClear {()=>void}     — called when user removes the file
 */
export default function DropZone({ file, onFile, onClear }) {
    const inputRef = useRef(null);
    const [dragOver, setDragOver] = useState(false);

    const handleFiles = useCallback((files) => {
        if (!files || files.length === 0) return;
        const picked = files[0];
        if (!ACCEPTED_TYPES.includes(picked.type)) {
            onFile(null, `Desteklenmeyen dosya türü: "${picked.type}". Lütfen bir resim veya PDF yükleyin.`);
            return;
        }
        onFile(picked);
    }, [onFile]);

    // ── Drag events ──────────────────────────────────────────
    const onDragEnter = (e) => { e.preventDefault(); e.stopPropagation(); setDragOver(true); };
    const onDragLeave = (e) => { e.preventDefault(); e.stopPropagation(); setDragOver(false); };
    const onDragOver  = (e) => { e.preventDefault(); e.stopPropagation(); };
    const onDrop = (e) => {
        e.preventDefault();
        e.stopPropagation();
        setDragOver(false);
        handleFiles(e.dataTransfer.files);
    };

    const onInputChange = (e) => handleFiles(e.target.files);
    const openDialog   = () => inputRef.current?.click();

    // Keyboard support — activate on Space / Enter
    const onKeyDown = (e) => {
        if (e.key === ' ' || e.key === 'Enter') { e.preventDefault(); openDialog(); }
    };

    const zoneClass = [
        'dropzone',
        dragOver ? 'drag-over' : '',
        file     ? 'has-file'  : '',
    ].filter(Boolean).join(' ');

    return (
        <div className="dropzone-wrapper">
            <div
                id="drop-zone"
                className={zoneClass}
                onClick={openDialog}
                onDragEnter={onDragEnter}
                onDragLeave={onDragLeave}
                onDragOver={onDragOver}
                onDrop={onDrop}
                onKeyDown={onKeyDown}
                tabIndex={0}
                role="button"
                aria-label="Dosya yükle veya bırak"
            >
                <input
                    ref={inputRef}
                    id="file-input"
                    type="file"
                    className="dropzone__input"
                    accept={ACCEPTED_TYPES.join(',')}
                    onChange={onInputChange}
                />

                {file ? (
                    /* ── File selected — show preview ── */
                    <div className="file-preview" onClick={(e) => e.stopPropagation()}>
                        <div className="file-preview__icon-wrap">
                            <FileIcon />
                        </div>
                        <div className="file-preview__info">
                            <div className="file-preview__name" title={file.name}>
                                {file.name}
                            </div>
                            <div className="file-preview__meta">
                                <span className="file-preview__size">{formatBytes(file.size)}</span>
                                <span>·</span>
                                <span>{file.type || 'unknown'}</span>
                            </div>
                        </div>
                        <button
                            className="file-preview__clear"
                            onClick={(e) => { e.stopPropagation(); onClear(); }}
                            aria-label="Dosyayı kaldır"
                        >
                            Kaldır
                        </button>
                    </div>
                ) : (
                    /* ── Empty — show invitation UI ── */
                    <>
                        <div className="dropzone__icon-wrap">
                            <UploadIcon />
                        </div>
                        <p className="dropzone__headline">
                            {dragOver ? 'Dosyayı bırakın!' : 'Dosyanızı sürükleyip bırakın'}
                        </p>
                        <p className="dropzone__sub">
                            veya <span>tıklayarak seçin</span>
                        </p>
                        <div className="dropzone__types">
                            {ACCEPTED_LABEL.map((t) => (
                                <span key={t} className="dropzone__type-chip">{t}</span>
                            ))}
                        </div>
                    </>
                )}
            </div>
        </div>
    );
}
