import { createClient } from 'npm:@supabase/supabase-js@2';
import { corsHeaders, jsonResponse } from '../_shared/cors.ts';
import { generateOtp, isValidEmail, isValidPkPhone, normalizeEmail, normalizePkPhone, sha256 } from '../_shared/security.ts';
import { sendOtpSms } from '../_shared/sms.ts';

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

    if (!isValidPkPhone(phone)) {
      return jsonResponse({ message: 'Enter a valid PK mobile number.' }, 400);
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
      email: isValidEmail(email) ? email : null,
      phone,
      provider: paymentMethod,
      otp_hash: otpHash,
      expires_at: expiresAt,
      attempts: 0,
      verified: false,
    });

    if (insertOtpError) {
      return jsonResponse({ message: `Failed to create OTP request: ${insertOtpError.message}` }, 500);
    }

    const smsResult = await sendOtpSms({
      to: phone,
      message:
          'Travello OTP: $otpCode for $paymentMethod payment ($bookingType). Expires in 10 minutes. Do not share this code.',
    });

    if (!smsResult.ok) {
      return jsonResponse({ message: smsResult.message }, 500);
    }

    await adminClient.from('payment_attempts').insert({
      payment_method: paymentMethod,
      amount: 0,
      status: 'otp_sent',
      metadata: {
        requestId,
        bookingType,
        phone,
      },
    });

    return jsonResponse({
      requestId,
      message: 'OTP sent to your phone number successfully.',
    });
  } catch (error) {
    const message = error instanceof Error ? error.message : 'Unexpected error';
    return jsonResponse({ message }, 500);
  }
});
