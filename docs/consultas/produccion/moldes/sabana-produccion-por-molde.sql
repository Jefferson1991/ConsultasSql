/* =========================================================================
   SÁBANA DE PRODUCCIÓN POR MOLDE Y MES
   Esquema: EMPAQPLAST_PROD | Motor: SAP HANA (SAP B1 + Beas)

   Propósito: una fila por molde, sin repetir, con los kilos fabricados y el
              número de órdenes de fabricación de cada mes y el total del año.
              El molde que no produjo sale con todos los meses en 0.

   Grano: 1 fila = 1 molde. (SB1_VIEW_ANALISIS_MOLDES, en cambio, agrupa también
          por artículo y por mes, así que repite el molde; y su
          WHERE "Tiempo_Ciclo_Real" > 0 convierte sus LEFT JOIN en INNER y deja
          fuera a los moldes sin tiempos. Por eso esta consulta es aparte.)

   CÓMO SE ENLAZA EL MOLDE CON LA PRODUCCIÓN
     SB1_VIEW_PROD_TRANSFORMADOS."Lote_Orden"  =  SB1_VIEW_BEAS_RESUMEN_OF."OT"
     y esa vista ya resuelve MOLDE_CODIGO por OT.

   SUPUESTOS VERIFICADOS CONTRA PRODUCCIÓN (2026-11-19)
     - SB1_VIEW_BEAS_RESUMEN_OF tiene UNA posición por OT (6.597 OTs, todas con
       una sola fila), así que el join por OT no multiplica kilos.
     - Universo de moldes = activos fijos (182 códigos con
       U_EMPA_COD_RECURSO = 'MOLDE') UNION Beas (214 códigos) = 265 únicos.
       Hay que unir: 82 moldes que producen NO están en el maestro de activos
       fijos, entre ellos MOLSOP1350, el de más órdenes del año.
     - Para el año 2026: 178 moldes con producción y 87 sin ninguna.
     - El JOIN del molde va por U_EMPA_COD_BEAS (ver docs/domain/moldes.md §3).
       Al 2026-11-19 U_EMPA_COD_BEAS y U_EMPA_COD_FRACTTAL resuelven el mismo
       conjunto de 132 moldes, pero se usa el documentado.

   QUÉ QUEDA FUERA, A PROPÓSITO
     La producción sin molde. En 2026, 1.445 de 3.958 órdenes de transformados
     (3,38 M kg de 15,15 M) no tienen OT en Beas: son CARNEEXT, IMPRES-2,
     BOBINZ-3, SELLA-3 y EXTRUS-1, es decir extrusión, impresión, bobinado y
     sellado. Esos procesos no usan molde.

   PARA CAMBIAR EL AÑO: la línea marcada ANIO, una sola vez.
   ========================================================================= */

WITH PARAM AS (
    SELECT 2026 AS "ANIO" FROM DUMMY          -- <<< ANIO: cambiar aquí
),

/* Moldes del maestro de activos fijos, deduplicados por código Beas.
   Son 212 filas de activo para 182 códigos: un mismo molde puede tener más de
   una ficha de activo, por eso el GROUP BY. */
MOLDES_ACTIVO AS (
    SELECT
        A."U_EMPA_COD_BEAS"                 AS "MOLDE",
        MAX(A."Descripcion")                AS "DESC_ACTIVO",
        MAX(A."U_EMPA_COD_FRACTTAL")        AS "COD_FRACTTAL",
        MIN(A."Cod_Articulo")               AS "ACTIVO_FIJO",
        COUNT(*)                            AS "FICHAS_ACTIVO"
    FROM "EMPAQPLAST_PROD"."SB1_VIEW_ACTIVOS_FIJOS" A
    WHERE A."U_EMPA_COD_RECURSO" = 'MOLDE'
      AND A."U_EMPA_COD_BEAS" IS NOT NULL
      AND TRIM(A."U_EMPA_COD_BEAS") <> ''
    GROUP BY A."U_EMPA_COD_BEAS"
),

/* Moldes que aparecen en órdenes de Beas, hayan producido o no este año. */
MOLDES_BEAS AS (
    SELECT
        R."MOLDE_CODIGO"                    AS "MOLDE",
        MAX(R."MOLDE_DESCRIPCION")          AS "DESC_BEAS",
        MAX(R."AREA")                       AS "AREA",
        COUNT(*)                            AS "OTS_HISTORICAS"
    FROM "EMPAQPLAST_PROD"."SB1_VIEW_BEAS_RESUMEN_OF" R
    WHERE R."MOLDE_CODIGO" IS NOT NULL
      AND TRIM(R."MOLDE_CODIGO") <> ''
    GROUP BY R."MOLDE_CODIGO"
),

/* El universo: la unión de los dos. UNION, no UNION ALL, para no repetir. */
UNIVERSO AS (
    SELECT "MOLDE" FROM MOLDES_ACTIVO
    UNION
    SELECT "MOLDE" FROM MOLDES_BEAS
),

