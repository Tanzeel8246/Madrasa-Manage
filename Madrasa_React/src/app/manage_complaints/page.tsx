'use client';
import { useState, useEffect } from 'react';
import Link from 'next/link';

const formatDate = (dateString: string) => {
  const d = new Date(dateString);
  return d.toLocaleDateString('en-GB', { day: '2-digit', month: 'short', year: 'numeric' });
};

export default function ManageComplaintsPage() {
  const [complaints, setComplaints] = useState<any[]>([]);
  const [loading, setLoading] = useState(true);

  const fetchData = async () => {
    try {
      const res = await fetch('/api/manage_complaints');
      const data = await res.json();
      if (data.success) {
        setComplaints(data.data);
      }
    } catch (error) {
      console.error('Failed to fetch data:', error);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchData();
  }, []);

  const handleDelete = async (id: number) => {
    if (!confirm('کیا آپ واقعی یہ ریکارڈ حذف کرنا چاہتے ہیں؟')) return;
    try {
      const res = await fetch(`/api/manage_complaints?id=${id}`, { method: 'DELETE' });
      const data = await res.json();
      if (data.success) {
        fetchData();
      }
    } catch (error) {
      alert('Failed to delete record');
    }
  };

  return (
    <div className="p-4 md:p-8 space-y-8 animate-fade-in">
      <div className="flex items-center justify-between bg-white dark:bg-slate-800 p-6 rounded-2xl shadow-sm border border-slate-100 dark:border-slate-700">
        <div>
          <h1 className="text-3xl font-bold text-slate-800 dark:text-white flex items-center gap-3">
            <span className="text-purple-500">⚠️</span> شکایات کا ریکارڈ
          </h1>
          <p className="text-slate-500 dark:text-slate-400 mt-2">
            اساتذہ یا مدرسہ کی طرف سے طلباء کے لیے درج کی گئی تمام شکایات اور نوٹس
          </p>
        </div>
        <div>
          <Link href="/add_complaint" className="bg-red-500 hover:bg-red-600 text-white px-6 py-3 rounded-xl font-bold shadow-md transition flex items-center gap-2">
            <span className="text-xl">➕</span> نیا اندراج کریں
          </Link>
        </div>
      </div>

      <div className="bg-white dark:bg-slate-800 rounded-2xl shadow-sm border border-slate-100 dark:border-slate-700 overflow-hidden">
        <div className="p-4 bg-slate-800 text-white border-b border-slate-700 flex justify-between items-center">
          <h2 className="font-bold text-lg">حالیہ ریکارڈ (آخری 50)</h2>
        </div>
        {loading ? (
          <div className="p-10 text-center text-slate-500">لوڈ ہو رہا ہے...</div>
        ) : complaints.length === 0 ? (
          <div className="p-10 text-center text-slate-500">کوئی ریکارڈ موجود نہیں</div>
        ) : (
          <div className="overflow-x-auto">
            <table className="w-full text-right border-collapse">
              <thead>
                <tr className="bg-slate-50 dark:bg-slate-700 text-slate-600 dark:text-slate-300 border-b border-slate-200 dark:border-slate-600 text-sm">
                  <th className="p-4 w-32 font-bold">تاریخ</th>
                  <th className="p-4 w-48 font-bold">طالب علم کا نام</th>
                  <th className="p-4 font-bold">تفصیل / شکایت</th>
                  <th className="p-4 w-24 text-center font-bold">ایکشن</th>
                </tr>
              </thead>
              <tbody>
                {complaints.map((c) => (
                  <tr key={c.id} className="border-b border-slate-100 dark:border-slate-700 hover:bg-slate-50 dark:hover:bg-slate-700/50 transition">
                    <td className="p-4 font-semibold text-slate-600 dark:text-slate-400 text-sm align-top">
                      {formatDate(c.date)}
                    </td>
                    <td className="p-4 font-bold text-slate-800 dark:text-slate-200 align-top">
                      {c.student_name}
                      <span className="block text-xs font-normal text-slate-500 dark:text-slate-400 mt-1">
                        رول نمبر: {c.admission_number}
                      </span>
                    </td>
                    <td className="p-4 text-slate-600 dark:text-slate-400 text-sm whitespace-pre-wrap align-top">
                      {c.description}
                    </td>
                    <td className="p-4 text-center align-top">
                      <button
                        onClick={() => handleDelete(c.id)}
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
  );
}
