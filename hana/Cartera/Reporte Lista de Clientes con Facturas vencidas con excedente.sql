SELECT
    T1."CardCode",
    T1."CardName",
    DAYS_BETWEEN(T0."DocDate", T0."DocDueDate")  AS dias_credito,
    T1."AvrageLate"                              AS dias_excedente,
    DAYS_BETWEEN(T0."DocDate", T0."DocDueDate")
        + T1."AvrageLate"                        AS total_dias_con_excedente,
    T0."DocNum",
    T0."DocDate"                                 AS fecha_documento,
    T0."DocDueDate"                              AS vencimiento_credito,
    ADD_DAYS(T0."DocDueDate", T1."AvrageLate")   AS vencimiento_credito_mas_excedente,
    DAYS_BETWEEN(ADD_DAYS(T0."DocDueDate", T1."AvrageLate"), CURRENT_DATE) AS dias_vencido,
    T0."DocTotal" - T0."PaidToDate"              AS saldo_pendiente
FROM OCRD T1
INNER JOIN OINV T0
        ON T0."CardCode" = T1."CardCode"
       AND T0."DocStatus" = 'O'
WHERE T1."U_EMPA_BLOQ_CARTER" = 'Y'
  AND CURRENT_DATE > ADD_DAYS(T0."DocDueDate", T1."AvrageLate")
  AND (T0."DocTotal" - T0."PaidToDate") > 0
ORDER BY T0."DocDueDate" ASC, T1."CardCode";