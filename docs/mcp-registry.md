# Registro de MCP — capacidad → servidor

Formato de §6.2 de `AGENTS.md`. Esta tabla registra **intención**; la realidad la
da el cliente en cada sesión (§2.3). Antes de afirmar que un servidor está
disponible, compruébalo en el cliente (`/mcp` en Claude Code, lista de
herramientas en IDE) y, si vas a apoyarte en él, llámalo.

`Last verified` = fecha en que se ejecutó una llamada **de solo lectura** contra
ese servidor y respondió. Sin fecha = estaba conectado pero no se llamó.

## Fuentes de datos del repo

| Capability | Server | Use for | Do not use for | Owner | Last verified |
|---|---|---|---|---|---|
| SAP B1 sobre HANA, producción (esquema `EMPAQPLAST_PROD`) | `hana-sap-b1-produccion` | Verificar esquema y datos antes de escribir cualquier consulta de `hana/`; `hana_describe_table`, `hana_search_tables`, `hana_execute_query` | Escrituras, DDL ni `hana_execute_statement` sin aprobación explícita (§5) | — | 2026-11-19 (HANA 2.00.087, usuario EMPAQPLAST, esquema EMPAQPLAST_PROD) |
| SAP B1 sobre HANA, pruebas | `hana-sap-b1-pruebas` | Probar vistas y SP antes de desplegar a producción | Confundir sus datos con los de producción en un reporte | — | — |
| SQL Server interno (base `internaEmpaqplast`) | `sqlserver-etl-local-internaEmpaqplast` | Esquema y consultas de `sqlserver/etl/`, `sqlserver/ops/` | Cargas masivas ni DDL sin aprobación (§5) | — | 2026-11-19 (SQL Server 2022 Express, instancia SRV-APP\SQLEXPRESS) |
| TimeControl (asistencia, timbradas, novedades) | `sqlserver-timecontrol` | Esquema real de `tbl_asistencia`, `tbl_perm_aus`, `viewEmpleados`, catálogos de permisos | Inventar códigos o umbrales: el catálogo se lee del origen | — | **Falló al conectar 2026-11-19** (`CONNECTION_CLOSED`) |
| OnlyControl | `sqlserver-onlycontrol` | Origen de nómina/talento consumido vía linked server `ONLYC` | — | — | **Falló al conectar 2026-11-19** (`CONNECTION_CLOSED`) |
| Base de Talento Humano (`th`) | `sqlserver-etl-local-th` | Destino de `sqlserver/rrhh/ausentismo/ausentismo_2_consumo_en_th.sql` | — | — | **Falló al conectar 2026-11-19** (`CONNECTION_CLOSED`) |
| Dispensario médico | `sqlserver-etl-local-dispensarioMedico` | Consultas del dispensario | — | — | **Falló al conectar 2026-11-19** (`CONNECTION_CLOSED`) |
| PostgreSQL local (base `energia`) | `postgres-local-empaqplast` | Esquema y consultas de eficiencia energética | — | — | 2026-11-19 (PostgreSQL 16.13, base `energia`, 226 MB) |
| PostgreSQL BI en AWS (base `emp_bi`) | `postgres-aws-empaqplast-cloud` | Modelo de BI en la nube; destino de `postgres/` | — | — | 2026-11-19 (PostgreSQL 16.13 en RDS us-east-1, base `emp_bi`, 170 MB) |
| PostgreSQL producción cloud | `postgres-produccion-empaqplast-cloud` | Apps Empaqplast y NPS en producción | Escrituras desde una tarea de desarrollo (§5) | — | — |
| MySQL de nómina (PAC) | `nomina-mysql-pac` | Lectura de nómina para cruces de RRHH | Cualquier escritura: es sistema de nómina | — | — |
| SAP B1 Service Layer | `sap-b1-service-layer-produccion`, `sap-b1-service-layer-pruebas` | Operaciones transaccionales de B1 por API | Reportería: para leer en volumen va HANA directo | — | — |
| Beas Manufacturing (Service Layer BSL) | `service-layer-beas-pruebas` | Órdenes de trabajo, tiempos, calidad en Beas (base de pruebas) | Producción: este servidor apunta a TST | — | — |
| Fracttal (mantenimiento) | `fracttal` | Activos, OT y recursos humanos de mantenimiento; origen de `fracttal/` | Escrituras (crear OT, terceros) sin aprobación explícita (§5) | — | — |
| Power BI (.pbip y modelo local) | `powerbi` | Medidas DAX, páginas y visuales de los tableros de `sqlserver/rrhh/powerbi/` | Publicar al servicio sin aprobación | — | — |

## Orquestación y entorno

| Capability | Server | Use for | Do not use for | Owner | Last verified |
|---|---|---|---|---|---|
| Orquestación de pipelines | `mage`, `mage-cloud` | ETL programado sobre estas fuentes | Disparar ejecuciones a producción sin aprobación (§5) | — | — |
| Automatización de flujos | `n8n-sapdesk` | Alertas y flujos ligados a SAP Desk | Activar/desactivar workflows sin aprobación | — | — |
| Tareas programadas | `scheduled-tasks` | Programar los scripts de `automatizaciones/` | — | — | — |
| Servidores Linux | `linux-ssh-cloud`, `linux-ssh-srv-app-dev`, `linux-ssh-srv-app-suse`, `linux-ssh-srv-app-cloud-jac`, `linux-ssh-kvm`, `linux-ssh-glpi`, `linux-ssh-ocs`, `linux-ssh-zimbra` | Diagnóstico de servicios y logs donde corren estas bases | Reinicios, cambios de servicio o paquetes sin aprobación | — | — |
| Archivos y terminal local | `filesystem`, `terminal` | Leer/escribir dentro del repo y ejecutar `sqlcmd`/Python | Salir de las carpetas del proyecto | — | — |
| OPC UA / planta | `uaexpert-opcua`, `bascula-br15` | Lecturas de planta para eficiencia energética y pesajes | Escrituras a PLC/indicador: §5 lo prohíbe desde una tarea de desarrollo | — | — |
| Red y planta física | `mikrotik`, `hp1950-switch`, `frigate` | Diagnóstico de red y video | Cambios de configuración sin aprobación | — | — |
| Correo y ofimática | `outlook365`, conectores de Gmail, Google Calendar, Google Drive y Notion | Envío de los reportes que ya generan los scripts | Enviar cualquier correo sin aprobación explícita en el mensaje | — | — |
| Catálogo de MCP | `mcp-registry` | Descubrir servidores disponibles | Suponer que lo listado está conectado | — | — |
| Otros conectados, ajenos a este repo | `illustrator`, `ubits`, `scraping-botellas` | — | — | — | — |

## Capacidades que ningún servidor conectado cubre

- **HANA vía `hana-mcp-server-hana-empaqplast`** (el que declara `.mcp.json`): falló al conectar el 2026-11-19 (`CONNECTION_CLOSED`). Se usa `hana-sap-b1-produccion` en su lugar, que da la misma base. Fila marcada como obsoleta, no borrada (§2.3).
- **TimeControl / OnlyControl / th / dispensario**: los cuatro servidores de SQL Server de esos orígenes fallaron el 2026-11-19. Mientras sigan caídos, cualquier consulta de `sqlserver/rrhh/**` se trabaja contra lo documentado en el repo y en `docs/domain/`, **diciéndolo**, y no se afirma nada sobre el esquema vivo de esos orígenes.

## Pendiente de dueño

La columna `Owner` está vacía a propósito: no hay fuente en el repo que diga
quién responde por cada servidor y no se inventa (§1). Rellénala cuando lo
confirmes.
