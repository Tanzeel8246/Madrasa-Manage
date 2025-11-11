import { useState } from "react";
import { Plus, Search, Edit, Trash2, Download } from "lucide-react";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from "@/components/ui/table";
import { Badge } from "@/components/ui/badge";
import { AlertDialog, AlertDialogAction, AlertDialogCancel, AlertDialogContent, AlertDialogDescription, AlertDialogFooter, AlertDialogHeader, AlertDialogTitle } from "@/components/ui/alert-dialog";
import { useAuth } from "@/contexts/AuthContext";
import { useExpenses, ExpenseRecord } from "@/hooks/useExpenses";
import { ExpenseDialog } from "@/components/Financial/ExpenseDialog";
import { format } from "date-fns";

const Expenses = () => {
  const { isAdmin } = useAuth();
  const { expenseRecords, isLoading, createExpense, updateExpense, deleteExpense } = useExpenses();
  const [searchQuery, setSearchQuery] = useState("");
  const [dialogOpen, setDialogOpen] = useState(false);
  const [deleteDialogOpen, setDeleteDialogOpen] = useState(false);
  const [selectedExpense, setSelectedExpense] = useState<ExpenseRecord | undefined>();
  const [expenseToDelete, setExpenseToDelete] = useState<string | null>(null);

  const filteredRecords = expenseRecords.filter((record) =>
    record.description.toLowerCase().includes(searchQuery.toLowerCase()) ||
    record.category.toLowerCase().includes(searchQuery.toLowerCase()) ||
    record.paid_to.toLowerCase().includes(searchQuery.toLowerCase()) ||
    record.amount.toString().includes(searchQuery)
  );

  const handleEdit = (expense: ExpenseRecord) => {
    setSelectedExpense(expense);
    setDialogOpen(true);
  };

  const handleDelete = (id: string) => {
    setExpenseToDelete(id);
    setDeleteDialogOpen(true);
  };

  const confirmDelete = () => {
    if (expenseToDelete) {
      deleteExpense.mutate(expenseToDelete);
      setDeleteDialogOpen(false);
      setExpenseToDelete(null);
    }
  };

  const handleSave = (expense: Omit<ExpenseRecord, "id" | "created_at" | "updated_at">) => {
    if (selectedExpense) {
      updateExpense.mutate({ ...expense, id: selectedExpense.id });
    } else {
      createExpense.mutate(expense);
    }
    setSelectedExpense(undefined);
  };

  const getCategoryBadge = (category: string) => {
    const categories: Record<string, { label: string; variant: "default" | "secondary" | "destructive" | "outline" }> = {
      salary: { label: "تنخواہ", variant: "default" },
      food: { label: "کھانا", variant: "secondary" },
      electricity: { label: "بجلی", variant: "outline" },
      water: { label: "پانی", variant: "outline" },
      gas: { label: "گیس", variant: "outline" },
      construction: { label: "تعمیرات", variant: "default" },
      repair: { label: "مرمت", variant: "secondary" },
      stationery: { label: "اسٹیشنری", variant: "outline" },
      transport: { label: "ٹرانسپورٹ", variant: "secondary" },
      other: { label: "دیگر", variant: "outline" },
    };
    return categories[category] || { label: category, variant: "default" };
  };

  const totalExpense = filteredRecords.reduce((sum, record) => sum + Number(record.amount), 0);

  return (
    <div className="container mx-auto p-6 space-y-6">
      <div className="flex justify-between items-center">
        <div>
          <h1 className="text-3xl font-bold">خرچ کا رجسٹر</h1>
          <p className="text-muted-foreground mt-2">تنخواہیں، بلز اور دیگر اخراجات کا ریکارڈ</p>
        </div>
        {isAdmin && (
          <Button onClick={() => { setSelectedExpense(undefined); setDialogOpen(true); }}>
            <Plus className="mr-2 h-4 w-4" />
            نیا خرچ کا ریکارڈ
          </Button>
        )}
      </div>

      <Card>
        <CardHeader>
          <div className="flex items-center justify-between">
            <div>
              <CardTitle>مجموعی خرچ</CardTitle>
              <CardDescription className="text-2xl font-bold text-destructive mt-2">
                Rs. {totalExpense.toLocaleString()}
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
              {searchQuery ? "کوئی نتیجہ نہیں ملا" : "ابھی تک کوئی خرچ کا ریکارڈ نہیں ہے"}
            </div>
          ) : (
            <Table>
              <TableHeader>
                <TableRow>
                  <TableHead>تاریخ</TableHead>
                  <TableHead>زمرہ</TableHead>
                  <TableHead>تفصیل</TableHead>
                  <TableHead>رقم</TableHead>
                  <TableHead>ادائیگی کس کو</TableHead>
                  <TableHead>طریقہ ادائیگی</TableHead>
                  {isAdmin && <TableHead className="text-right">اعمال</TableHead>}
                </TableRow>
              </TableHeader>
              <TableBody>
                {filteredRecords.map((record) => {
                  const categoryInfo = getCategoryBadge(record.category);
                  return (
                    <TableRow key={record.id}>
                      <TableCell>{format(new Date(record.date), "dd/MM/yyyy")}</TableCell>
                      <TableCell>
                        <Badge variant={categoryInfo.variant}>{categoryInfo.label}</Badge>
                      </TableCell>
                      <TableCell className="font-medium">{record.description}</TableCell>
                      <TableCell className="font-semibold text-destructive">
                        Rs. {Number(record.amount).toLocaleString()}
                      </TableCell>
                      <TableCell>{record.paid_to}</TableCell>
                      <TableCell>
                        {record.payment_method === "cash" && "نقد"}
                        {record.payment_method === "bank_transfer" && "بینک"}
                        {record.payment_method === "cheque" && "چیک"}
                        {record.payment_method === "online" && "آن لائن"}
                      </TableCell>
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

      <ExpenseDialog
        open={dialogOpen}
        onOpenChange={setDialogOpen}
        onSave={handleSave}
        expense={selectedExpense}
      />

      <AlertDialog open={deleteDialogOpen} onOpenChange={setDeleteDialogOpen}>
        <AlertDialogContent>
          <AlertDialogHeader>
            <AlertDialogTitle>کیا آپ واقعی ڈیلیٹ کرنا چاہتے ہیں؟</AlertDialogTitle>
            <AlertDialogDescription>
              یہ عمل واپس نہیں کیا جا سکتا۔ خرچ کا یہ ریکارڈ مستقل طور پر ڈیلیٹ ہو جائے گا۔
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

export default Expenses;
