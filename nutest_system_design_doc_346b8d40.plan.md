---
name: Nutest System Design Doc
overview: Author a single comprehensive `SYSTEM_DESIGN.md` at the workspace root that covers the Nutanix testing framework end-to-end — architecture, process model, lifecycle, configuration, resource/interface/entity model, logging/results, extension points — followed by a deep walkthrough of one V4 Recovery Plan test and one PD-to-EC Migration test, plus an interview-ready trade-offs/Q&A section.
todos:
  - id: scaffold
    content: Scaffold `SYSTEM_DESIGN.md` with the 17 sections and TOC
    status: completed
  - id: arch_diagrams
    content: "Author sections 1-4: exec summary, high-level architecture, process model, CLI surface (with mermaid process tree)"
    status: completed
  - id: loader_config
    content: "Author sections 5-6: test discovery/loading and config cascade with concrete code references and a waterfall diagram"
    status: completed
  - id: lifecycle
    content: "Author section 7: test lifecycle state machine with mermaid diagram and success/failure maps"
    status: completed
  - id: resource_model
    content: "Author sections 8-9: resource/interface/entity/component model and NuTest/NOSTest base classes"
    status: completed
  - id: logging_results
    content: "Author sections 10-12: NuLog, results/reporting, exception model"
    status: completed
  - id: extension
    content: "Author section 13: extension points (resources, pre/post-runs, decorators, callbacks)"
    status: completed
  - id: v4_deep_dive
    content: "Author section 14: V4 Recovery Plan APIs heavy walkthrough including tag resolution, RPJ action sequence, validators, and failure-mode debugging"
    status: completed
  - id: pdtoec_deep_dive
    content: "Author section 15: PD-to-EC Migration heavy walkthrough including pd_map placeholder resolution and convert_protection_domains flow"
    status: completed
  - id: tradeoffs_glossary
    content: "Author sections 16-17: trade-offs Q&A bait and glossary"
    status: completed
  - id: verify_links
    content: "Read-back pass: verify every file path / symbol reference resolves to an actual file, fix any drift"
    status: completed
isProject: false
---

## Nutanix Testing Framework — System Design Doc

### Output

- Single file: `SYSTEM_DESIGN.md` at workspace root (alongside the existing `NuTest_Automation_Complete_Guide.md`, which I will not modify).
- Top-down structure, interviewer-pitch style: architecture first → subsystem deep dives → worked examples → trade-offs.
- Heavy coverage of both example tests as the final third of the doc.
- Mermaid diagrams (process tree, lifecycle state machine, config cascade, resource model, RPJ action sequence).
- Cite real symbols/files via file:line links so it's defensible in an interview.

### Doc skeleton (sections to author)

