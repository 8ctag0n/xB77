#ifndef CMT_CORE_H
#define CMT_CORE_H

#include <stdint.h>
#include <stddef.h>

// CMT Core - Motor de Compresión Soberana (C Implementation)
// Diseñado para ser integrado en Zig y C-based Nodes.

typedef struct {
    uint8_t hash[32];
} cmt_hash_t;

typedef struct {
    uint8_t depth;
    size_t max_nodes;
    cmt_hash_t* nodes; // Array plano para el árbol (si cabe en memoria)
} cmt_tree_t;

// Hashing ultra-rápido usando Keccak (debe ser proveído externamente o por crypto.zig)
extern void cmt_keccak256(const uint8_t* data, size_t len, uint8_t* out);

// Calcula el hash de un nodo padre a partir de dos hijos.
static inline void cmt_hash_nodes(const cmt_hash_t* left, const cmt_hash_t* right, cmt_hash_t* out) {
    uint8_t buf[64];
    for(int i=0; i<32; i++) {
        buf[i] = left->hash[i];
        buf[i+32] = right->hash[i];
    }
    cmt_keccak256(buf, 64, out->hash);
}

// Verifica una prueba de inclusión. 1 = OK, 0 = FAIL.
int cmt_verify_proof(const cmt_hash_t* root, const cmt_hash_t* leaf, uint64_t index, const cmt_hash_t* proof, uint8_t depth);

// Genera los siblings (prueba) para un índice dado.
void cmt_get_proof(const cmt_hash_t* tree_nodes, uint64_t index, uint8_t depth, cmt_hash_t* out_siblings);

// Actualiza un nodo y recalcula sus ancestros hacia arriba (re-hashing).
void cmt_update_node(cmt_hash_t* tree_nodes, uint64_t index, uint8_t depth, cmt_hash_t new_leaf);

#endif // CMT_CORE_H
