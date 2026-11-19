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

## Dos archivos definen `SB1_VIEW_REVISION_STOCK_V2`, y la viva es la vieja

Comparado contra producción el 2026-11-19: **la vista que corre en HANA es la de
`SB1_VIEW_REVISION_STOCK_V2-version-alterna.sql`**, es decir la que todavía lleva
el ajuste fijo `- 74250` escrito a mano solo para `MPPASO00001`.

```
OITW · MPPASO00001 · UIO_IMPT   OnHand 0 + OnOrder 767.250 = 767.250
Vista viva · Transito_kg                                   = 693.000
```

La corrección que la cabecera de `SB1_VIEW_REVISION_STOCK_V2.sql` da por hecha el
2026-06-23 **nunca se desplegó**. Mientras siga así, para ese artículo
`Transito_kg`, `Stock_Neto_kg`, `Dias_Stock_Neto` y las columnas de costo quedan
subestimadas en 74.250 kg.

Las dos definiciones declaran las mismas 53 columnas en el mismo orden, así que la
estructura no las distingue: solo el dato.

Evidencia completa y decisión pendiente: [docs/domain/stock-definiciones-vigentes.md](../../domain/stock-definiciones-vigentes.md).

Los dos reportes de auditoría UIO/GYE estaban antes bajo `produccion/`: son
inventario, no producción.
