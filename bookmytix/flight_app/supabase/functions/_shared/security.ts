export async function sha256(input: string): Promise<string> {
  const data = new TextEncoder().encode(input);
  const hashBuffer = await crypto.subtle.digest('SHA-256', data);
  const bytes = new Uint8Array(hashBuffer);
  return Array.from(bytes)
      .map((b) => b.toString(16).padStart(2, '0'))
      .join('');
}

export function generateOtp(): string {
  const min = 100000;
  const max = 999999;
  const value = Math.floor(Math.random() * (max - min + 1)) + min;
  return value.toString();
}

export function normalizeEmail(raw: string): string {
  return raw.trim().toLowerCase();
}

export function isValidEmail(email: string): boolean {
  return /^[\w.+\-]+@[\w\-]+\.[a-zA-Z]{2,}$/.test(email.trim());
}

export function normalizePkPhone(raw: string): string {
  const digits = raw.replace(/\D/g, '');
  if (digits.length === 10 && digits.startsWith('3')) {
    return `+92${digits}`;
  }
  if (digits.length === 11 && digits.startsWith('03')) {
    return `+92${digits.substring(1)}`;
  }
  if (digits.length === 12 && digits.startsWith('923')) {
    return `+${digits}`;
  }
  if (raw.trim().startsWith('+923') && raw.trim().length >= 13) {
    return raw.trim();
  }
  return raw.trim();
}

export function isValidPkPhone(raw: string): boolean {
  const normalized = normalizePkPhone(raw);
  return /^\+923\d{9}$/.test(normalized);
}
