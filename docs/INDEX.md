# docs/ — mapa de la base de conocimiento

Primera lectura de cada sesión (§2.1 de `AGENTS.md`). Creado el 2026-11-19 a
partir de lo que realmente existe en el repo: antes de esa fecha no había `docs/`.

## Qué hay hoy

| Ruta | Contenido | Estado |
|---|---|---|
| `docs/INDEX.md` | Este mapa. Se actualiza **cada vez** que se agrega un archivo aquí. | — |
| `docs/mcp-registry.md` | Capacidad → servidor MCP, con qué se verificó y cuándo; incluye los servidores caídos. | Verificado 2026-11-19 |
| `docs/plans/2026-11-19-bootstrap-protocolo-agentes.md` | Plan aprobado del bootstrap del protocolo (este trabajo). | Implementado |
| `graphify-out/graph.json` | Índice topológico generado: nodos, aristas, superficie pública, refs externas, entrypoints, ciclos. No se edita a mano. | Regenerado 2026-11-19 |
| `graphify-out/HOW_TO_REGENERATE.md` | Comando exacto, versión del intérprete y limitaciones del generador. | 2026-11-19 |
| `scripts/graphify.py` | Generador del índice. Si el grafo está mal, se corrige **aquí**. | 2026-11-19 |

## Qué falta todavía

Estas carpetas de §6 **no existen aún** porque no hay contenido real que poner en
ellas. Créalas con el primer archivo, no antes, y agrega la línea a esta tabla:

| Ruta | Para qué | Primer candidato |
|---|---|---|
| `docs/domain/<área>.md` | Reglas de negocio e invariantes transversales: ausentismo, cartera, inventario, stock crítico, moldes. | `docs/domain/ausentismo.md` — la regla `En_Nomina` por periodo y el catálogo de tipos de permiso, que hoy viven solo en los scripts y en la cabeza del equipo. |
| `docs/adr/NNNN-<slug>.md` | Decisiones de arquitectura durables. | Por qué la cadena de alertas es HANA `SB1_VIEW_*` → SQL Server `OPENQUERY` → Python, y no una consulta directa. |
| `docs/integrations/<sistema>.md` | Contratos de sistemas externos: endpoints, payloads, modos de falla, dueño. | `docs/integrations/timecontrol.md` y `docs/integrations/fracttal.md`. |
| `docs/runbooks/<tarea>.md` | Procedimientos operativos. | El orden de ejecución de ausentismo, hoy en `sqlserver/rrhh/ausentismo/LEEME.md`. |

## Conocimiento que ya está en el repo, fuera de `docs/`

Documentación real que **no se movió** (queda junto a su consulta, que es donde
se busca). Al escribir en `docs/domain/`, cruza con estos archivos en vez de
crear una segunda versión de la misma verdad (§6.1):

| Archivo | Qué documenta |
|---|---|
| [README.md](README.md) | Organización por motor, reglas de nombres y convenciones técnicas (comillas en HANA, `WHERE` dentro del `OPENQUERY`, `sqlcmd` en Python). |
| [sqlserver/rrhh/ausentismo/LEEME.md](sqlserver/rrhh/ausentismo/LEEME.md) | Qué dos scripts de ausentismo son los vigentes y en qué orden, servidor y base corre cada uno. El resto de `sqlserver/rrhh/` es apoyo o versiones anteriores. |
| [sqlserver/rrhh/anteriores/VM_ATRASOS_ANALISIS.md](sqlserver/rrhh/anteriores/VM_ATRASOS_ANALISIS.md) | `vm_atrasos`: propósito, versiones, soporte de festivos. Reporte principal de Talento Humano para atrasos y faltas injustificadas. |
| [sqlserver/rrhh/powerbi/POWERBI_DASHBOARD_README.md](sqlserver/rrhh/powerbi/POWERBI_DASHBOARD_README.md) | Arquitectura TCONTROL (biométrico) + ONLYCONTROL (maestros) para el tablero. |
| [sqlserver/rrhh/powerbi/QUICK_REFERENCE.md](sqlserver/rrhh/powerbi/QUICK_REFERENCE.md) | Consultas de uso diario del tablero de RRHH. |
| [hana/ventas/notas-credito/README.md](hana/ventas/notas-credito/README.md) | Notas de crédito del BI de Gerencia: grano de cabecera y detalle, y por qué los montos van positivos frente a las vistas de venta. |
| [hana/produccion/moldes/ANALISIS_SB1_VIEW_ANALISIS_MOLDES.md](hana/produccion/moldes/ANALISIS_SB1_VIEW_ANALISIS_MOLDES.md) | `SB1_VIEW_ANALISIS_MOLDES` y sus objetos base, con dependencias por tabla de B1. |
| [catalogo-consultas/guia-consultas.html](catalogo-consultas/guia-consultas.html) | Guía interactiva del inventario de consultas. |
| `.agents/skills/` | Skills del proyecto por motor (orquestador, HANA, T-SQL, PostgreSQL) más tres externas fijadas en `skills-lock.json`. |

## Reglas cortas

- **Lo que se aprende en sesión, se escribe aquí** (§1, §6.1): una regla de negocio, una corrección, un umbral confirmado. Un hecho por línea, con fecha y quién lo dijo. Si la regla ya existe, se actualiza en su sitio; no se crea una segunda versión.
- **Plan aprobado → `docs/plans/AAAA-MM-DD-<slug>.md` antes del primer edit** (§4), y al cerrar se actualizan `Status` y `Outcome`.
- **Lo inferido se marca como inferido**, y se pregunta antes de registrarlo (§6.1).
- **`graphify-out/` es de solo lectura.** Lo que esté mal se arregla en `scripts/graphify.py` y se regenera.
