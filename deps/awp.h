#ifndef AWP_H
#define AWP_H

#include <stdint.h>
#include <string.h>

// --- AWP (Agent Wire Protocol) C Parser para Z-Node ---
// Estándar ultra-ligero para mensajes entre Agentes Soberanos.

typedef enum {
    AWP_MSG_HANDSHAKE = 0x01,
    AWP_MSG_SIGNAL = 0x02,
    AWP_MSG_TRANSFER = 0x03,
    AWP_MSG_AUDIT_REPORT = 0x04
} awp_msg_type_t;

typedef enum {
    AWP_CHAIN_SOLANA = 0,
    AWP_CHAIN_BASE = 1,
    AWP_CHAIN_ARBITRUM = 2,
    AWP_CHAIN_BITCOIN = 3
} awp_chain_t;

typedef enum {
    AWP_SIGNAL_BUY = 0x01,
    AWP_SIGNAL_SELL = 0x02,
    AWP_SIGNAL_HOLD = 0x03,
    AWP_SIGNAL_PANIC = 0xFF
} awp_signal_type_t;

typedef struct {
    awp_chain_t chain;
    const char* symbol;
    awp_signal_type_t signal;
    uint8_t confidence;
} awp_signal_msg_t;

typedef struct {
    awp_chain_t chain;
    uint64_t amount;
    uint8_t recipient[32]; // Max size (Solana is 32, EVM is 20)
} awp_transfer_msg_t;

// Escribe un varint (LEB128) en el buffer.
static inline size_t awp_write_varint(uint8_t* buf, uint64_t value) {
    size_t pos = 0;
    while (1) {
        uint8_t byte = value & 0x7F;
        value >>= 7;
        if (value > 0) {
            byte |= 0x80;
        }
        buf[pos++] = byte;
        if (value == 0) break;
    }
    return pos;
}

// Decodifica un varint (LEB128) desde el buffer y avanza el puntero.
static inline int awp_read_varint(const uint8_t** ptr, const uint8_t* end, uint64_t* out_val) {
    uint64_t value = 0;
    int shift = 0;
    while (*ptr < end) {
        uint8_t byte = **ptr;
        (*ptr)++;
        value |= (uint64_t)(byte & 0x7F) << shift;
        if ((byte & 0x80) == 0) {
            *out_val = value;
            return 1; // OK
        }
        shift += 7;
        if (shift >= 64) return 0; // Error: Varint demasiado grande
    }
    return 0; // Error: EOF
}

// Codifica un mensaje de transferencia. Retorna el tamaño escrito.
static inline size_t awp_encode_transfer(uint8_t* buf, const awp_transfer_msg_t* msg) {
    uint8_t* ptr = buf;
    *ptr++ = AWP_MSG_TRANSFER;
    *ptr++ = (uint8_t)msg->chain;
    ptr += awp_write_varint(ptr, msg->amount);
    size_t addr_len = (msg->chain == AWP_CHAIN_SOLANA) ? 32 : 20;
    memcpy(ptr, msg->recipient, addr_len);
    ptr += addr_len;
    return ptr - buf;
}

// Codifica un mensaje de señal. Retorna el tamaño escrito.
static inline size_t awp_encode_signal(uint8_t* buf, const awp_signal_msg_t* msg) {
    uint8_t* ptr = buf;
    *ptr++ = AWP_MSG_SIGNAL;
    *ptr++ = (uint8_t)msg->chain;
    size_t symbol_len = strlen(msg->symbol);
    ptr += awp_write_varint(ptr, (uint64_t)symbol_len);
    memcpy(ptr, msg->symbol, symbol_len);
    ptr += symbol_len;
    *ptr++ = (uint8_t)msg->signal;
    *ptr++ = msg->confidence;
    return ptr - buf;
}

// Decodifica un mensaje de transferencia directo a Stack (Zero Allocation)
static inline int awp_decode_transfer(const uint8_t* buffer, size_t len, awp_transfer_msg_t* out_msg) {
    const uint8_t* ptr = buffer;
    const uint8_t* end = buffer + len;

    if (ptr >= end) return 0;
    
    // 1. Tipo de mensaje
    uint8_t type = *ptr++;
    if (type != AWP_MSG_TRANSFER) return 0;

    if (ptr >= end) return 0;
    
    // 2. Chain ID
    out_msg->chain = (awp_chain_t)*ptr++;

    // 3. Amount (Varint)
    if (!awp_read_varint(&ptr, end, &out_msg->amount)) return 0;

    // 4. Recipient
    size_t req_len = (out_msg->chain == AWP_CHAIN_SOLANA) ? 32 : 20;
    if (ptr + req_len > end) return 0;

    memcpy(out_msg->recipient, ptr, req_len);
    
    return 1; // Parseo exitoso en tiempo O(1)
}

#endif // AWP_H
