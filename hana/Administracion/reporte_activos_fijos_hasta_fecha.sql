SELECT
    T0."ItemCode"                              AS "Cod_Articulo",
    T0."ItemName"                              AS "Descripcion",
    T0."ItemType"                              AS "Tipo_Articulo",
    T0."ItmsGrpCod"                            AS "Cod_Grupo",
    G."ItmsGrpNam"                             AS "Grupo_Articulo",
    T0."validFor"                              AS "Activo",
    T0."frozenFor"                             AS "Congelado",
    T0."U_EMPA_COD_RECURSO"                    AS "Recurso",
    T0."U_COD_RECURSO"                         AS "Cod_Recurso_Legacy",
    T0."U_EMPA_COD_BEAS"                       AS "Cod_BEAS",
    T0."U_EMPA_COD_FRACTTAL"                   AS "Cod_Fracttal",
    T0."U_EMPA_TIPO_ITEM"                      AS "Tipo_Item",
    T0."U_EMPA_ESTADO_ACTIVO"                  AS "Estado_Activo",
    T0."U_SEGURO"                              AS "Monto_Asegurado",
    T0."U_VAL_SEGURO"                          AS "Valor_Seguro",
    T0."U_Poliza_Seguros"                      AS "Poliza_Seguros",
    T0."U_EMPA_AVALUADOR"                      AS "Avaluador",
    T0."U_EMPA_VALOR_AVALUO"                   AS "Avaluo",
    T0."U_Garantia_Banco"                      AS "Cod_Ent_Financiera",
    B."BankName"                               AS "Ent_Financiera",
    T0."U_EMPA_VALOR_PRENDA"                   AS "Prenda",
    T0."U_Valor_Garantia"                      AS "Valor_Garantia",
    T0."U_Valor_Reevaluo"                      AS "Valor_Reevaluo",
    T0."U_EMPA_PROCEDENCIA"                    AS "Procedencia",
    T0."U_EMPA_MARCA"                          AS "Marca",
    T0."U_EMPA_MODELO"                         AS "Modelo",
    T0."U_EMPA_SERIE"                          AS "Serie",
    T0."AssetSerNo"                            AS "Serie_SAP",
    T0."UserText"                              AS "Comentarios",
    T0."AssetClass"                            AS "Subclase_AF",
    S."Name"                                   AS "Subclase_AF_Nombre",
    CP."Clase_AF"                              AS "Clase_AF",
    AD."Descr"                                 AS "Clase_AF_Nombre",
    T0."CapDate"                               AS "F_Capitalizacion",
    T0."CreateDate"                            AS "F_Creacion_Registro_SAP",
    T0."UpdateDate"                            AS "F_Ultima_Modificacion",
    C."F_Doc_Capitalizacion"                   AS "F_Doc_Capitalizacion",
    C."F_Contable_Capitalizacion"              AS "F_Contable_Capitalizacion",
    C."No_Doc_Capitalizacion"                  AS "No_Doc_Capitalizacion",
    C."Costo_Documentos_Cap"                   AS "Costo_Documentos_Cap",
    T7."DprStart"                              AS "F_Inicio_Amortizacion",
    T7."DprEnd"                                AS "F_Fin_Amortizacion",
    D."OcrCode"                                AS "Sucursal_Cod",
    OC1."OcrName"                              AS "Sucursal",
    D."OcrCode2"                               AS "Area_Cod",
    OC2."OcrName"                              AS "Area",
    D."OcrCode3"                               AS "Departamento_Cod",
    OC3."OcrName"                              AS "Departamento",
    D."OcrCode4"                               AS "Dimension4_Cod",
    D."OcrCode5"                               AS "Dimension5_Cod",
    D."ValidFrom"                              AS "Dimension_Desde",
    D."ValidTo"                                AS "Dimension_Hasta",
    CAST(YEAR([%0]) AS NVARCHAR(10))           AS "Periodo_Fiscal",
    T7."DprArea"                               AS "Area_Depreciacion",
    T7."DprType"                               AS "Metodo_Depreciacion",
    T7."UsefulLife"                            AS "Vida_Util_Meses",
    T7."RemainLife"                            AS "Resto_Vida_Util_Meses",
    T7."RemainDays"                            AS "Dias_Restantes",
    T8."Quantity"                              AS "Cantidad",
    T8."APC"                                   AS "Costo",
    T8."APCHist"                               AS "Costo_Historico",
    T8."SalvageVal"                            AS "Valor_Residual",
    T8."OrDpAcc"                               AS "Depreciacion_Acumulada",
    T8."UnDpAcc"                               AS "Depreciacion_No_Planeada",
    T8."WriteUpAcc"                            AS "Revaluacion_Positiva",
    T8."AppreAcc"                              AS "Apreciacion",
    COALESCE(T8."APC", 0)
      - COALESCE(T8."OrDpAcc", 0)
      + COALESCE(T8."WriteUpAcc", 0)
      - COALESCE(T8."AppreAcc", 0)             AS "Valor_Neto_Contable",
    CASE
        WHEN COALESCE(T7."UsefulLife", 0) > 0
         AND COALESCE(T7."DprType", '') <> 'NODEPRECIABLE'
        THEN (COALESCE(T8."APC", 0) - COALESCE(T8."SalvageVal", 0)) / T7."UsefulLife"
        ELSE 0
    END                                        AS "Amortizacion_Mensual_Calc",
    CASE
        WHEN COALESCE(T7."UsefulLife", 0) > 0
         AND COALESCE(T7."DprType", '') <> 'NODEPRECIABLE'
        THEN ((COALESCE(T8."APC", 0) - COALESCE(T8."SalvageVal", 0)) / T7."UsefulLife") * 12
        ELSE 0
    END                                        AS "Depreciacion_Anual_Calc",
    COALESCE(M."Dep_Posteada_Anio", 0)         AS "Depreciacion_Posteada_Anio",
    COALESCE(M."Enero", 0)                     AS "Enero",
    COALESCE(M."Febrero", 0)                   AS "Febrero",
    COALESCE(M."Marzo", 0)                     AS "Marzo",
    COALESCE(M."Abril", 0)                     AS "Abril",
    COALESCE(M."Mayo", 0)                      AS "Mayo",
    COALESCE(M."Junio", 0)                     AS "Junio",
    COALESCE(M."Julio", 0)                     AS "Julio",
    COALESCE(M."Agosto", 0)                    AS "Agosto",
    COALESCE(M."Septiembre", 0)                AS "Septiembre",
    COALESCE(M."Octubre", 0)                   AS "Octubre",
    COALESCE(M."Noviembre", 0)                 AS "Noviembre",
    COALESCE(M."Diciembre", 0)                 AS "Diciembre",
    [%0]                                       AS "Fecha_Corte_Reporte"
