export type Json =
  | string
  | number
  | boolean
  | null
  | { [key: string]: Json | undefined }
  | Json[]

export type Database = {
  // Allows to automatically instantiate createClient with right options
  // instead of createClient<Database, { PostgrestVersion: 'XX' }>(URL, KEY)
  __InternalSupabase: {
    PostgrestVersion: "13.0.5"
  }
  public: {
    Tables: {
      attendance: {
        Row: {
          class_id: string | null
          created_at: string
          date: string
          id: string
          madrasa_name: string | null
          noted_by: string | null
          status: string
          student_id: string | null
          time: string | null
        }
        Insert: {
          class_id?: string | null
          created_at?: string
          date?: string
          id?: string
          madrasa_name?: string | null
          noted_by?: string | null
          status: string
          student_id?: string | null
          time?: string | null
        }
        Update: {
          class_id?: string | null
          created_at?: string
          date?: string
          id?: string
          madrasa_name?: string | null
          noted_by?: string | null
          status?: string
          student_id?: string | null
          time?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "attendance_class_id_fkey"
            columns: ["class_id"]
            isOneToOne: false
            referencedRelation: "classes"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "attendance_student_id_fkey"
            columns: ["student_id"]
            isOneToOne: false
            referencedRelation: "students"
            referencedColumns: ["id"]
          },
        ]
      }
      classes: {
        Row: {
          created_at: string
          duration: string | null
          id: string
          level: string | null
          madrasa_name: string | null
          name: string
          room: string | null
          schedule: string | null
          section: string | null
          students_count: number | null
          teacher_id: string | null
          updated_at: string
          year: string | null
        }
        Insert: {
          created_at?: string
          duration?: string | null
          id?: string
          level?: string | null
          madrasa_name?: string | null
          name: string
          room?: string | null
          schedule?: string | null
          section?: string | null
          students_count?: number | null
          teacher_id?: string | null
          updated_at?: string
          year?: string | null
        }
        Update: {
          created_at?: string
          duration?: string | null
          id?: string
          level?: string | null
          madrasa_name?: string | null
          name?: string
          room?: string | null
          schedule?: string | null
          section?: string | null
          students_count?: number | null
          teacher_id?: string | null
          updated_at?: string
          year?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "classes_teacher_id_fkey"
            columns: ["teacher_id"]
            isOneToOne: false
            referencedRelation: "teachers"
            referencedColumns: ["id"]
          },
        ]
      }
      courses: {
        Row: {
          created_at: string
          description: string | null
          duration: string | null
          id: string
          level: string | null
          madrasa_name: string | null
          modules: number | null
          progress: number | null
          students_count: number | null
          title: string
          updated_at: string
        }
        Insert: {
          created_at?: string
          description?: string | null
          duration?: string | null
          id?: string
          level?: string | null
          madrasa_name?: string | null
          modules?: number | null
          progress?: number | null
          students_count?: number | null
          title: string
          updated_at?: string
        }
        Update: {
          created_at?: string
          description?: string | null
          duration?: string | null
          id?: string
          level?: string | null
          madrasa_name?: string | null
          modules?: number | null
          progress?: number | null
          students_count?: number | null
          title?: string
          updated_at?: string
        }
        Relationships: []
      }
      education_reports: {
        Row: {
          class_id: string | null
          created_at: string
          created_by: string | null
          date: string
          father_name: string
          id: string
          madrasa_name: string | null
          manzil: Json | null
          remarks: string | null
          sabak: Json | null
          sabqi: Json | null
          student_id: string
          updated_at: string
        }
        Insert: {
          class_id?: string | null
          created_at?: string
          created_by?: string | null
          date?: string
          father_name: string
          id?: string
          madrasa_name?: string | null
          manzil?: Json | null
          remarks?: string | null
          sabak?: Json | null
          sabqi?: Json | null
          student_id: string
          updated_at?: string
        }
        Update: {
          class_id?: string | null
          created_at?: string
          created_by?: string | null
          date?: string
          father_name?: string
          id?: string
          madrasa_name?: string | null
          manzil?: Json | null
          remarks?: string | null
          sabak?: Json | null
          sabqi?: Json | null
          student_id?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "education_reports_class_id_fkey"
            columns: ["class_id"]
            isOneToOne: false
            referencedRelation: "classes"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "education_reports_student_id_fkey"
            columns: ["student_id"]
            isOneToOne: false
            referencedRelation: "students"
            referencedColumns: ["id"]
          },
        ]
      }
      fees: {
        Row: {
          academic_year: string
          amount: number
          created_at: string | null
          created_by: string | null
          due_date: string
          fee_type: string
          id: string
          madrasa_name: string | null
          payment_screenshot_url: string | null
          status: string
          student_id: string
          updated_at: string | null
        }
        Insert: {
          academic_year: string
          amount: number
          created_at?: string | null
          created_by?: string | null
          due_date: string
          fee_type: string
          id?: string
          madrasa_name?: string | null
          payment_screenshot_url?: string | null
          status: string
          student_id: string
          updated_at?: string | null
        }
        Update: {
          academic_year?: string
          amount?: number
          created_at?: string | null
          created_by?: string | null
          due_date?: string
          fee_type?: string
          id?: string
          madrasa_name?: string | null
          payment_screenshot_url?: string | null
          status?: string
          student_id?: string
          updated_at?: string | null
        }
        Relationships: []
      }
      pending_user_roles: {
        Row: {
          created_at: string
          created_by: string | null
          email: string
          full_name: string | null
          id: string
          madrasa_name: string | null
          role: Database["public"]["Enums"]["app_role"]
        }
        Insert: {
          created_at?: string
          created_by?: string | null
          email: string
          full_name?: string | null
          id?: string
          madrasa_name?: string | null
          role: Database["public"]["Enums"]["app_role"]
        }
        Update: {
          created_at?: string
          created_by?: string | null
          email?: string
          full_name?: string | null
          id?: string
          madrasa_name?: string | null
          role?: Database["public"]["Enums"]["app_role"]
        }
        Relationships: []
      }
      profiles: {
        Row: {
          created_at: string
          full_name: string | null
          id: string
          logo_url: string | null
          madrasa_name: string | null
          updated_at: string
        }
        Insert: {
          created_at?: string
          full_name?: string | null
          id: string
          logo_url?: string | null
          madrasa_name?: string | null
          updated_at?: string
        }
        Update: {
          created_at?: string
          full_name?: string | null
          id?: string
          logo_url?: string | null
          madrasa_name?: string | null
          updated_at?: string
        }
        Relationships: []
      }
      students: {
        Row: {
          admission_date: string
          age: number | null
          class_id: string | null
          contact: string | null
          created_at: string
          father_name: string
          grade: string | null
          id: string
          madrasa_name: string | null
          name: string
          photo_url: string | null
          status: string
          updated_at: string
        }
        Insert: {
          admission_date?: string
          age?: number | null
          class_id?: string | null
          contact?: string | null
          created_at?: string
          father_name: string
          grade?: string | null
          id?: string
          madrasa_name?: string | null
          name: string
          photo_url?: string | null
          status?: string
          updated_at?: string
        }
        Update: {
          admission_date?: string
          age?: number | null
          class_id?: string | null
          contact?: string | null
          created_at?: string
          father_name?: string
          grade?: string | null
          id?: string
          madrasa_name?: string | null
          name?: string
          photo_url?: string | null
          status?: string
          updated_at?: string
        }
        Relationships: []
      }
      teachers: {
        Row: {
          classes_count: number | null
          contact: string
          created_at: string
          email: string
          id: string
          madrasa_name: string | null
          name: string
          qualification: string
          specialization: string | null
          students_count: number | null
          subject: string
          updated_at: string
        }
        Insert: {
          classes_count?: number | null
          contact: string
          created_at?: string
          email: string
          id?: string
          madrasa_name?: string | null
          name: string
          qualification: string
          specialization?: string | null
          students_count?: number | null
          subject: string
          updated_at?: string
        }
        Update: {
          classes_count?: number | null
          contact?: string
          created_at?: string
          email?: string
          id?: string
          madrasa_name?: string | null
          name?: string
          qualification?: string
          specialization?: string | null
          students_count?: number | null
          subject?: string
          updated_at?: string
        }
        Relationships: []
      }
      user_roles: {
        Row: {
          created_at: string
          id: string
          role: Database["public"]["Enums"]["app_role"]
          user_id: string
        }
        Insert: {
          created_at?: string
          id?: string
          role: Database["public"]["Enums"]["app_role"]
          user_id: string
        }
        Update: {
          created_at?: string
          id?: string
          role?: Database["public"]["Enums"]["app_role"]
          user_id?: string
        }
        Relationships: []
      }
    }
    Views: {
      [_ in never]: never
    }
    Functions: {
      has_role: {
        Args: {
          _role: Database["public"]["Enums"]["app_role"]
          _user_id: string
        }
        Returns: boolean
      }
    }
    Enums: {
      app_role: "admin" | "teacher" | "student" | "manager" | "parent"
    }
    CompositeTypes: {
      [_ in never]: never
    }
  }
}

