/* =========================================================================
   Solicitud de Traslado (Consumo) vs Salida de Mercancía generada
   Incluye: promedio ponderado (OINM.CalcPrice) por ItemCode+Bodega a la
   fecha del documento, comparativo de centros de costo (Traslado vs Salida)
   y el detalle del Asiento Contable (OJDT/JDT1) generado por la Salida.

   Bodega de referencia para el promedio ponderado: DINÁMICA, se toma del
   propio movimiento (T1."WhsCode" en el traslado / T4."WhsCode" en la
   salida) en vez de fijarla a 'UIO_ MAT'. Esto es necesario porque
   Guayaquil usa su propia bodega 'GYE_ MAT' (equivalente a 'UIO_ MAT' en
   Quito, ambos códigos reales traen un espacio) -- con la bodega fija se
   detectó que los documentos SLTGYE traían el costo histórico de Quito
   (irrelevante) en vez del de Guayaquil, y no cuadraban contra el asiento.

   Validado contra hana-sap-b1-produccion (esquema EMPAQPLAST_PROD).
   Nota HANA: no se puede usar TOP/ORDER BY dentro de una subconsulta
   correlacionada (error 309), por eso el promedio ponderado se resuelve
   con MAX("TransSeq") -- TransSeq crece de forma monótona con cada
   transacción de inventario, así que el máximo TransSeq entre las filas
   con DocDate <= fecha objetivo es la transacción vigente en esa fecha.

   Nota Asiento Contable: el vínculo Salida -> Asiento se hace por
   JDT1."BaseRef" = OIGE."DocNum" + JDT1."TransType" = OIGE."ObjType" ('60').
   JDT1."BaseRef" por sí solo NO es único entre tipos de documento (se
   repiten valores con facturas, entregas, cobros, etc.), por eso el
   filtro por ObjType es obligatorio. El asiento trae 2 líneas por Salida
   (Crédito en Inventario / Débito en CIF); se filtró TJL."Credit" > 0
   para traer solo la línea de Crédito (Inventario) y así no duplicar
   el renglón de traslado/salida.
   ========================================================================= */

