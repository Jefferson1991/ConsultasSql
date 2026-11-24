BEGIN;

TRUNCATE TABLE
  nps.nps_respuesta_area,
  nps.nps_encuesta,
  nps.nps_cliente
RESTART IDENTITY;

COMMIT;

--Nueva campaña semestral
INSERT INTO nps.nps_campana ("Nombre", "Periodo", "FechaInicio", "FechaFin", "Estado")
VALUES ('NPS 2026 - Semestre 2', '2026-S2', '2026-07-01', '2026-12-31', 'activa');
--Cerrar la anterior:
UPDATE nps.nps_campana SET "Estado" = 'cerrada' WHERE "Periodo" = '2026-S1';
--Activar la nueva:
UPDATE nps.nps_campana SET "Estado" = 'activa' WHERE "Periodo" = '2026-S2';


BEGIN;

TRUNCATE TABLE
  nps.nps_respuesta_area,
  nps.nps_encuesta,
  nps.nps_cliente,
  nps.nps_campana
RESTART IDENTITY;

COMMIT;