// type SendMailInput = {
//   to: string;
//   subject: string;
//   html: string;
//   text?: string;
// };

// export async function sendViaResend(input: SendMailInput): Promise<{ ok: boolean; status: number; message: string }> {
// //   const apiKey = Deno.env.get('RESEND_API_KEY');
// //   const from = Deno.env.get('MAIL_FROM') ?? 'Travello AI <noreply@example.com>';

//   if (!apiKey) {
//     return {
//       ok: false,
//       status: 500,
//       message: 'Missing RESEND_API_KEY secret.',
//     };
//   }

//   const response = await fetch('https://api.resend.com/emails', {
//     method: 'POST',
//     headers: {
//       Authorization: `Bearer ${apiKey}`,
//       'Content-Type': 'application/json',
//     },
//     body: JSON.stringify({
//       from,
//       to: [input.to],
//       subject: input.subject,
//       html: input.html,
//       text: input.text,
//     }),
//   });

//   if (!response.ok) {
//     const detail = await response.text();
//     return {
//       ok: false,
//       status: response.status,
//       message: `Resend API failed: ${detail}`,
//     };
//   }

//   return {
//     ok: true,
//     status: response.status,
//     message: 'Email sent.',
//   };
// }
