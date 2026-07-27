'use client';
import { useState, useEffect } from 'react';

const formatDate = (dateString: string) => {
  const d = new Date(dateString);
  return d.toLocaleDateString('en-GB', { day: '2-digit', month: 'short', year: 'numeric' });
};

const getToday = () => {
  const d = new Date();
  return d.toISOString().split('T')[0];
};

export default function NoticesPage() {
  const [notices, setNotices] = useState<any[]>([]);
  const [loading, setLoading] = useState(true);
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [formData, setFormData] = useState({
    title: '',
    date: getToday(),
    message: ''
  });

  const fetchNotices = async () => {
    try {
      const res = await fetch('/api/notices');
      const data = await res.json();
      if (data.success) {
        setNotices(data.data);
      }
    } catch (error) {
      console.error('Failed to fetch notices:', error);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchNotices();
  }, []);

  const handleChange = (e: React.ChangeEvent<HTMLInputElement | HTMLTextAreaElement>) => {
    setFormData({ ...formData, [e.target.name]: e.target.value });
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setIsSubmitting(true);
    try {
      const res = await fetch('/api/notices', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(formData)
      });
      const data = await res.json();
      if (data.success) {
        alert('اعلان کامیابی سے شامل کر دیا گیا!');
        setFormData({ title: '', date: getToday(), message: '' });
        fetchNotices();
      } else {
        alert(data.message || 'Error adding notice');
      }
    } catch (error) {
      alert('Network error');
    } finally {
      setIsSubmitting(false);
    }
  };

  const handleDelete = async (id: number) => {
    if (!confirm('کیا آپ واقعی یہ اعلان حذف کرنا چاہتے ہیں؟')) return;
    try {
      const res = await fetch(`/api/notices?id=${id}`, { method: 'DELETE' });
      const data = await res.json();
      if (data.success) {
        fetchNotices();
      }
    } catch (error) {
      alert('Failed to delete notice');
    }
  };

  return (
    <div className="p-4 md:p-8 space-y-8 animate-fade-in">
      <div className="flex items-center justify-between bg-white dark:bg-slate-800 p-6 rounded-2xl shadow-sm border border-slate-100 dark:border-slate-700">
        <div>
          <h1 className="text-3xl font-bold text-slate-800 dark:text-white flex items-center gap-3">
            <span className="text-red-500">📢</span> نوٹس بورڈ (اعلانات)
          </h1>
          <p className="text-slate-500 dark:text-slate-400 mt-2">
            مدرسے کے تمام اہم اعلانات کا اندراج اور ریکارڈ
          </p>
        </div>
      </div>

      <div className="grid md:grid-cols-3 gap-6">
        {/* Left Side: Add Notice Form */}
        <div className="md:col-span-1">
          <div className="bg-white dark:bg-slate-800 rounded-2xl shadow-sm border-t-4 border-t-red-500 overflow-hidden">
            <div className="p-4 bg-slate-50 dark:bg-slate-700/50 border-b border-slate-100 dark:border-slate-700">
              <h2 className="font-bold text-lg text-slate-800 dark:text-white flex items-center gap-2">
                <span className="text-red-500">➕</span> نیا اعلان
              </h2>
            </div>
            <div className="p-4">
              <form onSubmit={handleSubmit} className="space-y-4">
                <div>
                  <label className="block text-sm font-semibold mb-1 text-slate-700 dark:text-slate-300">عنوان (Title)</label>
                  <input
                    type="text"
                    name="title"
                    value={formData.title}
                    onChange={handleChange}
                    className="w-full border border-slate-300 dark:border-slate-600 rounded-xl px-3 py-2 bg-white dark:bg-slate-900 focus:ring-2 focus:ring-red-500 outline-none transition"
                    placeholder="مثلاً: چھٹی کا اعلان"
                    required
                  />
                </div>
                <div>
                  <label className="block text-sm font-semibold mb-1 text-slate-700 dark:text-slate-300">تاریخ</label>
                  <input
                    type="date"
                    name="date"
                    value={formData.date}
                    onChange={handleChange}
                    className="w-full border border-slate-300 dark:border-slate-600 rounded-xl px-3 py-2 bg-white dark:bg-slate-900 focus:ring-2 focus:ring-red-500 outline-none transition"
                    required
                  />
                </div>
                <div>
                  <label className="block text-sm font-semibold mb-1 text-slate-700 dark:text-slate-300">تفصیل (Message)</label>
                  <textarea
                    name="message"
                    value={formData.message}
                    onChange={handleChange}
                    rows={4}
                    className="w-full border border-slate-300 dark:border-slate-600 rounded-xl px-3 py-2 bg-white dark:bg-slate-900 focus:ring-2 focus:ring-red-500 outline-none transition"
                    placeholder="اعلان کی تفصیل لکھیں..."
                    required
                  ></textarea>
                </div>
                <button
                  type="submit"
                  disabled={isSubmitting}
                  className="w-full bg-red-500 hover:bg-red-600 text-white font-bold py-2 rounded-xl transition shadow-sm disabled:opacity-50"
                >
                  {isSubmitting ? 'محفوظ ہو رہا ہے...' : 'نوٹس بورڈ پر لگائیں'}
                </button>
              </form>
            </div>
          </div>
        </div>

        {/* Right Side: Notices List */}
        <div className="md:col-span-2">
          <div className="bg-white dark:bg-slate-800 rounded-2xl shadow-sm border border-slate-100 dark:border-slate-700 overflow-hidden">
            <div className="p-4 bg-slate-800 text-white border-b border-slate-700">
              <h2 className="font-bold text-lg">موجودہ اعلانات</h2>
            </div>
            
            {loading ? (
              <div className="p-10 text-center text-slate-500">لوڈ ہو رہا ہے...</div>
            ) : notices.length === 0 ? (
              <div className="p-10 text-center text-slate-500">کوئی اعلان موجود نہیں</div>
            ) : (
              <div className="overflow-x-auto">
                <table className="w-full text-right border-collapse">
                  <thead>
                    <tr className="bg-slate-50 dark:bg-slate-700 text-slate-600 dark:text-slate-300 border-b border-slate-200 dark:border-slate-600">
                      <th className="p-3 w-32">تاریخ</th>
                      <th className="p-3">عنوان / تفصیل</th>
                      <th className="p-3 w-20 text-center">ایکشن</th>
                    </tr>
                  </thead>
                  <tbody>
                    {notices.map((n) => (
                      <tr key={n.id} className="border-b border-slate-100 dark:border-slate-700 hover:bg-slate-50 dark:hover:bg-slate-700/50 transition">
                        <td className="p-3 align-top font-semibold text-slate-600 dark:text-slate-400">
                          {formatDate(n.date)}
                        </td>
                        <td className="p-3">
                          <strong className="text-red-500 block text-lg mb-1">{n.title}</strong>
                          <p className="text-slate-600 dark:text-slate-300 whitespace-pre-wrap leading-relaxed">{n.message}</p>
                        </td>
                        <td className="p-3 align-top text-center">
                          <button
                            onClick={() => handleDelete(n.id)}
                            className="p-2 text-red-500 hover:bg-red-50 dark:hover:bg-red-500/20 rounded-lg transition"
                            title="حذف کریں"
                          >
                            🗑️
                          </button>
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
    </div>
  );
}
