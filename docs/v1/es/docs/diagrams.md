---
pageClass: is-legacy-page
---
# Arquitectura del Sistema y Flujo de Datos xB77

## 1. Flujo de Tesorería de Alto Nivel
Este diagrama ilustra cómo se mueve la liquidez desde fuentes públicas hacia operaciones protegidas y optimización de rendimiento.

```mermaid
graph TD
    A[Fuente Pública: Starpay/Bóveda] -->|Fondear| B(xB77 Liquidity Manager)
    B -->|Verificar Umbrales| C{Decisión Estratégica}
    C -->|Capital Ocioso| D[Proveedor Yield: Kamino]
    C -->|Necesidad Operativa| E[Riel Privado: ShadowWire]
    D -->|Devengar Intereses| B
    E -->|Pago B2B| F[Comerciante/Proveedor]
    F -->|Generar Prueba| G[Almacén de Recibos Certificados]
```

## 2. Bucle de Decisión Autónoma (Motor de Estrategia)
El proceso que sigue un agente antes de ejecutar cualquier instrucción financiera.

```mermaid
graph LR
    Start[Inicio: Solicitud de Pago] --> Risk[Escaneo Helius y Range]
    Risk --> Score{Puntaje de Riesgo}
    Score -->|Bajo| Public[Ruta Pública: Starpay]
    Score -->|Medio| Shield[Ruta Protegida: ShadowWire]
    Score -->|Alto| Ghost[Modo Fantasma: Burner Relay]
    Score -->|Sancionado| Block[Bloquear Transacción]
    
    Public --> Audit[Generar Recibo Certificado]
    Shield --> Audit
    Ghost --> Audit
```

## 3. Revelación Selectiva Certificada (Auditoría)
Cómo el agente prueba sus gastos a un auditor externo sin comprometer la privacidad global.

```mermaid
sequenceDiagram
    participant Auditor as Auditor Externo
    participant Hub as Interfaz Hub
    participant Agent as Agente xB77
    participant Store as Almacén Privado

    Auditor->>Hub: Solicitar prueba para INV-001
    Hub->>Agent: Llamar agent.audit.report(receiptId)
    Agent->>Store: Recuperar recibo privado completo
    Agent->>Agent: Extraer campos solicitados
    Agent->>Agent: Firmar campos con Clave Secreta
    Agent-->>Hub: Prueba Certificada + Atestación
    Hub-->>Auditor: Mostrar Factura Verificable
```
