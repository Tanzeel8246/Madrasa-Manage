import { NextResponse } from 'next/server';
import { query } from '@/lib/db';

function formatDate(d: any) {
  if (typeof d === 'string') return d.split('T')[0];
  if (d instanceof Date) {
    const offset = d.getTimezoneOffset() * 60000;
    return (new Date(d.getTime() - offset)).toISOString().slice(0, 10);
  }
  return '';
}

export async function GET(request: Request) {
  try {
    const url = new URL(request.url);
    const month = url.searchParams.get('month');
    const year = url.searchParams.get('year');

    if (!month || !year) {
      return NextResponse.json({ success: false, message: 'Missing month or year' }, { status: 400 });
    }

    const startDate = `${year}-${month.padStart(2, '0')}-01`;
    const endDateObj = new Date(Number(year), Number(month), 0);
    const endDate = `${year}-${month.padStart(2, '0')}-${endDateObj.getDate().toString().padStart(2, '0')}`;

    const dates = [];
    for (let d = 1; d <= endDateObj.getDate(); d++) {
      dates.push(`${year}-${month.padStart(2, '0')}-${d.toString().padStart(2, '0')}`);
    }

    // Fetch Teachers
    const teachers: any = await query(
      "SELECT id, name, father_name FROM teachers WHERE status = 'Active' AND is_deleted = 0 ORDER BY name ASC"
    );

    // Fetch Teacher Attendance
    const tAtt: any = await query(
      "SELECT teacher_id, date, status, late_minutes FROM attendance_teachers WHERE date BETWEEN ? AND ?",
      [startDate, endDate]
    );

    const attMap: any = {};
    for (const row of tAtt) {
      const dString = formatDate(row.date);
      if (!attMap[row.teacher_id]) attMap[row.teacher_id] = {};
      attMap[row.teacher_id][dString] = {
        status: row.status,
        late: row.late_minutes
      };
    }

    const reportData = teachers.map((t: any) => ({
      id: t.id,
      name: t.name,
      father_name: t.father_name,
      attendance: attMap[t.id] || {}
    }));

    return NextResponse.json({ success: true, dates, data: reportData });
  } catch (error: any) {
    return NextResponse.json({ success: false, message: error.message }, { status: 500 });
  }
}
