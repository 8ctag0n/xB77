#include <stdio.h>
#include <stdlib.h>
#include <signal.h>
#include <unistd.h>
#include "../deps/znode.h"

// Bandera para salida limpia
static volatile int keep_running = 1;

void sig_handler(int _) {
    (void)_;
    keep_running = 0;
}

void on_solana_event(znode_event_type_t type, void* event_data, void* user_data) {
    (void)event_data;
    (void)user_data;

    if (type == ZNODE_EVENT_TRANSACTION) {
        // La data real ya se está mandando por el Unix Socket en znode.c
        // Aquí solo logueamos para el operador
        printf("[Z-Node] ⚡️ Stream Activity: Chunk forward to Agent\n");
    }
}

int main(int argc, char** argv) {
    signal(SIGINT, sig_handler);

    const char* env_endpoint = getenv("YELLOWSTONE_ENDPOINT");
    const char* env_token = getenv("YELLOWSTONE_TOKEN");

    const char* endpoint = (env_endpoint) ? env_endpoint : ((argc > 1) ? argv[1] : NULL);
    const char* token = (env_token) ? env_token : ((argc > 2) ? argv[2] : "");

    if (!endpoint) {
        printf("Error: No se proporcionó endpoint de Yellowstone.\n");
        printf("Uso: export YELLOWSTONE_ENDPOINT=... && znode-server\n");
        printf("O bien: znode-server <endpoint> [token]\n");
        return 1;
    }

    znode_config_t config = {
        .endpoint = endpoint,
        .token = token
    };

    printf("\n--- xB77 Z-Node Sentinel ---\n");
    printf("Endpoint: %s\n", config.endpoint);
    if (token && token[0] != '\0') printf("Token:    [PROPORCIONADO]\n");
    printf("Socket:   /tmp/xb77_znode.sock\n");
    printf("----------------------------\n");

    if (znode_connect(config, on_solana_event, NULL)) {
        printf("📡 Conexión gRPC establecida. Esperando eventos...\n");
        
        // En una implementación con libcurl real, esto debería ser 
        // un loop de curl_multi o similar. Para la demo/test, 
        // asumimos que znode_connect dispara el stream.
        while(keep_running) {
            sleep(1);
        }
    }

    znode_disconnect();
    printf("\nZ-Node apagado. Soberanía preservada.\n");

    return 0;
}
