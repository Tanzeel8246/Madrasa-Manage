import { NextResponse } from 'next/server';
import { query } from '@/lib/db';

export async function GET(request: Request) {
  try {
    const url = new URL(request.url);
    const id = url.searchParams.get('id');

    if (id) {
      const teacher: any = await query('SELECT * FROM teachers WHERE id = ?', [id]);
      return NextResponse.json({ success: true, data: teacher[0] });
    }

    const teachers = await query('SELECT * FROM teachers ORDER BY id DESC');
    return NextResponse.json({ success: true, data: teachers });
  } catch (error: any) {
    return NextResponse.json({ success: false, message: error.message }, { status: 500 });
  }
}

export async function POST(request: Request) {
  try {
    const data = await request.json();
    
    const sql = `INSERT INTO teachers 
      (name, father_name, phone, cnic, qualification, address, salary, house_rent, medical_allowance, travel_allowance, daily_deduction_rate, joining_date, status) 
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`;
      
    const values = [
      data.name, 
      data.father_name || '', 
      data.phone || '', 
      data.cnic || '', 
      data.qualification || '', 
      data.address || '', 
      data.salary || 0, 
      data.house_rent || 0, 
      data.medical_allowance || 0, 
      data.travel_allowance || 0, 
      data.daily_deduction_rate || 0, 
      data.joining_date || new Date().toISOString().split('T')[0], 
      data.status || 'Active'
    ];

    const result: any = await query(sql, values);
    return NextResponse.json({ success: true, message: 'Teacher added successfully', id: result.insertId });
  } catch (error: any) {
    return NextResponse.json({ success: false, message: error.message }, { status: 500 });
  }
}

export async function PUT(request: Request) {
  try {
    const data = await request.json();
    const id = data.id;

    if (!id) {
      return NextResponse.json({ success: false, message: 'Teacher ID is required' }, { status: 400 });
    }
    
    const sql = `UPDATE teachers SET 
      name=?, father_name=?, phone=?, cnic=?, qualification=?, address=?, 
      salary=?, house_rent=?, medical_allowance=?, travel_allowance=?, 
      daily_deduction_rate=?, joining_date=?, status=? 
      WHERE id=?`;
      
    const values = [
      data.name, 
      data.father_name || '', 
      data.phone || '', 
      data.cnic || '', 
      data.qualification || '', 
      data.address || '', 
      data.salary || 0, 
      data.house_rent || 0, 
      data.medical_allowance || 0, 
      data.travel_allowance || 0, 
      data.daily_deduction_rate || 0, 
      data.joining_date || new Date().toISOString().split('T')[0], 
      data.status || 'Active',
      id
    ];

    await query(sql, values);
    return NextResponse.json({ success: true, message: 'Teacher updated successfully' });
  } catch (error: any) {
    return NextResponse.json({ success: false, message: error.message }, { status: 500 });
  }
}

export async function DELETE(request: Request) {
  try {
    const url = new URL(request.url);
    const id = url.searchParams.get('id');

    if (!id) {
      return NextResponse.json({ success: false, message: 'ID is required' }, { status: 400 });
    }

    await query('DELETE FROM teachers WHERE id = ?', [id]);
    return NextResponse.json({ success: true, message: 'Teacher deleted successfully' });
  } catch (error: any) {
    return NextResponse.json({ success: false, message: error.message }, { status: 500 });
  }
}
