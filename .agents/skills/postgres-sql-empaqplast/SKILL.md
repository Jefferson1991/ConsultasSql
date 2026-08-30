---
name: postgres-sql-empaqplast
description: >-
  Escribe SQL seguro y mantenible para PostgreSQL en Empaqplast: auth app, NPS,
  permisos, menús y DDL. Usar cuando la consulta va en postgres/, mencione
  schemas auditorias/nps, permisos de roles, migraciones o MCP postgres-empaqplast.
---

# PostgreSQL — SQL Empaqplast

## MCP

| MCP | Uso |
|-----|-----|
| `user-postgres-produccion-empaqplast-cloud` | Producción cloud |
| `user-postgres-local-empaqplast` | Local / desarrollo |

Repo: `postgres/{app|nps}/`

## Estilo y nombres

Basado en [Bytebase Postgres SQL Review Guide](https://www.bytebase.com/blog/postgres-sql-review-guide/) y [PostgreSQL schema docs](https://www.postgresql.org/docs/current/ddl-schemas.html):

| Regla | Detalle |
|-------|---------|
| Identificadores | `snake_case`, minúsculas, máx ~63 chars |
| Reservadas | Evitar; consultar `SELECT * FROM pg_get_keywords()` |
| Schemas | Un schema por dominio: `auth`, `nps`, `auditorias` |
| Calificación | Siempre `schema.tabla` en scripts de producción |
| Comillas | Solo cuando necesario; preferir snake_case sin comillas |
| PK/FK | Nombre explícito: `tabla_pkey`, `tabla_col_fkey` |

## Seguridad de schemas

```sql
-- Revocar CREATE en public si aplica
REVOKE CREATE ON SCHEMA public FROM PUBLIC;

-- Rol de app: USAGE + permisos mínimos
GRANT USAGE ON SCHEMA auth TO app_role;
GRANT SELECT, INSERT, UPDATE ON ALL TABLES IN SCHEMA auth TO app_role;

-- search_path fijo por rol (evita hijacking)
ALTER ROLE app_role SET search_path = auth, public;
```

No otorgar superuser a roles de aplicación. Permisos por schema, no globales.

## Tipos recomendados

| Uso | Tipo |
|-----|------|
| IDs | `uuid` o `bigserial` |
| Texto | `text` (no varchar sin límite claro) |
| Fechas | `timestamptz` (siempre con zona) |
| JSON flexible | `jsonb` + índice GIN si se filtra |
| Dinero | `numeric(19,4)` |
| Flags | `boolean` |

## Migraciones / DDL

1. **Idempotente cuando sea posible** — `IF NOT EXISTS`, `ON CONFLICT`
2. **Transaccional** — DDL crítico dentro de `BEGIN; ... COMMIT;`
3. **Sin DROP ciego** — comentar impacto; backup antes en prod
4. **Locks** — evitar `ALTER` bloqueante en tablas grandes en horario pico; usar `CONCURRENTLY` en índices

```sql
BEGIN;

INSERT INTO auth.permisos (codigo, nombre)
VALUES ('menu.admin', 'Administrar menú')
ON CONFLICT (codigo) DO NOTHING;

COMMIT;
```

## Patrones Empaqplast existentes

| Archivo | Qué hace |
|---------|----------|
| `postgres/app/AutenticaciónNuevo.sql` | Permisos, menús, páginas auth |
| `postgres/app/Crear Base de datos en postgres.sql` | DDL infra |
| `postgres/nps/Conf Nps.sql` | Campañas NPS semestrales |

Antes de crear permiso/menú nuevo, buscar patrón en `AutenticaciónNuevo.sql`.

## Consultas analíticas

```sql
-- Siempre LIMIT en exploración
SELECT col1, col2
FROM nps.respuestas r
WHERE r.created_at >= NOW() - INTERVAL '90 days'
ORDER BY r.created_at DESC
LIMIT 100;
```

## Checklist

- [ ] Schema calificado (`auth.tabla`)
- [ ] snake_case consistente
- [ ] Permisos mínimos (GRANT explícito)
- [ ] Script idempotente o documentado como one-shot
- [ ] Archivo en `postgres/app/` o `postgres/nps/`

## Referencia extendida

Seguridad y revisión SQL: [referencias/estilo-y-seguridad.md](referencias/estilo-y-seguridad.md)
