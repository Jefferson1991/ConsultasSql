# Apps (PostgreSQL)

Las bases de las aplicaciones propias, no de SAP. Motor PostgreSQL 16.

| Archivo | Qué hace |
|---|---|
| [auth-permisos-y-menus.sql](auth-permisos-y-menus.sql) | Altas de permisos, menús y páginas en el esquema `auditorias`. Cada `INSERT` va con `WHERE NOT EXISTS`, así que es idempotente: se puede volver a ejecutar sin duplicar. |
| [crear-base-de-datos.sql](crear-base-de-datos.sql) | `CREATE DATABASE bi OWNER empaqplast`. DDL de infraestructura. |
| [nps/configuracion-nps.sql](nps/configuracion-nps.sql) | Configuración de la campaña NPS semestral: esquema `nps`. |

## Cuidado con la campaña NPS

`nps/configuracion-nps.sql` empieza con un `TRUNCATE` de `nps_respuesta_area`,
`nps_encuesta` y `nps_cliente` con `RESTART IDENTITY`, dentro de una transacción.
Eso **borra las respuestas de la campaña anterior**. §5 de `AGENTS.md` pide no
ejecutar `TRUNCATE` desde una tarea de desarrollo: ejecútalo tú, a conciencia, y
solo cuando la campaña anterior ya esté respaldada o explotada.

Servidores PostgreSQL disponibles por MCP (`postgres-local-empaqplast`,
`postgres-aws-empaqplast-cloud`, `postgres-produccion-empaqplast-cloud`):
ver [docs/mcp-registry.md](../../mcp-registry.md). Confirma contra cuál estás
corriendo antes de un DDL.
