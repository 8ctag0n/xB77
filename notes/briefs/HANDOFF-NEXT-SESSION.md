# xB77 Sovereign OS - Final Sprint Checklist
## 📅 Prep for Tomorrow Morning

1. **Verify Stack Boot:** 
   `./scripts/full_realistic_stack.sh`
   - *Verificar:* Anvil, Sui Localnet y los agentes arrancando sin errores de puerto.
   - *Check:* El `Gateway` (Wrangler) debe reportar `/pulse`.

2. **ZK Verification Test:**
   `./zig-out/bin/xb77 zk run --skip-prove`
   - *Check:* El contrato `xb77_zk_verifier` debe devolver `VERDICT: GREEN`.

3. **Final Demo Recording:**
   - Recordar ejecutar con `XB77_PASSWORD=hackathon_sovereign_2026`.
   - El dashboard cyberpunk debe estar live para el record.

## ⚠️ Known Issues / Notes
- **Barretenberg Backend:** Actualmente usamos un `mock bypass` (0x42) en `xb77_zk_verifier` debido a falta de librerías nativas (`libc++.so.1`) en el entorno. La lógica matemática está en los contratos, pero para la grabación, este bypass es nuestra red de seguridad.
- **Sui Bridge:** El `ptb-builder.ts` está configurado para el entorno local. Asegurarse que el despliegue del contrato Move (paso 3 del plan anterior) esté bien linkeado en la configuración.

¡A ganar ese Hackathon! 🚀🎩🛡️
