import { corsHeaders, jsonResponse } from '../_shared/cors.ts';
import { isValidEmail, normalizeEmail } from '../_shared/security.ts';
import { sendViaResend } from '../_shared/mail.ts';

type BookingPayload = {
  bookingType?: string;
  pnr?: string;
  transactionId?: string;
  total?: number;
  grandTotal?: number;
  currency?: string;
  email?: string;
  contactEmail?: string;
  paymentMethod?: string;
  flightDetails?: Record<string, unknown>;
  trainDetails?: Record<string, unknown>;
};

function routeSummary(payload: BookingPayload): string {
  if ((payload.bookingType ?? 'flight') == 'train') {
    const t = payload.trainDetails ?? {};
    return `${(t['from'] ?? 'N/A').toString()} -> ${(t['to'] ?? 'N/A').toString()}`;
  }
  const f = payload.flightDetails ?? {};
  return `${(f['from'] ?? 'N/A').toString()} -> ${(f['to'] ?? 'N/A').toString()}`;
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  if (req.method !== 'POST') {
    return jsonResponse({ message: 'Method not allowed' }, 405);
  }

  try {
    const payload = (await req.json()) as BookingPayload;
    const bookingType = (payload.bookingType ?? 'flight').toString();
    const email = normalizeEmail((payload.email ?? payload.contactEmail ?? '').toString());

    if (!isValidEmail(email)) {
      return jsonResponse({ sent: false, message: 'Enter a valid email address.' }, 400);
    }

    const pnr = (payload.pnr ?? 'N/A').toString();
    const transactionId = (payload.transactionId ?? 'N/A').toString();
    const totalAmount = payload.total ?? payload.grandTotal ?? 0;
    const currency = (payload.currency ?? 'PKR').toString().replaceAll(' ', '');
    const method = (payload.paymentMethod ?? 'N/A').toString();
    const route = routeSummary(payload);

    const subject = `Travello Booking Confirmed - ${pnr}`;
    const html = `
      <div style="font-family: Arial, sans-serif; line-height:1.6;">
        <h2>Your booking is confirmed</h2>
        <p>Thank you for booking with Travello AI.</p>
        <ul>
          <li><b>Booking type:</b> ${bookingType}</li>
          <li><b>PNR:</b> ${pnr}</li>
          <li><b>Route:</b> ${route}</li>
          <li><b>Transaction ID:</b> ${transactionId}</li>
          <li><b>Paid Amount:</b> ${currency} ${totalAmount}</li>
          <li><b>Payment Method:</b> ${method}</li>
        </ul>
        <p>Keep this email for your records and e-ticket reference.</p>
      </div>
    `;

    const text =
      `Booking confirmed. PNR: ${pnr}. Route: ${route}. Transaction ID: ${transactionId}. Amount: ${currency} ${totalAmount}.`;

    const mailResult = await sendViaResend({
      to: email,
      subject,
      html,
      text,
    });

    if (!mailResult.ok) {
      return jsonResponse({ sent: false, message: mailResult.message }, 500);
    }

    return jsonResponse({ sent: true, message: 'Booking confirmation email sent.' }, 200);
  } catch (error) {
    const message = error instanceof Error ? error.message : 'Unexpected error';
    return jsonResponse({ sent: false, message }, 500);
  }
});
