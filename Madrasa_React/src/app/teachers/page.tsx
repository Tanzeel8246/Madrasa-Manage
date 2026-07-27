'use client';

import { useState, useEffect } from 'react';
import Link from 'next/link';

interface Teacher {
  id: number;
  name: string;
  father_name: string;
  phone: string;
  cnic: string;
  qualification: string;
  address: string;
  salary: number;
  house_rent: number;
  medical_allowance: number;
  travel_allowance: number;
  daily_deduction_rate: number;
  joining_date: string;
  status: string;
}

export default function TeachersPage() {
  const [teachers, setTeachers] = useState<Teacher[]>([]);
  const [loading, setLoading] = useState(true);
  const [search, setSearch] = useState('');
  
  const [isModalOpen, setIsModalOpen] = useState(false);
  const [modalMode, setModalMode] = useState<'add'|'edit'|'delete'>('add');
  const [selectedTeacher, setSelectedTeacher] = useState<Teacher | null>(null);
  
  const [formData, setFormData] = useState<Partial<Teacher>>({});
  const [saving, setSaving] = useState(false);
  const [message, setMessage] = useState<{type: 'success'|'error', text: string} | null>(null);

  const fetchTeachers = async () => {
    setLoading(true);
    try {
      const res = await fetch('/api/teachers');
      const data = await res.json();
      if (data.success) {
        setTeachers(data.data);
      }
    } catch (error) {
      console.error('Error fetching teachers:', error);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchTeachers();
  }, []);

  const openModal = (mode: 'add'|'edit'|'delete', teacher?: Teacher) => {
    setModalMode(mode);
    setSelectedTeacher(teacher || null);
    setMessage(null);
    if (mode === 'edit' && teacher) {
      setFormData(teacher);
    } else if (mode === 'add') {
      setFormData({
        status: 'Active',
        joining_date: new Date().toISOString().split('T')[0],
        salary: 0,
        house_rent: 0,
        medical_allowance: 0,
        travel_allowance: 0,
        daily_deduction_rate: 0
      });
    }
    setIsModalOpen(true);
  };

  const handleSave = async (e: React.FormEvent) => {
    e.preventDefault();
    setSaving(true);
    setMessage(null);

    try {
      const url = '/api/teachers';
      const method = modalMode === 'edit' ? 'PUT' : 'POST';
      
      const res = await fetch(url, {
        method,
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(formData)
      });
      
      const data = await res.json();
      if (data.success) {
        setMessage({ type: 'success', text: data.message });
        fetchTeachers();
        setTimeout(() => setIsModalOpen(false), 1500);
      } else {
        setMessage({ type: 'error', text: data.message });
      }
    } catch (error: any) {
      setMessage({ type: 'error', text: error.message });
    } finally {
      setSaving(false);
    }
  };

  const handleDelete = async () => {
    if (!selectedTeacher) return;
    setSaving(true);
    try {
      const res = await fetch(`/api/teachers?id=${selectedTeacher.id}`, { method: 'DELETE' });
      const data = await res.json();
      if (data.success) {
        fetchTeachers();
        setIsModalOpen(false);
      } else {
        setMessage({ type: 'error', text: data.message });
      }
    } catch (error: any) {
      setMessage({ type: 'error', text: error.message });
    } finally {
      setSaving(false);
    }
  };

  const filteredTeachers = teachers.filter(t => 
    t.name?.toLowerCase().includes(search.toLowerCase()) || 
    t.phone?.includes(search) ||
    t.cnic?.includes(search)
  );

  return (
    <div className="flex flex-col bg-slate-50 dark:bg-slate-900 font-urdu transition-colors" dir="rtl">
      <main className="flex-1">
        <header className="h-20 bg-white/80 dark:bg-slate-800/80 backdrop-blur-md border-b border-slate-200 dark:border-slate-700 flex items-center justify-between px-8 sticky top-0 z-10 transition-colors">
          <div className="flex items-center gap-4">
            <Link href="/" className="text-theme-primary dark:text-theme-light hover:text-theme-hover transition-colors bg-theme-primary/10 p-2 rounded-lg">
              <span className="text-xl">🏠</span>
            </Link>
            <h2 className="text-2xl font-bold text-slate-800 dark:text-slate-100">اساتذہ و سٹاف کا ریکارڈ</h2>
          </div>
          <button 
            onClick={() => openModal('add')}
            className="bg-theme-primary hover:bg-theme-hover text-white px-6 py-2 rounded-lg font-bold shadow-md hover:shadow-lg transition-all flex items-center gap-2"
          >
            <span className="text-xl">+</span> نیا عملہ شامل کریں
          </button>
        </header>

        <div className="p-8">
          <div className="bg-white dark:bg-slate-800 p-4 rounded-2xl shadow-sm border border-slate-200 dark:border-slate-700 mb-6 flex gap-4 transition-colors">
            <input 
              type="text"
              placeholder="نام، فون نمبر یا شناختی کارڈ سے تلاش کریں..."
              className="flex-1 px-5 py-3 rounded-xl border border-slate-200 dark:border-slate-600 focus:outline-none focus:ring-2 focus:ring-theme-primary transition-all bg-slate-50 dark:bg-slate-700 text-slate-800 dark:text-slate-200 text-lg"
              value={search}
              onChange={(e) => setSearch(e.target.value)}
            />
          </div>

          <div className="bg-white dark:bg-slate-800 rounded-2xl shadow-sm border border-slate-200 dark:border-slate-700 overflow-hidden transition-colors">
            <div className="overflow-x-auto">
              <table className="w-full text-right border-collapse">
                <thead>
                  <tr className="bg-slate-50 dark:bg-slate-700/50 border-b border-slate-200 dark:border-slate-700 text-slate-600 dark:text-slate-300 font-bold text-lg">
                    <th className="py-4 px-6 w-16">#</th>
                    <th className="py-4 px-6">نام و ولدیت</th>
                    <th className="py-4 px-6">رابطہ / شناختی کارڈ</th>
                    <th className="py-4 px-6">تعلیم و عہدہ</th>
                    <th className="py-4 px-6">تاریخ شمولیت</th>
                    <th className="py-4 px-6">سٹیٹس</th>
                    <th className="py-4 px-6 text-center">ایکشن</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-slate-100 dark:divide-slate-700">
                  {loading ? (
                    <tr><td colSpan={7} className="py-10 text-center text-slate-500 dark:text-slate-400 font-bold text-lg">ڈیٹا لوڈ ہو رہا ہے...</td></tr>
                  ) : filteredTeachers.length === 0 ? (
                    <tr><td colSpan={7} className="py-10 text-center text-slate-500 dark:text-slate-400 font-bold text-lg">کوئی ریکارڈ نہیں ملا</td></tr>
                  ) : (
                    filteredTeachers.map((t, idx) => (
                      <tr key={t.id} className="hover:bg-slate-50 dark:hover:bg-slate-700/50 transition-colors group">
                        <td className="py-4 px-6 font-bold text-slate-600 dark:text-slate-400 text-lg">{idx + 1}</td>
                        <td className="py-4 px-6">
                          <div className="font-bold text-slate-800 dark:text-slate-100 text-xl">{t.name}</div>
                          <div className="text-slate-500 dark:text-slate-400 text-sm">ولد {t.father_name}</div>
                        </td>
                        <td className="py-4 px-6 font-sans">
                          <div className="text-slate-700 dark:text-slate-300 font-medium" dir="ltr">{t.phone}</div>
                          <div className="text-slate-500 dark:text-slate-400 text-sm" dir="ltr">{t.cnic}</div>
                        </td>
                        <td className="py-4 px-6 text-slate-700 dark:text-slate-300 text-lg">{t.qualification || '-'}</td>
                        <td className="py-4 px-6 text-slate-700 dark:text-slate-300 font-sans">{t.joining_date}</td>
                        <td className="py-4 px-6">
                          <span className={`px-3 py-1 rounded-full text-sm font-bold ${
                            t.status === 'Active' ? 'bg-emerald-100 text-emerald-700' : 'bg-red-100 text-red-700'
                          }`}>
                            {t.status === 'Active' ? 'فعال' : 'غیر فعال'}
                          </span>
                        </td>
                        <td className="py-4 px-6">
                          <div className="flex items-center justify-center gap-2">
                            <button onClick={() => openModal('edit', t)} className="p-2 bg-theme-primary/10 hover:bg-theme-primary/20 text-theme-primary rounded-lg transition-colors" title="ترمیم">✏️</button>
                            <button onClick={() => openModal('delete', t)} className="p-2 bg-red-100 hover:bg-red-200 text-red-600 rounded-lg transition-colors" title="حذف کریں">🗑️</button>
                          </div>
                        </td>
                      </tr>
                    ))
                  )}
                </tbody>
              </table>
            </div>
          </div>
        </div>
      </main>

      {/* Modals */}
      {isModalOpen && (
        <div className="fixed inset-0 bg-slate-900/50 backdrop-blur-sm flex items-center justify-center z-50 p-4 transition-colors">
          <div className="bg-white dark:bg-slate-800 rounded-3xl shadow-2xl w-full max-w-4xl max-h-[90vh] overflow-y-auto animate-in fade-in zoom-in duration-300 border border-slate-200 dark:border-slate-700 custom-scrollbar">
            <div className="bg-slate-50 dark:bg-slate-700/50 px-8 py-5 border-b border-slate-200 dark:border-slate-700 flex justify-between items-center sticky top-0 z-10">
              <h3 className="text-2xl font-bold text-slate-800 dark:text-slate-100 flex items-center gap-3">
                {modalMode === 'add' && 'نیا استاد / سٹاف شامل کریں'}
                {modalMode === 'edit' && 'ریکارڈ اپڈیٹ کریں'}
                {modalMode === 'delete' && 'محذوف کریں'}
              </h3>
              <button onClick={() => setIsModalOpen(false)} className="text-slate-400 hover:text-red-500 transition-colors text-3xl font-sans leading-none">&times;</button>
            </div>
            
            <div className="p-8">
              {message && (
                <div className={`mb-6 p-4 rounded-xl font-bold text-lg border ${message.type === 'success' ? 'bg-emerald-50 text-emerald-700 border-emerald-100' : 'bg-red-50 text-red-600 border-red-100'}`}>
                  {message.text}
                </div>
              )}

              {modalMode === 'delete' ? (
                <div className="text-center py-6">
                  <p className="text-2xl text-slate-800 dark:text-slate-200 mb-8 font-bold">کیا آپ واقعی <span className="text-red-600">"{selectedTeacher?.name}"</span> کا ریکارڈ حذف کرنا چاہتے ہیں؟</p>
                  <div className="flex gap-4 justify-center">
                    <button onClick={() => setIsModalOpen(false)} className="px-8 py-3 rounded-xl bg-slate-100 dark:bg-slate-700 text-slate-700 dark:text-slate-300 font-bold hover:bg-slate-200 dark:hover:bg-slate-600 text-xl transition-colors">منسوخ کریں</button>
                    <button onClick={handleDelete} disabled={saving} className="px-8 py-3 rounded-xl bg-red-600 text-white font-bold hover:bg-red-700 shadow-lg shadow-red-200 dark:shadow-none text-xl transition-colors">
                      {saving ? 'ہو رہا ہے...' : 'ہاں، ڈیلیٹ کریں'}
                    </button>
                  </div>
                </div>
              ) : (
                <form onSubmit={handleSave} className="grid grid-cols-1 md:grid-cols-12 gap-6">
                  
                  {/* Personal Info */}
                  <div className="md:col-span-12 mb-2">
                    <h4 className="text-xl font-bold text-theme-primary border-b border-theme-primary/20 pb-2">ذاتی معلومات</h4>
                  </div>

                  <div className="md:col-span-6">
                    <label className="block text-slate-700 dark:text-slate-300 font-bold mb-2 text-lg">نام *</label>
                    <input type="text" required className="w-full px-4 py-3 rounded-xl border border-slate-200 dark:border-slate-600 focus:ring-2 focus:ring-theme-primary bg-slate-50 dark:bg-slate-700 text-slate-800 dark:text-slate-100 text-lg transition-colors"
                      value={formData.name || ''} onChange={(e) => setFormData({...formData, name: e.target.value})} />
                  </div>
                  <div className="md:col-span-6">
                    <label className="block text-slate-700 dark:text-slate-300 font-bold mb-2 text-lg">ولدیت *</label>
                    <input type="text" required className="w-full px-4 py-3 rounded-xl border border-slate-200 dark:border-slate-600 focus:ring-2 focus:ring-theme-primary bg-slate-50 dark:bg-slate-700 text-slate-800 dark:text-slate-100 text-lg transition-colors"
                      value={formData.father_name || ''} onChange={(e) => setFormData({...formData, father_name: e.target.value})} />
                  </div>
                  <div className="md:col-span-4">
                    <label className="block text-slate-700 dark:text-slate-300 font-bold mb-2 text-lg">شناختی کارڈ نمبر</label>
                    <input type="text" className="w-full px-4 py-3 rounded-xl border border-slate-200 dark:border-slate-600 focus:ring-2 focus:ring-theme-primary bg-slate-50 dark:bg-slate-700 text-slate-800 dark:text-slate-100 text-lg font-sans transition-colors" dir="ltr"
                      value={formData.cnic || ''} onChange={(e) => setFormData({...formData, cnic: e.target.value})} />
                  </div>
                  <div className="md:col-span-4">
                    <label className="block text-slate-700 dark:text-slate-300 font-bold mb-2 text-lg">رابطہ نمبر</label>
                    <input type="text" className="w-full px-4 py-3 rounded-xl border border-slate-200 dark:border-slate-600 focus:ring-2 focus:ring-theme-primary bg-slate-50 dark:bg-slate-700 text-slate-800 dark:text-slate-100 text-lg font-sans transition-colors" dir="ltr"
                      value={formData.phone || ''} onChange={(e) => setFormData({...formData, phone: e.target.value})} />
                  </div>
                  <div className="md:col-span-4">
                    <label className="block text-slate-700 dark:text-slate-300 font-bold mb-2 text-lg">تعلیم / قابلیت</label>
                    <input type="text" className="w-full px-4 py-3 rounded-xl border border-slate-200 dark:border-slate-600 focus:ring-2 focus:ring-theme-primary bg-slate-50 dark:bg-slate-700 text-slate-800 dark:text-slate-100 text-lg transition-colors"
                      value={formData.qualification || ''} onChange={(e) => setFormData({...formData, qualification: e.target.value})} />
                  </div>
                  <div className="md:col-span-12">
                    <label className="block text-slate-700 dark:text-slate-300 font-bold mb-2 text-lg">مکمل پتہ</label>
                    <input type="text" className="w-full px-4 py-3 rounded-xl border border-slate-200 dark:border-slate-600 focus:ring-2 focus:ring-theme-primary bg-slate-50 dark:bg-slate-700 text-slate-800 dark:text-slate-100 text-lg transition-colors"
                      value={formData.address || ''} onChange={(e) => setFormData({...formData, address: e.target.value})} />
                  </div>

                  {/* Employment Info */}
                  <div className="md:col-span-12 mt-4 mb-2">
                    <h4 className="text-xl font-bold text-theme-primary border-b border-theme-primary/20 pb-2">ملازمت و مالیات</h4>
                  </div>

                  <div className="md:col-span-3">
                    <label className="block text-slate-700 dark:text-slate-300 font-bold mb-2 text-lg">بنیادی تنخواہ (Salary)</label>
                    <input type="number" className="w-full px-4 py-3 rounded-xl border border-slate-200 dark:border-slate-600 focus:ring-2 focus:ring-theme-primary bg-slate-50 dark:bg-slate-700 text-slate-800 dark:text-slate-100 text-lg font-sans transition-colors" dir="ltr"
                      value={formData.salary || 0} onChange={(e) => setFormData({...formData, salary: Number(e.target.value)})} />
                  </div>
                  <div className="md:col-span-3">
                    <label className="block text-slate-700 dark:text-slate-300 font-bold mb-2 text-lg">ہاؤس رینٹ</label>
                    <input type="number" className="w-full px-4 py-3 rounded-xl border border-slate-200 dark:border-slate-600 focus:ring-2 focus:ring-theme-primary bg-slate-50 dark:bg-slate-700 text-slate-800 dark:text-slate-100 text-lg font-sans transition-colors" dir="ltr"
                      value={formData.house_rent || 0} onChange={(e) => setFormData({...formData, house_rent: Number(e.target.value)})} />
                  </div>
                  <div className="md:col-span-3">
                    <label className="block text-slate-700 dark:text-slate-300 font-bold mb-2 text-lg">میڈیکل الاؤنس</label>
                    <input type="number" className="w-full px-4 py-3 rounded-xl border border-slate-200 dark:border-slate-600 focus:ring-2 focus:ring-theme-primary bg-slate-50 dark:bg-slate-700 text-slate-800 dark:text-slate-100 text-lg font-sans transition-colors" dir="ltr"
                      value={formData.medical_allowance || 0} onChange={(e) => setFormData({...formData, medical_allowance: Number(e.target.value)})} />
                  </div>
                  <div className="md:col-span-3">
                    <label className="block text-slate-700 dark:text-slate-300 font-bold mb-2 text-lg">سفری الاؤنس (Travel)</label>
                    <input type="number" className="w-full px-4 py-3 rounded-xl border border-slate-200 dark:border-slate-600 focus:ring-2 focus:ring-theme-primary bg-slate-50 dark:bg-slate-700 text-slate-800 dark:text-slate-100 text-lg font-sans transition-colors" dir="ltr"
                      value={formData.travel_allowance || 0} onChange={(e) => setFormData({...formData, travel_allowance: Number(e.target.value)})} />
                  </div>
                  
                  <div className="md:col-span-4">
                    <label className="block text-slate-700 dark:text-slate-300 font-bold mb-2 text-lg">تاریخ شمولیت</label>
                    <input type="date" className="w-full px-4 py-3 rounded-xl border border-slate-200 dark:border-slate-600 focus:ring-2 focus:ring-theme-primary bg-slate-50 dark:bg-slate-700 text-slate-800 dark:text-slate-100 text-lg font-sans transition-colors" 
                      value={formData.joining_date || ''} onChange={(e) => setFormData({...formData, joining_date: e.target.value})} />
                  </div>
                  <div className="md:col-span-4">
                    <label className="block text-slate-700 dark:text-slate-300 font-bold mb-2 text-lg">سٹیٹس (Status)</label>
                    <select className="w-full px-4 py-3 rounded-xl border border-slate-200 dark:border-slate-600 focus:ring-2 focus:ring-theme-primary bg-slate-50 dark:bg-slate-700 text-slate-800 dark:text-slate-100 text-lg transition-colors"
                      value={formData.status || 'Active'} onChange={(e) => setFormData({...formData, status: e.target.value})}>
                      <option value="Active">فعال (Active)</option>
                      <option value="Inactive">غیر فعال (Inactive)</option>
                    </select>
                  </div>
                  <div className="md:col-span-4">
                    <label className="block text-slate-700 dark:text-slate-300 font-bold mb-2 text-lg">یومیہ کٹوتی کی شرح (Deduction)</label>
                    <input type="number" className="w-full px-4 py-3 rounded-xl border border-slate-200 dark:border-slate-600 focus:ring-2 focus:ring-theme-primary bg-slate-50 dark:bg-slate-700 text-slate-800 dark:text-slate-100 text-lg font-sans transition-colors" dir="ltr"
                      value={formData.daily_deduction_rate || 0} onChange={(e) => setFormData({...formData, daily_deduction_rate: Number(e.target.value)})} />
                  </div>
                  
                  <div className="md:col-span-12 flex justify-end gap-4 mt-6 border-t border-slate-200 dark:border-slate-700 pt-6">
                    <button type="button" onClick={() => setIsModalOpen(false)} className="px-8 py-3 rounded-xl bg-slate-100 dark:bg-slate-700 text-slate-700 dark:text-slate-300 font-bold hover:bg-slate-200 dark:hover:bg-slate-600 text-xl transition-colors">منسوخ کریں</button>
                    <button type="submit" disabled={saving} className="px-10 py-3 rounded-xl bg-theme-primary hover:bg-theme-hover text-theme-light font-bold shadow-lg transition-all active:scale-95 text-xl">
                      {saving ? 'محفوظ ہو رہا ہے...' : 'محفوظ کریں'}
                    </button>
                  </div>
                </form>
              )}
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
