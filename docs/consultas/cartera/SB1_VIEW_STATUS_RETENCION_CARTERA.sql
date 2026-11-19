/* =========================================================================
   SB1_VIEW_STATUS_RETENCION_CARTERA
   Esquema: EMPAQPLAST_PROD   |   Motor: SAP HANA 2.00.087

   La funci├│n EMPAQPLAST::STATUSRETENCION responde bien. La vista qued├│
   invalidada (error 391). HANA no tiene RECOMPILE: se recrea con el
   mismo SELECT que ya corre en DBeaver.
   ========================================================================= */

CREATE OR REPLACE VIEW EMPAQPLAST_PROD.SB1_VIEW_STATUS_RETENCION_CARTERA AS
SELECT
    "Codigo",
    "Cliente",
    "Aplica Retencion",
    "Tipo",
    "No Factura",
    "Fecha Fac.",
    "Sucursal",
    "Valor Original",
    "Saldo",
    "Tipo cliente - proveedor",
    "Status Retencion",
    "Valor Retencion"
FROM "EMPAQPLAST::STATUSRETENCION"(TO_DATE('2018-01-01'), CURRENT_DATE)
WHERE "Cuenta Contable" IN ('11020102', '11020101');