type DatabaseWithoutInternals = Omit<Database, "__InternalSupabase">

type DefaultSchema = DatabaseWithoutInternals[Extract<keyof Database, "public">]

export type Tables<
  DefaultSchemaTableNameOrOptions extends
    | keyof (DefaultSchema["Tables"] & DefaultSchema["Views"])
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof (DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"] &
        DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Views"])
    : never = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? (DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"] &
      DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Views"])[TableName] extends {
      Row: infer R
    }
    ? R
    : never
  : DefaultSchemaTableNameOrOptions extends keyof (DefaultSchema["Tables"] &
        DefaultSchema["Views"])
    ? (DefaultSchema["Tables"] &
        DefaultSchema["Views"])[DefaultSchemaTableNameOrOptions] extends {
        Row: infer R
      }
      ? R
      : never
    : never

export type TablesInsert<
  DefaultSchemaTableNameOrOptions extends
    | keyof DefaultSchema["Tables"]
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"]
    : never = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"][TableName] extends {
      Insert: infer I
    }
    ? I
    : never
  : DefaultSchemaTableNameOrOptions extends keyof DefaultSchema["Tables"]
    ? DefaultSchema["Tables"][DefaultSchemaTableNameOrOptions] extends {
        Insert: infer I
      }
      ? I
      : never
    : never

