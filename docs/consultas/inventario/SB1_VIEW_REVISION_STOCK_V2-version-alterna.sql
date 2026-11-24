-- EMPAQPLAST_PROD.SB1_VIEW_REVISION_STOCK_V2 source
-- Vista viva (con ajuste -74250 en MPPASO00001).
-- 2026-11-24: OC pendientes = abiertas con OpenQty
--   O cerradas aún en carpeta (@ALS_CARPETA_IMP) con status
--   Por embarcarse / En tránsito / En nacionalización.
--   Link: OPOR.U_SYP_CARPIMP = @ALS_CARPETA_IMP.Code (LogInst = MAX).
--   Cantidad: solo del pedido (POR1.OpenQty si > 0; si no POR1.Quantity).

ALTER VIEW EMPAQPLAST_PROD.SB1_VIEW_REVISION_STOCK_V2 AS
SELECT
    -- =====================================================
    -- DATOS DE LA REVISIÓN
    -- =====================================================
    T0."Code"            AS "Revision_Code",
    T0."U_EMPA_DIAS_SUG" AS "Dias_Sugeridos",
    T0."U_EMPA_FECHA"    AS "Fecha_Revision",

    -- =====================================================
    -- DATOS DEL ARTÍCULO
    -- =====================================================
    T1."U_EMPA_MP_CODE"    AS "Codigo_MP",
    T1."U_EMPA_ITEMCODE"   AS "Codigo_Articulo",
    T6."ItemName"          AS "Descripcion",
    T1."U_EMPA_CONS_DIARIO" AS "CPD_Kg",
    T1."U_EMPA_STOCK_SUG"  AS "Stock_Sugerido",
    T1."U_EMPA_STOCK_SEG"  AS "Stock_Seguridad_Lin",

    -- =====================================================
    -- PARÁMETROS MAESTROS
    -- =====================================================
    T6."LeadTime"                  AS "Lead_Time",
    COALESCE(T6."MinOrdrQty", 0)   AS "MOQ",
    0.10  AS "Pct_Lead_Time",
    15    AS "Frecuencia_Dias",
    0.80  AS "Pct_Variacion",

    -- =====================================================
    -- STOCK FÍSICO Y TRÁNSITO
    -- =====================================================
    COALESCE(T3."OnHand",0)                                AS "Stock_Fisico_UIO",
    COALESCE(T5."OnHand",0)                                AS "Stock_Fisico_GYE",
    COALESCE(T3."OnHand",0) + COALESCE(T5."OnHand",0)      AS "Total_MP_Fisico",

    SUM(
        CASE
            WHEN T4."ItemCode" = 'MPPASO00001' THEN (T4."OnHand" + T4."OnOrder" - 74250)
            ELSE (T4."OnHand" + T4."OnOrder")
        END
    ) AS "Transito_kg",

    ( COALESCE(T3."OnHand",0) + COALESCE(T5."OnHand",0) +
      SUM(
        CASE
            WHEN T4."ItemCode" = 'MPPASO00001' THEN (T4."OnHand" + T4."OnOrder" - 74250)
            ELSE (T4."OnHand" + T4."OnOrder")
        END
      )
    ) AS "Stock_Neto_kg",

    -- =====================================================
    -- DÍAS DE COBERTURA
    -- =====================================================
    ROUND( (COALESCE(T3."OnHand",0) + COALESCE(T5."OnHand",0))
           / NULLIF(T1."U_EMPA_CONS_DIARIO",0), 2 ) AS "Dias_Stock_Fisico",

    CASE WHEN T1."U_EMPA_CONS_DIARIO" = 0 THEN NULL
         ELSE ROUND(
            ( COALESCE(T3."OnHand",0) + COALESCE(T5."OnHand",0) +
              SUM(
                CASE
                    WHEN T4."ItemCode" = 'MPPASO00001' THEN (T4."OnHand" + T4."OnOrder" - 74250)
                    ELSE (T4."OnHand" + T4."OnOrder")
                END
              )
            ) / T1."U_EMPA_CONS_DIARIO", 2)
    END AS "Dias_Stock_Neto",

    -- =====================================================
    -- FECHAS DE ANÁLISIS
    -- =====================================================
    CURRENT_DATE AS "Fecha_Analisis",

    ADD_DAYS(CURRENT_DATE,
        FLOOR( (COALESCE(T3."OnHand",0) + COALESCE(T5."OnHand",0))
               / NULLIF(T1."U_EMPA_CONS_DIARIO",0) )
    ) AS "Fecha_Stock_Fisico",

    ADD_DAYS(CURRENT_DATE,
        FLOOR(
            ( COALESCE(T3."OnHand",0) + COALESCE(T5."OnHand",0) +
              SUM(
                CASE
                    WHEN T4."ItemCode" = 'MPPASO00001' THEN (T4."OnHand" + T4."OnOrder" - 74250)
                    ELSE (T4."OnHand" + T4."OnOrder")
                END
              )
            ) / NULLIF(T1."U_EMPA_CONS_DIARIO",0)
        )
    ) AS "Fecha_Disponibilidad_Stock",

    -- =====================================================
    -- ZONAS DE COLORES (DDMRP / BUFFER MANAGEMENT)
    -- =====================================================
    ROUND( T1."U_EMPA_CONS_DIARIO" * T6."LeadTime" * 0.10, 2 ) AS "Zona_Roja_Buffer_ZRB",
    ROUND( T1."U_EMPA_CONS_DIARIO" * T6."LeadTime" * 0.10 * 0.80, 2 ) AS "Zona_Roja_ZR",
    ROUND( T1."U_EMPA_CONS_DIARIO" * T6."LeadTime", 2 ) AS "Zona_Amarilla_ZA",
    ROUND( T1."U_EMPA_CONS_DIARIO" * 15, 2 ) AS "Zona_Verde_ZV",

    ROUND( (T1."U_EMPA_CONS_DIARIO" * T6."LeadTime" * 0.10)
         + (T1."U_EMPA_CONS_DIARIO" * T6."LeadTime" * 0.10 * 0.80), 2 )
         AS "TDR_Stock_Seguridad",

    ROUND( (T1."U_EMPA_CONS_DIARIO" * T6."LeadTime" * 0.10)
         + (T1."U_EMPA_CONS_DIARIO" * T6."LeadTime" * 0.10 * 0.80)
         + (T1."U_EMPA_CONS_DIARIO" * T6."LeadTime"), 2 )
         AS "TDA_ROP",

    ROUND( (T1."U_EMPA_CONS_DIARIO" * T6."LeadTime" * 0.10)
         + (T1."U_EMPA_CONS_DIARIO" * T6."LeadTime" * 0.10 * 0.80)
         + (T1."U_EMPA_CONS_DIARIO" * T6."LeadTime")
         + (T1."U_EMPA_CONS_DIARIO" * 15), 2 )
         AS "TDV_Stock_Maximo",

    -- =====================================================
    -- SEMÁFORO DE ESTADO
    -- =====================================================
    CASE
        WHEN ( COALESCE(T3."OnHand",0) + COALESCE(T5."OnHand",0) +
               SUM(CASE WHEN T4."ItemCode" = 'MPPASO00001'
                        THEN (T4."OnHand" + T4."OnOrder" - 74250)
                        ELSE (T4."OnHand" + T4."OnOrder") END)
             ) <= ((T1."U_EMPA_CONS_DIARIO" * T6."LeadTime" * 0.10)
                 + (T1."U_EMPA_CONS_DIARIO" * T6."LeadTime" * 0.10 * 0.80))
        THEN 'ROJO - CRITICO'
        WHEN ( COALESCE(T3."OnHand",0) + COALESCE(T5."OnHand",0) +
               SUM(CASE WHEN T4."ItemCode" = 'MPPASO00001'
                        THEN (T4."OnHand" + T4."OnOrder" - 74250)
                        ELSE (T4."OnHand" + T4."OnOrder") END)
             ) <= ((T1."U_EMPA_CONS_DIARIO" * T6."LeadTime" * 0.10)
                 + (T1."U_EMPA_CONS_DIARIO" * T6."LeadTime" * 0.10 * 0.80)
                 + (T1."U_EMPA_CONS_DIARIO" * T6."LeadTime"))
        THEN 'AMARILLO - COMPRAR'
        WHEN ( COALESCE(T3."OnHand",0) + COALESCE(T5."OnHand",0) +
               SUM(CASE WHEN T4."ItemCode" = 'MPPASO00001'
                        THEN (T4."OnHand" + T4."OnOrder" - 74250)
                        ELSE (T4."OnHand" + T4."OnOrder") END)
             ) <= ((T1."U_EMPA_CONS_DIARIO" * T6."LeadTime" * 0.10)
                 + (T1."U_EMPA_CONS_DIARIO" * T6."LeadTime" * 0.10 * 0.80)
                 + (T1."U_EMPA_CONS_DIARIO" * T6."LeadTime")
                 + (T1."U_EMPA_CONS_DIARIO" * 15))
        THEN 'VERDE - OK'
        ELSE 'EXCESO'
    END AS "Estado_Stock",

    -- =====================================================
    -- INDICADORES DE PLANIFICACIÓN
    -- =====================================================
    ROUND( ((T1."U_EMPA_CONS_DIARIO" * T6."LeadTime" * 0.10)
          + (T1."U_EMPA_CONS_DIARIO" * T6."LeadTime" * 0.10 * 0.80))
          / NULLIF(T1."U_EMPA_CONS_DIARIO",0), 2 ) AS "Dias_Stock_Seguridad",

    ROUND( ((T1."U_EMPA_CONS_DIARIO" * T6."LeadTime" * 0.10)
          + (T1."U_EMPA_CONS_DIARIO" * T6."LeadTime" * 0.10 * 0.80)
          + (T1."U_EMPA_CONS_DIARIO" * T6."LeadTime"))
        + ( ( ((T1."U_EMPA_CONS_DIARIO" * T6."LeadTime" * 0.10)
             + (T1."U_EMPA_CONS_DIARIO" * T6."LeadTime" * 0.10 * 0.80)
             + (T1."U_EMPA_CONS_DIARIO" * T6."LeadTime"))
            - ((T1."U_EMPA_CONS_DIARIO" * T6."LeadTime" * 0.10)
             + (T1."U_EMPA_CONS_DIARIO" * T6."LeadTime" * 0.10 * 0.80)
             + (T1."U_EMPA_CONS_DIARIO" * T6."LeadTime")
             + (T1."U_EMPA_CONS_DIARIO" * 15)) ) / 2 ), 2
    ) AS "Cantidad_A_Comprar",

    ADD_DAYS( CURRENT_DATE,
        FLOOR(
            (
              ( COALESCE(T3."OnHand",0) + COALESCE(T5."OnHand",0) +
                SUM(CASE WHEN T4."ItemCode" = 'MPPASO00001'
                         THEN (T4."OnHand" + T4."OnOrder" - 74250)
                         ELSE (T4."OnHand" + T4."OnOrder") END)
              )
              - ((T1."U_EMPA_CONS_DIARIO" * T6."LeadTime" * 0.10)
               + (T1."U_EMPA_CONS_DIARIO" * T6."LeadTime" * 0.10 * 0.80))
            ) / NULLIF(T1."U_EMPA_CONS_DIARIO",0)
            - COALESCE(T6."LeadTime", 0)
        )
    ) AS "Fecha_De_Compra",

    ADD_DAYS(
        ADD_DAYS( CURRENT_DATE,
            FLOOR(
                (
                  ( COALESCE(T3."OnHand",0) + COALESCE(T5."OnHand",0) +
                    SUM(CASE WHEN T4."ItemCode" = 'MPPASO00001'
                             THEN (T4."OnHand" + T4."OnOrder" - 74250)
                             ELSE (T4."OnHand" + T4."OnOrder") END)
                  )
                  - ((T1."U_EMPA_CONS_DIARIO" * T6."LeadTime" * 0.10)
                   + (T1."U_EMPA_CONS_DIARIO" * T6."LeadTime" * 0.10 * 0.80))
                ) / NULLIF(T1."U_EMPA_CONS_DIARIO",0)
                - COALESCE(T6."LeadTime", 0)
            )
        ),
        90
    ) AS "Fecha_Sugerida_Llegada",

    -- =====================================================
    -- ÚLTIMO PEDIDO PENDIENTE (abierto o en importación)
    -- =====================================================
    COALESCE(ULT_PEDIDO."Price", 0)            AS "Precio_Ultimo_Pedido",
    COALESCE(ULT_PEDIDO."Price", 0) * 1.10    AS "Precio_CIF",
    ULT_PEDIDO."DocNum"                       AS "Nro_Pedido_Ultimo",
    ULT_PEDIDO."DocDate"                      AS "Fecha_Pedido_Ultimo",
    COALESCE(ULT_PEDIDO."Cant_Pendiente", 0)  AS "Cant_Ultimo_Pedido",
    ULT_PEDIDO."Status_Importacion"           AS "Status_Importacion",

    COALESCE(OC_PEND."Cant_OC_Abierta", 0)    AS "Cant_OC_Abierta",
    OC_PEND."Fecha_Ultima_OC_Abierta"         AS "Fecha_Ultima_OC_Abierta",
    OC_PEND."Nro_Ultima_OC_Abierta"           AS "Nro_Ultima_OC_Abierta",

    -- Precio mínimo de compra histórico + OC donde se compró a ese precio
    ROUND( PRECIO_MIN."Precio_Min", 4 )  AS "Precio_Min_Compra",
    PRECIO_MIN."DocNum_Min"              AS "OC_Precio_Min",
    PRECIO_MIN."DocDate_Min"             AS "Fecha_OC_Precio_Min",

    -- Precio máximo de compra histórico + OC donde se compró a ese precio
    ROUND( PRECIO_MAX."Precio_Max", 4 )  AS "Precio_Max_Compra",
    PRECIO_MAX."DocNum_Max"              AS "OC_Precio_Max",
    PRECIO_MAX."DocDate_Max"             AS "Fecha_OC_Precio_Max",

    -- Precio promedio histórico
    ROUND( PRECIO_AVG."Precio_Prom", 4 ) AS "Precio_Prom_Compra",

    COALESCE(T3."AvgPrice",0)               AS "Costo_Prom_UIO_MP",
    COALESCE(T5."AvgPrice",0)               AS "Costo_Prom_GYE_MP",
    MAX( COALESCE(T4."AvgPrice",0) )        AS "Costo_Prom_UIO_IMPT",

    ROUND(
      ( COALESCE(T3."OnHand",0) * COALESCE(T3."AvgPrice",0) ) +
      ( COALESCE(T5."OnHand",0) * COALESCE(T5."AvgPrice",0) ), 2
    ) AS "Costo_MP_Piso",

    ROUND( SUM(
        CASE
            WHEN T4."ItemCode" = 'MPPASO00001' THEN
                (T4."OnHand" + T4."OnOrder" - 74250) * COALESCE(ULT_PEDIDO."Price" * 1.085, T4."AvgPrice")
            ELSE
                (T4."OnHand" + T4."OnOrder") * COALESCE(ULT_PEDIDO."Price" * 1.085, T4."AvgPrice")
        END
    ), 2 ) AS "Costo_MP_Transito",

    ROUND(
      ( ( COALESCE(T3."OnHand",0) * COALESCE(T3."AvgPrice",0) ) +
        ( COALESCE(T5."OnHand",0) * COALESCE(T5."AvgPrice",0) ) )
      +
      SUM(
        CASE
            WHEN T4."ItemCode" = 'MPPASO00001' THEN
                (T4."OnHand" + T4."OnOrder" - 74250) * COALESCE(ULT_PEDIDO."Price" * 1.085, T4."AvgPrice")
            ELSE
                (T4."OnHand" + T4."OnOrder") * COALESCE(ULT_PEDIDO."Price" * 1.085, T4."AvgPrice")
        END
      )
    , 2 ) AS "Costo_MP_Total"

