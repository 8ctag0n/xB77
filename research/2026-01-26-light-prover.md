# Investigación: Prover en el repo Light

Fecha: 2026-01-26

## Resumen ejecutivo
- El repo contiene **dos “provers” distintos**: (1) un **wrapper local** en `scripts/light/local/prover.ts` que expone `/prove` y puede proxyear a un upstream, y (2) el **prover real de Light Protocol** en `light-protocol/prover/server`, escrito en Go y basado en **gnark**, que implementa el endpoint `/prove` y la cola Redis opcional.
- Los **circuitos** para el prover real están definidos en Go (gnark) bajo `light-protocol/prover/server/prover/v1/` y `light-protocol/prover/server/prover/v2/`, con helpers para construir R1CS y generar pruebas. Además, el repo tiene circuitos Noir para `agent_badge` en `circuits/agent_badge` con scripts de compilación separados.
- Los **scripts para arrancar `/prove`** incluyen: el wrapper local con Bun (`scripts/light/local/prover.ts`), el CLI de Light Protocol que descarga y ejecuta el binario (`light-protocol/cli/...`), y el servidor Go (`light-protocol/prover/server`) que se inicia con `light-prover start` o `go build` + `light-prover --config ...`.

## Hallazgos clave (con evidencia)

### 1) Dónde se construyen los circuits
**A. Prover de Light Protocol (gnark, Go)**
- Los circuitos “core” del prover están implementados como structs de gnark y compilados a R1CS en Go.
- Ejemplo: `BatchAppendCircuit` define la lógica y se compila con `frontend.Compile(...)` en `light-protocol/prover/server/prover/v2/batch_append_circuit.go`. Esto es la base para la generación de pruebas (`groth16.Setup/Prove`).
- Se observan múltiples circuitos y versiones:
  - V2: `light-protocol/prover/server/prover/v2/` (batch append, batch update/nullify, batch address append, inclusion, non-inclusion, combined, etc.).
  - V1: `light-protocol/prover/server/prover/v1/` (legacy inclusion, combined, non-inclusion, circuit_builder, etc.).

Evidencia:
- Definición/compilación de circuito gnark en `BatchAppendCircuit` y `R1CSBatchAppend` (Go + gnark). `light-protocol/prover/server/prover/v2/batch_append_circuit.go`.

**B. Scripts para generar R1CS/keys (gnark)**
- El script `light-protocol/scripts/tsc-create-r1cs.sh` usa el binario `./prover/server/light-prover r1cs` para generar R1CS y luego `import-setup` para exportar proving keys a `prover/server/proving-keys/`.

Evidencia:
- `light-protocol/scripts/tsc-create-r1cs.sh` invoca `light-prover r1cs` y `light-prover import-setup`.

**C. Circuitos Noir del repo (agent_badge)**
- Existe un circuito Noir separado en `circuits/agent_badge` (con `Nargo.toml`), compilado con scripts propios:
  - `scripts/build-noir-artifacts.sh` (usa contenedor `xb77-noir:0.36.0` y copia JSON a `sdk/src/artifacts`).
  - `scripts/noir-compile-sunspot.sh` (usa Sunspot y Noir 1.0.0-beta.13 para `nargo compile`).
  - `scripts/noir-execute*.sh` (genera test witness / artifacts).

Evidencia:
- `circuits/agent_badge/Nargo.toml`.
- `scripts/build-noir-artifacts.sh`, `scripts/noir-compile-sunspot.sh`, `scripts/noir-execute-sunspot.sh`, `scripts/noir-execute.sh`.

---

### 2) Scripts/entradas que arrancan el servicio `/prove`

**A. Wrapper local (Bun) con `/prove`**
- `scripts/light/local/prover.ts` crea un HTTP server que escucha por defecto en `127.0.0.1:3001`, expone `/prove` y si se configura `LIGHT_UPSTREAM_PROVER_URL` proxy a `.../prove`. Si no hay upstream, responde `501`.

Evidencia:
- `scripts/light/local/prover.ts` y `scripts/light/local/README.md`.

**B. Prover server real (Go, gnark)**
- El router principal registra `/prove` en `light-protocol/prover/server/server/server.go` usando `proverMux.Handle("/prove", proveHandler{...})`, además de `/health` y endpoints de cola/metrics.

Evidencia:
- `light-protocol/prover/server/server/server.go`.

**C. CLI de Light Protocol (descarga binario + arranque)**
- `light-protocol/cli/src/commands/start-prover/index.ts` ejecuta `startProver(...)`, que descarga el binario (`downloadProverBinary`) si es necesario y lo arranca con argumentos `start --keys-dir ... --prover-address ... --auto-download true`.
- `light-protocol/cli/src/commands/test-validator/index.ts` puede arrancar el prover como parte de `light test-validator` (o saltarlo con `--skip-prover`).

Evidencia:
- `light-protocol/cli/src/commands/start-prover/index.ts`.
- `light-protocol/cli/src/utils/processProverServer.ts`.
- `light-protocol/cli/src/commands/test-validator/index.ts`.

**D. Ejecutable directo del prover (Go)**
- `light-protocol/prover/server/README.md` documenta `go build .` y `light-prover --config <file>` y `light-prover start` con `/prove` y `/metrics`.

