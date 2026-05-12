const bs58 = require("bs58");
const str = "namesLPneUptT9mwwHSEiXreK7i3uWz9GZCDD62TVJ";
try {
    const decoded = bs58.decode(str);
    console.log("Length:", decoded.length);
} catch (e) {
    console.log("Error:", e.message);
}
