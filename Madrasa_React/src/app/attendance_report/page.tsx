'use client';
import { useState, useEffect } from 'react';

export default function AttendanceReportPage() {
  const [month, setMonth] = useState((new Date().getMonth() + 1).toString());
  const [year, setYear] = useState(new Date().getFullYear().toString());
  const [reportData, setReportData] = useState<any>(null);
  const [loading, setLoading] = useState(false);

  const fetchReport = async () => {
    setLoading(true);
    try {
      const res = await fetch(`/api/reports/attendance?month=${month}&year=${year}`);
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

  const renderStatusDot = (status: string, late: number) => {
    let bg = 'bg-slate-200'; // Default N/A
    if (status === 'P') bg = late > 0 ? 'bg-orange-500 border border-black' : 'bg-green-600';
    if (status === 'A') bg = 'bg-red-600';
    if (status === 'L') bg = 'bg-yellow-400';
    
    return <div className={`w-full h-full rounded-full ${bg}`}></div>;
  };

  return (
    <div className="p-4 sm:p-8 space-y-6 bg-slate-50 dark:bg-slate-900 min-h-screen">
      {/* Header & Filters (No Print) */}
      <div className="flex flex-col sm:flex-row justify-between items-center bg-white dark:bg-slate-800 p-4 rounded-2xl shadow-sm border border-slate-200 dark:border-slate-700 print:hidden gap-4">
        <h1 className="text-2xl font-bold text-slate-800 dark:text-white flex items-center gap-3">
          <span className="text-3xl">📊</span> حاضری کی تفصیلی رپورٹ
        </h1>
        
        <div className="flex items-center gap-3">
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
            className="px-4 py-2 bg-theme-primary text-white font-bold rounded-xl shadow hover:bg-theme-secondary transition"
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
          {reportData.data.map((cls: any, cIdx: number) => (
            <div key={cIdx} className="bg-white dark:bg-slate-800 rounded-xl shadow-lg border border-slate-200 dark:border-slate-700 overflow-hidden print:shadow-none print:border-none print:break-inside-avoid">
              <div className="bg-gradient-to-r from-theme-primary to-theme-secondary p-3 text-white text-center font-bold text-lg print:bg-none print:text-black print:border-b-2 print:border-black">
                کلاس: {cls.className}
              </div>
              
              <div className="overflow-x-auto p-2 print:overflow-visible">
                <table className="w-full text-center border-collapse text-xs print:text-[8px] print:w-full" style={{ direction: 'rtl' }}>
                  <thead>
                    <tr className="bg-slate-100 dark:bg-slate-700 text-slate-700 dark:text-slate-200">
                      <th className="border border-slate-300 dark:border-slate-600 p-1 w-8">#</th>
                      <th className="border border-slate-300 dark:border-slate-600 p-1 w-32 whitespace-nowrap">نام طالب علم / استاذ</th>
                      <th className="border border-slate-300 dark:border-slate-600 p-1 w-32 whitespace-nowrap">ولدیت / عہدہ</th>
                      {reportData.dates.map((date: string) => (
                        <th key={date} className="border border-slate-300 dark:border-slate-600 p-1">
                          <div className="flex flex-col items-center">
                            <span className="font-bold">{date.split('-')[2]}</span>
                          </div>
                        </th>
                      ))}
                      <th className="border border-slate-300 dark:border-slate-600 p-1 text-green-600">P</th>
                      <th className="border border-slate-300 dark:border-slate-600 p-1 text-orange-500">Late</th>
                      <th className="border border-slate-300 dark:border-slate-600 p-1 text-red-600">A</th>
                      <th className="border border-slate-300 dark:border-slate-600 p-1 text-yellow-600">L</th>
                    </tr>
                  </thead>
                  <tbody>
                    {/* Render Teachers First */}
                    {cls.teachers && cls.teachers.map((t: any, idx: number) => {
                      let totalP = 0, totalA = 0, totalL = 0, totalLate = 0;
                      return (
                        <tr key={`t-${t.id}`} className="bg-indigo-50/50 dark:bg-indigo-900/20 hover:bg-indigo-100 dark:hover:bg-indigo-900/40 transition border-b border-indigo-100 dark:border-indigo-800 text-indigo-900 dark:text-indigo-100">
                          <td className="border border-slate-300 dark:border-slate-600 p-1 font-bold text-indigo-600 dark:text-indigo-400">T-{idx + 1}</td>
                          <td className="border border-slate-300 dark:border-slate-600 p-1 font-bold whitespace-nowrap">{t.name}</td>
                          <td className="border border-slate-300 dark:border-slate-600 p-1 text-slate-500 text-xs">استاذ</td>
                          {reportData.dates.map((date: string) => (
                            <td key={date} className="border border-slate-300 dark:border-slate-600 p-1">
                              <div className={`grid gap-[1px] w-4 h-4 mx-auto ${cls.periods.length <= 4 ? 'grid-cols-2' : 'grid-cols-4'}`}>
                                {cls.periods.map((p: number) => {
                                  const att = t.attendance[date]?.[p];
                                  if (att) {
                                    if (att.status === 'P' || att.status === 'حاضر') {
                                      if (att.late > 0) totalLate++; else totalP++;
                                    }
                                    if (att.status === 'A' || att.status === 'غیر حاضر') totalA++;
                                    if (att.status === 'L' || att.status === 'رخصت') totalL++;
                                    return (
                                      <div key={p} className="w-full h-full rounded-full" title={`Period ${p}`}>
                                        {renderStatusDot(att.status, att.late)}
                                      </div>
                                    );
                                  }
                                  return <div key={p} className="w-full h-full rounded-full">{renderStatusDot('', 0)}</div>;
                                })}
                              </div>
                            </td>
                          ))}
                          <td className="border border-slate-300 dark:border-slate-600 p-1 font-bold text-green-700">{totalP}</td>
                          <td className="border border-slate-300 dark:border-slate-600 p-1 font-bold text-orange-600">{totalLate}</td>
                          <td className="border border-slate-300 dark:border-slate-600 p-1 font-bold text-red-700">{totalA}</td>
                          <td className="border border-slate-300 dark:border-slate-600 p-1 font-bold text-yellow-700">{totalL}</td>
                        </tr>
                      );
                    })}

                    {/* Render Students */}
                    {cls.students.map((std: any, sIdx: number) => {
                      let totalP = 0, totalLate = 0, totalA = 0, totalL = 0;
                      
                      return (
                        <tr key={std.id} className="hover:bg-slate-50 dark:hover:bg-slate-700/50 transition border-b border-slate-200 dark:border-slate-700 text-slate-800 dark:text-slate-100">
                          <td className="border border-slate-300 dark:border-slate-600 p-1">{sIdx + 1}</td>
                          <td className="border border-slate-300 dark:border-slate-600 p-1 font-bold whitespace-nowrap">{std.name}</td>
                          <td className="border border-slate-300 dark:border-slate-600 p-1 text-slate-500 dark:text-slate-400 whitespace-nowrap">{std.father_name}</td>
                          
                          {reportData.dates.map((date: string) => {
                            const attObj = std.attendance[date] || {};
                            // Count statuses for this date
                            cls.periods.forEach((p: number) => {
                              const s = attObj[p]?.status;
                              const l = attObj[p]?.late;
                              if (s === 'P') { if (l > 0) totalLate++; else totalP++; }
                              if (s === 'A') totalA++;
                              if (s === 'L') totalL++;
                            });

                            return (
                              <td key={date} className="border border-slate-300 dark:border-slate-600 p-[2px]">
                                <div className={`grid gap-[1px] w-4 h-4 mx-auto ${cls.periods.length <= 4 ? 'grid-cols-2' : 'grid-cols-4'}`}>
                                  {cls.periods.map((p: number) => {
                                     const att = attObj[p];
                                     return (
                                       <div key={p} title={`Period ${p}`}>
                                         {att ? renderStatusDot(att.status, att.late) : renderStatusDot('', 0)}
                                       </div>
                                     );
                                  })}
                                </div>
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
          ))}
          
          {reportData.data.length === 0 && (
            <div className="text-center py-20 text-slate-500 font-bold text-xl">
              اس مہینے کا کوئی ریکارڈ نہیں ملا۔
            </div>
          )}
        </div>
      )}
    </div>
  );
}
