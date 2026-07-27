'use client';
import { useState, useEffect } from 'react';

const formatDate = (dateString: string) => {
  const d = new Date(dateString);
  return d.toLocaleDateString('en-GB', { day: '2-digit', month: 'short', year: 'numeric' });
};

export default function ParentFeePage() {
  const [user, setUser] = useState<any>(null);
  const [fees, setFees] = useState<any[]>([]);
  const [heads, setHeads] = useState<any[]>([]);
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [selectedImage, setSelectedImage] = useState<string | null>(null);
  
  const [formData, setFormData] = useState({
    amount: '',
    head_id: '',
    description: '',
    screenshot: ''
  });

  useEffect(() => {
    const userStr = localStorage.getItem('user');
    if (userStr) {
      const parsed = JSON.parse(userStr);
      setUser(parsed);
      fetchFees(parsed.id);
    }
    // Fetch active heads for fee
    fetch('/api/classes') // Assuming a generic endpoints or we need a specific one for heads. We can just use an array for now or fetch from /api/heads if it existed.
      .catch(console.error); // Will implement properly if needed.
  }, []);

  const fetchFees = async (studentId: number) => {
    try {
      const res = await fetch(`/api/parent/fee?student_id=${studentId}`);
      const json = await res.json();
      if (json.success) setFees(json.data);
    } catch (e) {
      console.error(e);
    }
  };

  const handleImageUpload = (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (file) {
      const reader = new FileReader();
      reader.onloadend = () => {
        setFormData({ ...formData, screenshot: reader.result as string });
      };
      reader.readAsDataURL(file);
    }
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!user) return;
    setIsSubmitting(true);
    
    try {
      const res = await fetch('/api/parent/fee', {
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
        setFormData({ amount: '', head_id: '', description: '', screenshot: '' });
        fetchFees(user.id);
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
            <span className="text-emerald-500">💸</span> فیس / آن لائن ادائیگی
          </h1>
          <p className="text-slate-500 dark:text-slate-400 mt-2">
            اپنے بچے کی فیس یا مدرسے کا تعاون آن لائن ادا کر کے رسید یہاں اپلوڈ کریں
          </p>
        </div>
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
        
        {/* Form */}
        <div className="lg:col-span-1 bg-white dark:bg-slate-800 rounded-2xl p-6 shadow-sm border border-slate-100 dark:border-slate-700 h-fit">
          <h2 className="text-xl font-bold mb-4 border-b pb-2">نئی ادائیگی کی تفصیل</h2>
          <form onSubmit={handleSubmit} className="space-y-4">
            <div>
              <label className="block text-sm font-bold mb-1">رقم (روپے میں)</label>
              <input type="number" required value={formData.amount} onChange={(e) => setFormData({...formData, amount: e.target.value})} className="w-full border rounded-xl px-4 py-2 bg-slate-50 dark:bg-slate-900" placeholder="مثلاً 5000" />
            </div>
            <div>
              <label className="block text-sm font-bold mb-1">تفصیل</label>
              <textarea required rows={3} value={formData.description} onChange={(e) => setFormData({...formData, description: e.target.value})} className="w-full border rounded-xl px-4 py-2 bg-slate-50 dark:bg-slate-900" placeholder="کس مہینے کی فیس ہے یا کس مد میں تعاون ہے..."></textarea>
            </div>
            <div>
              <label className="block text-sm font-bold mb-1">رسید / سکرین شاٹ</label>
              <input type="file" accept="image/*" onChange={handleImageUpload} className="w-full border rounded-xl px-4 py-2 bg-slate-50 dark:bg-slate-900 text-sm" />
              {formData.screenshot && (
                <div className="mt-2 text-xs text-green-600 font-bold">تصویر منتخب ہو گئی ہے</div>
              )}
            </div>
            <button type="submit" disabled={isSubmitting} className="w-full bg-emerald-500 hover:bg-emerald-600 text-white font-bold py-3 rounded-xl transition">
              {isSubmitting ? 'بھیج رہا ہے...' : 'جمع کروائیں'}
            </button>
          </form>
        </div>

        {/* History */}
        <div className="lg:col-span-2 bg-white dark:bg-slate-800 rounded-2xl shadow-sm border border-slate-100 dark:border-slate-700 overflow-hidden">
          <div className="p-4 bg-slate-800 text-white border-b border-slate-700">
            <h2 className="font-bold">پچھلی ادائیگیوں کا ریکارڈ</h2>
          </div>
          <div className="overflow-x-auto">
            <table className="w-full text-right">
              <thead>
                <tr className="bg-slate-50 dark:bg-slate-700 text-sm">
                  <th className="p-4">جمع کرانے کی تاریخ</th>
                  <th className="p-4">رقم</th>
                  <th className="p-4">تفصیل</th>
                  <th className="p-4 text-center">رسید</th>
                  <th className="p-4 text-center">سٹیٹس</th>
                </tr>
              </thead>
              <tbody>
                {fees.length === 0 ? <tr><td colSpan={5} className="p-8 text-center text-slate-500">کوئی ریکارڈ موجود نہیں</td></tr> :
                  fees.map(f => (
                  <tr key={f.id} className="border-b dark:border-slate-700">
                    <td className="p-4 text-sm">{formatDate(f.submission_date)}</td>
                    <td className="p-4 text-emerald-600 font-bold text-lg">Rs. {parseInt(f.amount).toLocaleString()}</td>
                    <td className="p-4 text-sm">{f.description}</td>
                    <td className="p-4 text-center">
                      {f.screenshot ? (
                        <button type="button" onClick={() => setSelectedImage(f.screenshot)} className="bg-blue-100 text-blue-700 px-2 py-1 rounded text-xs">دیکھیں</button>
                      ) : '-'}
                    </td>
                    <td className="p-4 text-center">
                      <span className={`text-xs px-3 py-1 rounded-full font-bold ${f.status === 'Approved' ? 'bg-emerald-100 text-emerald-700' : f.status === 'Rejected' ? 'bg-red-100 text-red-700' : 'bg-yellow-100 text-yellow-700'}`}>
                        {f.status === 'Approved' ? 'منظور (اکاؤنٹس میں شامل)' : f.status === 'Rejected' ? 'مسترد شدہ' : 'زیرِ التوا'}
                      </span>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </div>

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
