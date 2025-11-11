import { useState } from "react";
import { Plus, Search, Edit, Trash2, Download, Phone, Mail } from "lucide-react";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from "@/components/ui/table";
import { Badge } from "@/components/ui/badge";
import { Avatar, AvatarFallback, AvatarImage } from "@/components/ui/avatar";
import { AlertDialog, AlertDialogAction, AlertDialogCancel, AlertDialogContent, AlertDialogDescription, AlertDialogFooter, AlertDialogHeader, AlertDialogTitle } from "@/components/ui/alert-dialog";
import { useAuth } from "@/contexts/AuthContext";
import { useStaff, StaffMember } from "@/hooks/useStaff";
import { StaffDialog } from "@/components/Financial/StaffDialog";
import { format } from "date-fns";

const Staff = () => {
  const { isAdmin } = useAuth();
  const { staffMembers, isLoading, createStaff, updateStaff, deleteStaff } = useStaff();
  const [searchQuery, setSearchQuery] = useState("");
  const [dialogOpen, setDialogOpen] = useState(false);
  const [deleteDialogOpen, setDeleteDialogOpen] = useState(false);
  const [selectedStaff, setSelectedStaff] = useState<StaffMember | undefined>();
  const [staffToDelete, setStaffToDelete] = useState<string | null>(null);

  const filteredMembers = staffMembers.filter((member) =>
    member.name.toLowerCase().includes(searchQuery.toLowerCase()) ||
    member.designation.toLowerCase().includes(searchQuery.toLowerCase()) ||
    member.contact.includes(searchQuery)
  );

  const handleEdit = (staff: StaffMember) => {
    setSelectedStaff(staff);
    setDialogOpen(true);
  };

  const handleDelete = (id: string) => {
    setStaffToDelete(id);
    setDeleteDialogOpen(true);
  };

  const confirmDelete = () => {
    if (staffToDelete) {
      deleteStaff.mutate(staffToDelete);
      setDeleteDialogOpen(false);
      setStaffToDelete(null);
    }
  };

  const handleSave = (staff: Omit<StaffMember, "id" | "created_at" | "updated_at">) => {
    if (selectedStaff) {
      updateStaff.mutate({ ...staff, id: selectedStaff.id });
    } else {
      createStaff.mutate(staff);
    }
    setSelectedStaff(undefined);
  };

  const getStatusBadge = (status: string) => {
    const statuses: Record<string, { label: string; variant: "default" | "secondary" | "destructive" }> = {
      active: { label: "فعال", variant: "default" },
      inactive: { label: "غیر فعال", variant: "secondary" },
      resigned: { label: "مستعفی", variant: "destructive" },
    };
    return statuses[status] || { label: status, variant: "default" };
  };

  const totalSalary = staffMembers
    .filter(m => m.status === "active")
    .reduce((sum, member) => sum + Number(member.salary), 0);

  return (
    <div className="container mx-auto p-6 space-y-6">
      <div className="flex justify-between items-center">
        <div>
          <h1 className="text-3xl font-bold">اسٹاف/ملازمین رجسٹر</h1>
          <p className="text-muted-foreground mt-2">ملازمین کی تفصیلات اور تنخواہوں کا ریکارڈ</p>
        </div>
        {isAdmin && (
          <Button onClick={() => { setSelectedStaff(undefined); setDialogOpen(true); }}>
            <Plus className="mr-2 h-4 w-4" />
            نیا اسٹاف ممبر
          </Button>
        )}
      </div>

      <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
        <Card>
          <CardHeader>
            <CardTitle>کل اسٹاف</CardTitle>
          </CardHeader>
          <CardContent>
            <p className="text-3xl font-bold">{staffMembers.length}</p>
          </CardContent>
        </Card>
        <Card>
          <CardHeader>
            <CardTitle>فعال اسٹاف</CardTitle>
          </CardHeader>
          <CardContent>
            <p className="text-3xl font-bold text-green-600">
              {staffMembers.filter(m => m.status === "active").length}
            </p>
          </CardContent>
        </Card>
        <Card>
          <CardHeader>
            <CardTitle>ماہانہ تنخواہیں</CardTitle>
          </CardHeader>
          <CardContent>
            <p className="text-3xl font-bold text-primary">
              Rs. {totalSalary.toLocaleString()}
            </p>
          </CardContent>
        </Card>
      </div>

      <Card>
        <CardHeader>
          <div className="flex items-center justify-between">
            <div>
              <CardTitle>اسٹاف ممبرز</CardTitle>
              <CardDescription>ملازمین کی مکمل فہرست</CardDescription>
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
          ) : filteredMembers.length === 0 ? (
            <div className="text-center py-8 text-muted-foreground">
              {searchQuery ? "کوئی نتیجہ نہیں ملا" : "ابھی تک کوئی اسٹاف ممبر نہیں ہے"}
            </div>
          ) : (
            <Table>
              <TableHeader>
                <TableRow>
                  <TableHead>نام</TableHead>
                  <TableHead>عہدہ</TableHead>
                  <TableHead>تنخواہ</TableHead>
                  <TableHead>شمولیت</TableHead>
                  <TableHead>رابطہ</TableHead>
                  <TableHead>حیثیت</TableHead>
                  {isAdmin && <TableHead className="text-right">اعمال</TableHead>}
                </TableRow>
              </TableHeader>
              <TableBody>
                {filteredMembers.map((member) => {
                  const statusInfo = getStatusBadge(member.status);
                  return (
                    <TableRow key={member.id}>
                      <TableCell>
                        <div className="flex items-center gap-3">
                          <Avatar>
                            <AvatarImage src={member.photo_url} />
                            <AvatarFallback>{member.name.charAt(0)}</AvatarFallback>
                          </Avatar>
                          <div>
                            <div className="font-medium">{member.name}</div>
                            {member.father_name && (
                              <div className="text-sm text-muted-foreground">
                                ولدیت: {member.father_name}
                              </div>
                            )}
                          </div>
                        </div>
                      </TableCell>
                      <TableCell>{member.designation}</TableCell>
                      <TableCell className="font-semibold">
                        Rs. {Number(member.salary).toLocaleString()}
                      </TableCell>
                      <TableCell>{format(new Date(member.joining_date), "dd/MM/yyyy")}</TableCell>
                      <TableCell>
                        <div className="flex flex-col gap-1">
                          <div className="flex items-center gap-1 text-sm">
                            <Phone className="h-3 w-3" />
                            {member.contact}
                          </div>
                          {member.email && (
                            <div className="flex items-center gap-1 text-sm text-muted-foreground">
                              <Mail className="h-3 w-3" />
                              {member.email}
                            </div>
                          )}
                        </div>
                      </TableCell>
                      <TableCell>
                        <Badge variant={statusInfo.variant}>{statusInfo.label}</Badge>
                      </TableCell>
                      {isAdmin && (
                        <TableCell className="text-right">
                          <div className="flex justify-end gap-2">
                            <Button variant="ghost" size="icon" onClick={() => handleEdit(member)}>
                              <Edit className="h-4 w-4" />
                            </Button>
                            <Button variant="ghost" size="icon" onClick={() => handleDelete(member.id)}>
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

      <StaffDialog
        open={dialogOpen}
        onOpenChange={setDialogOpen}
        onSave={handleSave}
        staff={selectedStaff}
      />

      <AlertDialog open={deleteDialogOpen} onOpenChange={setDeleteDialogOpen}>
        <AlertDialogContent>
          <AlertDialogHeader>
            <AlertDialogTitle>کیا آپ واقعی ڈیلیٹ کرنا چاہتے ہیں؟</AlertDialogTitle>
            <AlertDialogDescription>
              یہ عمل واپس نہیں کیا جا سکتا۔ اسٹاف ممبر کا یہ ریکارڈ مستقل طور پر ڈیلیٹ ہو جائے گا۔
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

export default Staff;
