#include "znode.h"
#include "awp.h"
#include <curl/curl.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <pthread.h>
#include <sys/socket.h>
#include <sys/un.h>

#define ZNODE_BUFFER_SIZE 65536

typedef struct {
    znode_config_t config;
    znode_on_event_cb callback;
    void* user_data;
    CURL* curl;
    int socket_fd;
    uint8_t buffer[ZNODE_BUFFER_SIZE];
    size_t buffer_len;
    pthread_t thread;
    volatile bool running;
} znode_client_t;

static znode_client_t* global_client = NULL;

static int connect_to_bridge() {
    int fd = socket(AF_UNIX, SOCK_STREAM, 0);
    if (fd < 0) return -1;

    struct sockaddr_un addr;
    memset(&addr, 0, sizeof(addr));
    addr.sun_family = AF_UNIX;
    strncpy(addr.sun_path, "/tmp/xb77_znode.sock", sizeof(addr.sun_path) - 1);

    if (connect(fd, (struct sockaddr*)&addr, sizeof(addr)) < 0) {
        close(fd);
        return -1;
    }
    return fd;
}

static void process_yellowstone_frame(znode_client_t* client, const uint8_t* data, size_t len) {
    if (len == 0) return;

    uint8_t* awp_buf = malloc(len + 16);
    if (!awp_buf) return;

    size_t awp_len = awp_encode_raw_yellowstone(awp_buf, data, len);

    if (client->socket_fd >= 0) {
        if (send(client->socket_fd, awp_buf, awp_len, MSG_NOSIGNAL) < 0) {
            close(client->socket_fd);
            client->socket_fd = connect_to_bridge();
            if (client->socket_fd >= 0) {
                send(client->socket_fd, awp_buf, awp_len, MSG_NOSIGNAL);
            }
        }
    }
    
    free(awp_buf);

    if (client->callback) {
        client->callback(ZNODE_EVENT_TRANSACTION, (void*)data, client->user_data);
    }
}

static size_t write_callback(char* ptr, size_t size, size_t nmemb, void* userdata) {
    znode_client_t* client = (znode_client_t*)userdata;
    size_t total_size = size * nmemb;

    if (client->socket_fd < 0) {
        client->socket_fd = connect_to_bridge();
    }

    if (client->buffer_len + total_size <= ZNODE_BUFFER_SIZE) {
        memcpy(client->buffer + client->buffer_len, ptr, total_size);
        client->buffer_len += total_size;

        size_t pos = 0;
        while (pos + 5 <= client->buffer_len) {
            uint32_t frame_len = (client->buffer[pos + 1] << 24) |
                                 (client->buffer[pos + 2] << 16) |
                                 (client->buffer[pos + 3] << 8) |
                                 (client->buffer[pos + 4]);
            
            if (pos + 5 + frame_len <= client->buffer_len) {
                process_yellowstone_frame(client, client->buffer + pos + 5, frame_len);
                pos += 5 + frame_len;
            } else {
                break;
            }
        }

        if (pos > 0) {
            memmove(client->buffer, client->buffer + pos, client->buffer_len - pos);
            client->buffer_len -= pos;
        }
    } else {
        client->buffer_len = 0;
    }

    return total_size;
}

static void* stream_thread(void* arg) {
    znode_client_t* client = (znode_client_t*)arg;
    
    while (client->running) {
        CURLcode res = curl_easy_perform(client->curl);
        if (res != CURLE_OK) {
            fprintf(stderr, "[Z-Node] Stream error: %s. Retrying in 5s...\n", curl_easy_strerror(res));
            sleep(5);
        } else {
            // Si el stream termina normalmente (raro en gRPC stream), salimos o reintentamos
            if (client->running) sleep(1);
        }
    }
    return NULL;
}

bool znode_connect(znode_config_t config, znode_on_event_cb callback, void* user_data) {
    if (global_client) return false;

    global_client = calloc(1, sizeof(znode_client_t));
    global_client->config = config;
    global_client->callback = callback;
    global_client->user_data = user_data;
    global_client->socket_fd = -1;
    global_client->running = true;

    curl_global_init(CURL_GLOBAL_ALL);
    global_client->curl = curl_easy_init();

    if (global_client->curl) {
        struct curl_slist* headers = NULL;
        headers = curl_slist_append(headers, "Content-Type: application/grpc");
        
        if (config.token && strlen(config.token) > 0) {
            char token_header[256];
            snprintf(token_header, sizeof(token_header), "x-token: %s", config.token);
            headers = curl_slist_append(headers, token_header);
        }

        curl_easy_setopt(global_client->curl, CURLOPT_URL, config.endpoint);
        curl_easy_setopt(global_client->curl, CURLOPT_HTTPHEADER, headers);
        curl_easy_setopt(global_client->curl, CURLOPT_HTTP_VERSION, CURL_HTTP_VERSION_2_0);
        curl_easy_setopt(global_client->curl, CURLOPT_POST, 1L);
        // El cuerpo del POST para Yellowstone gRPC suele ser vacío o un pequeño frame de suscripción
        // Aquí asumimos que el endpoint ya está configurado para streamear al conectar o enviamos dummy zero
        curl_easy_setopt(global_client->curl, CURLOPT_POSTFIELDS, "\0\0\0\0\0");
        curl_easy_setopt(global_client->curl, CURLOPT_POSTFIELDSIZE, 5L);
        curl_easy_setopt(global_client->curl, CURLOPT_WRITEFUNCTION, write_callback);
        curl_easy_setopt(global_client->curl, CURLOPT_WRITEDATA, global_client);
        curl_easy_setopt(global_client->curl, CURLOPT_PIPEWAIT, 1L);

        if (pthread_create(&global_client->thread, NULL, stream_thread, global_client) != 0) {
            curl_easy_cleanup(global_client->curl);
            free(global_client);
            global_client = NULL;
            return false;
        }

        return true;
    }

    return false;
}

void znode_disconnect() {
    if (global_client) {
        global_client->running = false;
        pthread_join(global_client->thread, NULL);
        if (global_client->socket_fd >= 0) close(global_client->socket_fd);
        if (global_client->curl) curl_easy_cleanup(global_client->curl);
        free(global_client);
        global_client = NULL;
        curl_global_cleanup();
    }
}
