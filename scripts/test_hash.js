const { createHash } = require("crypto");
const name = "bonfida";
const prefix = "SPL Name Service";
const hash = createHash("sha256").update(prefix + name).digest("hex");
console.log("Hash:", hash);
