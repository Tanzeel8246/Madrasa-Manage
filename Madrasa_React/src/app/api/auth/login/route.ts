import { NextResponse } from 'next/server';
import { query } from '@/lib/db';
import bcrypt from 'bcryptjs';

export async function POST(request: Request) {
  try {
    const { username, password, madrasaId } = await request.json();

    if (!username || !password) {
      return NextResponse.json({ success: false, message: 'Username and password are required' }, { status: 400 });
    }

    // Connect to the specific Madrasa tenant. 
    // For now, since we are using a shared database approach or migrating the first DB,
    // we just use the global pool which connects to 'mamfss_madrasa'.
    
    // Check user in the admins table
    const rows = await query('SELECT * FROM admins WHERE username = ?', [username]) as any[];

    if (rows.length > 0) {
      const admin = rows[0];
      
      // Verify password
      const isMatch = bcrypt.compareSync(password, admin.password);
      
      if (isMatch) {
        const { password: _, ...safeAdmin } = admin;
        return NextResponse.json({ success: true, user: safeAdmin, token: 'mock-jwt-token' });
      } else {
        return NextResponse.json({ success: false, message: 'غلط پاسورڈ!' }, { status: 401 });
      }
    } else {
      // 2. Check in students table for parent login (admission_number = username)
      const studentRows = await query('SELECT * FROM students WHERE admission_number = ? AND is_deleted = 0', [username]) as any[];
      if (studentRows.length > 0) {
        const student = studentRows[0];
        
        // In the legacy system, verify_pass was used.
        // We'll assume the student password column contains a bcrypt hash or plain text.
        // If it's empty or null, we might need a default or block them.
        let isMatch = false;
        if (student.password) {
            // Compare bcrypt hash
            try {
                isMatch = bcrypt.compareSync(password, student.password);
            } catch (e) {
                // If it's plain text (from older migrations)
                isMatch = (password === student.password);
            }
        } else {
            // Default password is '123456'
            isMatch = (password === '123456');
        }

        if (isMatch) {
          const parentUser = {
            id: student.id,
            name: student.name,
            role: 'parent',
            adm_no: student.admission_number,
            madrasa_id: student.madrasa_id
          };
          return NextResponse.json({ success: true, user: parentUser, token: 'mock-jwt-parent' });
        } else {
          return NextResponse.json({ success: false, message: 'غلط پاسورڈ!' }, { status: 401 });
        }
      }

      return NextResponse.json({ success: false, message: 'یوزر نیم موجود نہیں ہے!' }, { status: 401 });
    }

  } catch (error: any) {
    console.error('Login error:', error);
    return NextResponse.json({ success: false, message: 'Internal server error: ' + error.message }, { status: 500 });
  }
}
