# Edge Function Contracts (Used by App Code)

The Flutter app now calls these functions:

1. `send-payment-otp`
2. `verify-payment-otp`
3. `send-booking-confirmation`

## 1) send-payment-otp
### Request body
```json
{
  "bookingType": "flight",
  "paymentMethod": "easypaisa",
  "phone": "+923001234567"
}
```

### Success response (HTTP 200)
```json
{
  "requestId": "otp_req_abc123",
  "message": "OTP sent to your phone number successfully"
}
```

### Error response (HTTP 400/500)
```json
{
  "message": "Reason"
}
```

## 2) verify-payment-otp
### Request body
```json
{
  "requestId": "otp_req_abc123",
  "code": "123456",
  "phone": "+923001234567"
}
```

### Success response (HTTP 200)
```json
{
  "verified": true,
  "message": "OTP verified"
}
```

### Failed response (HTTP 400)
```json
{
  "verified": false,
  "message": "Invalid or expired OTP"
}
```

## 3) send-booking-confirmation
### Request body
Pass full booking payload from app (includes contact email, PNR, transaction id, amount, booking details).

### Success response (HTTP 200)
```json
{
  "sent": true,
  "message": "Booking confirmation email sent"
}
```

### Error response (HTTP 400/500)
```json
{
  "sent": false,
  "message": "Reason"
}
```

## Required Supabase Secrets
Set these in Supabase -> Edge Functions -> Secrets:

For SMS OTP (choose one provider mode):
- `SMS_PROVIDER=twilio`
- `TWILIO_ACCOUNT_SID`
- `TWILIO_AUTH_TOKEN`
- `TWILIO_FROM_NUMBER`

Or for custom SMS gateway:
- `SMS_PROVIDER=generic`
- `SMS_API_URL`
- `SMS_API_KEY`
- `SMS_SENDER_ID` (optional)

For booking confirmation email:

- `RESEND_API_KEY`
- `MAIL_FROM` (for example: `Travello AI <noreply@yourdomain.com>`)

Security:
- `OTP_PEPPER`

If using another provider (Brevo, Mailgun), add corresponding API key and update function logic.
