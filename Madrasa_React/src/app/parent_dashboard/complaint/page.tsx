'use client';
import { useState, useEffect } from 'react';

const formatDate = (dateString: string) => {
  const d = new Date(dateString);
  return d.toLocaleDateString('en-GB', { day: '2-digit', month: 'short', year: 'numeric' });
};

export default function ParentComplaintPage() {
  const [user, setUser] = useState<any>(null);
  const [complaints, setComplaints] = useState<any[]>([]);
  const [isSubmitting, setIsSubmitting] = useState(false);
  
  const [formData, setFormData] = useState({
    category: 'نصاب / تعلیم',
    description: ''
  });

  useEffect(() => {
    const userStr = localStorage.getItem('user');
    if (userStr) {
      const parsed = JSON.parse(userStr);
      setUser(parsed);
      fetchComplaints(parsed.id);
    }
  }, []);

  const fetchComplaints = async (studentId: number) => {
    try {
      const res = await fetch(`/api/parent/complaint?student_id=${studentId}`);
      const json = await res.json();
      if (json.success) setComplaints(json.data);
    } catch (e) {
      console.error(e);
    }
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!user) return;
    setIsSubmitting(true);
    
    try {
      const res = await fetch('/api/parent/complaint', {
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
        setFormData({ ...formData, description: '' });
        fetchComplaints(user.id);
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
            <span className="text-red-500">⚠️</span> شکایت درج کریں
          </h1>
          <p className="text-slate-500 dark:text-slate-400 mt-2">
            کسی بھی قسم کی تعلیمی یا انتظامی شکایت براہ راست مدرسہ انتظامیہ تک پہنچائیں
          </p>
        </div>
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
        
        {/* Form */}
        <div className="lg:col-span-1 bg-white dark:bg-slate-800 rounded-2xl p-6 shadow-sm border border-slate-100 dark:border-slate-700 h-fit border-t-4 border-t-red-500">
          <h2 className="text-xl font-bold mb-4 border-b pb-2">نئی شکایت</h2>
          <form onSubmit={handleSubmit} className="space-y-4">
            <div>
              <label className="block text-sm font-bold mb-1">کیٹگری</label>
              <select required value={formData.category} onChange={(e) => setFormData({...formData, category: e.target.value})} className="w-full border rounded-xl px-4 py-3 bg-slate-50 dark:bg-slate-900 font-bold">
                <option value="نصاب / تعلیم">نصاب / تعلیم</option>
                <option value="اساتذہ کا رویہ">اساتذہ کا رویہ</option>
                <option value="انتظامیہ">انتظامیہ</option>
                <option value="صفائی ستھرائی">صفائی ستھرائی</option>
                <option value="دیگر (متفرق)">دیگر (متفرق)</option>
              </select>
            </div>
            <div>
              <label className="block text-sm font-bold mb-1">شکایت کی تفصیل</label>
              <textarea required rows={5} value={formData.description} onChange={(e) => setFormData({...formData, description: e.target.value})} className="w-full border rounded-xl px-4 py-2 bg-slate-50 dark:bg-slate-900" placeholder="مکمل تفصیل یہاں لکھیں..."></textarea>
            </div>
            <button type="submit" disabled={isSubmitting} className="w-full bg-red-500 hover:bg-red-600 text-white font-bold py-3 rounded-xl transition">
              {isSubmitting ? 'بھیج رہا ہے...' : 'شکایت درج کریں'}
            </button>
          </form>
        </div>

        {/* History */}
        <div className="lg:col-span-2 bg-white dark:bg-slate-800 rounded-2xl shadow-sm border border-slate-100 dark:border-slate-700 overflow-hidden">
          <div className="p-4 bg-slate-800 text-white border-b border-slate-700">
            <h2 className="font-bold">آپ کی پچھلی شکایات</h2>
          </div>
          <div className="overflow-x-auto">
            <table className="w-full text-right">
              <thead>
                <tr className="bg-slate-50 dark:bg-slate-700 text-sm">
                  <th className="p-4 w-32">تاریخ</th>
                  <th className="p-4 w-32">کیٹگری</th>
                  <th className="p-4">تفصیل</th>
                  <th className="p-4 w-32 text-center">سٹیٹس</th>
                </tr>
              </thead>
              <tbody>
                {complaints.length === 0 ? <tr><td colSpan={4} className="p-8 text-center text-slate-500">کوئی شکایت درج نہیں کی گئی</td></tr> :
                  complaints.map(c => (
                  <tr key={c.id} className="border-b dark:border-slate-700">
                    <td className="p-4 text-sm font-bold">{formatDate(c.date)}</td>
                    <td className="p-4 text-sm">{c.category}</td>
                    <td className="p-4 text-sm whitespace-pre-wrap">{c.complaint}</td>
                    <td className="p-4 text-center">
                      <span className={`text-xs px-3 py-1 rounded-full font-bold ${c.status === 'Viewed' ? 'bg-green-100 text-green-700' : 'bg-yellow-100 text-yellow-700'}`}>
                        {c.status === 'Viewed' ? 'انتظامیہ نے دیکھ لیا' : 'زیرِ التوا'}
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
