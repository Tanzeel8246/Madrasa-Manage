import i18n from 'i18next';
import { initReactI18next } from 'react-i18next';

const resources = {
  en: {
    translation: {
      // Navigation
      dashboard: 'Dashboard',
      students: 'Students',
      teachers: 'Teachers',
      classes: 'Classes',
      attendance: 'Attendance',
      courses: 'Courses',
      learningReport: 'Learning Report',
      fees: 'Fees',
      userRoles: 'User Roles',
      
      // Common
      add: 'Add',
      edit: 'Edit',
      delete: 'Delete',
      cancel: 'Cancel',
      save: 'Save',
      search: 'Search',
      filter: 'Filter',
      export: 'Export',
      myAccount: 'My Account',
      signOut: 'Sign Out',
      admin: 'Admin',
      notifications: 'Notifications',
      noNewNotifications: 'No new notifications',
      pendingJoinRequests: 'pending join requests',
      viewAllRequests: 'View All Requests',
      adminUser: 'Admin User',
      notificationCount: '{{count}} pending requests',
      viewPendingRequests: 'View Pending Requests',
      noPendingRequests: 'No pending requests',
      manageAccountSettings: 'Manage your account settings and madrasa information',
      profileInformation: 'Profile Information',
      updateProfileDetails: 'Update your personal information',
      emailCannotBeChanged: 'Email cannot be changed',
      fullName: 'Full Name',
      enterFullName: 'Enter your full name',
      saveChanges: 'Save Changes',
      madrasaInformation: 'Madrasa Information',
      manageMadrasaDetails: 'Manage your madrasa details and branding',
      madrasaName: 'Madrasa Name',
      enterMadrasaName: 'Enter madrasa name',
      madrasaLogo: 'Madrasa Logo',
      uploadLogo: 'Upload Logo',
      logoRequirements: 'PNG, JPG up to 5MB. Recommended 200x200px',
      logoUpdated: 'Logo updated successfully!',
      profileUpdated: 'Profile updated successfully!',
      teacher: 'Teacher',
      actions: 'Actions',
      view: 'View',
      back: 'Back',
      next: 'Next',
      submit: 'Submit',
      close: 'Close',
      loading: 'Loading...',
      noData: 'No data available',
      
      // Header
      searchPlaceholder: 'Search students, teachers, classes...',
      language: 'Language',
      
      // Branding
      appTitle: 'Madrasa',
      appSubtitle: 'Management Kit',
      
      // Dashboard
      totalStudents: 'Total Students',
      totalTeachers: 'Total Teachers',
      totalClasses: 'Total Classes',
      activeStudents: 'Active Students',
      todayAttendance: 'Today\'s Attendance',
      pendingFees: 'Pending Fees',
      overview: 'Overview',
      
      // Student fields
      name: 'Name',
      fatherName: "Father's Name",
      class: 'Class',
      admissionDate: 'Admission Date',
      contact: 'Contact',
      age: 'Age',
      grade: 'Grade',
      status: 'Status',
      photo: 'Photo',
      email: 'Email',
      
      // Teacher fields
      qualification: 'Qualification',
      subject: 'Subject',
      specialization: 'Specialization',
      
      // Class fields
      room: 'Room',
      schedule: 'Schedule',
      duration: 'Duration',
      level: 'Level',
      year: 'Year',
      section: 'Section',
      
      // Attendance
      present: 'Present',
      absent: 'Absent',
      late: 'Late',
      leave: 'Leave',
      date: 'Date',
      time: 'Time',
      markAttendance: 'Mark Attendance',
      
      // Fees
      amount: 'Amount',
      dueDate: 'Due Date',
      paid: 'Paid',
      pending: 'Pending',
      feeType: 'Fee Type',
      academicYear: 'Academic Year',
      paymentScreenshot: 'Payment Screenshot',
      
      // Education Reports
      sabak: 'Sabak (New Lesson)',
      sabqi: 'Sabqi (Revision)',
      manzil: 'Manzil',
      remarks: 'Remarks',
      paraNo: 'Para Number',
      recited: 'Recited',
      heardBy: 'Heard By',
      
      // User Roles
      role: 'Role',
      assignRole: 'Assign Role',
      inviteUser: 'Invite User',
      
      // Forms
      requiredField: 'This field is required',
      invalidEmail: 'Invalid email address',
      selectOption: 'Select an option',
      
      // Messages
      success: 'Success',
      error: 'Error',
      warning: 'Warning',
      confirmDelete: 'Are you sure you want to delete this?',
    }
  },
  ur: {
    translation: {
      // Navigation
      dashboard: 'ڈیش بورڈ',
      students: 'طلباء',
      teachers: 'اساتذہ',
      classes: 'کلاسز',
      attendance: 'حاضری',
      courses: 'کورسز',
      learningReport: 'تعلیمی رپورٹ',
      fees: 'فیسیں',
      userRoles: 'صارف کے کردار',
      
      // Common
      add: 'شامل کریں',
      edit: 'ترمیم',
      delete: 'حذف کریں',
      cancel: 'منسوخ',
      save: 'محفوظ کریں',
      search: 'تلاش کریں',
      filter: 'فلٹر',
      export: 'ایکسپورٹ',
      myAccount: 'میرا اکاؤنٹ',
      signOut: 'سائن آؤٹ',
      admin: 'ایڈمن',
      notifications: 'اطلاعات',
      noNewNotifications: 'کوئی نئی اطلاع نہیں',
      pendingJoinRequests: 'زیر التوا درخواستیں',
      viewAllRequests: 'تمام درخواستیں دیکھیں',
      adminUser: 'ایڈمن صارف',
      notificationCount: '{{count}} زیر التوا درخواستیں',
      viewPendingRequests: 'زیر التوا درخواستیں دیکھیں',
      noPendingRequests: 'کوئی زیر التوا درخواست نہیں',
      manageAccountSettings: 'اپنے اکاؤنٹ کی ترتیبات اور مدرسہ کی معلومات کا انتظام کریں',
      profileInformation: 'پروفائل کی معلومات',
      updateProfileDetails: 'اپنی ذاتی معلومات کو اپ ڈیٹ کریں',
      emailCannotBeChanged: 'ای میل تبدیل نہیں کیا جا سکتا',
      fullName: 'پورا نام',
      enterFullName: 'اپنا پورا نام درج کریں',
      saveChanges: 'تبدیلیاں محفوظ کریں',
      madrasaInformation: 'مدرسہ کی معلومات',
      manageMadrasaDetails: 'اپنے مدرسہ کی تفصیلات اور برانڈنگ کا انتظام کریں',
      madrasaName: 'مدرسہ کا نام',
      enterMadrasaName: 'مدرسہ کا نام درج کریں',
      madrasaLogo: 'مدرسہ کا لوگو',
      uploadLogo: 'لوگو اپ لوڈ کریں',
      logoRequirements: 'PNG، JPG 5MB تک۔ تجویز کردہ 200x200px',
      logoUpdated: 'لوگو کامیابی سے اپ ڈیٹ ہو گیا!',
      profileUpdated: 'پروفائل کامیابی سے اپ ڈیٹ ہو گیا!',
      teacher: 'استاد',
      actions: 'اقدامات',
      view: 'دیکھیں',
      back: 'واپس',
      next: 'اگلا',
      submit: 'جمع کرائیں',
      close: 'بند کریں',
      loading: 'لوڈ ہو رہا ہے...',
      noData: 'کوئی ڈیٹا دستیاب نہیں',
      
      // Header
      searchPlaceholder: 'طلباء، اساتذہ، کلاسز تلاش کریں...',
      language: 'زبان',
      
      // Branding
      appTitle: 'مدرسہ',
      appSubtitle: 'مینجمنٹ کٹ',
      
      // Dashboard
      totalStudents: 'کل طلباء',
      totalTeachers: 'کل اساتذہ',
      totalClasses: 'کل کلاسز',
      activeStudents: 'فعال طلباء',
      todayAttendance: 'آج کی حاضری',
      pendingFees: 'باقی فیسیں',
      overview: 'جائزہ',
      
      // Student fields
      name: 'نام',
      fatherName: 'والد کا نام',
      class: 'کلاس',
      admissionDate: 'داخلے کی تاریخ',
      contact: 'رابطہ',
      age: 'عمر',
      grade: 'درجہ',
      status: 'حیثیت',
      photo: 'تصویر',
      email: 'ای میل',
      
      // Teacher fields
      qualification: 'قابلیت',
      subject: 'مضمون',
      specialization: 'خصوصیت',
      
      // Class fields
      room: 'کمرہ',
      schedule: 'شیڈول',
      duration: 'دورانیہ',
      level: 'سطح',
      year: 'سال',
      section: 'سیکشن',
      
      // Attendance
      present: 'حاضر',
      absent: 'غیر حاضر',
      late: 'تاخیر',
      leave: 'چھٹی',
      date: 'تاریخ',
      time: 'وقت',
      markAttendance: 'حاضری لگائیں',
      
      // Fees
      amount: 'رقم',
      dueDate: 'آخری تاریخ',
      paid: 'ادا شدہ',
      pending: 'باقی',
      feeType: 'فیس کی قسم',
      academicYear: 'تعلیمی سال',
      paymentScreenshot: 'ادائیگی کی تصویر',
      
      // Education Reports
      sabak: 'سبق (نیا سبق)',
      sabqi: 'سبقی (دہرائی)',
      manzil: 'منزل',
      remarks: 'تبصرے',
      paraNo: 'پارہ نمبر',
      recited: 'سنایا',
      heardBy: 'سننے والا',
      
      // User Roles
      role: 'کردار',
      assignRole: 'کردار تفویض کریں',
      inviteUser: 'صارف کو مدعو کریں',
      
      // Forms
      requiredField: 'یہ فیلڈ ضروری ہے',
      invalidEmail: 'غلط ای میل پتہ',
      selectOption: 'ایک آپشن منتخب کریں',
      
      // Messages
      success: 'کامیابی',
      error: 'خرابی',
      warning: 'انتباہ',
      confirmDelete: 'کیا آپ واقعی اسے حذف کرنا چاہتے ہیں؟',
    }
  }
};

i18n
  .use(initReactI18next)
  .init({
    resources,
    lng: 'en',
    fallbackLng: 'en',
    interpolation: {
      escapeValue: false
    }
  });

export default i18n;