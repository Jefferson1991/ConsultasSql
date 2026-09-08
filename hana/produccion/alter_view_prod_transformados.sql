-- =============================================================================
-- SB1_VIEW_PROD_TRANSFORMADOS
-- Esquema: EMPAQPLAST_PROD | Motor: SAP HANA
-- Fecha:   2026-09-08
--
-- OBJETIVO:
--   Misma lógica de kg que SB1_VIEW_KG_TRANSFORMADOS_EFICIENCIA_ENERGETICA.
--   No se cambian nombres ni cantidad de columnas de salida (tableros Power BI).
--
-- kilogramos_completados (= columna "Kg" de la vista de energía):
--   INY-PET            → SUM(ABS(BookedQty)) de BOM MP% (resina).
--                        Merma/desperdicio no restan.
--   SOP-PET / SOPPETGY → SUM PTPR% × IWeight1 / 1000 (solo preforma).
--   IMPR-BOB           → Kg_Base × máquinas MA%.
--   Resto              → DIN si existe; si no, OITM.IWeight1.
--
-- total_gramos          = kilogramos_completados × 1000
-- toneladas_completadas = kilogramos_completados / 1000
-- peso_unitario_maestro = OITM.IWeight1 (sin cambio)
--
-- VALIDACION PRODUCCION:
--   OT 9725 INY-PET  kilogramos_completados = 5783.1648
--   OT 9775 SOP-PET  kilogramos_completados = 1064.085
--
-- Despliegue: DROP VIEW si existe, luego CREATE VIEW en EMPAQPLAST_PROD
-- =============================================================================

