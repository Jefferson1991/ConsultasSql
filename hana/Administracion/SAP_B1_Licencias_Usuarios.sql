-- =============================================================================
-- SAP B1 sobre HANA - Reporte de Licencias y Usuarios
-- Esquema: EMPAQPLAST_PROD
-- =============================================================================

-- =============================================================================
-- USUARIOS ACTIVOS (Locked = 'N') CON SU LICENCIA
-- =============================================================================
SELECT
    T0."USERID"         AS "IdUsuario",
    T0."USER_CODE"      AS "CodigoUsuario",
    T0."U_NAME"         AS "NombreUsuario",
    CASE 
        WHEN T0."dType" = 'S' THEN 'Professional'
        WHEN T0."dType" = 'H' THEN 'Limited'
        ELSE 'Otro'
    END                 AS "TipoLicencia",
    CASE WHEN T0."SUPERUSER" = 'Y' THEN 'Sí' ELSE 'No' END AS "EsSuperUsuario",
    T0."createDate"     AS "FechaCreacion",
    T0."lastLogin"      AS "UltimoLogin",
    DAYS_BETWEEN(T0."lastLogin", CURRENT_DATE) AS "DiasDesdeUltimoLogin"
FROM EMPAQPLAST_PROD."OUSR" T0
WHERE T0."Locked" = 'N'
ORDER BY T0."dType", T0."U_NAME";


-- =============================================================================
-- USUARIOS INACTIVOS/BLOQUEADOS (Locked = 'Y') CON SU LICENCIA
-- =============================================================================
SELECT
    T0."USERID"         AS "IdUsuario",
    T0."USER_CODE"      AS "CodigoUsuario",
    T0."U_NAME"         AS "NombreUsuario",
    CASE 
        WHEN T0."dType" = 'S' THEN 'Professional'
        WHEN T0."dType" = 'H' THEN 'Limited'
        ELSE 'Otro'
    END                 AS "TipoLicencia",
    CASE WHEN T0."SUPERUSER" = 'Y' THEN 'Sí' ELSE 'No' END AS "EsSuperUsuario",
    T0."createDate"     AS "FechaCreacion",
    T0."lastLogin"      AS "UltimoLogin",
    DAYS_BETWEEN(T0."lastLogin", CURRENT_DATE) AS "DiasDesdeUltimoLogin"
FROM EMPAQPLAST_PROD."OUSR" T0
WHERE T0."Locked" = 'Y'
ORDER BY T0."dType", T0."U_NAME";


-- =============================================================================
-- RESUMEN DE LICENCIAS POR TIPO
-- =============================================================================
SELECT
    CASE 
        WHEN "dType" = 'S' THEN 'Professional (Completa)'
        WHEN "dType" = 'H' THEN 'Limited (Limitada)'
        ELSE 'Otro'
    END AS "Tipo_Licencia",
    COUNT(*) AS "Total_Licencias",
    SUM(CASE WHEN "Locked" = 'N' THEN 1 ELSE 0 END) AS "Activas",
    SUM(CASE WHEN "Locked" = 'Y' THEN 1 ELSE 0 END) AS "Bloqueadas",
    SUM(CASE WHEN "SUPERUSER" = 'Y' THEN 1 ELSE 0 END) AS "SuperUsuarios"
FROM EMPAQPLAST_PROD."OUSR"
GROUP BY "dType"
ORDER BY "Total_Licencias" DESC;


-- =============================================================================
-- 2. DETALLE DE USUARIOS CON LICENCIAS, SESIONES Y USO
-- =============================================================================
SELECT
    T0."USERID"                         AS "IdUsuario",
    T0."USER_CODE"                      AS "CodigoUsuario",
    T0."U_NAME"                         AS "NombreUsuario",
    CASE 
        WHEN T0."dType" = 'S' THEN 'Professional'
        WHEN T0."dType" = 'H' THEN 'Limited'
        ELSE 'Otro'
    END                                 AS "TipoLicencia",
    CASE WHEN T0."SUPERUSER" = 'Y' THEN 'Sí' ELSE 'No' END AS "EsSuperUsuario",
    CASE WHEN T0."Locked" = 'Y' THEN 'Bloqueado' ELSE 'Activo' END AS "Estado",
    T0."createDate"                     AS "FechaCreacion",
    T0."lastLogin"                      AS "UltimoLogin",
    T0."LstLogoutD"                     AS "UltimoLogout",
    DAYS_BETWEEN(T0."lastLogin", CURRENT_DATE) AS "DiasDesdeUltimoLogin",
    T1."TotalSesiones",
    T1."SesionesMes30Dias",
    T1."PromedioSesionesMes"
