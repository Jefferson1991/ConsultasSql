# Notas de crédito — BI de Gerencia

Vistas en `EMPAQPLAST_PROD` para el tablero de Gerencia. Una nota de crédito vigente (ORIN, `CANCELED = 'N'`) queda en cabecera; cada línea (RIN1) queda en detalle.

| Vista | Grano | Script |
|---|---|---|
| `SB1_VIEW_NC_CABECERA` | 1 fila por documento | `SB1_VIEW_NC_CABECERA.sql` |
| `SB1_VIEW_NC_DETALLE` | 1 fila por línea | `SB1_VIEW_NC_DETALLE.sql` |

Los montos van **positivos**, como en el módulo de Nota de crédito. `SB1_VIEW_VENTA_CABECERA_TDW` y `SB1_VIEW_VENTA_DETALLE_TDW` guardan el mismo documento en negativo.

## Modelo en Power BI

```
SB1_VIEW_NC_CABECERA.DocEntry  (1)
        │
        └── SB1_VIEW_NC_DETALLE.DocEntry  (*)
```

- Llave de la línea: `DocEntry` + `LineNum`.
- `DocTotal` se suma solo desde la cabecera. Incluye IVA.
- `BaseLineas` y `LineTotal` son base imponible. No incluyen IVA.
- `TotalLinea` = `LineTotal` + `VatSum`.

## Qué deja fuera la vista de ventas

Reconstruido el 2026-10-16 comparando las vistas de ventas contra `ORIN` / `RIN1`. La definición SQL de esas vistas no es visible con el usuario actual.

1. La cabecera de ventas incluye las series `NCUIO1` y `NCGYE`, excluye anuladas y la serie `CANCEL`, y guarda el total en negativo.
2. El detalle de ventas omite toda línea cuya cuenta no empieza por `41`.

En el histórico vigente esas líneas son:

| Cuenta | Nombre | Líneas | Base |
|---|---|---:|---:|
| 42010102 | Otros Ingresos | 159 | 80,863.47 |
| 19010101 | Cuenta de Orden Deudora | 9 | 12,004.08 |
| 42010101 | Venta de Activos Fijos | 18 | 2,130.66 |

Esas notas sí entran en la cabecera de ventas (el `DocTotal` las suma) y desaparecen en el detalle. `EnVistaVentas = 'Y'` marca la línea que el detalle de ventas sí trae. En cabecera, `BaseEnVistaVentas` y `BaseFueraVistaVentas` parten la base del documento.

## Clase de la línea

| Cuenta | Clase |
|---|---|
| 41030101 | Devolución en ventas |
| 41020102 | Rebate |
| 41020101 | Descuento en ventas |
| 42010102, 42010101 | Otros ingresos |
| 19010101 | Cuenta de orden |
| resto `41%` | Otra cuenta de ventas |
| otra | Otra cuenta |

Si el documento mezcla clases, la cabecera queda en `Mixta`.

`CostoInventario` solo se llena en devoluciones (`41030101`): ahí `StockSum` es el costo del producto que regresa a bodega. En rebates y descuentos SAP copia el valor de la línea al stock; no es costo de producción y el campo queda en 0. `CostoUnitario` (`StockPrice`) se expone siempre, para revisar el dato crudo.

## Dimensiones de proceso

- `ProcesoLinea` es `OcrCode3` de la línea (SOP-PET, SOPPETGY, etc.). Es el campo que la vista de ventas llama `U_ProcesoProductivo`.
- `ProcesoArticulo` es el dato maestro del ítem (`OITM.U_ProcesoProductivo`), con su descripción.

## Origen de la línea

| `BaseType` | Origen |
|---|---|
| 13 | Factura (`OINV`) enlazada en la línea |
| 234000031 | Solicitud de devolución (`ORRR`) |
| -1 | Sin documento base. Típico en rebates y descuentos |

En rebates y descuentos la factura fiscal no está en la línea. Está en la cabecera: `ORIN.U_D_MODIFICADO` = `OINV.U_N_DOCSRI`, y se expone como `FacturaDocNum`. Desde 2024 el número SRI no se repite entre facturas vigentes. Si en el futuro se repitiera, la factura queda en NULL para no duplicar la nota de crédito.

## Motivo (`U_M_DEVOLUCION`)

`01` medidas, `02` humedad, `03` olor, `04` cuerpos extraños, `05` CA vs FT, `06` color, `07` N/A, `08` calidad, `09` refacturación, `10` descuento clientes, `11` muestras, `12` error de despacho, `13` descuento por promoción. La cabecera guarda también el código (`MotivoCodigo`).

## Sucursal

`Sucursal` son los últimos 3 caracteres de la serie: `GYE` Guayaquil, `IO1` Quito. La cabecera traduce el nombre en `SucursalNombre`.

## Despliegue

Ejecutar ambos scripts en `EMPAQPLAST_PROD`. No dependen uno del otro.

```sql
GRANT SELECT ON EMPAQPLAST_PROD.SB1_VIEW_NC_CABECERA TO EMPAQPLAST;
GRANT SELECT ON EMPAQPLAST_PROD.SB1_VIEW_NC_DETALLE TO EMPAQPLAST;
```
