# Cartera

Todo sobre SAP B1 en HANA, esquema `EMPAQPLAST_PROD`.

| Archivo | Qué hace |
|---|---|
| [SB1_VIEW_STATUS_RETENCION_CARTERA.sql](SB1_VIEW_STATUS_RETENCION_CARTERA.sql) | Crea la vista de estado de retención. Se apoya en la función `EMPAQPLAST::STATUSRETENCION`. |
| [clientes-con-bloqueo.sql](clientes-con-bloqueo.sql) | Clientes con bloqueo: facturas abiertas y días de excedente (`OCRD.AvrageLate`). |
| [clientes-facturas-vencidas-excedente.sql](clientes-facturas-vencidas-excedente.sql) | Facturas vencidas más allá del excedente, con días de crédito por documento. |
| [bloqueo-cartera-transaction-notification.sql](bloqueo-cartera-transaction-notification.sql) | Lógica de bloqueo para el Transaction Notification: objeto 17 (`ORDR`), evento `A`. Exige saldo real pendiente (`DocTotal - PaidToDate > 0`). |

## Qué conviene saber antes de tocar

- `DocDueDate` **ya incluye** el crédito del cliente (`GroupNum`, por ejemplo 90 días); no hay que volver a sumarlo.
- `AvrageLate` (sí, con esa ortografía, es columna estándar de B1) es el excedente en días que se le tolera al cliente.
- `U_EMPA_BLOQ_CARTER` es el check de bloqueo, `'Y'`/`'N'`.
- La vista de retención quedó invalidada una vez con error 391 y hubo que recrearla con el mismo `SELECT`: HANA no tiene `RECOMPILE`.

El Transaction Notification de cartera se despliega junto con el resto de la
lógica de validaciones: ver [plataforma/sap-b1/](../plataforma/sap-b1/).
