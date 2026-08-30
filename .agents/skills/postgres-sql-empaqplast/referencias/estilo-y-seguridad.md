# PostgreSQL — Estilo y seguridad

## Revisión antes de desplegar

- [ ] ¿El script es re-ejecutable o dice explícitamente que es one-shot?
- [ ] ¿GRANT solo al rol necesario (ej. ADMINISTRADOR)?
- [ ] ¿Hay INSERT sin ON CONFLICT en catálogos que ya existen?
- [ ] ¿TRUNCATE/DELETE masivo documentado con rollback plan?

## Row Level Security (multi-tenant)

Si la app filtra por tenant:

```sql
ALTER TABLE billing.facturas ENABLE ROW LEVEL SECURITY;

CREATE POLICY tenant_isolation ON billing.facturas
  USING (tenant_id = current_setting('app.tenant_id')::uuid);
```

## Índices jsonb

```sql
CREATE INDEX idx_eventos_payload ON analytics.eventos USING GIN (payload);
-- Filtro: WHERE payload @> '{"tipo":"login"}'
```

## Anti-patrones

| Evitar | Motivo |
|--------|--------|
| `"MixedCase"` quoted identifiers | Dificulta tooling y MCP |
| `SELECT *` en prod | Rompe contratos y planes |
| Permisos en `public` writable | Riesgo search_path hijacking |
| Secuencias sin OWNED BY | Huérfanas al migrar |
| Funciones sin SECURITY definido | Revisar `SECURITY DEFINER` con cuidado |

## Herramientas MCP útiles

- `describe_table` — columnas y tipos reales
- `explain_query` — plan antes de deploy
- `list_policies` — RLS existente
