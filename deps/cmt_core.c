#include "cmt_core.h"
#include <string.h>

// --- Sovereign Keccak-256 (Fixed & Optimized) ---
#define ROTL64(x, y) (((x) << (y)) | ((x) >> (64 - (y))))

static const uint64_t keccakf_rndc[24] = {
    0x0000000000000001ULL, 0x0000000000008082ULL, 0x800000000000808aULL,
    0x8000000080008000ULL, 0x000000000000808bULL, 0x0000000080000001ULL,
    0x8000000080008081ULL, 0x8000000000008009ULL, 0x000000000000008aULL,
    0x0000000000000088ULL, 0x0000000080008009ULL, 0x000000008000000aULL,
    0x000000008000808bULL, 0x800000000000008bULL, 0x8000000000008089ULL,
    0x8000000000008003ULL, 0x8000000000008002ULL, 0x8000000000000080ULL,
    0x000000000000800aULL, 0x800000008000000aULL, 0x8000000080008081ULL,
    0x8000000000008080ULL, 0x0000000080000001ULL, 0x8000000080008008ULL
};

static const int keccakf_rotc[24] = {
    1, 3, 6, 10, 15, 21, 28, 36, 45, 55, 2, 14, 27, 44, 62, 8, 25, 43, 62, 18, 39, 61, 20, 44
};

static const int keccakf_piln[24] = {
    10, 7, 11, 17, 18, 3, 5, 16, 8, 21, 24, 4, 15, 23, 19, 13, 12, 2, 20, 14, 22, 9, 6, 1
};

static void keccakf(uint64_t st[25]) {
    int i, j, r;
    uint64_t t, bc[5];

    for (r = 0; r < 24; r++) {
        // Theta
        for (i = 0; i < 5; i++)
            bc[i] = st[i] ^ st[i + 5] ^ st[i + 10] ^ st[i + 15] ^ st[i + 20];
        for (i = 0; i < 5; i++) {
            t = bc[(i + 4) % 5] ^ ROTL64(bc[(i + 1) % 5], 1);
            for (j = 0; j < 25; j += 5) st[j + i] ^= t;
        }
        // Rho and pi
        t = st[1];
        for (i = 0; i < 24; i++) {
            j = keccakf_piln[i];
            bc[0] = st[j];
            st[j] = ROTL64(t, keccakf_rotc[i]);
            t = bc[0];
        }
        // Chi
        for (j = 0; j < 25; j += 5) {
            for (i = 0; i < 5; i++) bc[i] = st[j + i];
            for (i = 0; i < 5; i++) st[j + i] ^= (~bc[(i + 1) % 5]) & bc[(i + 2) % 5];
        }
        // Iota
        st[0] ^= keccakf_rndc[r];
    }
}

void cmt_keccak256(const uint8_t* data, size_t len, uint8_t* out) {
    uint64_t st[25];
    memset(st, 0, sizeof(st));

    const size_t rate = 136;
    size_t pos = 0;

    // Absorb full blocks
    while (len - pos >= rate) {
        for (int i = 0; i < 17; i++) {
            uint64_t val = 0;
            for (int k = 0; k < 8; k++) val |= ((uint64_t)data[pos + i * 8 + k]) << (k * 8);
            st[i] ^= val;
        }
        keccakf(st);
        pos += rate;
    }

    // Handle last block with padding
    uint8_t temp[136];
    size_t remaining = len - pos;
    memcpy(temp, data + pos, remaining);
    temp[remaining] = 0x01;
    memset(temp + remaining + 1, 0, rate - remaining - 1);
    temp[rate - 1] |= 0x80;

    for (int i = 0; i < 17; i++) {
        uint64_t val = 0;
        for (int k = 0; k < 8; k++) val |= ((uint64_t)temp[i * 8 + k]) << (k * 8);
        st[i] ^= val;
    }
    keccakf(st);

    // Squeeze out 32 bytes (4 words)
    for (int i = 0; i < 4; i++) {
        for (int k = 0; k < 8; k++) out[i * 8 + k] = (uint8_t)(st[i] >> (k * 8));
    }
}

int cmt_verify_proof(const cmt_hash_t* root, const cmt_hash_t* leaf, uint64_t index, const cmt_hash_t* proof, uint8_t depth) {
    cmt_hash_t current = *leaf;
    for (uint8_t i = 0; i < depth; i++) {
        cmt_hash_t out;
        if ((index >> i) & 1) {
            cmt_hash_nodes(&proof[i], &current, &out);
        } else {
            cmt_hash_nodes(&current, &proof[i], &out);
        }
        current = out;
    }
    return memcmp(current.hash, root->hash, 32) == 0;
}

void cmt_get_proof(const cmt_hash_t* tree_nodes, uint64_t leaf_index, uint8_t depth, cmt_hash_t* out_siblings) {
    uint64_t current_idx = ((uint64_t)1 << depth) - 1 + leaf_index;
    for (uint8_t i = 0; i < depth; i++) {
        uint64_t sibling_idx = (current_idx % 2 == 0) ? current_idx - 1 : current_idx + 1;
        out_siblings[i] = tree_nodes[sibling_idx];
        current_idx = (current_idx - 1) / 2;
    }
}

void cmt_update_node(cmt_hash_t* tree_nodes, uint64_t leaf_index, uint8_t depth, cmt_hash_t new_leaf) {
    uint64_t current_idx = ((uint64_t)1 << depth) - 1 + leaf_index;
    tree_nodes[current_idx] = new_leaf;
    while (current_idx > 0) {
        uint64_t parent_idx = (current_idx - 1) / 2;
        uint64_t left_idx, right_idx;
        if (current_idx % 2 == 0) {
            left_idx = current_idx - 1;
            right_idx = current_idx;
        } else {
            left_idx = current_idx;
            right_idx = current_idx + 1;
        }
        cmt_hash_nodes(&tree_nodes[left_idx], &tree_nodes[right_idx], &tree_nodes[parent_idx]);
        current_idx = parent_idx;
    }
}
