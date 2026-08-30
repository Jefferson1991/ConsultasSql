-- =============================================================================
-- REPORTE STOCK CRITICO – SAP HANA (EMPAQPLAST_PROD)
-- =============================================================================
--
-- ¿QUE HACE ESTE REPORTE?
-- ------------------------
-- Evalua si tenemos suficiente inventario de producto terminado (envases PET,
-- tapas, mangos) para cubrir la demanda de cada cliente sin riesgo de quiebre
-- de stock.
--
-- ¿COMO FUNCIONA?
-- ----------------
-- 1. STOCK: Toma el inventario actual de las bodegas de producto terminado
--    de Quito (UIO_PT) y Guayaquil (GYE_PT) directamente desde SAP.
--
-- 2. CONSUMO PROMEDIO DIARIO (CPD): Calcula cuantas unidades se entregan
--    por dia a los clientes. Para eso toma las entregas reales (notas de
--    entrega ODLN) de los ultimos 90 dias, divide entre 3 meses y luego
--    entre 30 dias → unidades/dia.
--
-- 3. DOH (Days On Hand / Dias de Inventario): Responde la pregunta
--    "¿para cuantos dias alcanza el stock actual?"
--    Formula: DOH = Stock / CPD
--    Ejemplo: 65,660 unidades / 2,542 unidades-dia = 25.8 dias
--
-- 4. PUNTO DE REORDEN (PR): Cada cliente tiene un objetivo minimo de dias
--    de inventario definido por Supply:
--
--       Cliente        | PR (dias)
--       ---------------|----------
--       Imperial       | 15
--       San Felipe     | 15
--       Unilever       | 15
--       Licorec        | 12
--       Ecopacific     | 40
--       Volcanic       | 20
--       Generico       | 20
--       Tesalia        | 20
--       Splendor       | 20
--
-- 5. CUMPLIMIENTO KR: ¿El item cumple? Si DOH >= PR del cliente → SI (1).
--    La meta es que el 70% de los items cumplan su PR.
--
-- 6. SEMAFORO:
--       Verde    → DOH >= PR + 5 dias  (holgura, bien abastecido)
--       Amarillo → DOH entre PR y PR+5  (justo, monitorear)
--       Rojo     → DOH < PR             (critico, riesgo de quiebre)
--
-- ¿DE DONDE SALEN LOS DATOS?
-- ----------------------------
--   OITW       → Stock actual por bodega (SAP, tiempo real)
--   OITM       → Maestro de articulos (nombre, lead time, stock minimo)
--   ODLN/DLN1  → Notas de entrega a clientes (consumo real, ultimos 90 dias)
--
-- COLUMNAS DE SALIDA PRINCIPALES:
--   Codigo / Item / Cliente       → Identificacion del producto
--   STOCK                         → Inventario PT disponible (UIO + GYE)
--   ConsumoPromedioDiario (CPD)   → Demanda diaria promedio
--   DOH                           → Dias de cobertura del stock actual
--   PR_Dias                       → Objetivo minimo en dias para ese cliente
--   Cumplimiento_KR               → 1 = cumple, 0 = no cumple
--   Semaforo                      → Verde / Amarillo / Rojo
--
-- =============================================================================
CREATE VIEW SB1_VIEW_REPORTE_STOCK_CRITICO AS 
WITH StockBase AS (
    SELECT
        T0."ItemCode" AS "Codigo",
        T1."U_Codigo_Secundario" AS "Codigo_Secundario",
        T1."ItemName" AS "Item",
        T1."LeadTime",
        T1."MinLevel",

        -- Cliente y Punto de Reorden (dias) por item
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
            ELSE 20  -- Volcanic, Generico, Tesalia, Splendor, Otro
        END AS "PR_Dias",

        -- Stock por bodega (pivot)
        SUM(CASE WHEN T0."WhsCode" = 'UIO_MP' THEN T0."OnHand" ELSE 0 END) AS "UIO_MP",
        SUM(CASE WHEN T0."WhsCode" = 'UIO_PT' THEN T0."OnHand" ELSE 0 END) AS "UIO_PT",
        SUM(CASE WHEN T0."WhsCode" = 'UIO_PROD' THEN T0."OnHand" ELSE 0 END) AS "UIO_PROD",
        SUM(CASE WHEN T0."WhsCode" = 'GYE_PT' THEN T0."OnHand" ELSE 0 END) AS "GYE_PT",
        SUM(CASE WHEN T0."WhsCode" = 'GYE_MP' THEN T0."OnHand" ELSE 0 END) AS "GYE_MP",
        SUM(CASE WHEN T0."WhsCode" = 'UIO_CONS' THEN T0."OnHand" ELSE 0 END) AS "UIO_CONS",
        SUM(CASE WHEN T0."WhsCode" = 'UIO_ MAT' THEN T0."OnHand" ELSE 0 END) AS "UIO_MAT",

        -- Consumo basado en Entregas (ODLN) ultimos 90 dias
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
        ("UIO_PROD" + "UIO_PT") AS "UIO Total",
        ("GYE_PT" + "GYE_MP") AS "GYE Total",
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
    "UIO Total",
    "GYE Total",
    "STOCK",
    "ConsumoPromedioDiario",
    "PR_Cantidad",
    -- DOH (Dias de Inventario)
    CASE
        WHEN "ConsumoPromedioDiario" > 0 THEN ROUND("STOCK" / "ConsumoPromedioDiario", 2)
        ELSE 0
    END AS "DOH",
    -- Cumplimiento KR: DOH >= PR individual del cliente (no fijo 20)
    CASE
        WHEN (CASE WHEN "ConsumoPromedioDiario" > 0 THEN "STOCK" / "ConsumoPromedioDiario" ELSE 0 END) >= "PR_Dias" THEN 1
        ELSE 0
    END AS "Cumplimiento_KR",
    -- Semaforo: Verde (>= PR+5), Amarillo (entre PR y PR+5), Rojo (< PR)
    CASE
        WHEN (CASE WHEN "ConsumoPromedioDiario" > 0 THEN "STOCK" / "ConsumoPromedioDiario" ELSE 0 END) >= "PR_Dias" + 5 THEN 'Verde'
        WHEN (CASE WHEN "ConsumoPromedioDiario" > 0 THEN "STOCK" / "ConsumoPromedioDiario" ELSE 0 END) >= "PR_Dias" THEN 'Amarillo'
        ELSE 'Rojo'
    END AS "Semaforo"
FROM CalculosFinales
ORDER BY "Cliente" ASC, "Codigo" ASC;
