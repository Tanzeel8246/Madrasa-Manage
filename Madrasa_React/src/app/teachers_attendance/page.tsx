'use client';
import { useState, useEffect } from 'react';
import Link from 'next/link';

export default function TeachersAttendancePage() {
  const [date, setDate] = useState<string>(new Date().toISOString().split('T')[0]);
  const [teachers, setTeachers] = useState<any[]>([]);
  const [loading, setLoading] = useState(false);
  const [saving, setSaving] = useState(false);

  const fetchAttendance = async () => {
    setLoading(true);
    try {
      const res = await fetch(`/api/teachers_attendance?date=${date}`);
      const data = await res.json();
      if (data.success) {
        setTeachers(data.data);
      }
    } catch (error) {
      console.error(error);
    }
    setLoading(false);
  };

  useEffect(() => {
    fetchAttendance();
  }, [date]);

  const updateStatus = (id: number, status: string) => {
    setTeachers(prev => prev.map(t => t.id === id ? { ...t, status } : t));
  };

  const markAll = (status: string) => {
    setTeachers(prev => prev.map(t => ({ ...t, status })));
  };

  const saveAttendance = async () => {
    setSaving(true);
    try {
      const payload = {
        date,
        teachers: teachers.map(t => ({ id: t.id, status: t.status, late_minutes: t.late_minutes || 0 }))
      };
      
      const res = await fetch('/api/teachers_attendance', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(payload)
      });
      const data = await res.json();
      
      if (data.success) {
        alert('اساتذہ کی حاضری کامیابی سے محفوظ ہو گئی!');
      } else {
        alert('Error: ' + data.message);
      }
    } catch (error) {
      console.error(error);
      alert('Error saving attendance');
    }
    setSaving(false);
  };

  return (
    <div className="p-4 sm:p-8 space-y-6 bg-slate-50 dark:bg-slate-900 min-h-screen">
      <div className="flex flex-col sm:flex-row justify-between items-center bg-white dark:bg-slate-800 p-6 rounded-2xl shadow-sm border border-slate-200 dark:border-slate-700 gap-4">
        <h1 className="text-2xl font-bold text-slate-800 dark:text-white flex items-center gap-3">
          <span className="text-3xl">👨‍🏫</span> اساتذہ کی یومیہ حاضری
        </h1>
        
        <div className="flex items-center gap-4">
          <Link href="/teachers_attendance_report" className="px-5 py-2 bg-blue-600 text-white font-bold rounded-xl shadow hover:bg-blue-700 transition flex items-center gap-2">
            📊 اساتذہ حاضری رپورٹ دیکھیں
          </Link>
          <input 
            type="date" 
            className="px-4 py-2 border border-slate-300 dark:border-slate-600 rounded-xl bg-slate-50 dark:bg-slate-700 text-slate-800 dark:text-white font-medium"
            value={date}
            onChange={e => setDate(e.target.value)}
          />
        </div>
      </div>

      <div className="bg-white dark:bg-slate-800 rounded-2xl shadow-sm border border-slate-200 dark:border-slate-700 overflow-hidden">
        <div className="p-4 bg-slate-50 dark:bg-slate-700/50 flex justify-between items-center border-b border-slate-200 dark:border-slate-700">
          <h2 className="text-lg font-bold text-slate-800 dark:text-white">اساتذہ کی فہرست</h2>
          <div className="flex gap-2">
             <button onClick={() => markAll('P')} className="px-3 py-1 bg-green-100 text-green-700 rounded hover:bg-green-200 text-sm font-bold">سب کو حاضر کریں</button>
             <button onClick={() => markAll('A')} className="px-3 py-1 bg-red-100 text-red-700 rounded hover:bg-red-200 text-sm font-bold">سب کو غیر حاضر کریں</button>
             <button onClick={() => markAll('L')} className="px-3 py-1 bg-yellow-100 text-yellow-700 rounded hover:bg-yellow-200 text-sm font-bold">سب کو رخصت کریں</button>
          </div>
        </div>

        {loading ? (
          <div className="p-8 text-center text-slate-500 font-bold">ڈیٹا لوڈ ہو رہا ہے...</div>
        ) : (
          <div className="overflow-x-auto">
            <table className="w-full text-right" style={{ direction: 'rtl' }}>
              <thead className="bg-slate-100 dark:bg-slate-700 text-slate-600 dark:text-slate-200 font-semibold text-sm">
                <tr>
                  <th className="p-4 w-16">#</th>
                  <th className="p-4">استاد کا نام</th>
                  <th className="p-4 text-center">حاضری کی حیثیت</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-slate-100 dark:divide-slate-700/50">
                {teachers.map((t, idx) => (
                  <tr key={t.id} className="hover:bg-slate-50 dark:hover:bg-slate-700/50 transition">
                    <td className="p-4 text-slate-600 dark:text-slate-400 font-medium">{idx + 1}</td>
                    <td className="p-4 font-bold text-slate-800 dark:text-slate-100">{t.name}</td>
                    <td className="p-4">
                      <div className="flex flex-col items-center gap-2">
                        <div className="flex justify-center gap-4">
                          <label className={`flex items-center gap-2 px-4 py-2 rounded-lg cursor-pointer transition border ${t.status === 'P' ? 'bg-green-100 border-green-500 text-green-700' : 'bg-slate-50 dark:bg-slate-800 border-slate-200 dark:border-slate-600 text-slate-500'}`}>
                            <input type="radio" name={`status-${t.id}`} checked={t.status === 'P'} onChange={() => updateStatus(t.id, 'P')} className="hidden" />
                            <div className={`w-4 h-4 rounded-full border-2 ${t.status === 'P' ? 'border-green-600 bg-green-500' : 'border-slate-300'}`}></div>
                            حاضر (P)
                          </label>
                          <label className={`flex items-center gap-2 px-4 py-2 rounded-lg cursor-pointer transition border ${t.status === 'A' ? 'bg-red-100 border-red-500 text-red-700' : 'bg-slate-50 dark:bg-slate-800 border-slate-200 dark:border-slate-600 text-slate-500'}`}>
                            <input type="radio" name={`status-${t.id}`} checked={t.status === 'A'} onChange={() => updateStatus(t.id, 'A')} className="hidden" />
                            <div className={`w-4 h-4 rounded-full border-2 ${t.status === 'A' ? 'border-red-600 bg-red-500' : 'border-slate-300'}`}></div>
                            غیر حاضر (A)
                          </label>
                          <label className={`flex items-center gap-2 px-4 py-2 rounded-lg cursor-pointer transition border ${t.status === 'L' ? 'bg-yellow-100 border-yellow-500 text-yellow-700' : 'bg-slate-50 dark:bg-slate-800 border-slate-200 dark:border-slate-600 text-slate-500'}`}>
                            <input type="radio" name={`status-${t.id}`} checked={t.status === 'L'} onChange={() => updateStatus(t.id, 'L')} className="hidden" />
                            <div className={`w-4 h-4 rounded-full border-2 ${t.status === 'L' ? 'border-yellow-600 bg-yellow-500' : 'border-slate-300'}`}></div>
                            رخصت (L)
                          </label>
                        </div>
                        {t.status === 'P' && (
                          <div className="flex items-center gap-2 mt-1">
                            <label className="text-sm font-bold text-slate-700 dark:text-slate-300">تاخیر (منٹ):</label>
                            <input 
                              type="number" 
                              min="0"
                              className="w-20 px-2 py-1 rounded border border-slate-300 dark:border-slate-600 bg-white dark:bg-slate-700 text-slate-800 dark:text-white"
                              value={t.late_minutes || 0}
                              onChange={(e) => setTeachers(prev => prev.map(pt => pt.id === t.id ? { ...pt, late_minutes: parseInt(e.target.value) || 0 } : pt))}
                            />
                          </div>
                        )}
                      </div>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </div>

      <div className="flex justify-center">
        <button 
          onClick={saveAttendance}
          disabled={saving}
          className="px-10 py-3 bg-theme-primary text-white font-bold text-lg rounded-xl shadow-lg hover:bg-theme-secondary transition disabled:opacity-50"
        >
          {saving ? 'محفوظ کیا جا رہا ہے...' : 'حاضری محفوظ کریں'}
        </button>
      </div>
    </div>
  );
}
