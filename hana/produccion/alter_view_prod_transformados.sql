-- =============================================================================
-- ALTER VIEW: SB1_VIEW_PROD_TRANSFORMADOS
-- Esquema: EMPAQPLAST_PROD
-- Fecha:   2026-04-10
--
-- OBJETIVO:
--   Reemplazar la lógica de cálculo de kg por la misma fuente aprobada por
--   el departamento de costos: SB1_VIEW_KG_TRANSFORMADOS_EFICIENCIA_ENERGETICA.
--   Se mantienen exactamente los mismos nombres de columnas para no romper
--   los tableros existentes que consumen esta vista.
--
-- PROBLEMA ORIGINAL:
--   La vista anterior usaba OIGE/IGE1 (consumos MP) + OIGN/IGN1 (PT recibidos)
--   mezclados, lo que generaba:
--     - Registros de CONSUMO MP inflando el total de kg
--     - Desfase vs la vista aprobada por costos (~487k kg vs ~177k kg en abril 2026)
--     - Coincidencias falsas de Lote_Orden entre distintos años/tipos de documento
--
-- SOLUCION:
--   Fuente única: BEAS_FTPOS (OTs confirmadas, ABGKZ='J', GEL_MENGE>0)
--   Cálculo de kg idéntico al aprobado:
--     UN       → (IWeight1 / 1000) × cantidad
--     KG/KILO  → cantidad
--     Otro     → (cantidad × IWeight1) / 1000
--   Ajuste IMPR-BOB: multiplica por cantidad real de máquinas (recursos MA%)
--
-- VALIDACION ABRIL 2026:
--   Vista aprobada   = 176,742.5977 kg | 65 registros
--   Nueva lógica     = 176,742.5977 kg | 65 registros  ✓
-- =============================================================================

-- NOTA: "CREATE OR REPLACE VIEW" es sintaxis válida de SAP HANA.
-- DBeaver puede mostrar falso error si el parser está en modo SQL Server.
-- Ejecutar desde una conexión HANA o con el parser configurado en "SQL Genérico".
CREATE OR REPLACE VIEW EMPAQPLAST_PROD.SB1_VIEW_PROD_TRANSFORMADOS AS

WITH "CostoRealHeader" AS (
-- Dimensiones de CC y datos del recibo físico (OIGN) por OT+Posición
    SELECT
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
    GROUP BY T0."U_beas_belnrid", T0."U_beas_belposid"
),

"Maquinas_Reales" AS (
-- Cantidad de máquinas reales (recursos MA%) por OT+Posición — ajuste IMPR-BOB
    SELECT
        "BELNR_ID",
        "BELPOS_ID",
        COUNT("APLATZ_ID")          AS "Cant_Maquinas"
    FROM "BEAS_FTAPL"
    WHERE "APLATZ_ID" LIKE 'MA%'
    GROUP BY "BELNR_ID", "BELPOS_ID"
),

"BEAS_CONSOLIDADO" AS (
-- OTs confirmadas con cantidad real > 0 y su cálculo base de Kg (misma lógica aprobada)
    SELECT
        T0."BELNR_ID",
        T0."BELPOS_ID",
        T0."ABGKZ_DATE"             AS "Fecha_Cierre",
        T0."ItemCode",
        T0."ItemName",
        T0."GEL_MENGE"             AS "Cantidad_Real",
        T4."IWeight1"              AS "Peso_Std",
        T4."SalUnitMsr"            AS "UoM_Maestro",
        T4."U_ProcesoProductivo",
        CAST(
            CASE
                WHEN UPPER(T4."SalUnitMsr") = 'UN'
                    THEN (T4."IWeight1" / 1000.0) * T0."GEL_MENGE"
                WHEN UPPER(T4."SalUnitMsr") IN ('KG', 'KILOGRAMO')
                    THEN T0."GEL_MENGE"
                ELSE
                    (T0."GEL_MENGE" * T4."IWeight1") / 1000.0
            END
        AS DECIMAL(18,6))          AS "Kg_Base"
    FROM "BEAS_FTPOS" T0
    LEFT JOIN "OITM" T4 ON T0."ItemCode" = T4."ItemCode"
    WHERE T0."ABGKZ" = 'J'
      AND T0."GEL_MENGE" > 0
)

