'use client';
import { useEffect, useState } from 'react';
import Link from 'next/link';

export default function ParentDashboard() {
  const [user, setUser] = useState<any>(null);

  useEffect(() => {
    const userStr = localStorage.getItem('user');
    if (userStr) {
      setUser(JSON.parse(userStr));
    }
  }, []);

  if (!user) return null;

  return (
    <div className="p-6 md:p-10 space-y-8 animate-fade-in font-urdu" dir="rtl">
      
      {/* Header */}
      <div className="bg-gradient-to-l from-indigo-600 to-blue-500 rounded-3xl p-8 text-white shadow-xl flex justify-between items-center relative overflow-hidden">
        <div className="relative z-10">
          <h1 className="text-4xl font-extrabold mb-2">خوش آمدید، {user.name} 🎓</h1>
          <p className="text-blue-100 text-lg opacity-90">آپ کا رول نمبر: <span className="font-bold">{user.adm_no}</span></p>
        </div>
        <div className="text-8xl opacity-10 absolute left-8 top-1/2 -translate-y-1/2">👨‍🎓</div>
      </div>

      {/* Quick Actions (Cards) */}
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6">
        
        <Link href="/parent_dashboard/report" className="block transform hover:-translate-y-2 transition-all duration-300">
          <div className="bg-gradient-to-br from-green-500 to-emerald-600 rounded-3xl p-6 text-white shadow-lg h-full relative overflow-hidden group">
            <div className="text-5xl mb-4 group-hover:scale-110 transition-transform">📊</div>
            <h3 className="text-2xl font-bold mb-1">تعلیمی رپورٹ</h3>
            <p className="text-green-100 text-sm">بچے کی کارکردگی اور حاضری</p>
            <div className="absolute -bottom-6 -left-6 w-32 h-32 bg-white opacity-10 rounded-full group-hover:scale-150 transition-transform"></div>
          </div>
        </Link>

        <Link href="/parent_dashboard/fee" className="block transform hover:-translate-y-2 transition-all duration-300">
          <div className="bg-gradient-to-br from-blue-500 to-indigo-600 rounded-3xl p-6 text-white shadow-lg h-full relative overflow-hidden group">
            <div className="text-5xl mb-4 group-hover:scale-110 transition-transform">💸</div>
            <h3 className="text-2xl font-bold mb-1">فیس / ادائیگی</h3>
            <p className="text-blue-100 text-sm">آن لائن ادائیگی اور ریکارڈ</p>
            <div className="absolute -bottom-6 -left-6 w-32 h-32 bg-white opacity-10 rounded-full group-hover:scale-150 transition-transform"></div>
          </div>
        </Link>

        <Link href="/parent_dashboard/leave" className="block transform hover:-translate-y-2 transition-all duration-300">
          <div className="bg-gradient-to-br from-yellow-500 to-orange-500 rounded-3xl p-6 text-white shadow-lg h-full relative overflow-hidden group">
            <div className="text-5xl mb-4 group-hover:scale-110 transition-transform">✉️</div>
            <h3 className="text-2xl font-bold mb-1">چھٹی کی درخواست</h3>
            <p className="text-yellow-100 text-sm">بیماری یا ضروری کام کے لیے</p>
            <div className="absolute -bottom-6 -left-6 w-32 h-32 bg-white opacity-10 rounded-full group-hover:scale-150 transition-transform"></div>
          </div>
        </Link>

        <Link href="/parent_dashboard/complaint" className="block transform hover:-translate-y-2 transition-all duration-300">
          <div className="bg-gradient-to-br from-red-500 to-rose-600 rounded-3xl p-6 text-white shadow-lg h-full relative overflow-hidden group">
            <div className="text-5xl mb-4 group-hover:scale-110 transition-transform">⚠️</div>
            <h3 className="text-2xl font-bold mb-1">شکایت درج کریں</h3>
            <p className="text-red-100 text-sm">کسی بھی مسئلے کی اطلاع دیں</p>
            <div className="absolute -bottom-6 -left-6 w-32 h-32 bg-white opacity-10 rounded-full group-hover:scale-150 transition-transform"></div>
          </div>
        </Link>

      </div>

    </div>
  );
}
