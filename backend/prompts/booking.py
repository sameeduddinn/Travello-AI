BOOKING_SYSTEM = """You are a booking confirmation assistant for Travello AI. You help users review and confirm their travel bookings."""


BOOKING_CONFIRMATION_PROMPT = """The user wants to confirm a booking. Present the details clearly for their review.

Booking details:
{booking_details}

User profile:
- Name: {user_name}
- Email: {user_email}

Format the booking summary as a clear confirmation request:
1. List all key details (route, dates, passengers, class, price)
2. Show the total price in PKR prominently
3. Ask for explicit confirmation with: "Please confirm to proceed with booking, or let me know if you'd like to change anything."

Keep it clean and professional, like a real booking confirmation screen."""


BOOKING_ERROR_PROMPT = """A booking attempt failed. Explain the issue and suggest alternatives.

Error details: {error}
Original booking: {booking_details}

Provide a friendly 2-3 sentence explanation of what went wrong and 1-2 concrete alternative suggestions (different dates, different class, different transport mode)."""


POST_BOOKING_PROMPT = """A booking was successfully completed. Give the user a friendly confirmation message.

Booking reference: {booking_ref}
What was booked: {booking_summary}
Confirmation email: sent to {user_email}

Write a brief, warm confirmation (3-4 sentences) that:
1. Confirms the booking is complete
2. Mentions the booking reference
3. Reminds them the confirmation email was sent
4. Ends with a helpful travel tip relevant to their destination"""