Evidencia:
- `light-protocol/prover/server/README.md`.

---

### 3) Dependencias requeridas (prover y entorno)

**A. Prover real (Go + gnark)**
- El servidor del prover está en Go y depende de gnark/gnark-crypto, Redis client, Prometheus, etc. (`go.mod`).
- Las pruebas usan/arrancan `spawn_prover` desde `light-prover-client` en varios tests.

Evidencia:
- `light-protocol/prover/server/go.mod`.
- Referencias a `light-prover-client` en `light-protocol/...` (ej. `sdk-libs/client` y `program-tests`).

**B. Proving keys descargadas automáticamente**
- `prover/common/key_downloader.go` descarga proving keys desde GCS (`storage.googleapis.com/light-protocol-proving-keys/...`) con reintentos y checksum.
- El CLI de Light Protocol inicia el binario con `--auto-download true` y `--keys-dir ~/.config/light/proving-keys`.

Evidencia:
- `light-protocol/prover/server/prover/common/key_downloader.go`.
- `light-protocol/cli/src/utils/processProverServer.ts`.

**C. Redis (opcional, para cola)**
- El prover soporta cola Redis; `server.go` habilita endpoints `/prove/status`, `/queue/*` cuando hay Redis configurado.
- `server/queue.go` crea cliente Redis y opera colas, deduplicación y cache de resultados.

Evidencia:
- `light-protocol/prover/server/server/server.go`.
- `light-protocol/prover/server/server/queue.go`.

**D. Wrapper local (Bun)**
- El wrapper local se ejecuta con Bun (`bun scripts/light/local/prover.ts`) y requiere variables de entorno para endpoints.

Evidencia:
- `scripts/light/local/README.md`.
- `scripts/light/local/prover.ts`.

**E. Circuitos Noir (si aplica al flujo del repo)**
- Requiere contenedor con noirup y herramientas asociadas (ver `containers/noir/Containerfile` y `containers/sunspot/Containerfile`).

Evidencia:
- `containers/noir/Containerfile`.
- `containers/sunspot/Containerfile`.

---

## Paths relevantes (lista rápida)
- Prover Go (Light Protocol):
  - `light-protocol/prover/server/` (main + README + Docker)
  - `light-protocol/prover/server/server/server.go` (routing `/prove`)
  - `light-protocol/prover/server/prover/v1/` y `light-protocol/prover/server/prover/v2/` (circuitos gnark)
  - `light-protocol/prover/server/prover/common/key_downloader.go` (auto-download keys)
- Scripts de generación de circuits/keys (gnark):
  - `light-protocol/scripts/tsc-create-r1cs.sh`
- CLI que arranca el prover:
  - `light-protocol/cli/src/commands/start-prover/index.ts`
  - `light-protocol/cli/src/utils/processProverServer.ts`
  - `light-protocol/cli/src/commands/test-validator/index.ts`
- Wrapper local `/prove` (Bun):
  - `scripts/light/local/prover.ts`
  - `scripts/light/local/README.md`
- Circuitos Noir del repo:
  - `circuits/agent_badge/`
  - `scripts/build-noir-artifacts.sh`
  - `scripts/noir-compile-sunspot.sh`
  - `scripts/noir-execute-sunspot.sh`
  - `containers/noir/Containerfile`
  - `containers/sunspot/Containerfile`

## Método y rastreo de evidencia
- Búsquedas locales con `rg` para “prover”, “/prove”, “circuit”, y revisión directa de archivos clave.
- Lectura de scripts y archivos fuente en `scripts/`, `light-protocol/prover/server`, `light-protocol/cli`, `circuits/`.

## Incertidumbres / preguntas abiertas
- No se identificó en este repo un script que “wiree” explícitamente el wrapper local (Bun) con el prover real; parece ser un stub/proxy. Si hay un flujo esperado (por ejemplo, apuntar a un prover externo) necesitaría confirmación del entorno de ejecución.
- La generación de proving keys (gnark) parece depender de tooling externo (`semaphore-mtb-setup`, ptau, contribuciones). No está automatizado en un único script de CI.

## Fuentes (archivos del repo)
- `scripts/light/local/prover.ts`
- `scripts/light/local/README.md`
- `light-protocol/prover/server/README.md`
- `light-protocol/prover/server/server/server.go`
- `light-protocol/prover/server/prover/v2/batch_append_circuit.go`
- `light-protocol/scripts/tsc-create-r1cs.sh`
- `light-protocol/cli/src/commands/start-prover/index.ts`
- `light-protocol/cli/src/utils/processProverServer.ts`
- `light-protocol/cli/src/commands/test-validator/index.ts`
- `light-protocol/prover/server/go.mod`
- `light-protocol/prover/server/prover/common/key_downloader.go`
- `light-protocol/prover/server/server/queue.go`
- `circuits/agent_badge/Nargo.toml`
- `scripts/build-noir-artifacts.sh`
- `scripts/noir-compile-sunspot.sh`
- `scripts/noir-execute-sunspot.sh`
- `containers/noir/Containerfile`
- `containers/sunspot/Containerfile`
