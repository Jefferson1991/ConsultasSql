-- =============================================================================
-- SAP B1 sobre HANA - Vistas SB1_VIEW con clasificación por Área
-- Esquema: EMPAQPLAST_PROD
-- Desde: 2023-03-01
-- Clasificación basada en las TABLAS BASE que usa cada vista (OBJECT_DEPENDENCIES)
-- =============================================================================

-- =============================================================================
-- RESUMEN: CANTIDAD DE VISTAS POR ÁREA (basado en tablas que usa la vista)
-- =============================================================================
SELECT
    "Area",
    COUNT(*) AS "Cantidad"
FROM (
    SELECT
        V.VIEW_NAME,
        CASE
            -- BEAS Manufacturing (tablas BEAS_*, FTAPL, FTPOS, etc.)
            WHEN STRING_AGG(D.BASE_OBJECT_NAME, ',') LIKE '%BEAS_%'
              OR STRING_AGG(D.BASE_OBJECT_NAME, ',') LIKE '%FTAPL%'
              OR STRING_AGG(D.BASE_OBJECT_NAME, ',') LIKE '%FTPOS%'
              OR STRING_AGG(D.BASE_OBJECT_NAME, ',') LIKE '%FTIMD%'
              OR STRING_AGG(D.BASE_OBJECT_NAME, ',') LIKE '%FTORD%'
              OR STRING_AGG(D.BASE_OBJECT_NAME, ',') LIKE '%FTRES%'
              OR STRING_AGG(D.BASE_OBJECT_NAME, ',') LIKE '%FTINR%'
              OR STRING_AGG(D.BASE_OBJECT_NAME, ',') LIKE '%FTHAUPT%'
              OR STRING_AGG(D.BASE_OBJECT_NAME, ',') LIKE '%FTSTMP%'
              OR STRING_AGG(D.BASE_OBJECT_NAME, ',') LIKE '%APLATZ%'
                 THEN 'BEAS Manufacturing'
            -- Ventas (OINV, ODLN, ORDR, OQUT, OSLP)
            WHEN STRING_AGG(D.BASE_OBJECT_NAME, ',') LIKE '%OINV%'
              OR STRING_AGG(D.BASE_OBJECT_NAME, ',') LIKE '%INV1%'
              OR STRING_AGG(D.BASE_OBJECT_NAME, ',') LIKE '%ODLN%'
              OR STRING_AGG(D.BASE_OBJECT_NAME, ',') LIKE '%DLN1%'
              OR STRING_AGG(D.BASE_OBJECT_NAME, ',') LIKE '%ORDR%'
              OR STRING_AGG(D.BASE_OBJECT_NAME, ',') LIKE '%RDR1%'
              OR STRING_AGG(D.BASE_OBJECT_NAME, ',') LIKE '%OQUT%'
              OR STRING_AGG(D.BASE_OBJECT_NAME, ',') LIKE '%QUT1%'
              OR STRING_AGG(D.BASE_OBJECT_NAME, ',') LIKE '%OSLP%'
                 THEN 'Ventas'
            -- Compras (OPOR, OPRQ, OPDN, OPCH)
            WHEN STRING_AGG(D.BASE_OBJECT_NAME, ',') LIKE '%OPOR%'
              OR STRING_AGG(D.BASE_OBJECT_NAME, ',') LIKE '%POR1%'
              OR STRING_AGG(D.BASE_OBJECT_NAME, ',') LIKE '%OPRQ%'
              OR STRING_AGG(D.BASE_OBJECT_NAME, ',') LIKE '%PRQ1%'
              OR STRING_AGG(D.BASE_OBJECT_NAME, ',') LIKE '%OPDN%'
              OR STRING_AGG(D.BASE_OBJECT_NAME, ',') LIKE '%PDN1%'
              OR STRING_AGG(D.BASE_OBJECT_NAME, ',') LIKE '%OPCH%'
              OR STRING_AGG(D.BASE_OBJECT_NAME, ',') LIKE '%PCH1%'
                 THEN 'Compras'
            -- Inventario (OITM, OITW, OWTR, OIGE, OIGN, OBTQ, OWHS)
            WHEN STRING_AGG(D.BASE_OBJECT_NAME, ',') LIKE '%OITM%'
              OR STRING_AGG(D.BASE_OBJECT_NAME, ',') LIKE '%OITW%'
              OR STRING_AGG(D.BASE_OBJECT_NAME, ',') LIKE '%OWTR%'
              OR STRING_AGG(D.BASE_OBJECT_NAME, ',') LIKE '%WTR1%'
              OR STRING_AGG(D.BASE_OBJECT_NAME, ',') LIKE '%OIGE%'
              OR STRING_AGG(D.BASE_OBJECT_NAME, ',') LIKE '%IGE1%'
              OR STRING_AGG(D.BASE_OBJECT_NAME, ',') LIKE '%OIGN%'
              OR STRING_AGG(D.BASE_OBJECT_NAME, ',') LIKE '%IGN1%'
              OR STRING_AGG(D.BASE_OBJECT_NAME, ',') LIKE '%OBTQ%'
              OR STRING_AGG(D.BASE_OBJECT_NAME, ',') LIKE '%OBTW%'
              OR STRING_AGG(D.BASE_OBJECT_NAME, ',') LIKE '%OWHS%'
                 THEN 'Inventario'
            -- Finanzas / Tesorería (OACT, OJDT, OBNK, OVPM, ORCT)
            WHEN STRING_AGG(D.BASE_OBJECT_NAME, ',') LIKE '%OACT%'
              OR STRING_AGG(D.BASE_OBJECT_NAME, ',') LIKE '%OJDT%'
              OR STRING_AGG(D.BASE_OBJECT_NAME, ',') LIKE '%JDT1%'
              OR STRING_AGG(D.BASE_OBJECT_NAME, ',') LIKE '%OBNK%'
              OR STRING_AGG(D.BASE_OBJECT_NAME, ',') LIKE '%OVPM%'
              OR STRING_AGG(D.BASE_OBJECT_NAME, ',') LIKE '%VPM1%'
              OR STRING_AGG(D.BASE_OBJECT_NAME, ',') LIKE '%ORCT%'
              OR STRING_AGG(D.BASE_OBJECT_NAME, ',') LIKE '%RCT1%'
                 THEN 'Finanzas / Tesorería'
            -- Proyectos (OPRJ, OPMG)
            WHEN STRING_AGG(D.BASE_OBJECT_NAME, ',') LIKE '%OPRJ%'
              OR STRING_AGG(D.BASE_OBJECT_NAME, ',') LIKE '%OPMG%'
                 THEN 'Proyectos'
            -- Producción SBO estándar (OWOR)
            WHEN STRING_AGG(D.BASE_OBJECT_NAME, ',') LIKE '%OWOR%'
              OR STRING_AGG(D.BASE_OBJECT_NAME, ',') LIKE '%WOR1%'
                 THEN 'Producción SBO'
            -- Socios de Negocio (OCRD)
            WHEN STRING_AGG(D.BASE_OBJECT_NAME, ',') LIKE '%OCRD%'
              OR STRING_AGG(D.BASE_OBJECT_NAME, ',') LIKE '%CRD1%'
                 THEN 'Socios de Negocio'
            ELSE 'Otros'
        END AS "Area"
    FROM SYS.VIEWS V
    LEFT JOIN SYS.OBJECT_DEPENDENCIES D
        ON D.DEPENDENT_SCHEMA_NAME = V.SCHEMA_NAME
        AND D.DEPENDENT_OBJECT_NAME = V.VIEW_NAME
        AND D.BASE_OBJECT_TYPE = 'TABLE'
    WHERE V.SCHEMA_NAME = 'EMPAQPLAST_PROD'
      AND V.VIEW_NAME LIKE 'SB1_VIEW%'
      AND V.CREATE_TIME >= '2023-03-01'
    GROUP BY V.VIEW_NAME
)
GROUP BY "Area"
ORDER BY "Cantidad" DESC;


