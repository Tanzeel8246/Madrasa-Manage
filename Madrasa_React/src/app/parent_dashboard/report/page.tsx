'use client';
import { useState, useEffect } from 'react';

const formatDate = (dateString: string) => {
  const d = new Date(dateString);
  return d.toLocaleDateString('en-GB', { day: '2-digit', month: 'short', year: 'numeric' });
};

export default function ParentReportPage() {
  const [user, setUser] = useState<any>(null);
  const [data, setData] = useState<any>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const userStr = localStorage.getItem('user');
    if (userStr) {
      const parsed = JSON.parse(userStr);
      setUser(parsed);
      fetchReport(parsed.id);
    }
  }, []);

  const fetchReport = async (studentId: number) => {
    try {
      const res = await fetch(`/api/parent/report?student_id=${studentId}`);
      const json = await res.json();
      if (json.success) setData(json.data);
    } catch (e) {
      console.error(e);
    } finally {
      setLoading(false);
    }
  };

  if (loading) return <div className="p-10 text-center animate-fade-in text-slate-500">لوڈ ہو رہا ہے...</div>;
  if (!data) return <div className="p-10 text-center text-red-500 animate-fade-in">کوئی ڈیٹا نہیں ملا</div>;

  return (
    <div className="p-4 md:p-8 space-y-6 animate-fade-in font-urdu" dir="rtl">
      
      <div className="flex flex-col md:flex-row gap-6 items-start md:items-center justify-between bg-white dark:bg-slate-800 p-6 rounded-2xl shadow-sm border border-slate-100 dark:border-slate-700">
        <div>
          <h1 className="text-3xl font-bold text-slate-800 dark:text-white flex items-center gap-3">
            <span className="text-blue-500">📊</span> تعلیمی رپورٹ
          </h1>
          <p className="text-slate-500 dark:text-slate-400 mt-2">
            اپنے بچے کی کارکردگی اور حاضری کا جائزہ لیں
          </p>
        </div>
        
        {data.student && (
          <div className="bg-slate-50 dark:bg-slate-900 p-4 rounded-xl border border-slate-200 dark:border-slate-700 min-w-[250px]">
            <p className="text-sm text-slate-500 mb-1">طالب علم کا نام</p>
            <p className="font-bold text-lg text-slate-800 dark:text-slate-200">{data.student.name}</p>
            <p className="text-sm text-slate-500 mt-2">کلاس: <span className="font-bold text-slate-700 dark:text-slate-300">{data.student.class}</span></p>
          </div>
        )}
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        
        {/* Attendance Section */}
        <div className="bg-white dark:bg-slate-800 rounded-2xl shadow-sm border border-slate-100 dark:border-slate-700 overflow-hidden">
          <div className="p-4 bg-gradient-to-r from-indigo-500 to-blue-600 text-white">
            <h2 className="font-bold text-lg flex items-center gap-2">
              <span>📅</span> حاضری کا ریکارڈ (پچھلے 30 دن)
            </h2>
          </div>
          <div className="p-4">
            {data.attendance.length === 0 ? (
              <p className="text-center text-slate-500 py-8">حاضری کا کوئی ریکارڈ موجود نہیں</p>
            ) : (
              <div className="space-y-3">
                {data.attendance.map((att: any) => (
                  <div key={att.id} className="flex justify-between items-center p-3 bg-slate-50 dark:bg-slate-900/50 rounded-xl border border-slate-100 dark:border-slate-700">
                    <div>
                      <span className="font-bold text-slate-700 dark:text-slate-300">{formatDate(att.date)}</span>
                      {att.status === 'Absent' && att.remarks && (
                        <p className="text-xs text-red-500 mt-1">{att.remarks}</p>
                      )}
                    </div>
                    <div>
                      {att.status === 'Present' && <span className="bg-green-100 text-green-700 px-4 py-1 rounded-full text-sm font-bold">حاضر</span>}
                      {att.status === 'Absent' && <span className="bg-red-100 text-red-700 px-4 py-1 rounded-full text-sm font-bold">غیر حاضر</span>}
                      {att.status === 'Leave' && <span className="bg-yellow-100 text-yellow-700 px-4 py-1 rounded-full text-sm font-bold">رخصت</span>}
                      {att.status === 'Late' && <span className="bg-orange-100 text-orange-700 px-4 py-1 rounded-full text-sm font-bold">تاخیر</span>}
                    </div>
                  </div>
                ))}
              </div>
            )}
          </div>
        </div>

        {/* Academics Section */}
        <div className="bg-white dark:bg-slate-800 rounded-2xl shadow-sm border border-slate-100 dark:border-slate-700 overflow-hidden opacity-75">
          <div className="p-4 bg-gradient-to-r from-emerald-500 to-teal-600 text-white flex justify-between items-center">
            <h2 className="font-bold text-lg flex items-center gap-2">
              <span>📖</span> تعلیمی کارکردگی
            </h2>
            <span className="text-xs bg-black/20 px-2 py-1 rounded">جلد آ رہا ہے</span>
          </div>
          <div className="p-10 text-center">
            <p className="text-slate-500 mb-2">یہ سیکشن اگلے مرحلے (Phase 3) میں فعال کیا جائے گا۔</p>
            <p className="text-sm text-slate-400">اس میں روزانہ کا سبق، منزل، اور ٹیسٹ کے نتائج شامل ہوں گے۔</p>
          </div>
        </div>

      </div>

    </div>
  );
}