FROM OITM T0
INNER JOIN OITB G
    ON G."ItmsGrpCod" = T0."ItmsGrpCod"
LEFT JOIN ITM7 T7
    ON T7."ItemCode" = T0."ItemCode"
   AND T7."DprArea" = 'FINANCIERO'
   AND T7."PeriodCat" = CAST(YEAR([%0]) AS NVARCHAR(10))
LEFT JOIN ITM8 T8
    ON T8."ItemCode" = T7."ItemCode"
   AND T8."PeriodCat" = T7."PeriodCat"
   AND T8."DprArea" = T7."DprArea"
LEFT JOIN ITM6 D
    ON D."ItemCode" = T0."ItemCode"
   AND D."LineNum" = (
        SELECT MAX(D2."LineNum")
        FROM ITM6 D2
        WHERE D2."ItemCode" = T0."ItemCode"
          AND D2."ValidFrom" <= [%0]
          AND (D2."ValidTo" IS NULL OR D2."ValidTo" >= [%0])
   )
LEFT JOIN OOCR OC1
    ON OC1."OcrCode" = D."OcrCode"
   AND OC1."DimCode" = 1
LEFT JOIN OOCR OC2
    ON OC2."OcrCode" = D."OcrCode2"
   AND OC2."DimCode" = 2
