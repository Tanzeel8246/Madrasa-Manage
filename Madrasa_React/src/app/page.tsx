'use client';

import { useEffect, useState } from 'react';
import { useRouter } from 'next/navigation';

import { useTheme } from '@/context/ThemeContext';

export default function DashboardPage() {
  const [user, setUser] = useState<any>(null);
  const [notices, setNotices] = useState<any[]>([]);
  const [stats, setStats] = useState({
    totalStudents: 0,
    totalTeachers: 0,
    attendancePercent: '0%',
    monthlyIncome: '0',
    recentActivities: [] as any[]
  });
  const [loadingStats, setLoadingStats] = useState(true);

  const router = useRouter();
  const { theme, setTheme, mode, toggleMode } = useTheme();

  useEffect(() => {
    const storedUser = localStorage.getItem('user');
    if (!storedUser) {
      router.push('/login');
    } else {
      setUser(JSON.parse(storedUser));
    }

    const fetchDashboardData = async () => {
      try {
        const [noticesRes, statsRes] = await Promise.all([
          fetch('/api/notices'),
          fetch('/api/dashboard')
        ]);
        
        const noticesData = await noticesRes.json();
        if (noticesData.success) {
          setNotices(noticesData.data.slice(0, 5));
        }

        const statsData = await statsRes.json();
        if (statsData.success) {
          setStats(statsData.data);
        }
      } catch (e) {
        console.error('Failed to fetch dashboard data:', e);
      } finally {
        setLoadingStats(false);
      }
    };
    
    fetchDashboardData();
  }, [router]);

  if (!user) return null;

  const handleLogout = () => {
    localStorage.removeItem('user');
    localStorage.removeItem('token');
    router.push('/login');
  };

  const themes: Array<'indigo' | 'emerald' | 'amber' | 'rose' | 'purple'> = ['indigo', 'emerald', 'amber', 'rose', 'purple'];
  const themeColors: Record<string, string> = {
    indigo: 'bg-indigo-600',
    emerald: 'bg-emerald-600',
    amber: 'bg-amber-600',
    rose: 'bg-rose-600',
    purple: 'bg-purple-600',
  };

  return (
    <div className="flex-1 flex flex-col font-urdu" dir="rtl">
      {/* Top Header */}
      <header className="h-20 bg-white dark:bg-slate-800 border-b border-slate-200 dark:border-slate-700 flex items-center justify-between px-8 shadow-sm transition-colors">
        <div>
          <h2 className="text-2xl font-bold text-slate-800 dark:text-slate-100">خوش آمدید، {user.name} 👋</h2>
          <p className="text-slate-500 dark:text-slate-400 mt-1">آج کا دن کیسا گزر رہا ہے؟</p>
        </div>
        
        <div className="flex items-center gap-4">
          <button 
            onClick={toggleMode}
            className="w-10 h-10 flex items-center justify-center rounded-full bg-slate-100 dark:bg-slate-700 text-slate-600 dark:text-slate-300 hover:bg-slate-200 dark:hover:bg-slate-600 transition-colors"
            title={mode === 'dark' ? 'لائٹ موڈ' : 'ڈارک موڈ'}
          >
            <span className="text-xl">{mode === 'dark' ? '☀️' : '🌙'}</span>
          </button>
          
          <div className="flex items-center gap-2 bg-slate-100 dark:bg-slate-700 p-1.5 rounded-full px-4 ml-2 transition-colors">
            <span className="text-sm font-bold text-slate-600 dark:text-slate-300 ml-2">تھیم:</span>
            {themes.map(t => (
              <button
                key={t}
                onClick={() => setTheme(t)}
                className={`w-6 h-6 rounded-full border-2 transition-transform ${themeColors[t]} ${theme === t ? 'scale-125 border-white shadow-md' : 'border-transparent opacity-70 hover:opacity-100'}`}
                title={t}
              />
            ))}
          </div>

          <button className="relative p-2 text-slate-400 dark:text-slate-300 hover:text-theme-primary hover:bg-theme-primary/10 rounded-full transition-colors">
            <span className="text-2xl">🔔</span>
            <span className="absolute top-1 right-1 w-3 h-3 bg-red-500 rounded-full border-2 border-white"></span>
          </button>
          
          <button 
            onClick={handleLogout}
            className="flex items-center gap-2 bg-red-50 dark:bg-red-900/30 hover:bg-red-100 dark:hover:bg-red-900/50 text-red-600 dark:text-red-400 px-4 py-2 rounded-xl font-bold transition-colors"
          >
            لاگ آؤٹ <span className="text-xl">🚪</span>
          </button>
        </div>
      </header>

      {/* Main Content */}
      <main className="flex-1 overflow-y-auto pb-10">
        <header className="h-20 bg-white/80 dark:bg-slate-800/80 backdrop-blur-md border-b border-slate-200 dark:border-slate-700 flex items-center justify-between px-8 sticky top-0 z-10 transition-colors">
          <h2 className="text-2xl font-bold text-slate-800 dark:text-white">ڈیش بورڈ کا جائزہ</h2>
          <div className="flex items-center gap-4">
            <span className="px-4 py-1.5 bg-emerald-100 dark:bg-emerald-900/30 text-emerald-700 dark:text-emerald-400 text-sm font-bold rounded-full border border-emerald-200 dark:border-emerald-800">
              فعال مدرسہ: {user.madrasa_name || 'سپر ایڈمن (مرکزی پینل)'}
            </span>
          </div>
        </header>
        
        <div className="p-8">
          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6 mb-8">
            <StatCard title="کل طلباء" value={loadingStats ? '...' : stats.totalStudents.toLocaleString()} icon="👥" color="from-blue-500 to-cyan-400" />
            <StatCard title="کل اساتذہ" value={loadingStats ? '...' : stats.totalTeachers.toLocaleString()} icon="👨‍🏫" color="from-purple-500 to-pink-400" />
            <StatCard title="آج کی حاضری" value={loadingStats ? '...' : stats.attendancePercent} icon="✅" color="from-emerald-500 to-teal-400" />
            <StatCard title="آمدن (اس مہینے)" value={loadingStats ? '...' : stats.monthlyIncome} icon="💰" color="from-orange-500 to-amber-400" />
          </div>

          <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
            {/* Recent Activity */}
            <div className="bg-white dark:bg-slate-800 p-6 rounded-2xl shadow-sm border border-slate-100 dark:border-slate-700 relative overflow-hidden">
              <h3 className="text-xl font-bold text-slate-800 dark:text-white mb-6">حالیہ سرگرمیاں (Recent Activity)</h3>
              <div className="space-y-4">
                {loadingStats ? (
                  <p className="text-slate-500 text-center py-4">لوڈ ہو رہا ہے...</p>
                ) : stats.recentActivities.length === 0 ? (
                  <p className="text-slate-500 text-center py-4">کوئی حالیہ سرگرمی نہیں ہے</p>
                ) : (
                  stats.recentActivities.map((activity: any, i: number) => (
                    <div key={i} className="flex items-center gap-4 p-4 rounded-xl hover:bg-slate-50 dark:hover:bg-slate-700/50 transition-colors border border-transparent hover:border-slate-100 dark:hover:border-slate-600 cursor-pointer">
                      <div className="w-12 h-12 rounded-full bg-indigo-50 dark:bg-indigo-900/30 flex items-center justify-center text-indigo-600 dark:text-indigo-400 text-xl border border-indigo-100 dark:border-indigo-800/50">
                        ⚡
                      </div>
                      <div>
                        <p className="text-lg font-bold text-slate-800 dark:text-slate-200">{activity.title}</p>
                        <p className="text-sm text-slate-500 dark:text-slate-400">{activity.time} بذریعہ {activity.user}</p>
                      </div>
                    </div>
                  ))
                )}
              </div>
            </div>

            {/* Notice Board */}
            <div className="bg-white dark:bg-slate-800 p-6 rounded-2xl shadow-sm border border-slate-100 dark:border-slate-700 relative overflow-hidden border-t-4 border-t-red-500">
              <h3 className="text-xl font-bold text-slate-800 dark:text-white mb-6 flex items-center gap-2">
                <span className="text-red-500">📢</span> نوٹس بورڈ (اعلانات)
              </h3>
              <div className="space-y-4">
                {notices.length === 0 ? (
                  <p className="text-slate-500 dark:text-slate-400 text-center py-4">فی الحال کوئی اعلان موجود نہیں ہے</p>
                ) : (
                  notices.map((notice: any) => (
                    <div key={notice.id} className="p-4 rounded-xl bg-red-50 dark:bg-red-900/10 border border-red-100 dark:border-red-900/30">
                      <div className="flex justify-between items-start mb-2">
                        <strong className="text-lg text-red-600 dark:text-red-400 font-bold">{notice.title}</strong>
                        <span className="text-xs font-bold text-red-500 dark:text-red-400 bg-white dark:bg-slate-800 px-2 py-1 rounded-md border border-red-100 dark:border-red-800">
                          {new Date(notice.date).toLocaleDateString('en-GB', { day: '2-digit', month: 'short' })}
                        </span>
                      </div>
                      <p className="text-slate-700 dark:text-slate-300 text-sm whitespace-pre-wrap">{notice.message}</p>
                    </div>
                  ))
                )}
              </div>
            </div>
          </div>
        </div>
      </main>
    </div>
  );
}

function StatCard({ title, value, icon, color }: { title: string, value: string | number, icon: string, color: string }) {
  return (
    <div className="bg-white dark:bg-slate-800 p-6 rounded-2xl shadow-sm border border-slate-100 dark:border-slate-700 relative overflow-hidden group hover:shadow-md transition-all duration-300 transform hover:-translate-y-1">
      <div className={`absolute top-0 left-0 w-24 h-24 bg-gradient-to-br ${color} opacity-10 dark:opacity-20 rounded-br-full transform group-hover:scale-125 transition-transform duration-500`}></div>
      <div className="flex justify-between items-start relative z-10">
        <div>
          <p className="text-base font-bold text-slate-500 dark:text-slate-400 mb-2">{title}</p>
          <h3 className="text-3xl font-extrabold text-slate-800 dark:text-white leading-tight">{value}</h3>
        </div>
        <div className={`w-14 h-14 rounded-2xl bg-gradient-to-br ${color} text-white flex items-center justify-center text-3xl shadow-sm transform group-hover:rotate-6 transition-transform duration-300`}>
          {icon}
        </div>
      </div>
    </div>
  );
}