FROM "@T_REV_STOCK_CAB" T0
INNER JOIN "@T_REV_STOCK_LIN" T1 ON T1."Code" = T0."Code"
LEFT  JOIN OITW T3 ON T1."U_EMPA_MP_CODE" = T3."ItemCode" AND T3."WhsCode" = 'UIO_MP'
LEFT  JOIN OITW T5 ON T1."U_EMPA_MP_CODE" = T5."ItemCode" AND T5."WhsCode" = 'GYE_MP'
LEFT  JOIN OITW T4 ON T1."U_EMPA_MP_CODE" = T4."ItemCode" AND T4."WhsCode" = 'UIO_IMPT'
LEFT  JOIN OITM T6 ON T1."U_EMPA_MP_CODE" = T6."ItemCode"

-- Carpeta vigente: una fila por Code (MAX LogInst)
-- Último pedido pendiente (B1 abierto O importación no liquidada)
LEFT  JOIN (
    SELECT
        P."ItemCode",
        P."Price",
        P."Cant_Pendiente",
        P."DocNum",
        P."DocDate",
        P."Status_Importacion",
        ROW_NUMBER() OVER(
            PARTITION BY P."ItemCode"
            ORDER BY P."DocDate" DESC, P."DocEntry" DESC
        ) AS "Rank"
    FROM (
        SELECT
            POR1."ItemCode",
            POR1."Price",
            OPOR."DocEntry",
            OPOR."DocNum",
            OPOR."DocDate",
            C."U_EMPA_STATUS_IMPORT" AS "Status_Importacion",
            CASE
                WHEN POR1."OpenQty" > 0 THEN POR1."OpenQty"
                ELSE POR1."Quantity"
            END AS "Cant_Pendiente"
        FROM OPOR
        INNER JOIN POR1 ON OPOR."DocEntry" = POR1."DocEntry"
        LEFT JOIN (
            SELECT C1."Code", C1."U_EMPA_STATUS_IMPORT", C1."U_EMP_ITEM_PEDIDO"
            FROM "@ALS_CARPETA_IMP" C1
            INNER JOIN (
                SELECT "Code", MAX("LogInst") AS "MaxLog"
                FROM "@ALS_CARPETA_IMP"
                GROUP BY "Code"
            ) M ON C1."Code" = M."Code" AND C1."LogInst" = M."MaxLog"
        ) C ON C."Code" = OPOR."U_SYP_CARPIMP"
           AND (C."U_EMP_ITEM_PEDIDO" IS NULL OR C."U_EMP_ITEM_PEDIDO" = POR1."ItemCode")
        WHERE OPOR."CANCELED" = 'N'
          AND COALESCE(C."U_EMPA_STATUS_IMPORT", '') <> 'Anulado'
          AND (
                (OPOR."DocStatus" = 'O' AND POR1."LineStatus" = 'O' AND POR1."OpenQty" > 0)
             OR C."U_EMPA_STATUS_IMPORT" IN ('Por embarcarse', 'En tránsito', 'En nacionalización')
          )
    ) P
) ULT_PEDIDO ON T1."U_EMPA_MP_CODE" = ULT_PEDIDO."ItemCode" AND ULT_PEDIDO."Rank" = 1