1. **Executive summary** — what NuTest is, who uses it, in 5 bullets.
2. **High-level architecture** — process tree + responsibilities table.
3. **Process model & IPC** — multi-process design, Bottle webserver subprocess, TinyDB shared state, why this over threads/queues.
4. **CLI surface (`nutest run`, `find`, `clusters`, `lint`, `install`)** — argparse layout from [bin/nutest](nutest-py3/bin/nutest) + [framework/test_driver/nutest_client.py](nutest-py3/framework/test_driver/nutest_client.py).
5. **Test discovery & loading** — `NuTestLoader` walks `testcases/`, supports dotted prefixes, tags, test sets (`.lst` YAML), class/test variations (`~~~`, `___` delimiters), parallel metadata extraction.
6. **Configuration cascade** — global → package `config.json` → class → test → CLI `-a key=val` → `--test_args_file`; Jinja2 resource-spec templates; class/test variation resolution in [framework/test_driver/nutest_config_parser.py](nutest-py3/framework/test_driver/nutest_config_parser.py).
7. **Test lifecycle (state machine)** — `Initializer → class_pre_run → class_setup → tests (non-destructive batches + destructive serial) → class_teardown → class_post_run` and per-test `pre_run → setup → test_body → teardown → post_run → log_normalization`; `success_map`/`failure_map`; `TimedExecutor` per stage; abort-on-failure semantics.
8. **Resource & interface model** — `Resource` factory ([framework/resources/resource.py](nutest-py3/framework/resources/resource.py)), `ResourceType` enum, `Interface` enum (REST/ACLI/NCLI/RPC/SDK/…), entities under `framework/entities/*`, components under `framework/components/*` (Cerebro, Magneto, GoMagneto, Cassandra, …), hypervisors (AHV/ESX/HyperV), Jarvis/RDM metadata sourcing.
9. **Base test classes** — `NuTest` ([framework/lib/test/nutest.py](nutest-py3/framework/lib/test/nutest.py)) → `NOSTest` ([framework/lib/test/nos_test.py](nutest-py3/framework/lib/test/nos_test.py)); `DEFAULT_RESOURCE_SPEC`; `get_resources_by_type/_name/_tag`; per-class shared state vs per-test state; `result`/`set_param`/`register_callback`/`invoke_callback`.
10. **Logging (NuLog)** — custom levels `STAGE`/`STEP`/`TRACE`, hierarchical per-process per-test log dirs, log file redirect contexts, timed/sized rotation, log_normalization stage.
11. **Results & reporting** — `NuTestResult` states (PENDING/RUNNING/PASSED/FAILED/WARNING/SKIPPED/TIMEDOUT/ERROR/ABORTED/KILLED), `NuTestStage` enum, TinyDB-backed `NutestDB`, Bottle webserver REST endpoints, generated `results.json` + `index.html` HTML report, coverage HTML/XML.
12. **Exception model** — `NuTestError` hierarchy + `__new__` enforcement, `ErrorCategory`, exception collectors, `ExceptionDecoder` active-state dumps, Logbay auto-collection on failure, IAM diagnoser hooks.
13. **Extension points** — adding a new `ResourceType`, custom pre/post-runs via config `name: <fqn>` + `stage: CLASS_PRERUN/TEST_PRERUN/...`, registering callbacks via webserver, custom interfaces, decorators (`@readonly`, `@manual`, `@retry`, `@profile`, `@access_control`).
14. **Deep dive A — V4 Recovery Plan APIs test** (heavy):
    - File: [test_v4_recovery_plan_apis.py](nutest-py3-tests/testcases/dr/draas/entity_protection_recovery/v4_runbook_apis/test_v4_recovery_plan_apis.py).
    - Walk through `class_setup` → `setup` (DrSites, DrWorkflow, RBAC users) → one test method body → `teardown`.
    - Show how [workflow.py](nutest-py3-tests/workflows/draas3/workflow.py) (`DrWorkflow.setup`/`create_entities`/`process_protection_policies`/`create_recovery_plans`) orchestrates entities.
    - Tag resolution: `#VM1`, `#CAT_CAT1_VAL1`, `$SELF_AZ` via `DrConfig` + `SpecHelper`.
    - RPJ action sequence (VALIDATE → PFO → FAILBACK → TFO → CLEANUP → FAILOVER), per-action `shouldIgnoreWarnings`, validators (`recovery_plan_job_validator`, `protection_policy_validator`).
    - How `config.json` test_args override merges with class-level `entities` dict.
    - Show the failure-mode debugging workflow (lift from the `.cursor/rules/draas-test-debugging.mdc` rule that's already in this workspace).
15. **Deep dive B — PD-to-EC Migration test** (heavy):
    - File: [test_pdtoec.py](nutest-py3-tests/testcases/dr/draas/pd_to_ec_migration/test_pdtoec.py).
    - Setup creates legacy PDs (via `pdtoec_util.setup_pdtoec_entities`) on PE + EC entities (categories/PPs) on PC.
    - Dryrun (precheck) then actual `convert_protection_domains(dryrun='true'/'false')`.
    - Post-migration verification: original PD empty on PE; categories/PPs/RPs created on PC.
    - Pd_map tag/placeholder resolution (`$LARGE_PD_NAME`, `$VG_UUIDS`, `$FILES`, `remote_cluster_*`).
    - Teardown order and `_draas_wo.teardown(full_cleanup=…)` + `pdtoec_util.teardown_pdtoec_entities`.
16. **Cross-cutting trade-offs (interview Q&A bait)**:
    - Why multi-process per class instead of threads? (memory isolation, signal handling, coverage subprocess support).
    - Why HTTP + TinyDB instead of `multiprocessing.Queue`? (callbacks across machines, REST UI, language-agnostic).
    - Config cascade vs pytest fixtures — pros/cons.
    - Tag-based entity registry (`#VM1`) vs raw object references — pros/cons.
    - Per-stage timeout via `signal.SIGALRM` — limitations on Windows, fallback `WinAlarm` thread.
    - Non-destructive batching for parallel speedup; destructive serial.
    - Variations (`~~~`/`___`) vs parameterized tests.
17. **Glossary / quick reference** — table of acronyms (PD, PP, RP, RPJ, PE, PC, EC, DRaaS, NuLog, NCC, Logbay, Jarvis, RDM) and one-liner pointers to source files.

### Diagrams (mermaid)

- Process tree: `nutest CLI → NuTestClient → NuTestScheduler → [Bottle webserver subprocess] + per-class NuTestClassRunner → per-test NuTestTestRunner`.
- Test stage state machine with `success_map`/`failure_map` transitions.
- Config-cascade waterfall (global → package → class → test → CLI → test_args_file).
- Resource creation flow (CLI `-r NOS_CLUSTER:foo` → Jarvis metadata → `Resource` factory → typed `NOSCluster`).
- Entity registry / tag resolution (`config.json` entities[] → `DrConfig` → tag tokens → `SpecHelper.resolve` → real entity objects).
- V4 RPJ action sequence and validator checkpoints.

### What I will NOT do

- Will not modify existing docs, configs, or any code.
- Will not invent APIs — every cited symbol/file will be from the actual repos.
- Will not include emojis (per workspace tone guidance).
- Will not include markdown tables in the plan itself (per plan-mode rule) — but the final `SYSTEM_DESIGN.md` may use tables freely.