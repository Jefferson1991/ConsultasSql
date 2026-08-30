CREATE VIEW SB1_VIEW_UBICACIONES_UPC AS 
SELECT  

    T0."Code",
    T0."Name",
    T1."ItmsGrpCod",
    T1."LastPurPrc",
    T2."WhsCode",
    T2."OnHand",
    T0."U_EMPA_SECCION_ITEM",
    T0."U_EMPA_PERCHA_ITEM",
    T0."U_EMPA_FILA_ITEM",
    T0."U_EMPA_ESPACIO_ITEM"
FROM
    "@T_UBICACION_ITEM" T0
LEFT JOIN OITM T1 ON T1."ItemCode" = T0."Code"
LEFT JOIN OITW T2 ON T2."ItemCode" = T0."Code"
WHERE (T2."WhsCode" IN ('UIO_ MAT'))
