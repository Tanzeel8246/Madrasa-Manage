import { NextResponse } from 'next/server';
import { query } from '@/lib/db';

export async function GET(request: Request) {
    try {
        const complaints: any = await query(`
            SELECT c.id, c.date, c.category, c.complaint as description, c.status, s.name as student_name
            FROM parent_complaints c
            JOIN students s ON c.student_id = s.id
            ORDER BY FIELD(c.status, 'Pending', 'Viewed'), c.date DESC
        `);

        const leaves: any = await query(`
            SELECT l.id, l.date_from, l.date_to, l.reason, l.status, l.created_at, s.name as student_name
            FROM leave_applications l
            JOIN students s ON l.student_id = s.id
            ORDER BY FIELD(l.status, 'Pending', 'Approved', 'Rejected'), l.created_at DESC
        `);

        const fees: any = await query(`
            SELECT f.id, f.amount, f.description, f.screenshot, f.status, f.submission_date, f.finance_id, s.name as student_name, h.name as head_name
            FROM fee_submissions f
            JOIN students s ON f.student_id = s.id
            LEFT JOIN heads h ON f.head_id = h.id
            ORDER BY FIELD(f.status, 'Pending', 'Approved', 'Rejected'), f.submission_date DESC
        `);

        return NextResponse.json({ 
            success: true, 
            data: {
                complaints,
                leaves,
                fees
            } 
        });
    } catch (error: any) {
        return NextResponse.json({ success: false, message: error.message }, { status: 500 });
    }
}

export async function DELETE(request: Request) {
    try {
        const url = new URL(request.url);
        const id = url.searchParams.get('id');
        const type = url.searchParams.get('type'); // 'complaint', 'leave', 'fee'

        if (!id || !type) {
            return NextResponse.json({ success: false, message: 'ID and Type are required' }, { status: 400 });
        }

        if (type === 'complaint') {
            await query('DELETE FROM parent_complaints WHERE id = ?', [id]);
        } else if (type === 'leave') {
            await query('DELETE FROM leave_applications WHERE id = ?', [id]);
        } else if (type === 'fee') {
            await query('DELETE FROM fee_submissions WHERE id = ?', [id]);
        }

        return NextResponse.json({ success: true });
    } catch(error: any) {
        return NextResponse.json({ success: false, message: error.message }, { status: 500 });
    }
}

export async function PUT(request: Request) {
    try {
        const body = await request.json();
        const { id, type, status } = body;

        if (!id || !type || !status) {
            return NextResponse.json({ success: false, message: 'ID, Type and Status are required' }, { status: 400 });
        }

        if (type === 'complaint') {
            await query('UPDATE parent_complaints SET status = ? WHERE id = ?', [status, id]);
        } else if (type === 'leave') {
            await query('UPDATE leave_applications SET status = ? WHERE id = ?', [status, id]);
        } else if (type === 'fee') {
            if (status === 'Approved') {
                // If fee is approved, insert into finance table (simplified logic from old system)
                const f: any = await query('SELECT f.*, s.name FROM fee_submissions f JOIN students s ON f.student_id = s.id WHERE f.id = ?', [id]);
                if (f.length > 0) {
                    const feeRow = f[0];
                    const desc = feeRow.description ? feeRow.description + ` (آن لائن ID: ${id})` : `Online Fee (ID: ${id})`;
                    
                    // Note: We skip generating computer_receipt_no for now to avoid complexity, or leave it blank
                    const insertRes: any = await query(
                        `INSERT INTO finance (date, type, amount, description, donor_name, head_id, user_id, user_name) 
                          VALUES (CURDATE(), 'Income', ?, ?, ?, ?, 1, 'Admin')`,
                        [feeRow.amount, desc, feeRow.name, feeRow.head_id]
                    );
                    
                    await query('UPDATE fee_submissions SET status = ?, finance_id = ? WHERE id = ?', [status, insertRes.insertId, id]);
                }
            } else {
                await query('UPDATE fee_submissions SET status = ? WHERE id = ?', [status, id]);
            }
        }

        return NextResponse.json({ success: true });
    } catch(error: any) {
        return NextResponse.json({ success: false, message: error.message }, { status: 500 });
    }
}
