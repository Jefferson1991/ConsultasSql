# Reorganizar el repo dentro de docs/, por dominio de negocio

- **Date:** 2026-11-19
- **Status:** Implemented
- **Approved by:** Jefferson, en sesión: eligió "Las carpetas completas" y luego "lee las carpetas el contenido y observa que incluso esta por nombre de bdd organiza de acuerdo a las reglas y va mas halla"
- **Scope:** mover `hana/`, `sqlserver/`, `postgres/`, `automatizaciones/`, `fracttal/` y `catalogo-consultas/` dentro de `docs/`, reorganizados por dominio; renombrar a kebab-case; reubicar los 6 `.md` sueltos a `docs/domain/` y `docs/runbooks/`; actualizar `README.md`, `AGENTS.md` §7/§7.1, `docs/INDEX.md`, `docs/mcp-registry.md`, las 4 skills locales de `.agents/skills/`, `guia-consultas.html` y `scripts/graphify.py`.
- **Out of scope:** el **contenido SQL** de las consultas no se toca — ni una línea de lógica; las 3 skills externas (`mssql`, `sap-sqlscript`, `supabase-postgres-best-practices`), porque `skills-lock.json` fija su hash; ninguna escritura a ninguna base de datos; rotar la contraseña encontrada (ver "Questions resolved").

## Problem

El repo está organizado por **nombre de motor** (`hana/`, `sqlserver/`, `postgres/`), que es dónde se ejecuta una consulta, no de qué trata. Leído el contenido de los 69 archivos, eso rompe tres cosas:

1. **Parte las cadenas de trabajo.** Las tres automatizaciones reales cruzan motores y hoy viven en tres carpetas distintas: órdenes de compra (`SB1_VIEW_ORDENES_COMPRA` → vista `OPENQUERY` → `NotificacionOrdenesCompra.py`), stock crítico (`SB1_VIEW_REPORTE_STOCK_CRITICO` → `sp_Stock_Critico_Clientes` → `reporte_stock_critico.py`) y pricing (`extraer-facturas-pricing.sql` → `llenar_plantilla_pricing.py`). Para entender una hay que abrir tres carpetas.
2. **Ya causó un bug real.** `automatizaciones/pricing/llenar_plantilla_pricing.py` resuelve su consulta como `Path(__file__).parent / "extraer-facturas-pricing.sql"`, pero ese archivo está en `hana/ventas/`: el script no encuentra su SQL. Agrupar por dominio lo deja al lado y lo arregla sin tocar código.
3. **El motor no es la pregunta que uno se hace.** Nadie busca "algo en sqlserver"; busca ausentismo, cartera, moldes, pallets. El motor sigue importando para *ejecutar*, así que no se pierde: pasa a los README de cada dominio y a la cabecera de cada archivo, que ya lo declaran.

Además, §6 de `AGENTS.md` ya definía `docs/domain/` y `docs/runbooks/`, y había 6 documentos sueltos que son exactamente eso.

## Decision

Todo pasa a `docs/`, con dos mitades que no se mezclan:

```
docs/
├── INDEX.md, mcp-registry.md
├── adr/ · domain/ · runbooks/ · plans/      ← conocimiento (§6)
├── catalogo/guia-consultas.html             ← navegación
└── consultas/                               ← los archivos ejecutables, por dominio
    ├── activos-fijos/        ├── logistica/
    ├── apps/                 ├── plataforma/
    ├── cartera/              ├── produccion/
    ├── compras/              ├── rrhh/
    ├── eficiencia-energetica/├── supply/
    ├── inventario/           └── ventas/
```

Reglas que se aplican al mover, y que quedan para los pedidos nuevos:

- **Un dominio = una carpeta**, con `README.md` que diga: qué hay, en qué motor y servidor corre cada archivo, en qué orden, y qué depende de qué. El motor deja de ser carpeta y pasa a ser dato.
- **Nombre de archivo:** si el script **crea un objeto de base de datos**, el archivo se llama como el objeto (`SB1_VIEW_NC_CABECERA.sql`), porque así se encuentra desde el error del motor. Si es un reporte o un análisis, kebab-case en español (regla de `README.md`), sin espacios ni mayúsculas sueltas.
- **`_historico/`** para versiones superadas, en vez de `anteriores/`: el guion bajo lo manda al final del listado y deja claro que no se ejecuta.
- **Los `.md` de conocimiento salen de las carpetas de consultas** y van a `docs/domain/` o `docs/runbooks/` según sean regla de negocio o procedimiento.

## Alternatives rejected

- **Mover las carpetas tal cual, conservando `docs/hana/`, `docs/sqlserver/`…** — era la lectura literal del pedido, pero deja el problema intacto: solo cambia el prefijo de la ruta y sigue partiendo las cadenas.
- **Organizar por dominio pero con el motor como subcarpeta** (`cartera/hana/…`) — reintroduce el árbol por motor un nivel más abajo, con carpetas de un solo archivo.
- **Dejar los `.md` junto a sus consultas** — era lo decidido en el plan del bootstrap; se revierte aquí porque §6 ya tenía sitio para ellos y el pedido es ordenar según las reglas.
- **Renombrar también los archivos que crean vistas** — se descartó: el nombre del objeto es la pista que da el motor cuando algo falla.

## Downstream impact

Del índice topológico (`graphify-out/graph.json`, regenerado en esta sesión): 65 nodos y 18 aristas cambian de ruta, **ninguno cambia de contenido**. Las 18 aristas se conservan porque son referencias a objetos de base de datos, no a rutas de archivo. Lo que sí referencia rutas y hay que actualizar:

