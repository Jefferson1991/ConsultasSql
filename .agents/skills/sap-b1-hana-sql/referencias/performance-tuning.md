# HANA — Rendimiento y anti-patrones

## Filtros recomendados en B1

```sql
-- Documentos activos
WHERE T0."CANCELED" = 'N'

-- Facturas no canceladas (incluye evitar tipo 'C')
WHERE T0."CANCELED" = 'N' AND T0."DocStatus" = 'O'

-- Rango de fechas (preferir sobre funciones)
WHERE T0."DocDate" >= ADD_DAYS(CURRENT_DATE, -90)
```

## Anti-patrones

| Evitar | Usar en su lugar |
|--------|------------------|
| `SELECT *` | Lista explícita de columnas |
| `WHERE YEAR("DocDate")=2026` | `WHERE "DocDate" BETWEEN '2026-01-01' AND '2026-12-31'` |
| Subconsultas correlacionadas por fila | JOIN o window functions |
| Números mágicos en CASE | Documentar origen o eliminar |
| OPENQUERY sin WHERE interno | Filtro dentro del string OPENQUERY |
| Vista sin GRANT al usuario ODBC | `GRANT SELECT ON ... TO EMPAQPLAST` |

## EXPLAIN

Usar MCP `hana_explain_plan` antes de desplegar vistas que escaneen tablas grandes (`OINM`, `JDT1`, `INV1` histórico).

## Vistas existentes (no duplicar)

`SB1_VIEW_ORDENES_COMPRA`, `SB1_VIEW_REVISION_STOCK_V2`, `SB1_VIEW_STATUS_RETENCION_CARTERA`,
`SB1_VIEW_UBICACIONES_UPC`, `create_view_reporte_stock_critico`, `create_view_analisis_moldes`

Consultar repo `hana/` y catálogo HTML antes de crear vista nueva.
