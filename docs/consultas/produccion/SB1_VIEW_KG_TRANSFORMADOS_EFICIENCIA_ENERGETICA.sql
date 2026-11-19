-- =============================================================================
-- SB1_VIEW_KG_TRANSFORMADOS_EFICIENCIA_ENERGETICA
-- Esquema: EMPAQPLAST_PROD | Motor: SAP HANA
-- Fecha:   2026-09-08
--
-- OBJETIVO:
--   Kg transformados por OT Beas confirmada (ABGKZ='J', GEL_MENGE>0)
--   para eficiencia energética y costos. Mismos nombres de columna.
--
-- REGLA DE KG (columna "Kg"):
--   INY-PET            → SUM(ABS(BookedQty)) de BOM MP% (resina).
--                        Merma/desperdicio MER%/DES% no restan.
--   SOP-PET / SOPPETGY → SUM ABS(BookedQty) de BOM PTPR% × IWeight1/1000.
--                        Fundas y merma no entran.
--   IMPR-BOB           → Kg_Base × cantidad de recursos MA%.
--   Resto              → cantidad × (DIN si existe; si no OITM.IWeight1) / 1000.
--
-- VALIDACION PRODUCCION:
--   OT 9725 INY-PET  Kg = 5783.1648  (4048.2154 + 1734.9494; merma -8.4 excluida)
--   OT 9775 SOP-PET  Kg = 1064.085   (70939 preformas × 15 g)
--
-- Despliegue: CREATE OR REPLACE VIEW en EMPAQPLAST_PROD
-- Alineada con: SB1_VIEW_PROD_TRANSFORMADOS (kilogramos_completados)
-- =============================================================================
--CREATE VIEW EMPAQPLAST_PROD.SB1_VIEW_KG_TRANSFORMADOS_EFICIENCIA_ENERGETICA AS
WITH "CostoRealHeader" AS (SELECT 
        "U_beas_belnrid", 
        "U_beas_belposid", 
        MAX("OcrCode") AS "Sucursal",
        MAX("OcrCode2") AS "Area",
        MAX("OcrCode3") AS "Departamento",
        MAX("OcrCode4") AS "Maquina",
        MAX("WhsCode") AS "Bodega"
    FROM "IGN1" 
    WHERE "U_beas_belnrid" IS NOT NULL
    GROUP BY "U_beas_belnrid", "U_beas_belposid"), "Maquinas_Reales" AS (SELECT 
        "BELNR_ID", 
        "BELPOS_ID", 
        COUNT("APLATZ_ID") AS "Cant_Maquinas"
    FROM "BEAS_FTAPL"
    WHERE "APLATZ_ID" LIKE 'MA%' -- FILTRO CLAVE: Solo recursos que empiezan con MA
    GROUP BY "BELNR_ID", "BELPOS_ID"), "Kg_MP" AS (
    -- INY-PET: solo resina MP. ABS para que merma negativa no reste.
    SELECT
        T3."BELNR_ID",
        T3."BELPOS_ID",
        SUM(ABS(T3."BookedQty")) AS "Kg"
    FROM "BEAS_FTSTL" T3
    WHERE T3."ART1_ID" LIKE 'MP%'
    GROUP BY T3."BELNR_ID", T3."BELPOS_ID"
), "Kg_PTPR" AS (
    -- SOP-PET: solo preforma PTPR. ABS para que merma negativa no reste.
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
        'BEAS' AS "Fuente",
        T0."BELNR_ID" AS "OT_Num",
        CAST(T0."ABGKZ_DATE" AS DATE) AS "Fecha_Cierre",
        T0."ItemCode",
        T0."GEL_MENGE" AS "Cantidad_Real",
        T4."IWeight1" AS "Peso_Std",
        T4."SalUnitMsr" AS "UoM_Maestro",
        CAST(ABS(CASE 
            WHEN UPPER(T4."SalUnitMsr") = 'UN' THEN (
                CASE WHEN IFNULL(TRIM(T0."DIN"), '') = '' THEN T4."IWeight1" ELSE TO_DECIMAL(T0."DIN") END
                / 1000.0
            ) * T0."GEL_MENGE"
            WHEN UPPER(T4."SalUnitMsr") IN ('KG', 'KILOGRAMO') THEN T0."GEL_MENGE"
            ELSE (T0."GEL_MENGE" * CASE WHEN IFNULL(TRIM(T0."DIN"), '') = '' THEN T4."IWeight1" ELSE TO_DECIMAL(T0."DIN") END) / 1000.0 
        END) AS DECIMAL(18,6)) AS "Kg_Base",
        T0."BELPOS_ID"
    FROM "BEAS_FTPOS" T0
    LEFT JOIN "OITM" T4 ON T0."ItemCode" = T4."ItemCode"
    WHERE T0."ABGKZ" = 'J' 
      AND T0."GEL_MENGE" > 0) SELECT
    B."Fuente",
    CAST(B."OT_Num" AS NVARCHAR(50)) AS "Documento Entrada Mercancias",
    CAST(B."OT_Num" AS NVARCHAR(50)) AS "OT",
    B."Fecha_Cierre" AS "Fecha",
    YEAR(B."Fecha_Cierre") AS "Anio",
    MONTH(B."Fecha_Cierre") AS "Mes",
    B."Cantidad_Real" AS "Cantidad",
    B."Peso_Std" AS "Peso",
    CAST(ABS(CASE 
        WHEN CR."Departamento" = 'INY-PET' THEN COALESCE(MP."Kg", B."Kg_Base")
        WHEN CR."Departamento" IN ('SOP-PET', 'SOPPETGY') THEN COALESCE(PT."Kg", B."Kg_Base")
        WHEN CR."Departamento" = 'IMPR-BOB' THEN B."Kg_Base" * COALESCE(M."Cant_Maquinas", 1)
        ELSE B."Kg_Base" 
    END) AS DECIMAL(18,6)) AS "Kg",
    CAST(COALESCE(CR."Sucursal", '') AS NVARCHAR(50)) AS "Sucursal",
    CAST(COALESCE(CR."Area", '') AS NVARCHAR(50)) AS "Area",
    CAST(COALESCE(CR."Departamento", '') AS NVARCHAR(50)) AS "Departamento",
    CAST(COALESCE(CR."Maquina", '') AS NVARCHAR(50)) AS "Maquina",
    CAST(COALESCE(CR."Bodega", '') AS NVARCHAR(50)) AS "Bodega"
FROM "BEAS_CONSOLIDADO" B
LEFT JOIN "CostoRealHeader" CR ON CAST(CR."U_beas_belnrid" AS NVARCHAR(50)) = CAST(B."OT_Num" AS NVARCHAR(50)) 
                             AND CR."U_beas_belposid" = B."BELPOS_ID"
LEFT JOIN "Maquinas_Reales" M ON M."BELNR_ID" = B."OT_Num" AND M."BELPOS_ID" = B."BELPOS_ID"
LEFT JOIN "Kg_MP" MP ON MP."BELNR_ID" = B."OT_Num" AND MP."BELPOS_ID" = B."BELPOS_ID"
LEFT JOIN "Kg_PTPR" PT ON PT."BELNR_ID" = B."OT_Num" AND PT."BELPOS_ID" = B."BELPOS_ID"
ORDER BY B."Fecha_Cierre" DESC, B."OT_Num";