| Archivo | Qué referencia |
|---|---|
| `README.md` | árbol de carpetas, tablas por motor, reglas de ubicación y nombre, ruta del catálogo |
| `AGENTS.md` §7, §7.1 | mapa de directorios y conteo de archivos |
| `docs/INDEX.md` | los 8 enlaces a documentación dispersa |
| `docs/mcp-registry.md` | rutas citadas en "Use for" |
| `.agents/skills/consultas-sql-empaqplast/SKILL.md` y `referencias/flujo-trabajo.md` | árbol, tabla de ubicación por tipo de pedido, ruta del catálogo |
| `.agents/skills/sap-b1-hana-sql/SKILL.md` y `referencias/performance-tuning.md` | `hana/{dominio}/` y checklist |
| `.agents/skills/sqlserver-tsql-empaqplast/SKILL.md` | `sqlserver/{subcarpeta}/` y checklist |
| `.agents/skills/postgres-sql-empaqplast/SKILL.md` | `postgres/{app\|nps}/` y tabla de archivos |
| `docs/catalogo/guia-consultas.html` | ~40 `path:` de consultas y la lista de carpetas con su conteo |
| `scripts/graphify.py` | `SKIP_DIRS` excluía `docs/` entero, y el motor se deducía del primer segmento de la ruta |

Las 3 skills externas no se tocan: `skills-lock.json` fija el hash de su `SKILL.md`.

## Questions resolved

- ¿Mover la documentación o las carpetas completas? → Las carpetas completas, y organizadas por las reglas, no por motor. → Jefferson, en esta sesión.
- ¿El motor deja de ser visible? → No: pasa al `README.md` de cada dominio y sigue en la cabecera de cada script. → Decisión de este plan.
- ¿Se arregla la contraseña en claro de `hana/ia/creacion_usuario_ia_bdd.sql`? → **No en este trabajo.** El archivo tiene `CREATE USER USR_IA PASSWORD "<literal>"`, que §5 prohíbe, y ya está en el historial de git: borrarlo del archivo no lo saca del historial y da falsa tranquilidad. Lo correcto es rotar la contraseña de `USR_IA` en HANA y recién entonces reemplazar el literal por una variable. Queda señalado, sin tocar, para decisión de Jefferson.

## Verification

```
python scripts/graphify.py            # 65 nodos y 18 aristas, con las rutas nuevas
git status --short                    # solo R (renames), ninguna M en archivos .sql
git diff --cached --stat -M           # los .sql movidos no deben sumar lineas modificadas
grep -rn "hana/\|sqlserver/\|postgres/\|automatizaciones/" --include=*.md --include=*.html .
```

Pasa si: el grafo mantiene 65 nodos / 18 aristas / 0 ciclos con rutas bajo `docs/consultas/`; git registra los `.sql` como renombrados sin cambios de contenido; y el grep no devuelve rutas viejas fuera de `docs/plans/` (los planes son registro histórico y no se reescriben).

## Outcome

Implementado el 2026-11-19. Resultado verificado: **76 renames, 0 cambios de contenido** en `.sql` y `.py`; el grafo mantiene 65 nodos, 18 aristas y 0 ciclos con las rutas nuevas; el catálogo HTML quedó con sus 37 fichas apuntando a `docs/`.

Qué quedó, además del movimiento:

- **13 `README.md` nuevos**: uno por dominio más el índice `docs/consultas/README.md`. Ahí vive ahora el motor, el servidor, la base y el orden de despliegue de cada archivo — el dato que antes daba la carpeta.
- **`scripts/graphify.py` aprende dominio y motor.** `docs/` dejó de estar excluido; el nodo ahora trae `domain` (de la ruta) y `engine` **deducido del contenido** con precedencia explícita y `engine_evidence`, porque un dominio mezcla motores. Los 65 archivos quedaron clasificados, ninguno como `desconocido`.
- **Tres cadenas quedaron juntas**: compras, supply y pricing, cada una con su README explicando el flujo y el orden de despliegue.

Desviaciones y hallazgos durante la ejecución:

- **16 archivos no se pudieron mover al primer intento**: el índice de git los tenía como `hana/Administracion/`, `hana/Cartera/`, `hana/IA/` e `hana/Inventario/`, con mayúscula, mientras Windows mostraba minúscula. Es un desajuste **previo** a este trabajo, que la reorganización dejó al descubierto y resolvió al reescribir esas rutas.
- **Tres fichas del catálogo HTML ya estaban rotas antes**: apuntaban a `sqlserver/rrhh/<archivo>` sin la subcarpeta real. Se corrigieron de paso.
- `docs/adr/` y `docs/integrations/` siguen sin existir: no hay contenido real que poner.

Pendientes que este trabajo deja abiertos:

- **La contraseña en claro de `docs/consultas/plataforma/ops/creacion-usuario-ia.sql` sigue ahí y sin rotar.** Está señalada en el README de `plataforma/` con el orden correcto: rotar en HANA primero, después tocar el archivo.
- Tres objetos tienen dos definiciones cada uno (`SB1_VIEW_REVISION_STOCK_V2`, `SB1_VIEW_REPORTE_STOCK_CRITICO`, `vm_atrasos`). Quedan señalados en el README de su dominio, no resueltos: hay que comparar contra lo vivo en cada motor.
- `docs/domain/ausentismo.md` sigue sin escribirse.
