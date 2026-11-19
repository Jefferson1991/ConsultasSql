# Inventario

Todo sobre SAP B1 en HANA, esquema `EMPAQPLAST_PROD`.

| Archivo | Crea | Qué hace |
|---|---|---|
| [SB1_VIEW_ANTIGUEDAD_INVENTARIO_PT_MP.sql](SB1_VIEW_ANTIGUEDAD_INVENTARIO_PT_MP.sql) | `SB1_VIEW_ANTIGUEDAD_INVENTARIO_PT_MP` | Antigüedad de producto terminado y materia prima. Una fila por artículo + lote + bodega con stock positivo; sin lote, una fila por artículo + bodega con lote `'SIN LOTE'`. Ticket GLPI 2621. |
| [SB1_VIEW_REVISION_STOCK_V2.sql](SB1_VIEW_REVISION_STOCK_V2.sql) | `SB1_VIEW_REVISION_STOCK_V2` | Revisión de stock. |
| [SB1_VIEW_REVISION_STOCK_V2-version-alterna.sql](SB1_VIEW_REVISION_STOCK_V2-version-alterna.sql) | `SB1_VIEW_REVISION_STOCK_V2` | **Segunda definición del mismo objeto.** Ver el aviso de abajo. |
| [SB1_VIEW_UBICACIONES_UPC.sql](SB1_VIEW_UBICACIONES_UPC.sql) | `SB1_VIEW_UBICACIONES_UPC` | Ubicaciones y UPC por artículo y bodega. |
| [SB1_VIEW_REPORTE_ENTRADA_MERCANCIAS_OT.sql](SB1_VIEW_REPORTE_ENTRADA_MERCANCIAS_OT.sql) | `SB1_VIEW_REPORTE_ENTRADA_MERCANCIAS_OT` | Entradas de mercancía por orden de trabajo, con año/mes/día separados. |
| [datos-maestros-articulos.sql](datos-maestros-articulos.sql) | — | Artículos activos con grupo, unidad de medida, y fecha y usuario de creación y actualización. Pedido de Diego Morales, 2026-11-06. |
| [resumen-inventario-uio-gye.sql](resumen-inventario-uio-gye.sql) | — | Réplica del informe de auditoría de stocks por sucursal: movimientos `TransType` 59 (entrada) y 60 (salida). Excluye grupos 106, 107 y 108. **Hay que ajustar `YEAR`/`MONTH` en el `WHERE` de cada CTE.** |
| [stock-actual-bodega-uio-gye.sql](stock-actual-bodega-uio-gye.sql) | — | Saldos en tiempo real (`OITW`) más el último movimiento de entrada y salida. Mismas exclusiones de grupo. |

## Dos archivos definen `SB1_VIEW_REVISION_STOCK_V2`

El índice topológico lo marca en `public_surface`. Antes de ejecutar uno, confirma
cuál coincide con la vista viva en HANA. Dato de contexto que está en la cabecera
de `SB1_VIEW_REVISION_STOCK_V2.sql`: el 2026-06-23 se eliminó un ajuste fijo de
`- 74250` escrito a mano solo para `MPPASO00001`, que calzaba el tránsito de un
embarque puntual. Si la versión alterna todavía lo tiene, desplegarla reintroduce
el error.

Los dos reportes de auditoría UIO/GYE estaban antes bajo `produccion/`: son
inventario, no producción.
