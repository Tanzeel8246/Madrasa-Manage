import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { supabase } from "@/integrations/supabase/untypedClient";
import { toast } from "sonner";
import { useAuth } from "@/contexts/AuthContext";

export interface StaffMember {
  id: string;
  name: string;
  father_name?: string;
  designation: string;
  qualification?: string;
  salary: number;
  joining_date: string;
  contact: string;
  email?: string;
  address?: string;
  cnic?: string;
  status: string;
  bank_name?: string;
  account_number?: string;
  photo_url?: string;
  created_at: string;
  updated_at: string;
}

export const useStaff = () => {
  const queryClient = useQueryClient();
  const { madrasaName } = useAuth();

  const { data: staffMembers, isLoading } = useQuery({
    queryKey: ["staff_members", madrasaName],
    queryFn: async () => {
      const { data, error } = await supabase
        .from("staff_members")
        .select("*")
        .order("name", { ascending: true });

      if (error) throw error;
      return data as StaffMember[];
    },
    enabled: !!madrasaName,
  });

  const createStaff = useMutation({
    mutationFn: async (newStaff: Omit<StaffMember, "id" | "created_at" | "updated_at">) => {
      const { data, error } = await supabase
        .from("staff_members")
        .insert([newStaff])
        .select()
        .single();

      if (error) throw error;
      return data;
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["staff_members"] });
      toast.success("اسٹاف ممبر شامل ہو گیا");
    },
    onError: (error: Error) => {
      toast.error(`ناکامی: ${error.message}`);
    },
  });

  const updateStaff = useMutation({
    mutationFn: async ({ id, ...updates }: Partial<StaffMember> & { id: string }) => {
      const { data, error } = await supabase
        .from("staff_members")
        .update(updates)
        .eq("id", id)
        .select()
        .single();

      if (error) throw error;
      return data;
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["staff_members"] });
      toast.success("اسٹاف ممبر اپ ڈیٹ ہو گیا");
    },
    onError: (error: Error) => {
      toast.error(`ناکامی: ${error.message}`);
    },
  });

  const deleteStaff = useMutation({
    mutationFn: async (id: string) => {
      const { error } = await supabase.from("staff_members").delete().eq("id", id);
      if (error) throw error;
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["staff_members"] });
      toast.success("اسٹاف ممبر ڈیلیٹ ہو گیا");
    },
    onError: (error: Error) => {
      toast.error(`ناکامی: ${error.message}`);
    },
  });

  return {
    staffMembers: staffMembers || [],
    isLoading,
    createStaff,
    updateStaff,
    deleteStaff,
  };
};
