import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { supabase } from "@/integrations/supabase/untypedClient";
import { toast } from "sonner";
import { useAuth } from "@/contexts/AuthContext";

export interface ExpenseRecord {
  id: string;
  amount: number;
  category: string;
  description: string;
  paid_to: string;
  payment_method: string;
  date: string;
  receipt_url?: string;
  voucher_number?: string;
  created_at: string;
  updated_at: string;
}

export const useExpenses = () => {
  const queryClient = useQueryClient();
  const { madrasaName } = useAuth();

  const { data: expenseRecords, isLoading } = useQuery({
    queryKey: ["expense_records", madrasaName],
    queryFn: async () => {
      const { data, error } = await supabase
        .from("expense_records")
        .select("*")
        .order("date", { ascending: false });

      if (error) throw error;
      return data as ExpenseRecord[];
    },
    enabled: !!madrasaName,
  });

  const createExpense = useMutation({
    mutationFn: async (newExpense: Omit<ExpenseRecord, "id" | "created_at" | "updated_at">) => {
      const { data: authData } = await supabase.auth.getUser();
      const { data, error } = await supabase
        .from("expense_records")
        .insert([{ ...newExpense, created_by: authData.user?.id }])
        .select()
        .single();

      if (error) throw error;
      return data;
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["expense_records"] });
      toast.success("خرچ کا ریکارڈ شامل ہو گیا");
    },
    onError: (error: Error) => {
      toast.error(`ناکامی: ${error.message}`);
    },
  });

  const updateExpense = useMutation({
    mutationFn: async ({ id, ...updates }: Partial<ExpenseRecord> & { id: string }) => {
      const { data, error } = await supabase
        .from("expense_records")
        .update(updates)
        .eq("id", id)
        .select()
        .single();

      if (error) throw error;
      return data;
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["expense_records"] });
      toast.success("خرچ کا ریکارڈ اپ ڈیٹ ہو گیا");
    },
    onError: (error: Error) => {
      toast.error(`ناکامی: ${error.message}`);
    },
  });

  const deleteExpense = useMutation({
    mutationFn: async (id: string) => {
      const { error } = await supabase.from("expense_records").delete().eq("id", id);
      if (error) throw error;
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["expense_records"] });
      toast.success("خرچ کا ریکارڈ ڈیلیٹ ہو گیا");
    },
    onError: (error: Error) => {
      toast.error(`ناکامی: ${error.message}`);
    },
  });

  return {
    expenseRecords: expenseRecords || [],
    isLoading,
    createExpense,
    updateExpense,
    deleteExpense,
  };
};
