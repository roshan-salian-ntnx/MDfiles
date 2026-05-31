# Quick Reference: IPython Test Execution

## File Location
```
/Users/roshan.salian/Documents/Nutest-Working/run_test_rpj_cluster_selection_hybrid_upfo_tfo.py
```

## Quick Start

### 1. Update Cluster Values (SECTION 1)
```python
PC1_IP = "YOUR_PC_A_IP"           # Change this
PC2_IP = "YOUR_PC_B_IP"           # Change this
PE1_UUID = "YOUR_PE_A1_UUID"      # Change this
PE2_UUID = "YOUR_PE_A2_UUID"      # Change this
PE3_UUID = "YOUR_PE_A3_UUID"      # Change this
PE4_UUID = "YOUR_PE_B1_UUID"      # Change this
```

### 2. In IPython Terminal - Copy Each Step

```bash
# STEP 1: Create categories
wo_list = [ms_obj.wo_a_b, ms_obj.wo_a_c1c2_c3]
STEP("Create categories.")
categories_list = test_args["categories"]
ms_obj.create_pc_categories(categories_list, wo_list)

# STEP 2: Create subnets
STEP("Create production subnets on all clusters.")
ms_obj.create_production_network(wo_list=wo_list)
STEP("Create test subnets on all clusters.")
ms_obj.create_test_network(wo_list=wo_list)

# ... continue through STEP 18
```

## 18 Steps Overview

| # | Name | Duration | Critical |
|---|------|----------|----------|
| 1 | Create categories | 2-5m | - |
| 2 | Create subnets | 3-5m | - |
| 3 | Create UVMs | 5-10m | - |
| 4 | Create PR | 2-3m | - |
| 5 | Bind & Process PR | 5-10m | - |
| 6 | Create RP | 2-3m | - |
| 7 | TEST-FAILOVER A→B | 10-15m | - |
| 8 | Cleanup TFO | 3-5m | - |
| 9 | Block networks | 1-2m | ⚠️ |
| 10 | UPFO A→B | 15-20m | ⚠️ |
| 11 | Bind remote WF | 1-2m | - |
| 12 | **Unblock & Process PR** | **40m** | **🔴 KEY FIX** |
| 13 | UPFO B→A3 | 15-20m | ⚠️ |
| 14 | Cleanup & Unblock | 5-10m | ⚠️ |
| 15 | **Edit & Process PR** | **40m** | **🔴 KEY FIX** |
| 16 | TEST-FAILOVER B→A | 10-15m | - |
| 17 | Validate & Cleanup | 5-10m | - |
| 18 | Final UPFO B→A | 15-20m | - |

**Total Estimated Time**: 3-4 hours

## Key Fixes Applied

### Fix 1: Network Unblock (STEP 12)
```python
# Before Process PR, unblock network for replication
draas_library.block_site1_site2_communication(
  ms_obj.pc_b, ms_obj.pe_list_b,
  ms_obj.pc_a, site_a_remote_clusters, unblock=True)
```

### Fix 2: Timeout Increase (STEP 12 & 15)
```python
# Default: 1200s → New: 2400s (40 minutes)
ms_obj.wo_a_b_remote.process_protection_rule(
  ...,
  snapshot_timeout=2400,  # ← 2x default
  ...
)
```

## Variables You'll Need

**From test_args**:
- `categories_list` - VM categories
- `protection_rule_categories` - PR categories
- `pr_az_pairs` - Pairing configuration
- `recovery_plan_stages` - RP stages

**From ms_obj**:
- `ms_obj.pc_a`, `ms_obj.pc_b` - Prism Central
- `ms_obj.pe_list_a`, `ms_obj.pe_list_b` - Clusters
- `ms_obj.wo_a_b` - Workflow A↔B
- `ms_obj.wo_a_c1c2_c3` - Workflow A-self AZ
- `ms_obj.wo_a_b_remote` - Remote workflow

**Created during test**:
- `uvms` - VMs created at A1, A2
- `pr` - Protection rule
- `rp` - Recovery plan
- `recovered_vms` - From failovers

## Critical Timeout Settings

| Method | Parameter | Default | New | Location |
|--------|-----------|---------|-----|----------|
| `create_oob_snapshot()` | `timeout` | 1200s | N/A* | - |
| `process_protection_rule()` | `snapshot_timeout` | 1200s | **2400s** | STEP 12, 15 |
| `process_protection_rule()` | `validate_entities_timeout` | 300s | 300s | - |

*Not used in current test (commented out)

## Copy-Paste Commands

