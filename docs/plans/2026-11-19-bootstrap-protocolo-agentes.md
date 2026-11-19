# Bootstrap del protocolo AGENTS.md en el repo de consultas

- **Date:** 2026-11-19
- **Status:** Implemented
- **Approved by:** Jefferson, mensaje "Ejecuta esto" con AGENTS.md adjunto (sesión Claude Code 2026-11-19)
- **Scope:** `docs/INDEX.md`, `docs/plans/2026-11-19-bootstrap-protocolo-agentes.md`, `docs/mcp-registry.md`, `scripts/graphify.py`, `graphify-out/graph.json`, `graphify-out/HOW_TO_REGENERATE.md`, `.gitignore`, secciones 7 y 7.1 de `AGENTS.md`
  - *Enmienda del 2026-11-19:* el generador quedó en `scripts/graphify.py`, no dentro de `graphify-out/` como decía la primera versión de este plan. Razón: §5 prohíbe editar a mano cualquier cosa bajo `graphify-out/`, y §2.2 nombra `scripts/graphify.*` como el lugar donde la próxima sesión lo buscará. Se añadió también §7.1 al alcance: estaba con el árbol genérico de la plantilla (`src/`, `tests/`), que no existe en este repo.
- **Out of scope:** ninguna consulta SQL, vista, procedimiento ni script Python existente; ninguna escritura a HANA, SQL Server, PostgreSQL, Fracttal ni Power BI; ningún commit.

## Problem

`AGENTS.md` entró al repo sin ejecutarse (archivo sin seguimiento en git al inicio de la sesión). El bootstrap de §2 no existe:

- No hay `docs/` → §2.1 sin base de conocimiento, §6 sin destino para lo que se aprende en sesión.
- No hay `graphify-out/` → §2.2 obliga a construirlo; sin él, el razonamiento topológico (§3.2) se haría a ciegas con grep.
- No hay `docs/mcp-registry.md` → §2.3 sin mapa capacidad → servidor, en un repo cuyo trabajo real pasa casi todo por MCP.
- §7 en blanco → cada sesión vuelve a deducir el stack desde cero.

## Decision

Ejecutar el bootstrap completo en una pasada, sin tocar consultas:

1. `docs/INDEX.md` construido desde lo que realmente existe bajo `docs/` más punteros a la documentación ya dispersa en el repo (`hana/ventas/notas-credito/README.md`, `sqlserver/rrhh/ausentismo/LEEME.md`, etc.).
2. Índice topológico derivado por agente: un parser propio de SQL/Python que extrae objetos creados y objetos referenciados. El repo no tiene `package.json`, `pyproject.toml` ni `Makefile`, y `madge`/`dependency-cruiser`/`pydeps` no aplican a un repo de 69 `.sql`; por eso se toma el escalón 4 de la escalera de §2.2 con `"generator": "agent-derived"`.
3. `docs/mcp-registry.md` con los servidores **realmente conectados en este cliente**, no los que declara `.mcp.json`, y con `Last verified` solo donde se ejecutó una llamada de solo lectura en esta sesión.
4. Rellenar §7 de `AGENTS.md` con lo verificado por lectura del repo.
5. `graphify-out/` al `.gitignore`: es índice generado y §7 fija `Commit generated indexes?: no`.

## Alternatives rejected

- **Instalar un generador de grafos (madge, dependency-cruiser, pydeps)** — ninguno entiende dependencias entre vistas SQL, que es el 95% del repo; además §3.1 prohíbe introducir dependencias nuevas sin pedirlo.
- **Saltar §2.2 y declarar el índice "no aplicable"** — §2.2 dice explícitamente que debe existir y prohíbe seguir solo con grep.
- **Copiar `.mcp.json` al registry** — `.mcp.json` lleva credenciales en `env` y declara intención, no realidad; §2.3 y §5 lo descartan.
- **Commitear `graphify-out/`** — es artefacto regenerable; se ignora en git.

## Downstream impact

Del §3.2 (índice derivado en esta misma sesión): **ninguna** consulta, vista, procedimiento, script Python ni objeto de base de datos cambia. Los archivos nuevos (`docs/**`, `graphify-out/**`) no son referenciados por ningún `.sql` ni `.py` del repo. Lo único que cambia de comportamiento es el arranque de las sesiones de agente futuras, por `AGENTS.md` §7 y `docs/INDEX.md`.

