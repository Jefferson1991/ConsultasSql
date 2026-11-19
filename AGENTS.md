# AGENTS.md — Engineering Agent Protocol

## 0. Scope and precedence

This file governs any AI agent operating in this repository (Claude Code, Cursor, Copilot, Windsurf, Continue, Roo, web interfaces). Read it fully before the first file edit of a session.

When instructions conflict, this is the order:

1. The user's explicit instruction in the current message
2. This file
3. Tool/IDE defaults and model habits

If the user's request conflicts with a rule here, follow the user and state in one line which rule you are setting aside. Never override silently.

---

## 1. Operating principles

**Cite, don't assume.** Every claim about a business rule, schema relationship, or API contract must point to a source: `path/to/file.ts:42`, a table name, an ADR ID, or a named MCP call. If no source exists, say "not found" and ask. A plausible-sounding answer with no source is a failure, not a partial success.

**Smallest correct change.** Touch only what the task requires. No opportunistic refactors, renames, reformatting, or dependency upgrades bundled into an unrelated change.

**Read before write.** Never edit a file you have not read in this session.

**Degrade honestly.** If an index, document, or server named below is missing or stale, say so and follow the stated fallback. Never simulate having consulted a source.

**Knowledge that is not written down does not exist.** Anything learned in conversation — a business rule, a correction, a constraint — is lost at the end of the session unless it lands in `docs/`. Writing it is part of the task, not an extra.

---

## 2. Session bootstrap

Do this once per session, before the first substantive answer. Report the result in one or two lines — this replaces any compliance badge, because it is verifiable.

### 2.1 Knowledge base

Read `docs/INDEX.md` first. It is the one-screen map of everything in §6. If it does not exist, create it from what is actually under `docs/` and say so.

### 2.2 Topology index — build it if missing

`graphify-out/` is the machine-readable dependency index. **It must exist.** If it is absent, or stale (older than the latest commit touching the files in scope), regenerate it before doing topological reasoning. Do not silently skip it, and do not proceed on grep alone.

Regeneration ladder — take the first option that works:

1. The **graph generation command** in §7, if filled.
2. An obvious repo script: `npm run graph*`, a `Makefile` target, `scripts/graphify.*`.
3. A language-appropriate generator present in the environment (for example `madge` or `dependency-cruiser` for JS/TS, `pydeps` or `import-linter` for Python, an analyzer for .NET). Name which one you chose.
4. Nothing available: derive a minimal `graphify-out/graph.json` yourself by parsing imports/usings/requires across the source tree, and set `"generator": "agent-derived"` inside it so it is never mistaken for tool output.

Whatever path you take:

- Write or update `graphify-out/HOW_TO_REGENERATE.md` with the exact command, tool version, and date. The next session must not have to rediscover this.
- Minimum contents of the index: file/module nodes, import edges, exported public surface, entrypoints and their reachable set, and flagged cycles.
- Never hand-edit a generated graph to make it agree with you. If the graph contradicts your assumption, the graph wins until a file read proves otherwise.
- Commit `graphify-out/` only if §7 says this repo commits generated indexes; otherwise confirm it is in `.gitignore`.

### 2.3 MCP inventory

- Enumerate the MCP servers **actually connected in this client** (the mechanism varies: `/mcp` in Claude Code, the tool list in an IDE or API session). `docs/mcp-registry.md` records intent; the client records reality. Never claim a server is available because the registry lists it.
- In your first substantive response, state in one line which connected servers are relevant to this task and which you will use.
- If the task needs a capability no connected server provides, say so, name what would provide it, and continue with the fallback. Do not fabricate a result that an MCP would have returned.
- **Fact precedence:** connected MCP querying the authoritative system > files in this repo > web search > model memory. Never answer from memory about live state (schemas, current configuration, running versions, actual data) when an MCP can be queried.
- Read-only MCP calls need no approval. Any MCP call that writes, sends, posts, or mutates an external system requires explicit approval in the current message — see §5.
- If a connected server is missing from `docs/mcp-registry.md`, add a row. If a registry row points at a server that is gone, mark it stale rather than deleting it.

---

## 3. Work sequence

Run in order. Skip a step only when the task is trivially local (a typo, a single-line fix) — and say that you skipped it.

### 3.1 Context

- Determine the stack from §7. If §7 is blank, derive it from `package.json`, `*.csproj`, `pyproject.toml`, `requirements.txt`, lockfiles, and root config. Never invent a stack.
- Do not introduce a new runtime dependency, framework, or architectural pattern unless explicitly requested. If one seems necessary, propose it separately: what it adds, and the alternative you rejected.

### 3.2 Topology

- Query the index from §2.2 to identify callers, callees, and the public surface of what you are touching. State which method produced the index you used.
- Before finishing, list the downstream files, exported symbols, DB objects, or endpoints your change affects. If that list is empty, say so explicitly — it is a claim, not an omission.

### 3.3 Domain

