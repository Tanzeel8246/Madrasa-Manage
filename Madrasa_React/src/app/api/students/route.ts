import { NextResponse } from 'next/server';
import { query } from '@/lib/db';
import fs from 'fs';
import path from 'path';

// Helper function to save base64 image
const savePhoto = (base64String: string, oldPath?: string) => {
  if (!base64String || !base64String.startsWith('data:image')) return oldPath || '';
  
  try {
    const matches = base64String.match(/^data:image\/([A-Za-z-+\/]+);base64,(.+)$/);
    if (!matches || matches.length !== 3) return oldPath || '';

    const ext = matches[1] === 'jpeg' ? 'jpg' : matches[1];
    const data = Buffer.from(matches[2], 'base64');
    
    const fileName = `std_${Date.now()}_${Math.random().toString(36).substring(7)}.${ext}`;
    const uploadDir = path.join(process.cwd(), 'public', 'uploads', 'students');
    
    // Create dir if not exists
    if (!fs.existsSync(uploadDir)) {
      fs.mkdirSync(uploadDir, { recursive: true });
    }

    const filePath = path.join(uploadDir, fileName);
    fs.writeFileSync(filePath, data);
    
    return `/uploads/students/${fileName}`;
  } catch (err) {
    console.error('Error saving photo:', err);
    return oldPath || '';
  }
};

export async function GET(request: Request) {
  try {
    const url = new URL(request.url);
    const search = url.searchParams.get('search') || '';
    
    let sql = `SELECT * FROM students WHERE status = 'Active' AND is_deleted = 0`;
    let params: any[] = [];
    
    if (search) {
      sql += ` AND (name LIKE ? OR father_name LIKE ? OR admission_number LIKE ? OR class LIKE ?)`;
      const searchParam = `%${search}%`;
      params = [searchParam, searchParam, searchParam, searchParam];
    }
    
    sql += ` ORDER BY admission_number DESC`;

    const students = await query(sql, params);
    
    return NextResponse.json({ success: true, students });
  } catch (error: any) {
    console.error('API Error:', error);
    return NextResponse.json({ success: false, message: error.message }, { status: 500 });
  }
}

export async function POST(request: Request) {
  try {
    const data = await request.json();
    const { name, father_name, class: cls, contact_number, address, admission_date, admission_number, photoBase64 } = data;

    if (!name || !father_name || !cls || !contact_number) {
      return NextResponse.json({ success: false, message: 'All required fields must be filled' }, { status: 400 });
    }

    const photoPath = savePhoto(photoBase64);

    const sql = `INSERT INTO students (name, father_name, admission_number, class, contact_number, address, status, admission_date, photo) VALUES (?, ?, ?, ?, ?, ?, 'Active', ?, ?)`;
    await query(sql, [name, father_name, admission_number, cls, contact_number, address, admission_date, photoPath]);

    return NextResponse.json({ success: true, message: 'طالب علم کامیابی سے شامل کر لیا گیا!' });
  } catch (error: any) {
    console.error('API Error:', error);
    return NextResponse.json({ success: false, message: error.message }, { status: 500 });
  }
}

export async function PUT(request: Request) {
  try {
    const data = await request.json();
    const { id, name, father_name, class: cls, contact_number, address, admission_date, admission_number, photoBase64 } = data;

    if (!id || !name || !father_name || !cls) {
      return NextResponse.json({ success: false, message: 'Missing required fields for update' }, { status: 400 });
    }

    // Get old photo path to retain if not changed
    const oldStudent: any = await query(`SELECT photo FROM students WHERE id = ?`, [id]);
    const oldPhotoPath = oldStudent[0]?.photo;

    // Only save new photo if photoBase64 is an actual new base64 string
    const photoPath = photoBase64.startsWith('data:image') ? savePhoto(photoBase64, oldPhotoPath) : oldPhotoPath;

    const sql = `UPDATE students SET name=?, father_name=?, admission_number=?, class=?, contact_number=?, address=?, admission_date=?, photo=? WHERE id=?`;
    await query(sql, [name, father_name, admission_number, cls, contact_number, address, admission_date, photoPath, id]);

    return NextResponse.json({ success: true, message: 'طالب علم کا ریکارڈ اپڈیٹ ہو گیا!' });
  } catch (error: any) {
    console.error('API Error:', error);
    return NextResponse.json({ success: false, message: error.message }, { status: 500 });
  }
}

export async function DELETE(request: Request) {
  try {
    const url = new URL(request.url);
    const id = url.searchParams.get('id');
    const type = url.searchParams.get('type'); // 'alumni' or 'delete'

    if (!id) {
      return NextResponse.json({ success: false, message: 'ID is required' }, { status: 400 });
    }

    if (type === 'alumni') {
      const sql = `UPDATE students SET status = 'Alumni', graduation_date = ? WHERE id=?`;
      await query(sql, [new Date().toISOString().split('T')[0], id]);
      return NextResponse.json({ success: true, message: 'طالب علم کو فارغ التحصیل کر دیا گیا!' });
    } else {
      // Soft delete
      const sql = `UPDATE students SET is_deleted = 1 WHERE id=?`;
      await query(sql, [id]);
      return NextResponse.json({ success: true, message: 'طالب علم کا ریکارڈ حذف (ڈیلیٹ) کر دیا گیا!' });
    }
  } catch (error: any) {
    console.error('API Error:', error);
    return NextResponse.json({ success: false, message: error.message }, { status: 500 });
  }
}