SELECT
    -- ---------- Encabezado Solicitud de Traslado ----------
    T2."SeriesName"                                    AS "Serie_Traslado",
    T0."DocNum"                                        AS "Numero_Solicitud",
    T0."DocDate"                                       AS "Fecha_Contabilizacion_Traslado",
    T0."DocDueDate"                                    AS "Fecha_Vencimiento",
    T0."TaxDate"                                       AS "Fecha_Documento_Traslado",
    CASE
        WHEN T0."U_EMPA_TIPO" = 1 THEN 'Solicitud Normal'
        WHEN T0."U_EMPA_TIPO" = 2 THEN 'Solicitud ExtraOrdinaria'
        ELSE 'Ninguno'
    END                                                 AS "Tipo_Formato",
    T0."U_EMPA_REQ_MAT"                                AS "Movimiento_Fracttal",
    CASE
        WHEN T0."U_EMPA_T_C" = 1 THEN 'Traslado'
        WHEN T0."U_EMPA_T_C" = 2 THEN 'Consumo'
        ELSE 'Ninguno'
    END                                                 AS "Tipo_Solicitud",
    CASE
        WHEN T0."U_EMPA_MOT" = 1 THEN 'Devolución'
        WHEN T0."U_EMPA_MOT" = 2 THEN 'Entrega'
        ELSE 'Ninguno'
    END                                                 AS "Motivo_Traslado",
    T0."U_EMPA_N_SE"                                   AS "Numero_Servicio",
    T0."U_EMPA_EMPL"                                   AS "Solicitado_por",
    T0."U_EMPA_HORA"                                   AS "Hora",

    -- ---------- Línea del artículo (Traslado) ----------
    T1."ItemCode"                                      AS "ItemCode",
    T1."Dscription"                                    AS "Dscription",
    T1."WhsCode"                                       AS "Almacen_Origen",
    T1."FromWhsCod"                                    AS "Almacen_Destino",
    T1."Quantity"                                      AS "Cantidad_Traslado",

    -- Promedio ponderado del artículo en su bodega de origen (T1.WhsCode), vigente a la fecha del documento del traslado
    ( SELECT O1."CalcPrice"
        FROM OINM O1
       WHERE O1."ItemCode"  = T1."ItemCode"
         AND O1."Warehouse" = T1."WhsCode"
         AND O1."DocDate"  <= T0."TaxDate"
         AND O1."TransSeq"  = ( SELECT MAX(O1b."TransSeq")
                                   FROM OINM O1b
                                  WHERE O1b."ItemCode"  = T1."ItemCode"
                                    AND O1b."Warehouse" = T1."WhsCode"
                                    AND O1b."DocDate"  <= T0."TaxDate" )
    )                                                   AS "Promedio_Ponderado_Traslado",

    T1."OcrCode2"                                      AS "Area_Traslado",
    PA1."PrcName"                                       AS "Area_Traslado_Desc",
    T1."OcrCode3"                                      AS "Departamento_Traslado",
    PD1."PrcName"                                       AS "Departamento_Traslado_Desc",
    T1."OcrCode4"                                      AS "Maquina_Traslado",
    PM1."PrcName"                                       AS "Maquina_Traslado_Desc",
    T0."Comments"                                       AS "Comentarios_Traslado",

    -- ---------- Salida de Mercancía asociada (si ya se generó) ----------
    T5."SeriesName"                                    AS "Serie_Salida",
    T3."DocNum"                                        AS "Numero_Salida",
    CASE
        WHEN T3."U_EMPA_T_S" = 1 THEN 'Pedido de producción'
        WHEN T3."U_EMPA_T_S" = 2 THEN 'Ajuste'
        ELSE 'Ninguno'
    END                                                 AS "Tipo_Salida",
    T3."DocDate"                                       AS "Fecha_Contabilizacion_Salida",
    T3."TaxDate"                                       AS "Fecha_Documento_Salida",
    T4."Quantity"                                      AS "Cantidad_Salida",

    -- Promedio ponderado del artículo en la bodega de la Salida (T4.WhsCode), vigente a la fecha del documento de la salida
    ( SELECT O2."CalcPrice"
        FROM OINM O2
       WHERE O2."ItemCode"  = T4."ItemCode"
         AND O2."Warehouse" = T4."WhsCode"
         AND O2."DocDate"  <= T3."TaxDate"
         AND O2."TransSeq"  = ( SELECT MAX(O2b."TransSeq")
                                   FROM OINM O2b
                                  WHERE O2b."ItemCode"  = T4."ItemCode"
                                    AND O2b."Warehouse" = T4."WhsCode"
                                    AND O2b."DocDate"  <= T3."TaxDate" )
    )                                                   AS "Promedio_Ponderado_Salida",

    -- Valor de la Salida = Cantidad_Salida * Promedio_Ponderado_Salida
    -- (si Items_En_Salida = 1, debe coincidir con "Credito" del asiento;
    -- si Items_En_Salida > 1, la suma de este valor entre los ítems del
    -- mismo Numero_Salida debe coincidir con "Credito", ya que ese Crédito
    -- es el total agrupado del documento)
    ROUND(
        T4."Quantity" *
        ( SELECT O2."CalcPrice"
            FROM OINM O2
           WHERE O2."ItemCode"  = T4."ItemCode"
             AND O2."Warehouse" = T4."WhsCode"
             AND O2."DocDate"  <= T3."TaxDate"
             AND O2."TransSeq"  = ( SELECT MAX(O2b."TransSeq")
                                       FROM OINM O2b
                                      WHERE O2b."ItemCode"  = T4."ItemCode"
                                        AND O2b."Warehouse" = T4."WhsCode"
                                        AND O2b."DocDate"  <= T3."TaxDate" )
        )
    , 6)                                                AS "Valor_Salida",

    T4."WhsCode"                                       AS "Almacen_Salida",
    T4."OcrCode2"                                      AS "Area_Salida",
    PA2."PrcName"                                       AS "Area_Salida_Desc",
    T4."OcrCode3"                                      AS "Departamento_Salida",
    PD2."PrcName"                                       AS "Departamento_Salida_Desc",
    T4."OcrCode4"                                      AS "Maquina_Salida",
    PM2."PrcName"                                       AS "Maquina_Salida_Desc",
    T3."U_SYP_PROCESADO_FT"                            AS "Procesado_Fracttal",

    -- ---------- Comparativo de Centros de Costo (Traslado vs Salida) ----------
    CASE
        WHEN T4."DocEntry" IS NULL THEN 'SIN SALIDA GENERADA'
        WHEN COALESCE(T1."OcrCode2",'') = COALESCE(T4."OcrCode2",'')
         AND COALESCE(T1."OcrCode3",'') = COALESCE(T4."OcrCode3",'')
         AND COALESCE(T1."OcrCode4",'') = COALESCE(T4."OcrCode4",'')
        THEN 'COINCIDE'
        ELSE 'DIFIERE'
    END                                                 AS "Comparativo_Centro_Costo",

    -- Diferencia entre el promedio ponderado al momento del traslado y al momento de la salida
    ROUND(
        ( SELECT O2."CalcPrice"
            FROM OINM O2
           WHERE O2."ItemCode"  = T4."ItemCode"
             AND O2."Warehouse" = T4."WhsCode"
             AND O2."DocDate"  <= T3."TaxDate"
             AND O2."TransSeq"  = ( SELECT MAX(O2b."TransSeq")
                                       FROM OINM O2b
                                      WHERE O2b."ItemCode"  = T4."ItemCode"
                                        AND O2b."Warehouse" = T4."WhsCode"
                                        AND O2b."DocDate"  <= T3."TaxDate" )
        )
        -
        ( SELECT O1."CalcPrice"
            FROM OINM O1
           WHERE O1."ItemCode"  = T1."ItemCode"
             AND O1."Warehouse" = T1."WhsCode"
             AND O1."DocDate"  <= T0."TaxDate"
             AND O1."TransSeq"  = ( SELECT MAX(O1b."TransSeq")
                                       FROM OINM O1b
                                      WHERE O1b."ItemCode"  = T1."ItemCode"
                                        AND O1b."Warehouse" = T1."WhsCode"
                                        AND O1b."DocDate"  <= T0."TaxDate" )
        )
    , 6)                                                AS "Diferencia_Promedio_Ponderado",

    -- ---------- Asiento Contable generado por la Salida de Mercancía ----------
    N6."SeriesName"                                    AS "Serie_Asiento",
    TJE."Number"                                        AS "Numero_Asiento",
    TJE."TransId"                                       AS "TransId_Asiento",
    TJE."RefDate"                                       AS "Fecha_Contabilizacion_Asiento",
    TJE."DueDate"                                       AS "Fecha_Vencimiento_Asiento",
    TJE."TaxDate"                                       AS "Fecha_Documento_Asiento",
    TJE."Memo"                                          AS "Comentarios_Asiento",
    TJL."BaseRef"                                       AS "Numero_Origen_Asiento",
    TJL."Account"                                       AS "Cuenta_Mayor",
    ACC."AcctName"                                       AS "Nombre_Cuenta",
    TJL."Debit"                                         AS "Debito",
    TJL."Credit"                                        AS "Credito",

    -- Cuántos ítems comparten esta misma Salida/asiento: si es 1, el Crédito de
    -- arriba es exclusivo de este ítem; si es > 1, es el TOTAL del documento
    -- completo (SAP agrupa el asiento por documento, no por ítem/línea)
    ( SELECT COUNT(*) FROM IGE1 X WHERE X."DocEntry" = T3."DocEntry" ) AS "Items_En_Salida"