/* Producción del año, por molde y mes. El mes sale de la fecha del recibo de
   producción (transformados), que es cuando se fabricó. */
PRODUCCION AS (
    SELECT
        R."MOLDE_CODIGO"                        AS "MOLDE",
        T."mes"                                 AS "MES",
        SUM(T."kilogramos_completados")         AS "KG",
        SUM(T."cantidad_unidades")              AS "UNIDADES",
        COUNT(DISTINCT T."Lote_Orden")          AS "ORDENES"
    FROM "EMPAQPLAST_PROD"."SB1_VIEW_PROD_TRANSFORMADOS" T
    INNER JOIN "EMPAQPLAST_PROD"."SB1_VIEW_BEAS_RESUMEN_OF" R
            ON TO_VARCHAR(R."OT") = T."Lote_Orden"
    CROSS JOIN PARAM P
    WHERE T."anio" = P."ANIO"
      AND R."MOLDE_CODIGO" IS NOT NULL
      AND TRIM(R."MOLDE_CODIGO") <> ''
    GROUP BY R."MOLDE_CODIGO", T."mes"
),

/* Órdenes del año contadas una sola vez. No es la suma de las mensuales: una
   orden que produce en enero y en febrero cuenta en los dos meses, pero es una
   sola orden en el año. */
ORDENES_ANIO AS (
    SELECT
        R."MOLDE_CODIGO"                        AS "MOLDE",
        COUNT(DISTINCT T."Lote_Orden")          AS "ORDENES_ANIO"
    FROM "EMPAQPLAST_PROD"."SB1_VIEW_PROD_TRANSFORMADOS" T
    INNER JOIN "EMPAQPLAST_PROD"."SB1_VIEW_BEAS_RESUMEN_OF" R
            ON TO_VARCHAR(R."OT") = T."Lote_Orden"
    CROSS JOIN PARAM P
    WHERE T."anio" = P."ANIO"
      AND R."MOLDE_CODIGO" IS NOT NULL
      AND TRIM(R."MOLDE_CODIGO") <> ''
    GROUP BY R."MOLDE_CODIGO"
)

SELECT
    (SELECT "ANIO" FROM PARAM)                                              AS "Anio",
    U."MOLDE"                                                               AS "Molde",
    COALESCE(B."DESC_BEAS", A."DESC_ACTIVO")                                AS "Descripcion",
    B."AREA"                                                                AS "Area",
    CASE
        WHEN A."MOLDE" IS NOT NULL AND B."MOLDE" IS NOT NULL THEN 'ACTIVO FIJO + BEAS'
        WHEN A."MOLDE" IS NOT NULL                           THEN 'SOLO ACTIVO FIJO'
        ELSE                                                      'SOLO BEAS'
    END                                                                     AS "Origen_Molde",
    A."COD_FRACTTAL"                                                        AS "Cod_Fracttal",
    A."ACTIVO_FIJO"                                                         AS "Activo_Fijo",

    -- Kilogramos por mes
    ROUND(COALESCE(SUM(CASE WHEN D."MES" =  1 THEN D."KG" END), 0), 2)      AS "Kg_01_Ene",
    ROUND(COALESCE(SUM(CASE WHEN D."MES" =  2 THEN D."KG" END), 0), 2)      AS "Kg_02_Feb",
    ROUND(COALESCE(SUM(CASE WHEN D."MES" =  3 THEN D."KG" END), 0), 2)      AS "Kg_03_Mar",
    ROUND(COALESCE(SUM(CASE WHEN D."MES" =  4 THEN D."KG" END), 0), 2)      AS "Kg_04_Abr",
    ROUND(COALESCE(SUM(CASE WHEN D."MES" =  5 THEN D."KG" END), 0), 2)      AS "Kg_05_May",
    ROUND(COALESCE(SUM(CASE WHEN D."MES" =  6 THEN D."KG" END), 0), 2)      AS "Kg_06_Jun",
    ROUND(COALESCE(SUM(CASE WHEN D."MES" =  7 THEN D."KG" END), 0), 2)      AS "Kg_07_Jul",
    ROUND(COALESCE(SUM(CASE WHEN D."MES" =  8 THEN D."KG" END), 0), 2)      AS "Kg_08_Ago",
    ROUND(COALESCE(SUM(CASE WHEN D."MES" =  9 THEN D."KG" END), 0), 2)      AS "Kg_09_Sep",
    ROUND(COALESCE(SUM(CASE WHEN D."MES" = 10 THEN D."KG" END), 0), 2)      AS "Kg_10_Oct",
    ROUND(COALESCE(SUM(CASE WHEN D."MES" = 11 THEN D."KG" END), 0), 2)      AS "Kg_11_Nov",
    ROUND(COALESCE(SUM(CASE WHEN D."MES" = 12 THEN D."KG" END), 0), 2)      AS "Kg_12_Dic",
    ROUND(COALESCE(SUM(D."KG"), 0), 2)                                      AS "Kg_Total_Anio",

    -- Órdenes de fabricación por mes
    COALESCE(SUM(CASE WHEN D."MES" =  1 THEN D."ORDENES" END), 0)           AS "Ord_01_Ene",
    COALESCE(SUM(CASE WHEN D."MES" =  2 THEN D."ORDENES" END), 0)           AS "Ord_02_Feb",
    COALESCE(SUM(CASE WHEN D."MES" =  3 THEN D."ORDENES" END), 0)           AS "Ord_03_Mar",
    COALESCE(SUM(CASE WHEN D."MES" =  4 THEN D."ORDENES" END), 0)           AS "Ord_04_Abr",
    COALESCE(SUM(CASE WHEN D."MES" =  5 THEN D."ORDENES" END), 0)           AS "Ord_05_May",
    COALESCE(SUM(CASE WHEN D."MES" =  6 THEN D."ORDENES" END), 0)           AS "Ord_06_Jun",
    COALESCE(SUM(CASE WHEN D."MES" =  7 THEN D."ORDENES" END), 0)           AS "Ord_07_Jul",
    COALESCE(SUM(CASE WHEN D."MES" =  8 THEN D."ORDENES" END), 0)           AS "Ord_08_Ago",
    COALESCE(SUM(CASE WHEN D."MES" =  9 THEN D."ORDENES" END), 0)           AS "Ord_09_Sep",
    COALESCE(SUM(CASE WHEN D."MES" = 10 THEN D."ORDENES" END), 0)           AS "Ord_10_Oct",
    COALESCE(SUM(CASE WHEN D."MES" = 11 THEN D."ORDENES" END), 0)           AS "Ord_11_Nov",
    COALESCE(SUM(CASE WHEN D."MES" = 12 THEN D."ORDENES" END), 0)           AS "Ord_12_Dic",
    COALESCE(MAX(O."ORDENES_ANIO"), 0)                                      AS "Ordenes_Total_Anio",

    -- Apoyo
    ROUND(COALESCE(SUM(D."UNIDADES"), 0), 0)                                AS "Unidades_Total_Anio",
    COUNT(DISTINCT D."MES")                                                 AS "Meses_Con_Produccion",
    COALESCE(B."OTS_HISTORICAS", 0)                                         AS "OTs_Historicas_Beas"

