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
import { StaffMember } from "@/hooks/useStaff";

interface StaffDialogProps {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  onSave: (staff: Omit<StaffMember, "id" | "created_at" | "updated_at">) => void;
  staff?: StaffMember;
}

export const StaffDialog = ({ open, onOpenChange, onSave, staff }: StaffDialogProps) => {
  const [formData, setFormData] = useState<Omit<StaffMember, "id" | "created_at" | "updated_at">>({
    name: "",
    father_name: "",
    designation: "",
    qualification: "",
    salary: 0,
    joining_date: new Date().toISOString().split('T')[0],
    contact: "",
    email: "",
    address: "",
    cnic: "",
    status: "active",
    bank_name: "",
    account_number: "",
  });

  useEffect(() => {
    if (staff) {
      setFormData({
        name: staff.name,
        father_name: staff.father_name,
        designation: staff.designation,
        qualification: staff.qualification,
        salary: staff.salary,
        joining_date: staff.joining_date,
        contact: staff.contact,
        email: staff.email,
        address: staff.address,
        cnic: staff.cnic,
        status: staff.status,
        bank_name: staff.bank_name,
        account_number: staff.account_number,
      });
    }
  }, [staff]);

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    onSave(formData);
    onOpenChange(false);
  };

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="max-w-3xl max-h-[90vh] overflow-y-auto">
        <DialogHeader>
          <DialogTitle>{staff ? "اسٹاف میں ترمیم" : "نیا اسٹاف ممبر"}</DialogTitle>
        </DialogHeader>
        <form onSubmit={handleSubmit} className="space-y-4">
          <div className="grid grid-cols-2 gap-4">
            <div className="space-y-2">
              <Label>نام *</Label>
              <Input
                required
                value={formData.name}
                onChange={(e) => setFormData({ ...formData, name: e.target.value })}
              />
            </div>

            <div className="space-y-2">
              <Label>والد کا نام</Label>
              <Input
                value={formData.father_name}
                onChange={(e) => setFormData({ ...formData, father_name: e.target.value })}
              />
            </div>

            <div className="space-y-2">
              <Label>عہدہ *</Label>
              <Input
                required
                value={formData.designation}
                onChange={(e) => setFormData({ ...formData, designation: e.target.value })}
              />
            </div>

            <div className="space-y-2">
              <Label>تعلیمی قابلیت</Label>
              <Input
                value={formData.qualification}
                onChange={(e) => setFormData({ ...formData, qualification: e.target.value })}
              />
            </div>

            <div className="space-y-2">
              <Label>تنخواہ *</Label>
              <Input
                type="number"
                required
                value={formData.salary}
                onChange={(e) => setFormData({ ...formData, salary: parseFloat(e.target.value) })}
              />
            </div>

            <div className="space-y-2">
              <Label>شمولیت کی تاریخ *</Label>
              <Popover>
                <PopoverTrigger asChild>
                  <Button
                    variant="outline"
                    className={cn(
                      "w-full justify-start text-left font-normal",
                      !formData.joining_date && "text-muted-foreground"
                    )}
                  >
                    <CalendarIcon className="mr-2 h-4 w-4" />
                    {formData.joining_date ? format(new Date(formData.joining_date), "PPP") : "تاریخ منتخب کریں"}
                  </Button>
                </PopoverTrigger>
                <PopoverContent className="w-auto p-0">
                  <Calendar
                    mode="single"
                    selected={formData.joining_date ? new Date(formData.joining_date) : undefined}
                    onSelect={(date) => setFormData({ ...formData, joining_date: date?.toISOString().split('T')[0] || "" })}
                    initialFocus
                    className="pointer-events-auto"
                  />
                </PopoverContent>
              </Popover>
            </div>

            <div className="space-y-2">
              <Label>رابطہ نمبر *</Label>
              <Input
                required
                value={formData.contact}
                onChange={(e) => setFormData({ ...formData, contact: e.target.value })}
              />
            </div>

            <div className="space-y-2">
              <Label>ای میل</Label>
              <Input
                type="email"
                value={formData.email}
                onChange={(e) => setFormData({ ...formData, email: e.target.value })}
              />
            </div>

            <div className="space-y-2">
              <Label>شناختی کارڈ نمبر</Label>
              <Input
                value={formData.cnic}
                onChange={(e) => setFormData({ ...formData, cnic: e.target.value })}
              />
            </div>

            <div className="space-y-2">
              <Label>حیثیت *</Label>
              <Select
                value={formData.status}
                onValueChange={(value) => setFormData({ ...formData, status: value })}
              >
                <SelectTrigger>
                  <SelectValue />
                </SelectTrigger>
                <SelectContent>
                  <SelectItem value="active">فعال</SelectItem>
                  <SelectItem value="inactive">غیر فعال</SelectItem>
                  <SelectItem value="resigned">مستعفی</SelectItem>
                </SelectContent>
              </Select>
            </div>

            <div className="space-y-2 col-span-2">
              <Label>پتہ</Label>
              <Textarea
                value={formData.address}
                onChange={(e) => setFormData({ ...formData, address: e.target.value })}
                rows={2}
              />
            </div>

            <div className="space-y-2">
              <Label>بینک کا نام</Label>
              <Input
                value={formData.bank_name}
                onChange={(e) => setFormData({ ...formData, bank_name: e.target.value })}
              />
            </div>

            <div className="space-y-2">
              <Label>اکاؤنٹ نمبر</Label>
              <Input
                value={formData.account_number}
                onChange={(e) => setFormData({ ...formData, account_number: e.target.value })}
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
