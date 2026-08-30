# SAP B1 sobre HANA — Patrones SQL

## Sintaxis

```sql
-- Tablas estándar B1 (sin comillas)
SELECT T0."ItemCode", T0."ItemName"
FROM OITM T0
WHERE T0."validFor" = 'Y';

-- Esquema de producción
CREATE OR REPLACE VIEW EMPAQPLAST_PROD.SB1_VIEW_EJEMPLO AS
SELECT ...
```

## Tablas frecuentes por dominio

| Dominio | Tablas clave |
|---------|--------------|
| Inventario | `OITM`, `OITW`, `OINM`, `OWHS`, `OBIN` |
| Compras | `OPOR`, `POR1`, `OPDN`, `PDN1` |
| Ventas / Cartera | `OCRD`, `OINV`, `INV1`, `ORIN`, `RIN1`, `OJDT`, `JDT1` |
| Producción | `OWOR`, `WOR1`, `OIGE`, `IGE1`, `OIGN`, `IGN1` |
| Traslados | `OWTQ`, `WTQ1`, `OWTR`, `WTR1` |
| Logística pallets | `ODLN`, `OWTR`, `WTR1` (UDFs `U_EntregaRef`, `U_TipoMov`, `U_PalletCantidad`) |

## Vistas SB1_VIEW_* existentes (referencia)

| Vista | Dominio |
|-------|---------|
| `SB1_VIEW_ORDENES_COMPRA` | Compras abiertas serie OCNAC |
| `SB1_VIEW_STATUS_RETENCION_CARTERA` | Cartera / retenciones |
| `SB1_VIEW_REVISION_STOCK_V2` | Inventario / revisión stock |
| `SB1_VIEW_UBICACIONES_UPC` | Ubicaciones UPC |
| `SB1_VIEW_REPORTE_STOCK_CRITICO` | Supply / stock crítico |
| `SB1_VIEW_ANALISIS_MOLDES` | Producción / moldes |

## Transaction Notification (SQLScript)

Procedimientos como `SBO_SP_TransactionNotification_*` usan:
- `in object_type`, `in transaction_type` (`A`/`U`/`D`/`C`)
- `inout error`, `inout error_message`
- Validar contra tabla de objetos B1 (17=ORDR, etc.)

## UDFs Empaqplast frecuentes

- `U_EMPA_*` — campos personalizados producción/inventario
- `U_EMPA_BLOQ_CARTER` — bloqueo cartera en OCRD
- `U_EMPA_S_T` — enlace traslado → salida mercancía

## Verificación con MCP

```
hana_describe_table(table='OITM', schema='EMPAQPLAST_PROD')
hana_execute_query(query='SELECT TOP 5 "ItemCode" FROM EMPAQPLAST_PROD.OITM')
```

Siempre probar `COUNT(*)` con filtros antes de desplegar vistas pesadas.
