const { getDomainKeySync } = require("@bonfida/spl-name-service");
const { domain, pubkey } = getDomainKeySync("bonfida");
console.log("Domain PDA:", pubkey.toBase58());
