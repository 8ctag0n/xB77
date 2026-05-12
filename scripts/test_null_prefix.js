const { createHash } = require("crypto");
const name = "bonfida";
const hashed = createHash("sha256").update(Buffer.concat([Buffer.alloc(1, 0), Buffer.from(name)])).digest("hex");
console.log("Hashed Name (null-prefix):", hashed);
