# Revisión de stock: qué cuenta como OC pendiente

Regla para `SB1_VIEW_REVISION_STOCK_V2` (columnas de pedido / cantidad).
Declarada por Jefferson el **2026-11-24**.

**Despliegue:** `ALTER VIEW` ejecutado en HANA prod el **2026-11-24** (Jefferson).
Archivo que describe la base: `docs/consultas/inventario/SB1_VIEW_REVISION_STOCK_V2-version-alterna.sql`.
Comprobado vía MCP `user-hana-sap-b1-produccion`: columnas
`Cant_Ultimo_Pedido`, `Status_Importacion`, `Cant_OC_Abierta`,
`Fecha_Ultima_OC_Abierta`, `Nro_Ultima_OC_Abierta` presentes; PET Botellón
muestra OC `200001716` / `En tránsito` / 138.000 kg.

## Criterio

Una línea de OC cuenta como pendiente si `CANCELED = 'N'` y:

1. **Abierta en B1:** `DocStatus = 'O'`, `LineStatus = 'O'`, `OpenQty > 0`, **o**
2. **Importación no liquidada:** la carpeta vigente (`@ALS_CARPETA_IMP`, `LogInst = MAX`) tiene
   `U_EMPA_STATUS_IMPORT` en `Por embarcarse`, `En tránsito` o `En nacionalización`.

No entran: `Concluido`, `Anulado` (aunque la OC siga abierta en B1). Status nulo solo entra si cumple (1).

## Enlace

- `OPOR."U_SYP_CARPIMP"` = `@ALS_CARPETA_IMP."Code"` (mismo número que la OC / Nro. Carpeta Importación).
- Ítem de carpeta: `U_EMP_ITEM_PEDIDO` (si viene vacío, no se filtra por ítem).

## Cantidad

Solo del pedido (`POR1`), nunca de la carpeta:

- Si `OpenQty > 0` → `OpenQty`.
- Si no (OC cerrada pero carpeta activa) → `Quantity` de la línea.

## Evidencia

`MPRPBO00001` / OC `200001716`: `DocStatus = C`, `OpenQty = 0`, carpeta `En tránsito`, 138.000 kg — debe mostrar fecha y cantidad.
`MPPAI800001` con OC cerradas sin carpeta activa — no debe mostrar pedido pendiente.
