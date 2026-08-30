---
name: sqlserver-tsql-empaqplast
description: >-
  Escribe y optimiza T-SQL para Empaqplast en SQL Server: TimeControl, OnlyControl,
  AlertasB1 (OPENQUERY HANA), vistas vm_atrasos, ETL y Power BI. Usar cuando la
  consulta va en sqlserver/, mencione TBL_ASISTENCIA, OPENQUERY, vm_atrasos,
  NOMINA, AlertasB1 o linked server HANAODBC.
---

# SQL Server — T-SQL Empaqplast

## MCP y bases

| MCP | Uso |
|-----|-----|
| `user-sqlserver-timecontrol` | `TBL_ASISTENCIA`, `TBL_PERM_AUS`, `vm_atrasos` |
| `user-sqlserver-onlycontrol` | `NOMINA`, `AREA`, `CALIFICA` |
| `user-sqlserver-etl-local-internaEmpaqplast` | ETL rotación |

Repo: `sqlserver/{alertas-b1|rrhh|supply|etl|ops}/`

## OPENQUERY AlertasB1 (crítico)

```sql
CREATE VIEW dbo.ORDENES_COMPRA AS
SELECT *
FROM OPENQUERY(HANAODBC,
  'SELECT * FROM EMPAQPLAST_PROD.SB1_VIEW_ORDENES_COMPRA
   WHERE "Cantidad_Pendiente" > 0');
```

**El WHERE va dentro del OPENQUERY.** Filtrar afuera trae todo el histórico de HANA.

Probar: `SELECT COUNT(*) FROM dbo.ORDENES_COMPRA;`

## Mejores prácticas T-SQL

Basado en [SQL Server Guides SP best practices](https://sqlserverguides.com/sql-stored-procedure-best-practices/) y [Query Store tuning 2025](https://developersvoice.com/blog/database/sql-server-query-tuning-in-2025/):

1. **`SET NOCOUNT ON`** al inicio de SPs y scripts largos
2. **Sin SELECT *** — solo columnas necesarias
3. **Nombres calificados** — `dbo.TBL_ASISTENCIA`, `ONLYCONTROL.dbo.NOMINA`
4. **Tipos exactos** en parámetros = tipos de columna (evita scans por implicit cast)
5. **Lógica set-based** — evitar cursores; usar JOIN, MERGE, window functions
6. **Filtro por fecha obligatorio** en tablas de hechos:
   ```sql
   WHERE a.Fecha_Ingreso >= DATEADD(MONTH, -3, GETDATE())
   ```
7. **Transacciones cortas** — BEGIN/COMMIT solo donde haga falta; validar con SELECT antes de UPDATE
8. **TRY/CATCH** en SPs que modifican datos
9. **Dynamic SQL** — solo con `sp_executesql` parametrizado, nunca concatenación directa
10. **Query Store** — revisar regresiones en producción; PSP optimization en SQL Server 2022+

## Join estándar RRHH

```sql
FROM dbo.TBL_ASISTENCIA a
LEFT JOIN ONLYCONTROL.dbo.NOMINA n ON a.EMP_ID = n.NOMINA_ID
LEFT JOIN ONLYCONTROL.dbo.AREA ar ON n.NOMINA_AREA = ar.AREA_ID
WHERE a.Fecha_Ingreso >= @fecha_desde
```

## Power BI / dashboards

- Separar **dimensión** (empleados, áreas) de **hechos** (asistencia diaria)
- Documentar relaciones en cabecera del .sql
- Siempre filtrar por rango de fechas en origen, no solo en DAX
- Archivos en `sqlserver/rrhh/`

## ETL incremental

Patrón en `sqlserver/etl/`:

1. Vista staging (filas nuevas → formato destino)
2. MERGE o INSERT condicionado sin duplicados
3. Idempotente: re-ejecutable sin duplicar

## Plantilla SP

```sql
CREATE OR ALTER PROCEDURE dbo.sp_ejemplo
    @emp_id VARCHAR(10) = NULL,
    @fecha_desde DATE
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    SELECT ...
    FROM dbo.TBL_ASISTENCIA a
    WHERE a.Fecha_Ingreso >= @fecha_desde
      AND (@emp_id IS NULL OR a.EMP_ID = @emp_id);
END
```

## Checklist

- [ ] Esquema verificado con MCP
- [ ] Filtro de fecha en tablas grandes
- [ ] OPENQUERY con WHERE interno (si aplica)
- [ ] Archivo en `sqlserver/{subcarpeta}/`
- [ ] UPDATE/DELETE precedido de SELECT de validación

## Referencia extendida

Tuning y diagnóstico: [referencias/performance-tuning.md](referencias/performance-tuning.md)