-- =============================================================================
-- DETALLE: LISTADO DE VISTAS SB1_VIEW CON TABLAS BASE Y ÁREA
-- =============================================================================
ALTER VIEW fact_vistas_bdd AS 
SELECT
    V.VIEW_NAME                                                         AS "NombreVista",
    V.CREATE_TIME                                                       AS "FechaCreacion",
    STRING_AGG(D.BASE_OBJECT_NAME, ', ' ORDER BY D.BASE_OBJECT_NAME)    AS "TablasBase",
    CASE
        -- BEAS Manufacturing (tablas BEAS_*, FTAPL, FTPOS, etc.)
        WHEN STRING_AGG(D.BASE_OBJECT_NAME, ',') LIKE '%BEAS_%'
          OR STRING_AGG(D.BASE_OBJECT_NAME, ',') LIKE '%FTAPL%'
          OR STRING_AGG(D.BASE_OBJECT_NAME, ',') LIKE '%FTPOS%'
          OR STRING_AGG(D.BASE_OBJECT_NAME, ',') LIKE '%FTIMD%'
          OR STRING_AGG(D.BASE_OBJECT_NAME, ',') LIKE '%FTORD%'
          OR STRING_AGG(D.BASE_OBJECT_NAME, ',') LIKE '%FTRES%'
          OR STRING_AGG(D.BASE_OBJECT_NAME, ',') LIKE '%FTINR%'
          OR STRING_AGG(D.BASE_OBJECT_NAME, ',') LIKE '%FTHAUPT%'
          OR STRING_AGG(D.BASE_OBJECT_NAME, ',') LIKE '%FTSTMP%'
          OR STRING_AGG(D.BASE_OBJECT_NAME, ',') LIKE '%APLATZ%'
             THEN 'BEAS Manufacturing'
        -- Ventas (OINV, ODLN, ORDR, OQUT, OSLP)
        WHEN STRING_AGG(D.BASE_OBJECT_NAME, ',') LIKE '%OINV%'
          OR STRING_AGG(D.BASE_OBJECT_NAME, ',') LIKE '%INV1%'
          OR STRING_AGG(D.BASE_OBJECT_NAME, ',') LIKE '%ODLN%'
          OR STRING_AGG(D.BASE_OBJECT_NAME, ',') LIKE '%DLN1%'
          OR STRING_AGG(D.BASE_OBJECT_NAME, ',') LIKE '%ORDR%'
          OR STRING_AGG(D.BASE_OBJECT_NAME, ',') LIKE '%RDR1%'
          OR STRING_AGG(D.BASE_OBJECT_NAME, ',') LIKE '%OQUT%'
          OR STRING_AGG(D.BASE_OBJECT_NAME, ',') LIKE '%QUT1%'
          OR STRING_AGG(D.BASE_OBJECT_NAME, ',') LIKE '%OSLP%'
             THEN 'Ventas'
        -- Compras (OPOR, OPRQ, OPDN, OPCH)
        WHEN STRING_AGG(D.BASE_OBJECT_NAME, ',') LIKE '%OPOR%'
          OR STRING_AGG(D.BASE_OBJECT_NAME, ',') LIKE '%POR1%'
          OR STRING_AGG(D.BASE_OBJECT_NAME, ',') LIKE '%OPRQ%'
          OR STRING_AGG(D.BASE_OBJECT_NAME, ',') LIKE '%PRQ1%'
          OR STRING_AGG(D.BASE_OBJECT_NAME, ',') LIKE '%OPDN%'
          OR STRING_AGG(D.BASE_OBJECT_NAME, ',') LIKE '%PDN1%'
          OR STRING_AGG(D.BASE_OBJECT_NAME, ',') LIKE '%OPCH%'
          OR STRING_AGG(D.BASE_OBJECT_NAME, ',') LIKE '%PCH1%'
             THEN 'Compras'
        -- Inventario (OITM, OITW, OWTR, OIGE, OIGN, OBTQ, OWHS)
        WHEN STRING_AGG(D.BASE_OBJECT_NAME, ',') LIKE '%OITM%'
          OR STRING_AGG(D.BASE_OBJECT_NAME, ',') LIKE '%OITW%'
          OR STRING_AGG(D.BASE_OBJECT_NAME, ',') LIKE '%OWTR%'
          OR STRING_AGG(D.BASE_OBJECT_NAME, ',') LIKE '%WTR1%'
          OR STRING_AGG(D.BASE_OBJECT_NAME, ',') LIKE '%OIGE%'
          OR STRING_AGG(D.BASE_OBJECT_NAME, ',') LIKE '%IGE1%'
          OR STRING_AGG(D.BASE_OBJECT_NAME, ',') LIKE '%OIGN%'
          OR STRING_AGG(D.BASE_OBJECT_NAME, ',') LIKE '%IGN1%'
          OR STRING_AGG(D.BASE_OBJECT_NAME, ',') LIKE '%OBTQ%'
          OR STRING_AGG(D.BASE_OBJECT_NAME, ',') LIKE '%OBTW%'
          OR STRING_AGG(D.BASE_OBJECT_NAME, ',') LIKE '%OWHS%'
             THEN 'Inventario'
        -- Finanzas / Tesorería (OACT, OJDT, OBNK, OVPM, ORCT)
        WHEN STRING_AGG(D.BASE_OBJECT_NAME, ',') LIKE '%OACT%'
          OR STRING_AGG(D.BASE_OBJECT_NAME, ',') LIKE '%OJDT%'
          OR STRING_AGG(D.BASE_OBJECT_NAME, ',') LIKE '%JDT1%'
          OR STRING_AGG(D.BASE_OBJECT_NAME, ',') LIKE '%OBNK%'
          OR STRING_AGG(D.BASE_OBJECT_NAME, ',') LIKE '%OVPM%'
          OR STRING_AGG(D.BASE_OBJECT_NAME, ',') LIKE '%VPM1%'
          OR STRING_AGG(D.BASE_OBJECT_NAME, ',') LIKE '%ORCT%'
          OR STRING_AGG(D.BASE_OBJECT_NAME, ',') LIKE '%RCT1%'
             THEN 'Finanzas / Tesorería'
        -- Proyectos (OPRJ, OPMG)
        WHEN STRING_AGG(D.BASE_OBJECT_NAME, ',') LIKE '%OPRJ%'
          OR STRING_AGG(D.BASE_OBJECT_NAME, ',') LIKE '%OPMG%'
             THEN 'Proyectos'
        -- Producción SBO estándar (OWOR)
        WHEN STRING_AGG(D.BASE_OBJECT_NAME, ',') LIKE '%OWOR%'
          OR STRING_AGG(D.BASE_OBJECT_NAME, ',') LIKE '%WOR1%'
             THEN 'Producción SBO'
        -- Socios de Negocio (OCRD)
        WHEN STRING_AGG(D.BASE_OBJECT_NAME, ',') LIKE '%OCRD%'
          OR STRING_AGG(D.BASE_OBJECT_NAME, ',') LIKE '%CRD1%'
             THEN 'Socios de Negocio'
        ELSE 'Otros'
    END                                                                 AS "Area"
