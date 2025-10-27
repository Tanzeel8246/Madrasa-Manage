import React, { createContext, useContext, useEffect, useState } from 'react';
import { User, Session } from '@supabase/supabase-js';
import { supabase } from '@/integrations/supabase/untypedClient';
import { useNavigate } from 'react-router-dom';
import { toast } from 'sonner';

interface AuthContextType {
  user: User | null;
  session: Session | null;
  isLoading: boolean;
  signUp: (email: string, password: string, fullName: string, madrasaName: string) => Promise<{ error: Error | null }>;
  signIn: (email: string, password: string) => Promise<{ error: Error | null }>;
  signInWithGoogle: () => Promise<{ error: Error | null }>;
  signOut: () => Promise<void>;
  resetPassword: (email: string) => Promise<{ error: Error | null }>;
  isAdmin: boolean;
  madrasaName: string | null;
  logoUrl: string | null;
}

const AuthContext = createContext<AuthContextType | undefined>(undefined);

export const AuthProvider: React.FC<{ children: React.ReactNode }> = ({ children }) => {
  const [user, setUser] = useState<User | null>(null);
  const [session, setSession] = useState<Session | null>(null);
  const [isLoading, setIsLoading] = useState(true);
  const [isAdmin, setIsAdmin] = useState(false);
  const [madrasaName, setMadrasaName] = useState<string | null>(null);
  const [logoUrl, setLogoUrl] = useState<string | null>(null);
  const navigate = useNavigate();

  useEffect(() => {
    // Set up auth state listener
    const { data: { subscription } } = supabase.auth.onAuthStateChange(
      (event, session) => {
        setSession(session);
        setUser(session?.user ?? null);
        
        // Check admin role when session changes
        if (session?.user) {
          setTimeout(() => {
            checkAdminRole(session.user.id);
          }, 0);
        } else {
          setIsAdmin(false);
        }
      }
    );

    // Check for existing session
    supabase.auth.getSession().then(({ data: { session } }) => {
      setSession(session);
      setUser(session?.user ?? null);
      
      if (session?.user) {
        setTimeout(() => {
          checkAdminRole(session.user.id);
        }, 0);
      }
      
      setIsLoading(false);
    });

    return () => subscription.unsubscribe();
  }, []);

  const checkAdminRole = async (userId: string) => {
    try {
      const { data, error } = await supabase
        .from('user_roles')
        .select('role')
        .eq('user_id', userId)
        .eq('role', 'admin')
        .maybeSingle();
      
      if (!error && data) {
        setIsAdmin(true);
      } else {
        setIsAdmin(false);
      }

      // Fetch madrasa name and logo from profile
      const { data: profileData } = await supabase
        .from('profiles')
        .select('madrasa_name, logo_url')
        .eq('id', userId)
        .maybeSingle();
      
      if (profileData?.madrasa_name) {
        setMadrasaName(profileData.madrasa_name);
      }
      if (profileData?.logo_url) {
        setLogoUrl(profileData.logo_url);
      }
    } catch (error) {
      setIsAdmin(false);
    }
  };

  const signUp = async (email: string, password: string, fullName: string, madrasaName: string) => {
    try {
      const redirectUrl = `${window.location.origin}/`;
      
      const { error } = await supabase.auth.signUp({
        email,
        password,
        options: {
          emailRedirectTo: redirectUrl,
          data: {
            full_name: fullName,
            madrasa_name: madrasaName
          }
        }
      });

      if (error) throw error;

      toast.success('Account created successfully! Please check your email.');
      return { error: null };
    } catch (error: any) {
      const message = error.message || 'Failed to sign up';
      toast.error(message);
      return { error };
    }
  };

  const signIn = async (email: string, password: string) => {
    try {
      const { error } = await supabase.auth.signInWithPassword({
        email,
        password
      });

      if (error) throw error;

      toast.success('Signed in successfully!');
      navigate('/');
      return { error: null };
    } catch (error: any) {
      const message = error.message === 'Invalid login credentials'
        ? 'Invalid email or password'
        : error.message || 'Failed to sign in';
      toast.error(message);
      return { error };
    }
  };

  const signInWithGoogle = async () => {
    try {
      const { error } = await supabase.auth.signInWithOAuth({
        provider: 'google',
        options: {
          redirectTo: `${window.location.origin}/`
        }
      });

      if (error) throw error;
      return { error: null };
    } catch (error: any) {
      const message = error.message || 'Failed to sign in with Google';
      toast.error(message);
      return { error };
    }
  };

  const signOut = async () => {
    try {
      const { error } = await supabase.auth.signOut();
      if (error) throw error;
      
      setIsAdmin(false);
      toast.success('Signed out successfully');
      navigate('/auth');
    } catch (error: any) {
      toast.error('Failed to sign out');
    }
  };

  const resetPassword = async (email: string) => {
    try {
      const { error } = await supabase.auth.resetPasswordForEmail(email, {
        redirectTo: `${window.location.origin}/reset-password`,
      });

      if (error) throw error;

      toast.success('پاس ورڈ ری سیٹ لنک آپ کی ای میل پر بھیج دیا گیا ہے');
      return { error: null };
    } catch (error: any) {
      const message = error.message || 'پاس ورڈ ری سیٹ میں ناکامی';
      toast.error(message);
      return { error };
    }
  };

  return (
    <AuthContext.Provider value={{ user, session, isLoading, signUp, signIn, signInWithGoogle, signOut, resetPassword, isAdmin, madrasaName, logoUrl }}>
      {children}
    </AuthContext.Provider>
  );
};

export const useAuth = () => {
  const context = useContext(AuthContext);
  if (context === undefined) {
    throw new Error('useAuth must be used within an AuthProvider');
  }
  return context;
};
