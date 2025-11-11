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
import { IncomeRecord } from "@/hooks/useIncome";

interface IncomeDialogProps {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  onSave: (income: Omit<IncomeRecord, "id" | "created_at" | "updated_at">) => void;
  income?: IncomeRecord;
}

export const IncomeDialog = ({ open, onOpenChange, onSave, income }: IncomeDialogProps) => {
  const [formData, setFormData] = useState<Omit<IncomeRecord, "id" | "created_at" | "updated_at">>({
    amount: 0,
    income_type: "donation",
    donor_name: "",
    donor_contact: "",
    donor_email: "",
    payment_method: "cash",
    date: new Date().toISOString().split('T')[0],
    notes: "",
    receipt_number: "",
  });

  useEffect(() => {
    if (income) {
      setFormData({
        amount: income.amount,
        income_type: income.income_type,
        donor_name: income.donor_name,
        donor_contact: income.donor_contact,
        donor_email: income.donor_email,
        payment_method: income.payment_method,
        date: income.date,
        notes: income.notes,
        receipt_number: income.receipt_number,
      });
    }
  }, [income]);

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    onSave(formData);
    onOpenChange(false);
  };

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="max-w-2xl max-h-[90vh] overflow-y-auto">
        <DialogHeader>
          <DialogTitle>{income ? "آمد میں ترمیم" : "نیا آمد کا ریکارڈ"}</DialogTitle>
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
              <Label>قسم *</Label>
              <Select
                value={formData.income_type}
                onValueChange={(value) => setFormData({ ...formData, income_type: value })}
              >
                <SelectTrigger>
                  <SelectValue />
                </SelectTrigger>
                <SelectContent>
                  <SelectItem value="zakat">زکوٰۃ</SelectItem>
                  <SelectItem value="sadaqat">صدقات</SelectItem>
                  <SelectItem value="fitrana">فطرانہ</SelectItem>
                  <SelectItem value="donation">عطیات</SelectItem>
                  <SelectItem value="monthly_donation">ماہانہ عطیہ</SelectItem>
                  <SelectItem value="yearly_donation">سالانہ عطیہ</SelectItem>
                  <SelectItem value="onetime_donation">ایک وقتی عطیہ</SelectItem>
                </SelectContent>
              </Select>
            </div>

            <div className="space-y-2">
              <Label>عطیہ دہندہ کا نام *</Label>
              <Input
                required
                value={formData.donor_name}
                onChange={(e) => setFormData({ ...formData, donor_name: e.target.value })}
              />
            </div>

            <div className="space-y-2">
              <Label>رابطہ نمبر</Label>
              <Input
                value={formData.donor_contact}
                onChange={(e) => setFormData({ ...formData, donor_contact: e.target.value })}
              />
            </div>

            <div className="space-y-2">
              <Label>ای میل</Label>
              <Input
                type="email"
                value={formData.donor_email}
                onChange={(e) => setFormData({ ...formData, donor_email: e.target.value })}
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
              <Label>رسید نمبر</Label>
              <Input
                value={formData.receipt_number}
                onChange={(e) => setFormData({ ...formData, receipt_number: e.target.value })}
              />
            </div>
          </div>

          <div className="space-y-2">
            <Label>نوٹس</Label>
            <Textarea
              value={formData.notes}
              onChange={(e) => setFormData({ ...formData, notes: e.target.value })}
              rows={3}
            />
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