FROM SYS.VIEWS V
LEFT JOIN SYS.OBJECT_DEPENDENCIES D
    ON D.DEPENDENT_SCHEMA_NAME = V.SCHEMA_NAME
    AND D.DEPENDENT_OBJECT_NAME = V.VIEW_NAME
    AND D.BASE_OBJECT_TYPE = 'TABLE'
WHERE V.SCHEMA_NAME = 'EMPAQPLAST_PROD'
  AND (V.VIEW_NAME LIKE 'SB1_VIEW%' OR V.VIEW_NAME LIKE 'PLG%')
  AND V.CREATE_TIME >= '2023-03-01'
GROUP BY V.VIEW_NAME, V.CREATE_TIME
ORDER BY V.CREATE_TIME DESC;


-- =============================================================================
-- DETALLE POR ÁREA ESPECÍFICA (ejemplo: BEAS Manufacturing)
-- Cambiar el filtro en el HAVING para ver otras áreas
-- =============================================================================
SELECT
    V.VIEW_NAME                                                         AS "NombreVista",
    V.CREATE_TIME                                                       AS "FechaCreacion",
    STRING_AGG(D.BASE_OBJECT_NAME, ', ' ORDER BY D.BASE_OBJECT_NAME)    AS "TablasBase"
FROM SYS.VIEWS V
LEFT JOIN SYS.OBJECT_DEPENDENCIES D
    ON D.DEPENDENT_SCHEMA_NAME = V.SCHEMA_NAME
    AND D.DEPENDENT_OBJECT_NAME = V.VIEW_NAME
    AND D.BASE_OBJECT_TYPE = 'TABLE'
WHERE V.SCHEMA_NAME = 'EMPAQPLAST_PROD'
  AND V.VIEW_NAME LIKE 'SB1_VIEW%'
  AND V.CREATE_TIME >= '2023-03-01'
GROUP BY V.VIEW_NAME, V.CREATE_TIME
HAVING STRING_AGG(D.BASE_OBJECT_NAME, ',') LIKE '%BEAS_%'
    OR STRING_AGG(D.BASE_OBJECT_NAME, ',') LIKE '%FTAPL%'
    OR STRING_AGG(D.BASE_OBJECT_NAME, ',') LIKE '%APLATZ%'
ORDER BY V.CREATE_TIME DESC;
