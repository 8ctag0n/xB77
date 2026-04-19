#ifndef ZNODE_H
#define ZNODE_H

#include <stdint.h>
#include <stdbool.h>
#include <stddef.h>

typedef enum {
    ZNODE_CHAIN_SOLANA,
    ZNODE_CHAIN_EVM_BASE,
    ZNODE_CHAIN_EVM_ARBITRUM
} znode_chain_t;

typedef enum {
    ZNODE_EVENT_TX_STANDARD,      // Transacción pública
    ZNODE_EVENT_TX_COMPRESSED,    // Solana State Compression (Light/Photon)
    ZNODE_EVENT_TX_CONFIDENTIAL,  // Arcium / Encrypted
    ZNODE_EVENT_ACCOUNT_UPDATE,   // Cambios de balance/data
    ZNODE_EVENT_ERROR
} znode_event_type_t;

// Estructura universal de evento para el Bus local
typedef struct {
    znode_chain_t chain;
    znode_event_type_t type;
    uint64_t timestamp;
    uint8_t signature[64];
    
    // Data polimórfica (depende del tipo de evento)
    const uint8_t* payload;
    size_t payload_len;
    
    // Metadatos de desencriptación (si aplica)
    bool is_encrypted;
    uint8_t encryption_tag[16];
} znode_event_t;

typedef void (*znode_on_event_cb)(const znode_event_t* event, void* user_data);

bool znode_connect_solana(const char* endpoint, const char* token);
bool znode_connect_evm(znode_chain_t chain, const char* endpoint);
bool znode_subscribe_program(znode_chain_t chain, const uint8_t* program_id);

// Bus Local (para los 100 agentes)
bool znode_bus_init(const char* bus_name);
void znode_bus_publish(const znode_event_t* event);

#endif // ZNODE_H
