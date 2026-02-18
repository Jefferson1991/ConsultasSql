-- EMPAQPLAST_PROD.SB1_VIEW_KG_TRANSFORMADOS_EFICIENCIA_ENERGETICA source
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
    GROUP BY "BELNR_ID", "BELPOS_ID"), "BEAS_CONSOLIDADO" AS (SELECT
        'BEAS' AS "Fuente",
        T0."BELNR_ID" AS "OT_Num",
        CAST(T0."ABGKZ_DATE" AS DATE) AS "Fecha_Cierre",
        T0."ItemCode",
        T0."GEL_MENGE" AS "Cantidad_Real",
        T4."IWeight1" AS "Peso_Std",
        T4."SalUnitMsr" AS "UoM_Maestro",
        -- Cálculo base de Kg
        CAST(CASE 
            WHEN UPPER(T4."SalUnitMsr") = 'UN' THEN (T4."IWeight1" / 1000.0) * T0."GEL_MENGE"
            WHEN UPPER(T4."SalUnitMsr") IN ('KG', 'KILOGRAMO') THEN T0."GEL_MENGE"
            ELSE (T0."GEL_MENGE" * T4."IWeight1") / 1000.0 
        END AS DECIMAL(18,6)) AS "Kg_Base",
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
    B."Cantidad_Real" AS "Cantidad", -- Aquí aparecerán los 31,248 o 506 según la OT
    B."Peso_Std" AS "Peso",
    -- AJUSTE: Solo multiplica si el depto es IMPR-BOB y usa el conteo de máquinas reales (MA)
    CAST(CASE 
        WHEN CR."Departamento" = 'IMPR-BOB' THEN B."Kg_Base" * COALESCE(M."Cant_Maquinas", 1)
        ELSE B."Kg_Base" 
    END AS DECIMAL(18,6)) AS "Kg",
    CAST(COALESCE(CR."Sucursal", '') AS NVARCHAR(50)) AS "Sucursal",
    CAST(COALESCE(CR."Area", '') AS NVARCHAR(50)) AS "Area",
    CAST(COALESCE(CR."Departamento", '') AS NVARCHAR(50)) AS "Departamento",
    CAST(COALESCE(CR."Maquina", '') AS NVARCHAR(50)) AS "Maquina",
    CAST(COALESCE(CR."Bodega", '') AS NVARCHAR(50)) AS "Bodega"
FROM "BEAS_CONSOLIDADO" B
LEFT JOIN "CostoRealHeader" CR ON CAST(CR."U_beas_belnrid" AS NVARCHAR(50)) = CAST(B."OT_Num" AS NVARCHAR(50)) 
                             AND CR."U_beas_belposid" = B."BELPOS_ID"
LEFT JOIN "Maquinas_Reales" M ON M."BELNR_ID" = B."OT_Num" AND M."BELPOS_ID" = B."BELPOS_ID" ORDER BY B."Fecha_Cierre" DESC, B."OT_Num";