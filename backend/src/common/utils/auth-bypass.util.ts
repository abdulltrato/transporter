import { UserRole } from '../enums/user-role.enum';

const DISABLED_VALUES = new Set(['0', 'false', 'no', 'off']);

export function isAuthBypassEnabled(): boolean {
  return isToggleEnabled(process.env.TRANSPORTER_AUTH_BYPASS, false);
}

export function isAuthorizationBypassEnabled(): boolean {
  return isToggleEnabled(
    process.env.TRANSPORTER_AUTHZ_BYPASS,
    isAuthBypassEnabled()
  );
}

export function resolveBypassRole(input: {
  headerRole?: string;
  token?: string;
}): UserRole {
  const fromHeader = parseUserRole(input.headerRole);
  if (fromHeader) {
    return fromHeader;
  }

  const fromToken = parseUserRole(input.token);
  if (fromToken) {
    return fromToken;
  }

  return UserRole.CLIENT;
}

export function getBypassUserProfile(role: UserRole): {
  fullName: string;
  phone: string;
} {
  if (role === UserRole.DRIVER) {
    return {
      fullName: 'Taxista Modo Teste',
      phone: '+258900000002'
    };
  }

  return {
    fullName: 'Cliente Modo Teste',
    phone: '+258900000001'
  };
}

function parseUserRole(rawValue?: string): UserRole | undefined {
  if (!rawValue) {
    return undefined;
  }

  const normalized = rawValue.trim().toLowerCase();
  if (normalized.includes(UserRole.DRIVER)) {
    return UserRole.DRIVER;
  }

  if (normalized.includes(UserRole.CLIENT)) {
    return UserRole.CLIENT;
  }

  return undefined;
}

function isToggleEnabled(rawValue: string | undefined, defaultValue: boolean): boolean {
  if (!rawValue || rawValue.trim().length === 0) {
    return defaultValue;
  }

  return !DISABLED_VALUES.has(rawValue.trim().toLowerCase());
}