export type TablesUpdate<
  DefaultSchemaTableNameOrOptions extends
    | keyof DefaultSchema["Tables"]
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"]
    : never = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"][TableName] extends {
      Update: infer U
    }
    ? U
    : never
  : DefaultSchemaTableNameOrOptions extends keyof DefaultSchema["Tables"]
    ? DefaultSchema["Tables"][DefaultSchemaTableNameOrOptions] extends {
        Update: infer U
      }
      ? U
      : never
    : never

export type Enums<
  DefaultSchemaEnumNameOrOptions extends
    | keyof DefaultSchema["Enums"]
    | { schema: keyof DatabaseWithoutInternals },
  EnumName extends DefaultSchemaEnumNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaEnumNameOrOptions["schema"]]["Enums"]
    : never = never,
> = DefaultSchemaEnumNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaEnumNameOrOptions["schema"]]["Enums"][EnumName]
  : DefaultSchemaEnumNameOrOptions extends keyof DefaultSchema["Enums"]
    ? DefaultSchema["Enums"][DefaultSchemaEnumNameOrOptions]
    : never

export type CompositeTypes<
  PublicCompositeTypeNameOrOptions extends
    | keyof DefaultSchema["CompositeTypes"]
    | { schema: keyof DatabaseWithoutInternals },
  CompositeTypeName extends PublicCompositeTypeNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[PublicCompositeTypeNameOrOptions["schema"]]["CompositeTypes"]
    : never = never,
> = PublicCompositeTypeNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[PublicCompositeTypeNameOrOptions["schema"]]["CompositeTypes"][CompositeTypeName]
  : PublicCompositeTypeNameOrOptions extends keyof DefaultSchema["CompositeTypes"]
    ? DefaultSchema["CompositeTypes"][PublicCompositeTypeNameOrOptions]
    : never

export const Constants = {
  public: {
    Enums: {
      app_role: ["admin", "teacher", "student", "manager", "parent"],
    },
  },
} as const
