import { serve } from "https://deno.land/std@0.190.0/http/server.ts";
import { Resend } from "https://esm.sh/resend@4.0.0";

const resend = new Resend(Deno.env.get("RESEND_API_KEY"));

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

interface InviteEmailRequest {
  email: string;
  role: string;
  madrasaName: string;
  invitedBy: string;
}

const handler = async (req: Request): Promise<Response> => {
  // Handle CORS preflight requests
  if (req.method === "OPTIONS") {
    return new Response(null, { headers: corsHeaders });
  }

  try {
    const { email, role, madrasaName, invitedBy }: InviteEmailRequest = await req.json();

    // Create signup URL with email pre-filled
    const signupUrl = `${Deno.env.get("VITE_SUPABASE_URL")?.replace('/v1', '') || ''}/auth/v1/signup?email=${encodeURIComponent(email)}`;

    const emailResponse = await resend.emails.send({
      from: "Madrasa Management <onboarding@resend.dev>",
      to: [email],
      subject: `${madrasaName} میں شامل ہونے کی دعوت`,
      html: `
        <div dir="rtl" style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
          <h1 style="color: #2563eb;">السلام علیکم ورحمۃ اللہ وبرکاتہ</h1>
          <p style="font-size: 16px; line-height: 1.6;">
            آپ کو <strong>${madrasaName}</strong> میں <strong>${role}</strong> کے طور پر شامل ہونے کی دعوت دی گئی ہے۔
          </p>
          <p style="font-size: 16px; line-height: 1.6;">
            براہ کرم اپنا اکاؤنٹ بنانے کے لیے نیچے دیے گئے بٹن پر کلک کریں:
          </p>
          <div style="text-align: center; margin: 30px 0;">
            <a href="${signupUrl}" 
               style="background-color: #2563eb; color: white; padding: 12px 30px; text-decoration: none; border-radius: 5px; display: inline-block; font-size: 16px;">
              اکاؤنٹ بنائیں
            </a>
          </div>
          <p style="font-size: 14px; color: #666; line-height: 1.6;">
            یا اس لنک کو کاپی کر کے اپنے براؤزر میں کھولیں:
            <br/>
            <a href="${signupUrl}" style="color: #2563eb; word-break: break-all;">${signupUrl}</a>
          </p>
          <p style="font-size: 14px; color: #666; margin-top: 30px;">
            آپ کو ${invitedBy} نے مدعو کیا ہے۔
          </p>
          <p style="font-size: 14px; color: #666;">
            اگر آپ نے یہ دعوت نہیں مانگی تو اس ای میل کو نظرانداز کر دیں۔
          </p>
        </div>
      `,
    });

    console.log("Invitation email sent successfully:", emailResponse);

    return new Response(JSON.stringify(emailResponse), {
      status: 200,
      headers: {
        "Content-Type": "application/json",
        ...corsHeaders,
      },
    });
  } catch (error: any) {
    console.error("Error in send-role-invite function:", error);
    return new Response(
      JSON.stringify({ error: error.message }),
      {
        status: 500,
        headers: { "Content-Type": "application/json", ...corsHeaders },
      }
    );
  }
};

serve(handler);
