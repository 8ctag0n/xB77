const bs58 = require("bs58");
const str = "namesLPneUptT9mwwHSEiXreK7i3uWz9GZCDD62TVJ";
try {
    const decode = bs58.decode || bs58.default.decode;
    const decoded = decode(str);
    console.log("Length:", decoded.length);
} catch (e) {
    console.log("Error:", e.message);
}
