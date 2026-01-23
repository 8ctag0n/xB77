import {
  PaymentGateway,
  PaymentRequest,
  PaymentExecutionResult,
  PaymentContext,
  PaymentProvider
} from './payments';
import { RangeAdapter } from './payment_adapters/range';
import { ComplianceError } from './errors';

export interface RouterConfig {
  gateway: PaymentGateway;
  range: RangeAdapter;
  preferredInternalProvider: PaymentProvider;
  preferredExternalProvider: PaymentProvider;
}

export class PaymentRouter {
  constructor(private config: RouterConfig) {}

  /**
   * Routes a payment request through the appropriate provider after safety checks.
   */
  async route(request: PaymentRequest, context?: PaymentContext): Promise<PaymentExecutionResult> {
    // 1. Compliance Check
    const compliance = await this.config.range.preScreenPayment(request.vendor, request.amount);
    if (!compliance.isSafe) {
      throw new ComplianceError(compliance.reason || 'Risk score too low', { score: compliance.score });
    }

    // 2. Routing Decision
    const provider = this.determineProvider(request);

    // 3. Execution
    return await this.config.gateway.execute({
      ...request,
      provider
    }, context);
  }

  private determineProvider(request: PaymentRequest): PaymentProvider {
    // If provider is explicitly requested, use it (after compliance)
    if (request.provider) return request.provider;

    // Default routing logic
    if (request.type === 'internal') {
      return this.config.preferredInternalProvider;
    }

    // For external, we could have more complex logic here
    // e.g. checking if the vendor address is a SOL address or a merchant name
    if (this.isWeb2Merchant(request.vendor)) {
      return 'starpay';
    }

    return this.config.preferredExternalProvider;
  }

  private isWeb2Merchant(vendor: string): boolean {
    // Simple heuristic: if it doesn't look like a public key, it's probably Web2
    return vendor.length < 32 || !/^[1-9A-HJ-NP-Za-km-z]+$/.test(vendor);
  }
}
