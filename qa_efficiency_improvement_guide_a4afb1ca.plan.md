---
name: QA Efficiency Improvement Guide
overview: Comprehensive recommendations for improving QA automation efficiency, including better interactive testing workflows, framework testing approaches, and productivity best practices.
todos:
  - id: improve-ipython-workflow
    content: "Improve iPython workflow: Create modular setup_session.py, use auto-reload, configure %store for persistence"
    status: completed
  - id: create-entity-templates
    content: Create reusable entity template JSON files in scripts/entity_templates/
    status: completed
  - id: add-framework-unit-test
    content: When testing framework code, add unit tests following pattern in nutest-py3/framework/unittests/
    status: completed
  - id: setup-shell-aliases
    content: Create shell aliases for common nutest commands
    status: completed
  - id: create-quick-setup-function
    content: Add quick_setup() function to setup_session.py for one-liner DR environment setup
    status: completed
isProject: false
---

# QA Efficiency Improvement Guide

## Q1: Better Interactive Testing Workflow

Your current approach with `test.py` + iPython + tmux is valid but can be significantly optimized:

### Current Workflow Issues

- Manual copy-paste from `test.py` to iPython is slow and error-prone
- No state persistence between sessions
- Entity specs embedded directly in test.py become messy

### Recommended Improvements

#### 1. Use IPython Magic Commands for Auto-Reload

Instead of restarting iPython when you modify code, use auto-reload:

```python
%load_ext autoreload
%autoreload 2  # Automatically reload all modules before executing
```

This means you can edit framework/workflow code and have it automatically reflected without restarting your session.

#### 2. Create Reusable Setup Modules

Instead of one large `test.py`, split into focused modules:

```
scripts/
├── setup_session.py       # Imports + cluster setup
├── entity_templates/      # JSON specs organized by test type
│   ├── vm_vg_basic.json
│   ├── recovery_plan.json
│   └── pd_migration.json
└── helpers.py             # Reusable helper functions
```

Then in IPython:

```python
%run scripts/setup_session.py
entities = json.load(open('scripts/entity_templates/vm_vg_basic.json'))
entities_created = draas_wo.setup(entity_spec=entities)
```

#### 3. Use IPython's `%store` for Session Persistence

Save important objects between sessions:

```python
%store draas_wo dr_sites entities_created  # Save
# After iPython restart:
%store -r  # Restore
```

#### 4. Create a Quick Setup Function

Add to your `scripts/setup_session.py`:

```python
def quick_setup(pc1_ip, pc2_ip, entity_template="basic"):
    """One-liner DR setup for testing."""
    pc1 = PrismCentralCluster(cluster=pc1_ip)
    pc2 = PrismCentralCluster(cluster=pc2_ip)
    
    # ... (your existing setup code)
    
    return draas_wo, dr_sites, entities_created

# Usage: draas_wo, dr_sites, entities = quick_setup("10.61.7.255", "10.61.7.254")
```

#### 5. Use Pytest Fixtures for Faster Test Development (Recommended)

Instead of iPython, consider using pytest with the `--pdb` flag:

```bash
pytest test_pdtoec.py::PDtoECMigration::test_your_test -v --pdb
```

This drops you into pdb when a test fails or at breakpoints (`import pdb; pdb.set_trace()`), with all entities already created by `setup()`.

---

## Q2: Testing Framework Code (`nutest_py3`)

### For Unit Testing Framework Code

The framework already has unit tests in `[nutest-py3/framework/unittests/](nutest-py3/framework/unittests/)` using pytest + mocking.

**Pattern to follow (from existing tests):**

```python
# File: framework/unittests/entities/my_entity/test_my_entity.py
import pytest
from unittest import mock

@pytest.fixture()
def my_entity(mocker):
    """Create mocked entity for testing."""
    mocker.patch('framework.entities.cluster.base_cluster.BaseCluster')
    # Setup mock object
    return entity

def test_my_method(my_entity):
    """Test specific functionality."""
    result = my_entity.do_something()
    assert result == expected
```

**Run framework unit tests:**

```bash
cd nutest-py3
python -m pytest framework/unittests/entities/vm/test_nos_vm.py -v
```

### For Integration Testing Framework Code

If you need to test framework code with a real cluster:

1. **Create a minimal test in `nutest-py3-tests/testcases/`:**

```python
class FrameworkFeatureTest(NOSTest):
    def test_framework_feature(self):
        """Test the framework feature with real cluster."""
        # Use self.pe_clusters, self.pc_clusters from setup
        result = framework_feature_to_test()
        assert result
```

1. **Run with nutest:**

