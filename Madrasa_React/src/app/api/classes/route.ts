import { NextResponse } from 'next/server';
import { query } from '@/lib/db';

export async function GET(request: Request) {
  try {
    // Fetch all classes
    const classes = await query('SELECT * FROM classes ORDER BY id ASC');
    
    // Fetch all class periods
    const periods = await query('SELECT * FROM class_periods ORDER BY class_id, period_no');
    
    // Group periods by class_id
    const periodsByClass: Record<number, any[]> = {};
    (periods as any[]).forEach(p => {
      if (!periodsByClass[p.class_id]) periodsByClass[p.class_id] = [];
      periodsByClass[p.class_id].push(p);
    });

    // Attach periods to classes
    const classesWithPeriods = (classes as any[]).map(cls => ({
      ...cls,
      periods: periodsByClass[cls.id] || []
    }));

    return NextResponse.json({ success: true, data: classesWithPeriods });
  } catch (error: any) {
    return NextResponse.json({ success: false, message: error.message }, { status: 500 });
  }
}

export async function POST(request: Request) {
  try {
    const data = await request.json();
    
    // 1. Insert into classes
    const classSql = `INSERT INTO classes (name, section, class_type, main_teacher_ids, subjects_list) VALUES (?, ?, ?, ?, ?)`;
    const classValues = [
      data.name,
      data.section || '',
      data.class_type || 'Darse Nizami / Other',
      data.main_teacher_ids ? JSON.stringify(data.main_teacher_ids) : '[]',
      data.subjects_list || ''
    ];
    
    const classResult: any = await query(classSql, classValues);
    const classId = classResult.insertId;

    // 2. Insert into class_periods
    if (data.periods && Array.isArray(data.periods)) {
      for (const p of data.periods) {
        if (p.books || (p.teacher_ids && p.teacher_ids.length > 0)) {
          const pSql = `INSERT INTO class_periods (class_id, period_no, books, teacher_ids) VALUES (?, ?, ?, ?)`;
          const pValues = [
            classId,
            p.period_no,
            p.books || '',
            p.teacher_ids ? JSON.stringify(p.teacher_ids) : '[]'
          ];
          await query(pSql, pValues);
        }
      }
    }

    return NextResponse.json({ success: true, message: 'Class added successfully', id: classId });
  } catch (error: any) {
    return NextResponse.json({ success: false, message: error.message }, { status: 500 });
  }
}

export async function PUT(request: Request) {
  try {
    const data = await request.json();
    const id = data.id;

    if (!id) {
      return NextResponse.json({ success: false, message: 'Class ID is required' }, { status: 400 });
    }
    
    // 1. Update classes table
    const classSql = `UPDATE classes SET name=?, section=?, class_type=?, main_teacher_ids=?, subjects_list=? WHERE id=?`;
    const classValues = [
      data.name,
      data.section || '',
      data.class_type || 'Darse Nizami / Other',
      data.main_teacher_ids ? JSON.stringify(data.main_teacher_ids) : '[]',
      data.subjects_list || '',
      id
    ];
    await query(classSql, classValues);

    // 2. Delete existing periods and recreate them
    await query('DELETE FROM class_periods WHERE class_id = ?', [id]);

    if (data.periods && Array.isArray(data.periods)) {
      for (const p of data.periods) {
        if (p.books || (p.teacher_ids && p.teacher_ids.length > 0)) {
          const pSql = `INSERT INTO class_periods (class_id, period_no, books, teacher_ids) VALUES (?, ?, ?, ?)`;
          const pValues = [
            id,
            p.period_no,
            p.books || '',
            p.teacher_ids ? JSON.stringify(p.teacher_ids) : '[]'
          ];
          await query(pSql, pValues);
        }
      }
    }

    return NextResponse.json({ success: true, message: 'Class updated successfully' });
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

    // Deleting from classes will cascade delete class_periods if FOREIGN KEY constraints are set,
    // but just to be safe:
    await query('DELETE FROM class_periods WHERE class_id = ?', [id]);
    await query('DELETE FROM classes WHERE id = ?', [id]);
    
    return NextResponse.json({ success: true, message: 'Class deleted successfully' });
  } catch (error: any) {
    return NextResponse.json({ success: false, message: error.message }, { status: 500 });
  }
}