### Load All Test Arguments
```python
test_args = {
    "categories": [{"category": {"hybrid-az": "upfo-tfo"}, "uvm_count": 1}],
    "protection_rule_categories": [{"category": {"hybrid-az": "upfo-tfo"}, "filter_type": "CATEGORY"}],
    "pr_az_pairs": [...],  # See full file
    "primary_location_list": ["pc_a"],
    "recovery_plan_stages": [{"category": {"hybrid-az": "upfo-tfo"}, "entity_filter_type": "CATEGORIES"}]
}
```

### Network Operations Syntax
```python
# Block
draas_library.block_site1_site2_communication(pc_src, pe_list_src, pc_dst, pe_list_dst)

# Unblock
draas_library.block_site1_site2_communication(pc_src, pe_list_src, pc_dst, pe_list_dst, unblock=True)
```

### Failover Syntax
```python
# Test Failover
ms_obj.wo_a_b.start_recovery(
    action="TEST_FAILOVER", 
    recovery_plan=rp, 
    validate_recovery_order=True,
    return_recovered_vm_list=True, 
    remote_pe_list=target_clusters,
    rpj_cross_az_target_cluster_selection_flag=True)

# Unplanned Failover (UPFO)
ms_obj.wo_a_b.start_recovery(
    action="FAILOVER",  # ← Different action
    recovery_plan=rp, 
    validate_recovery_order=True,
    return_recovered_vm_list=True, 
    remote_pe_list=target_clusters,
    rpj_cross_az_target_cluster_selection_flag=True)
```

## Common Issues & Quick Fixes

| Error | Fix |
|-------|-----|
| "Snapshot timeout after 1200s" | Increase `snapshot_timeout=3600` |
| "Network blocked" | Add `unblock=True` parameter |
| "VM not found" | Verify previous step created VM |
| "PR process failed" | Check test_args categories match config |
| "Cannot bind remote WF" | Ensure PR already exists |

## Monitor Logs

```bash
# In separate terminal
tail -f ~/test_logs/test.log
tail -f ~/test_logs/draas.log

# Search for issues
grep -i error ~/test_logs/test.log
grep -i timeout ~/test_logs/test.log
```

## Step Dependencies

```
STEP 1-2-3 ─────┐
                ├─→ STEP 4-5-6 ─┐
                │                ├─→ STEP 7-8 ─┐
                │                │              ├─→ STEP 9-10 ─┐
                │                │              │               ├─→ STEP 11 ─┐
                │                │              │               │            ├─→ STEP 12 🔴
                │                │              │               │            ├─→ STEP 13
                │                │              │               │            ├─→ STEP 14
                │                │              │               │            ├─→ STEP 15 🔴
                │                │              │               │            ├─→ STEP 16
                └────────────────┴──────────────┴───────────────┴────────────┴─→ STEP 17-18

Legend:
- Sequential order (must run in order)
- 🔴 = Critical steps with timeout fixes
```

## Success Checklist

- [ ] STEP 1: Categories created
- [ ] STEP 3: UVMs exist at A1, A2
- [ ] STEP 5: PR processes successfully
- [ ] STEP 7: TFO recovers VMs
- [ ] STEP 10: UPFO A→B completes
- [ ] STEP 12: **Process PR with 2400s timeout** ✓
- [ ] STEP 13: UPFO B→A3 completes
- [ ] STEP 15: **Process PR with 2400s timeout** ✓
- [ ] STEP 16: TFO B→A completes
- [ ] STEP 18: Final UPFO completes
- [ ] All VMs at expected clusters
- [ ] **TEST COMPLETED SUCCESSFULLY!** ✅

## File References

| File | Purpose |
|------|---------|
| `run_test_rpj_cluster_selection_hybrid_upfo_tfo.py` | Main test script - 18 steps |
| `IPYTHON_TEST_EXECUTION_GUIDE.md` | Detailed execution guide |
| `test_multisite_hybrid_az.py` | Original test method |
| `TIMEOUT_QUICK_REFERENCE.md` | Timeout parameters |
| `COMPLETE_SOLUTION_SUMMARY.md` | All fixes applied |

## Ready to Execute?

1. ✅ Update cluster IPs/UUIDs in SECTION 1
2. ✅ Open file in editor
3. ✅ Open IPython terminal
4. ✅ Copy STEP 1 code
5. ✅ Paste into IPython
6. ✅ Press Enter
7. ✅ Wait for completion
8. ✅ Move to STEP 2
9. ✅ Repeat for all 18 steps
10. ✅ Celebrate when all complete! 🎉

**Estimated Total Time**: 3-4 hours
**Key Fixes**: Network unblock + 2400s timeout
**Status**: Ready for execution
