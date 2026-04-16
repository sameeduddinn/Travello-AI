# Next Steps After SQL (Supabase)

You already ran SQL successfully. Now complete this checklist.

## 1) Set Edge Function Secrets
In Supabase Dashboard -> Edge Functions -> Secrets, add:

- `SMS_PROVIDER=twilio`
- `TWILIO_ACCOUNT_SID`
- `TWILIO_AUTH_TOKEN`
- `TWILIO_FROM_NUMBER`
- `OTP_PEPPER` (any long random secret string)

For booking confirmation email also add:

- `RESEND_API_KEY`
- `MAIL_FROM` (example: `Travello AI <noreply@yourdomain.com>`)

If using your own SMS gateway instead of Twilio:

- `SMS_PROVIDER=generic`
- `SMS_API_URL`
- `SMS_API_KEY`
- `SMS_SENDER_ID` (optional)

`SUPABASE_URL` and `SUPABASE_SERVICE_ROLE_KEY` are available automatically in hosted functions.

## 2) Deploy Functions
From project root, run:

```bash
supabase functions deploy send-payment-otp
supabase functions deploy verify-payment-otp
supabase functions deploy send-booking-confirmation
```

## 3) Test Functions Quickly (Supabase Dashboard)
- Open each function -> Invoke
- Send sample payload from `supabase/edge_function_contracts.md`
- Ensure HTTP 200 responses and expected keys

## 4) App Test Flow (End-to-End)
1. Login with authenticated user (not guest)
2. Go to booking payment
3. For Easypaisa/JazzCash click `Get Code`
4. Check phone SMS inbox for OTP
5. Enter OTP and click `Verify OTP`
6. Complete payment
7. On payment success, check:
   - booking row in `bookings`
   - payment log row in `payment_attempts`
   - booking confirmation email delivered

## 5) If OTP/Email Fails
- Verify function logs in Supabase Dashboard
- Confirm SMS secrets/provider are valid
- Confirm sender number is approved with your SMS provider
- Confirm sender domain is allowed by your email provider
- Confirm app still has internet and user is authenticated

## 6) Optional Hardening (after demo)
- Add rate limiting by email/phone in `send-payment-otp`
- Store provider response IDs in `payment_attempts.metadata`
- Add daily cleanup for expired `payment_otps`
