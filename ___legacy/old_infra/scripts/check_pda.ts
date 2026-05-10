import { Connection, PublicKey } from '@solana/web3.js';

async function main() {
    const coreId = new PublicKey("5M5LkrMSKXSYkTDF93te6qnSMBMiG6fP4AJuGuDm4XJm");
    const [configPda] = PublicKey.findProgramAddressSync([Buffer.from("config")], coreId);
    console.log("Config PDA:", configPda.toBase58());

    const connection = new Connection('http://127.0.0.1:8899', 'confirmed');
    const acc = await connection.getAccountInfo(configPda);
    if (!acc) {
        console.log("ACCOUNT NOT FOUND - FRESH STATE");
    } else {
        console.log("ACCOUNT EXISTS - DATA LENGTH:", acc.data.length);
        console.log("OWNER:", acc.owner.toBase58());
        // Read admin (first 32 bytes)
        const admin = new PublicKey(acc.data.slice(0, 32));
        console.log("ADMIN IN STATE:", admin.toBase58());
    }
}

main();
