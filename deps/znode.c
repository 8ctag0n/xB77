#include "znode.h"
#include <curl/curl.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

// Contexto interno del cliente
typedef struct {
    znode_config_t config;
    znode_on_event_cb callback;
    void* user_data;
    CURL* curl;
} znode_client_t;

static znode_client_t* global_client = NULL;

// Esta función se llama cada vez que llega un "chorro" de bytes de QuickNode
static size_t write_callback(char* ptr, size_t size, size_t nmemb, void* userdata) {
    znode_client_t* client = (znode_client_t*)userdata;
    size_t total_size = size * nmemb;

    // TODO: Aquí integraremos nanopb para decodificar el mensaje gRPC (Length-Prefixed)
    // Por ahora, solo notificamos que llegó data para testear la conexión
    if (client->callback) {
        // Simulamos un evento de SLOT para validar que el cable funciona
        client->callback(ZNODE_EVENT_SLOT, NULL, client->user_data);
    }

    return total_size;
}

bool znode_connect(znode_config_t config, znode_on_event_cb callback, void* user_data) {
    if (global_client) return false;

    global_client = calloc(1, sizeof(znode_client_t));
    global_client->config = config;
    global_client->callback = callback;
    global_client->user_data = user_data;

    curl_global_init(CURL_GLOBAL_ALL);
    global_client->curl = curl_easy_init();

    if (global_client->curl) {
        struct curl_slist* headers = NULL;
        headers = curl_slist_append(headers, "Content-Type: application/grpc");
        
        // El secreto de QuickNode: x-token
        char token_header[256];
        snprintf(token_header, sizeof(token_header), "x-token: %s", config.token);
        headers = curl_slist_append(headers, token_header);

        curl_easy_setopt(global_client->curl, CURLOPT_URL, config.endpoint);
        curl_easy_setopt(global_client->curl, CURLOPT_HTTPHEADER, headers);
        curl_easy_setopt(global_client->curl, CURLOPT_HTTP_VERSION, CURL_HTTP_VERSION_2_0);
        
        // IMPORTANTE: gRPC usa POST para subscripciones
        curl_easy_setopt(global_client->curl, CURLOPT_POST, 1L);
        
        // No queremos que curl guarde la data en un archivo, queremos procesarla en vivo
        curl_easy_setopt(global_client->curl, CURLOPT_WRITEFUNCTION, write_callback);
        curl_easy_setopt(global_client->curl, CURLOPT_WRITEDATA, global_client);

        // Esto dispara el stream en un hilo separado o bloquea según cómo lo llamemos
        // Para la demo, lo dejaremos listo para integrarse al event loop de Zig
        return true;
    }

    return false;
}

void znode_disconnect() {
    if (global_client) {
        if (global_client->curl) curl_easy_cleanup(global_client->curl);
        free(global_client);
        global_client = NULL;
        curl_global_cleanup();
    }
}

bool znode_subscribe_vault(const uint8_t* pubkey) {
    // TODO: Construir el mensaje Protobuf SubscribeRequest y mandarlo por el stream
    (void)pubkey;
    return true;
}