- Check `docs/domain/`, `docs/adr/`, `docs/integrations/`, and any linked vault for the invariants covering the touched area.
- **Stop and ask** when: business rules are ambiguous or contradictory; the change alters transaction boundaries, posting logic, pricing, inventory movements, or anything with financial or audit effect; the change touches an ERP / PLC / OPC UA integration contract; or correct behavior depends on production data you cannot see.
- Every answer you receive to such a question gets written to `docs/` under §6 before the task closes.

---

## 4. Approved plans must be documented

**Hard gate.** Once the user approves a plan, write it to `docs/plans/YYYY-MM-DD-<slug>.md` **before the first file edit**. No code, no migration script, no MCP write until that file exists and its path is named in your response.

This applies to any plan with more than one step or more than one file — including plans agreed verbally in chat, and including plans you proposed that the user simply said "yes" to.

Template:

```markdown
# <Title>

- **Date:** YYYY-MM-DD
- **Status:** Approved | In progress | Implemented | Superseded by <plan> | Abandoned
- **Approved by:** <name>, <session or message reference>
- **Scope:** files, modules, tables, endpoints in scope
- **Out of scope:** what this explicitly does not touch

## Problem
## Decision
## Alternatives rejected
One line each, with why.
## Downstream impact
From §3.2, by path.
## Questions resolved
Question → answer → who answered.
## Verification
Commands, and what a passing result looks like.
## Outcome
Filled at completion: what shipped, what deviated from the plan and why, commit references.
```

Rules around it:

- If implementation diverges from the plan, amend the plan document in the same turn. Silent drift is a protocol violation.
- Update `Status` and `Outcome` when the work finishes, fails, or is abandoned. A plan left at "In progress" forever is worse than no plan.
- If the plan establishes a durable architectural decision, also write `docs/adr/NNNN-<slug>.md` and cross-link the two.
- Plans are append-only in spirit: supersede, do not overwrite history.

---

## 5. Prohibitions

No exceptions without explicit user approval in the current session.

- No file edits before the approved plan document exists (§4).
- No MCP call that writes to, sends to, or mutates an external system without explicit approval in the current message.
- No schema migrations, `DROP`, `TRUNCATE`, bulk `UPDATE`/`DELETE`, or data backfills — propose the script, do not run it.
- No writes to production systems, ERP endpoints, or message brokers from a development task.
- No deleting, skipping, or weakening a test to make a suite pass.
- No secrets, connection strings, tokens, or real customer/personnel data in source, commits, logs, fixtures, examples, or documentation. Use environment variables and synthetic data.
- No `git push --force`, history rewrites, branch deletion, or direct commits to `main`/`master`.
- No hand-editing anything under `graphify-out/`.
- No code paths that silently return mock or hardcoded data outside of tests.
- No truncating files with `...` when writing them. If output is too long, write it in named sections across turns and say so.

---

## 6. Knowledge base

Layout under `docs/`:

| Path | Holds |
|---|---|
| `docs/INDEX.md` | One-screen map of everything below. Update it whenever you add a file. |
| `docs/plans/YYYY-MM-DD-<slug>.md` | Approved plans (§4). |
| `docs/adr/NNNN-<slug>.md` | Architecture decisions: context, decision, consequences, status. |
| `docs/domain/<area>.md` | Business rules, invariants, glossary of internal terms and codes. |
| `docs/integrations/<system>.md` | Contracts for ERP, OPC UA, and external systems: endpoints, payloads, failure modes, owner. |
| `docs/mcp-registry.md` | Capability → server map (§2.3). |
| `docs/runbooks/<task>.md` | Operational procedures. |
| `graphify-out/` | Generated topology. Read-only. |

### 6.1 Capture duty

- When the user answers a §3.3 question, corrects a business rule, or tells you something about a system that is not in the repository: write it to the right file **in the same task**, and name the file in your response.
- Do not ask permission to record a fact the user just stated. Do ask before recording something you inferred, and label it as inferred.
- Write facts, not transcripts. One line per rule, with the date and who stated it.
- If the rule already exists, update it in place and note what changed. Do not create a second version of the same truth.

### 6.2 `docs/mcp-registry.md` format

```markdown
| Capability | Server | Use for | Do not use for | Owner | Last verified |
|---|---|---|---|---|---|
```

---

## 7. Project context

*Maintainer: fill in per repository. Leave a line blank rather than guessing — a blank line means "discover from the repo."*

*Relleno el 2026-11-19 a partir de lectura del repo y del índice topológico. Lo que dice "ninguno" se comprobó ausente, no se omitió.*

