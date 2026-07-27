'use client';
import Link from 'next/link';
import { usePathname } from 'next/navigation';
import { useState, useEffect } from 'react';

export default function Sidebar() {
  const pathname = usePathname();

  const [userRole, setUserRole] = useState<string>('admin');

  useEffect(() => {
    const userStr = localStorage.getItem('user');
    if (userStr) {
      const user = JSON.parse(userStr);
      setUserRole(user.role || 'admin');
    }
  }, []);

  const adminNavItems: any[] = [
    { name: 'ہوم', icon: '🌐', href: '#' },
    { name: 'ڈیش بورڈ', icon: '⏱️', href: '/' },
    { name: 'درخواستیں وشکایات', icon: '📝', href: '/complaints' },
    { name: 'نوٹس بورڈ (اعلانات)', icon: '📢', href: '/notices' },
    { name: 'کلاسز اور نصاب', icon: '📚', href: '/classes' },
    { name: 'داخلہ درخواستیں', icon: '🎓', href: '#' },
    { name: 'تعلیمی کارکردگی (اندراج)', icon: '📖', href: '#' },
    { name: 'تعلیمی کارکردگی (دیکھیں)', icon: '📈', href: '#' },
    { name: 'طلباء کا ریکارڈ', icon: '👨‍🎓', href: '/students' },
    { name: 'فارغ التحصیل طلباء', icon: '🏅', href: '#' },
    { name: 'اساتذہ کا ریکارڈ', icon: '👨‍🏫', href: '/teachers' },
    { name: 'اساتذہ کی یومیہ حاضری', icon: '📝', href: '/teachers_attendance' },
    { name: 'اساتذہ حاضری رپورٹ', icon: '📊', href: '/teachers_attendance_report' },
    { name: 'پیریڈ وائز حاضری', icon: '📅', href: '/attendance' },
    { name: 'حاضری کی تفصیلی رپورٹ', icon: '📋', href: '/attendance_report' },
    { name: 'امتحانات (نتیجہ)', icon: '📑', href: '#' },
    { name: 'مالیات', icon: '💰', href: '#', isDropdown: true },
    { name: 'شکایت کا اندراج', icon: '➕', href: '/add_complaint' },
    { name: 'شکایات کا ریکارڈ', icon: '⚠️', href: '/manage_complaints' },
    { name: 'یوزرز کا انتظام', icon: '👥', href: '#' },
    { name: 'سافٹ ویئر سیٹنگ', icon: '⚙️', href: '#' },
    { name: 'پاسورڈ کی تبدیلی', icon: '🔑', href: '#' },
    { name: 'لاگ آؤٹ (باہر نکلیں)', icon: '🚪', href: '#' },
  ];

  const parentNavItems = [
    { name: 'ڈیش بورڈ (ہوم)', icon: '🏠', href: '/parent_dashboard' },
    { name: 'تعلیمی رپورٹ', icon: '📊', href: '/parent_dashboard/report' },
    { name: 'فیس / آن لائن ادائیگی', icon: '💸', href: '/parent_dashboard/fee' },
    { name: 'چھٹی کی درخواست', icon: '✉️', href: '/parent_dashboard/leave' },
    { name: 'شکایت کا اندراج', icon: '⚠️', href: '/parent_dashboard/complaint' },
    { name: 'لاگ آؤٹ (باہر نکلیں)', icon: '🚪', href: '#' },
  ];

  const navItems = userRole === 'parent' ? parentNavItems : adminNavItems;

  const handleLogout = (e: React.MouseEvent, isLogoutItem: boolean) => {
    if (isLogoutItem) {
      e.preventDefault();
      localStorage.removeItem('user');
      localStorage.removeItem('token');
      window.location.href = '/login';
    }
  };

  return (
    <aside className="w-72 bg-white dark:bg-slate-900 text-slate-700 dark:text-slate-300 flex flex-col shadow-2xl h-screen overflow-y-auto print:hidden font-urdu custom-scrollbar border-l border-slate-200 dark:border-slate-800 transition-colors" dir="rtl">
      
      {/* Header Profile Area */}
      <div className="p-4 border-b border-slate-200 dark:border-slate-800 bg-slate-50 dark:bg-slate-800/50 sticky top-0 z-10 text-center transition-colors">
        <h2 className="text-xl font-extrabold text-theme-primary">مدرسہ ہب</h2>
        <p className="text-sm text-slate-500 dark:text-slate-400">{userRole === 'parent' ? 'پیرنٹس پینل' : 'مینجمنٹ سسٹم'}</p>
      </div>

      <nav className="flex-1 py-4">
        {navItems.map((item, index) => {
          const isActive = pathname === item.href;
          const isLogout = item.name.includes('لاگ آؤٹ');
          return (
            <Link 
              key={index} 
              href={item.href}
              onClick={(e) => handleLogout(e, isLogout)}
              className={`flex items-center gap-3 px-6 py-2.5 transition-all text-base border-r-4 ${
                isActive 
                  ? 'bg-theme-primary/10 border-theme-primary text-theme-primary font-bold' 
                  : 'border-transparent hover:bg-slate-100 dark:hover:bg-slate-800 text-slate-600 dark:text-slate-400 hover:text-theme-primary dark:hover:text-theme-light'
              } ${isLogout ? 'text-red-500 hover:text-red-600 dark:text-red-400 dark:hover:text-red-300 mt-4 border-t border-slate-200 dark:border-slate-800 pt-4' : ''}`}
            >
              <span className="text-xl w-8 text-center">{item.icon}</span>
              <span className="flex-1">{item.name}</span>
              {item.isDropdown && <span className="text-xs">▼</span>}
            </Link>
          );
        })}
      </nav>
      
      {/* Scrollbar CSS */}
      <style dangerouslySetInnerHTML={{__html: `
        .custom-scrollbar::-webkit-scrollbar { width: 6px; }
        .custom-scrollbar::-webkit-scrollbar-track { background: #263238; }
        .custom-scrollbar::-webkit-scrollbar-thumb { background: #546E7A; border-radius: 4px; }
        .custom-scrollbar::-webkit-scrollbar-thumb:hover { background: #78909C; }
      `}} />
    </aside>
  );
}
