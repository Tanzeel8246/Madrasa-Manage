'use client';
import { useState, useEffect } from 'react';

const formatDate = (dateString: string) => {
  const d = new Date(dateString);
  return d.toLocaleDateString('en-GB', { day: '2-digit', month: 'short', year: 'numeric' });
};

export default function RequestsPage() {
  const [activeTab, setActiveTab] = useState<'leaves' | 'complaints' | 'fees'>('leaves');
  const [data, setData] = useState({
    complaints: [] as any[],
    leaves: [] as any[],
    fees: [] as any[]
  });
  const [loading, setLoading] = useState(true);
  const [selectedImage, setSelectedImage] = useState<string | null>(null);

  const fetchData = async () => {
    try {
      const res = await fetch('/api/complaints');
      const json = await res.json();
      if (json.success) {
        setData(json.data);
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

  const handleDelete = async (id: number, type: string) => {
    if (!confirm('کیا آپ واقعی یہ ریکارڈ حذف کرنا چاہتے ہیں؟')) return;
    try {
      const res = await fetch(`/api/complaints?id=${id}&type=${type}`, { method: 'DELETE' });
      const json = await res.json();
      if (json.success) {
        fetchData();
      }
    } catch (error) {
      alert('Failed to delete record');
    }
  };

  const updateStatus = async (id: number, type: string, status: string) => {
    try {
      const res = await fetch('/api/complaints', {
        method: 'PUT',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ id, type, status })
      });
      const json = await res.json();
      if (json.success) {
        fetchData();
      } else {
        alert('Error: ' + json.message);
      }
    } catch (error) {
      alert('Failed to update status');
    }
  };

  return (
    <div className="p-4 md:p-8 space-y-6 animate-fade-in font-urdu" dir="rtl">
      <div className="flex items-center justify-between bg-white dark:bg-slate-800 p-6 rounded-2xl shadow-sm border border-slate-100 dark:border-slate-700">
        <div>
          <h1 className="text-3xl font-bold text-slate-800 dark:text-white flex items-center gap-3">
            <span className="text-blue-500">📥</span> درخواستیں و شکایات (پیرنٹس پینل)
          </h1>
          <p className="text-slate-500 dark:text-slate-400 mt-2">
            والدین کی جانب سے موصول ہونے والی چھٹی کی درخواستیں، آن لائن فیس، اور شکایات
          </p>
        </div>
      </div>

      {/* Tabs */}
      <div className="flex gap-4 border-b border-slate-200 dark:border-slate-700 pb-2">
        <button 
          onClick={() => setActiveTab('leaves')}
          className={`px-6 py-3 font-bold rounded-t-xl transition-all ${activeTab === 'leaves' ? 'bg-blue-500 text-white shadow-md' : 'bg-slate-100 dark:bg-slate-800 text-slate-600 dark:text-slate-400 hover:bg-slate-200 dark:hover:bg-slate-700'}`}
        >
          <span className="me-2">✉️</span> چھٹی کی درخواستیں
          {data.leaves.filter(l => l.status === 'Pending').length > 0 && (
            <span className="ms-2 bg-red-500 text-white text-xs px-2 py-0.5 rounded-full">{data.leaves.filter(l => l.status === 'Pending').length}</span>
          )}
        </button>
        <button 
          onClick={() => setActiveTab('fees')}
          className={`px-6 py-3 font-bold rounded-t-xl transition-all ${activeTab === 'fees' ? 'bg-emerald-500 text-white shadow-md' : 'bg-slate-100 dark:bg-slate-800 text-slate-600 dark:text-slate-400 hover:bg-slate-200 dark:hover:bg-slate-700'}`}
        >
          <span className="me-2">💸</span> فیس / آن لائن تعاون
          {data.fees.filter(f => f.status === 'Pending').length > 0 && (
            <span className="ms-2 bg-red-500 text-white text-xs px-2 py-0.5 rounded-full">{data.fees.filter(f => f.status === 'Pending').length}</span>
          )}
        </button>
        <button 
          onClick={() => setActiveTab('complaints')}
          className={`px-6 py-3 font-bold rounded-t-xl transition-all ${activeTab === 'complaints' ? 'bg-red-500 text-white shadow-md' : 'bg-slate-100 dark:bg-slate-800 text-slate-600 dark:text-slate-400 hover:bg-slate-200 dark:hover:bg-slate-700'}`}
        >
          <span className="me-2">⚠️</span> والدین کی شکایات
          {data.complaints.filter(c => c.status === 'Pending').length > 0 && (
            <span className="ms-2 bg-yellow-400 text-yellow-900 text-xs px-2 py-0.5 rounded-full">{data.complaints.filter(c => c.status === 'Pending').length}</span>
          )}
        </button>
      </div>

      <div className="bg-white dark:bg-slate-800 rounded-2xl shadow-sm border border-slate-100 dark:border-slate-700 overflow-hidden">
        {loading ? (
          <div className="p-10 text-center text-slate-500">لوڈ ہو رہا ہے...</div>
        ) : (
          <div className="overflow-x-auto">
            {/* LEAVES TAB */}
            {activeTab === 'leaves' && (
              <table className="w-full text-right border-collapse">
                <thead>
                  <tr className="bg-blue-50 dark:bg-slate-700 text-slate-600 dark:text-slate-300 border-b border-slate-200 dark:border-slate-600 text-sm">
                    <th className="p-4 w-32 font-bold">درخواست کی تاریخ</th>
                    <th className="p-4 w-48 font-bold">طالب علم کا نام</th>
                    <th className="p-4 w-48 font-bold">چھٹی کی تاریخ</th>
                    <th className="p-4 font-bold">وجہ / تفصیل</th>
                    <th className="p-4 w-48 text-center font-bold">سٹیٹس / ایکشن</th>
                  </tr>
                </thead>
                <tbody>
                  {data.leaves.length === 0 ? <tr><td colSpan={5} className="p-8 text-center text-slate-500">کوئی درخواست موجود نہیں</td></tr> : 
                    data.leaves.map((l) => (
                    <tr key={l.id} className="border-b border-slate-100 dark:border-slate-700 hover:bg-slate-50 dark:hover:bg-slate-700/50 transition">
                      <td className="p-4 text-slate-500 dark:text-slate-400 text-sm align-top">{formatDate(l.created_at)}</td>
                      <td className="p-4 font-bold text-slate-800 dark:text-slate-200 align-top">{l.student_name}</td>
                      <td className="p-4 text-blue-600 dark:text-blue-400 font-bold align-top" dir="ltr">
                        {formatDate(l.date_from)} - {formatDate(l.date_to)}
                      </td>
                      <td className="p-4 text-slate-600 dark:text-slate-400 text-sm align-top whitespace-pre-wrap">{l.reason}</td>
                      <td className="p-4 align-top">
                        <div className="flex flex-col gap-2">
                          {l.status === 'Pending' ? (
                            <div className="flex gap-2">
                              <button onClick={() => updateStatus(l.id, 'leave', 'Approved')} className="bg-green-500 hover:bg-green-600 text-white text-xs px-3 py-1.5 rounded-lg w-full transition">منظور کریں</button>
                              <button onClick={() => updateStatus(l.id, 'leave', 'Rejected')} className="bg-red-500 hover:bg-red-600 text-white text-xs px-3 py-1.5 rounded-lg w-full transition">مسترد کریں</button>
                            </div>
                          ) : (
                            <span className={`text-center text-xs px-3 py-1.5 rounded-full font-bold ${l.status === 'Approved' ? 'bg-green-100 text-green-700' : 'bg-red-100 text-red-700'}`}>
                              {l.status === 'Approved' ? 'منظور شدہ' : 'مسترد شدہ'}
                            </span>
                          )}
                          <button onClick={() => handleDelete(l.id, 'leave')} className="text-xs text-red-400 hover:text-red-600 mt-1">حذف کریں</button>
                        </div>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            )}

            {/* COMPLAINTS TAB */}
            {activeTab === 'complaints' && (
              <table className="w-full text-right border-collapse">
                <thead>
                  <tr className="bg-red-50 dark:bg-slate-700 text-slate-600 dark:text-slate-300 border-b border-slate-200 dark:border-slate-600 text-sm">
                    <th className="p-4 w-32 font-bold">تاریخ</th>
                    <th className="p-4 w-48 font-bold">طالب علم کا نام</th>
                    <th className="p-4 w-40 font-bold">کیٹگری</th>
                    <th className="p-4 font-bold">تفصیل</th>
                    <th className="p-4 w-32 text-center font-bold">سٹیٹس / ایکشن</th>
                  </tr>
                </thead>
                <tbody>
                  {data.complaints.length === 0 ? <tr><td colSpan={5} className="p-8 text-center text-slate-500">کوئی شکایت موجود نہیں</td></tr> : 
                    data.complaints.map((c) => (
                    <tr key={c.id} className="border-b border-slate-100 dark:border-slate-700 hover:bg-slate-50 dark:hover:bg-slate-700/50 transition">
                      <td className="p-4 font-semibold text-slate-500 dark:text-slate-400 text-sm align-top">{formatDate(c.date)}</td>
                      <td className="p-4 font-bold text-slate-800 dark:text-slate-200 align-top">{c.student_name}</td>
                      <td className="p-4 align-top font-semibold text-slate-700 dark:text-slate-300 text-sm">{c.category}</td>
                      <td className="p-4 text-slate-600 dark:text-slate-400 text-sm whitespace-pre-wrap align-top">{c.description}</td>
                      <td className="p-4 align-top">
                        <div className="flex flex-col items-center gap-2">
                          {c.status === 'Pending' ? (
                            <button onClick={() => updateStatus(c.id, 'complaint', 'Viewed')} className="bg-yellow-500 hover:bg-yellow-600 text-white text-xs px-3 py-1.5 rounded-lg w-full transition">
                              مارک ایز ویوڈ (View)
                            </button>
                          ) : (
                            <span className="bg-green-100 text-green-700 px-3 py-1 rounded-full text-xs font-bold w-full text-center">دیکھ لیا</span>
                          )}
                          <button onClick={() => handleDelete(c.id, 'complaint')} className="text-xs text-red-400 hover:text-red-600 mt-1">حذف کریں</button>
                        </div>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            )}

            {/* FEES TAB */}
            {activeTab === 'fees' && (
              <table className="w-full text-right border-collapse">
                <thead>
                  <tr className="bg-emerald-50 dark:bg-slate-700 text-slate-600 dark:text-slate-300 border-b border-slate-200 dark:border-slate-600 text-sm">
                    <th className="p-4 w-48 font-bold">طالب علم / مد</th>
                    <th className="p-4 w-32 font-bold">تاریخ</th>
                    <th className="p-4 w-48 font-bold">رقم / تفصیل</th>
                    <th className="p-4 w-32 text-center font-bold">سکرین شاٹ</th>
                    <th className="p-4 w-48 text-center font-bold">سٹیٹس / ایکشن</th>
                  </tr>
                </thead>
                <tbody>
                  {data.fees.length === 0 ? <tr><td colSpan={5} className="p-8 text-center text-slate-500">کوئی فیس یا تعاون موصول نہیں ہوا</td></tr> : 
                    data.fees.map((f) => (
                    <tr key={f.id} className="border-b border-slate-100 dark:border-slate-700 hover:bg-slate-50 dark:hover:bg-slate-700/50 transition">
                      <td className="p-4 align-top">
                        <span className="font-bold text-slate-800 dark:text-slate-200 block">{f.student_name}</span>
                        <span className="text-xs text-slate-500 dark:text-slate-400">{f.head_name || 'بغیر مد'}</span>
                      </td>
                      <td className="p-4 font-semibold text-slate-500 dark:text-slate-400 text-sm align-top">{formatDate(f.submission_date)}</td>
                      <td className="p-4 align-top">
                        <span className="font-bold text-emerald-600 dark:text-emerald-400 block text-lg">Rs. {parseInt(f.amount).toLocaleString()}</span>
                        <span className="text-xs text-slate-600 dark:text-slate-400">{f.description}</span>
                      </td>
                      <td className="p-4 text-center align-top">
                        {f.screenshot ? (
                          <button onClick={() => setSelectedImage(f.screenshot)} className="bg-blue-100 text-blue-700 hover:bg-blue-200 px-3 py-1 rounded-lg text-xs font-bold transition">
                            👁️ دیکھیں
                          </button>
                        ) : (
                          <span className="text-xs text-slate-400">نہیں ہے</span>
                        )}
                      </td>
                      <td className="p-4 align-top">
                        <div className="flex flex-col gap-2">
                          {f.status === 'Pending' ? (
                            <div className="flex gap-2">
                              <button onClick={() => updateStatus(f.id, 'fee', 'Approved')} className="bg-emerald-500 hover:bg-emerald-600 text-white text-xs px-3 py-1.5 rounded-lg w-full transition">منظور</button>
                              <button onClick={() => updateStatus(f.id, 'fee', 'Rejected')} className="bg-red-500 hover:bg-red-600 text-white text-xs px-3 py-1.5 rounded-lg w-full transition">مسترد</button>
                            </div>
                          ) : (
                            <span className={`text-center text-xs px-3 py-1.5 rounded-full font-bold ${f.status === 'Approved' ? 'bg-emerald-100 text-emerald-700' : 'bg-red-100 text-red-700'}`}>
                              {f.status === 'Approved' ? 'منظور شدہ (اکاؤنٹس میں شامل)' : 'مسترد شدہ'}
                            </span>
                          )}
                          <button onClick={() => handleDelete(f.id, 'fee')} className="text-xs text-red-400 hover:text-red-600 mt-1">حذف کریں</button>
                        </div>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            )}
          </div>
        )}
      </div>

      {/* Image Modal */}
      {selectedImage && (
        <div className="fixed inset-0 bg-black/80 flex items-center justify-center z-50 p-4" onClick={() => setSelectedImage(null)}>
          <div className="bg-white p-2 rounded-xl max-w-2xl max-h-[90vh] overflow-hidden relative">
            <button onClick={() => setSelectedImage(null)} className="absolute top-4 right-4 bg-red-500 text-white w-8 h-8 rounded-full font-bold">X</button>
            <img src={selectedImage} alt="Screenshot" className="max-w-full max-h-[85vh] object-contain rounded-lg" />
          </div>
        </div>
      )}
    </div>
  );
}
