ALTER VIEW SB1_VIEW_REPORTE_ENTRADA_MERCANCIAS_OT AS 

SELECT 
    -- Fechas separadas (compatibles con HANA)
    YEAR(T0."DocDate")                 AS "Año",
    MONTH(T0."DocDate")                AS "Mes",
    DAYOFMONTH(T0."DocDate")           AS "Dia",
    -- Orden y fechas
    T0."DocDate"                       AS "Fecha_Creacion",
    T1."U_beas_belnrid"                AS "OrdenProd",
    T0."DocNum" 					   AS "Documento_Entrada_Mercancias", 
    T2."DocDate" 					   AS "Fecha del movimiento",
    -- Artículo
    T1."ItemCode"                      AS "ItemProduccion",
    T4."ItemName"                      AS "DescItemProd",
    
    T4."InvntryUom"                    AS "Unidad_de_medida",
    T4."IWeight1"                      AS "Peso_Gramos",

    -- Inventario y costos
    T1."WhsCode"                       AS "Almacen",
    
    T4."LastPurPrc"                    AS "CostoEstandarProd",
    T1."Quantity"                         AS "Cantidad",
    T2."CalcPrice"                     AS "CostoReal",
    T2."CalcPrice" * T2."InQty"        AS "Valor_transaccion",
    (T4."IWeight1" / 1000) * T1."Quantity" AS "Peso_Kilogramos",

    -- Organización y clasificación
    T1."OcrCode"                       AS "Sucursal",
    T1."OcrCode2"                      AS "Area",
    T1."OcrCode3"                      AS "Departamento",
    T1."U_beas_znr"                    AS "Codigo_Maquina",
    T1."OcrCode4"					   AS "Maquina",
    T5."ItmsGrpNam"                    AS "Grupo_de_articulos",
    T0."Comments"                     AS "Comentarios "

FROM OIGN T0
INNER JOIN IGN1 T1 ON T1."DocEntry" = T0."DocEntry"
LEFT JOIN OINM T2 ON 
    T2."BASE_REF" = CAST(T0."DocNum" AS NVARCHAR)
    AND T2."DocLineNum" = T1."LineNum"
    AND T2."ItemCode" = T1."ItemCode"
    AND T2."TransType" = 59
LEFT JOIN BEAS_FTPOS T3 ON 
    T3."BELNR_ID" = T1."U_beas_belnrid"
    AND T3."BELPOS_ID" = T1."U_beas_belposid"
INNER JOIN OITM T4 ON T4."ItemCode" = T1."ItemCode"
INNER JOIN OITB T5 ON T5."ItmsGrpCod" = T4."ItmsGrpCod"

WHERE 
    T0."CANCELED" = 'N'
    AND T5."ItmsGrpNam" IN ('PRODUCTO TERMINADO','PRODUCTO SEMIELABORADO')
    AND T1."U_beas_belnrid" > 0
    AND  YEAR(T0."DocDate") IN ('2026')
    --AND T0."DocNum" = 151699
    --AND T1."U_beas_belnrid" = '3658'
  --  AND T1."ItemCode" = 'PTEPET0097'