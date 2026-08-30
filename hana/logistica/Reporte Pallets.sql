-- Reporte Automatización Pallets (TransferenciasAutomaticas)
-- Empresa: EMPAQPLAST_PROD | Tablas: ODLN (guía) + OWTR (transferencia) + WTR1 (líneas)
--
-- Enlace cruzado que escribe n8n:
--   Guía (ODLN):  U_EntregaRef = DocNum transferencia | U_TipoMov = TRANSFERENCIA
--   Transfer (OWTR): U_EntregaRef = DocNum guía      | U_TipoMov = TRANSFERENCIA (POST)
--                    (PATCH posterior puede dejar ENTREGA; aceptar ambos en el JOIN)
--
-- Ajustar fecha de corte según go-live del flujo:
--   AND E."DocDate" >= '2026-07-06'

SELECT
    E."DocNum"              AS "Guia",
    T."DocNum"              AS "Transferencia",
    E."DocDate"             AS "FechaGuia",
    T."DocDate"             AS "FechaTransferencia",
    E."CardCode"            AS "Cliente",
    E."U_PalletCantidad"    AS "PalletsGuia",
    T."U_PalletCantidad"    AS "PalletsTransferencia",
    W."Quantity"            AS "PalletsLinea",
    COALESCE(W."FromWhsCod", T."Filler")     AS "BodegaOrigen",
    COALESCE(W."WhsCode", T."ToWhsCode")     AS "BodegaDestino",
    CASE E."U_PalletProcesado"
        WHEN 'N' THEN 'Pendiente'
        WHEN 'P' THEN 'En proceso'
        WHEN 'Y' THEN 'Completado'
        WHEN 'E' THEN 'Error'
        WHEN 'A' THEN 'Anulado'
        WHEN 'X' THEN 'Exonerado'
        ELSE E."U_PalletProcesado"
    END AS "EstadoGuia",
    CASE T."U_PalletProcesado"
        WHEN 'N' THEN 'Pendiente'
        WHEN 'P' THEN 'En proceso'
        WHEN 'Y' THEN 'Completado'
        WHEN 'E' THEN 'Error'
        WHEN 'A' THEN 'Anulado'
        WHEN 'X' THEN 'Exonerado'
        ELSE T."U_PalletProcesado"
    END AS "EstadoTransferencia",
    E."U_TipoMov"           AS "TipoMovGuia",
    T."U_TipoMov"           AS "TipoMovTransferencia",
    E."U_EntregaRef"        AS "RefEnGuia",
    T."U_EntregaRef"        AS "RefEnTransferencia",
    CASE
        WHEN T."DocNum" IS NULL
            THEN 'Sin transferencia'
        WHEN E."U_PalletCantidad" <> T."U_PalletCantidad"
            THEN 'Cantidad distinta'
        WHEN NULLIF(E."U_EntregaRef", '') IS NOT NULL
             AND E."U_EntregaRef" <> TO_VARCHAR(T."DocNum")
            THEN 'Ref guía incorrecta'
        WHEN NULLIF(T."U_EntregaRef", '') IS NOT NULL
             AND T."U_EntregaRef" <> TO_VARCHAR(E."DocNum")
            THEN 'Ref transferencia incorrecta'
        WHEN E."U_PalletProcesado" = 'E' OR T."U_PalletProcesado" = 'E'
            THEN 'Error en procesamiento'
        WHEN E."U_PalletProcesado" IN ('N', 'P')
             OR T."U_PalletProcesado" IN ('N', 'P')
            THEN 'Pendiente de completar'
        WHEN E."U_PalletProcesado" = 'Y' AND T."U_PalletProcesado" = 'Y'
            THEN 'OK'
        ELSE 'Revisar'
    END AS "Validacion"
FROM "ODLN" E
LEFT JOIN "OWTR" T
    ON  T."CANCELED" = 'N'
    AND COALESCE(T."U_TipoMov", 'TRANSFERENCIA') IN ('ENTREGA', 'TRANSFERENCIA')
    AND (
        T."U_EntregaRef" = TO_VARCHAR(E."DocNum")
        OR TO_VARCHAR(T."DocNum") = NULLIF(E."U_EntregaRef", '')
    )
LEFT JOIN "WTR1" W
    ON  W."DocEntry" = T."DocEntry"
WHERE COALESCE(E."U_PalletCantidad", 0) > 0
  AND E."DocDate" >= '2026-07-06'
  -- AND E."DocNum" = 100088272   -- filtro puntual de prueba
ORDER BY E."DocDate" DESC, E."DocNum" DESC;