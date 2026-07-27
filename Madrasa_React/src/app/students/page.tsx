'use client';

import { useEffect, useState } from 'react';
import { useRouter } from 'next/navigation';
import Link from 'next/link';

export default function StudentsPage() {
  const [students, setStudents] = useState<any[]>([]);
  const [search, setSearch] = useState('');
  const [loading, setLoading] = useState(true);
  
  // Modal states
  const [isModalOpen, setIsModalOpen] = useState(false);
  const [modalMode, setModalMode] = useState<'add' | 'edit' | 'view' | 'delete' | 'promote' | 'alumni' | 'idcard'>('add');
  const [selectedStudent, setSelectedStudent] = useState<any>(null);
  
  // Additional states for specific actions
  const [promoteClass, setPromoteClass] = useState('');
  
  // Form states
  const [formData, setFormData] = useState({
    id: '',
    name: '',
    father_name: '',
    admission_number: '',
    class: '',
    contact_number: '',
    address: '',
    admission_date: new Date().toISOString().split('T')[0],
    photoBase64: ''
  });

  const [saving, setSaving] = useState(false);
  const [message, setMessage] = useState<{type: 'success'|'error', text: string} | null>(null);

  const fetchStudents = async () => {
    setLoading(true);
    try {
      const res = await fetch(`/api/students?search=${search}`);
      const data = await res.json();
      if (data.success) {
        setStudents(data.students);
      }
    } catch (error) {
      console.error('Failed to fetch students', error);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchStudents();
  }, [search]);

  const handlePhotoUpload = (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (file) {
      const reader = new FileReader();
      reader.onloadend = () => {
        setFormData({ ...formData, photoBase64: reader.result as string });
      };
      reader.readAsDataURL(file);
    }
  };

  const openModal = (mode: 'add' | 'edit' | 'view' | 'delete' | 'promote' | 'alumni' | 'idcard', student: any = null) => {
    setModalMode(mode);
    setSelectedStudent(student);
    setMessage(null);
    setPromoteClass('');
    
    if (student && (mode === 'edit' || mode === 'view' || mode === 'idcard')) {
      setFormData({
        id: student.id,
        name: student.name || '',
        father_name: student.father_name || '',
        admission_number: student.admission_number || '',
        class: student.class || '',
        contact_number: student.contact_number || '',
        address: student.address || '',
        admission_date: student.admission_date ? student.admission_date.split('T')[0] : '',
        photoBase64: student.photo || '' 
      });
    } else {
      setFormData({
        id: '', name: '', father_name: '', admission_number: '', class: '', contact_number: '', address: '', admission_date: new Date().toISOString().split('T')[0], photoBase64: ''
      });
    }
    
    setIsModalOpen(true);
  };

  const handleSave = async (e: React.FormEvent) => {
    e.preventDefault();
    setSaving(true);
    setMessage(null);

    const method = modalMode === 'add' ? 'POST' : 'PUT';
    
    try {
      const res = await fetch('/api/students', {
        method,
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(formData)
      });
      
      const data = await res.json();
      if (data.success) {
        setMessage({ type: 'success', text: data.message });
        fetchStudents();
        setTimeout(() => setIsModalOpen(false), 1500);
      } else {
        setMessage({ type: 'error', text: data.message });
      }
    } catch (error) {
      setMessage({ type: 'error', text: 'سرور سے رابطہ منقطع ہو گیا۔' });
    } finally {
      setSaving(false);
    }
  };

  const handleDelete = async () => {
    setSaving(true);
    try {
      const res = await fetch(`/api/students?id=${selectedStudent.id}`, { method: 'DELETE' });
      const data = await res.json();
      if (data.success) {
        fetchStudents();
        setIsModalOpen(false);
      } else {
        setMessage({ type: 'error', text: data.message });
      }
    } catch (error) {
      setMessage({ type: 'error', text: 'سرور سے رابطہ منقطع ہو گیا۔' });
    } finally {
      setSaving(false);
    }
  };

  const handlePromote = async () => {
    if (!promoteClass) return;
    setSaving(true);
    try {
      const res = await fetch('/api/students', {
        method: 'PUT',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ ...selectedStudent, class: promoteClass, photoBase64: selectedStudent.photo || '' })
      });
      const data = await res.json();
      if (data.success) {
        fetchStudents();
        setIsModalOpen(false);
      }
    } catch (error) {
      console.error(error);
    } finally {
      setSaving(false);
    }
  };

  const handleAlumni = async () => {
    setSaving(true);
    try {
      const res = await fetch(`/api/students?id=${selectedStudent.id}&type=alumni`, { method: 'DELETE' });
      const data = await res.json();
      if (data.success) {
        fetchStudents();
        setIsModalOpen(false);
      }
    } catch (error) {
      console.error(error);
    } finally {
      setSaving(false);
    }
  };

  return (
    <div className="flex flex-col bg-slate-50 dark:bg-slate-900 font-urdu transition-colors" dir="rtl">
      <main className="flex-1">
        <header className="h-20 bg-white/80 dark:bg-slate-800/80 backdrop-blur-md border-b border-slate-200 dark:border-slate-700 flex items-center justify-between px-8 sticky top-0 z-10 print:hidden transition-colors">
          <div className="flex items-center gap-4">
            <Link href="/" className="text-indigo-600 dark:text-indigo-400 hover:text-indigo-800 dark:hover:text-indigo-300 transition-colors bg-indigo-50 dark:bg-indigo-900/30 p-2 rounded-lg">
              <span className="text-xl">🏠</span>
            </Link>
            <h2 className="text-2xl font-bold text-slate-800 dark:text-slate-100">طلباء کا ریکارڈ</h2>
          </div>
          <button 
            onClick={() => openModal('add')}
            className="bg-gradient-to-r from-emerald-600 to-teal-600 hover:from-emerald-700 hover:to-teal-700 text-white px-6 py-2.5 rounded-xl font-bold shadow-lg shadow-emerald-200 transition-all active:scale-95 text-lg flex items-center gap-2"
          >
            <span>➕</span> نیا طالب علم شامل کریں
          </button>
        </header>
        
        <div className="p-8 print:hidden">
          <div className="bg-white dark:bg-slate-800 p-4 rounded-2xl shadow-sm border border-slate-200 dark:border-slate-700 mb-6 flex gap-4 transition-colors">
            <input 
              type="text"
              placeholder="طالب علم کا نام، والد کا نام یا رول نمبر سے تلاش کریں..."
              className="flex-1 px-5 py-3 rounded-xl border border-slate-200 dark:border-slate-600 focus:outline-none focus:ring-2 focus:ring-emerald-500 transition-all bg-slate-50 dark:bg-slate-700 text-slate-800 dark:text-slate-200 text-lg"
              value={search}
              onChange={(e) => setSearch(e.target.value)}
            />
          </div>

          <div className="bg-white dark:bg-slate-800 rounded-2xl shadow-sm border border-slate-200 dark:border-slate-700 overflow-hidden transition-colors">
            <div className="overflow-x-auto">
              <table className="w-full text-center border-collapse">
                <thead>
                  <tr className="bg-slate-50 dark:bg-slate-700/50 border-b border-slate-200 dark:border-slate-700 text-slate-600 dark:text-slate-300 font-bold text-lg">
                    <th className="py-4 px-4 font-bold">نمبر شمار</th>
                    <th className="py-4 px-4 font-bold">رول نمبر</th>
                    <th className="py-4 px-4 font-bold">تصویر</th>
                    <th className="py-4 px-4 font-bold text-right">نام طالب علم</th>
                    <th className="py-4 px-4 font-bold text-right">ولدیت</th>
                    <th className="py-4 px-4 font-bold">رابطہ</th>
                    <th className="py-4 px-4 font-bold w-[250px]">ایکشن</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-slate-100 dark:divide-slate-700">
                  {loading ? (
                    <tr><td colSpan={7} className="py-10 text-center text-slate-500 dark:text-slate-400 font-bold text-lg">ڈیٹا لوڈ ہو رہا ہے...</td></tr>
                  ) : students.length === 0 ? (
                    <tr><td colSpan={7} className="py-10 text-center text-slate-500 dark:text-slate-400 font-bold text-lg">کوئی ریکارڈ نہیں ملا</td></tr>
                  ) : (
                    students.map((std, idx) => (
                      <tr key={std.id} className="border-b border-slate-50 dark:border-slate-700 hover:bg-slate-50 dark:hover:bg-slate-700/50 transition-colors bg-white dark:bg-slate-800">
                        <td className="py-3 px-4 font-bold text-slate-600 dark:text-slate-400 text-lg">{idx + 1}</td>
                        <td className="py-3 px-4 font-bold text-slate-800 dark:text-slate-200 font-sans text-lg">{std.admission_number}</td>
                        <td className="py-3 px-4">
                          <div className="w-12 h-12 rounded-full bg-slate-200 dark:bg-slate-700 border-2 border-white dark:border-slate-600 shadow-sm overflow-hidden mx-auto flex items-center justify-center text-slate-400">
                            {std.photo ? (
                              <img src={std.photo} alt="Photo" className="w-full h-full object-cover" />
                            ) : '👤'}
                          </div>
                        </td>
                        <td className="py-3 px-4 font-bold text-slate-800 dark:text-slate-100 text-xl text-right">{std.name}</td>
                        <td className="py-3 px-4 text-slate-600 dark:text-slate-300 text-lg text-right">{std.father_name}</td>
                        <td className="py-3 px-4 text-slate-600 dark:text-slate-300 font-sans text-lg">{std.contact_number}</td>
                        <td className="py-3 px-4">
                          <div className="flex items-center justify-center gap-1 bg-slate-800 dark:bg-slate-900 p-1 rounded-lg shadow-md">
                            <button onClick={() => openModal('delete', std)} className="p-1.5 px-2 bg-red-600 hover:bg-red-700 text-white rounded transition-colors text-sm" title="ڈیلیٹ">🗑️</button>
                            <button onClick={() => openModal('promote', std)} className="p-1.5 px-2 bg-slate-700 hover:bg-slate-600 text-white rounded transition-colors text-sm" title="پروموٹ">⤴️</button>
                            <button onClick={() => openModal('alumni', std)} className="p-1.5 px-2 bg-amber-600 hover:bg-amber-700 text-white rounded transition-colors text-sm" title="فارغ التحصیل">🎓</button>
                            <button onClick={() => openModal('edit', std)} className="p-1.5 px-2 bg-blue-600 hover:bg-blue-700 text-white rounded transition-colors text-sm" title="ترمیم">📝</button>
                            <button onClick={() => openModal('idcard', std)} className="p-1.5 px-2 bg-emerald-600 hover:bg-emerald-700 text-white rounded transition-colors text-sm" title="آئی ڈی کارڈ">🪪</button>
                            <button onClick={() => openModal('view', std)} className="p-1.5 px-2 bg-slate-600 hover:bg-slate-500 text-white rounded transition-colors text-sm" title="پرنٹ فارم">🖨️</button>
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
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/60 backdrop-blur-sm p-4 overflow-y-auto print:p-0 print:bg-white print:items-start">
          <div className={`bg-white shadow-2xl w-full ${modalMode === 'view' ? 'max-w-4xl' : modalMode === 'idcard' ? 'max-w-sm' : 'max-w-3xl'} overflow-hidden my-8 print:shadow-none print:m-0 print:w-full rounded-2xl print:rounded-none`}>
            
            {/* --- ADMISSION FORM PRINT VIEW (EXACT PARITY) --- */}
            {modalMode === 'view' && (
              <div className="p-10 print:p-0">
                <div className="text-center print:hidden mb-4">
                  <button onClick={() => window.print()} className="bg-slate-800 text-white px-8 py-2 rounded font-bold shadow-lg text-lg">پرنٹ کریں (Print / PDF)</button>
                  <button onClick={() => setIsModalOpen(false)} className="bg-slate-100 text-slate-700 px-6 py-2 rounded font-bold border ms-2">واپس جائیں</button>
                </div>
                
                <div className="border-4 border-double border-slate-900 p-8 m-auto max-w-3xl bg-slate-50" style={{ outline: '2px solid black', outlineOffset: '4px' }}>
                  
                  {/* Header */}
                  <div className="text-center mb-6">
                    <h2 className="text-3xl font-bold mb-1">داخلہ فارم</h2>
                    <h1 className="text-4xl font-extrabold mb-3">مدرسہ اشرف المدارس</h1>
                    <p className="text-lg font-bold">منسلک جامع مسجد حنفیہ (محلہ راؤ رشید والا/بالمقابل دفتر زراعت ساہیوال روڈ <br/> فروکہ ضلع سرگودھا</p>
                  </div>

                  {/* Photo & Top Details */}
                  <div className="relative mb-8">
                    <div className="absolute top-0 right-0 w-32 h-40 border-2 border-slate-400 bg-white p-1 overflow-hidden">
                       {selectedStudent?.photo ? (
                          <img src={selectedStudent.photo} alt="Photo" className="w-full h-full object-cover" />
                        ) : (
                          <div className="w-full h-full bg-slate-100 flex items-center justify-center text-slate-400 text-sm text-center">تصویر</div>
                        )}
                    </div>
                    
                    <div className="mr-40 ml-4">
                      {/* Row 1 */}
                      <div className="flex justify-between items-end mb-4">
                        <div className="flex-1 flex items-end">
                          <span className="font-bold w-24">داخلہ نمبر:</span>
                          <span className="flex-1 border-b border-dashed border-slate-400 font-sans text-center px-2">{selectedStudent?.admission_number}</span>
                        </div>
                        <div className="flex-1 flex items-end mr-4">
                          <span className="font-bold w-24">تاریخ داخلہ:</span>
                          <span className="flex-1 border-b border-dashed border-slate-400 font-sans text-center px-2">{selectedStudent?.admission_date}</span>
                        </div>
                      </div>

                      {/* Row 2 */}
                      <div className="flex items-end mb-4">
                        <span className="font-bold w-32">طالب علم کا نام:</span>
                        <span className="flex-1 border-b border-dashed border-slate-400 text-blue-600 font-bold text-center px-2 text-xl">{selectedStudent?.name}</span>
                      </div>

                      {/* Row 3 */}
                      <div className="flex items-end mb-4">
                        <span className="font-bold w-24">والد کا نام:</span>
                        <span className="flex-1 border-b border-dashed border-slate-400 text-center px-2 text-lg">{selectedStudent?.father_name}</span>
                      </div>

                      {/* Row 4 */}
                      <div className="flex justify-between items-end mb-4">
                        <div className="flex-1 flex items-end">
                          <span className="font-bold w-24">تاریخ پیدائش:</span>
                          <span className="flex-1 border-b border-dashed border-slate-400 text-center px-2">---</span>
                        </div>
                        <div className="flex-1 flex items-end mr-4">
                          <span className="font-bold w-24">شعبہ / درجہ:</span>
                          <span className="flex-1 border-b border-dashed border-slate-400 text-center px-2">{selectedStudent?.class}</span>
                        </div>
                      </div>

                      {/* Row 5 */}
                      <div className="flex items-end mb-4">
                        <span className="font-bold w-24">موجودہ پتہ:</span>
                        <span className="flex-1 border-b border-dashed border-slate-400 text-center px-2 text-sm">{selectedStudent?.address || '---'}</span>
                      </div>
                      
                      {/* Row 6 */}
                      <div className="flex items-end mb-4">
                        <span className="font-bold w-24">مستقل پتہ:</span>
                        <span className="flex-1 border-b border-dashed border-slate-400 text-center px-2 text-sm">{selectedStudent?.address || '---'}</span>
                      </div>

                      {/* Row 7 */}
                      <div className="flex justify-between items-end mb-4">
                        <div className="flex-1 flex items-end">
                          <span className="font-bold w-24">موبائل نمبر:</span>
                          <span className="flex-1 border-b border-dashed border-slate-400 font-sans text-center px-2">{selectedStudent?.contact_number}</span>
                        </div>
                        <div className="flex-1 flex items-end mr-4">
                          <span className="font-bold w-20">ای میل:</span>
                          <span className="flex-1 border-b border-dashed border-slate-400 text-center px-2">---</span>
                        </div>
                      </div>
                    </div>
                  </div>

                  {/* Pledge 1 */}
                  <div className="mb-4">
                    <div className="bg-slate-900 text-white text-center py-1 font-bold mb-2">عہد نامہ از طالب علم</div>
                    <p className="text-center text-sm leading-relaxed px-4">
                      میں نے تمام قواعد وضوابط کا بغور مطالعہ کیا ہے اور میں یہ عہد کرتا ہوں اور اپنے اساتذہ کو یقین دلاتا ہوں کہ ان تمام قواعد وضوابط اور ان کے علاوہ بھی وقتاً فوقتاً اساتذہ کی طرف سے ملنے والی ہدایات پر عمل کروں گا اور قطعاً شکایت کا موقع نہیں دوں گا۔
                    </p>
                  </div>

                  {/* Pledge 2 */}
                  <div className="mb-8">
                    <div className="bg-slate-900 text-white text-center py-1 font-bold mb-2">عہد نامہ از سرپرست / والد</div>
                    <p className="text-center text-sm leading-relaxed px-4 mb-4">
                      میں حلفاً بیان کرتا ہوں کہ مندرجہ بالا معلومات 100٪ درست ہیں۔ میں بحیثیت سرپرست وعدہ کرتا ہوں کہ اپنے عزیز کی تمام تر تعلیمی ذمہ داری پوری کروں گا۔ چھٹیوں کے دوران اور جمعہ کے دن گھر میں تعلیم کی نگرانی کروں گا، کسی بھی غیر قانونی یا سیاسی غیر شرعی کام میں ملوث پائے جانے کی صورت میں ادارہ کی تادیبی کارروائی قبول کروں گا۔
                    </p>
                    <div className="text-center text-blue-600 font-bold mb-4">{selectedStudent?.name}</div>
                  </div>

                  {/* Signatures */}
                  <div className="flex justify-between items-end mt-12 mb-4 px-4">
                    <div className="text-center">
                      <div className="w-40 border-b border-slate-900 mb-1"></div>
                      <span className="font-bold">دستخط مہتمم مدرسہ</span>
                    </div>
                    <div className="text-center">
                      <div className="w-40 border-b border-slate-900 mb-1"></div>
                      <span className="font-bold">دستخط سرپرست</span>
                    </div>
                    <div className="text-center">
                      <div className="text-xs text-slate-500 mb-1 font-sans">{new Date().toLocaleString()}</div>
                      <div className="w-40 border-b border-slate-900 mb-1"></div>
                      <span className="font-bold">دستخط طالب علم / فارم</span>
                    </div>
                  </div>

                </div>
              </div>
            )}

            {/* --- ID CARD VIEW (LANDSCAPE) --- */}
            {modalMode === 'idcard' && (
              <div className="p-0 bg-white print:p-0">
                <div className="text-center print:hidden p-4 border-b">
                  <button onClick={() => window.print()} className="bg-emerald-600 text-white px-8 py-2 rounded-lg font-bold shadow-md hover:bg-emerald-700">پرنٹ کارڈ</button>
                  <button onClick={() => setIsModalOpen(false)} className="bg-slate-100 text-slate-700 px-8 py-2 rounded-lg font-bold border ms-4 hover:bg-slate-200">بند کریں</button>
                  <p className="text-sm text-slate-500 mt-2">پرنٹ کرنے کے لیے پیپر سائز A4 رکھیں اور Scale کو 100% پر سیٹ کریں۔</p>
                </div>
                
                <div className="p-8 flex justify-center items-center bg-slate-100 print:p-0 print:bg-white min-h-[350px]">
                  
                  {/* ID CARD CONTAINER (Using exact pixels for 3.375x2.125 inches at 96 DPI -> 324px x 204px) */}
                  <div className="relative overflow-hidden bg-white shadow-2xl print:shadow-none font-urdu" style={{ width: '324px', height: '204px', border: '1px solid #ddd' }}>
                    
                    {/* Top Header (Green) */}
                    <div className="absolute top-0 left-0 right-0 h-[40px] bg-[#2d5a3f] flex items-center justify-between px-2" dir="ltr">
                      {/* Logo Left */}
                      <div className="w-[30px] h-[30px] flex items-center justify-center bg-white rounded-full p-0.5 overflow-hidden">
                        <img src="/logo.png" alt="Logo" className="w-full h-full object-contain" />
                      </div>
                      
                      <h2 className="text-white font-extrabold flex-1 text-center text-xl mt-1 font-urdu" style={{ textShadow: '1px 1px 2px rgba(0,0,0,0.8)' }}>مدرسہ اشرف المدارس</h2>
                      
                      {/* Logo Right */}
                      <div className="w-[30px] h-[30px] flex items-center justify-center bg-white rounded-full p-0.5 overflow-hidden">
                        <img src="/logo.png" alt="Logo" className="w-full h-full object-contain" />
                      </div>
                    </div>

                    {/* Main Body */}
                    <div className="absolute top-[40px] bottom-[28px] left-0 right-0 flex p-2" dir="ltr">
                      
                      {/* Left Side: Photo & Signature */}
                      <div className="w-[85px] flex flex-col items-center justify-between h-full shrink-0 pt-1 border-r-2 border-slate-100 pr-2 mr-2">
                        <div className="w-[75px] h-[90px] border-[3px] border-[#2d5a3f] bg-slate-200 overflow-hidden flex items-center justify-center rounded-sm shadow-sm">
                          {selectedStudent?.photo ? (
                            <img src={selectedStudent.photo} alt="Photo" className="w-full h-full object-cover" />
                          ) : (
                            <span className="text-gray-400 text-[10px]">تصویر</span>
                          )}
                        </div>
                        <div className="w-full text-center mt-1">
                          <div className="border-t-2 border-black w-full mb-[2px]"></div>
                          <span className="font-bold text-black text-[11px]" dir="rtl">دستخط جاری</span>
                        </div>
                      </div>

                      {/* Right Side: Details (RTL Text) */}
                      <div className="flex-1 flex flex-col justify-start space-y-1.5 shrink-0 pt-1" dir="rtl">
                        
                        <div className="flex items-center justify-start border-b border-dashed border-gray-300 pb-0.5">
                          <span className="font-bold text-black text-[13px] w-[50px] shrink-0 text-right">نام:</span>
                          <span className="font-extrabold text-[#2d5a3f] text-[15px] mr-2 truncate leading-none">{selectedStudent?.name}</span>
                        </div>
                        
                        <div className="flex items-center justify-start border-b border-dashed border-gray-300 pb-0.5">
                          <span className="font-bold text-black text-[13px] w-[50px] shrink-0 text-right">ولدیت:</span>
                          <span className="font-extrabold text-[#2d5a3f] text-[14px] mr-2 truncate leading-none">{selectedStudent?.father_name}</span>
                        </div>
                        
                        <div className="flex items-center justify-start border-b border-dashed border-gray-300 pb-0.5">
                          <span className="font-bold text-black text-[13px] w-[50px] shrink-0 text-right leading-tight">داخلہ نمبر:</span>
                          <span className="font-extrabold text-[#2d5a3f] text-[14px] font-sans mr-2 leading-none" dir="ltr">{selectedStudent?.admission_number}</span>
                        </div>

                        {/* Dates Row - Fixed properly so it is visible */}
                        <div className="flex justify-between items-center mt-1">
                          <div className="flex flex-col">
                            <span className="text-gray-600 font-bold text-[9px] mb-0.5">تاریخ اجراء</span>
                            <span className="font-bold font-sans text-[#2d5a3f] text-[10px] leading-none" dir="ltr">
                              {`${new Date().getDate().toString().padStart(2, '0')}-${(new Date().getMonth() + 1).toString().padStart(2, '0')}-${new Date().getFullYear()}`}
                            </span>
                          </div>
                          <div className="flex flex-col text-left">
                            <span className="text-gray-600 font-bold text-[9px] mb-0.5 text-right">تاریخ انتہاء</span>
                            <span className="font-bold text-red-600 font-sans text-[10px] leading-none" dir="ltr">
                              {`${new Date().getDate().toString().padStart(2, '0')}-${(new Date().getMonth() + 1).toString().padStart(2, '0')}-${new Date().getFullYear() + 1}`}
                            </span>
                          </div>
                        </div>
                        
                      </div>

                    </div>

                    {/* Bottom Footer (Gold) */}
                    <div className="absolute bottom-0 left-0 right-0 h-[28px] bg-[#c6a218] flex items-center justify-center">
                      <span className="font-bold text-black text-[13px] mt-1" style={{ textShadow: '0px 0px 1px rgba(255,255,255,0.7)' }}>العلم نور ۔ تعلیم و تربیت کا گہوارہ</span>
                    </div>

                  </div>
                </div>
              </div>
            )}

            {/* --- PROMOTE MODAL --- */}
            {modalMode === 'promote' && (
              <div className="p-8 text-center print:hidden">
                <h3 className="text-2xl font-bold text-slate-800 mb-4">پروموٹ کریں</h3>
                <p className="text-lg text-slate-600 mb-6">طالب علم <b>{selectedStudent?.name}</b> کو نئی کلاس میں پروموٹ کریں۔</p>
                <select 
                  className="w-full px-4 py-3 rounded-xl border border-slate-300 focus:border-emerald-500 mb-6 text-lg"
                  value={promoteClass}
                  onChange={(e) => setPromoteClass(e.target.value)}
                >
                  <option value="">نئی کلاس منتخب کریں...</option>
                  <option value="حفظ">حفظ</option>
                  <option value="ناظرہ">ناظرہ</option>
                  <option value="قاعدہ">قاعدہ</option>
                  <option value="اولیٰ">اولیٰ</option>
                  <option value="اولیٰ دہم">اولیٰ دہم</option>
                </select>
                <div className="flex gap-4 justify-center">
                  <button onClick={() => setIsModalOpen(false)} className="px-6 py-3 rounded-xl bg-slate-100 text-slate-700 font-bold hover:bg-slate-200 text-lg">منسوخ کریں</button>
                  <button onClick={handlePromote} disabled={saving || !promoteClass} className="px-6 py-3 rounded-xl bg-slate-800 text-white font-bold hover:bg-slate-900 shadow-lg text-lg disabled:opacity-50">
                    {saving ? 'ہو رہا ہے...' : 'پروموٹ کریں'}
                  </button>
                </div>
              </div>
            )}

            {/* --- ALUMNI MODAL --- */}
            {modalMode === 'alumni' && (
              <div className="p-8 text-center print:hidden">
                <div className="text-5xl mb-4">🎓</div>
                <h3 className="text-2xl font-bold text-slate-800 mb-4">فارغ التحصیل</h3>
                <p className="text-lg text-slate-600 mb-6">کیا آپ واقعی <b>{selectedStudent?.name}</b> کو فارغ التحصیل (Alumni) کی لسٹ میں منتقل کرنا چاہتے ہیں؟</p>
                <div className="flex gap-4 justify-center">
                  <button onClick={() => setIsModalOpen(false)} className="px-6 py-3 rounded-xl bg-slate-100 text-slate-700 font-bold hover:bg-slate-200 text-lg">منسوخ کریں</button>
                  <button onClick={handleAlumni} disabled={saving} className="px-6 py-3 rounded-xl bg-amber-600 text-white font-bold hover:bg-amber-700 shadow-lg text-lg">
                    {saving ? 'ہو رہا ہے...' : 'ہاں، منتقل کریں'}
                  </button>
                </div>
              </div>
            )}

            {/* --- ADD / EDIT / DELETE FORMS --- */}
            {(modalMode === 'add' || modalMode === 'edit' || modalMode === 'delete') && (
              <div className="fixed inset-0 bg-slate-900/40 backdrop-blur-sm flex items-center justify-center z-50 p-4 transition-colors">
            <div className="bg-white dark:bg-slate-800 rounded-3xl shadow-2xl w-full max-w-3xl overflow-hidden animate-in fade-in zoom-in duration-300 print:hidden border border-slate-200 dark:border-slate-700 transition-colors">
              <div className="bg-slate-50 dark:bg-slate-700/50 px-8 py-5 border-b border-slate-200 dark:border-slate-700 flex justify-between items-center transition-colors">
                <h3 className="text-2xl font-bold text-slate-800 dark:text-slate-100 flex items-center gap-3">
                    {modalMode === 'add' && 'نیا داخلہ فارم (Add Student)'}
                    {modalMode === 'edit' && 'طالب علم کا ریکارڈ اپڈیٹ کریں'}
                    {modalMode === 'delete' && 'محذوف کریں (Delete Student)'}
                  </h3>
                  <button onClick={() => setIsModalOpen(false)} className="text-slate-400 hover:text-red-500 transition-colors text-3xl font-sans leading-none">&times;</button>
                </div>
                
                <div className="p-8 print:hidden">
                  {message && (
                    <div className={`mb-6 p-4 rounded-xl font-bold text-lg border ${message.type === 'success' ? 'bg-emerald-50 text-emerald-700 border-emerald-100' : 'bg-red-50 text-red-600 border-red-100'}`}>
                      {message.text}
                    </div>
                  )}

                  {modalMode === 'delete' ? (
                    <div className="text-center py-6">
                      <p className="text-2xl text-slate-800 mb-8 font-bold">کیا آپ واقعی <span className="text-red-600">"{selectedStudent?.name}"</span> کا ریکارڈ حذف کرنا چاہتے ہیں؟</p>
                      <div className="flex gap-4 justify-center">
                        <button onClick={() => setIsModalOpen(false)} className="px-8 py-3 rounded-xl bg-slate-100 text-slate-700 font-bold hover:bg-slate-200 text-xl">منسوخ کریں</button>
                        <button onClick={handleDelete} disabled={saving} className="px-8 py-3 rounded-xl bg-red-600 text-white font-bold hover:bg-red-700 shadow-lg shadow-red-200 text-xl">
                          {saving ? 'ہو رہا ہے...' : 'ہاں، ڈیلیٹ کریں'}
                        </button>
                      </div>
                    </div>
                  ) : (
                    <form onSubmit={handleSave} className="grid grid-cols-1 md:grid-cols-12 gap-6">
                      
                      <div className="md:col-span-12 flex items-center gap-6 mb-4 p-4 bg-slate-50 rounded-xl border border-slate-200">
                        <div className="w-24 h-24 rounded-full bg-white border-4 border-slate-200 shadow-sm overflow-hidden flex items-center justify-center relative group">
                          {formData.photoBase64 ? (
                            <img src={formData.photoBase64} alt="Preview" className="w-full h-full object-cover" />
                          ) : (
                            <span className="text-3xl">📷</span>
                          )}
                          <div className="absolute inset-0 bg-black/40 flex items-center justify-center opacity-0 group-hover:opacity-100 transition-opacity">
                            <span className="text-white text-xs font-bold">تبدیل کریں</span>
                          </div>
                          <input type="file" accept="image/*" className="absolute inset-0 opacity-0 cursor-pointer" onChange={handlePhotoUpload} />
                        </div>
                        <div>
                          <h4 className="font-bold text-slate-800 text-lg mb-1">طالب علم کی تصویر منتخب کریں</h4>
                          <p className="text-slate-500 text-sm">JPG یا PNG فارمیٹ میں</p>
                        </div>
                      </div>

                      <div className="md:col-span-6">
                        <label className="block text-slate-700 dark:text-slate-300 font-bold mb-2 text-lg">نام طالب علم *</label>
                        <input 
                          type="text" 
                          required 
                          className="w-full px-4 py-3 rounded-xl border border-slate-200 dark:border-slate-600 focus:ring-2 focus:ring-theme-primary focus:border-theme-primary bg-slate-50 dark:bg-slate-700 text-slate-800 dark:text-slate-100 text-lg transition-colors"
                          value={formData.name} onChange={(e) => setFormData({...formData, name: e.target.value})} />
                      </div>
                      
                      <div className="md:col-span-6">
                        <label className="block text-slate-700 dark:text-slate-300 font-bold mb-2 text-lg">ولدیت *</label>
                        <input 
                          type="text" 
                          required 
                          className="w-full px-4 py-3 rounded-xl border border-slate-200 dark:border-slate-600 focus:ring-2 focus:ring-theme-primary focus:border-theme-primary bg-slate-50 dark:bg-slate-700 text-slate-800 dark:text-slate-100 text-lg transition-colors"
                          value={formData.father_name} onChange={(e) => setFormData({...formData, father_name: e.target.value})} />
                      </div>
                      <div className="md:col-span-4">
                        <label className="block text-slate-700 font-bold mb-2">داخلہ / رول نمبر *</label>
                        <input type="text" required className="w-full px-4 py-3 rounded-xl border border-slate-300 focus:border-emerald-500 focus:ring-1 focus:ring-emerald-500 outline-none text-lg bg-white shadow-sm font-sans" dir="ltr"
                          value={formData.admission_number} onChange={(e) => setFormData({...formData, admission_number: e.target.value})} />
                      </div>
                      <div className="md:col-span-4">
                        <label className="block text-slate-700 font-bold mb-2">کلاس / درجہ *</label>
                        <select required className="w-full px-4 py-3 rounded-xl border border-slate-300 focus:border-emerald-500 focus:ring-1 focus:ring-emerald-500 outline-none text-lg bg-white shadow-sm" 
                          value={formData.class} onChange={(e) => setFormData({...formData, class: e.target.value})}>
                          <option value="">منتخب کریں...</option>
                          <option value="حفظ">حفظ</option>
                          <option value="ناظرہ">ناظرہ</option>
                          <option value="قاعدہ">قاعدہ</option>
                          <option value="اولیٰ">اولیٰ</option>
                          <option value="اولیٰ دہم">اولیٰ دہم</option>
                        </select>
                      </div>
                      <div className="md:col-span-4">
                        <label className="block text-slate-700 font-bold mb-2">تاریخِ داخلہ</label>
                        <input type="date" className="w-full px-4 py-3 rounded-xl border border-slate-300 focus:border-emerald-500 focus:ring-1 focus:ring-emerald-500 outline-none text-lg bg-white shadow-sm font-sans" 
                          value={formData.admission_date} onChange={(e) => setFormData({...formData, admission_date: e.target.value})} />
                      </div>
                      <div className="md:col-span-12">
                        <label className="block text-slate-700 font-bold mb-2">رابطہ نمبر *</label>
                        <input type="text" required className="w-full px-4 py-3 rounded-xl border border-slate-300 focus:border-emerald-500 focus:ring-1 focus:ring-emerald-500 outline-none text-lg bg-white shadow-sm font-sans" dir="ltr" placeholder="03001234567"
                          value={formData.contact_number} onChange={(e) => setFormData({...formData, contact_number: e.target.value})} />
                      </div>
                      <div className="md:col-span-12">
                        <label className="block text-slate-700 font-bold mb-2">مکمل پتہ</label>
                        <textarea rows={2} className="w-full px-4 py-3 rounded-xl border border-slate-300 focus:border-emerald-500 focus:ring-1 focus:ring-emerald-500 outline-none text-lg bg-white shadow-sm resize-none" 
                          value={formData.address} onChange={(e) => setFormData({...formData, address: e.target.value})} />
                      </div>
                      
                      <div className="md:col-span-12 flex justify-end gap-4 mt-6 border-t border-slate-100 pt-6">
                        <button type="button" onClick={() => setIsModalOpen(false)} className="px-8 py-3 rounded-xl bg-slate-100 text-slate-700 font-bold hover:bg-slate-200 text-xl">منسوخ کریں</button>
                        <button type="submit" disabled={saving} className="px-10 py-3 rounded-xl bg-emerald-600 hover:bg-emerald-700 text-white font-bold shadow-lg shadow-emerald-200 transition-all active:scale-95 text-xl">
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
        </div>
      )}
    </div>
  );
}
