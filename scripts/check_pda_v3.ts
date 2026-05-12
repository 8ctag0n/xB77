import { createHash } from "crypto";
import { PublicKey } from "@solana/web3.js"; // I'll use it just for display comparison if needed, or skip it

const domain = "bonfida";
const target = "Fw1ETanDZafof7xEULsnq9UY6o71Tpds89tNwPkWLb1v"; // This is the owner, NOT the registry account!

console.log("Domain:", domain);
console.log("Target Owner:", target);

// The registry account address for bonfida.sol is actually:
// 7kvXEnfjfqP6MkCmJhkGFzpLDohJqaXiDTT73vvP3FiZ
const registry = "7kvXEnfjfqP6MkCmJhkGFzpLDohJqaXiDTT73vvP3FiZ";
console.log("Registry (Known):", registry);