FROM OWTQ T0
INNER JOIN WTQ1 T1 ON T1."DocEntry" = T0."DocEntry"
INNER JOIN NNM1 T2 ON T2."Series"   = T0."Series"

-- Salida de mercancía generada a partir de la solicitud (U_EMPA_S_T = DocNum del traslado)
LEFT JOIN OIGE T3 ON T3."U_EMPA_S_T" = TO_VARCHAR(T0."DocNum")
LEFT JOIN IGE1 T4 ON T4."DocEntry"  = T3."DocEntry" AND T4."ItemCode" = T1."ItemCode"
LEFT JOIN NNM1 T5 ON T5."Series"    = T3."Series"

-- Descripción de centros de costo (Traslado)
LEFT JOIN OPRC PA1 ON PA1."PrcCode" = T1."OcrCode2"
LEFT JOIN OPRC PD1 ON PD1."PrcCode" = T1."OcrCode3"
LEFT JOIN OPRC PM1 ON PM1."PrcCode" = T1."OcrCode4"

-- Descripción de centros de costo (Salida)
LEFT JOIN OPRC PA2 ON PA2."PrcCode" = T4."OcrCode2"
LEFT JOIN OPRC PD2 ON PD2."PrcCode" = T4."OcrCode3"
LEFT JOIN OPRC PM2 ON PM2."PrcCode" = T4."OcrCode4"

-- Asiento contable (OJDT/JDT1) generado al contabilizar la Salida de Mercancía
-- Solo la línea de Crédito (cuenta de Inventario) -- se descarta la de Débito (CIF)
-- IMPORTANTE: se condiciona a T4."DocEntry" IS NOT NULL -> el asiento solo se
-- trae si ESTE ítem específico ya tiene línea contabilizada en la Salida; si
-- el ítem del traslado no llegó a tener línea en IGE1 (aún no se emitió/
-- contabilizó para ese ítem), no se le pega el asiento de otro ítem.
LEFT JOIN JDT1 TJL ON TJL."BaseRef" = TO_VARCHAR(T3."DocNum") AND TJL."TransType" = T3."ObjType"
                   AND TJL."Credit" > 0 AND T4."DocEntry" IS NOT NULL
LEFT JOIN OJDT TJE ON TJE."TransId"  = TJL."TransId"
LEFT JOIN NNM1 N6   ON N6."Series"   = TJE."Series"
LEFT JOIN OACT ACC  ON ACC."AcctCode" = TJL."Account"

WHERE T0."U_EMPA_N_SE" <> ''
  AND T0."U_EMPA_T_C" = '2'
  AND T0."U_EMPA_REQ_MAT" <> ''

ORDER BY T0."DocDate" DESC, T0."DocNum" DESC;