```bash
nutest run --tests testcases.your_test.FrameworkFeatureTest.test_framework_feature
```

### Key Files for Framework Understanding

- `[nutest-py3-tests/workflows/unittests/conftest.py](nutest-py3-tests/workflows/unittests/conftest.py)` - Fixtures for cluster, hypervisor, SVM mocks
- `[nutest-py3/framework/lib/test/nutest.py](nutest-py3/framework/lib/test/nutest.py)` - Base `NuTest` class
- `[nutest-py3/framework/lib/test/nos_test.py](nutest-py3/framework/lib/test/nos_test.py)` - `NOSTest` base class

---

## Q3: Best Practices for Automation QA Excellence

### Time-Saving Practices


| Practice                 | Impact | Implementation                                 |
| ------------------------ | ------ | ---------------------------------------------- |
| Template-driven tests    | High   | Store entity specs in JSON, reuse across tests |
| Parallel entity creation | High   | Use `ParallelExecutor` from framework          |
| Early validation         | Medium | Add assertions after setup, not just in test   |
| Log grep patterns        | Medium | Create regex patterns for common failures      |


### Development Speed Improvements

#### 1. Pre-built Entity Templates

Store commonly used entity configurations in JSON files so you don't recreate them each time.

#### 2. Use `DrWorkflow.setup()` Efficiently

The `DrWorkflow` class already handles parallel entity creation. Always use it instead of creating entities one-by-one.

#### 3. Leverage Existing Helpers

Your codebase has many utilities:

- `get_synced_entities()` - Entity synchronization across sites
- `delete_existing_rps()` - Quick cleanup
- `remove_log_files()` - Log management

#### 4. Debug Flags

Use these in `test_args` for faster debugging:

```python
test_args = {
    "full_cleanup": False,  # Don't cleanup on failure - inspect state
    "enable_debug_logs": True,
    "collect_uvm_logs": True
}
```

### Code Organization Patterns

#### For Test Files:

```python
class YourTest(NOSTest):
    # 1. class_setup() - One-time setup (cluster connections, cloud trusts)
    # 2. setup() - Per-test setup (create entities)
    # 3. test_X() - Actual test logic
    # 4. teardown() - Per-test cleanup
    # 5. class_teardown() - Final cleanup
```

#### For Framework Code:

- Always add unit tests in `framework/unittests/`
- Follow existing patterns (use pytest fixtures, mock external calls)
- Run linter before committing: `python thirdparty_tools/nutest_linter/nutest_linter.py`

---

## Q4: Quick Automation Wins

### 1. Shell Aliases for Common Commands

Add to `~/.zshrc` or `~/.bashrc`:

```bash
alias nrun='nutest run --tests'
alias nshell='nutest shell'
alias ipy='ipython --no-banner -i scripts/setup_session.py'
```

### 2. Tmux Configuration for Testing

Create a tmux layout script:

```bash
#!/bin/bash
tmux new-session -d -s nutest
tmux split-window -h
tmux send-keys -t 0 'cd ~/nutest && ipython -i scripts/setup_session.py' C-m
tmux send-keys -t 1 'tail -f /var/log/nutest.log' C-m
tmux attach
```

### 3. Quick Entity Status Check Script

```python
# scripts/check_entities.py
def status():
    """Quick status of all entities."""
    print(f"VMs: {len(draas_wo.get_vms())}")
    print(f"VGs: {len(draas_wo.get_vgs())}")
    print(f"RPs: {len(draas_wo.get_recovery_plans())}")
    print(f"PPs: {len(draas_wo.get_protection_policies())}")
```

### 4. IDE Productivity (for Cursor/VSCode)

- Use multi-cursor editing for updating entity specs
- Create code snippets for common patterns (entity specs, test structure)
- Use the integrated terminal split view (one for iPython, one for logs)

### 5. Config Validation Before Running

Create a quick validator:

```python
def validate_config(entity_spec):
    """Validate entity spec before running setup."""
    required_keys = ['vms', 'categories']
    for key in required_keys:
        if key not in entity_spec:
            raise ValueError(f"Missing required key: {key}")
    print("Config valid!")
```

---

## Summary: Key Takeaways

1. **Optimize your iPython workflow** - Use auto-reload, %store, and modular setup scripts
2. **Use pytest for development** - `pytest --pdb` gives you interactive debugging with setup already done
3. **Framework testing** - Unit tests use pytest + mocking; look at existing `framework/unittests/` examples
4. **Template everything** - Entity specs, test args, common setups should be reusable JSON/Python modules
5. **Automate the repetitive** - Shell aliases, tmux scripts, status check functions

The goal is to minimize the time between "I want to test X" and "I'm actually testing X".