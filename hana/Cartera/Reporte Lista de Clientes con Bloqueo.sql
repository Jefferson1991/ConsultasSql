SELECT
    T1."CardCode",
    T1."CardName",
    T1."AvrageLate"                          AS excedente_dias,
    COUNT(T0."DocEntry")                     AS facturas_abiertas,
    SUM(CASE WHEN CURRENT_DATE > ADD_DAYS(T0."DocDueDate", T1."AvrageLate")
              AND (T0."DocTotal" - T0."PaidToDate") > 0
             THEN 1 ELSE 0 END)              AS facturas_vencidas,
    SUM(CASE WHEN CURRENT_DATE > ADD_DAYS(T0."DocDueDate", T1."AvrageLate")
              AND (T0."DocTotal" - T0."PaidToDate") > 0
             THEN T0."DocTotal" - T0."PaidToDate" ELSE 0 END) AS saldo_vencido
FROM OCRD T1
INNER JOIN OINV T0
        ON T0."CardCode" = T1."CardCode"
       AND T0."DocStatus" = 'O'
       AND (T0."DocTotal" - T0."PaidToDate") > 0
WHERE T1."U_EMPA_BLOQ_CARTER" = 'Y'
GROUP BY T1."CardCode", T1."CardName", T1."AvrageLate"
HAVING SUM(CASE WHEN CURRENT_DATE > ADD_DAYS(T0."DocDueDate", T1."AvrageLate")
                 AND (T0."DocTotal" - T0."PaidToDate") > 0
                THEN 1 ELSE 0 END) > 0
ORDER BY saldo_vencido DESC;