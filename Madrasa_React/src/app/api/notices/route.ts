import { query } from '@/lib/db';
import { NextResponse } from 'next/server';

export async function GET() {
  try {
    const notices = await query('SELECT * FROM notices WHERE is_deleted = 0 ORDER BY date DESC, id DESC');
    return NextResponse.json({ success: true, data: notices });
  } catch (error: any) {
    return NextResponse.json({ success: false, message: error.message }, { status: 500 });
  }
}

export async function POST(request: Request) {
  try {
    const body = await request.json();
    const { title, message, date } = body;
    
    if (!title || !message || !date) {
      return NextResponse.json({ success: false, message: 'All fields are required' }, { status: 400 });
    }

    const result: any = await query(
      'INSERT INTO notices (title, message, date) VALUES (?, ?, ?)',
      [title, message, date]
    );

    return NextResponse.json({ success: true, insertId: result.insertId });
  } catch (error: any) {
    return NextResponse.json({ success: false, message: error.message }, { status: 500 });
  }
}

export async function DELETE(request: Request) {
  try {
    const { searchParams } = new URL(request.url);
    const id = searchParams.get('id');

    if (!id) {
      return NextResponse.json({ success: false, message: 'ID required' }, { status: 400 });
    }

    await query('UPDATE notices SET is_deleted = 1 WHERE id = ?', [id]);
    return NextResponse.json({ success: true });
  } catch (error: any) {
    return NextResponse.json({ success: false, message: error.message }, { status: 500 });
  }
}
