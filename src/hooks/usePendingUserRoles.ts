import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { supabase } from "@/integrations/supabase/untypedClient";
import { toast } from "sonner";
import { useAuth } from "@/contexts/AuthContext";

export interface PendingUserRole {
  id: string;
  email: string;
  role: string;
  created_by: string | null;
  created_at: string;
}

export const usePendingUserRoles = () => {
  const queryClient = useQueryClient();
  const { madrasaName } = useAuth();

  const { data: pendingRoles, isLoading } = useQuery({
    queryKey: ["pending_user_roles", madrasaName],
    queryFn: async () => {
      const { data, error } = await supabase
        .from("pending_user_roles")
        .select("*")
        .order("created_at", { ascending: false });

      if (error) throw error;
      return data as PendingUserRole[];
    },
    enabled: !!madrasaName,
  });

  const createPendingRole = useMutation({
    mutationFn: async (newRole: { email: string; role: string; full_name?: string; madrasa_name?: string }) => {
      const { data: authData } = await supabase.auth.getUser();
      
      const insertData: any = {
        email: newRole.email,
        role: newRole.role,
      };

      let madrasaNameForEmail = '';
      let inviterName = '';

      // If madrasa_name is provided, use it (for join requests)
      // Otherwise, get from current user's profile (for admin invites)
      if (newRole.madrasa_name) {
        insertData.madrasa_name = newRole.madrasa_name;
        madrasaNameForEmail = newRole.madrasa_name;
      } else if (authData.user) {
        const { data: profile } = await supabase
          .from('profiles')
          .select('madrasa_name, full_name')
          .eq('id', authData.user.id)
          .single();
        
        if (profile?.madrasa_name) {
          insertData.madrasa_name = profile.madrasa_name;
          madrasaNameForEmail = profile.madrasa_name;
        }
        if (profile?.full_name) {
          inviterName = profile.full_name;
        }
      }

      const { data, error } = await supabase
        .from("pending_user_roles")
        .insert([insertData])
        .select()
        .single();

      if (error) throw error;

      // Send invitation email
      if (madrasaNameForEmail) {
        try {
          await supabase.functions.invoke('send-role-invite', {
            body: {
              email: newRole.email,
              role: newRole.role,
              madrasaName: madrasaNameForEmail,
              invitedBy: inviterName || authData.user?.email || 'Admin'
            }
          });
        } catch (emailError) {
          console.error('Failed to send invitation email:', emailError);
          // Don't throw error - the pending role was created successfully
        }
      }

      return data;
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["pending_user_roles"] });
      toast.success("دعوت نامہ کامیابی سے بھیج دیا گیا");
    },
    onError: (error: Error) => {
      toast.error(`دعوت نامہ بھیجنے میں ناکامی: ${error.message}`);
    },
  });

  const deletePendingRole = useMutation({
    mutationFn: async (id: string) => {
      const { error } = await supabase.from("pending_user_roles").delete().eq("id", id);
      if (error) throw error;
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["pending_user_roles"] });
      toast.success("Pending role removed successfully");
    },
    onError: (error: Error) => {
      toast.error(`Failed to remove pending role: ${error.message}`);
    },
  });

  return {
    pendingRoles: pendingRoles || [],
    isLoading,
    createPendingRole,
    deletePendingRole,
  };
};
