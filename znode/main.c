#include <stdio.h>
#include <stdlib.h>
#include <curl/curl.h>
#include "../deps/znode.h"

// Este será el binario independiente "Z-Node Server"
// Su única misión: Mantener el gRPC con QuickNode y 
// repartir la data a los agentes locales.

void on_solana_event(znode_event_type_t type, void* event_data, void* user_data) {
    (void)event_data;
    (void)user_data;

    switch(type) {
        case ZNODE_EVENT_SLOT:
            printf("[Z-Node Server] 🟢 Nuevo Slot detectado. Notificando a agentes...\n");
            // TODO: Escribir en memoria compartida / Unix Socket
            break;
        case ZNODE_EVENT_TRANSACTION:
            printf("[Z-Node Server] 💸 Transacción de interés detectada.\n");
            break;
        default:
            break;
    }
}

int main(int argc, char** argv) {
    if (argc < 3) {
        printf("Uso: znode-server <endpoint> <token>\n");
        return 1;
    }

    znode_config_t config = {
        .endpoint = argv[1],
        .token = argv[2]
    };

    printf("xB77 Z-Node Server inicializando...\n");
    printf("Conectando a: %s\n", config.endpoint);

    if (znode_connect(config, on_solana_event, NULL)) {
        printf("📡 Stream gRPC abierto. Presiona Ctrl+C para salir.\n");
        
        // El servidor se queda vivo manteniendo la conexión
        // En una implementación real usaríamos curl_easy_perform o un multi-handle loop
        while(1) {
            // Loop de eventos
        }
    }

    return 0;
}