-- Total pendiente por artículo + nro/fecha de la más reciente
LEFT  JOIN (
    SELECT
        "ItemCode",
        SUM("Cant_Pendiente") AS "Cant_OC_Abierta",
        MAX("DocDate") AS "Fecha_Ultima_OC_Abierta",
        MAX(CASE WHEN "Rnk" = 1 THEN "DocNum" END) AS "Nro_Ultima_OC_Abierta"
    FROM (
        SELECT
            POR1."ItemCode",
            OPOR."DocDate",
            OPOR."DocNum",
            CASE
                WHEN POR1."OpenQty" > 0 THEN POR1."OpenQty"
                ELSE POR1."Quantity"
            END AS "Cant_Pendiente",
            ROW_NUMBER() OVER(
                PARTITION BY POR1."ItemCode"
                ORDER BY OPOR."DocDate" DESC, OPOR."DocEntry" DESC
            ) AS "Rnk"
        FROM OPOR
        INNER JOIN POR1 ON OPOR."DocEntry" = POR1."DocEntry"
        LEFT JOIN (
            SELECT C1."Code", C1."U_EMPA_STATUS_IMPORT", C1."U_EMP_ITEM_PEDIDO"
            FROM "@ALS_CARPETA_IMP" C1
            INNER JOIN (
                SELECT "Code", MAX("LogInst") AS "MaxLog"
                FROM "@ALS_CARPETA_IMP"
                GROUP BY "Code"
            ) M ON C1."Code" = M."Code" AND C1."LogInst" = M."MaxLog"
        ) C ON C."Code" = OPOR."U_SYP_CARPIMP"
           AND (C."U_EMP_ITEM_PEDIDO" IS NULL OR C."U_EMP_ITEM_PEDIDO" = POR1."ItemCode")
        WHERE OPOR."CANCELED" = 'N'
          AND COALESCE(C."U_EMPA_STATUS_IMPORT", '') <> 'Anulado'
          AND (
                (OPOR."DocStatus" = 'O' AND POR1."LineStatus" = 'O' AND POR1."OpenQty" > 0)
             OR C."U_EMPA_STATUS_IMPORT" IN ('Por embarcarse', 'En tránsito', 'En nacionalización')
          )
    )
    GROUP BY "ItemCode"
) OC_PEND ON T1."U_EMPA_MP_CODE" = OC_PEND."ItemCode"