FROM EMPAQPLAST_PROD."OUSR" T0
LEFT JOIN (
    -- Subquery para estadísticas de sesiones por usuario
    SELECT 
        "UserCode",
        COUNT(*) AS "TotalSesiones",
        SUM(CASE WHEN "Date" >= ADD_DAYS(CURRENT_DATE, -30) THEN 1 ELSE 0 END) AS "SesionesMes30Dias",
        ROUND(COUNT(*) * 1.0 / NULLIF(MONTHS_BETWEEN(CURRENT_DATE, MIN("Date")), 0), 2) AS "PromedioSesionesMes"
    FROM EMPAQPLAST_PROD."USR5"
    WHERE "Action" = 'L'  -- Solo contar Logins
    GROUP BY "UserCode"
) T1 ON T0."USER_CODE" = T1."UserCode"
ORDER BY T0."lastLogin" DESC NULLS LAST;


-- =============================================================================
-- 3. USUARIOS ACTIVOS VS INACTIVOS (últimos 30/60/90 días)
-- =============================================================================
SELECT
    CASE 
        WHEN T0."Locked" = 'Y' THEN 'Bloqueado'
        WHEN T0."lastLogin" IS NULL THEN 'Nunca ingresó'
        WHEN DAYS_BETWEEN(T0."lastLogin", CURRENT_DATE) <= 30 THEN 'Activo (0-30 días)'
        WHEN DAYS_BETWEEN(T0."lastLogin", CURRENT_DATE) <= 60 THEN 'Moderado (31-60 días)'
        WHEN DAYS_BETWEEN(T0."lastLogin", CURRENT_DATE) <= 90 THEN 'Bajo uso (61-90 días)'
        ELSE 'Inactivo (+90 días)'
    END AS "Categoria_Actividad",
    CASE 
        WHEN T0."dType" = 'S' THEN 'Professional'
        WHEN T0."dType" = 'H' THEN 'Limited'
        ELSE 'Otro'
    END AS "TipoLicencia",
    COUNT(*) AS "CantidadUsuarios"
FROM EMPAQPLAST_PROD."OUSR" T0
GROUP BY
    CASE 
        WHEN T0."Locked" = 'Y' THEN 'Bloqueado'
        WHEN T0."lastLogin" IS NULL THEN 'Nunca ingresó'
        WHEN DAYS_BETWEEN(T0."lastLogin", CURRENT_DATE) <= 30 THEN 'Activo (0-30 días)'
        WHEN DAYS_BETWEEN(T0."lastLogin", CURRENT_DATE) <= 60 THEN 'Moderado (31-60 días)'
        WHEN DAYS_BETWEEN(T0."lastLogin", CURRENT_DATE) <= 90 THEN 'Bajo uso (61-90 días)'
        ELSE 'Inactivo (+90 días)'
    END,
    CASE 
        WHEN T0."dType" = 'S' THEN 'Professional'
        WHEN T0."dType" = 'H' THEN 'Limited'
        ELSE 'Otro'
    END
ORDER BY "TipoLicencia", "Categoria_Actividad";


-- =============================================================================
-- 4. TOP USUARIOS POR USO (sesiones en los últimos 30 días)
-- =============================================================================
SELECT
    T0."USER_CODE"                      AS "CodigoUsuario",
    T0."U_NAME"                         AS "NombreUsuario",
    CASE 
        WHEN T0."dType" = 'S' THEN 'Professional'
        WHEN T0."dType" = 'H' THEN 'Limited'
        ELSE 'Otro'
    END                                 AS "TipoLicencia",
    T1."Sesiones30Dias",
    T1."DiasConSesion",
    ROUND(T1."Sesiones30Dias" * 1.0 / NULLIF(T1."DiasConSesion", 0), 2) AS "SesionesPorDia"
FROM EMPAQPLAST_PROD."OUSR" T0
INNER JOIN (
    SELECT 
        "UserCode",
        COUNT(*) AS "Sesiones30Dias",
        COUNT(DISTINCT "Date") AS "DiasConSesion"
    FROM EMPAQPLAST_PROD."USR5"
    WHERE "Action" = 'L'
      AND "Date" >= ADD_DAYS(CURRENT_DATE, -30)
    GROUP BY "UserCode"
) T1 ON T0."USER_CODE" = T1."UserCode"
WHERE T0."Locked" = 'N'
ORDER BY T1."Sesiones30Dias" DESC;


-- =============================================================================
-- 5. LICENCIAS SIN USO (candidatas a reasignación)
-- Usuarios activos (no bloqueados) que no han ingresado en más de 90 días
-- =============================================================================
SELECT
    T0."USER_CODE"                      AS "CodigoUsuario",
    T0."U_NAME"                         AS "NombreUsuario",
    CASE 
        WHEN T0."dType" = 'S' THEN 'Professional'
        WHEN T0."dType" = 'H' THEN 'Limited'
        ELSE 'Otro'
    END                                 AS "TipoLicencia",
    T0."createDate"                     AS "FechaCreacion",
    T0."lastLogin"                      AS "UltimoLogin",
    DAYS_BETWEEN(T0."lastLogin", CURRENT_DATE) AS "DiasInactivo"
FROM EMPAQPLAST_PROD."OUSR" T0
WHERE T0."Locked" = 'N'
  AND (T0."lastLogin" IS NULL OR DAYS_BETWEEN(T0."lastLogin", CURRENT_DATE) > 90)
ORDER BY T0."lastLogin" NULLS FIRST;
