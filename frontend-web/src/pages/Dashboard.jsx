import React, { useEffect, useState } from 'react';
import { supabase } from '../lib/supabase';
import { PieChart, Pie, Cell, Tooltip, ResponsiveContainer, Legend } from 'recharts';

export default function Dashboard({ headerOffset }) {
    const [scans, setScans] = useState([]);
    const [loading, setLoading] = useState(true);

    useEffect(() => {
        async function fetchScans() {
            const { data: { user } } = await supabase.auth.getUser();
            if (!user) {
                setLoading(false);
                return;
            }
            
            const { data, error } = await supabase
                .from('scans')
                .select('*')
                .eq('user_id', user.id)
                .order('created_at', { ascending: false });

            if (data) setScans(data);
            if (error) console.error('Error fetching scans:', error);
            
            setLoading(false);
        }
        fetchScans();
    }, []);

    // Calculate stats
    const totalScans = scans.length;
    const safeScans = scans.filter(s => s.verdict === 'clean').length;
    const maliciousScans = scans.filter(s => s.verdict === 'malicious').length;
    const suspiciousScans = scans.filter(s => s.verdict === 'suspicious').length;
    
    // Status counts
    const pendingScans = scans.filter(s => s.status === 'PENDING').length;

    const chartData = [
        { name: 'Güvenli (Safe)', value: safeScans, color: '#10b981' }, // var(--color-success)
        { name: 'Kritik (Malicious)', value: maliciousScans, color: '#ef4444' }, // var(--color-danger)
        { name: 'Şüpheli (Suspicious)', value: suspiciousScans, color: '#f59e0b' } // var(--color-warning)
    ].filter(item => item.value > 0);

    if (loading) {
        return (
            <div className="dashboard-container" style={{ paddingTop: headerOffset ? 100 : 24 }}>
                <div style={{ display: 'flex', justifyContent: 'center', padding: '50px' }}>
                    <div className="boot-spinner" style={{
                        width: 44, height: 44,
                        border: '3px solid rgba(59,130,246,0.2)',
                        borderTopColor: '#3b82f6',
                        borderRadius: '50%',
                        animation: 'spin 0.9s linear infinite'
                    }} />
                </div>
            </div>
        );
    }

    return (
        <div className="dashboard-container" style={{ paddingTop: headerOffset ? 100 : 24, animation: 'fadeIn 0.5s ease' }}>
            <div className="dashboard-header">
                <h2>Geçmiş Taramalarım (Threat Dashboard)</h2>
                <p>Toplam Tarama: {totalScans} | Bekleyen: {pendingScans}</p>
            </div>
            
            <div className="dashboard-content">
                <div className="chart-section dashboard-card">
                    <h3>Risk Dağılımı</h3>
                    {totalScans === 0 ? (
                        <p style={{ color: 'var(--text-muted)' }}>Henüz tarama verisi yok.</p>
                    ) : (
                        <div style={{ height: 300, marginTop: 20 }}>
                            <ResponsiveContainer width="100%" height="100%">
                                <PieChart>
                                    <Pie
                                        data={chartData}
                                        cx="50%"
                                        cy="50%"
                                        innerRadius={65}
                                        outerRadius={90}
                                        paddingAngle={5}
                                        dataKey="value"
                                        stroke="none"
                                    >
                                        {chartData.map((entry, index) => (
                                            <Cell key={`cell-${index}`} fill={entry.color} />
                                        ))}
                                    </Pie>
                                    <Tooltip 
                                        contentStyle={{ 
                                            backgroundColor: 'var(--bg-elevated)', 
                                            borderColor: 'var(--border-subtle)', 
                                            color: 'var(--text-primary)', 
                                            borderRadius: 'var(--radius-sm)' 
                                        }}
                                        itemStyle={{ color: 'var(--text-primary)' }}
                                    />
                                    <Legend verticalAlign="bottom" height={36}/>
                                </PieChart>
                            </ResponsiveContainer>
                        </div>
                    )}
                </div>

                <div className="table-section dashboard-card">
                    <h3>Tarama Geçmişi</h3>
                    {totalScans === 0 ? (
                        <p style={{ color: 'var(--text-muted)' }}>Tarama geçmişiniz boş.</p>
                    ) : (
                        <div className="table-wrapper">
                            <table className="scan-table">
                                <thead>
                                    <tr>
                                        <th>Tarih</th>
                                        <th>Tip</th>
                                        <th>Durum</th>
                                        <th>Risk / Sonuç</th>
                                    </tr>
                                </thead>
                                <tbody>
                                    {scans.map(scan => (
                                        <tr key={scan.id}>
                                            <td>{new Date(scan.created_at).toLocaleString('tr-TR')}</td>
                                            <td style={{ fontWeight: 500 }}>
                                                <span title={scan.file_name}>
                                                    {scan.file_name?.includes('http') || scan.file_name?.includes('URL') ? '🔗 ' : 
                                                     scan.file_name?.includes('Yapay Zeka') ? '📧 ' : '📁 '}
                                                    {scan.file_name?.length > 25 ? scan.file_name.substring(0, 25) + '...' : scan.file_name || 'Bilinmeyen Dosya'}
                                                </span>
                                            </td>
                                            <td>
                                                <span className={`status-badge ${scan.status?.toLowerCase() || 'pending'}`}>
                                                    {scan.status || 'PENDING'}
                                                </span>
                                            </td>
                                            <td>
                                                <span className={`verdict-badge ${scan.verdict?.toLowerCase() || 'unknown'}`}>
                                                    {scan.verdict === 'clean' ? '✅ Güvenli' : 
                                                     scan.verdict === 'malicious' ? '🚨 Kritik' : 
                                                     scan.verdict === 'suspicious' ? '⚠️ Şüpheli' : '⏳ Bilinmiyor'}
                                                </span>
                                            </td>
                                        </tr>
                                    ))}
                                </tbody>
                            </table>
                        </div>
                    )}
                </div>
            </div>
        </div>
    );
}
