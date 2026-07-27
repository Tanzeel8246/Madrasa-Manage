'use client';

import { useState, useEffect } from 'react';
import Link from 'next/link';

interface Period {
  id?: number;
  period_no: number;
  books: string;
  teacher_ids: number[];
}

interface ClassModel {
  id: number;
  name: string;
  section: string;
  class_type: string;
  main_teacher_ids: number[];
  subjects_list: string;
  periods: Period[];
}

interface Teacher {
  id: number;
  name: string;
}

export default function ClassesPage() {
  const [classes, setClasses] = useState<ClassModel[]>([]);
  const [teachers, setTeachers] = useState<Teacher[]>([]);
  const [loading, setLoading] = useState(true);
  const [search, setSearch] = useState('');
  
  const [isModalOpen, setIsModalOpen] = useState(false);
  const [modalMode, setModalMode] = useState<'add'|'edit'|'delete'>('add');
  const [selectedClass, setSelectedClass] = useState<ClassModel | null>(null);
  
  const [formData, setFormData] = useState<Partial<ClassModel>>({});
  const [formPeriods, setFormPeriods] = useState<Period[]>([]);
  const [saving, setSaving] = useState(false);
  const [message, setMessage] = useState<{type: 'success'|'error', text: string} | null>(null);

  const fetchData = async () => {
    setLoading(true);
    try {
      const [clsRes, tchrRes] = await Promise.all([
        fetch('/api/classes'),
        fetch('/api/teachers')
      ]);
      const clsData = await clsRes.json();
      const tchrData = await tchrRes.json();
      
      if (clsData.success) {
        // Parse JSON strings to arrays
        const parsedClasses = clsData.data.map((c: any) => ({
          ...c,
          main_teacher_ids: typeof c.main_teacher_ids === 'string' ? JSON.parse(c.main_teacher_ids) : c.main_teacher_ids,
          periods: (c.periods || []).map((p: any) => ({
            ...p,
            teacher_ids: typeof p.teacher_ids === 'string' ? JSON.parse(p.teacher_ids) : p.teacher_ids
          }))
        }));
        setClasses(parsedClasses);
      }
      if (tchrData.success) {
        setTeachers(tchrData.data.filter((t: any) => t.status !== 'Inactive'));
      }
    } catch (error) {
      console.error('Error fetching data:', error);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchData();
  }, []);

  const openModal = (mode: 'add'|'edit'|'delete', cls?: ClassModel) => {
    setModalMode(mode);
    setSelectedClass(cls || null);
    setMessage(null);
    if (mode === 'edit' && cls) {
      setFormData(cls);
      // Ensure we have 8 periods initialized
      const periodsMap = new Map(cls.periods.map(p => [p.period_no, p]));
      const initializedPeriods = Array.from({length: 8}, (_, i) => {
        const pNo = i + 1;
        return periodsMap.get(pNo) || { period_no: pNo, books: '', teacher_ids: [] };
      });
      setFormPeriods(initializedPeriods);
    } else if (mode === 'add') {
      setFormData({
        class_type: 'Darse Nizami / Other',
        main_teacher_ids: []
      });
      setFormPeriods(Array.from({length: 8}, (_, i) => ({ period_no: i + 1, books: '', teacher_ids: [] })));
    }
    setIsModalOpen(true);
  };

  const handleSave = async (e: React.FormEvent) => {
    e.preventDefault();
    setSaving(true);
    setMessage(null);

    try {
      const url = '/api/classes';
      const method = modalMode === 'edit' ? 'PUT' : 'POST';
      
      const payload = {
        ...formData,
        periods: formPeriods.filter(p => p.books !== '' || p.teacher_ids.length > 0)
      };

      const res = await fetch(url, {
        method,
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(payload)
      });
      
      const data = await res.json();
      if (data.success) {
        setMessage({ type: 'success', text: data.message });
        fetchData();
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
    if (!selectedClass) return;
    setSaving(true);
    try {
      const res = await fetch(`/api/classes?id=${selectedClass.id}`, { method: 'DELETE' });
      const data = await res.json();
      if (data.success) {
        fetchData();
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

  const handlePeriodChange = (index: number, field: keyof Period, value: any) => {
    const updated = [...formPeriods];
    updated[index] = { ...updated[index], [field]: value };
    setFormPeriods(updated);
  };

  const filteredClasses = classes.filter(c => 
    c.name?.toLowerCase().includes(search.toLowerCase()) || 
    c.section?.toLowerCase().includes(search.toLowerCase())
  );

  return (
    <div className="flex flex-col bg-slate-50 dark:bg-slate-900 font-urdu transition-colors" dir="rtl">
      <main className="flex-1">
        <header className="h-20 bg-white/80 dark:bg-slate-800/80 backdrop-blur-md border-b border-slate-200 dark:border-slate-700 flex items-center justify-between px-8 sticky top-0 z-10 transition-colors">
          <div className="flex items-center gap-4">
            <Link href="/" className="text-theme-primary dark:text-theme-light hover:text-theme-hover transition-colors bg-theme-primary/10 p-2 rounded-lg">
              <span className="text-xl">🏠</span>
            </Link>
            <h2 className="text-2xl font-bold text-slate-800 dark:text-slate-100">کلاسز اور پیریڈز مینجمنٹ</h2>
          </div>
          <button 
            onClick={() => openModal('add')}
            className="bg-theme-primary hover:bg-theme-hover text-white px-6 py-2 rounded-lg font-bold shadow-md hover:shadow-lg transition-all flex items-center gap-2"
          >
            <span className="text-xl">+</span> نئی کلاس شامل کریں
          </button>
        </header>

        <div className="p-8">
          <div className="bg-white dark:bg-slate-800 p-4 rounded-2xl shadow-sm border border-slate-200 dark:border-slate-700 mb-6 flex gap-4 transition-colors">
            <input 
              type="text"
              placeholder="کلاس کا نام یا سیکشن سے تلاش کریں..."
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
                    <th className="py-4 px-6">کلاس کا نام</th>
                    <th className="py-4 px-6">سیکشن</th>
                    <th className="py-4 px-6">کلاس کی قسم</th>
                    <th className="py-4 px-6">پیریڈز کی تعداد</th>
                    <th className="py-4 px-6 text-center">ایکشن</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-slate-100 dark:divide-slate-700">
                  {loading ? (
                    <tr><td colSpan={6} className="py-10 text-center text-slate-500 dark:text-slate-400 font-bold text-lg">ڈیٹا لوڈ ہو رہا ہے...</td></tr>
                  ) : filteredClasses.length === 0 ? (
                    <tr><td colSpan={6} className="py-10 text-center text-slate-500 dark:text-slate-400 font-bold text-lg">کوئی ریکارڈ نہیں ملا</td></tr>
                  ) : (
                    filteredClasses.map((c, idx) => (
                      <tr key={c.id} className="hover:bg-slate-50 dark:hover:bg-slate-700/50 transition-colors group">
                        <td className="py-4 px-6 font-bold text-slate-600 dark:text-slate-400 text-lg">{idx + 1}</td>
                        <td className="py-4 px-6 font-bold text-slate-800 dark:text-slate-100 text-xl">{c.name}</td>
                        <td className="py-4 px-6 text-slate-700 dark:text-slate-300 font-sans">{c.section || '-'}</td>
                        <td className="py-4 px-6">
                          <span className="px-3 py-1 rounded-full text-sm font-bold bg-theme-primary/10 text-theme-primary">
                            {c.class_type}
                          </span>
                        </td>
                        <td className="py-4 px-6 text-slate-700 dark:text-slate-300">
                          <span className="bg-slate-100 dark:bg-slate-700 px-3 py-1 rounded-md font-sans font-bold">
                            {c.periods.length} پیریڈز
                          </span>
                        </td>
                        <td className="py-4 px-6">
                          <div className="flex items-center justify-center gap-2">
                            <button onClick={() => openModal('edit', c)} className="p-2 bg-theme-primary/10 hover:bg-theme-primary/20 text-theme-primary rounded-lg transition-colors" title="ترمیم">✏️</button>
                            <button onClick={() => openModal('delete', c)} className="p-2 bg-red-100 hover:bg-red-200 text-red-600 rounded-lg transition-colors" title="حذف کریں">🗑️</button>
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
          <div className="bg-white dark:bg-slate-800 rounded-3xl shadow-2xl w-full max-w-5xl max-h-[90vh] overflow-hidden flex flex-col animate-in fade-in zoom-in duration-300 border border-slate-200 dark:border-slate-700">
            <div className="bg-slate-50 dark:bg-slate-700/50 px-8 py-5 border-b border-slate-200 dark:border-slate-700 flex justify-between items-center">
              <h3 className="text-2xl font-bold text-slate-800 dark:text-slate-100 flex items-center gap-3">
                {modalMode === 'add' && 'نئی کلاس اور پیریڈز شامل کریں'}
                {modalMode === 'edit' && 'کلاس اور پیریڈز اپڈیٹ کریں'}
                {modalMode === 'delete' && 'محذوف کریں'}
              </h3>
              <button onClick={() => setIsModalOpen(false)} className="text-slate-400 hover:text-red-500 transition-colors text-3xl font-sans leading-none">&times;</button>
            </div>
            
            <div className="p-8 overflow-y-auto flex-1 custom-scrollbar">
              {message && (
                <div className={`mb-6 p-4 rounded-xl font-bold text-lg border ${message.type === 'success' ? 'bg-emerald-50 text-emerald-700 border-emerald-100' : 'bg-red-50 text-red-600 border-red-100'}`}>
                  {message.text}
                </div>
              )}

              {modalMode === 'delete' ? (
                <div className="text-center py-6">
                  <p className="text-2xl text-slate-800 dark:text-slate-200 mb-8 font-bold">کیا آپ واقعی <span className="text-red-600">"{selectedClass?.name}"</span> کو حذف کرنا چاہتے ہیں؟ اس سے وابستہ تمام پیریڈز بھی ڈیلیٹ ہو جائیں گے۔</p>
                  <div className="flex gap-4 justify-center">
                    <button onClick={() => setIsModalOpen(false)} className="px-8 py-3 rounded-xl bg-slate-100 dark:bg-slate-700 text-slate-700 dark:text-slate-300 font-bold hover:bg-slate-200 dark:hover:bg-slate-600 text-xl transition-colors">منسوخ کریں</button>
                    <button onClick={handleDelete} disabled={saving} className="px-8 py-3 rounded-xl bg-red-600 text-white font-bold hover:bg-red-700 shadow-lg shadow-red-200 dark:shadow-none text-xl transition-colors">
                      {saving ? 'ہو رہا ہے...' : 'ہاں، ڈیلیٹ کریں'}
                    </button>
                  </div>
                </div>
              ) : (
                <form onSubmit={handleSave} className="space-y-8">
                  
                  {/* Class Info */}
                  <div>
                    <h4 className="text-xl font-bold text-theme-primary border-b border-theme-primary/20 pb-2 mb-6">کلاس کی معلومات</h4>
                    <div className="grid grid-cols-1 md:grid-cols-12 gap-6">
                      <div className="md:col-span-4">
                        <label className="block text-slate-700 dark:text-slate-300 font-bold mb-2 text-lg">کلاس کا نام *</label>
                        <input type="text" required className="w-full px-4 py-3 rounded-xl border border-slate-200 dark:border-slate-600 focus:ring-2 focus:ring-theme-primary bg-slate-50 dark:bg-slate-700 text-slate-800 dark:text-slate-100 text-lg transition-colors"
                          placeholder="مثلاً: درجہ اولیٰ"
                          value={formData.name || ''} onChange={(e) => setFormData({...formData, name: e.target.value})} />
                      </div>
                      <div className="md:col-span-4">
                        <label className="block text-slate-700 dark:text-slate-300 font-bold mb-2 text-lg">سیکشن</label>
                        <input type="text" className="w-full px-4 py-3 rounded-xl border border-slate-200 dark:border-slate-600 focus:ring-2 focus:ring-theme-primary bg-slate-50 dark:bg-slate-700 text-slate-800 dark:text-slate-100 text-lg transition-colors font-sans"
                          placeholder="مثلاً: A, B, Boys"
                          value={formData.section || ''} onChange={(e) => setFormData({...formData, section: e.target.value})} />
                      </div>
                      <div className="md:col-span-4">
                        <label className="block text-slate-700 dark:text-slate-300 font-bold mb-2 text-lg">کلاس کی قسم</label>
                        <select required className="w-full px-4 py-3 rounded-xl border border-slate-200 dark:border-slate-600 focus:ring-2 focus:ring-theme-primary bg-slate-50 dark:bg-slate-700 text-slate-800 dark:text-slate-100 text-lg transition-colors"
                          value={formData.class_type || 'Darse Nizami / Other'} onChange={(e) => setFormData({...formData, class_type: e.target.value})}>
                          <optgroup label="قرآن کریم">
                            <option value="Hifz/Gardan/Husn">حفظ، گردان، حسن صوت</option>
                            <option value="Nazira">ناظرہ</option>
                            <option value="Qaida">نورانی قاعدہ / نماز حنفی</option>
                            <option value="Tajweed">تجوید</option>
                          </optgroup>
                          <optgroup label="دیگر">
                            <option value="Asri Taleem">عصری تعلیم</option>
                            <option value="Darse Nizami">درس نظامی / Other</option>
                          </optgroup>
                        </select>
                      </div>
                    </div>
                  </div>

                  {/* Periods Info */}
                  <div>
                    <h4 className="text-xl font-bold text-theme-primary border-b border-theme-primary/20 pb-2 mb-6">پیریڈز اور اساتذہ کی تفصیل</h4>
                    
                    <div className="bg-slate-50 dark:bg-slate-800/50 rounded-2xl border border-slate-200 dark:border-slate-700 p-4">
                      <div className="grid grid-cols-12 gap-4 mb-2 font-bold text-slate-600 dark:text-slate-400 text-center border-b border-slate-200 dark:border-slate-700 pb-2">
                        <div className="col-span-1">پیریڈ نمبر</div>
                        <div className="col-span-5 text-right pr-2">کتاب / مضمون کا نام</div>
                        <div className="col-span-6 text-right pr-2">متعلقہ اساتذہ (ایک یا زائد منتخب کریں)</div>
                      </div>
                      
                      {formPeriods.map((period, index) => (
                        <div key={index} className="grid grid-cols-12 gap-4 items-center mb-3">
                          <div className="col-span-1 text-center font-bold font-sans text-xl text-slate-700 dark:text-slate-300">
                            {period.period_no}
                          </div>
                          <div className="col-span-5">
                            <input 
                              type="text" 
                              className="w-full px-3 py-2 rounded-lg border border-slate-200 dark:border-slate-600 focus:ring-2 focus:ring-theme-primary bg-white dark:bg-slate-700 text-slate-800 dark:text-slate-100 transition-colors"
                              placeholder="کتاب کا نام..."
                              value={period.books}
                              onChange={(e) => handlePeriodChange(index, 'books', e.target.value)}
                            />
                          </div>
                          <div className="col-span-6">
                            <select 
                              multiple 
                              className="w-full px-3 py-2 rounded-lg border border-slate-200 dark:border-slate-600 focus:ring-2 focus:ring-theme-primary bg-white dark:bg-slate-700 text-slate-800 dark:text-slate-100 transition-colors custom-scrollbar h-24"
                              value={period.teacher_ids.map(String)}
                              onChange={(e) => {
                                const selectedOpts = Array.from(e.target.selectedOptions).map(opt => Number(opt.value));
                                handlePeriodChange(index, 'teacher_ids', selectedOpts);
                              }}
                            >
                              {teachers.map(t => (
                                <option key={t.id} value={t.id} className="py-1 px-2 mb-1 rounded hover:bg-theme-primary/10 checked:bg-theme-primary/20 checked:text-theme-primary checked:font-bold">
                                  {t.name}
                                </option>
                              ))}
                            </select>
                          </div>
                        </div>
                      ))}
                    </div>
                  </div>
                  
                  <div className="flex justify-end gap-4 mt-6 border-t border-slate-200 dark:border-slate-700 pt-6">
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
