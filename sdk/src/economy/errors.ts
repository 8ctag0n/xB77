export class EconomyError extends Error {
  constructor(message: string, public code: string, public details?: any) {
    super(message);
    this.name = 'EconomyError';
  }
}

export class ComplianceError extends EconomyError {
  constructor(reason: string, details?: any) {
    super(`Compliance Block: ${reason}`, 'COMPLIANCE_REJECTED', details);
    this.name = 'ComplianceError';
  }
}

export class LiquidityError extends EconomyError {
  constructor(message: string, details?: any) {
    super(message, 'INSUFFICIENT_LIQUIDITY', details);
    this.name = 'LiquidityError';
  }
}

export class ProviderError extends EconomyError {
  constructor(provider: string, message: string, details?: any) {
    super(`Provider ${provider} error: ${message}`, 'PROVIDER_FAILURE', details);
    this.name = 'ProviderError';
  }
}
