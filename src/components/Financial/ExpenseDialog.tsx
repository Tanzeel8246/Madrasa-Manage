import { useState, useEffect } from "react";
import { Dialog, DialogContent, DialogHeader, DialogTitle } from "@/components/ui/dialog";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { Textarea } from "@/components/ui/textarea";
import { Calendar } from "@/components/ui/calendar";
import { Popover, PopoverContent, PopoverTrigger } from "@/components/ui/popover";
import { CalendarIcon } from "lucide-react";
import { format } from "date-fns";
import { cn } from "@/lib/utils";
import { ExpenseRecord } from "@/hooks/useExpenses";

interface ExpenseDialogProps {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  onSave: (expense: Omit<ExpenseRecord, "id" | "created_at" | "updated_at">) => void;
  expense?: ExpenseRecord;
}

export const ExpenseDialog = ({ open, onOpenChange, onSave, expense }: ExpenseDialogProps) => {
  const [formData, setFormData] = useState<Omit<ExpenseRecord, "id" | "created_at" | "updated_at">>({
    amount: 0,
    category: "other",
    description: "",
    paid_to: "",
    payment_method: "cash",
    date: new Date().toISOString().split('T')[0],
    voucher_number: "",
  });

  useEffect(() => {
    if (expense) {
      setFormData({
        amount: expense.amount,
        category: expense.category,
        description: expense.description,
        paid_to: expense.paid_to,
        payment_method: expense.payment_method,
        date: expense.date,
        voucher_number: expense.voucher_number,
      });
    }
  }, [expense]);

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    onSave(formData);
    onOpenChange(false);
  };

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="max-w-2xl max-h-[90vh] overflow-y-auto">
        <DialogHeader>
          <DialogTitle>{expense ? "خرچ میں ترمیم" : "نیا خرچ کا ریکارڈ"}</DialogTitle>
        </DialogHeader>
        <form onSubmit={handleSubmit} className="space-y-4">
          <div className="grid grid-cols-2 gap-4">
            <div className="space-y-2">
              <Label>رقم *</Label>
              <Input
                type="number"
                required
                value={formData.amount}
                onChange={(e) => setFormData({ ...formData, amount: parseFloat(e.target.value) })}
              />
            </div>

            <div className="space-y-2">
              <Label>زمرہ *</Label>
              <Select
                value={formData.category}
                onValueChange={(value) => setFormData({ ...formData, category: value })}
              >
                <SelectTrigger>
                  <SelectValue />
                </SelectTrigger>
                <SelectContent>
                  <SelectItem value="salary">تنخواہیں</SelectItem>
                  <SelectItem value="food">طلباء کا کھانا</SelectItem>
                  <SelectItem value="electricity">بجلی</SelectItem>
                  <SelectItem value="water">پانی</SelectItem>
                  <SelectItem value="gas">گیس</SelectItem>
                  <SelectItem value="construction">تعمیرات</SelectItem>
                  <SelectItem value="repair">مرمت</SelectItem>
                  <SelectItem value="stationery">اسٹیشنری</SelectItem>
                  <SelectItem value="transport">ٹرانسپورٹ</SelectItem>
                  <SelectItem value="other">دیگر</SelectItem>
                </SelectContent>
              </Select>
            </div>

            <div className="space-y-2 col-span-2">
              <Label>تفصیل *</Label>
              <Textarea
                required
                value={formData.description}
                onChange={(e) => setFormData({ ...formData, description: e.target.value })}
                rows={2}
              />
            </div>

            <div className="space-y-2">
              <Label>ادائیگی کس کو *</Label>
              <Input
                required
                value={formData.paid_to}
                onChange={(e) => setFormData({ ...formData, paid_to: e.target.value })}
              />
            </div>

            <div className="space-y-2">
              <Label>ادائیگی کا طریقہ *</Label>
              <Select
                value={formData.payment_method}
                onValueChange={(value) => setFormData({ ...formData, payment_method: value })}
              >
                <SelectTrigger>
                  <SelectValue />
                </SelectTrigger>
                <SelectContent>
                  <SelectItem value="cash">نقد</SelectItem>
                  <SelectItem value="bank_transfer">بینک ٹرانسفر</SelectItem>
                  <SelectItem value="cheque">چیک</SelectItem>
                  <SelectItem value="online">آن لائن</SelectItem>
                </SelectContent>
              </Select>
            </div>

            <div className="space-y-2">
              <Label>تاریخ *</Label>
              <Popover>
                <PopoverTrigger asChild>
                  <Button
                    variant="outline"
                    className={cn(
                      "w-full justify-start text-left font-normal",
                      !formData.date && "text-muted-foreground"
                    )}
                  >
                    <CalendarIcon className="mr-2 h-4 w-4" />
                    {formData.date ? format(new Date(formData.date), "PPP") : "تاریخ منتخب کریں"}
                  </Button>
                </PopoverTrigger>
                <PopoverContent className="w-auto p-0">
                  <Calendar
                    mode="single"
                    selected={formData.date ? new Date(formData.date) : undefined}
                    onSelect={(date) => setFormData({ ...formData, date: date?.toISOString().split('T')[0] || "" })}
                    initialFocus
                    className="pointer-events-auto"
                  />
                </PopoverContent>
              </Popover>
            </div>

            <div className="space-y-2">
              <Label>واؤچر نمبر</Label>
              <Input
                value={formData.voucher_number}
                onChange={(e) => setFormData({ ...formData, voucher_number: e.target.value })}
              />
            </div>
          </div>

          <div className="flex gap-2 justify-end">
            <Button type="button" variant="outline" onClick={() => onOpenChange(false)}>
              منسوخ
            </Button>
            <Button type="submit">محفوظ کریں</Button>
          </div>
        </form>
      </DialogContent>
    </Dialog>
  );
};
