#!/usr/bin/env bash
# scripts/demo_deluxe_test.sh - Smoke test para asegurar que el agente esté demo-ready.

set -e

# Configuración
export XB77_PASSWORD=password123
export XB77_DEMO_MODE=1
BIN="./zig-out/bin/xb77"

echo "--- 🚀 Iniciando Smoke Test Deluxe ---"

# 1. Limpiar estado previo
pkill -f "xb77 -p alpha serve" || true
rm -rf .xb77/alpha

# 2. Inicializar
echo "[1/4] Inicializando agente..."
$BIN -p alpha init > /dev/null

# 3. Levantar servicio en background
echo "[2/4] Levantando servicio de agente..."
$BIN -p alpha serve --gateway https://api.devnet.solana.com > serve.log 2>&1 &
AGENT_PID=$!
sleep 3

# 4. Verificar status
echo "[3/4] Verificando status..."
$BIN -p alpha status --gateway https://api.devnet.solana.com | grep "SOVEREIGN_COMPUTING_ACTIVE"

# 5. Ejecutar misión Deluxe
echo "[4/4] Ejecutando misión Deluxe..."
$BIN -p alpha issue "Verify treasury state" --gateway https://api.devnet.solana.com

# Cleanup
kill $AGENT_PID
echo "--- ✅ Smoke Test Deluxe completado con éxito ---"
