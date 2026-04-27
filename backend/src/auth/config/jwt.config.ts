import type { StringValue } from 'ms';

export function getJwtSecret(): string {
  return process.env.JWT_SECRET ?? 'change_me_in_production';
}

export function getJwtExpiresIn(): StringValue {
  const rawValue = process.env.JWT_EXPIRES_IN ?? '7d';
  return rawValue as StringValue;
}

export function getOtpTtlSeconds(): number {
  const rawValue = process.env.OTP_TTL_SECONDS;
  const ttl = rawValue ? Number(rawValue) : 300;
  return Number.isFinite(ttl) && ttl > 0 ? ttl : 300;
}

export function getOtpRequestCooldownSeconds(): number {
  const rawValue = process.env.OTP_REQUEST_COOLDOWN_SECONDS;
  const cooldown = rawValue ? Number(rawValue) : 30;
  return Number.isFinite(cooldown) && cooldown > 0 ? cooldown : 30;
}

export function getOtpRequestWindowSeconds(): number {
  const rawValue = process.env.OTP_REQUEST_WINDOW_SECONDS;
  const windowSeconds = rawValue ? Number(rawValue) : 300;
  return Number.isFinite(windowSeconds) && windowSeconds > 0
    ? windowSeconds
    : 300;
}

export function getOtpMaxRequestsPerWindow(): number {
  const rawValue = process.env.OTP_MAX_REQUESTS_PER_WINDOW;
  const maxRequests = rawValue ? Number(rawValue) : 5;
  return Number.isFinite(maxRequests) && maxRequests > 0 ? maxRequests : 5;
}