SELECT
    -- -------------------------------------------------------------------------
    -- Identificación / origen
    -- -------------------------------------------------------------------------
    CAST('PROCESADO'                        AS VARCHAR(12))     AS "origen",
    CAST(B."Fecha_Cierre"                   AS TIMESTAMP)       AS "fecha",
    YEAR(B."Fecha_Cierre")                                      AS "anio",
    MONTH(B."Fecha_Cierre")                                     AS "mes",
    DAYOFMONTH(B."Fecha_Cierre")                                AS "dia",
    CAST(COALESCE(CR."Sucursal", '')        AS VARCHAR(50))     AS "sucursal",

    -- -------------------------------------------------------------------------
    -- Artículo
    -- -------------------------------------------------------------------------
    CAST(B."ItemCode"                       AS NVARCHAR(50))    AS "Codigo_Articulo",
    CAST(B."ItemName"                       AS NVARCHAR(200))   AS "Nombre_Articulo",

    -- -------------------------------------------------------------------------
    -- Documento / recibo
    -- -------------------------------------------------------------------------
    CAST(B."BELNR_ID"                       AS VARCHAR(50))     AS "Lote_Orden",
    CR."DocNum"                                                 AS "Recibo_Produccion",
    CR."LineNum"                                                AS "Linea_Recibo",
    CAST(COALESCE(CR."Bodega", '')          AS NVARCHAR(8))     AS "Bodega_Recepcion",
    CAST(CR."Series"                        AS VARCHAR(50))     AS "Serie_o_Tipo",

    -- -------------------------------------------------------------------------
    -- Centros de costo
    -- -------------------------------------------------------------------------
    CAST(COALESCE(CR."Sucursal",    '')     AS VARCHAR(50))     AS "Sucursal_CC",
    CAST(COALESCE(CR."Area",        '')     AS VARCHAR(50))     AS "Area",
    CAST(COALESCE(CR."Departamento",'')     AS VARCHAR(50))     AS "Departamento",
    CAST(COALESCE(CR."Maquina",     '')     AS VARCHAR(50))     AS "Maquina",

    -- -------------------------------------------------------------------------
    -- Clasificación de línea de producción (desde OITM.U_ProcesoProductivo)
    -- -------------------------------------------------------------------------
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

    -- -------------------------------------------------------------------------
    -- Unidades de medida
    -- -------------------------------------------------------------------------
    CAST(COALESCE(B."UoM_Maestro", '')      AS NVARCHAR(100))  AS "Unidad_Medida_Inv",
    CAST(
        CASE
            WHEN UPPER(B."UoM_Maestro") IN ('KG', 'KILOGRAMO') THEN ''
            ELSE 'g'
        END
    AS NVARCHAR(2))                                             AS "Unidad_Peso_Maestro",

    -- -------------------------------------------------------------------------
    -- Cantidades y pesos (misma lógica aprobada por costos)
    -- -------------------------------------------------------------------------
    B."Cantidad_Real"                                           AS "cantidad_unidades",
    B."Peso_Std"                                               AS "peso_unitario_maestro",

    -- total_gramos: Kg aprobado × 1000 (con ajuste IMPR-BOB)
    CAST(
        CASE
            WHEN CR."Departamento" = 'IMPR-BOB'
                THEN B."Kg_Base" * COALESCE(M."Cant_Maquinas", 1) * 1000.0
            ELSE
                B."Kg_Base" * 1000.0
        END
    AS DECIMAL(18,6))                                          AS "total_gramos",

    -- kilogramos_completados: idéntico a columna "Kg" de la vista aprobada
    CAST(
        CASE
            WHEN CR."Departamento" = 'IMPR-BOB'
                THEN B."Kg_Base" * COALESCE(M."Cant_Maquinas", 1)
            ELSE
                B."Kg_Base"
        END
    AS DECIMAL(18,6))                                          AS "kilogramos_completados",

    -- toneladas_completadas: Kg / 1000
    CAST(
        CASE
            WHEN CR."Departamento" = 'IMPR-BOB'
                THEN (B."Kg_Base" * COALESCE(M."Cant_Maquinas", 1)) / 1000.0
            ELSE
                B."Kg_Base" / 1000.0
        END
    AS DECIMAL(18,6))                                          AS "toneladas_completadas"

FROM "BEAS_CONSOLIDADO" B

LEFT JOIN "CostoRealHeader" CR
    ON  CR."U_beas_belnrid"  = B."BELNR_ID"
    AND CR."U_beas_belposid" = B."BELPOS_ID"

LEFT JOIN "Maquinas_Reales" M
    ON  M."BELNR_ID"  = B."BELNR_ID"
    AND M."BELPOS_ID" = B."BELPOS_ID"

ORDER BY B."Fecha_Cierre" DESC, B."BELNR_ID";
