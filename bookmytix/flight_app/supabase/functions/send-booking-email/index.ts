/// <reference path="../_shared/compat.d.ts" />
import { createClient } from 'npm:@supabase/supabase-js@2';
import { corsHeaders, jsonResponse } from '../_shared/cors.ts';
import { isValidEmail, normalizeEmail } from '../_shared/security.ts';
import { sendViaResend } from '../_shared/mail.ts';

type BookingEmailBody = {
  email?: string;
  name?: string;
  destination?: string;
  amount?: number | string;
  booking_id?: string;
};

function escapeHtml(value: string): string {
  return value
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&#39;');
}

function normalizeAmount(value: unknown): number | null {
  const amount =
    typeof value === 'number' ? value : Number.parseFloat(String(value));
  if (!Number.isFinite(amount) || amount <= 0) return null;
  return Math.round(amount * 100) / 100;
}

Deno.serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  if (req.method !== 'POST') {
    return jsonResponse({ success: false, message: 'Method not allowed.' }, 405);
  }

  try {
    const supabaseUrl = Deno.env.get('SUPABASE_URL');
    const anonKey = Deno.env.get('SUPABASE_ANON_KEY');
    if (!supabaseUrl || !anonKey) {
      return jsonResponse({ success: false, message: 'Supabase environment is not configured.' }, 500);
    }

    const authorization = req.headers.get('Authorization') ?? '';
    if (!authorization.toLowerCase().startsWith('bearer ')) {
      return jsonResponse({ success: false, message: 'Missing auth token.' }, 401);
    }

    const userClient = createClient(supabaseUrl, anonKey, {
      auth: { persistSession: false, autoRefreshToken: false },
      global: { headers: { Authorization: authorization } },
    });

    const { data: userData, error: authError } = await userClient.auth.getUser();
    if (authError || !userData?.user) {
      return jsonResponse({ success: false, message: 'Unauthorized request.' }, 401);
    }

    const body = (await req.json()) as BookingEmailBody;

    const email = normalizeEmail((body.email ?? '').toString());
    const name = (body.name ?? '').toString().trim();
    const destination = (body.destination ?? '').toString().trim();
    const bookingId = (body.booking_id ?? '').toString().trim();
    const amount = normalizeAmount(body.amount);

    if (!isValidEmail(email)) {
      return jsonResponse({ success: false, message: 'Valid email is required.' }, 400);
    }
    if (name.length < 2) {
      return jsonResponse({ success: false, message: 'Valid name is required.' }, 400);
    }
    if (destination.length < 2) {
      return jsonResponse({ success: false, message: 'Valid destination is required.' }, 400);
    }
    if (bookingId.length < 3) {
      return jsonResponse({ success: false, message: 'Valid booking_id is required.' }, 400);
    }
    if (amount === null) {
      return jsonResponse({ success: false, message: 'Valid amount is required.' }, 400);
    }

    const safeName = escapeHtml(name);
    const safeDestination = escapeHtml(destination);
    const safeBookingId = escapeHtml(bookingId);
    const amountLabel = `PKR ${amount.toLocaleString('en-US', {
      minimumFractionDigits: 0,
      maximumFractionDigits: 2,
    })}`;

    const subject = `TravelloAI Booking Confirmed - ${safeBookingId}`;

    const html = `
      <div style="margin:0;padding:0;background:#f4f6fb;font-family:Arial,sans-serif;">
        <table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="padding:32px 12px;">
          <tr>
            <td align="center">
              <table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="max-width:640px;background:#ffffff;border-radius:16px;overflow:hidden;box-shadow:0 8px 30px rgba(20,30,55,.12);">
                <tr>
                  <td style="background:linear-gradient(120deg,#0ea86f,#0f9dd6);padding:26px 28px;color:#ffffff;">
                    <h1 style="margin:0;font-size:24px;font-weight:700;letter-spacing:.2px;">Booking Confirmation</h1>
                    <p style="margin:8px 0 0 0;font-size:14px;opacity:.95;">Your payment was successful and your trip is now confirmed.</p>
                  </td>
                </tr>
                <tr>
                  <td style="padding:24px 28px 8px 28px;color:#1f2a37;">
                    <p style="margin:0 0 18px 0;font-size:15px;">Hello <strong>${safeName}</strong>,</p>
                    <table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="border-collapse:separate;border-spacing:0 10px;">
                      <tr>
                        <td style="font-size:14px;color:#556070;">Destination</td>
                        <td align="right" style="font-size:15px;font-weight:600;color:#162030;">${safeDestination}</td>
                      </tr>
                      <tr>
                        <td style="font-size:14px;color:#556070;">Amount Paid</td>
                        <td align="right" style="font-size:15px;font-weight:700;color:#0c7c4a;">${amountLabel}</td>
                      </tr>
                      <tr>
                        <td style="font-size:14px;color:#556070;">Booking ID</td>
                        <td align="right" style="font-size:15px;font-weight:600;color:#162030;">${safeBookingId}</td>
                      </tr>
                    </table>
                    <p style="margin:18px 0 0 0;font-size:13px;color:#6b7686;line-height:1.7;">Please keep this email for your records. You can review your booking anytime in the TravelloAI app.</p>
                  </td>
                </tr>
                <tr>
                  <td style="padding:20px 28px 24px 28px;font-size:12px;color:#8b95a5;">
                    <hr style="border:none;border-top:1px solid #e8ebf1;margin:0 0 16px 0;" />
                    TravelloAI · Automated confirmation email
                  </td>
                </tr>
              </table>
            </td>
          </tr>
        </table>
      </div>
    `;

    const text =
      `Booking Confirmation\n` +
      `Name: ${name}\n` +
      `Destination: ${destination}\n` +
      `Amount Paid: ${amountLabel}\n` +
      `Booking ID: ${bookingId}`;

    const result = await sendViaResend({
      to: email,
      subject,
      html,
      text,
    });

    if (!result.ok) {
      return jsonResponse({ success: false, message: result.message }, 500);
    }

    return jsonResponse(
      {
        success: true,
        message: 'Booking confirmation email sent.',
        booking_id: bookingId,
        recipient: email,
      },
      200,
    );
  } catch (error) {
    const message = error instanceof Error ? error.message : 'Unexpected error.';
    return jsonResponse({ success: false, message }, 500);
  }
});
