# Consultas — Empaqplast

Consultas, vistas y scripts de automatización sobre SAP B1 (HANA), SQL Server,
PostgreSQL y Fracttal.

## Qué es y qué no es este repositorio

**Es el registro de las consultas que hemos hecho.** No es un espejo de lo que
vive en la base de datos ni la fuente desde la que se despliega. (Jefferson,
2026-11-19.)

De ahí se sigue:

- La **verdad de lo que corre** está en el motor, no aquí. Un archivo guardado puede diferir de la vista o el procedimiento con el mismo nombre, y eso no es un error del repositorio.
- Que un archivo y el objeto vivo difieran **no implica que haya algo pendiente de desplegar**. Antes de reutilizar una consulta, verifica el esquema y el dato contra el origen.
- Dos archivos que generan el mismo objeto son **dos versiones de una consulta guardadas en momentos distintos**, no dos candidatos compitiendo por producción.

## Organización

Todo vive bajo `docs/`, en dos mitades que no se mezclan: el **conocimiento** y
las **consultas ejecutables**. Las consultas están agrupadas por dominio de
negocio, no por motor — reorganizado el 2026-11-19, ver
[docs/plans/2026-11-19-reorganizar-consultas-por-dominio.md](docs/plans/2026-11-19-reorganizar-consultas-por-dominio.md).

```
Consultas con SQL/
├── docs/
│   ├── INDEX.md          mapa de la base de conocimiento: empezar aquí
│   ├── mcp-registry.md   capacidad → servidor MCP, con qué se verificó
│   ├── domain/           reglas de negocio e invariantes
│   ├── runbooks/         procedimientos operativos
│   ├── adr/              decisiones de arquitectura
│   ├── plans/            planes aprobados
│   ├── catalogo/         guía HTML del inventario
│   └── consultas/        los archivos ejecutables, por dominio
├── graphify-out/         índice de dependencias generado (no se edita)
├── scripts/              graphify.py, el generador del índice
├── AGENTS.md             protocolo para agentes
└── README.md
```

### docs/consultas/

| Dominio | Contenido | Motores |
|---|---|---|
| `activos-fijos/` | Sábana para Power BI, exportes de Fracttal | HANA |
| `apps/` | Auth, permisos y menús, DDL de infra, NPS | PostgreSQL |
| `cartera/` | Bloqueos, vencidas con excedente, retenciones | HANA |
| `compras/` | Cadena de alerta de órdenes de compra | HANA → SQL Server → Python |
| `eficiencia-energetica/` | Combustible | HANA |
| `inventario/` | Stock, antigüedad PT/MP, UPC, datos maestros, auditoría UIO/GYE | HANA |
| `logistica/` | Pallets del flujo automático, traslados | HANA |
| `plataforma/` | Administración B1, validaciones, backups, diagnóstico | HANA + SQL Server |
| `produccion/` | Transformados, trazabilidad PT→MP, moldes | HANA + Beas |
| `rrhh/` | Ausentismo, atrasos, permisos, asistencia, festivos, Power BI | SQL Server |
| `supply/` | Cadena de alerta de stock crítico | HANA → SQL Server → Python |
| `ventas/` | Notas de crédito BI, cadena de pricing | HANA → Python |

Cada dominio tiene su `README.md` con el detalle: qué archivo es, **en qué motor
y servidor corre**, qué hace y en qué orden se despliega.

## Reglas

- **Pedido nuevo:** carpeta del **dominio**, no del motor (`docs/consultas/cartera/`, `docs/consultas/rrhh/`). Si el pedido cruza motores, los archivos van juntos en el mismo dominio.
- **Nombre:** si el script crea un objeto de base de datos, el archivo se llama igual que el objeto (`SB1_VIEW_NC_CABECERA.sql`); si es un reporte o un análisis, kebab-case en español, sin fechas.
- **Continuación:** misma carpeta de dominio, no crear una paralela.
- **Superado:** a `_historico/` dentro de su dominio. No se ejecuta.
- **Raíz:** solo `README.md`, `AGENTS.md`, `Consultas.code-workspace`, `.mcp.json`, `skills-lock.json`, más `docs/`, `scripts/` y `graphify-out/`.
- **Cabecera SQL:** propósito, motor y esquema o base, supuestos verificados con fecha, orden de despliegue.
- **Al cerrar el pedido:** fila nueva en el `README.md` del dominio, y lo que se aprendió a `docs/domain/` o `docs/runbooks/`.

## Convenciones técnicas

- **SAP B1 / HANA:** columnas `"ItemCode"` con comillas; tablas `OITM` sin comillas; esquema `EMPAQPLAST_PROD`.
- **Alertas:** vista `SB1_VIEW_*` en HANA → vista `OPENQUERY` en SQL Server → script Python. Las tres piezas viven en la carpeta del dominio.
- **OPENQUERY:** el `WHERE` va **dentro** del OPENQUERY.
- **Python:** `sqlcmd` para base de datos.
- Verificar esquema en vivo antes de escribir consultas.

## Dependencias entre objetos

`graphify-out/graph.json` dice qué objeto crea cada archivo, qué referencia y qué
depende de qué. Se regenera con:

```powershell
python scripts/graphify.py
```

## Catálogo y Agent Skills

Guía interactiva: `docs/catalogo/guia-consultas.html`

Skills del proyecto en `.agents/skills/` (Cursor los carga automáticamente).
Registry externo fijado en `skills-lock.json`; restaurar con
`npx skills experimental_install`.

| Skill | Origen | Motor |
|-------|--------|-------|
| `consultas-sql-empaqplast` | local | Orquestador del repo |
| `sap-b1-hana-sql` | local | SAP B1 / HANA |
| `sqlserver-tsql-empaqplast` | local | SQL Server (Empaqplast) |
| `postgres-sql-empaqplast` | local | PostgreSQL (Empaqplast) |
| `supabase-postgres-best-practices` | [skills.sh](https://skills.sh/supabase/agent-skills/supabase-postgres-best-practices) | PostgreSQL (general) |
| `mssql` | [skills.sh](https://skills.sh/sanjay3290/ai-skills/mssql) | SQL Server (consultas read-only) |
| `sap-sqlscript` | [skills.sh](https://skills.sh/secondsky/sap-skills/sap-sqlscript) | HANA SQLScript / SP |

Instalar más skills: `npx skills find postgres` o `npx skills add owner/repo --skill nombre -a cursor -y`.
