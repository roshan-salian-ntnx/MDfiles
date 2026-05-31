#!/usr/bin/env python3
"""Fast nutest debug loop - companion module.
=============================================

Workflow guide + helpers for iterating on nutest tests without paying
setup cost on every change. Implements the 5-layer debugging pyramid
from .cursor/plans/nutest_fast_debug_loop_*.plan.md.

THE 5-LAYER PYRAMID
-------------------
  L0  Static read of code (no run)             <- .cursor/rules/draas-test-debugging.mdc
  L1  breakpoint() inside the live test        <- this module: embed_here()
  L2  Re-run with --skip_class_setup --skip_setup --skip_teardown
  L3  Instantiate test class in IPython        <- this module: build_test_instance()
  L4  Full clean nutest run                    <- last resort

This module supplies:

  embed_here(local_ns)            L1 - drop into IPython with caller locals
  reload_modules(*names)          L1 - hot-reload edited modules in place
  build_test_instance(cls, ...)   L3 - factory for any NOSTest subclass
  build_negative_test(...)        L3 - convenience wrapper for the
                                       unplanned-failover NegativeTest


LAYER 1 - drop into IPython at the failing scenario
---------------------------------------------------
1. Open the failing test, find the STEP() where it dies.
2. Insert one line at the start of that scenario block:

       STEP("Stopping ergon service on remote PE.")
       from scripts.dev_loop import embed_here; embed_here(locals())
       remote_pe = self.remote_pe_list[0]
       Ergon(remote_pe).stop()
       ...

3. Run the test once with --skip_teardown so cluster state survives:

       nutest run --tests dr.draas.merged_tests.\\
       recovery_plan_unplanned_failover.\\
       test_recovery_plan_unplanned_failover.\\
       NegativeTest.test_upfo_error_scenarios \\
           --verbose --no_log_collection --skip_teardown \\
           --resources NOS:auto_cluster_... \\
                       PC:10.61.4.2 PC:10.61.4.21

4. At the IPython prompt you have self / draas_wo / test_args /
   #TAG resolution all live. Iterate WITHOUT restarting nutest:

       # Inspect
       self.draas_wo.pc_entities[self.remote_pc.svms[0].ip]

       # Edit workflows/draas/draas_library.py in another buffer, save.
       # Then re-pull the module here:
       reload_modules("workflows.draas.draas_library")

       # Re-call the failing op on the live self:
       self.draas_wo.trigger_rpj(recovery_plan=rp, action='FAILOVER')

5. Ctrl-D to resume test execution, OR `quit` and remove the
   embed_here() line. Final verification: full clean run.


LAYER 2 - re-run with class state still up
------------------------------------------
When the IPython namespace is dirty but cluster state (categories,
VMs, PR, RP, ...) is still good from your --skip_teardown run:

       nutest run --tests ... \\
           --skip_class_setup --skip_setup --skip_teardown \\
           --no_log_collection --verbose --resources ...

A shell alias `niter` in scripts/nutest_aliases.sh wraps this.

Caveat: each nutest run is a fresh Python process, so self is rebuilt
from scratch. Cluster-side state survives; in-Python state doesn't.


LAYER 3 - instantiate the test class in IPython
-----------------------------------------------
Use this when you want to poke at a test without a breakpoint, or
when you've already set up cluster objects in IPython and want the
test's setup() to run on top.

       from scripts.dev_loop import build_negative_test
       t = build_negative_test(
           pc_clusters=[pc1, pc2],
           pe_clusters=[pe1, pe2, pe3],
           test_args={
               "dummy_vm": False,
               "categories": [
                   {"category": {"dept": "hr"}, "uvm_count": 1}],
               "protection_rule_categories": [
                   {"category": {"dept": "hr"},
                    "filter_type": "CATEGORY"}],
               "recovery_plan_stages_1": [
                   {"category": {"dept": "hr"}, "delay": 60,
                    "entity_filter_type": "CATEGORIES"}],
               "sleep": 60,
           })

       # t.draas_wo, t.source_pc, t.remote_pe_list, ... are now live.
       # Run any sub-step of the test method:
       t.draas_wo.do_setup(create_uvm=False, create_rp=False)
       t.draas_wo.create_categories(
           categories_list=t.test_args["categories"])

For other test classes:

       from scripts.dev_loop import build_test_instance
       from testcases.some.module import SomeTest
       t = build_test_instance(SomeTest,
           pc_clusters=[...], pe_clusters=[...],
           test_args={...}, run_setup=True)

Caveats:
  - We bypass NOSTest.__init__ (which expects CLI-parsed resources),
    so anything __init__ does besides resource wiring is skipped.
    For all DRaaS tests this is fine; setup() is where the real work
    happens.
  - Don't call t.teardown() in dev - it dereferences `t.result` which
    is a property that hits the test-results URL. Clean up manually
    via draas_wo.teardown(...) or per-entity helpers.


CURSOR REMOTE SSH - stop copying files to the ubvm
--------------------------------------------------
~/.ssh/config has:

    Host ubvm
        HostName 10.111.51.158
        User roshan.salian
        IdentityFile ~/.ssh/id_ed25519
        ServerAliveInterval 60   # keep Remote-SSH alive on idle
        ServerAliveCountMax 3

Verified working: ssh ubvm -> roshan-salian.r8.ubvm.nutanix.com.
Nutest checkout on the ubvm: /home/roshan.salian/Nutest
IPython on the ubvm:         /home/roshan.salian/.pyenv/shims/ipython

In Cursor on Mac:
  1. Cmd+Shift+P -> "Remote-SSH: Connect to Host" -> pick `ubvm`.
     If the command isn't there, install the "Remote - SSH"
     extension from the Extensions panel first.
  2. A new Cursor window opens, attached to the VM.
  3. File -> Open Folder -> /home/roshan.salian/Nutest
     From here on, all edits, AI requests, terminals, IPython, and
     the debugger run on the ubvm. No scp.

Why this matters: the L1 breakpoint workflow above only works if your
edits are visible to the running test process. Remote-SSH makes "the
file you edit" and "the file nutest runs" the same file by
construction.
"""

