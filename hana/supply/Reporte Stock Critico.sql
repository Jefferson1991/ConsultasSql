WITH StockBase AS (
    SELECT 
        T0."ItemCode" AS "Codigo",
        T1."U_Codigo_Secundario" AS "Codigo_Secundario",
        T1."ItemName" AS "Item",
        T1."LeadTime",
        T1."MinLevel",
        SUM(CASE WHEN T0."WhsCode" = 'UIO_MP' THEN T0."OnHand" ELSE 0 END) AS "UIO_MP",
        SUM(CASE WHEN T0."WhsCode" = 'UIO_PT' THEN T0."OnHand" ELSE 0 END) AS "UIO_PT",
        SUM(CASE WHEN T0."WhsCode" = 'UIO_PROD' THEN T0."OnHand" ELSE 0 END) AS "UIO_PROD",
        SUM(CASE WHEN T0."WhsCode" = 'GYE_PT' THEN T0."OnHand" ELSE 0 END) AS "GYE_PT",
        SUM(CASE WHEN T0."WhsCode" = 'GYE_MP' THEN T0."OnHand" ELSE 0 END) AS "GYE_MP",
        SUM(CASE WHEN T0."WhsCode" = 'UIO_CONS' THEN T0."OnHand" ELSE 0 END) AS "UIO_CONS",
        SUM(CASE WHEN T0."WhsCode" = 'UIO_ MAT' THEN T0."OnHand" ELSE 0 END) AS "UIO_MAT",
        
        -- Consumo basado únicamente en Entregas (ODLN) últimos 90 días
        (SELECT SUM(A."Quantity") 
         FROM DLN1 A 
         INNER JOIN ODLN B ON A."DocEntry" = B."DocEntry"
         WHERE A."ItemCode" = T0."ItemCode" 
           AND B."CANCELED" = 'N'
           AND B."DocDate" >= ADD_DAYS(CURRENT_DATE, -90)
        ) AS "Consumo_90_dias"
        
    FROM OITW T0
    INNER JOIN OITM T1 ON T1."ItemCode" = T0."ItemCode"
     WHERE T1."ItemCode" IN (
        'PTEPET0136', 'PTEPET0192', 'PTEPET0195', 'PTEPET0196', 'PTEPET0197', 
        'PTEPET0198', 'PTEPET0202', 'PTEPET0165', 'PTEPET0282', 'PTEPET0307', 
        'PTEPET0132', 'PTEPET0326', 'PTTAPA0048', 'PTTAPA0050', 'PTEPET0325', 
        'PTEPET0074', 'PTEPET0079', 'PTTAPA0118', 'PTTAPA0119', 'PTEPET0312', 
        'PTEPET0163', 'PTEPET0130', 'PTEPET0114', 'PTEPET0097', 'PTEPET0281', 
        'PTEPET0318', 'PTEPET0278', 'PTTAPA0160', 'PTMANI0020', 'PTMANI0026', 
        'PTMANI0027', 'PTTAPA0199', 'PTTAPA0169', 'PTTAPA0122', 'PTTAPA0121', 
        'PTTAPA0085', 'PTTAPA0087', 'PTEPAD0058'
    )
    AND T0."WhsCode" IN ('UIO_PT','UIO_MP','UIO_PROD','GYE_PT','GYE_MP','UIO_CONS','UIO_ MAT')
    GROUP BY T0."ItemCode", T1."ItemName", T1."U_Codigo_Secundario", T1."LeadTime", T1."MinLevel"
),
CalculosFinales AS (
    SELECT 
        *,
        ("UIO_PROD" + "UIO_PT") AS "UIO Total",
        ("GYE_PT" + "GYE_MP") AS "GYE Total",
        ("UIO_PT" + "GYE_PT") AS "STOCK",
        ROUND(IFNULL(("Consumo_90_dias" / 3.0) / 30.0, 0), 2) AS "ConsumoPromedioDiario",
        -- Punto de Reorden (Cantidad)
        ROUND((IFNULL(("Consumo_90_dias" / 3.0) / 30.0, 0) * IFNULL("LeadTime", 0)) + IFNULL("MinLevel", 0), 2) AS "PR_Cantidad"
    FROM StockBase
)

SELECT 
    *,
    -- DOH (Días de Inventario)
    CASE 
        WHEN "ConsumoPromedioDiario" > 0 THEN ROUND("STOCK" / "ConsumoPromedioDiario", 2) 
        ELSE 0 
    END AS "DOH",
    -- Lógica de Cumplimiento KR: SI DOH >= Punto de Reorden (en este caso el PR definido en tu excel como días objetivo)
    -- Nota: Si tu "Punto de Reorden" en el Excel son DÍAS (como el target de 20 días), usamos esta lógica:
    CASE 
        WHEN (CASE WHEN "ConsumoPromedioDiario" > 0 THEN "STOCK" / "ConsumoPromedioDiario" ELSE 0 END) >= 20 THEN 1 
        ELSE 0 
    END AS "Cumplimiento_KR"
FROM CalculosFinales
ORDER BY "Codigo" ASC;