WITH Tabla_Libro AS (
    -- Generamos un número de fila para el Libro Mayor
    SELECT 
        ROW_NUMBER() OVER(ORDER BY "OrdenL" ASC, "N_ReconciliacionL" ASC) AS "Num_Fila",
        ROW_NUMBER() OVER(PARTITION BY CASE WHEN "N_ReferenciaL" IS NULL OR "N_ReferenciaL" = '' THEN '@@VACIO@@' ELSE "N_ReferenciaL" END ORDER BY "OrdenL" ASC, "N_ReconciliacionL" ASC) AS "Fila_MatchL",
        *
    FROM (
        -- ========================================================
        -- 1. CONSULTA PARA EL SALDO INICIAL LIBRO
        -- ========================================================
        SELECT
            0 AS "OrdenL",
            2026 AS "AnioL",
            10 AS "MesL",
            'Saldo Inicial' AS "ConsultaL",
            T0."Account" AS "N_CuentaL",
            MAX(T0."OrgAccName") AS "Nombre_CuentaL",
            'Saldo Inicial' AS "DetalleL",
            CAST(NULL AS DATE) AS "F_ContabilizacionL",
            CAST(NULL AS DATE) AS "F_VencimientoL",
            NULL AS "Tipo_DocL",
            NULL AS "N_DocumentoL",
            NULL AS "N_TransaccionL",
            'Saldo Inicial' AS "ComentarioL",
            NULL AS "Cuenta_ContrapartidaL",
            NULL AS "N_ReconciliacionL",
            NULL AS "N_ReferenciaL",
            SUM(T0."Debit" - T0."Credit") AS "ValoresL",
            NULL AS "DebitoL",
            NULL AS "CreditoL",
            NULL AS "Valor_Pagos_Rec/EfeL",
            NULL AS "Es_ChequeL"
        FROM JDT1 T0
        WHERE T0."Account" = '11010205'
          AND T0."RefDate" < CAST(TO_VARCHAR(2026) || '-' || LPAD(TO_VARCHAR(10), 2, '0') || '-01' AS DATE)
        GROUP BY T0."Account"
 
        UNION ALL
 
        -- ========================================================
        -- 2. MOVIMIENTOS DEL MES ACTUAL LIBRO
        -- ========================================================
        SELECT
            1 AS "OrdenL",
            YEAR(T0."DueDate") AS "AnioL",
            MONTH(T0."DueDate") AS "MesL",
            'Libro' AS "ConsultaL",
            T0."Account" AS "N_CuentaL",
            T0."OrgAccName" AS "Nombre_CuentaL",
            CASE
	-- 1. Evaluamos Anulados primero
	WHEN T1."Canceled" = 'Y' OR T2."Canceled" = 'Y' OR T3."Canceled" = 'Y' THEN 'Anulado'
	 -- 2. Evaluamos los TransType 30 ESPECÍFICOS
	WHEN T0."TransType" = 30 AND (T0."ContraAct" IN ('73010201','73010101') OR T0."TransCode" IN ('COBN','CCHD')) THEN 'Comision'
	 WHEN T0."TransType" = 30 AND T0."TransCode" = 'TREC' AND (T0."Debit" <> 0) THEN 'Traslado de Credito'
	WHEN T0."TransType" = 30 AND T0."TransCode" = 'TREC' AND (T0."Credit" <> 0) THEN 'Traslado de Debito'
	 -- 3. Evaluamos los TransType 30 RESTANTES (y los tipos normales 24, 25, 46)
	WHEN T0."TransType" = 24 OR T0."TransType" = 25 OR (T0."TransType" = 30 AND T0."Debit" <> 0) THEN 'Deposito'
	WHEN T0."TransType" = 46 OR (T0."TransType" = 30 AND T0."Credit" <> 0) THEN 'Pago'
	-- Buena práctica: evitar nulos
	ELSE 'No Identificado'
            END AS "DetalleL",
            T0."RefDate" AS "F_ContabilizacionL",
            T0."DueDate" AS "F_VencimientoL",
            T0."TransType" AS "Tipo_DocL",
            T0."Ref1" AS "N_DocumentoL",
            T0."TransId" AS "N_TransaccionL",
            T0."LineMemo" AS "ComentarioL",
            T0."ContraAct" AS "Cuenta_ContrapartidaL",
            T0."ExtrMatch" AS "N_ReconciliacionL",
            T0."Ref3Line" AS "N_ReferenciaL",
            CASE
	-- 1. Anulados (Mantenemos tu lógica intacta para reversos)
	WHEN T0."Credit" <> 0 AND (T1."Canceled" = 'Y' OR T3."Canceled" = 'Y') THEN -T0."Credit"
	WHEN T0."Debit" <> 0 AND T2."Canceled" = 'Y' THEN T0."Debit"
	-- 2. Comisiones (Cuenta 7301... o Código COBN)
	WHEN T0."TransType" = 30 AND T0."ContraAct" IN ('73010201', '73010101') THEN COALESCE(NULLIF(T0."Debit", 0), -T0."Credit")
	WHEN T0."TransType" = 30 AND T0."TransCode" = 'COBN' THEN COALESCE(NULLIF(T0."Debit", 0), -T0."Credit")
	-- 3. Traslados (TREC)
	WHEN T0."TransType" = 30 AND T0."TransCode" = 'TREC' THEN COALESCE(NULLIF(T0."Debit", 0), -T0."Credit")
	-- 4. Depósitos (Tipos 24, 25, o Tipo 30 sobrante en el Débito)
	WHEN T0."TransType" = 24 OR T0."TransType" = 25 OR (T0."TransType" = 30 AND T0."Debit" <> 0) THEN COALESCE(NULLIF(T0."Debit", 0), -T0."Credit")
	-- 5. Pagos (Tipo 46, o Tipo 30 sobrante en el Crédito)
	WHEN T0."TransType" = 46 OR (T0."TransType" = 30 AND T0."Credit" <> 0) THEN COALESCE(NULLIF(T0."Debit", 0), -T0."Credit")
	-- Cierre de seguridad por si existe un registro atípico
	ELSE COALESCE(NULLIF(T0."Debit", 0), -T0."Credit")
            END AS "ValoresL",
            T0."Debit" AS "DebitoL",
            T0."Credit" AS "CreditoL",
            CASE
	WHEN T0."TransType" = 25 THEN T3."LocTotal"
                WHEN T0."TransType" = 24 THEN T1."DocTotal"
                WHEN T0."TransType" = 46 THEN T2."DocTotal" 
            END AS "Valor_Pagos_Rec/EfeL",
            CASE 
                -- Primero validamos que Ref3Line no esté nulo o vacío
                WHEN T0."Ref3Line" IS NOT NULL AND T0."Ref3Line" <> '' AND 
                    -- Verificamos si existe en la tabla de cheques
                    EXISTS (SELECT 1 FROM OCHO T4 WHERE TO_VARCHAR(T4."CheckNum") = T0."Ref3Line") 
                THEN 'Si'
                ELSE 'No'
            END AS "Es_ChequeL"
        FROM JDT1 T0
        LEFT JOIN ORCT T1 ON T0."Ref1" = TO_VARCHAR(T1."DocNum") AND T0."TransType" = 24
        LEFT JOIN OVPM T2 ON T0."Ref1" = TO_VARCHAR(T2."DocNum") AND T0."TransType" = 46
        LEFT JOIN ODPS T3 ON T0."Ref1" = TO_VARCHAR(T3."DeposNum") AND T0."TransType" = 25
        WHERE T0."Account" = '11010205'
            AND YEAR(T0."RefDate") = 2026
            AND MONTH(T0."RefDate") = 10
    ) AS LibroMayor
),
 