## Questions resolved

- ¿Hay `docs/` o `graphify-out/` previos? → No; `docs/` no existía y `graphify-out/` tampoco (verificado con `ls` en el working tree). → Verificado en sesión.
- ¿Qué generador de grafos usa el repo? → Ninguno; no hay `package.json`, `pyproject.toml`, `Makefile` ni `scripts/graphify.*`. → Verificado en sesión.
- ¿Qué servidores MCP están conectados de verdad? → Los del inventario de §2.3 de este plan, registrados en `docs/mcp-registry.md`; cinco servidores declarados en `.mcp.json` fallaron al conectar. → Verificado en sesión.

## Verification

```
python scripts/graphify.py --check     # esperado: "sin cambios"
git check-ignore -v graphify-out/graph.json    # esperado: lo ignora por graphify-out/*
git status --short --ignored graphify-out/     # esperado: graph.json como !!, HOW_TO_REGENERATE.md no ignorado
```

Pasa si: `graph.json` es JSON válido con `generator == "agent-derived"`, el conteo de nodos iguala el de archivos `.sql`/`.py` fuera de `.agents/` **y de `scripts/`** (65 = 62 `.sql` + 3 `.py` de `automatizaciones/`; el propio `scripts/graphify.py` no se indexa a sí mismo), `--check` dice "sin cambios", y `docs/INDEX.md` lista exactamente los archivos presentes bajo `docs/`.

Resultado ejecutado el 2026-11-19: `python scripts/graphify.py` → 65 nodos, 18 aristas, 58 objetos creados, 157 referencias externas, 56 entrypoints, 0 ciclos. `--check` → "sin cambios". `git status --short --ignored graphify-out/` → `graph.json` ignorado, `HOW_TO_REGENERATE.md` versionable.

## Outcome

Implementado el 2026-11-19. Qué quedó:

- `docs/INDEX.md`, `docs/mcp-registry.md` y este plan; `docs/domain/`, `docs/adr/`, `docs/integrations/` y `docs/runbooks/` **no** se crearon vacías: `INDEX.md` las anota como pendientes con su primer candidato, porque una carpeta vacía no se versiona en git y una carpeta con un README de relleno finge conocimiento que no existe.
- `scripts/graphify.py` + `graphify-out/graph.json` + `graphify-out/HOW_TO_REGENERATE.md`.
- §7 y §7.1 de `AGENTS.md` rellenas con lo verificado; `Graph generation command` queda fijado, así que la próxima sesión toma el escalón 2 de la escalera de §2.2 y no vuelve a derivar nada.
- `.gitignore`: `graphify-out/*` con `!graphify-out/HOW_TO_REGENERATE.md`.

Desviaciones frente al plan, además de la enmienda de alcance anotada arriba:

- El generador se corrigió cuatro veces durante la verificación, al leer su salida: las CTE aparecían como referencias externas; los `from email.mime.base import X` de Python entraban como `FROM` de SQL; dos literales contiguos (`msg["From"] = user`) se leían como `FROM user`; y el SP que `automatizaciones/stock-critico/` ejecuta por f-string (`EXEC {SP_NOMBRE}`) no se resolvía. Las referencias externas bajaron de 196 a 157 y aparecieron las 2 aristas que conectan los scripts Python con su SQL. El grafo nunca se tocó a mano (§5).
- Ningún commit: §5 prohíbe commitear directo a `master` y no se pidió rama.

Pendientes que este trabajo deja abiertos, no resueltos:

- `docs/mcp-registry.md` tiene la columna `Owner` vacía: no hay fuente en el repo que diga quién responde por cada servidor.
- Los cuatro servidores MCP de SQL Server de RRHH (`sqlserver-timecontrol`, `sqlserver-onlycontrol`, `sqlserver-etl-local-th`, `sqlserver-etl-local-dispensarioMedico`) y `hana-mcp-server-hana-empaqplast` fallaron al conectar: mientras sigan caídos, nada sobre el esquema vivo de TimeControl/OnlyControl se puede afirmar en esta sesión.
- La primera `docs/domain/ausentismo.md` sigue sin escribirse: la regla `En_Nomina` por periodo y el catálogo de tipos de permiso viven hoy solo en los scripts.