FROM UNIVERSO U
LEFT JOIN MOLDES_ACTIVO A ON A."MOLDE" = U."MOLDE"
LEFT JOIN MOLDES_BEAS   B ON B."MOLDE" = U."MOLDE"
LEFT JOIN PRODUCCION    D ON D."MOLDE" = U."MOLDE"
LEFT JOIN ORDENES_ANIO  O ON O."MOLDE" = U."MOLDE"
GROUP BY
    U."MOLDE",
    A."MOLDE", B."MOLDE",
    A."DESC_ACTIVO", B."DESC_BEAS", B."AREA",
    A."COD_FRACTTAL", A."ACTIVO_FIJO", B."OTS_HISTORICAS"
ORDER BY "Kg_Total_Anio" DESC, U."MOLDE";


/* =========================================================================
   VERSIÓN LARGA (molde × mes), si se va a modelar en Power BI.
   Una fila por molde y mes con producción; no trae los moldes en cero.
   =========================================================================

WITH PARAM AS (SELECT 2026 AS "ANIO" FROM DUMMY)
SELECT
    P."ANIO"                                AS "Anio",
    T."mes"                                 AS "Mes",
    R."MOLDE_CODIGO"                        AS "Molde",
    MAX(R."MOLDE_DESCRIPCION")              AS "Descripcion",
    MAX(R."AREA")                           AS "Area",
    COUNT(DISTINCT T."Lote_Orden")          AS "Ordenes",
    ROUND(SUM(T."kilogramos_completados"),2) AS "Kg",
    ROUND(SUM(T."cantidad_unidades"),0)     AS "Unidades"
FROM "EMPAQPLAST_PROD"."SB1_VIEW_PROD_TRANSFORMADOS" T
INNER JOIN "EMPAQPLAST_PROD"."SB1_VIEW_BEAS_RESUMEN_OF" R
        ON TO_VARCHAR(R."OT") = T."Lote_Orden"
CROSS JOIN PARAM P
WHERE T."anio" = P."ANIO"
  AND R."MOLDE_CODIGO" IS NOT NULL
  AND TRIM(R."MOLDE_CODIGO") <> ''
GROUP BY P."ANIO", T."mes", R."MOLDE_CODIGO"
ORDER BY "Mes", "Kg" DESC;

   =========================================================================
   NOTA PARA QUIEN EDITE ESTA CONSULTA
   No filtrar los moldes con NOT IN contra una subconsulta que pueda traer
   NULL: un solo NULL hace que NOT IN no devuelva ninguna fila. Usar
   NOT EXISTS, o filtrar el NULL en la subconsulta.
   ========================================================================= */
