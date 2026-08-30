# SQL Server — Patrones Empaqplast

## Bases de datos

| Alias MCP | Uso | Esquema típico |
|-----------|-----|----------------|
| `user-sqlserver-timecontrol` | Asistencia, atrasos, permisos | `dbo.TBL_ASISTENCIA`, `dbo.TBL_PERM_AUS` |
| `user-sqlserver-onlycontrol` | Nómina, áreas, calificaciones | `ONLYCONTROL.dbo.NOMINA`, `AREA`, `CALIFICA` |
| `user-sqlserver-etl-local-internaEmpaqplast` | ETL interno, rotación | Vistas de carga incremental |
| AlertasB1 (linked server) | Puente HANA → SQL Server | `OPENQUERY(HANAODBC, ...)` |

## Patrón AlertasB1 (OPENQUERY)

```sql
CREATE VIEW dbo.ORDENES_COMPRA AS
SELECT *
FROM OPENQUERY(HANAODBC,
  'SELECT * FROM EMPAQPLAST_PROD.SB1_VIEW_ORDENES_COMPRA
   WHERE "Cantidad_Pendiente" > 0');  -- filtro DENTRO
```

**Error común:** poner el WHERE fuera del OPENQUERY → trae millones de filas y filtra tarde.

## TimeControl / RRHH

Vistas clave:
- `dbo.vm_atrasos` — atrasos, faltas, no cumplimiento horario
- Consultas Power BI en `powerbi_dashboard_queries.sql`

Siempre filtrar por fecha:
```sql
WHERE a.Fecha_Ingreso >= DATEADD(MONTH, -3, GETDATE())
```

Join estándar empleado:
```sql
LEFT JOIN ONLYCONTROL.dbo.NOMINA n ON a.EMP_ID = n.NOMINA_ID
```

## Permisos con período (21 al 20)

Usar variables `DECLARE` para empleado, año, período. Replica pantalla "Asignación de Permisos".

## ETL / carga incremental

Patrón upsert en `Proceso de carga Rotacion.sql`:
1. Vista de transformación (filas nuevas → formato legacy)
2. MERGE o INSERT condicionado sin duplicados

## Backups y mantenimiento

`backups_manual.sql` — scripts operativos, no reportes.

## Python + sqlcmd (alertas)

```python
subprocess.run([
    "sqlcmd", "-S", server, "-d", "AlertasB1",
    "-Q", query, "-s", "|", "-W"
], check=True)
```

Salida → `xlsxwriter` → SMTP.