Tabla_Extracto AS (
    -- Generamos un número de fila para el Extracto Bancario
    SELECT 
        ROW_NUMBER() OVER(ORDER BY "OrdenE" ASC, "N_ReconciliacionE" ASC) AS "Num_Fila",
        ROW_NUMBER() OVER(PARTITION BY CASE WHEN "N_ReferenciaE" IS NULL OR "N_ReferenciaE" = '' THEN '@@VACIO@@' ELSE "N_ReferenciaE" END ORDER BY "OrdenE" ASC, "N_ReconciliacionE" ASC) AS "Fila_MatchE",
        *
    FROM (
        -- ========================================================
        -- 3. CONSULTA PARA EL SALDO INICIAL EXTRACTO
        -- ========================================================
        SELECT
            0 AS "OrdenE",
            2026 AS "AnioE",
            10 AS "MesE",
            'Saldo Inicial' AS "ConsultaE",
            T0."AcctCode" AS "N_CuentaE",
            MAX(T0."AcctName") AS "Nombre_CuentaE",
            CAST(NULL AS DATE) AS "F_VencimientoE",
            NULL AS "N_ReconciliacionE",
            NULL AS "N_ReferenciaE",
            'Acumulado hasta el mes anterior' AS "ComentarioE",
            NULL AS "Comentario2E",
            SUM(T0."CredAmnt" - T0."DebAmount") AS "ValoresE",
            NULL AS "DebitoE",
            NULL AS "CreditoE"
        FROM OBNK T0
        WHERE T0."AcctCode" = '11010205'
          AND T0."DueDate" < CAST(TO_VARCHAR(2026) || '-' || LPAD(TO_VARCHAR(10), 2, '0') || '-01' AS DATE)
        GROUP BY T0."AcctCode"
 
        UNION ALL
 
        -- ========================================================
        -- 4. MOVIMIENTOS DEL MES ACTUAL EXTRACTO
        -- ========================================================
        SELECT
            1 AS "OrdenE",
            YEAR(T0."DueDate") AS "AnioE",
            MONTH(T0."DueDate") AS "MesE",
            'Extracto' AS "ConsultaE",
            T0."AcctCode" AS "N_CuentaE",
            T0."AcctName" AS "Nombre_CuentaE",
            T0."DueDate" AS "F_VencimientoE",
            T0."BankMatch" AS "N_ReconciliacionE",
            T0."Ref" AS "N_ReferenciaE",
            T0."Memo" AS "ComentarioE",
            T0."Memo2" AS "Comentario2E",
            CASE
                WHEN T0."CredAmnt" <> 0 THEN T0."CredAmnt"
                WHEN T0."DebAmount" <> 0 THEN -T0."DebAmount"
            END AS "ValoresE",
            T0."DebAmount" AS "DebitoE",
            T0."CredAmnt" AS "CreditoE"
        FROM OBNK T0
        WHERE T0."AcctCode" = '11010205'
            AND YEAR(T0."DueDate") = 2026
            AND MONTH(T0."DueDate") = 10
    ) AS ExtractoBancario
)
-- ========================================================
-- RESULTADO FINAL: UNIÓN LADO A LADO
-- ========================================================
SELECT
    COALESCE(L."AnioL", E."AnioE") AS "Anio",
    COALESCE(L."MesL", E."MesE") AS "Mes",
    COALESCE(L."N_CuentaL", E."N_CuentaE") AS "N_Cuenta",
    COALESCE(L."Nombre_CuentaL", E."Nombre_CuentaE") AS "Nombre_Cuenta",
    -- Columnas del Libro (L)
    L."ConsultaL", L."DetalleL", L."F_ContabilizacionL", L."F_VencimientoL",
    L."Tipo_DocL", L."N_DocumentoL", L."N_TransaccionL", L."ComentarioL",
    L."Cuenta_ContrapartidaL", L."N_ReconciliacionL", L."N_ReferenciaL",
    L."ValoresL", L."DebitoL", L."CreditoL", L."Valor_Pagos_Rec/EfeL",L."Es_ChequeL",
    -- Columnas del Extracto (E)
    E."ConsultaE", E."F_VencimientoE", E."N_ReconciliacionE", E."N_ReferenciaE",
    E."ComentarioE", E."Comentario2E", E."ValoresE", E."DebitoE", E."CreditoE"
FROM Tabla_Libro L
FULL OUTER JOIN Tabla_Extracto E 
  ON (CASE WHEN L."N_ReferenciaL" IS NULL OR L."N_ReferenciaL" = '' THEN '@@VACIO@@' ELSE L."N_ReferenciaL" END) = 
     (CASE WHEN E."N_ReferenciaE" IS NULL OR E."N_ReferenciaE" = '' THEN '@@VACIO@@' ELSE E."N_ReferenciaE" END)
  AND L."Fila_MatchL" = E."Fila_MatchE"
ORDER BY COALESCE(L."Num_Fila", E."Num_Fila") ASC