-- PRECIO MÍNIMO HISTÓRICO
LEFT  JOIN (
    SELECT "ItemCode", "Precio_Min", "DocNum_Min", "DocDate_Min"
    FROM (
        SELECT
            POR1."ItemCode",
            POR1."Price"   AS "Precio_Min",
            OPOR."DocNum"  AS "DocNum_Min",
            OPOR."DocDate" AS "DocDate_Min",
            ROW_NUMBER() OVER (
                PARTITION BY POR1."ItemCode"
                ORDER BY POR1."Price" ASC, OPOR."DocDate" DESC
            ) AS "Rnk"
        FROM OPOR
        INNER JOIN POR1 ON OPOR."DocEntry" = POR1."DocEntry"
        WHERE POR1."Price" > 0.01
          AND OPOR."CANCELED" = 'N'
    )
    WHERE "Rnk" = 1
) PRECIO_MIN ON T1."U_EMPA_MP_CODE" = PRECIO_MIN."ItemCode"

-- PRECIO MÁXIMO HISTÓRICO
LEFT  JOIN (
    SELECT "ItemCode", "Precio_Max", "DocNum_Max", "DocDate_Max"
    FROM (
        SELECT
            POR1."ItemCode",
            POR1."Price"   AS "Precio_Max",
            OPOR."DocNum"  AS "DocNum_Max",
            OPOR."DocDate" AS "DocDate_Max",
            ROW_NUMBER() OVER (
                PARTITION BY POR1."ItemCode"
                ORDER BY POR1."Price" DESC, OPOR."DocDate" DESC
            ) AS "Rnk"
        FROM OPOR
        INNER JOIN POR1 ON OPOR."DocEntry" = POR1."DocEntry"
        WHERE POR1."Price" > 0.01
          AND OPOR."CANCELED" = 'N'
    )
    WHERE "Rnk" = 1
) PRECIO_MAX ON T1."U_EMPA_MP_CODE" = PRECIO_MAX."ItemCode"

