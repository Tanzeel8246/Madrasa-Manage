import { NextResponse } from 'next/server';
import { query } from '@/lib/db';

export async function POST(request: Request) {
  try {
    const body = await request.json();
    const { student_ids, date, category, new_category, complaint } = body;

    if (!student_ids || !Array.isArray(student_ids) || student_ids.length === 0 || !date || !complaint) {
      return NextResponse.json({ success: false, message: 'Required fields missing' }, { status: 400 });
    }

    let finalCategory = category;
    if (category === '__NEW__' && new_category) {
      finalCategory = new_category;
    } else if (category === '__NEW__') {
      finalCategory = 'General';
    }

    const finalComplaintText = `[${finalCategory}] ${complaint}`;

    for (const std_id of student_ids) {
      await query('INSERT INTO complaints (student_id, date, complaint) VALUES (?, ?, ?)', [
        std_id, date, finalComplaintText
      ]);
    }

    return NextResponse.json({ success: true, message: 'شکایت / نوٹ کامیابی سے درج کر لیا گیا ہے!' });
  } catch (error: any) {
    return NextResponse.json({ success: false, message: error.message }, { status: 500 });
  }
}
