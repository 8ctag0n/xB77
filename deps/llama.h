#ifndef LLAMA_H
#define LLAMA_H

#include <stddef.h>
#include <stdint.h>
#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

struct llama_model;
struct llama_context;

struct llama_model_params {
    int32_t n_gpu_layers;
    bool vocab_only;
    bool use_mmap;
    bool use_mlock;
};

struct llama_context_params {
    uint32_t n_ctx;
    uint32_t n_batch;
    uint32_t n_threads;
    uint32_t n_threads_batch;
};

typedef int32_t llama_token;

struct llama_batch {
    int32_t n_tokens;
    llama_token * token;
    float * embd;
    int32_t * pos;
    int32_t * n_seq_id;
    int32_t ** seq_id;
    int8_t * logits;
};

void llama_backend_init(void);
struct llama_model_params llama_model_default_params(void);
struct llama_context_params llama_context_default_params(void);
struct llama_model * llama_model_load_from_file(const char * path_model, struct llama_model_params params);
struct llama_context * llama_init_from_model(struct llama_model * model, struct llama_context_params params);
void llama_free(struct llama_context * ctx);
void llama_model_free(struct llama_model * model);

int32_t llama_tokenize(const struct llama_model * model, const char * text, int32_t text_len, llama_token * tokens, int32_t n_max_tokens, bool add_special, bool parse_special);
int32_t llama_decode(struct llama_context * ctx, struct llama_batch batch);
float * llama_get_logits_ith(struct llama_context * ctx, int32_t i);
const char * llama_token_to_piece(const struct llama_model * model, llama_token token, char * buf, int32_t length, bool special);

struct llama_batch llama_batch_init(int32_t n_tokens, int32_t embd, int32_t n_seq_max);
void llama_batch_free(struct llama_batch batch);

#ifdef __cplusplus
}
#endif

#endif
