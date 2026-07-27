import { NextResponse } from 'next/server';
import { query } from '@/lib/db';

export async function POST(request: Request) {
    try {
        const body = await request.json();
        const { student_id, amount, head_id, description, screenshot } = body;

        if (!student_id || !amount) {
            return NextResponse.json({ success: false, message: 'طالب علم کی آئی ڈی اور رقم لازمی ہے' }, { status: 400 });
        }

        await query(
            'INSERT INTO fee_submissions (student_id, head_id, amount, description, screenshot, status, submission_date) VALUES (?, ?, ?, ?, ?, "Pending", NOW())', 
            [student_id, head_id || null, amount, description || '', screenshot || '']
        );

        return NextResponse.json({ success: true, message: 'فیس / تعاون کی تفصیلات جمع کر دی گئی ہیں' });
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

        const fees = await query(
            'SELECT f.*, h.name as head_name FROM fee_submissions f LEFT JOIN heads h ON f.head_id = h.id WHERE f.student_id = ? ORDER BY f.submission_date DESC',
            [student_id]
        );

        return NextResponse.json({ success: true, data: fees });
    } catch(error: any) {
        return NextResponse.json({ success: false, message: error.message }, { status: 500 });
    }
}
