import { dlopen, FFIType, suffix } from "bun:ffi";
import { Side, Chain } from './awp';
import * as path from 'path';

// Localizar la librería nativa
const libPath = path.resolve(__dirname, `../../zig-out/lib/libxb77_sdk.${suffix}`);

// Cargar la librería nativa de xB77
const lib = dlopen(libPath, {
  xb77_submit_order_c: {
    args: [
      FFIType.u8,     // side
      FFIType.u8,     // chain
      FFIType.ptr,    // symbol (pointer)
      FFIType.u64,    // symbol_len
      FFIType.u64,    // amount
      FFIType.u64     // price
    ],
    returns: FFIType.bool,
  },
});

/**
 * xB77 Merchant Client (Native Wrapper)
 * Usa el core de Zig para máxima performance y consistencia.
 */
export class MerchantClient {
    /**
     * Envía una orden al AWPool usando el motor nativo de Zig
     */
    async submitOrder(order: {
        side: Side,
        chain: Chain,
        symbol: string,
        amount: bigint,
        price: number
    }): Promise<void> {
        const symbolBuf = Buffer.from(order.symbol, 'utf8');
        
        const success = lib.symbols.xb77_submit_order_c(
            order.side,
            order.chain,
            symbolBuf,
            BigInt(symbolBuf.length),
            order.amount,
            BigInt(order.price)
        );

        if (!success) {
            throw new Error("Failed to submit order via Native SDK");
        }

        console.log(`[Native-SDK] 🚀 Order Submitted: ${order.side === Side.Buy ? 'BUY' : 'SELL'} ${order.symbol}`);
    }
}
