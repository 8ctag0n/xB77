// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title Groth16Verifier — BN254 Groth16 verifier, agent_badge circuit (3 public inputs)
/// @dev Assembly implementation mirroring xb77_zk_verifier.wasm layout exactly.
///      Proof wire: type_byte(1) | A/G1(64) | B/G2(128) | C/G1(64) = 257 bytes
///      VK ported 1:1 from onchain/stylus/zk_verifier.zig G16_* constants.
///      Gas profile target: honest comparison vs Stylus WASM (~537k net).
contract Groth16Verifier {

    // ── Verifying Key (agent_badge circuit) ───────────────────────────────────

    uint256 constant ALPHA_X = 0x26b0f2f25bea4fb2c5a742478b40a96479ca0881a8871989499f8f65f3fd8da2;
    uint256 constant ALPHA_Y = 0x0ca51e6e61897b94489c4c8c22b1b748efc7cbf30770f8d3a51be164f5bc7bcb;

    // Beta G2 — EIP-197 encoding: x.c1, x.c0, y.c1, y.c0
    uint256 constant BETA_X1 = 0x1efabf0df72158c710999804bec081404ac99680d25ecc994381e80b54c25d74;
    uint256 constant BETA_X0 = 0x2eed3ad410490daaa77830ccd1c3987b1e55e7e84518c90060851095890cfc9a;
    uint256 constant BETA_Y1 = 0x089d039a2850f79e3154c501200e8dd96b7f2a38141bf25b1739e687200f4acb;
    uint256 constant BETA_Y0 = 0x2e15079c3de9d303ce8026363c9b427c9eccccf11a38a5a264b19bd5ed102eae;

    // Gamma G2
    uint256 constant GAMMA_X1 = 0x2afb2d7e310f644633577596fd0d2d4c8d5ac484aa023575cbccb9c7e7469dce;
    uint256 constant GAMMA_X0 = 0x185641e68a00e980d5585cb905ecd20bf69210c2832ca5f032d38d1d20fef944;
    uint256 constant GAMMA_Y1 = 0x2883fa41901dc49991cbdea8e008ba7f3c23f1422c153e26bee302141b4ab56a;
    uint256 constant GAMMA_Y0 = 0x26dbd1741a5317b446caa6cdee70856ed866d82399e70c2ff21bca75edcb7fcc;

    // Delta G2
    uint256 constant DELTA_X1 = 0x27dcba54a1fa2dd1dc848fb083df7b94ca4baedad2701e85da9be1396b710bc8;
    uint256 constant DELTA_X0 = 0x217c7ab4b62eb3c0b39800affb64029bf0a127a68aab2cf614226303689b54f5;
    uint256 constant DELTA_Y1 = 0x22d5995c01e5d57c3241d9ba875ec04683ddc50ff3427f72cc2994c3b6879986;
    uint256 constant DELTA_Y0 = 0x05820662886f4f5d6d70ba5d15fbc9f4496760c6c4ffcf95f4bec72ac996d925;

    // IC (gamma_abc) — IC[0] + sum(pub[i] * IC[i+1])
    uint256 constant IC0_X = 0x18e05ee16a02b53aa18eed3594d766517bfa0b0d04189edc3fcd1c3b4a5301cd;
    uint256 constant IC0_Y = 0x1f6da7b901631e0ee00c03f50a51e129443a189a68b416f0736bf9df83c03f19;
    uint256 constant IC1_X = 0x2000878937d942bb602eb8e3819d723f1c7498867b94536fb788484e3cf9eaf6;
    uint256 constant IC1_Y = 0x132c463300b406a3c6b37f8b474c5db99da435d9f49403b4ebfe3c4c8823facb;
    uint256 constant IC2_X = 0x2defa49e7c9f4fc76df1c2f2b0741539d7e3ba0c3f3247b5d47851ebd87b00f1;
    uint256 constant IC2_Y = 0x023d22f0fde3076cec6c1b8a07ce895bd4a23413b0d02616b1aa5303b5926f8e;
    uint256 constant IC3_X = 0x0f81d1289a46b399df691daabc969781362a3689dbd7a94917f07947578cb4b3;
    uint256 constant IC3_Y = 0x0ff3ec2fa487ab3773ecaf70dd8014a7c9aaa8d6055faf6c8c386f0f0fdf7571;

    // BN254 field prime
    uint256 constant Q  = 0x30644e72e131a029b85045b68181585d97816a916871ca8d3c208c16d87cfd47;
    // BN254 scalar field order
    uint256 constant R  = 0x30644e72e131a029b85045b68181585d2833e84879b9709142e1f38b2a52ed77;

    event ProofVerified(bytes32 indexed publicRoot, bool valid);

    /// @notice Verify a Groth16 proof for agent_badge (3 public inputs).
    /// @param proof   257 bytes: 0x01 | A(64) | B(128) | C(64)
    /// @param publicInputs  Up to 3 BN254 scalar field elements (< R)
    function verifyProof(bytes calldata proof, bytes32[] calldata publicInputs)
        external
        returns (bool valid)
    {
        require(proof.length == 257 && proof[0] == 0x01, "bad proof len/type");
        uint256 nInputs = publicInputs.length;
        require(nInputs <= 3, "too many inputs");

        // ── 1. Parse A, B, C from proof ───────────────────────────────────────
        // proof[1..65]    = A (G1)
        // proof[65..193]  = B (G2, EIP-197: x.c1,x.c0,y.c1,y.c0)
        // proof[193..257] = C (G1)
        uint256 aX; uint256 aY;
        uint256 bX1; uint256 bX0; uint256 bY1; uint256 bY0;
        uint256 cX; uint256 cY;
        assembly {
            // proof.offset points at the first byte of the calldata bytes value (after length).
            // proof[0] = type byte at proof.offset; A starts at proof.offset + 1
            let p := add(proof.offset, 1)
            aX  := calldataload(p)
            aY  := calldataload(add(p, 32))
            bX1 := calldataload(add(p, 64))
            bX0 := calldataload(add(p, 96))
            bY1 := calldataload(add(p, 128))
            bY0 := calldataload(add(p, 160))
            cX  := calldataload(add(p, 192))
            cY  := calldataload(add(p, 224))
        }

        // ── 2. Compute vk_x = IC[0] + Σ pub[i] * IC[i+1]  (ecMul + ecAdd) ──
        uint256 vkX = IC0_X;
        uint256 vkY = IC0_Y;

        for (uint256 i = 0; i < nInputs; i++) {
            uint256 scalar = uint256(publicInputs[i]);

            // ecMul(IC[i+1], scalar) → (mX, mY)
            uint256 icX; uint256 icY;
            if (i == 0) { icX = IC1_X; icY = IC1_Y; }
            else if (i == 1) { icX = IC2_X; icY = IC2_Y; }
            else { icX = IC3_X; icY = IC3_Y; }

            uint256 mX; uint256 mY;
            assembly {
                let mem := mload(0x40)
                mstore(mem,        icX)
                mstore(add(mem, 32), icY)
                mstore(add(mem, 64), scalar)
                // ecMul precompile: 0x07
                let ok := staticcall(gas(), 0x07, mem, 96, mem, 64)
                if iszero(ok) { revert(0, 0) }
                mX := mload(mem)
                mY := mload(add(mem, 32))
            }

            // ecAdd(vk_x, (mX, mY)) → new vk_x
            assembly {
                let mem := mload(0x40)
                mstore(mem,         vkX)
                mstore(add(mem, 32), vkY)
                mstore(add(mem, 64), mX)
                mstore(add(mem, 96), mY)
                // ecAdd precompile: 0x06
                let ok := staticcall(gas(), 0x06, mem, 128, mem, 64)
                if iszero(ok) { revert(0, 0) }
                vkX := mload(mem)
                vkY := mload(add(mem, 32))
            }
        }

        // ── 3. Negate A: (aX, aY) → (aX, Q - aY) ────────────────────────────
        uint256 negAY;
        assembly {
            negAY := sub(Q, mod(aY, Q))
        }

        // ── 4. 4-pair ecPairing: e(-A,B) · e(α,β) · e(vk_x,γ) · e(C,δ) == 1 ─
        // Input layout: 4 × 192 bytes = 768 bytes
        // Each pair: G1(64) || G2(128)  in EIP-197 encoding
        assembly {
            let mem := mload(0x40)

            // pair 0: (-A, B)
            mstore(mem,          aX)
            mstore(add(mem, 32), negAY)
            mstore(add(mem, 64), bX1)
            mstore(add(mem, 96), bX0)
            mstore(add(mem,128), bY1)
            mstore(add(mem,160), bY0)

            // pair 1: (α, β)
            mstore(add(mem,192), ALPHA_X)
            mstore(add(mem,224), ALPHA_Y)
            mstore(add(mem,256), BETA_X1)
            mstore(add(mem,288), BETA_X0)
            mstore(add(mem,320), BETA_Y1)
            mstore(add(mem,352), BETA_Y0)

            // pair 2: (vk_x, γ)
            mstore(add(mem,384), vkX)
            mstore(add(mem,416), vkY)
            mstore(add(mem,448), GAMMA_X1)
            mstore(add(mem,480), GAMMA_X0)
            mstore(add(mem,512), GAMMA_Y1)
            mstore(add(mem,544), GAMMA_Y0)

            // pair 3: (C, δ)
            mstore(add(mem,576), cX)
            mstore(add(mem,608), cY)
            mstore(add(mem,640), DELTA_X1)
            mstore(add(mem,672), DELTA_X0)
            mstore(add(mem,704), DELTA_Y1)
            mstore(add(mem,736), DELTA_Y0)

            // ecPairing precompile: 0x08, 768 bytes input → 32 bytes output
            let ok := staticcall(gas(), 0x08, mem, 768, mem, 32)
            if iszero(ok) { revert(0, 0) }
            valid := mload(mem)
        }

        bytes32 pubRoot = publicInputs.length > 0 ? publicInputs[0] : bytes32(0);
        emit ProofVerified(pubRoot, valid);
    }
}
