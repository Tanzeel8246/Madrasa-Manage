import { NextResponse } from 'next/server';
import { query } from '@/lib/db';

export async function POST(request: Request) {
    try {
        const body = await request.json();
        const { student_id, date_from, date_to, reason } = body;

        if (!student_id || !date_from || !date_to || !reason) {
            return NextResponse.json({ success: false, message: 'تمام خانے پر کرنا لازمی ہے' }, { status: 400 });
        }

        await query(
            'INSERT INTO leave_applications (student_id, date_from, date_to, reason, status, created_at) VALUES (?, ?, ?, ?, "Pending", NOW())', 
            [student_id, date_from, date_to, reason]
        );

        return NextResponse.json({ success: true, message: 'چھٹی کی درخواست جمع کر دی گئی ہے' });
    } catch(error: any) {
        return NextResponse.json({ success: false, message: error.message }, { status: 500 });
    }
}

export async function GET(request: Request) {
    try {
        const url = new URL(request.url);
        const student_id = url.searchParams.get('student_id');

        if (!student_id) {
            return NextResponse.json({ success: false, message: 'طالب علم کی آئی ڈی درکار ہے' }, { status: 400 });
        }

        const leaves = await query(
            'SELECT * FROM leave_applications WHERE student_id = ? ORDER BY created_at DESC',
            [student_id]
        );

        return NextResponse.json({ success: true, data: leaves });
    } catch(error: any) {
        return NextResponse.json({ success: false, message: error.message }, { status: 500 });
    }
}
