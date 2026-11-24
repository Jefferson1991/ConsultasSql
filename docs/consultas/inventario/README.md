# Inventario

Todo sobre SAP B1 en HANA, esquema `EMPAQPLAST_PROD`.

| Archivo | Crea | Qué hace |
|---|---|---|
| [SB1_VIEW_ANTIGUEDAD_INVENTARIO_PT_MP.sql](SB1_VIEW_ANTIGUEDAD_INVENTARIO_PT_MP.sql) | `SB1_VIEW_ANTIGUEDAD_INVENTARIO_PT_MP` | Antigüedad de producto terminado y materia prima. Una fila por artículo + lote + bodega con stock positivo; sin lote, una fila por artículo + bodega con lote `'SIN LOTE'`. Ticket GLPI 2621. |
| [SB1_VIEW_REVISION_STOCK_V2.sql](SB1_VIEW_REVISION_STOCK_V2.sql) | `SB1_VIEW_REVISION_STOCK_V2` | Revisión de stock. |
| [SB1_VIEW_REVISION_STOCK_V2-version-alterna.sql](SB1_VIEW_REVISION_STOCK_V2-version-alterna.sql) | `SB1_VIEW_REVISION_STOCK_V2` | **Define la vista viva** (ALTER ejecutado 2026-11-24). OC pendientes = abiertas **o** carpeta importación no liquidada; `Status_Importacion`. Regla: [revision-stock-oc-pendientes.md](../../domain/revision-stock-oc-pendientes.md). |
| [SB1_VIEW_UBICACIONES_UPC.sql](SB1_VIEW_UBICACIONES_UPC.sql) | `SB1_VIEW_UBICACIONES_UPC` | Ubicaciones y UPC por artículo y bodega. |
| [SB1_VIEW_REPORTE_ENTRADA_MERCANCIAS_OT.sql](SB1_VIEW_REPORTE_ENTRADA_MERCANCIAS_OT.sql) | `SB1_VIEW_REPORTE_ENTRADA_MERCANCIAS_OT` | Entradas de mercancía por orden de trabajo, con año/mes/día separados. |
| [datos-maestros-articulos.sql](datos-maestros-articulos.sql) | — | Artículos activos con grupo, unidad de medida, y fecha y usuario de creación y actualización. Pedido de Diego Morales, 2026-11-06. |
| [resumen-inventario-uio-gye.sql](resumen-inventario-uio-gye.sql) | — | Réplica del informe de auditoría de stocks por sucursal: movimientos `TransType` 59 (entrada) y 60 (salida). Excluye grupos 106, 107 y 108. **Hay que ajustar `YEAR`/`MONTH` en el `WHERE` de cada CTE.** |
| [stock-actual-bodega-uio-gye.sql](stock-actual-bodega-uio-gye.sql) | — | Saldos en tiempo real (`OITW`) más el último movimiento de entrada y salida. Mismas exclusiones de grupo. |

## Dos archivos para `SB1_VIEW_REVISION_STOCK_V2`: cuál describe la base

Son dos versiones de la misma consulta. La viva es `…-version-alterna.sql`
(ALTER 2026-11-24: OC pendientes + `Status_Importacion`). Además del ajuste
fijo `- 74250` en `MPPASO00001`, esa versión ya no coincide en número de
columnas con `SB1_VIEW_REVISION_STOCK_V2.sql`.

Comprobado 2026-11-19 (tránsito) y 2026-11-24 (columnas OC / status).

```
OITW · MPPASO00001 · UIO_IMPT   OnHand 0 + OnOrder 767.250 = 767.250
Vista viva · Transito_kg                                   = 693.000
```

Si reutilizas `SB1_VIEW_REVISION_STOCK_V2.sql`, que ya no lleva el ajuste, para
ese artículo obtendrás 74.250 kg más de tránsito que el motor, y lo mismo en
`Stock_Neto_kg`, `Dias_Stock_Neto` y las columnas de costo.

Evidencia: [docs/domain/stock-diferencias-con-la-bdd.md](../../domain/stock-diferencias-con-la-bdd.md).

Los dos reportes de auditoría UIO/GYE estaban antes bajo `produccion/`: son
inventario, no producción.
