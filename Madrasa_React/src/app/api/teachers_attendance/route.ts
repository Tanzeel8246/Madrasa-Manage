import { NextResponse } from 'next/server';
import { query } from '@/lib/db';

export async function GET(request: Request) {
  try {
    const url = new URL(request.url);
    const date = url.searchParams.get('date');

    if (!date) {
      return NextResponse.json({ success: false, message: 'Missing date parameter' }, { status: 400 });
    }

    // 1. Fetch Teachers
    const teachers: any = await query(
      "SELECT id, name, father_name FROM teachers WHERE status = 'Active' AND is_deleted = 0 ORDER BY name ASC"
    );

    // 2. Fetch existing attendance for this date
    const attendance: any = await query(
      "SELECT teacher_id, status, late_minutes FROM attendance_teachers WHERE date = ?",
      [date]
    );

    const attMap = new Map<number, any>(attendance.map((a: any) => [a.teacher_id, { status: a.status, late_minutes: a.late_minutes }]));

    // 3. Map status to teachers
    const mappedTeachers = teachers.map((t: any) => {
      const att = attMap.get(t.id);
      return {
        ...t,
        status: att ? att.status : 'P',
        late_minutes: att ? att.late_minutes : 0
      };
    });

    return NextResponse.json({ success: true, data: mappedTeachers });
  } catch (error: any) {
    return NextResponse.json({ success: false, message: error.message }, { status: 500 });
  }
}

export async function POST(request: Request) {
  try {
    const data = await request.json();
    const { date, teachers } = data;

    if (!date || !teachers || !Array.isArray(teachers)) {
      return NextResponse.json({ success: false, message: 'Missing parameters' }, { status: 400 });
    }

    for (const t of teachers) {
      const lateMins = t.late_minutes || 0;
      // Check if exists
      const exists: any = await query(
        "SELECT id FROM attendance_teachers WHERE date = ? AND teacher_id = ?",
        [date, t.id]
      );
      
      if (exists.length > 0) {
        await query(
          "UPDATE attendance_teachers SET status = ?, late_minutes = ? WHERE id = ?",
          [t.status, lateMins, exists[0].id]
        );
      } else {
        await query(
          "INSERT INTO attendance_teachers (teacher_id, date, status, late_minutes, remarks) VALUES (?, ?, ?, ?, '')",
          [t.id, date, t.status, lateMins]
        );
      }
    }

    return NextResponse.json({ success: true, message: 'Attendance saved successfully' });
  } catch (error: any) {
    return NextResponse.json({ success: false, message: error.message }, { status: 500 });
  }
}
