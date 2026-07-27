import { NextResponse } from 'next/server';
import { query } from '@/lib/db';

export async function GET(request: Request) {
  try {
    const url = new URL(request.url);
    const date = url.searchParams.get('date');
    const classId = url.searchParams.get('class_id');
    const periodNo = url.searchParams.get('period_no');

    if (!date || !classId || !periodNo) {
      return NextResponse.json({ success: false, message: 'Missing parameters' }, { status: 400 });
    }

    // 1. Fetch Students in the class
    const cls: any = await query('SELECT name FROM classes WHERE id = ?', [classId]);
    let finalStudents = [];
    if (cls.length > 0) {
      finalStudents = await query(
        "SELECT id, name, father_name, admission_number FROM students WHERE class = ? AND status = 'Active' AND is_deleted = 0 ORDER BY name ASC",
        [cls[0].name]
      ) as any[];
    }

    // Fetch existing student attendance for this period
    const stdAtt: any = await query(
      "SELECT student_id, status FROM period_attendance WHERE date = ? AND period_num = ?",
      [date, periodNo]
    );
    const stdAttMap = new Map(stdAtt.map((a: any) => [a.student_id, a.status]));

    const mappedStudents = finalStudents.map((s: any) => ({
      ...s,
      status: stdAttMap.get(s.id) || 'P' // Default to Present
    }));

    // 2. Fetch Teacher for this class and period
    const periods: any = await query(
      "SELECT teacher_ids FROM class_periods WHERE class_id = ? AND period_no = ?",
      [classId, periodNo]
    );
    
    let teacher = null;
    if (periods.length > 0 && periods[0].teacher_ids) {
      const tIds = JSON.parse(periods[0].teacher_ids);
      if (tIds && tIds.length > 0) {
        // Just take the first assigned teacher for simplicity in UI, or handle multiple
        const tId = tIds[0];
        const tData: any = await query("SELECT id, name FROM teachers WHERE id = ?", [tId]);
        
        if (tData.length > 0) {
          teacher = tData[0];
          
          // Fetch existing teacher attendance
          const tAtt: any = await query(
            "SELECT status FROM teacher_period_attendance WHERE teacher_id = ? AND date = ? AND period_no = ?",
            [tId, date, periodNo]
          );
          teacher.status = tAtt.length > 0 ? tAtt[0].status : 'P'; // Default
        }
      }
    }

    return NextResponse.json({ 
      success: true, 
      data: {
        students: mappedStudents,
        teacher: teacher
      }
    });

  } catch (error: any) {
    return NextResponse.json({ success: false, message: error.message }, { status: 500 });
  }
}

export async function POST(request: Request) {
  try {
    const data = await request.json();
    const { date, class_id, period_no, students, teacher_id, teacher_status, teacher_late_mins } = data;

    if (!date || !class_id || !period_no) {
      return NextResponse.json({ success: false, message: 'Missing parameters' }, { status: 400 });
    }

    // 1. Save Student Attendance
    if (students && Array.isArray(students)) {
      const cls: any = await query('SELECT name FROM classes WHERE id = ?', [class_id]);
      const className = cls.length > 0 ? cls[0].name : class_id;

      for (const std of students) {
        // Check if exists
        const exists: any = await query(
          "SELECT id FROM period_attendance WHERE date = ? AND period_num = ? AND student_id = ?",
          [date, period_no, std.id]
        );
        
        if (exists.length > 0) {
          await query(
            "UPDATE period_attendance SET status = ? WHERE id = ?",
            [std.status, exists[0].id]
          );
        } else {
          await query(
            "INSERT INTO period_attendance (student_id, date, period_num, status) VALUES (?, ?, ?, ?)",
            [std.id, date, period_no, std.status]
          );
        }
      }
    }

    // 2. Save Teacher Period Attendance
    if (teacher_id && teacher_status) {
      const lateMins = parseInt(teacher_late_mins) || 0;
      const tExists: any = await query(
        "SELECT id FROM teacher_period_attendance WHERE teacher_id = ? AND date = ? AND period_no = ? AND class_id = ?",
        [teacher_id, date, period_no, class_id]
      );

      if (tExists.length > 0) {
        await query(
          "UPDATE teacher_period_attendance SET status = ?, late_minutes = ? WHERE id = ?",
          [teacher_status, lateMins, tExists[0].id]
        );
      } else {
        await query(
          "INSERT INTO teacher_period_attendance (teacher_id, class_id, date, period_no, status, late_minutes, remarks) VALUES (?, ?, ?, ?, ?, ?, '')",
          [teacher_id, class_id, date, period_no, teacher_status, lateMins]
        );
      }

      // 3. Sync Daily Teacher Summary
      const allPeriods: any = await query(
        "SELECT status, late_minutes FROM teacher_period_attendance WHERE teacher_id = ? AND date = ?",
        [teacher_id, date]
      );
      
      let dailyStatus = 'A';
      let dailyLate = 0;
      for (const p of allPeriods) {
        if (p.status === 'P' || p.status === 'حاضر') {
          dailyStatus = 'P';
        } else if (p.status === 'L' || p.status === 'رخصت') {
          if (dailyStatus !== 'P') dailyStatus = 'L';
        }
        if (p.late_minutes > dailyLate) {
          dailyLate = p.late_minutes; // Store maximum late minutes of the day
        }
      }

      const dailyExists: any = await query(
        "SELECT id FROM attendance_teachers WHERE teacher_id = ? AND date = ?",
        [teacher_id, date]
      );

      if (dailyExists.length > 0) {
        await query(
          "UPDATE attendance_teachers SET status = ?, late_minutes = ? WHERE id = ?",
          [dailyStatus, dailyLate, dailyExists[0].id]
        );
      } else {
        await query(
          "INSERT INTO attendance_teachers (teacher_id, date, status, late_minutes, remarks) VALUES (?, ?, ?, ?, '')",
          [teacher_id, date, dailyStatus, dailyLate]
        );
      }
    }

    return NextResponse.json({ success: true, message: 'Attendance saved successfully' });
  } catch (error: any) {
    return NextResponse.json({ success: false, message: error.message }, { status: 500 });
  }
}
