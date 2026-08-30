# Consultas — Empaqplast

Consultas, vistas y scripts de automatización sobre SAP B1 (HANA), SQL Server,
PostgreSQL y Fracttal.

## Organización por base de datos

```
Consultas con SQL/
├── hana/              SAP B1 sobre HANA (EMPAQPLAST_PROD)
├── sqlserver/         TimeControl, OnlyControl, AlertasB1
├── postgres/          Apps Empaqplast, NPS
├── automatizaciones/  Python (alertas, ETL Excel)
├── fracttal/          Exportes Fracttal
└── catalogo-consultas/ Guía HTML del inventario
```

### hana/

| Subcarpeta | Contenido |
|---|---|
| `administracion/` | Licencias, vistas B1, Query Manager |
| `cartera/` | Bloqueos, vencidas, retenciones, SP cartera |
| `compras/` | `SB1_VIEW_ORDENES_COMPRA` |
| `eficiencia-energetica/` | Combustible |
| `ia/` | Usuario BD IA |
| `inventario/` | Revisión stock, UPC, entradas OT |
| `logistica/` | Traslados, pallets |
| `ops/` | Diagnóstico conexiones |
| `produccion/` | Stock plantas, transformados, moldes |
| `supply/` | Stock crítico (vistas HANA) |
| `validaciones/` | Transaction Notifications |
| `ventas/` | Facturas pricing |

### sqlserver/

| Subcarpeta | Contenido |
|---|---|
| `alertas-b1/` | Vistas OPENQUERY sobre HANA |
| `rrhh/` | vm_atrasos, Power BI, asistencia, permisos |
| `supply/` | SP stock crítico |
| `etl/` | Carga rotación |
| `ops/` | Backups |

### postgres/

| Subcarpeta | Contenido |
|---|---|
| `app/` | Auth y DDL infra |
| `nps/` | Campañas NPS |

### automatizaciones/

Scripts Python que orquestan SQL + correo/Excel. Van **junto** a las consultas
de su BDD origen en subcarpetas temáticas (`ordenes-compra/`, `pricing/`,
`stock-critico/`).

## Reglas

- **Pedido nuevo:** crear subcarpeta dentro del motor correcto (`hana/cartera/`, `sqlserver/rrhh/`, etc.).
- **Nombre:** kebab-case, descriptivo del asunto, en español, sin fechas.
- **Continuación:** misma subcarpeta existente, no crear paralela.
- **Raíz:** solo `README.md`, `Consultas.code-workspace`, `.mcp.json`.
- **Cabecera SQL:** propósito, esquema, supuestos verificados, orden de despliegue.

## Convenciones técnicas

- **SAP B1 / HANA:** columnas `"ItemCode"` con comillas; tablas `OITM` sin comillas; esquema `EMPAQPLAST_PROD`.
- **Alertas:** HANA `SB1_VIEW_*` → `sqlserver/alertas-b1/` OPENQUERY → `automatizaciones/` Python.
- **OPENQUERY:** el `WHERE` va **dentro** del OPENQUERY.
- **Python:** `sqlcmd` para base de datos.
- Verificar esquema en vivo antes de escribir consultas.

## Catálogo y Agent Skills

Guía interactiva: `catalogo-consultas/guia-consultas.html`

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
`npx autoskills` en este repo solo detecta frontend (por `guia-consultas.html`); usar `skills add` para SQL.
