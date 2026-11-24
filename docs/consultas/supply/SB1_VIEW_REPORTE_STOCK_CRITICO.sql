-- =============================================================================
-- CREAR VISTA EN HANA: SB1_VIEW_REPORTE_STOCK_CRITICO
-- Esquema: EMPAQPLAST_PROD
-- =============================================================================
-- Ejecutar en HANA (DBeaver) para crear la vista que luego SQL Server
-- consume via OPENQUERY en la vista STOCK_CRITICO_CLIENTES.
--
-- Si la vista ya existe usar ALTER VIEW en lugar de CREATE VIEW.
-- =============================================================================

CREATE VIEW EMPAQPLAST_PROD.SB1_VIEW_REPORTE_STOCK_CRITICO AS
WITH StockBase AS (
    SELECT
        T0."ItemCode" AS "Codigo",
        T1."U_Codigo_Secundario" AS "Codigo_Secundario",
        T1."ItemName" AS "Item",
        T1."LeadTime",
        T1."MinLevel",
        CASE
            WHEN T0."ItemCode" IN ('PTEPET0136','PTEPET0192','PTEPET0195','PTEPET0196','PTEPET0197','PTEPET0198','PTEPET0202') THEN 'Imperial'
            WHEN T0."ItemCode" IN ('PTEPET0165','PTEPET0282','PTEPET0307') THEN 'San Felipe'
            WHEN T0."ItemCode" IN ('PTEPET0132','PTEPET0326','PTTAPA0048','PTTAPA0050','PTEPET0325') THEN 'Volcanic'
            WHEN T0."ItemCode" IN ('PTEPET0074','PTEPET0079','PTTAPA0118','PTTAPA0119') THEN 'Unilever'
            WHEN T0."ItemCode" IN ('PTEPET0312') THEN 'Licorec'
            WHEN T0."ItemCode" IN ('PTEPET0163') THEN 'Ecopacific'
            WHEN T0."ItemCode" IN ('PTEPET0130','PTEPET0114','PTEPET0097','PTEPET0281','PTEPET0318','PTEPET0278') THEN 'Generico'
            WHEN T0."ItemCode" IN ('PTTAPA0160','PTMANI0020','PTMANI0026','PTMANI0027','PTTAPA0199') THEN 'Tesalia'
            WHEN T0."ItemCode" IN ('PTTAPA0169') THEN 'Splendor'
            ELSE 'Otro'
        END AS "Cliente",
        CASE
            WHEN T0."ItemCode" IN ('PTEPET0136','PTEPET0192','PTEPET0195','PTEPET0196','PTEPET0197','PTEPET0198','PTEPET0202') THEN 15
            WHEN T0."ItemCode" IN ('PTEPET0165','PTEPET0282','PTEPET0307') THEN 15
            WHEN T0."ItemCode" IN ('PTEPET0074','PTEPET0079','PTTAPA0118','PTTAPA0119') THEN 15
            WHEN T0."ItemCode" IN ('PTEPET0312') THEN 12
            WHEN T0."ItemCode" IN ('PTEPET0163') THEN 40
            ELSE 20
        END AS "PR_Dias",
        SUM(CASE WHEN T0."WhsCode" = 'UIO_MP' THEN T0."OnHand" ELSE 0 END) AS "UIO_MP",
        SUM(CASE WHEN T0."WhsCode" = 'UIO_PT' THEN T0."OnHand" ELSE 0 END) AS "UIO_PT",
        SUM(CASE WHEN T0."WhsCode" = 'UIO_PROD' THEN T0."OnHand" ELSE 0 END) AS "UIO_PROD",
        SUM(CASE WHEN T0."WhsCode" = 'GYE_PT' THEN T0."OnHand" ELSE 0 END) AS "GYE_PT",
        SUM(CASE WHEN T0."WhsCode" = 'GYE_MP' THEN T0."OnHand" ELSE 0 END) AS "GYE_MP",
        SUM(CASE WHEN T0."WhsCode" = 'UIO_CONS' THEN T0."OnHand" ELSE 0 END) AS "UIO_CONS",
        SUM(CASE WHEN T0."WhsCode" = 'UIO_ MAT' THEN T0."OnHand" ELSE 0 END) AS "UIO_MAT",
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
        "Codigo",
        "Codigo_Secundario",
        "Item",
        "Cliente",
        "PR_Dias",
        "LeadTime",
        "MinLevel",
        "UIO_MP",
        "UIO_PT",
        "UIO_PROD",
        "GYE_PT",
        "GYE_MP",
        "UIO_CONS",
        "UIO_MAT",
        "Consumo_90_dias",
        ("UIO_PROD" + "UIO_PT") AS "UIO_Total",
        ("GYE_PT" + "GYE_MP") AS "GYE_Total",
        ("UIO_PT" + "GYE_PT") AS "STOCK",
        ROUND(IFNULL(("Consumo_90_dias" / 3.0) / 30.0, 0), 2) AS "ConsumoPromedioDiario",
        ROUND((IFNULL(("Consumo_90_dias" / 3.0) / 30.0, 0) * IFNULL("LeadTime", 0)) + IFNULL("MinLevel", 0), 2) AS "PR_Cantidad"
    FROM StockBase
)
SELECT
    "Codigo",
    "Codigo_Secundario",
    "Item",
    "Cliente",
    "PR_Dias",
    "LeadTime",
    "MinLevel",
    "UIO_MP",
    "UIO_PT",
    "UIO_PROD",
    "GYE_PT",
    "GYE_MP",
    "UIO_CONS",
    "UIO_MAT",
    "Consumo_90_dias",
    "UIO_Total",
    "GYE_Total",
    "STOCK",
    "ConsumoPromedioDiario",
    "PR_Cantidad",
    CASE
        WHEN "ConsumoPromedioDiario" > 0 THEN ROUND("STOCK" / "ConsumoPromedioDiario", 2)
        ELSE 0
    END AS "DOH",
    CASE
        WHEN (CASE WHEN "ConsumoPromedioDiario" > 0 THEN "STOCK" / "ConsumoPromedioDiario" ELSE 0 END) >= "PR_Dias" THEN 1
        ELSE 0
    END AS "Cumplimiento_KR",
    CASE
        WHEN (CASE WHEN "ConsumoPromedioDiario" > 0 THEN "STOCK" / "ConsumoPromedioDiario" ELSE 0 END) >= "PR_Dias" + 5 THEN 'Verde'
        WHEN (CASE WHEN "ConsumoPromedioDiario" > 0 THEN "STOCK" / "ConsumoPromedioDiario" ELSE 0 END) >= "PR_Dias" THEN 'Amarillo'
        ELSE 'Rojo'
    END AS "Semaforo"
FROM CalculosFinales;