import importlib
import sys


def embed_here(local_ns=None, header=""):
    """Drop into IPython (or pdb fallback) with the caller's locals.

    Args:
      local_ns: pass `locals()` so self / test_args / draas_wo
        are bound by name in the embedded prompt.
      header: short context string shown above the prompt (e.g.
        the scenario name).

    Example:
      from scripts.dev_loop import embed_here
      embed_here(locals(), header="PHASE K - acropolis race")
    """
    try:
      from IPython import embed
    except ImportError:
      import pdb
      print("IPython not installed; falling back to pdb.")
      if local_ns is not None:
        globals().update(local_ns)
      pdb.set_trace()
      return

    ns = {}
    ns.update(globals())
    if local_ns:
      ns.update(local_ns)

    banner_lines = ["=" * 70]
    if header:
      banner_lines.append("  " + header)
    banner_lines.extend([
      "  embed_here() - L1 debug.",
      "  Caller locals (self, test_args, ...) are bound here.",
      "  reload_modules('pkg.mod')  -> apply edits without leaving.",
      "  Ctrl-D to resume test execution.",
      "=" * 70,
    ])
    embed(user_ns=ns, header="\n".join(banner_lines), colors="neutral")


def reload_modules(*names):
    """Hot-reload one or more dotted-name modules.

    Use after editing a helper module to apply changes in the running
    IPython session. Note: instances of classes from the reloaded
    module keep their old methods until re-instantiated. For framework-
    deep changes you may need to drop back to Layer 2.

    Returns the list of module names that were (re)loaded.

    Example:
      reload_modules(
          "workflows.draas.draas_library",
          "workflows.draas.draas_workflows",
      )
    """
    reloaded = []
    for name in names:
      mod = sys.modules.get(name)
      try:
        if mod is not None:
          importlib.reload(mod)
          reloaded.append(name)
        else:
          importlib.import_module(name)
          reloaded.append("%s (freshly imported)" % name)
      except Exception as exc:  # noqa: BLE001 - dev helper, surface anything
        print("reload failed for %s: %s" % (name, exc))
    if reloaded:
      print("reloaded: " + ", ".join(reloaded))
    return reloaded


def build_test_instance(test_class, pc_clusters, pe_clusters,
                        test_args=None, interface_type=None,
                        run_setup=True, extra_attrs=None):
    """Instantiate a NOSTest subclass and (optionally) call its setup().

    Bypasses NOSTest.__init__ (which expects CLI-parsed resources) and
    wires the minimum attributes setup() needs to run. After this you
    can call any method of the test exactly as it would be called by
    the real runner - including #TAG resolution via the workflow's
    DrConfig - because `self` is a real instance.

    Args:
      test_class: e.g. NegativeTest, NOSTest subclass.
      pc_clusters: list of PrismCentralCluster objects.
      pe_clusters: list of NOSCluster objects.
      test_args: dict matching the test's config.json `test_args`.
      interface_type: framework.interfaces.interface.Interface value.
        Defaults to REST.
      run_setup: if True, call t.setup() before returning.
      extra_attrs: dict of attributes to set BEFORE setup() runs.

    Returns: the test instance.

    See module docstring for full Layer 3 example.
    """
    from framework.interfaces.interface import Interface

    t = test_class.__new__(test_class)

    # NOSTest.get_resources_by_type filters self.resources by their
    # `resource_type` attribute, which is already set correctly on
    # PrismCentralCluster / NOSCluster objects. So just hand it a flat
    # list and the framework's own logic does the right thing.
    t.resources = list(pe_clusters) + list(pc_clusters)
    t.clusters = list(pe_clusters) + list(pc_clusters)
    t.cluster = t.clusters[0] if t.clusters else None

    t.test_args = dict(test_args or {})
    t.interface_type = interface_type or Interface.REST

    # NuTest base normally sets params from CLI; supply a stub.
    t.params = {"resources": [], "resource_spec": []}

    # Used by teardown helpers / log paths; harmless defaults for dev.
    if not getattr(t, "log_dir", None):
      t.log_dir = "/tmp"

    if extra_attrs:
      for k, v in extra_attrs.items():
        setattr(t, k, v)

    if run_setup:
      t.setup()
    return t


def build_negative_test(pc_clusters, pe_clusters, test_args=None,
                        interface_type=None, run_setup=True):
    """Build the unplanned-failover NegativeTest with the L3 factory.

    Convenience wrapper around build_test_instance() for the test in
    testcases/dr/draas/merged_tests/recovery_plan_unplanned_failover/
    test_recovery_plan_unplanned_failover.py.

    See module docstring for a worked example matching
    test_upfo_error_scenarios.
    """
    from testcases.dr.draas.merged_tests.\
        recovery_plan_unplanned_failover.\
        test_recovery_plan_unplanned_failover import NegativeTest
    return build_test_instance(
        NegativeTest,
        pc_clusters=pc_clusters,
        pe_clusters=pe_clusters,
        test_args=test_args,
        interface_type=interface_type,
        run_setup=run_setup,
    )
