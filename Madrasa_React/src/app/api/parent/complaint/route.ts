import { NextResponse } from 'next/server';
import { query } from '@/lib/db';

export async function POST(request: Request) {
    try {
        const body = await request.json();
        const { student_id, category, description } = body;

        if (!student_id || !category || !description) {
            return NextResponse.json({ success: false, message: 'تمام خانے پر کرنا لازمی ہے' }, { status: 400 });
        }

        await query(
            'INSERT INTO parent_complaints (student_id, category, complaint, status, date) VALUES (?, ?, ?, "Pending", CURDATE())', 
            [student_id, category, description]
        );

        return NextResponse.json({ success: true, message: 'آپ کی شکایت بھیج دی گئی ہے' });
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

        const complaints = await query(
            'SELECT * FROM parent_complaints WHERE student_id = ? ORDER BY date DESC',
            [student_id]
        );

        return NextResponse.json({ success: true, data: complaints });
    } catch(error: any) {
        return NextResponse.json({ success: false, message: error.message }, { status: 500 });
    }
}
