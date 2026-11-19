# docs/ — mapa del repositorio

Primera lectura de cada sesión (§2.1 de `AGENTS.md`). Actualizado el 2026-11-19,
cuando todo el repositorio pasó a vivir bajo `docs/`.

`docs/` tiene dos mitades que no se mezclan: el **conocimiento** (reglas,
procedimientos, decisiones) y las **consultas ejecutables**.

## Conocimiento

| Ruta | Contenido |
|---|---|
| [mcp-registry.md](mcp-registry.md) | Capacidad → servidor MCP, con qué se verificó cada uno y cuáles estaban caídos. |
| [domain/atrasos.md](domain/atrasos.md) | `vm_atrasos`: el reporte de atrasos y faltas injustificadas de Talento Humano, sus versiones y el soporte de festivos. |
| [domain/moldes.md](domain/moldes.md) | `SB1_VIEW_ANALISIS_MOLDES` y sus objetos base, con las dependencias por tabla de B1. |
| [domain/notas-credito.md](domain/notas-credito.md) | Notas de crédito del BI de Gerencia: grano de cabecera y detalle, y por qué los montos van positivos frente a las vistas de venta. |
| [domain/rrhh-tablero-powerbi.md](domain/rrhh-tablero-powerbi.md) | Arquitectura del tablero de RRHH: TCONTROL (biométrico) + ONLYCONTROL (maestros). |
| [domain/stock-definiciones-vigentes.md](domain/stock-definiciones-vigentes.md) | Cuál de las dos definiciones de `SB1_VIEW_REVISION_STOCK_V2` y `SB1_VIEW_REPORTE_STOCK_CRITICO` es la que corre en HANA, con la evidencia. Verificado el 2026-11-19. |
| [runbooks/ausentismo.md](runbooks/ausentismo.md) | Qué dos scripts de ausentismo son los vigentes, en qué servidor y base corre cada uno y en qué orden. |
| [runbooks/powerbi-rrhh-consultas-diarias.md](runbooks/powerbi-rrhh-consultas-diarias.md) | Consultas de uso diario del tablero de RRHH. |
| [plans/2026-11-19-bootstrap-protocolo-agentes.md](plans/2026-11-19-bootstrap-protocolo-agentes.md) | Puesta en marcha del protocolo de `AGENTS.md`. Implementado. |
| [plans/2026-11-19-reorganizar-consultas-por-dominio.md](plans/2026-11-19-reorganizar-consultas-por-dominio.md) | Esta reorganización: mapeo completo de qué se movió y por qué. |
| `adr/` | **Aún no existe.** Primer candidato: por qué la cadena de alertas es HANA → `OPENQUERY` → Python y no una consulta directa. |
| `integrations/` | **Aún no existe.** Primeros candidatos: `timecontrol.md` y `fracttal.md`. |

## Consultas

[consultas/README.md](consultas/README.md) es el índice de los 12 dominios y las
reglas para un pedido nuevo. Cada dominio tiene su propio `README.md` con el
motor, el servidor y el orden de despliegue de cada archivo.

| Dominio | Atajo | Ojo con |
|---|---|---|
| [activos-fijos/](consultas/activos-fijos/README.md) | Power BI de activos, exportes de Fracttal | Códigos Beas ≠ códigos Fracttal |
| [apps/](consultas/apps/README.md) | Auth, DDL, NPS (PostgreSQL) | La configuración de NPS empieza con `TRUNCATE` |
| [cartera/](consultas/cartera/README.md) | Bloqueos y vencidas | `DocDueDate` ya incluye el crédito |
| [compras/](consultas/compras/README.md) | Cadena de alerta de OC | El alcance (serie OCNAC, abiertos) está en el `WHERE` de la vista de HANA |
| [eficiencia-energetica/](consultas/eficiencia-energetica/README.md) | Combustible | La otra mitad del indicador está en `produccion/` |
| [inventario/](consultas/inventario/README.md) | Stock, antigüedad, UPC | La vista viva es la que aún tiene el ajuste `- 74250` |
| [logistica/](consultas/logistica/README.md) | Pallets, traslados | El flujo lo escribe n8n con `U_EntregaRef` |
| [plataforma/](consultas/plataforma/README.md) | Administración B1, ops | Contraseña en claro sin rotar en `ops/creacion-usuario-ia.sql` |
| [produccion/](consultas/produccion/README.md) | Transformados, trazabilidad, moldes | El enlace con Beas va por `U_EMPA_COD_BEAS` |
| [rrhh/](consultas/rrhh/README.md) | Ausentismo, atrasos, permisos | Tres servidores distintos; dos definen `vm_atrasos` |
| [supply/](consultas/supply/README.md) | Cadena de stock crítico | Desplegar el `.sql` homónimo rompe la alerta: renombra dos columnas |
| [ventas/](consultas/ventas/README.md) | Notas de crédito, pricing | El `.py` y su `.sql` deben quedar en la misma carpeta |

[catalogo/guia-consultas.html](catalogo/guia-consultas.html) es la guía
interactiva del inventario.

## Fuera de docs/

| Ruta | Contenido |
|---|---|
| `graphify-out/graph.json` | Índice topológico generado: qué objeto crea cada archivo, qué referencia, entrypoints y ciclos. No se edita a mano (§5). |
| `graphify-out/HOW_TO_REGENERATE.md` | Comando exacto, versión del intérprete y limitaciones del generador. |
| `scripts/graphify.py` | El generador. Si el grafo está mal, se corrige aquí y se regenera. |
| `README.md` | Organización del repo, reglas de ubicación y nombre, convenciones técnicas. |
| `AGENTS.md` | Protocolo para agentes. §7 tiene el contexto del proyecto verificado. |
| `.agents/skills/` | Skills por motor. Las tres externas están fijadas por hash en `skills-lock.json`: no se editan. |

## Reglas cortas

- **Lo que se aprende en sesión, se escribe aquí** (§1, §6.1): un hecho por línea, con fecha y quién lo dijo. Si la regla ya existe, se actualiza en su sitio.
- **Plan aprobado → `docs/plans/AAAA-MM-DD-<slug>.md` antes del primer edit** (§4); al cerrar se actualizan `Status` y `Outcome`.
- **Regla de negocio → `docs/domain/`. Procedimiento → `docs/runbooks/`.** No se quedan en el `README.md` de un dominio ni dentro de un comentario SQL.
- **Lo inferido se marca como inferido**, y se pregunta antes de registrarlo (§6.1).
- **`graphify-out/` es de solo lectura.**
