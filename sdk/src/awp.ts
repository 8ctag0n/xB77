/**
 * Agent Wire Protocol (AWP) v0.2 - TypeScript SDK
 * xB77 Sovereign Infrastructure
 */

export enum MessageType {
    Handshake = 0x01,
    Signal = 0x02,
    Transfer = 0x03,
    Order = 0x06
}

export enum Side {
    Buy = 0x01,
    Sell = 0x02
}

export enum Chain {
    Solana = 0,
    Base = 1
}

export class AwpEncoder {
    private buf: number[] = [];

    private writeVarint(value: number) {
        let val = value;
        while (true) {
            let byte = val & 0x7f;
            val >>= 7;
            if (val > 0) {
                byte |= 0x80;
            }
            this.buf.push(byte);
            if (val === 0) break;
        }
    }

    private writeByte(byte: number) {
        this.buf.push(byte & 0xff);
    }

    private writeBytes(bytes: Uint8Array | Buffer) {
        for (const b of bytes) {
            this.buf.push(b);
        }
    }

    private writeString(str: string) {
        const bytes = Buffer.from(str, 'utf8');
        this.writeVarint(bytes.length);
        this.writeBytes(bytes);
    }

    /**
     * Codifica una orden de compra/venta para el AWPool
     */
    encodeOrder(order: {
        side: Side,
        chain: Chain,
        symbol: string,
        amount: bigint,
        price: number,
        nonce: number
    }): Buffer {
        this.buf = [];
        this.writeByte(MessageType.Order);
        this.writeByte(order.side);
        this.writeByte(order.chain);
        this.writeString(order.symbol);
        
        // Manejo de BigInt para el amount (Varint)
        this.writeVarint(Number(order.amount)); // TODO: Soporte completo BigInt para Varints gigantes
        this.writeVarint(order.price);
        this.writeVarint(order.nonce);

        return Buffer.from(this.buf);
    }
}
