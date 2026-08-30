-- EMPAQPLAST_PROD.SB1_VIEW_REVISION_STOCK_V2 source

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
    0.10  AS "Pct_Lead_Time",   -- Variabilidad del Lead Time
    15    AS "Frecuencia_Dias", -- Frecuencia de revisión
    0.80  AS "Pct_Variacion",   -- Variación de demanda

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
    -- ÚLTIMO PEDIDO Y RANGO DE PRECIOS HISTÓRICOS
    -- =====================================================
    COALESCE(ULT_PEDIDO."Price", 0)         AS "Precio_Ultimo_Pedido",
    COALESCE(ULT_PEDIDO."Price", 0) * 1.10  AS "Precio_CIF",
    ULT_PEDIDO."DocNum"                     AS "Nro_Pedido_Ultimo",
    ULT_PEDIDO."DocDate"                    AS "Fecha_Pedido_Ultimo",

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

-- ÚLTIMO PEDIDO DE COMPRA
LEFT  JOIN (
    SELECT 
        POR1."ItemCode",
        POR1."Price",
        OPOR."DocNum",
        OPOR."DocDate",
        ROW_NUMBER() OVER(PARTITION BY POR1."ItemCode" ORDER BY OPOR."DocDate" DESC) AS "Rank"
    FROM OPOR 
    INNER JOIN POR1 ON OPOR."DocEntry" = POR1."DocEntry"
) ULT_PEDIDO ON T1."U_EMPA_MP_CODE" = ULT_PEDIDO."ItemCode" AND ULT_PEDIDO."Rank" = 1

-- PRECIO MÍNIMO HISTÓRICO + DocNum y Fecha de esa orden
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

-- PRECIO MÁXIMO HISTÓRICO + DocNum y Fecha de esa orden
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
    PRECIO_MIN."Precio_Min", PRECIO_MIN."DocNum_Min", PRECIO_MIN."DocDate_Min",
    PRECIO_MAX."Precio_Max", PRECIO_MAX."DocNum_Max", PRECIO_MAX."DocDate_Max",
    PRECIO_AVG."Precio_Prom" ORDER BY T1."U_EMPA_ITEMCODE" DESC;