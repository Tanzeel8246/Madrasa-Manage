'use client';
import { useState, useEffect } from 'react';

const formatDate = (dateString: string) => {
  const d = new Date(dateString);
  return d.toLocaleDateString('en-GB', { day: '2-digit', month: 'short', year: 'numeric' });
};

export default function ParentLeavePage() {
  const [user, setUser] = useState<any>(null);
  const [leaves, setLeaves] = useState<any[]>([]);
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [formData, setFormData] = useState({
    date_from: '',
    date_to: '',
    reason: ''
  });

  useEffect(() => {
    const userStr = localStorage.getItem('user');
    if (userStr) {
      const parsed = JSON.parse(userStr);
      setUser(parsed);
      fetchLeaves(parsed.id);
    }
  }, []);

  const fetchLeaves = async (studentId: number) => {
    try {
      const res = await fetch(`/api/parent/leave?student_id=${studentId}`);
      const json = await res.json();
      if (json.success) setLeaves(json.data);
    } catch (e) {
      console.error(e);
    }
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!user) return;
    setIsSubmitting(true);
    
    try {
      const res = await fetch('/api/parent/leave', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          student_id: user.id,
          ...formData
        })
      });
      const json = await res.json();
      if (json.success) {
        alert(json.message);
        setFormData({ date_from: '', date_to: '', reason: '' });
        fetchLeaves(user.id);
      } else {
        alert(json.message);
      }
    } catch (e) {
      alert('نیٹ ورک ایرر');
    } finally {
      setIsSubmitting(false);
    }
  };

  return (
    <div className="p-4 md:p-8 space-y-6 animate-fade-in font-urdu" dir="rtl">
      
      <div className="flex items-center justify-between bg-white dark:bg-slate-800 p-6 rounded-2xl shadow-sm border border-slate-100 dark:border-slate-700">
        <div>
          <h1 className="text-3xl font-bold text-slate-800 dark:text-white flex items-center gap-3">
            <span className="text-yellow-500">✉️</span> چھٹی کی درخواست
          </h1>
          <p className="text-slate-500 dark:text-slate-400 mt-2">
            بیماری یا کسی ضروری کام کی صورت میں چھٹی کے لیے درخواست دیں
          </p>
        </div>
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
        
        {/* Form */}
        <div className="lg:col-span-1 bg-white dark:bg-slate-800 rounded-2xl p-6 shadow-sm border border-slate-100 dark:border-slate-700 h-fit">
          <h2 className="text-xl font-bold mb-4 border-b pb-2">نئی درخواست</h2>
          <form onSubmit={handleSubmit} className="space-y-4">
            <div>
              <label className="block text-sm font-bold mb-1">کب سے (Date From)</label>
              <input type="date" required value={formData.date_from} onChange={(e) => setFormData({...formData, date_from: e.target.value})} className="w-full border rounded-xl px-4 py-2 bg-slate-50 dark:bg-slate-900" />
            </div>
            <div>
              <label className="block text-sm font-bold mb-1">کب تک (Date To)</label>
              <input type="date" required value={formData.date_to} onChange={(e) => setFormData({...formData, date_to: e.target.value})} className="w-full border rounded-xl px-4 py-2 bg-slate-50 dark:bg-slate-900" />
            </div>
            <div>
              <label className="block text-sm font-bold mb-1">وجہ (Reason)</label>
              <textarea required rows={4} value={formData.reason} onChange={(e) => setFormData({...formData, reason: e.target.value})} className="w-full border rounded-xl px-4 py-2 bg-slate-50 dark:bg-slate-900" placeholder="چھٹی کی وجہ لکھیں..."></textarea>
            </div>
            <button type="submit" disabled={isSubmitting} className="w-full bg-yellow-500 hover:bg-yellow-600 text-white font-bold py-3 rounded-xl transition">
              {isSubmitting ? 'بھیج رہا ہے...' : 'درخواست بھیجیں'}
            </button>
          </form>
        </div>

        {/* History */}
        <div className="lg:col-span-2 bg-white dark:bg-slate-800 rounded-2xl shadow-sm border border-slate-100 dark:border-slate-700 overflow-hidden">
          <div className="p-4 bg-slate-800 text-white border-b border-slate-700">
            <h2 className="font-bold">درخواستوں کا ریکارڈ</h2>
          </div>
          <div className="overflow-x-auto">
            <table className="w-full text-right">
              <thead>
                <tr className="bg-slate-50 dark:bg-slate-700 text-sm">
                  <th className="p-4">جمع کرانے کی تاریخ</th>
                  <th className="p-4">چھٹی کے ایام</th>
                  <th className="p-4">وجہ</th>
                  <th className="p-4 text-center">سٹیٹس</th>
                </tr>
              </thead>
              <tbody>
                {leaves.length === 0 ? <tr><td colSpan={4} className="p-8 text-center text-slate-500">کوئی ریکارڈ موجود نہیں</td></tr> :
                  leaves.map(l => (
                  <tr key={l.id} className="border-b dark:border-slate-700">
                    <td className="p-4 text-sm">{formatDate(l.created_at)}</td>
                    <td className="p-4 text-blue-600 font-bold" dir="ltr">{formatDate(l.date_from)} - {formatDate(l.date_to)}</td>
                    <td className="p-4 text-sm">{l.reason}</td>
                    <td className="p-4 text-center">
                      <span className={`text-xs px-3 py-1 rounded-full font-bold ${l.status === 'Approved' ? 'bg-green-100 text-green-700' : l.status === 'Rejected' ? 'bg-red-100 text-red-700' : 'bg-yellow-100 text-yellow-700'}`}>
                        {l.status === 'Approved' ? 'منظور شدہ' : l.status === 'Rejected' ? 'مسترد شدہ' : 'زیرِ التوا'}
                      </span>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </div>

      </div>
    </div>
  );
}