- **Languages:** SQL (HANA SQLScript, T-SQL, PL/pgSQL) en 62 archivos; Python 3 en 3 scripts de `automatizaciones/`. Sin compilación.
- **Frameworks:** ninguno. Los scripts usan librería estándar más `hdbcli`, `openpyxl`, `xlsxwriter` y `sqlcmd` como subproceso. No hay `package.json`, `pyproject.toml`, `requirements.txt` en la raíz ni `Makefile`.
- **Databases:** SAP B1 sobre HANA (esquema `EMPAQPLAST_PROD`, HANA 2.00.087); SQL Server 2022 Express (`internaEmpaqplast`, `AlertasB1`, `TH` en `SRV-APP\SQLEXPRESS`) y SQL Server 2008 R2 (`TCONTROL` en `SRV-BIOM-001`); PostgreSQL 16 (`energia` local, `emp_bi` en RDS); MySQL de nómina (PAC).
- **Architecture pattern:** repositorio de consultas organizado por motor, no aplicación. La dependencia real son objetos de base de datos, no imports. Patrón de alertas: vista `SB1_VIEW_*` en HANA → vista `OPENQUERY` en SQL Server → script Python que envía correo/Excel.
- **Inter-service communication:** linked servers (`HANAODBC` hacia HANA, `ONLYC` hacia OnlyControl, `EMP_NOM` hacia nómina) con el `WHERE` **dentro** del `OPENQUERY`; `sqlcmd` desde Python; servidores MCP para consultar esquema y datos en vivo.
- **Lint/format authority:** ninguno. No hay archivo de configuración de lint ni formato en el repo; manda la sección "Convenciones técnicas" de `README.md`.
- **Test command:** ninguno. No hay `tests/` ni suite. La verificación de una consulta es ejecutarla contra el origen por MCP y comparar el resultado con lo que se afirma.
- **Build command:** ninguno. No hay artefacto que construir; los `.sql` se despliegan ejecutándolos en su motor.
- **Graph generation command:** `python scripts/graphify.py` (`--check` para comprobar si está desactualizado sin escribir).
- **Commit generated indexes?:** no — `graphify-out/*` está en `.gitignore`, excepto `HOW_TO_REGENERATE.md`, que sí se versiona.
- **Branch / commit convention:** el historial de `master` usa un mensaje por pedido, una frase descriptiva en español, sin prefijo de tipo ni número de ticket. §5 prohíbe commitear directo a `master`: trabaja en una rama por pedido y deja el merge al mantenedor.

### 7.1 Directory map

- `hana/` — SAP B1 sobre HANA, por área: `administracion/`, `cartera/`, `compras/`, `eficiencia-energetica/`, `inventario/`, `logistica/`, `produccion/`, `supply/`, `validaciones/`, `ventas/`, `ops/`, `ia/`
- `sqlserver/` — `alertas-b1/` (vistas `OPENQUERY`), `rrhh/` (ausentismo, atrasos, Power BI, mantenimiento, `anteriores/` = versiones superadas), `etl/`, `supply/`, `ops/`
- `postgres/` — `app/` (auth y DDL de infraestructura), `nps/` (campañas)
- `automatizaciones/` — scripts Python por asunto (`ordenes-compra/`, `pricing/`, `stock-critico/`); van junto a las consultas de su origen
- `fracttal/` — exportes de mantenimiento (xlsx)
- `catalogo-consultas/` — guía HTML del inventario
- `.agents/skills/` — skills del proyecto por motor; externas fijadas en `skills-lock.json`
- `scripts/` — utilitarios del repo: `graphify.py` genera el índice topológico
- `graphify-out/` — índice de dependencias generado (solo lectura, §5)
- `docs/` — base de conocimiento (§6); empieza por `docs/INDEX.md`
- No hay `src/`, `app/` ni `tests/`: este repo no es una aplicación

---

## 8. Response format

Do not open with a compliance badge or a restatement of this protocol. Start with the substance.

For any change touching more than one file, or altering behavior:

**Sources & tools** — one line: which MCP servers you used, how the topology index was obtained (existing / regenerated / agent-derived), which `docs/` files you read.

**Impact** — 2–4 sentences: what changes, which modules and tables, what downstream is affected (§3.2), named by path.

**Open questions** — only if §3.3 triggered a stop. Batch them: ask up to three at once, then wait.

**Plan** — path to the plan document from §4.

**Change** — complete files or unified diffs, each preceded by its path. Typed, with error handling on I/O and external calls, matching the lint authority in §7.

**Knowledge written** — paths of the `docs/` files you created or updated this task, one line each.

**Verification** — the exact command(s) to validate, and what a passing result looks like. If you ran them, give the result. If you could not, say so.

For questions, reviews, and explanations: answer in prose. No template.

---

## 9. Self-check before responding

- Every factual claim about this codebase or its systems traces to a file read, an index entry, or an MCP call made this session.
- Nothing in §5 was done.
- The approved plan document exists, and its path appears in the response.
- New knowledge from this session is written under `docs/`, not only in the chat.
- Every MCP server you named as used was actually connected and actually called.
- The downstream list from §3.2 is stated, even if empty.
- Untested code is labeled untested.
- Anything guessed is marked as a guess in the response itself — not buried in a code comment.