-- PRECIO PROMEDIO HISTÓRICO
LEFT  JOIN (
    SELECT
        POR1."ItemCode",
        AVG(POR1."Price") AS "Precio_Prom"
    FROM OPOR
    INNER JOIN POR1 ON OPOR."DocEntry" = POR1."DocEntry"
    WHERE POR1."Price" > 0.01
      AND OPOR."CANCELED" = 'N'
    GROUP BY POR1."ItemCode"
) PRECIO_AVG ON T1."U_EMPA_MP_CODE" = PRECIO_AVG."ItemCode"

WHERE T0."Code" = 4
GROUP BY
    T0."Code", T0."U_EMPA_DIAS_SUG", T0."U_EMPA_FECHA",
    T1."U_EMPA_MP_CODE", T1."U_EMPA_ITEMCODE",
    T1."U_EMPA_CONS_DIARIO", T1."U_EMPA_STOCK_SUG", T1."U_EMPA_STOCK_SEG",
    T3."OnHand", T3."AvgPrice",
    T5."OnHand", T5."AvgPrice",
    T6."ItemName", T6."LeadTime", T6."MinOrdrQty",
    ULT_PEDIDO."Price", ULT_PEDIDO."DocNum", ULT_PEDIDO."DocDate",
    ULT_PEDIDO."Cant_Pendiente", ULT_PEDIDO."Status_Importacion",
    OC_PEND."Cant_OC_Abierta", OC_PEND."Fecha_Ultima_OC_Abierta", OC_PEND."Nro_Ultima_OC_Abierta",
    PRECIO_MIN."Precio_Min", PRECIO_MIN."DocNum_Min", PRECIO_MIN."DocDate_Min",
    PRECIO_MAX."Precio_Max", PRECIO_MAX."DocNum_Max", PRECIO_MAX."DocDate_Max",
    PRECIO_AVG."Precio_Prom"
ORDER BY T1."U_EMPA_ITEMCODE" DESC;
