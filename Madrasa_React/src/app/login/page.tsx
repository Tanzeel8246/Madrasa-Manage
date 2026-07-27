'use client';

import { useState } from 'react';
import { useRouter } from 'next/navigation';

export default function LoginPage() {
  const [username, setUsername] = useState('');
  const [password, setPassword] = useState('');
  const [madrasaId, setMadrasaId] = useState('');
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(false);
  const router = useRouter();

  const handleLogin = async (e: React.FormEvent) => {
    e.preventDefault();
    setError('');
    setLoading(true);

    try {
      const res = await fetch('/api/auth/login', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ username, password, madrasaId }),
      });

      const data = await res.json();

      if (data.success) {
        // Store user in local storage for now (should use HTTP only cookies for real auth)
        localStorage.setItem('user', JSON.stringify(data.user));
        localStorage.setItem('token', data.token);
        
        if (data.user.role === 'parent') {
          router.push('/parent_dashboard');
        } else {
          router.push('/');
        }
      } else {
        setError(data.message || 'لاگ ان ناکام ہو گیا');
      }
    } catch (err) {
      setError('کوئی مسئلہ درپیش ہے۔ براہ کرم دوبارہ کوشش کریں۔');
    } finally {
      setLoading(false);
    }
  };

  return (
    <div suppressHydrationWarning className="min-h-screen flex items-center justify-center bg-gradient-to-br from-indigo-100 via-purple-50 to-teal-50 font-urdu" dir="rtl">
      <div suppressHydrationWarning className="w-full max-w-md p-10 space-y-8 bg-white/80 backdrop-blur-2xl rounded-3xl shadow-[0_8px_30px_rgb(0,0,0,0.12)] border border-white/50">
        <div suppressHydrationWarning className="text-center">
          <h1 className="text-5xl font-extrabold tracking-tight text-slate-800 mb-3 bg-clip-text text-transparent bg-gradient-to-r from-indigo-600 to-purple-600">
            مدرسہ ہب
          </h1>
          <p className="text-slate-500 font-bold text-lg">اپنے ملٹی ٹیننٹ اکاؤنٹ میں سائن ان کریں</p>
        </div>

        {error && (
          <div className="bg-red-50 text-red-600 p-4 rounded-xl text-base font-bold border border-red-100 text-center">
            {error}
          </div>
        )}

        <form onSubmit={handleLogin} className="space-y-6 mt-8">
          <div>
            <label className="block text-base font-bold text-slate-700 mb-2">مدرسہ آئی ڈی (ٹیننٹ)</label>
            <input
              type="text"
              value={madrasaId}
              onChange={(e) => setMadrasaId(e.target.value)}
              className="w-full px-5 py-4 rounded-xl border-2 border-slate-200 focus:outline-none focus:ring-0 focus:border-indigo-500 transition-all bg-white/50 text-lg font-sans"
              placeholder="مثال: madrasa_1 (فی الحال چھوڑ سکتے ہیں)"
              dir="ltr"
            />
          </div>

          <div>
            <label className="block text-base font-bold text-slate-700 mb-2">یوزر نیم (Username)</label>
            <input
              type="text"
              value={username}
              onChange={(e) => setUsername(e.target.value)}
              required
              className="w-full px-5 py-4 rounded-xl border-2 border-slate-200 focus:outline-none focus:ring-0 focus:border-indigo-500 transition-all bg-white/50 text-lg font-sans"
              placeholder="اپنا یوزر نیم درج کریں"
              dir="ltr"
            />
          </div>

          <div>
            <label className="block text-base font-bold text-slate-700 mb-2">پاسورڈ (Password)</label>
            <input
              type="password"
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              required
              className="w-full px-5 py-4 rounded-xl border-2 border-slate-200 focus:outline-none focus:ring-0 focus:border-indigo-500 transition-all bg-white/50 text-lg font-sans"
              placeholder="••••••••"
              dir="ltr"
            />
          </div>

          <button
            type="submit"
            disabled={loading}
            className="w-full py-4 px-4 mt-2 bg-gradient-to-r from-indigo-600 to-purple-600 hover:from-indigo-700 hover:to-purple-700 text-white font-bold text-xl rounded-xl shadow-lg shadow-indigo-200 transform transition-all active:scale-95 disabled:opacity-70 disabled:cursor-not-allowed"
          >
            {loading ? 'سائن ان ہو رہا ہے...' : 'سائن ان کریں'}
          </button>
        </form>
      </div>
    </div>
  );
}
