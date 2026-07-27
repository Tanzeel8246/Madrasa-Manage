import { NextResponse } from 'next/server';
import { query } from '@/lib/db';

export async function GET(request: Request) {
    try {
        const url = new URL(request.url);
        const student_id = url.searchParams.get('student_id');

        if (!student_id) {
            return NextResponse.json({ success: false, message: 'طالب علم کی آئی ڈی درکار ہے' }, { status: 400 });
        }

        // Fetch Student Info
        const students = await query('SELECT * FROM students WHERE id = ?', [student_id]) as any[];
        const student = students.length > 0 ? students[0] : null;

        // Fetch Recent Attendance (Last 30 Days)
        const attendance = await query(
            'SELECT * FROM attendance WHERE student_id = ? ORDER BY date DESC LIMIT 30',
            [student_id]
        ) as any[];

        // Note: Academic records (Hifz/Nazira) and Exams will be added here in Phase 3 & 4.
        
        return NextResponse.json({ 
            success: true, 
            data: {
                student,
                attendance,
                // academics: [],
                // exams: []
            } 
        });
    } catch(error: any) {
        return NextResponse.json({ success: false, message: error.message }, { status: 500 });
    }
}
