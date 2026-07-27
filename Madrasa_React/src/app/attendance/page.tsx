'use client';

import { useState, useEffect } from 'react';
import Link from 'next/link';

interface StudentAtt {
  id: number;
  name: string;
  father_name: string;
  admission_number: string;
  status: 'P' | 'A' | 'L';
}

interface TeacherAtt {
  id: number;
  name: string;
  status: 'P' | 'A' | 'L';
  late_minutes?: number;
}

export default function AttendancePage() {
  const [date, setDate] = useState(new Date().toISOString().split('T')[0]);
  const [classes, setClasses] = useState<any[]>([]);
  
  const [selectedClassId, setSelectedClassId] = useState('');
  const [selectedPeriod, setSelectedPeriod] = useState('1');
  
  const [students, setStudents] = useState<StudentAtt[]>([]);
  const [teacher, setTeacher] = useState<TeacherAtt | null>(null);
  
  const [loading, setLoading] = useState(false);
  const [saving, setSaving] = useState(false);
  const [message, setMessage] = useState<{type: 'success'|'error', text: string} | null>(null);

  useEffect(() => {
    // Fetch classes for dropdown
    fetch('/api/classes')
      .then(r => r.json())
      .then(data => {
        if (data.success) {
          setClasses(data.data);
        }
      });
  }, []);

  const loadAttendance = async () => {
    if (!selectedClassId || !selectedPeriod) return;
    setLoading(true);
    setMessage(null);
    try {
      const res = await fetch(`/api/attendance?date=${date}&class_id=${selectedClassId}&period_no=${selectedPeriod}`);
      const data = await res.json();
      if (data.success) {
        setStudents(data.data.students);
        setTeacher(data.data.teacher);
      } else {
        setMessage({ type: 'error', text: data.message });
      }
    } catch (err: any) {
      setMessage({ type: 'error', text: err.message });
    } finally {
      setLoading(false);
    }
  };

  // Load data when filters change and are fully selected
  useEffect(() => {
    if (selectedClassId && selectedPeriod && date) {
      loadAttendance();
    }
  }, [selectedClassId, selectedPeriod, date]);

  const handleStudentStatusChange = (index: number, newStatus: 'P' | 'A' | 'L') => {
    const updated = [...students];
    updated[index].status = newStatus;
    setStudents(updated);
  };

  const handleTeacherStatusChange = (newStatus: 'P' | 'A' | 'L') => {
    if (teacher) {
      setTeacher({ ...teacher, status: newStatus });
    }
  };

  const saveAttendance = async () => {
    if (!selectedClassId || !selectedPeriod) return;
    setSaving(true);
    setMessage(null);
    try {
      const payload = {
        date,
        class_id: selectedClassId,
        period_no: selectedPeriod,
        students: students,
        teacher_id: teacher ? teacher.id : null,
        teacher_status: teacher ? teacher.status : null,
        teacher_late_mins: teacher ? (teacher.late_minutes || 0) : 0
      };
      
      const res = await fetch('/api/attendance', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(payload)
      });
      const data = await res.json();
      if (data.success) {
        setMessage({ type: 'success', text: 'حاضری کامیابی سے محفوظ کر لی گئی!' });
      } else {
        setMessage({ type: 'error', text: data.message });
      }
    } catch (err: any) {
      setMessage({ type: 'error', text: err.message });
    } finally {
      setSaving(false);
    }
  };

  const getStatusColor = (status: 'P' | 'A' | 'L') => {
    switch (status) {
      case 'P': return 'bg-emerald-500 text-white';
      case 'A': return 'bg-red-500 text-white';
      case 'L': return 'bg-amber-500 text-white';
      default: return 'bg-slate-200 text-slate-700';
    }
  };

  const getUnselectedColor = (status: 'P' | 'A' | 'L') => {
    switch (status) {
      case 'P': return 'bg-emerald-100 text-emerald-700 hover:bg-emerald-200 dark:bg-emerald-900/30 dark:text-emerald-400';
      case 'A': return 'bg-red-100 text-red-700 hover:bg-red-200 dark:bg-red-900/30 dark:text-red-400';
      case 'L': return 'bg-amber-100 text-amber-700 hover:bg-amber-200 dark:bg-amber-900/30 dark:text-amber-400';
      default: return 'bg-slate-100 text-slate-700 dark:bg-slate-700 dark:text-slate-300';
    }
  };

  return (
    <div className="flex flex-col bg-slate-50 dark:bg-slate-900 font-urdu min-h-screen transition-colors" dir="rtl">
      <main className="flex-1 pb-20">
        <header className="h-20 bg-white/80 dark:bg-slate-800/80 backdrop-blur-md border-b border-slate-200 dark:border-slate-700 flex items-center px-8 sticky top-0 z-10 transition-colors">
          <Link href="/" className="text-theme-primary dark:text-theme-light hover:text-theme-hover transition-colors bg-theme-primary/10 p-2 rounded-lg ml-4">
            <span className="text-xl">🏠</span>
          </Link>
          <h2 className="text-2xl font-bold text-slate-800 dark:text-slate-100">پیریڈ وائز حاضری</h2>
        </header>

        <div className="p-8">
          {/* Filters Area */}
          <div className="bg-white dark:bg-slate-800 p-6 rounded-2xl shadow-sm border border-slate-200 dark:border-slate-700 mb-8 transition-colors">
            <h3 className="text-lg font-bold text-slate-800 dark:text-slate-100 mb-4 flex items-center gap-2">
              <span>⚙️</span> فلٹرز منتخب کریں
            </h3>
            <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
              <div>
                <label className="block text-slate-700 dark:text-slate-300 font-bold mb-2">تاریخ</label>
                <input type="date" className="w-full px-4 py-3 rounded-xl border border-slate-200 dark:border-slate-600 focus:ring-2 focus:ring-theme-primary bg-slate-50 dark:bg-slate-700 text-slate-800 dark:text-slate-100 text-lg transition-colors font-sans"
                  value={date} onChange={e => setDate(e.target.value)} />
              </div>
              <div>
                <label className="block text-slate-700 dark:text-slate-300 font-bold mb-2">کلاس / درجہ</label>
                <select className="w-full px-4 py-3 rounded-xl border border-slate-200 dark:border-slate-600 focus:ring-2 focus:ring-theme-primary bg-slate-50 dark:bg-slate-700 text-slate-800 dark:text-slate-100 text-lg transition-colors"
                  value={selectedClassId} onChange={e => setSelectedClassId(e.target.value)}>
                  <option value="">منتخب کریں...</option>
                  {classes.map(c => (
                    <option key={c.id} value={c.id}>{c.name} {c.section ? `(${c.section})` : ''}</option>
                  ))}
                </select>
              </div>
              <div>
                <label className="block text-slate-700 dark:text-slate-300 font-bold mb-2">پیریڈ</label>
                <select className="w-full px-4 py-3 rounded-xl border border-slate-200 dark:border-slate-600 focus:ring-2 focus:ring-theme-primary bg-slate-50 dark:bg-slate-700 text-slate-800 dark:text-slate-100 text-lg transition-colors"
                  value={selectedPeriod} onChange={e => setSelectedPeriod(e.target.value)}>
                  {(() => {
                    const selClass = classes.find(c => c.id.toString() === selectedClassId);
                    const type = selClass?.class_type || '';
                    if (type.includes('Hifz')) {
                      return [
                        <option key="1" value="1">صبح (فجر کے بعد)</option>,
                        <option key="2" value="2">ناشتے کے بعد</option>,
                        <option key="3" value="3">دوپہر (ظہر کے بعد)</option>,
                        <option key="4" value="4">شام (مغرب کے بعد)</option>
                      ];
                    } else if (type.includes('Nazira')) {
                      return [
                        <option key="1" value="1">صبح</option>,
                        <option key="2" value="2">شام</option>
                      ];
                    } else {
                      return [1,2,3,4,5,6,7,8].map(p => (
                        <option key={p} value={p}>پیریڈ {p}</option>
                      ));
                    }
                  })()}
                </select>
              </div>
            </div>
          </div>

          {message && (
            <div className={`mb-8 p-4 rounded-xl font-bold text-lg border shadow-sm ${message.type === 'success' ? 'bg-emerald-50 text-emerald-700 border-emerald-200' : 'bg-red-50 text-red-600 border-red-200'}`}>
              {message.text}
            </div>
          )}

          {loading && (
            <div className="text-center py-20">
              <div className="text-xl font-bold text-slate-500 dark:text-slate-400">حاضری کا ریکارڈ لوڈ ہو رہا ہے...</div>
            </div>
          )}

          {!loading && selectedClassId && selectedPeriod && (
            <div className="space-y-8 animate-in fade-in slide-in-from-bottom-4 duration-500">
              
              {/* Teacher Attendance Section */}
              <div className="bg-white dark:bg-slate-800 p-6 rounded-2xl shadow-sm border border-slate-200 dark:border-slate-700 transition-colors">
                <h3 className="text-xl font-bold text-theme-primary mb-4 border-b border-theme-primary/10 pb-2">اس پیریڈ کے متعلقہ استاد کی حاضری</h3>
                {teacher ? (
                  <div className="flex items-center justify-between p-4 bg-slate-50 dark:bg-slate-700/50 rounded-xl border border-slate-200 dark:border-slate-600">
                    <div className="flex items-center gap-4">
                      <div className="w-12 h-12 bg-white dark:bg-slate-600 rounded-full flex items-center justify-center text-2xl shadow-sm border border-slate-200 dark:border-slate-500">👨‍🏫</div>
                      <div>
                        <div className="text-lg font-bold text-slate-800 dark:text-slate-100">{teacher.name}</div>
                        <div className="text-sm text-slate-500 dark:text-slate-400">استاد کی حاضری طلباء کے ساتھ خودکار طور پر محفوظ ہو جائے گی</div>
                      </div>
                    </div>
                    <div className="flex flex-col gap-2">
                      <div className="flex gap-2">
                        <button onClick={() => handleTeacherStatusChange('P')} className={`px-6 py-2 rounded-lg font-bold transition-all ${teacher.status === 'P' ? getStatusColor('P') : getUnselectedColor('P')}`}>حاضر</button>
                        <button onClick={() => handleTeacherStatusChange('A')} className={`px-6 py-2 rounded-lg font-bold transition-all ${teacher.status === 'A' ? getStatusColor('A') : getUnselectedColor('A')}`}>غیر حاضر</button>
                        <button onClick={() => handleTeacherStatusChange('L')} className={`px-6 py-2 rounded-lg font-bold transition-all ${teacher.status === 'L' ? getStatusColor('L') : getUnselectedColor('L')}`}>رخصت</button>
                      </div>
                      {teacher.status === 'P' && (
                        <div className="flex items-center gap-2 mt-2">
                          <label className="text-sm font-bold text-slate-700 dark:text-slate-300">تاخیر (منٹ):</label>
                          <input 
                            type="number" 
                            min="0"
                            className="w-20 px-2 py-1 rounded border border-slate-300 dark:border-slate-600 bg-white dark:bg-slate-700 text-slate-800 dark:text-white"
                            value={teacher.late_minutes || 0}
                            onChange={(e) => setTeacher({...teacher, late_minutes: parseInt(e.target.value) || 0})}
                          />
                        </div>
                      )}
                    </div>
                  </div>
                ) : (
                  <div className="p-4 bg-slate-50 dark:bg-slate-700/50 text-slate-500 dark:text-slate-400 rounded-xl text-center">اس پیریڈ کے لیے کوئی استاد مقرر نہیں کیا گیا</div>
                )}
              </div>

              {/* Students Attendance Section */}
              <div className="bg-white dark:bg-slate-800 p-6 rounded-2xl shadow-sm border border-slate-200 dark:border-slate-700 transition-colors">
                <div className="flex justify-between items-center mb-4 border-b border-theme-primary/10 pb-2">
                  <h3 className="text-xl font-bold text-theme-primary">طلباء کی حاضری</h3>
                  <div className="text-slate-500 dark:text-slate-400 text-sm">کل طلباء: {students.length}</div>
                </div>

                {students.length === 0 ? (
                  <div className="text-center py-10 text-lg text-slate-500 dark:text-slate-400">اس کلاس میں کوئی طالب علم موجود نہیں</div>
                ) : (
                  <div className="space-y-3">
                    {students.map((student, index) => (
                      <div key={student.id} className="flex items-center justify-between p-3 hover:bg-slate-50 dark:hover:bg-slate-700/50 rounded-xl transition-colors border border-transparent hover:border-slate-200 dark:hover:border-slate-600 group">
                        <div className="flex items-center gap-4 w-1/2">
                          <div className="w-10 h-10 bg-slate-100 dark:bg-slate-700 rounded-full flex items-center justify-center font-bold text-slate-500 dark:text-slate-400 font-sans border border-slate-200 dark:border-slate-600 group-hover:bg-white dark:group-hover:bg-slate-800 transition-colors">
                            {index + 1}
                          </div>
                          <div>
                            <div className="text-lg font-bold text-slate-800 dark:text-slate-100 leading-none mb-1">{student.name} <span className="text-sm font-normal text-slate-500 dark:text-slate-400 ml-2">ولد {student.father_name}</span></div>
                            <div className="text-xs text-slate-500 dark:text-slate-400 font-sans mt-1">داخلہ نمبر: {student.admission_number}</div>
                          </div>
                        </div>
                        
                        <div className="flex gap-2">
                          <button onClick={() => handleStudentStatusChange(index, 'P')} className={`px-5 py-2 rounded-lg font-bold text-sm transition-all ${student.status === 'P' ? getStatusColor('P') : getUnselectedColor('P')}`}>حاضر</button>
                          <button onClick={() => handleStudentStatusChange(index, 'A')} className={`px-5 py-2 rounded-lg font-bold text-sm transition-all ${student.status === 'A' ? getStatusColor('A') : getUnselectedColor('A')}`}>غیر حاضر</button>
                          <button onClick={() => handleStudentStatusChange(index, 'L')} className={`px-5 py-2 rounded-lg font-bold text-sm transition-all ${student.status === 'L' ? getStatusColor('L') : getUnselectedColor('L')}`}>رخصت</button>
                        </div>
                      </div>
                    ))}
                  </div>
                )}
              </div>

              {/* Floating Action Bar */}
              <div className="fixed bottom-0 left-0 right-0 p-4 bg-white/90 dark:bg-slate-900/90 backdrop-blur-md border-t border-slate-200 dark:border-slate-800 flex justify-center z-20 shadow-[0_-10px_40px_-10px_rgba(0,0,0,0.1)]">
                <button 
                  onClick={saveAttendance} 
                  disabled={saving || students.length === 0} 
                  className="bg-theme-primary hover:bg-theme-hover text-white px-12 py-3 rounded-2xl font-bold text-xl shadow-xl shadow-theme-primary/30 transition-all active:scale-95 disabled:opacity-50 disabled:active:scale-100 flex items-center gap-3"
                >
                  {saving ? 'محفوظ ہو رہا ہے...' : 'حاضری محفوظ کریں (Save Attendance)'}
                </button>
              </div>

            </div>
          )}
        </div>
      </main>
    </div>
  );
}
