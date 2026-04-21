#ifndef ZNODE_H
#define ZNODE_H

#include <stdint.h>
#include <stdbool.h>
#include <stddef.h>

typedef enum {
    ZNODE_EVENT_SLOT,
    ZNODE_EVENT_TRANSACTION,
    ZNODE_EVENT_ERROR
} znode_event_type_t;

typedef struct {
    const char* endpoint;
    const char* token;
} znode_config_t;

typedef void (*znode_on_event_cb)(znode_event_type_t type, void* event_data, void* user_data);

bool znode_connect(znode_config_t config, znode_on_event_cb callback, void* user_data);
void znode_disconnect();

#endif // ZNODE_H
