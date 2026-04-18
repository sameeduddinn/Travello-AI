/// <reference path="../_shared/compat.d.ts" />
import { createClient } from 'npm:@supabase/supabase-js@2';
import { corsHeaders, jsonResponse } from '../_shared/cors.ts';
import { generateOtp, isValidEmail, isValidPkPhone, normalizeEmail, normalizePkPhone, sha256 } from '../_shared/security.ts';
import { sendViaResend } from '../_shared/mail.ts';

type ReqBody = {
  bookingType?: string;
  paymentMethod?: string;
  email?: string;
  phone?: string;
};

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  if (req.method !== 'POST') {
    return jsonResponse({ message: 'Method not allowed' }, 405);
  }

  try {
    const supabaseUrl = Deno.env.get('SUPABASE_URL');
    const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');

    if (!supabaseUrl || !serviceRoleKey) {
      return jsonResponse({ message: 'Supabase env is not configured.' }, 500);
    }

    const body = (await req.json()) as ReqBody;
    const bookingType = (body.bookingType ?? 'flight').toString();
    const paymentMethod = (body.paymentMethod ?? 'wallet').toString();
    const email = normalizeEmail((body.email ?? '').toString());
    const phone = normalizePkPhone((body.phone ?? '').toString());

    if (!isValidEmail(email)) {
      return jsonResponse({ message: 'Enter a valid email address.' }, 400);
    }

    if (!isValidPkPhone(phone)) {
      return jsonResponse({ message: 'Enter a valid PK mobile number (03XXXXXXXXX).' }, 400);
    }

    const requestId = `otp_${crypto.randomUUID().replaceAll('-', '')}`;
    const otpCode = generateOtp();
    const otpPepper = Deno.env.get('OTP_PEPPER') ?? 'travello-demo-pepper';
    const otpHash = await sha256(`${requestId}:${otpCode}:${otpPepper}`);
    const expiresAt = new Date(Date.now() + 10 * 60 * 1000).toISOString();

    const adminClient = createClient(supabaseUrl, serviceRoleKey, {
      auth: { persistSession: false, autoRefreshToken: false },
    });

    const { error: insertOtpError } = await adminClient.from('payment_otps').insert({
      request_id: requestId,
      email: email,
      phone: phone,
      provider: paymentMethod,
      otp_hash: otpHash,
      expires_at: expiresAt,
      attempts: 0,
      verified: false,
    });

    if (insertOtpError) {
      return jsonResponse({ message: `Failed to create OTP request: ${insertOtpError.message}` }, 500);
    }

    // Send OTP via email (Resend) — free tier, no domain verification needed with onboarding@resend.dev
    // Fix: was Dart string interpolation ($otpCode) → use JS template literal (${otpCode})
    const providerLabel = paymentMethod === 'jazzcash' ? 'JazzCash' : 'EasyPaisa';
    const emailResult = await sendViaResend({
      to: email,
      subject: `Travello AI — Your ${providerLabel} OTP`,
      html: `
        <div style="font-family:Arial,sans-serif;max-width:480px;margin:0 auto;padding:24px;">
          <h2 style="color:#0ea86f;margin-top:0;">Travello AI Payment OTP</h2>
          <p>You requested a payment OTP for your <strong>${bookingType}</strong> booking via <strong>${providerLabel}</strong>.</p>
          <div style="background:#f4f6fb;border-radius:12px;padding:20px 24px;text-align:center;margin:20px 0;">
            <span style="font-size:36px;font-weight:700;letter-spacing:8px;color:#162030;">${otpCode}</span>
          </div>
          <p style="color:#556070;font-size:14px;">This code expires in <strong>10 minutes</strong>. Do not share it with anyone.</p>
          <hr style="border:none;border-top:1px solid #e8ebf1;margin:20px 0;" />
          <p style="color:#8b95a5;font-size:12px;">If you did not request this code, ignore this email.</p>
        </div>
      `,
      text: `Travello AI OTP: ${otpCode} for ${paymentMethod} payment (${bookingType}). Expires in 10 minutes. Do not share.`,
    });

    if (!emailResult.ok) {
      return jsonResponse({ message: emailResult.message }, 500);
    }

    await adminClient.from('payment_attempts').insert({
      payment_method: paymentMethod,
      amount: 0,
      status: 'otp_sent',
      metadata: { requestId, bookingType, phone, email },
    });

    return jsonResponse({
      requestId,
      message: `OTP sent to ${email}. Check your inbox.`,
    });
  } catch (error) {
    const message = error instanceof Error ? error.message : 'Unexpected error';
    return jsonResponse({ message }, 500);
  }
});
