#include "znode.h"
#include <curl/curl.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/socket.h>
#include <sys/un.h>

typedef struct {
    znode_config_t config;
    znode_on_event_cb callback;
    void* user_data;
    CURL* curl;
    int socket_fd;
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

static size_t write_callback(char* ptr, size_t size, size_t nmemb, void* userdata) {
    znode_client_t* client = (znode_client_t*)userdata;
    size_t total_size = size * nmemb;

    // Intentar reconectar si el socket se cerró
    if (client->socket_fd < 0) {
        client->socket_fd = connect_to_bridge();
    }

    // MANDAR DATA CRUDA AL BRIDGE EN ZIG
    if (client->socket_fd >= 0) {
        if (send(client->socket_fd, ptr, total_size, MSG_NOSIGNAL) < 0) {
            close(client->socket_fd);
            client->socket_fd = -1;
        }
    }

    if (client->callback) {
        client->callback(ZNODE_EVENT_TRANSACTION, ptr, client->user_data);
    }

    return total_size;
}

bool znode_connect(znode_config_t config, znode_on_event_cb callback, void* user_data) {
    if (global_client) return false;

    global_client = calloc(1, sizeof(znode_client_t));
    global_client->config = config;
    global_client->callback = callback;
    global_client->user_data = user_data;
    global_client->socket_fd = -1;

    curl_global_init(CURL_GLOBAL_ALL);
    global_client->curl = curl_easy_init();

    if (global_client->curl) {
        struct curl_slist* headers = NULL;
        headers = curl_slist_append(headers, "Content-Type: application/grpc");
        
        char token_header[256];
        snprintf(token_header, sizeof(token_header), "x-token: %s", config.token);
        headers = curl_slist_append(headers, token_header);

        curl_easy_setopt(global_client->curl, CURLOPT_URL, config.endpoint);
        curl_easy_setopt(global_client->curl, CURLOPT_HTTPHEADER, headers);
        curl_easy_setopt(global_client->curl, CURLOPT_HTTP_VERSION, CURL_HTTP_VERSION_2_0);
        curl_easy_setopt(global_client->curl, CURLOPT_POST, 1L);
        curl_easy_setopt(global_client->curl, CURLOPT_WRITEFUNCTION, write_callback);
        curl_easy_setopt(global_client->curl, CURLOPT_WRITEDATA, global_client);

        return true;
    }

    return false;
}

void znode_disconnect() {
    if (global_client) {
        if (global_client->socket_fd >= 0) close(global_client->socket_fd);
        if (global_client->curl) curl_easy_cleanup(global_client->curl);
        free(global_client);
        global_client = NULL;
        curl_global_cleanup();
    }
}
