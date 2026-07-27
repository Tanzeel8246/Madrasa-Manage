import { query } from '@/lib/db';
import { NextResponse } from 'next/server';

export async function GET() {
  try {
    const totalStudentsData: any = await query("SELECT COUNT(*) as count FROM students WHERE is_deleted=0 AND (status='Active' OR status='' OR status IS NULL)");
    const totalTeachersData: any = await query("SELECT COUNT(*) as count FROM teachers WHERE is_deleted=0 AND (status='Active' OR status='' OR status IS NULL)");
    
    // Today's attendance percentage
    const today = new Date().toISOString().split('T')[0];
    const attendanceData: any = await query(`
      SELECT status_1, status_2, status_3, status_4 
      FROM attendance 
      WHERE date = ? AND is_deleted=0
    `, [today]);

    let today_total = 0;
    let today_present = 0;

    for (const att of attendanceData) {
      for (let i = 1; i <= 4; i++) {
        const status = (att[`status_${i}`] || '').trim().toUpperCase();
        if (!status) continue;
        today_total++;
        if (status === 'P' || status === 'PRESENT') {
          today_present++;
        }
      }
    }
    const attendancePercent = today_total > 0 ? Math.round((today_present / today_total) * 100) : 0;

    // Monthly Income
    const firstDay = new Date();
    firstDay.setDate(1);
    const firstDayStr = firstDay.toISOString().split('T')[0];

    // Assuming we have an income table or finance table, we will mock or query it.
    // Wait, the legacy used `acc_receipts` or `finance`. Let's query `finance` for income.
    const incomeData: any = await query("SELECT SUM(amount) as total FROM finance WHERE LOWER(type)='income' AND is_deleted=0 AND date >= ?", [firstDayStr]);
    const monthlyIncome = incomeData[0]?.total || 0;

    // Recent Activities (Mix of recent complaints, and recent notices)
    const recentActivities = [];

    const recentComplaints: any = await query(`
      SELECT c.date, c.complaint, s.name as user, 'Complaint' as type 
      FROM complaints c 
      JOIN students s ON c.student_id = s.id 
      WHERE c.is_deleted=0 
      ORDER BY c.date DESC, c.id DESC LIMIT 3
    `);

    for (const c of recentComplaints) {
      recentActivities.push({
        title: 'نئی شکایت / نوٹ درج کیا گیا',
        time: new Date(c.date).toLocaleDateString('en-GB'),
        user: c.user
      });
    }

    const recentAdmissions: any = await query(`
      SELECT admission_date, name 
      FROM students 
      WHERE is_deleted=0 
      ORDER BY id DESC LIMIT 2
    `);

    for (const s of recentAdmissions) {
      recentActivities.push({
        title: 'نئے طالب علم کا داخلہ',
        time: new Date(s.admission_date || new Date()).toLocaleDateString('en-GB'),
        user: s.name
      });
    }

    // Sort activities by time roughly (we don't have exact timestamps for all, but this is a mock representation)
    
    return NextResponse.json({
      success: true,
      data: {
        totalStudents: totalStudentsData[0]?.count || 0,
        totalTeachers: totalTeachersData[0]?.count || 0,
        attendancePercent: `${attendancePercent}%`,
        monthlyIncome: `${parseInt(monthlyIncome).toLocaleString()} روپئے`,
        recentActivities: recentActivities.slice(0, 4) // Return up to 4 recent activities
      }
    });

  } catch (error: any) {
    return NextResponse.json({ success: false, message: error.message }, { status: 500 });
  }
}
