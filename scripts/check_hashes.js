const { createHash } = require("crypto");
const name = "bonfida";

const sha256 = createHash("sha256").update("SPL Name Service" + name).digest("hex");
const keccak256 = createHash("sha3-256").update("SPL Name Service" + name).digest("hex"); // Not Keccak, let's use the right one

console.log("SHA256:", sha256);
