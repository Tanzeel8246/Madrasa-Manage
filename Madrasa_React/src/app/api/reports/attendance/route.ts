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
    const studentId = url.searchParams.get('student_id');

    if (!month || !year) {
      return NextResponse.json({ success: false, message: 'Missing month or year' }, { status: 400 });
    }

    // Determine start and end dates
    const startDate = `${year}-${month.padStart(2, '0')}-01`;
    // Last day of month
    const endDateObj = new Date(Number(year), Number(month), 0);
    const endDate = `${year}-${month.padStart(2, '0')}-${endDateObj.getDate().toString().padStart(2, '0')}`;

    // Get all dates in range
    const dates = [];
    for (let d = 1; d <= endDateObj.getDate(); d++) {
      dates.push(`${year}-${month.padStart(2, '0')}-${d.toString().padStart(2, '0')}`);
    }

    // Fetch Students
    let stdQuery = `SELECT id, name, father_name, admission_number, class as className FROM students WHERE (status='Active' OR status='Present') AND is_deleted=0`;
    let stdParams: any[] = [];
    if (studentId) {
      stdQuery += ` AND id = ?`;
      stdParams.push(studentId);
    }
    stdQuery += ` ORDER BY class ASC, name ASC`;
    const students: any = await query(stdQuery, stdParams);

    // Group students by class
    const studentsByClass: Record<string, any[]> = {};
    for (const s of students) {
      const c = s.className || 'دیگر';
      if (!studentsByClass[c]) studentsByClass[c] = [];
      studentsByClass[c].push(s);
    }

    // Fetch Period Attendance for these dates
    let paQuery = `SELECT student_id, date, period_num, status, remarks FROM period_attendance WHERE date BETWEEN ? AND ?`;
    let paParams: any[] = [startDate, endDate];
    if (studentId) {
       paQuery += ` AND student_id = ?`;
       paParams.push(studentId);
    }
    const pAtt: any = await query(paQuery, paParams);

    // Map pAtt to [student_id][date][period_num]
    const pAttMap: any = {};
    for (const row of pAtt) {
       if (!pAttMap[row.student_id]) pAttMap[row.student_id] = {};
       const dString = formatDate(row.date);
       if (!pAttMap[row.student_id][dString]) pAttMap[row.student_id][dString] = {};
       pAttMap[row.student_id][dString][row.period_num] = {
           status: row.status,
           late: parseInt(row.remarks) || 0
       };
    }

    // Fetch Teachers to get their names
    const teachersList: any = await query('SELECT id, name FROM teachers');
    const teacherNameMap: any = {};
    for (const t of teachersList) {
       teacherNameMap[t.id] = t.name;
    }

    // Fetch Classes to get assigned teachers
    const classList: any = await query('SELECT name, main_teacher_ids FROM classes');
    const classAssignedTeachers: any = {};
    for (const c of classList) {
        let tIds: number[] = [];
        if (c.main_teacher_ids) {
            try {
                const parsed = JSON.parse(c.main_teacher_ids);
                if (Array.isArray(parsed)) tIds = parsed.map((id: any) => parseInt(id));
            } catch(e) {
                tIds = c.main_teacher_ids.split(',').map((id: any) => parseInt(id)).filter((id: number) => !isNaN(id));
            }
        }
        classAssignedTeachers[c.name] = tIds;
    }

    // Fetch Teacher Attendance
    const tAtt: any = await query(
      `SELECT t.teacher_id, t.class_id, c.name as className, t.date, t.period_no, t.status, t.late_minutes 
       FROM teacher_period_attendance t
       LEFT JOIN classes c ON t.class_id = c.id
       WHERE t.date BETWEEN ? AND ?`,
      [startDate, endDate]
    );

    const tAttMap: any = {}; // Map: className -> teacher_id -> date -> period -> status
    for (const row of tAtt) {
       const dString = formatDate(row.date);
       const cName = row.className || row.class_id;
       const tId = row.teacher_id;
       
       if (!tAttMap[cName]) tAttMap[cName] = {};
       if (!tAttMap[cName][tId]) tAttMap[cName][tId] = {};
       if (!tAttMap[cName][tId][dString]) tAttMap[cName][tId][dString] = {};
       
       tAttMap[cName][tId][dString][row.period_no] = {
           status: row.status,
           late: row.late_minutes
       };
    }

    // Build Final Structure
    const reportData = [];
    for (const className of Object.keys(studentsByClass)) {
       const classStudents = studentsByClass[className];
       
       const typeStr = className.toLowerCase();
       let periods = [1,2,3,4,5,6,7,8];
       if (typeStr.includes('hifz') || typeStr.includes('حفظ') || typeStr.includes('gardan') || typeStr.includes('گردان')) periods = [1,2,3,4];
       else if (typeStr.includes('nazira') || typeStr.includes('ناظرہ')) periods = [1,2];

       // Build teachers array for this class
       const classTeachersMap = tAttMap[className] || {};
       const assignedIds = classAssignedTeachers[className] || [];
       
       // Get all unique teacher IDs (assigned + those who marked attendance)
       const allTeacherIds = new Set([...assignedIds, ...Object.keys(classTeachersMap).map(id => parseInt(id))]);
       
       const classTeachers = Array.from(allTeacherIds).map(tId => {
           return {
               id: tId,
               name: teacherNameMap[tId] || `Teacher ${tId}`,
               attendance: classTeachersMap[tId] || {}
           };
       });

       const clsData = {
           className,
           periods,
           teachers: classTeachers,
           students: classStudents.map((s: any) => ({
               id: s.id,
               name: s.name,
               father_name: s.father_name,
               attendance: pAttMap[s.id] || {}
           }))
       };
       reportData.push(clsData);
    }

    return NextResponse.json({ success: true, dates, data: reportData });
  } catch (error: any) {
    return NextResponse.json({ success: false, message: error.message }, { status: 500 });
  }
}
