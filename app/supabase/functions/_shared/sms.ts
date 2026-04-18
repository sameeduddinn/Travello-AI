/// <reference path="./compat.d.ts" />

type SendSmsInput = {
  to: string;
  message: string;
};

type SendSmsResult = {
  ok: boolean;
  status: number;
  message: string;
};

async function sendViaTwilio(input: SendSmsInput): Promise<SendSmsResult> {
  const sid = Deno.env.get('TWILIO_ACCOUNT_SID');
  const token = Deno.env.get('TWILIO_AUTH_TOKEN');
  const from = Deno.env.get('TWILIO_FROM_NUMBER');

  if (!sid || !token || !from) {
    return {
      ok: false,
      status: 500,
      message: 'Missing TWILIO_ACCOUNT_SID / TWILIO_AUTH_TOKEN / TWILIO_FROM_NUMBER.',
    };
  }

  const auth = btoa(`${sid}:${token}`);
  const body = new URLSearchParams({
    To: input.to,
    From: from,
    Body: input.message,
  });

  const response = await fetch(
      `https://api.twilio.com/2010-04-01/Accounts/${sid}/Messages.json`,
      {
        method: 'POST',
        headers: {
          Authorization: `Basic ${auth}`,
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body,
      },
  );

  if (!response.ok) {
    const detail = await response.text();
    return {
      ok: false,
      status: response.status,
      message: `Twilio SMS failed: ${detail}`,
    };
  }

  return {
    ok: true,
    status: response.status,
    message: 'SMS sent.',
  };
}

async function sendViaGenericGateway(input: SendSmsInput): Promise<SendSmsResult> {
  const url = Deno.env.get('SMS_API_URL');
  const apiKey = Deno.env.get('SMS_API_KEY');
  const sender = Deno.env.get('SMS_SENDER_ID') ?? 'Travello';

  if (!url || !apiKey) {
    return {
      ok: false,
      status: 500,
      message: 'Missing SMS_API_URL / SMS_API_KEY.',
    };
  }

  const response = await fetch(url, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${apiKey}`,
    },
    body: JSON.stringify({
      to: input.to,
      message: input.message,
      sender,
    }),
  });

  if (!response.ok) {
    const detail = await response.text();
    return {
      ok: false,
      status: response.status,
      message: `Generic SMS gateway failed: ${detail}`,
    };
  }

  return {
    ok: true,
    status: response.status,
    message: 'SMS sent.',
  };
}

export async function sendOtpSms(input: SendSmsInput): Promise<SendSmsResult> {
  const provider = (Deno.env.get('SMS_PROVIDER') ?? 'twilio').toLowerCase();

  if (provider === 'twilio') {
    return await sendViaTwilio(input);
  }

  if (provider === 'generic') {
    return await sendViaGenericGateway(input);
  }

  return {
    ok: false,
    status: 500,
    message: `Unsupported SMS_PROVIDER: ${provider}`,
  };
}
