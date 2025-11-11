import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { supabase } from "@/integrations/supabase/untypedClient";
import { toast } from "sonner";
import { useAuth } from "@/contexts/AuthContext";

export interface IncomeRecord {
  id: string;
  amount: number;
  income_type: string;
  donor_name: string;
  donor_contact?: string;
  donor_email?: string;
  payment_method: string;
  date: string;
  notes?: string;
  receipt_number?: string;
  created_at: string;
  updated_at: string;
}

export const useIncome = () => {
  const queryClient = useQueryClient();
  const { madrasaName } = useAuth();

  const { data: incomeRecords, isLoading } = useQuery({
    queryKey: ["income_records", madrasaName],
    queryFn: async () => {
      const { data, error } = await supabase
        .from("income_records")
        .select("*")
        .order("date", { ascending: false });

      if (error) throw error;
      return data as IncomeRecord[];
    },
    enabled: !!madrasaName,
  });

  const createIncome = useMutation({
    mutationFn: async (newIncome: Omit<IncomeRecord, "id" | "created_at" | "updated_at">) => {
      const { data: authData } = await supabase.auth.getUser();
      const { data, error } = await supabase
        .from("income_records")
        .insert([{ ...newIncome, created_by: authData.user?.id }])
        .select()
        .single();

      if (error) throw error;
      return data;
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["income_records"] });
      toast.success("آمد کا ریکارڈ شامل ہو گیا");
    },
    onError: (error: Error) => {
      toast.error(`ناکامی: ${error.message}`);
    },
  });

  const updateIncome = useMutation({
    mutationFn: async ({ id, ...updates }: Partial<IncomeRecord> & { id: string }) => {
      const { data, error } = await supabase
        .from("income_records")
        .update(updates)
        .eq("id", id)
        .select()
        .single();

      if (error) throw error;
      return data;
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["income_records"] });
      toast.success("آمد کا ریکارڈ اپ ڈیٹ ہو گیا");
    },
    onError: (error: Error) => {
      toast.error(`ناکامی: ${error.message}`);
    },
  });

  const deleteIncome = useMutation({
    mutationFn: async (id: string) => {
      const { error } = await supabase.from("income_records").delete().eq("id", id);
      if (error) throw error;
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["income_records"] });
      toast.success("آمد کا ریکارڈ ڈیلیٹ ہو گیا");
    },
    onError: (error: Error) => {
      toast.error(`ناکامی: ${error.message}`);
    },
  });

  return {
    incomeRecords: incomeRecords || [],
    isLoading,
    createIncome,
    updateIncome,
    deleteIncome,
  };
};
