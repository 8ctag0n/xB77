export const PAYMENT_METHODS = {
  PRIVACY_CASH: 1 << 0,
  STARPAY: 1 << 1,
  SHADOWWIRE: 1 << 2,
  SILENTSWAP: 1 << 3,
} as const;

export type PaymentMethod = keyof typeof PAYMENT_METHODS;
