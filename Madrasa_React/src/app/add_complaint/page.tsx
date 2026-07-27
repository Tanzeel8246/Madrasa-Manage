'use client';
import { useState, useEffect } from 'react';
import { useRouter } from 'next/navigation';

const getToday = () => {
  const d = new Date();
  return d.toISOString().split('T')[0];
};

export default function AddComplaintPage() {
  const [students, setStudents] = useState<any[]>([]);
  const [categories, setCategories] = useState<string[]>([]);
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [searchTerm, setSearchTerm] = useState('');
  const router = useRouter();

  const [formData, setFormData] = useState({
    student_ids: [] as number[],
    date: getToday(),
    category: 'اساتذہ/مدرسہ کی طرف سے (نوٹ)',
    new_category: '',
    complaint: ''
  });

  useEffect(() => {
    const fetchData = async () => {
      try {
        const [compRes, stdRes] = await Promise.all([
          fetch('/api/complaints'), // Fetch parent complaints to get unique categories used there
          fetch('/api/students')
        ]);
        const compData = await compRes.json();
        const stdData = await stdRes.json();

        if (compData.success) {
          const uniqueCats = new Set<string>();
          compData.data.forEach((c: any) => {
            if (c.category) uniqueCats.add(c.category);
          });
          setCategories(Array.from(uniqueCats));
        }
        
        if (stdData.success) {
          setStudents(stdData.students);
        }
      } catch (error) {
        console.error('Failed to fetch data:', error);
      }
    };
    fetchData();
  }, []);

  const handleStudentToggle = (stdId: number) => {
    setFormData(prev => {
      const ids = prev.student_ids;
      if (ids.includes(stdId)) {
        return { ...prev, student_ids: ids.filter(id => id !== stdId) };
      } else {
        return { ...prev, student_ids: [...ids, stdId] };
      }
    });
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (formData.student_ids.length === 0) {
      alert('براہ کرم کم از کم ایک طالب علم منتخب کریں!');
      return;
    }

    setIsSubmitting(true);
    try {
      const res = await fetch('/api/add_complaint', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(formData)
      });
      const data = await res.json();
      if (data.success) {
        alert(data.message || 'شکایت / نوٹ کامیابی سے شامل کر دیا گیا!');
        router.push('/manage_complaints');
      } else {
        alert(data.message || 'Error adding complaint');
        setIsSubmitting(false);
      }
    } catch (error) {
      alert('Network error');
      setIsSubmitting(false);
    }
  };

  const filteredStudents = students.filter(s => s.name.includes(searchTerm) || s.admission_number.toString().includes(searchTerm));

  return (
    <div className="p-4 md:p-8 space-y-8 animate-fade-in max-w-4xl mx-auto">
      <div className="flex items-center justify-between bg-white dark:bg-slate-800 p-6 rounded-2xl shadow-sm border border-slate-100 dark:border-slate-700">
        <div>
          <h1 className="text-3xl font-bold text-slate-800 dark:text-white flex items-center gap-3">
            <span className="text-red-500">➕</span> شکایت / نوٹ درج کریں
          </h1>
          <p className="text-slate-500 dark:text-slate-400 mt-2">
            اساتذہ یا ایڈمن کی طرف سے کسی بھی طالب علم کی کارکردگی یا رویے پر نوٹ درج کریں
          </p>
        </div>
      </div>

      <div className="bg-white dark:bg-slate-800 rounded-2xl shadow-sm border-t-4 border-t-red-500 overflow-hidden">
        <div className="p-6">
          <form onSubmit={handleSubmit} className="space-y-6">
            
            <div className="bg-slate-50 dark:bg-slate-900/50 p-6 rounded-xl border border-slate-200 dark:border-slate-700">
              <label className="block text-lg font-bold mb-3 text-slate-800 dark:text-white flex items-center gap-2">
                <span className="text-blue-500">👥</span> طلباء منتخب کریں (ایک یا زیادہ)
              </label>
              <input
                type="text"
                placeholder="طالب علم کا نام یا رول نمبر تلاش کریں..."
                value={searchTerm}
                onChange={(e) => setSearchTerm(e.target.value)}
                className="w-full mb-3 border border-slate-300 dark:border-slate-600 rounded-xl px-4 py-3 bg-white dark:bg-slate-900 text-base focus:ring-2 focus:ring-blue-500 outline-none transition shadow-sm"
              />
              <div className="border border-slate-200 dark:border-slate-600 rounded-xl h-60 overflow-y-auto bg-white dark:bg-slate-800 p-3 space-y-1 shadow-inner">
                {filteredStudents.map(s => (
                  <label key={s.id} className="flex items-center gap-3 p-3 hover:bg-blue-50 dark:hover:bg-blue-900/30 rounded-lg cursor-pointer transition border border-transparent hover:border-blue-100 dark:hover:border-blue-800">
                    <input
                      type="checkbox"
                      checked={formData.student_ids.includes(s.id)}
                      onChange={() => handleStudentToggle(s.id)}
                      className="w-5 h-5 text-blue-600 rounded border-slate-300 focus:ring-blue-500"
                    />
                    <span className="text-base font-bold text-slate-700 dark:text-slate-300">
                      {s.name} <span className="text-slate-400 text-sm font-normal">(رول نمبر: {s.admission_number})</span>
                    </span>
                  </label>
                ))}
                {filteredStudents.length === 0 && <p className="text-sm text-center text-slate-400 mt-8">کوئی طالب علم نہیں ملا</p>}
              </div>
              <p className="text-sm font-bold text-blue-600 dark:text-blue-400 mt-3 bg-blue-50 dark:bg-blue-900/30 inline-block px-3 py-1 rounded-full border border-blue-100 dark:border-blue-800">
                منتخب شدہ طلباء: {formData.student_ids.length}
              </p>
            </div>

            <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
              <div>
                <label className="block text-sm font-bold mb-2 text-slate-700 dark:text-slate-300">تاریخ</label>
                <input
                  type="date"
                  value={formData.date}
                  onChange={(e) => setFormData({...formData, date: e.target.value})}
                  className="w-full border border-slate-300 dark:border-slate-600 rounded-xl px-4 py-3 bg-slate-50 dark:bg-slate-900 focus:bg-white dark:focus:bg-slate-800 focus:ring-2 focus:ring-blue-500 outline-none transition"
                  required
                />
              </div>

              <div>
                <label className="block text-sm font-bold mb-2 text-slate-700 dark:text-slate-300">کیٹیگری</label>
                <select
                  value={formData.category}
                  onChange={(e) => setFormData({...formData, category: e.target.value})}
                  className="w-full border border-slate-300 dark:border-slate-600 rounded-xl px-4 py-3 bg-slate-50 dark:bg-slate-900 focus:bg-white dark:focus:bg-slate-800 focus:ring-2 focus:ring-blue-500 outline-none transition font-bold"
                >
                  <option value="اساتذہ/مدرسہ کی طرف سے (نوٹ)">اساتذہ/مدرسہ کی طرف سے (نوٹ)</option>
                  {categories.filter(c => c !== 'اساتذہ/مدرسہ کی طرف سے (نوٹ)').map(c => (
                    <option key={c} value={c}>{c}</option>
                  ))}
                  <option value="__NEW__" className="text-red-500 font-bold">+ نئی کیٹیگری شامل کریں</option>
                </select>
              </div>
            </div>

            {formData.category === '__NEW__' && (
              <div className="animate-fade-in bg-red-50 dark:bg-red-900/10 p-4 rounded-xl border border-red-100 dark:border-red-900/30">
                <label className="block text-sm font-bold mb-2 text-red-700 dark:text-red-400">نئی کیٹیگری کا نام</label>
                <input
                  type="text"
                  value={formData.new_category}
                  onChange={(e) => setFormData({...formData, new_category: e.target.value})}
                  placeholder="مثلاً: صفائی، ڈسپلن..."
                  className="w-full border border-red-200 dark:border-red-800 rounded-xl px-4 py-3 bg-white dark:bg-slate-900 focus:ring-2 focus:ring-red-500 outline-none transition"
                  required
                />
              </div>
            )}

            <div>
              <label className="block text-sm font-bold mb-2 text-slate-700 dark:text-slate-300">تفصیل (شکایت / نوٹ)</label>
              <textarea
                value={formData.complaint}
                onChange={(e) => setFormData({...formData, complaint: e.target.value})}
                rows={5}
                className="w-full border border-slate-300 dark:border-slate-600 rounded-xl px-4 py-3 bg-slate-50 dark:bg-slate-900 focus:bg-white dark:focus:bg-slate-800 focus:ring-2 focus:ring-blue-500 outline-none transition text-base"
                placeholder="تفصیلات یہاں لکھیں..."
                required
              ></textarea>
            </div>

            <button
              type="submit"
              disabled={isSubmitting || formData.student_ids.length === 0}
              className="w-full bg-red-600 hover:bg-red-700 text-white font-bold py-4 rounded-xl transition shadow-lg disabled:opacity-50 text-lg flex justify-center items-center gap-2"
            >
              {isSubmitting ? 'محفوظ ہو رہا ہے...' : (
                <>
                  محفوظ کریں <span className="text-xl">💾</span>
                </>
              )}
            </button>
          </form>
        </div>
      </div>
    </div>
  );
}
