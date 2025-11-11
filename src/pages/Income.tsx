import { useState } from "react";
import { Plus, Search, Edit, Trash2, Download } from "lucide-react";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from "@/components/ui/table";
import { Badge } from "@/components/ui/badge";
import { AlertDialog, AlertDialogAction, AlertDialogCancel, AlertDialogContent, AlertDialogDescription, AlertDialogFooter, AlertDialogHeader, AlertDialogTitle } from "@/components/ui/alert-dialog";
import { useAuth } from "@/contexts/AuthContext";
import { useIncome, IncomeRecord } from "@/hooks/useIncome";
import { IncomeDialog } from "@/components/Financial/IncomeDialog";
import { format } from "date-fns";

const Income = () => {
  const { isAdmin } = useAuth();
  const { incomeRecords, isLoading, createIncome, updateIncome, deleteIncome } = useIncome();
  const [searchQuery, setSearchQuery] = useState("");
  const [dialogOpen, setDialogOpen] = useState(false);
  const [deleteDialogOpen, setDeleteDialogOpen] = useState(false);
  const [selectedIncome, setSelectedIncome] = useState<IncomeRecord | undefined>();
  const [incomeToDelete, setIncomeToDelete] = useState<string | null>(null);

  const filteredRecords = incomeRecords.filter((record) =>
    record.donor_name.toLowerCase().includes(searchQuery.toLowerCase()) ||
    record.income_type.toLowerCase().includes(searchQuery.toLowerCase()) ||
    record.amount.toString().includes(searchQuery)
  );

  const handleEdit = (income: IncomeRecord) => {
    setSelectedIncome(income);
    setDialogOpen(true);
  };

  const handleDelete = (id: string) => {
    setIncomeToDelete(id);
    setDeleteDialogOpen(true);
  };

  const confirmDelete = () => {
    if (incomeToDelete) {
      deleteIncome.mutate(incomeToDelete);
      setDeleteDialogOpen(false);
      setIncomeToDelete(null);
    }
  };

  const handleSave = (income: Omit<IncomeRecord, "id" | "created_at" | "updated_at">) => {
    if (selectedIncome) {
      updateIncome.mutate({ ...income, id: selectedIncome.id });
    } else {
      createIncome.mutate(income);
    }
    setSelectedIncome(undefined);
  };

  const getIncomeTypeBadge = (type: string) => {
    const types: Record<string, { label: string; variant: "default" | "secondary" | "outline" }> = {
      zakat: { label: "زکوٰۃ", variant: "default" },
      sadaqat: { label: "صدقات", variant: "secondary" },
      fitrana: { label: "فطرانہ", variant: "outline" },
      donation: { label: "عطیہ", variant: "default" },
      monthly_donation: { label: "ماہانہ", variant: "secondary" },
      yearly_donation: { label: "سالانہ", variant: "outline" },
      onetime_donation: { label: "ایک وقتی", variant: "default" },
    };
    return types[type] || { label: type, variant: "default" };
  };

  const totalIncome = filteredRecords.reduce((sum, record) => sum + Number(record.amount), 0);

  return (
    <div className="container mx-auto p-6 space-y-6">
      <div className="flex justify-between items-center">
        <div>
          <h1 className="text-3xl font-bold">آمد کا رجسٹر</h1>
          <p className="text-muted-foreground mt-2">زکوٰۃ، صدقات، عطیات اور دیگر آمدنی کا ریکارڈ</p>
        </div>
        {isAdmin && (
          <Button onClick={() => { setSelectedIncome(undefined); setDialogOpen(true); }}>
            <Plus className="mr-2 h-4 w-4" />
            نیا آمد کا ریکارڈ
          </Button>
        )}
      </div>

      <Card>
        <CardHeader>
          <div className="flex items-center justify-between">
            <div>
              <CardTitle>مجموعی آمد</CardTitle>
              <CardDescription className="text-2xl font-bold text-primary mt-2">
                Rs. {totalIncome.toLocaleString()}
              </CardDescription>
            </div>
            <div className="flex gap-2">
              <div className="relative">
                <Search className="absolute left-3 top-1/2 transform -translate-y-1/2 h-4 w-4 text-muted-foreground" />
                <Input
                  placeholder="تلاش کریں..."
                  value={searchQuery}
                  onChange={(e) => setSearchQuery(e.target.value)}
                  className="pl-10 w-64"
                />
              </div>
              <Button variant="outline">
                <Download className="mr-2 h-4 w-4" />
                ایکسپورٹ
              </Button>
            </div>
          </div>
        </CardHeader>
        <CardContent>
          {isLoading ? (
            <div className="text-center py-8">لوڈ ہو رہا ہے...</div>
          ) : filteredRecords.length === 0 ? (
            <div className="text-center py-8 text-muted-foreground">
              {searchQuery ? "کوئی نتیجہ نہیں ملا" : "ابھی تک کوئی آمد کا ریکارڈ نہیں ہے"}
            </div>
          ) : (
            <Table>
              <TableHeader>
                <TableRow>
                  <TableHead>تاریخ</TableHead>
                  <TableHead>عطیہ دہندہ</TableHead>
                  <TableHead>قسم</TableHead>
                  <TableHead>رقم</TableHead>
                  <TableHead>طریقہ ادائیگی</TableHead>
                  <TableHead>رابطہ</TableHead>
                  {isAdmin && <TableHead className="text-right">اعمال</TableHead>}
                </TableRow>
              </TableHeader>
              <TableBody>
                {filteredRecords.map((record) => {
                  const typeInfo = getIncomeTypeBadge(record.income_type);
                  return (
                    <TableRow key={record.id}>
                      <TableCell>{format(new Date(record.date), "dd/MM/yyyy")}</TableCell>
                      <TableCell className="font-medium">{record.donor_name}</TableCell>
                      <TableCell>
                        <Badge variant={typeInfo.variant}>{typeInfo.label}</Badge>
                      </TableCell>
                      <TableCell className="font-semibold">Rs. {Number(record.amount).toLocaleString()}</TableCell>
                      <TableCell>
                        {record.payment_method === "cash" && "نقد"}
                        {record.payment_method === "bank_transfer" && "بینک"}
                        {record.payment_method === "cheque" && "چیک"}
                        {record.payment_method === "online" && "آن لائن"}
                      </TableCell>
                      <TableCell>{record.donor_contact || "-"}</TableCell>
                      {isAdmin && (
                        <TableCell className="text-right">
                          <div className="flex justify-end gap-2">
                            <Button variant="ghost" size="icon" onClick={() => handleEdit(record)}>
                              <Edit className="h-4 w-4" />
                            </Button>
                            <Button variant="ghost" size="icon" onClick={() => handleDelete(record.id)}>
                              <Trash2 className="h-4 w-4" />
                            </Button>
                          </div>
                        </TableCell>
                      )}
                    </TableRow>
                  );
                })}
              </TableBody>
            </Table>
          )}
        </CardContent>
      </Card>

      <IncomeDialog
        open={dialogOpen}
        onOpenChange={setDialogOpen}
        onSave={handleSave}
        income={selectedIncome}
      />

      <AlertDialog open={deleteDialogOpen} onOpenChange={setDeleteDialogOpen}>
        <AlertDialogContent>
          <AlertDialogHeader>
            <AlertDialogTitle>کیا آپ واقعی ڈیلیٹ کرنا چاہتے ہیں؟</AlertDialogTitle>
            <AlertDialogDescription>
              یہ عمل واپس نہیں کیا جا سکتا۔ آمد کا یہ ریکارڈ مستقل طور پر ڈیلیٹ ہو جائے گا۔
            </AlertDialogDescription>
          </AlertDialogHeader>
          <AlertDialogFooter>
            <AlertDialogCancel>منسوخ</AlertDialogCancel>
            <AlertDialogAction onClick={confirmDelete}>ڈیلیٹ کریں</AlertDialogAction>
          </AlertDialogFooter>
        </AlertDialogContent>
      </AlertDialog>
    </div>
  );
};

export default Income;