LEFT JOIN OOCR OC3
    ON OC3."OcrCode" = D."OcrCode3"
   AND OC3."DimCode" = 3
LEFT JOIN OACS S
    ON S."Code" = T0."AssetClass"
LEFT JOIN (
    SELECT
        X0."Code"           AS "Subclase_Code",
        MAX(X1."AcctDtn")   AS "Clase_AF"
    FROM ACS1 X0
    LEFT JOIN AAC1 X1
        ON X1."Code" = X0."Code"
       AND X1."DprAreaID" = X0."DprAreaID"
    WHERE X0."DprAreaID" = 'FINANCIERO'
    GROUP BY X0."Code"
) CP
    ON CP."Subclase_Code" = T0."AssetClass"
LEFT JOIN AADT AD
    ON AD."Code" = CP."Clase_AF"
   AND AD."LogInstanc" = 1
LEFT JOIN ODSC B
    ON B."BankCode" = T0."U_Garantia_Banco"
LEFT JOIN (
    SELECT
        X1."ItemCode",
        MIN(X0."DocDate")  AS "F_Doc_Capitalizacion",
        MIN(X0."PostDate") AS "F_Contable_Capitalizacion",
        MAX(X0."DocNum")   AS "No_Doc_Capitalizacion",
        SUM(X1."APC")      AS "Costo_Documentos_Cap"
    FROM OACQ X0
    INNER JOIN ACQ1 X1
        ON X1."DocEntry" = X0."DocEntry"
    WHERE X0."DocStatus" IN ('C', 'P')
    GROUP BY X1."ItemCode"
) C
    ON C."ItemCode" = T0."ItemCode"
LEFT JOIN (
    SELECT
        X0."ItemCode",
        SUM(CASE WHEN X0."SubPeriod" =  1 THEN X0."OrdDprAct" ELSE 0 END) AS "Enero",
        SUM(CASE WHEN X0."SubPeriod" =  2 THEN X0."OrdDprAct" ELSE 0 END) AS "Febrero",
        SUM(CASE WHEN X0."SubPeriod" =  3 THEN X0."OrdDprAct" ELSE 0 END) AS "Marzo",
        SUM(CASE WHEN X0."SubPeriod" =  4 THEN X0."OrdDprAct" ELSE 0 END) AS "Abril",
        SUM(CASE WHEN X0."SubPeriod" =  5 THEN X0."OrdDprAct" ELSE 0 END) AS "Mayo",
        SUM(CASE WHEN X0."SubPeriod" =  6 THEN X0."OrdDprAct" ELSE 0 END) AS "Junio",
        SUM(CASE WHEN X0."SubPeriod" =  7 THEN X0."OrdDprAct" ELSE 0 END) AS "Julio",
        SUM(CASE WHEN X0."SubPeriod" =  8 THEN X0."OrdDprAct" ELSE 0 END) AS "Agosto",
        SUM(CASE WHEN X0."SubPeriod" =  9 THEN X0."OrdDprAct" ELSE 0 END) AS "Septiembre",
        SUM(CASE WHEN X0."SubPeriod" = 10 THEN X0."OrdDprAct" ELSE 0 END) AS "Octubre",
        SUM(CASE WHEN X0."SubPeriod" = 11 THEN X0."OrdDprAct" ELSE 0 END) AS "Noviembre",
        SUM(CASE WHEN X0."SubPeriod" = 12 THEN X0."OrdDprAct" ELSE 0 END) AS "Diciembre",
        SUM(X0."OrdDprAct") AS "Dep_Posteada_Anio"
    FROM ODPV X0
    WHERE X0."DprArea" = 'FINANCIERO'
      AND X0."PeriodCat" = CAST(YEAR([%0]) AS NVARCHAR(10))
    GROUP BY X0."ItemCode"
) M
    ON M."ItemCode" = T0."ItemCode"
WHERE T0."ItemType" = 'F'
  AND T0."ItmsGrpCod" IN (106, 107)
  AND T0."CapDate" <= [%0]
ORDER BY
    T0."CapDate" DESC,
    T0."ItemCode"
