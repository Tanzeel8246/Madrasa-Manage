'use client';
import { useState, useEffect } from 'react';
import Link from 'next/link';

export default function TeachersAttendanceReportPage() {
  const [month, setMonth] = useState((new Date().getMonth() + 1).toString());
  const [year, setYear] = useState(new Date().getFullYear().toString());
  const [reportData, setReportData] = useState<any>(null);
  const [loading, setLoading] = useState(false);

  const fetchReport = async () => {
    setLoading(true);
    try {
      const res = await fetch(`/api/reports/teachers_attendance?month=${month}&year=${year}`);
      const data = await res.json();
      if (data.success) {
        setReportData(data);
      } else {
        alert(data.message);
      }
    } catch (error) {
      console.error(error);
      alert('Error fetching report');
    }
    setLoading(false);
  };

  useEffect(() => {
    fetchReport();
  }, []);

  const handlePrint = () => {
    window.print();
  };

  const urduMonths = [
    'جنوری', 'فروری', 'مارچ', 'اپریل', 'مئی', 'جون', 
    'جولائی', 'اگست', 'ستمبر', 'اکتوبر', 'نومبر', 'دسمبر'
  ];

  return (
    <div className="p-4 sm:p-8 space-y-6 bg-slate-50 dark:bg-slate-900 min-h-screen">
      {/* Header & Filters (No Print) */}
      <div className="flex flex-col sm:flex-row justify-between items-center bg-white dark:bg-slate-800 p-4 rounded-2xl shadow-sm border border-slate-200 dark:border-slate-700 print:hidden gap-4">
        <h1 className="text-2xl font-bold text-slate-800 dark:text-white flex items-center gap-3">
          <span className="text-3xl">👨‍🏫</span> اساتذہ کی حاضری کی رپورٹ
        </h1>
        
        <div className="flex items-center gap-3">
          <Link href="/teachers_attendance" className="px-5 py-2 bg-theme-primary text-white font-bold rounded-xl shadow hover:bg-theme-secondary transition flex items-center gap-2">
            ⬅️ حاضری مارک کریں
          </Link>
          <select 
            value={month} 
            onChange={e => setMonth(e.target.value)}
            className="px-4 py-2 rounded-xl border border-slate-200 dark:border-slate-600 focus:ring-2 focus:ring-theme-primary bg-slate-50 dark:bg-slate-700 text-slate-800 dark:text-slate-100"
          >
            {urduMonths.map((m, i) => (
              <option key={i+1} value={(i+1).toString()}>{m}</option>
            ))}
          </select>
          
          <select 
            value={year} 
            onChange={e => setYear(e.target.value)}
            className="px-4 py-2 rounded-xl border border-slate-200 dark:border-slate-600 focus:ring-2 focus:ring-theme-primary bg-slate-50 dark:bg-slate-700 text-slate-800 dark:text-slate-100"
          >
            {[...Array(5)].map((_, i) => {
              const y = new Date().getFullYear() - 2 + i;
              return <option key={y} value={y.toString()}>{y}</option>;
            })}
          </select>
          
          <button 
            onClick={fetchReport}
            className="px-4 py-2 bg-slate-600 text-white font-bold rounded-xl shadow hover:bg-slate-700 transition"
          >
            دیکھیں
          </button>
          
          <button 
            onClick={handlePrint}
            className="px-4 py-2 bg-emerald-600 text-white font-bold rounded-xl shadow hover:bg-emerald-700 transition flex items-center gap-2"
          >
            🖨️ پرنٹ
          </button>
        </div>
      </div>

      {loading && (
        <div className="text-center py-20 text-slate-500 font-bold text-xl">
          ڈیٹا لوڈ ہو رہا ہے...
        </div>
      )}

      {/* Report Data */}
      {!loading && reportData && (
        <div className="space-y-10">
          <div className="bg-white dark:bg-slate-800 rounded-xl shadow-lg border border-slate-200 dark:border-slate-700 overflow-hidden print:shadow-none print:border-none print:break-inside-avoid">
            <div className="bg-gradient-to-r from-slate-700 to-slate-900 p-3 text-white text-center font-bold text-lg print:bg-none print:text-black print:border-b-2 print:border-black">
              ماہانہ حاضری رپورٹ برائے اساتذہ
            </div>
            
            <div className="overflow-x-auto p-2 print:overflow-visible">
              <table className="w-full text-center border-collapse text-xs print:text-[8px] print:w-full" style={{ direction: 'rtl' }}>
                <thead>
                  <tr className="bg-slate-100 dark:bg-slate-700 text-slate-700 dark:text-slate-200">
                    <th className="border border-slate-300 dark:border-slate-600 p-1 w-8">#</th>
                    <th className="border border-slate-300 dark:border-slate-600 p-1 w-32 whitespace-nowrap">استاد کا نام</th>
                    {reportData.dates.map((date: string) => (
                      <th key={date} className="border border-slate-300 dark:border-slate-600 p-1">
                        <span className="font-bold">{date.split('-')[2]}</span>
                      </th>
                    ))}
                    <th className="border border-slate-300 dark:border-slate-600 p-1 text-green-600">حاضر</th>
                    <th className="border border-slate-300 dark:border-slate-600 p-1 text-orange-500">تاخیر</th>
                    <th className="border border-slate-300 dark:border-slate-600 p-1 text-red-600">غیر حاضر</th>
                    <th className="border border-slate-300 dark:border-slate-600 p-1 text-yellow-600">رخصت</th>
                  </tr>
                </thead>
                <tbody>
                  {reportData.data.map((t: any, idx: number) => {
                    let totalP = 0, totalLate = 0, totalA = 0, totalL = 0;
                    
                    return (
                      <tr key={t.id} className="hover:bg-slate-50 dark:hover:bg-slate-700/50 transition border-b border-slate-200 dark:border-slate-700 text-slate-800 dark:text-slate-100">
                        <td className="border border-slate-300 dark:border-slate-600 p-1">{idx + 1}</td>
                        <td className="border border-slate-300 dark:border-slate-600 p-1 font-bold whitespace-nowrap">{t.name}</td>
                        
                        {reportData.dates.map((date: string) => {
                          const att = t.attendance[date] || {};
                          const s = att.status || '-';
                          const l = att.late || 0;
                          
                          if (s === 'P' || s === 'حاضر') { if (l > 0) totalLate++; else totalP++; }
                          if (s === 'A' || s === 'غیر حاضر') totalA++;
                          if (s === 'L' || s === 'رخصت') totalL++;

                          let colorClass = 'text-slate-400';
                          if (s === 'P' || s === 'حاضر') colorClass = l > 0 ? 'text-orange-500 font-bold' : 'text-green-600 font-bold';
                          if (s === 'A' || s === 'غیر حاضر') colorClass = 'text-red-600 font-bold';
                          if (s === 'L' || s === 'رخصت') colorClass = 'text-yellow-600 font-bold';

                          return (
                            <td key={date} className={`border border-slate-300 dark:border-slate-600 p-1 ${colorClass}`}>
                              {s === 'P' ? 'P' : s === 'A' ? 'A' : s === 'L' ? 'L' : '-'}
                            </td>
                          );
                        })}
                        <td className="border border-slate-300 dark:border-slate-600 p-1 font-bold">{totalP}</td>
                        <td className="border border-slate-300 dark:border-slate-600 p-1 font-bold text-orange-500">{totalLate}</td>
                        <td className="border border-slate-300 dark:border-slate-600 p-1 font-bold">{totalA}</td>
                        <td className="border border-slate-300 dark:border-slate-600 p-1 font-bold">{totalL}</td>
                      </tr>
                    );
                  })}
                </tbody>
              </table>
            </div>
          </div>
          
          {reportData.data.length === 0 && (
            <div className="text-center py-20 text-slate-500 font-bold text-xl">
              کوئی استاد موجود نہیں۔
            </div>
          )}
        </div>
      )}
    </div>
  );
}
