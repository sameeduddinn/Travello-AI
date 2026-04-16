import { createClient } from 'npm:@supabase/supabase-js@2';
import { corsHeaders, jsonResponse } from '../_shared/cors.ts';
import { isValidEmail, isValidPkPhone, normalizeEmail, normalizePkPhone, sha256 } from '../_shared/security.ts';

type ReqBody = {
  requestId?: string;
  code?: string;
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
    const requestId = (body.requestId ?? '').toString().trim();
    const code = (body.code ?? '').toString().trim();
    const email = normalizeEmail((body.email ?? '').toString());
    const phone = normalizePkPhone((body.phone ?? '').toString());

    if (requestId.isEmpty || code.length != 6) {
      return jsonResponse({ verified: false, message: 'Invalid request id or OTP.' }, 400);
    }

    if (!isValidPkPhone(phone)) {
      return jsonResponse({ verified: false, message: 'Enter a valid PK mobile number.' }, 400);
    }

    const adminClient = createClient(supabaseUrl, serviceRoleKey, {
      auth: { persistSession: false, autoRefreshToken: false },
    });

    const { data: otpRow, error: fetchError } = await adminClient
      .from('payment_otps')
      .select('id, request_id, email, phone, otp_hash, attempts, verified, expires_at, provider')
      .eq('request_id', requestId)
      .maybeSingle();

    if (fetchError || otpRow == null) {
      return jsonResponse({ verified: false, message: 'OTP request not found.' }, 400);
    }

    if ((otpRow.phone ?? '').toString() != phone) {
      return jsonResponse({ verified: false, message: 'Phone does not match OTP request.' }, 400);
    }

    const storedEmail = (otpRow.email ?? '').toString().toLowerCase();
    if (email.isNotEmpty && isValidEmail(email) && storedEmail.isNotEmpty && storedEmail != email) {
      return jsonResponse({ verified: false, message: 'Email does not match OTP request.' }, 400);
    }

    if (otpRow.verified == true) {
      return jsonResponse({ verified: true, message: 'OTP already verified.' }, 200);
    }

    const now = new Date();
    const expiry = new Date(otpRow.expires_at as string);
    if (now.getTime() > expiry.getTime()) {
      return jsonResponse({ verified: false, message: 'OTP expired. Please request a new code.' }, 400);
    }

    const attempts = (otpRow.attempts as number? ?? 0);
    if (attempts >= 5) {
      return jsonResponse({ verified: false, message: 'Too many invalid attempts. Request a new OTP.' }, 400);
    }

    const otpPepper = Deno.env.get('OTP_PEPPER') ?? 'travello-demo-pepper';
    const expectedHash = await sha256(`${requestId}:${code}:${otpPepper}`);

    if (expectedHash != otpRow.otp_hash) {
      await adminClient
        .from('payment_otps')
        .update({ attempts: attempts + 1 })
        .eq('id', otpRow.id);

      return jsonResponse({ verified: false, message: 'Invalid OTP code.' }, 400);
    }

    await adminClient
      .from('payment_otps')
      .update({
        verified: true,
        verified_at: new Date().toISOString(),
        attempts: attempts + 1,
      })
      .eq('id', otpRow.id);

    await adminClient.from('payment_attempts').insert({
      payment_method: (otpRow.provider ?? 'wallet').toString(),
      amount: 0,
      status: 'otp_verified',
      metadata: { requestId },
    });

    return jsonResponse({ verified: true, message: 'OTP verified.' }, 200);
  } catch (error) {
    const message = error instanceof Error ? error.message : 'Unexpected error';
    return jsonResponse({ verified: false, message }, 500);
  }
});
