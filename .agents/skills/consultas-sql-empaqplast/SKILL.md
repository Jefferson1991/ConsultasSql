---
name: consultas-sql-empaqplast
description: >-
  Escribe, revisa y despliega consultas SQL para Empaqplast sobre SAP B1 (HANA),
  SQL Server (TimeControl, OnlyControl, AlertasB1), PostgreSQL y automatizaciones
  Python. Usar cuando el usuario pida consultas, vistas SB1_VIEW_*, alertas por
  correo, OPENQUERY, reportes de inventario/cartera/producción/RRHH, o trabaje
  en el repo Consultas con SQL.
---

# Consultas SQL — Empaqplast

## Antes de escribir SQL

1. **Verificar esquema en vivo** — nunca asumir nombres de columna.
   - HANA/SAP B1: MCP `user-hana-sap-b1-produccion` (`hana_describe_table`, `hana_execute_query`)
   - SQL Server TimeControl: MCP `user-sqlserver-timecontrol`
   - SQL Server OnlyControl: MCP `user-sqlserver-onlycontrol`
   - PostgreSQL: MCP `user-postgres-produccion-empaqplast-cloud` o `user-postgres-local-empaqplast`
2. **Ubicar consultas existentes** — abrir `docs/catalogo/guia-consultas.html` o buscar en el repo antes de crear algo nuevo.
3. **Seguir reglas de carpeta** — cada pedido nuevo va en su propia carpeta kebab-case en español (ver `README.md` del repo).

## Convenciones obligatorias

| Motor | Regla |
|-------|-------|
| SAP B1 / HANA | Columnas B1 entre comillas dobles y case-sensitive: `"ItemCode"`. Tablas B1 en MAYÚSCULAS sin comillas: `OITM`. Esquema prod: `EMPAQPLAST_PROD`. |
| Vistas alerta | Prefijo `SB1_VIEW_*` en HANA → vista `AlertasB1` con `OPENQUERY(HANAODBC, ...)` → Python (`sqlcmd`, `xlsxwriter`, SMTP). |
| OPENQUERY | El `WHERE` va **dentro** del OPENQUERY; filtrar afuera trae todo el histórico. |
| SQL origen | Código magro; omitir `AS` cuando la vista ya trae alias. |
| Python | `sqlcmd` para comandos de base de datos. |

## Flujo por tipo de entrega

### Consulta ad hoc / reporte
```
Verificar esquema → escribir .sql en carpeta del pedido → probar con MCP → documentar supuestos en cabecera
```

### Vista HANA para consumo externo
```
CREATE VIEW EMPAQPLAST_PROD.SB1_VIEW_* → GRANT SELECT → (opcional) vista AlertasB1 → (opcional) alerta Python
```

### Dashboard Power BI
```
Consulta en `docs/consultas/rrhh/powerbi/` → filtrar por fecha → tablas dim/hechos separadas → documentar relaciones en cabecera
```

## Taxonomía del catálogo

Organizar por **dominio de negocio**, no por motor. Todo cuelga de `docs/consultas/`:

| Dominio | Qué entra | Motores |
|---|---|---|
| `cartera/` | bloqueos, vencidas, retenciones | HANA |
| `compras/` | cadena de alerta de OC | HANA + SQL Server + Python |
| `supply/` | cadena de stock crítico | HANA + SQL Server + Python |
| `inventario/` | stock, antigüedad, UPC, auditoría | HANA |
| `produccion/` | transformados, trazabilidad, moldes | HANA + Beas |
| `logistica/` | pallets, traslados | HANA |
| `ventas/` | notas de crédito, pricing | HANA + Python |
| `activos-fijos/` | activos B1 y Fracttal | HANA |
| `eficiencia-energetica/` | combustible | HANA |
| `rrhh/` | ausentismo, atrasos, permisos, asistencia, Power BI | SQL Server |
| `apps/` | auth, DDL, NPS | PostgreSQL |
| `plataforma/` | administración B1, validaciones, ops | HANA + SQL Server |

Si el pedido cruza motores, los archivos van **juntos** en el dominio. Cada
dominio tiene `README.md` con motor, servidor y orden de despliegue.

## Cabecera mínima en cada .sql

```sql
/* =========================================================================
   NOMBRE_OBJETO
   Esquema: ... | Motor: ...
   Propósito: una línea clara
   Supuestos verificados: ...
   Despliegue: orden si aplica (vista HANA → linked server → Python)
   ========================================================================= */
```

## Checklist antes de entregar

- [ ] Nombres de columna verificados contra servidor
- [ ] Filtros de fecha/documento explícitos (no full scan accidental)
- [ ] Archivo en carpeta correcta del pedido (no suelto en raíz)
- [ ] Cabecera con supuestos de negocio no obvios
- [ ] Si es alerta: WHERE dentro de OPENQUERY probado con COUNT

## Skills por motor (usar según BDD)

| Motor | Skill |
|-------|-------|
| SAP B1 / HANA | `sap-b1-hana-sql` |
| SQL Server | `sqlserver-tsql-empaqplast` |
| PostgreSQL | `postgres-sql-empaqplast` |

Activar el skill del motor **antes** de escribir SQL en esa BDD.

## Referencias (repo Empaqplast)

- Patrones SAP B1 / HANA: [referencias/sap-b1-hana.md](referencias/sap-b1-hana.md)
- SQL Server, AlertasB1 y TimeControl: [referencias/sqlserver-patrones.md](referencias/sqlserver-patrones.md)
- Flujo completo alertas y organización: [referencias/flujo-trabajo.md](referencias/flujo-trabajo.md)
- Catálogo visual del repo: `docs/catalogo/guia-consultas.html`