CREATE VIEW EMPAQPLAST_PROD.SB1_VIEW_PROD_TRANSFORMADOS AS
WITH "CostoRealHeader" AS (SELECT
        T0."U_beas_belnrid"         AS "U_beas_belnrid",
        T0."U_beas_belposid"        AS "U_beas_belposid",
        MAX(T0."OcrCode")           AS "Sucursal",
        MAX(T0."OcrCode2")          AS "Area",
        MAX(T0."OcrCode3")          AS "Departamento",
        MAX(T0."OcrCode4")          AS "Maquina",
        MAX(T0."WhsCode")           AS "Bodega",
        MAX(T1."DocNum")            AS "DocNum",
        MAX(T1."Series")            AS "Series",
        MAX(T0."LineNum")           AS "LineNum"
    FROM "IGN1" T0
    JOIN "OIGN" T1 ON T0."DocEntry" = T1."DocEntry"
    WHERE T0."U_beas_belnrid" IS NOT NULL
    GROUP BY T0."U_beas_belnrid", T0."U_beas_belposid"), "Maquinas_Reales" AS (SELECT
        "BELNR_ID",
        "BELPOS_ID",
        COUNT("APLATZ_ID")          AS "Cant_Maquinas"
    FROM "BEAS_FTAPL"
    WHERE "APLATZ_ID" LIKE 'MA%'
    GROUP BY "BELNR_ID", "BELPOS_ID"), "Kg_MP" AS (
    SELECT
        T3."BELNR_ID",
        T3."BELPOS_ID",
        SUM(ABS(T3."BookedQty")) AS "Kg"
    FROM "BEAS_FTSTL" T3
    WHERE T3."ART1_ID" LIKE 'MP%'
    GROUP BY T3."BELNR_ID", T3."BELPOS_ID"
), "Kg_PTPR" AS (
    SELECT
        T3."BELNR_ID",
        T3."BELPOS_ID",
        SUM(
            ABS(T3."BookedQty") * CASE
                WHEN UPPER(IFNULL(T5."InvntryUom", '')) IN ('KG', 'KILOGRAMO') THEN 1
                ELSE IFNULL(T5."IWeight1", 0) / 1000.0
            END
        ) AS "Kg"
    FROM "BEAS_FTSTL" T3
    LEFT JOIN "OITM" T5 ON T3."ART1_ID" = T5."ItemCode"
    WHERE T3."ART1_ID" LIKE 'PTPR%'
    GROUP BY T3."BELNR_ID", T3."BELPOS_ID"
), "BEAS_CONSOLIDADO" AS (SELECT
        T0."BELNR_ID",
        T0."BELPOS_ID",
        T0."ABGKZ_DATE"             AS "Fecha_Cierre",
        T0."ItemCode",
        T0."ItemName",
        T0."GEL_MENGE"             AS "Cantidad_Real",
        T4."IWeight1"              AS "Peso_Std",
        T4."SalUnitMsr"            AS "UoM_Maestro",
        T4."U_ProcesoProductivo",
        CAST(ABS(CASE
            WHEN UPPER(T4."SalUnitMsr") = 'UN' THEN (
                CASE WHEN IFNULL(TRIM(T0."DIN"), '') = '' THEN T4."IWeight1" ELSE TO_DECIMAL(T0."DIN") END
                / 1000.0
            ) * T0."GEL_MENGE"
            WHEN UPPER(T4."SalUnitMsr") IN ('KG', 'KILOGRAMO') THEN T0."GEL_MENGE"
            ELSE (T0."GEL_MENGE" * CASE WHEN IFNULL(TRIM(T0."DIN"), '') = '' THEN T4."IWeight1" ELSE TO_DECIMAL(T0."DIN") END) / 1000.0
        END) AS DECIMAL(18,6))     AS "Kg_Base"
    FROM "BEAS_FTPOS" T0
    LEFT JOIN "OITM" T4 ON T0."ItemCode" = T4."ItemCode"
    WHERE T0."ABGKZ" = 'J'
      AND T0."GEL_MENGE" > 0) SELECT
    CAST('PROCESADO'                        AS VARCHAR(12))     AS "origen",
    CAST(B."Fecha_Cierre"                   AS TIMESTAMP)       AS "fecha",
    YEAR(B."Fecha_Cierre")                                      AS "anio",
    MONTH(B."Fecha_Cierre")                                     AS "mes",
    DAYOFMONTH(B."Fecha_Cierre")                                AS "dia",
    CAST(COALESCE(CR."Sucursal", '')        AS VARCHAR(50))     AS "sucursal",
    CAST(B."ItemCode"                       AS NVARCHAR(50))    AS "Codigo_Articulo",
    CAST(B."ItemName"                       AS NVARCHAR(200))   AS "Nombre_Articulo",
    CAST(B."BELNR_ID"                       AS VARCHAR(50))     AS "Lote_Orden",
    CR."DocNum"                                                 AS "Recibo_Produccion",
    CR."LineNum"                                                AS "Linea_Recibo",
    CAST(COALESCE(CR."Bodega", '')          AS NVARCHAR(8))     AS "Bodega_Recepcion",
    CAST(CR."Series"                        AS VARCHAR(50))     AS "Serie_o_Tipo",
    CAST(COALESCE(CR."Sucursal",    '')     AS VARCHAR(50))     AS "Sucursal_CC",
    CAST(COALESCE(CR."Area",        '')     AS VARCHAR(50))     AS "Area",
    CAST(COALESCE(CR."Departamento",'')     AS VARCHAR(50))     AS "Departamento",
    CAST(COALESCE(CR."Maquina",     '')     AS VARCHAR(50))     AS "Maquina",
    CAST(
        CASE B."U_ProcesoProductivo"
            WHEN '01' THEN 'EXTRUSION'
            WHEN '02' THEN 'SELLADO'
            WHEN '03' THEN 'SOPLADO CONVENCIONAL'
            WHEN '04' THEN 'INYECCION CONVENCIONAL'
            WHEN '05' THEN 'INYECCION PET'
            WHEN '06' THEN 'SOPLADO PET'
            WHEN '07' THEN 'INYECTO SOPLADO'
            ELSE            'OTROS'
        END
    AS VARCHAR(22))                                             AS "linea_produccion",
    CAST(COALESCE(B."UoM_Maestro", '')      AS NVARCHAR(100))  AS "Unidad_Medida_Inv",
    CAST(
        CASE
            WHEN UPPER(B."UoM_Maestro") IN ('KG', 'KILOGRAMO') THEN ''
            ELSE 'g'
        END
    AS NVARCHAR(2))                                             AS "Unidad_Peso_Maestro",
    B."Cantidad_Real"                                           AS "cantidad_unidades",
    B."Peso_Std"                                               AS "peso_unitario_maestro",
    CAST(ABS(CASE
        WHEN CR."Departamento" = 'INY-PET' THEN COALESCE(MP."Kg", B."Kg_Base")
        WHEN CR."Departamento" IN ('SOP-PET', 'SOPPETGY') THEN COALESCE(PT."Kg", B."Kg_Base")
        WHEN CR."Departamento" = 'IMPR-BOB' THEN B."Kg_Base" * COALESCE(M."Cant_Maquinas", 1)
        ELSE B."Kg_Base"
    END) * 1000.0 AS DECIMAL(18,6))                            AS "total_gramos",
    CAST(ABS(CASE
        WHEN CR."Departamento" = 'INY-PET' THEN COALESCE(MP."Kg", B."Kg_Base")
        WHEN CR."Departamento" IN ('SOP-PET', 'SOPPETGY') THEN COALESCE(PT."Kg", B."Kg_Base")
        WHEN CR."Departamento" = 'IMPR-BOB' THEN B."Kg_Base" * COALESCE(M."Cant_Maquinas", 1)
        ELSE B."Kg_Base"
    END) AS DECIMAL(18,6))                                     AS "kilogramos_completados",
    CAST(ABS(CASE
        WHEN CR."Departamento" = 'INY-PET' THEN COALESCE(MP."Kg", B."Kg_Base")
        WHEN CR."Departamento" IN ('SOP-PET', 'SOPPETGY') THEN COALESCE(PT."Kg", B."Kg_Base")
        WHEN CR."Departamento" = 'IMPR-BOB' THEN B."Kg_Base" * COALESCE(M."Cant_Maquinas", 1)
        ELSE B."Kg_Base"
    END) / 1000.0 AS DECIMAL(18,6))                            AS "toneladas_completadas"
FROM "BEAS_CONSOLIDADO" B
LEFT JOIN "CostoRealHeader" CR
    ON  CR."U_beas_belnrid"  = B."BELNR_ID"
    AND CR."U_beas_belposid" = B."BELPOS_ID"
LEFT JOIN "Maquinas_Reales" M
    ON  M."BELNR_ID"  = B."BELNR_ID"
    AND M."BELPOS_ID" = B."BELPOS_ID"
LEFT JOIN "Kg_MP" MP
    ON  MP."BELNR_ID"  = B."BELNR_ID"
    AND MP."BELPOS_ID" = B."BELPOS_ID"
LEFT JOIN "Kg_PTPR" PT
    ON  PT."BELNR_ID"  = B."BELNR_ID"
    AND PT."BELPOS_ID" = B."BELPOS_ID"
ORDER BY B."Fecha_Cierre" DESC, B."BELNR_ID";
