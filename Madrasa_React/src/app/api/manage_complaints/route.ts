import { NextResponse } from 'next/server';
import { query } from '@/lib/db';

export async function GET(request: Request) {
    try {
        const url = new URL(request.url);
        
        // Fetch admin complaints from 'complaints' table
        const adminComplaints: any = await query(`
            SELECT c.id, c.date, c.complaint as description, s.name as student_name, s.admission_number
            FROM complaints c
            JOIN students s ON c.student_id = s.id
            ORDER BY c.date DESC, c.id DESC
        `);

        return NextResponse.json({ success: true, data: adminComplaints });
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

        await query('DELETE FROM complaints WHERE id = ?', [id]);
        return NextResponse.json({ success: true });
    } catch(error: any) {
        return NextResponse.json({ success: false, message: error.message }, { status: 500 });
    }
}
