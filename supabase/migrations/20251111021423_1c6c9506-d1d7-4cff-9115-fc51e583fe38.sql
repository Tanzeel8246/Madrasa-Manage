-- Create enum for income types
CREATE TYPE income_type AS ENUM (
  'zakat',
  'sadaqat', 
  'fitrana',
  'donation',
  'monthly_donation',
  'yearly_donation',
  'onetime_donation'
);

-- Create enum for expense categories
CREATE TYPE expense_category AS ENUM (
  'salary',
  'food',
  'electricity',
  'water',
  'gas',
  'construction',
  'repair',
  'stationery',
  'transport',
  'other'
);

-- Create enum for payment methods
CREATE TYPE payment_method AS ENUM (
  'cash',
  'bank_transfer',
  'cheque',
  'online'
);

-- Create income_records table
CREATE TABLE public.income_records (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  madrasa_name TEXT,
  amount NUMERIC NOT NULL CHECK (amount > 0),
  income_type income_type NOT NULL,
  donor_name TEXT NOT NULL,
  donor_contact TEXT,
  donor_email TEXT,
  payment_method payment_method NOT NULL DEFAULT 'cash',
  date DATE NOT NULL DEFAULT CURRENT_DATE,
  notes TEXT,
  receipt_number TEXT,
  created_by UUID,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now()
);

-- Create expense_records table
CREATE TABLE public.expense_records (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  madrasa_name TEXT,
  amount NUMERIC NOT NULL CHECK (amount > 0),
  category expense_category NOT NULL,
  description TEXT NOT NULL,
  paid_to TEXT NOT NULL,
  payment_method payment_method NOT NULL DEFAULT 'cash',
  date DATE NOT NULL DEFAULT CURRENT_DATE,
  receipt_url TEXT,
  voucher_number TEXT,
  created_by UUID,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now()
);

-- Create staff_members table
CREATE TABLE public.staff_members (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  madrasa_name TEXT,
  name TEXT NOT NULL,
  father_name TEXT,
  designation TEXT NOT NULL,
  qualification TEXT,
  salary NUMERIC NOT NULL CHECK (salary >= 0),
  joining_date DATE NOT NULL,
  contact TEXT NOT NULL,
  email TEXT,
  address TEXT,
  cnic TEXT,
  status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'inactive', 'resigned')),
  bank_name TEXT,
  account_number TEXT,
  photo_url TEXT,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now()
);

-- Create storage bucket for receipts and staff photos
INSERT INTO storage.buckets (id, name, public) 
VALUES 
  ('receipts', 'receipts', false),
  ('staff-photos', 'staff-photos', true)
ON CONFLICT (id) DO NOTHING;

-- Enable RLS
ALTER TABLE public.income_records ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.expense_records ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.staff_members ENABLE ROW LEVEL SECURITY;

-- RLS Policies for income_records
CREATE POLICY "Users can view income in their madrasa"
ON public.income_records FOR SELECT
USING (madrasa_name = (SELECT madrasa_name FROM profiles WHERE id = auth.uid()));

CREATE POLICY "Admins can manage income in their madrasa"
ON public.income_records FOR ALL
USING (
  madrasa_name = (SELECT madrasa_name FROM profiles WHERE id = auth.uid())
  AND has_role(auth.uid(), 'admin'::app_role)
);

-- RLS Policies for expense_records
CREATE POLICY "Users can view expenses in their madrasa"
ON public.expense_records FOR SELECT
USING (madrasa_name = (SELECT madrasa_name FROM profiles WHERE id = auth.uid()));

CREATE POLICY "Admins can manage expenses in their madrasa"
ON public.expense_records FOR ALL
USING (
  madrasa_name = (SELECT madrasa_name FROM profiles WHERE id = auth.uid())
  AND has_role(auth.uid(), 'admin'::app_role)
);

-- RLS Policies for staff_members
CREATE POLICY "Users can view staff in their madrasa"
ON public.staff_members FOR SELECT
USING (madrasa_name = (SELECT madrasa_name FROM profiles WHERE id = auth.uid()));

CREATE POLICY "Admins can manage staff in their madrasa"
ON public.staff_members FOR ALL
USING (
  madrasa_name = (SELECT madrasa_name FROM profiles WHERE id = auth.uid())
  AND has_role(auth.uid(), 'admin'::app_role)
);

-- Storage policies for receipts bucket
CREATE POLICY "Users can view receipts from their madrasa"
ON storage.objects FOR SELECT
USING (
  bucket_id = 'receipts' 
  AND auth.uid() IN (SELECT id FROM profiles WHERE madrasa_name = (storage.foldername(name))[1])
);

CREATE POLICY "Admins can upload receipts"
ON storage.objects FOR INSERT
WITH CHECK (
  bucket_id = 'receipts'
  AND has_role(auth.uid(), 'admin'::app_role)
);

CREATE POLICY "Admins can update receipts"
ON storage.objects FOR UPDATE
USING (
  bucket_id = 'receipts'
  AND has_role(auth.uid(), 'admin'::app_role)
);

CREATE POLICY "Admins can delete receipts"
ON storage.objects FOR DELETE
USING (
  bucket_id = 'receipts'
  AND has_role(auth.uid(), 'admin'::app_role)
);

-- Storage policies for staff-photos bucket
CREATE POLICY "Anyone can view staff photos"
ON storage.objects FOR SELECT
USING (bucket_id = 'staff-photos');

CREATE POLICY "Admins can upload staff photos"
ON storage.objects FOR INSERT
WITH CHECK (
  bucket_id = 'staff-photos'
  AND has_role(auth.uid(), 'admin'::app_role)
);

CREATE POLICY "Admins can update staff photos"
ON storage.objects FOR UPDATE
USING (
  bucket_id = 'staff-photos'
  AND has_role(auth.uid(), 'admin'::app_role)
);

CREATE POLICY "Admins can delete staff photos"
ON storage.objects FOR DELETE
USING (
  bucket_id = 'staff-photos'
  AND has_role(auth.uid(), 'admin'::app_role)
);

-- Triggers for madrasa_name
CREATE TRIGGER set_income_madrasa_name
  BEFORE INSERT ON public.income_records
  FOR EACH ROW
  EXECUTE FUNCTION public.set_madrasa_name();

CREATE TRIGGER set_expense_madrasa_name
  BEFORE INSERT ON public.expense_records
  FOR EACH ROW
  EXECUTE FUNCTION public.set_madrasa_name();

CREATE TRIGGER set_staff_madrasa_name
  BEFORE INSERT ON public.staff_members
  FOR EACH ROW
  EXECUTE FUNCTION public.set_madrasa_name();

-- Triggers for updated_at
CREATE TRIGGER update_income_updated_at
  BEFORE UPDATE ON public.income_records
  FOR EACH ROW
  EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER update_expense_updated_at
  BEFORE UPDATE ON public.expense_records
  FOR EACH ROW
  EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER update_staff_updated_at
  BEFORE UPDATE ON public.staff_members
  FOR EACH ROW
  EXECUTE FUNCTION public.update_updated_at_column();