# Guide: Running test_rpj_cluster_selection_hybrid_upfo_tfo in IPython Terminal

## Overview

The file `run_test_rpj_cluster_selection_hybrid_upfo_tfo.py` is a standalone Python script that breaks down the test into individual steps suitable for IPython terminal execution.

**Location**: `/Users/roshan.salian/Documents/Nutest-Working/run_test_rpj_cluster_selection_hybrid_upfo_tfo.py`

## How It Works

### Section 1: Cluster Objects
The script starts by defining cluster objects matching the test setup from `test.py` (lines 113-121):
```python
pc1 = PrismCentralCluster(cluster=PC1_IP)   # PC A
pc2 = PrismCentralCluster(cluster=PC2_IP)   # PC B
pe1 = NOSCluster(cluster=PE1_UUID)          # PE A1
pe2 = NOSCluster(cluster=PE2_UUID)          # PE A2
pe3 = NOSCluster(cluster=PE3_UUID)          # PE A3
pe4 = NOSCluster(cluster=PE4_UUID)          # PE B1
```

**Action Required**: Update IP addresses and UUIDs with your actual infrastructure values.

### Section 2: Test Arguments
The script loads test configuration from the config.json:
```python
test_args = {
    "categories": [...],
    "protection_rule_categories": [...],
    "pr_az_pairs": [...],
    "primary_location_list": ["pc_a"],
    "recovery_plan_stages": [...]
}
```

### Section 3: MultiSite Workflow Object
This section prepares for ms_obj creation. The actual creation happens in the test framework.

### Section 4: 18 Test Steps
Each step is self-contained with copy-paste code blocks for IPython execution.

## Step-by-Step Execution

### Quick Copy-Paste Instructions

1. **Open the file in editor or viewer**:
   ```bash
   cat /Users/roshan.salian/Documents/Nutest-Working/run_test_rpj_cluster_selection_hybrid_upfo_tfo.py
   ```

2. **For each STEP (1-18)**:
   - Copy the code block from "STEP X: ..."
   - Paste into IPython terminal
   - Press Enter to execute
   - Wait for "✓ Step X completed" message
   - Move to next step

### Test Steps Overview

| Step | Description | Key Action |
|------|-------------|-----------|
| 1 | Create categories | Setup categories for VMs |
| 2 | Create subnets | Create production & test networks |
| 3 | Create UVMs | Create VMs at A1 and A2 |
| 4 | Create PR | Create protection rules (A-A3, A-B, A3-B) |
| 5 | Bind & Process PR | Bind entities and process PR |
| 6 | Create RP | Create recovery plan RP1 (A-B) |
| 7 | TEST-FAILOVER A→B | Test failover from A to B |
| 8 | Cleanup TFO | Delete recovered VMs from TFO |
| 9 | **Block networks** | **Block A-B and A-A3** |
| 10 | **UPFO A→B** | **Unplanned failover A to B** |
| 11 | Bind remote WF | Bind wo_a_b_remote |
| 12 | **Unblock & Process PR** | **🔑 CRITICAL: Unblock B-A3, Process with 2400s timeout** |
| 13 | **UPFO B→A3** | **Unplanned failover B to A3** |
| 14 | Cleanup & Unblock | Delete VMs, unblock all networks |
| 15 | **Edit & Process PR** | **🔑 CRITICAL: Process with 2400s timeout** |
| 16 | TEST-FAILOVER B→A | Test failover from B to A |
| 17 | Validate & Cleanup | Validate cluster references, cleanup |
| 18 | **Final UPFO B→A** | **Block B-(A1,A2), UPFO B to A** |

### Critical Steps

**Steps 12 and 15** contain the critical fixes:

**STEP 12** (Line 470-490):
```python
STEP("Unblock network between B - A(A3) for snapshot replication")
draas_library.block_site1_site2_communication(
  ms_obj.pc_b, ms_obj.pe_list_b,
  ms_obj.pc_a, site_a_remote_clusters, unblock=True)  # ← UNBLOCK

STEP("Process PR.")
ms_obj.wo_a_b_remote.process_protection_rule(
  categories_list=test_args["protection_rule_categories"],
  calc_local_checksum=False, calc_remote_checksum=False,
  validate_snaps=True, snapshot_timeout=2400,  # ← 2x TIMEOUT
  remote_pe_list=site_a_remote_clusters)
```

**STEP 15** (Line 548-564):
```python
ms_obj.wo_a_b_remote.process_protection_rule(
  categories_list=test_args["protection_rule_categories"],
  calc_local_checksum=False, calc_remote_checksum=False,
  validate_snaps=True, snapshot_timeout=2400,  # ← 2x TIMEOUT
  remote_pe_list=site_a_source_clusters)
```

## Usage Examples

### Example 1: Copy Single Step

```bash
# Open file
vim /Users/roshan.salian/Documents/Nutest-Working/run_test_rpj_cluster_selection_hybrid_upfo_tfo.py

# Find "STEP 1: Create categories"
# Copy from "wo_list = ..." to "print(...)"
# Paste in IPython terminal
```

### Example 2: Execute Full Test

```bash
# In IPython terminal:
exec(open('/Users/roshan.salian/Documents/Nutest-Working/run_test_rpj_cluster_selection_hybrid_upfo_tfo.py').read())

# This will print all 18 steps with code blocks to copy-paste
```

### Example 3: Jump to Specific Step

If you need to restart from Step 12:

1. Find "STEP 12: Unblock network B-A3 and Process PR"
2. Note that it depends on variables from Steps 1-11
3. Ensure all previous steps have been executed
4. Copy STEP 12 code block
5. Execute in IPython

## Required Variables at Each Step

### Before STEP 12:
- `ms_obj` - MultiSite workflow object
- `ms_obj.wo_a_b`, `ms_obj.wo_a_c1c2_c3` - Workflow objects
- `ms_obj.pc_a`, `ms_obj.pc_b` - Prism Central objects
- `ms_obj.pe_list_a`, `ms_obj.pe_list_b` - Cluster objects
- `site_a_source_clusters`, `site_a_remote_clusters` - Cluster arrays
- `categories_list` - Categories from test_args
- `pr` - Protection rule object
- `rp` - Recovery plan object
- `uvms` - List of created VMs
- `things_to_edit` - Dictionary with failover flags
- `test_args` - Test configuration

### After STEP 12:
- All variables above
- `recovered_vms` - Recovered VMs from TFO

## Timeout Parameters Applied

| Step | Parameter | Value | Duration |
|------|-----------|-------|----------|
| 12 | `snapshot_timeout` | 2400 | 40 minutes |
| 15 | `snapshot_timeout` | 2400 | 40 minutes |

**Why 2400 seconds?**
- Default: 1200s (20 min)
- After failover: 2400s (40 min) = 2x
- Covers: snapshot replication + entity validation + checksum calc + system load

## Error Handling

### If Step Fails

1. **Read error message carefully**
2. **Check logs**: `~/test_logs/` or similar
3. **Common issues**:
   - Network blocking/unblocking failed → Check network connectivity
   - Timeout occurred → Check system load, increase timeout if needed
   - VM not found → Check if previous steps succeeded
   - PR not created → Check categories and protection rule config

### Recovery Steps

If you need to restart from a failed step:

1. Identify which step failed
2. Fix the issue (network, timeout, config, etc.)
3. Run the failed step again
4. Continue from the next step

### Rolling Back

To restart entire test:
1. Delete all created VMs, PRs, RPs from the test framework
2. Return to STEP 1
3. Re-execute all steps

## File Structure

```
run_test_rpj_cluster_selection_hybrid_upfo_tfo.py
├── SECTION 1: Initialize Cluster Objects (lines 21-47)
├── SECTION 2: Load Test Arguments (lines 49-105)
├── SECTION 3: Create MultiSite Workflow Object (lines 107-119)
├── SECTION 4: TEST EXECUTION (lines 121+)
│   ├── STEP 1: Create categories
│   ├── STEP 2: Create subnets
│   ├── STEP 3: Create UVMs
│   ├── STEP 4: Create PR
│   ├── STEP 5: Bind & Process PR
│   ├── STEP 6: Create RP
│   ├── STEP 7: TEST-FAILOVER A→B
│   ├── STEP 8: Cleanup TFO
│   ├── STEP 9: Block networks
│   ├── STEP 10: UPFO A→B
│   ├── STEP 11: Bind remote WF
│   ├── STEP 12: Unblock & Process PR ⭐ CRITICAL FIX
│   ├── STEP 13: UPFO B→A3
│   ├── STEP 14: Cleanup & Unblock
│   ├── STEP 15: Edit & Process PR ⭐ CRITICAL FIX
│   ├── STEP 16: TEST-FAILOVER B→A
│   ├── STEP 17: Validate & Cleanup
│   └── STEP 18: Final UPFO B→A
└── EXECUTION INSTRUCTIONS (final section)
```

## Tips for Successful Execution

1. **Before Starting**:
   - Ensure test framework is initialized
   - Verify cluster connectivity
   - Check that ms_obj is available in IPython

2. **During Execution**:
   - Copy code blocks completely (don't skip lines)
   - Wait for each step to complete before proceeding
   - Monitor logs in parallel terminal: `tail -f ~/test_logs/test.log`
   - Note any warnings or errors

3. **After Each Step**:
   - Verify output shows "✓ Step completed"
   - Check logs for any issues
   - Confirm expected objects were created

4. **Network Operations**:
   - STEP 9: Blocks networks
   - STEP 12: Unblocks network B-A3
   - STEP 14: Unblocks all networks
   - STEP 18: Blocks network B-A(A1,A2)
   - Monitor network status in separate terminal

5. **Failover Operations**:
   - TFO (Test Failover) = recovers VMs, doesn't activate
   - UPFO (Unplanned Failover) = activates failover
   - Watch for cluster references and VM placement

## Expected Test Results

### Success Indicators
- All 18 steps complete without errors
- Each step prints "✓ Step completed successfully"
- Final output: "✅ TEST COMPLETED SUCCESSFULLY!"
- VMs exist at expected clusters after failovers
- Cluster reference validation passes

### Key Assertions
- Step 3: UVMs created at A1 and A2
- Step 5: PR processes successfully, snapshots replicated
- Step 7: TFO succeeds, recovered VMs available
- Step 12: PR processes with 2400s timeout (cross-AZ replication)
- Step 13: UPFO succeeds, A3 is new primary
- Step 16: TFO B→A succeeds, VMs at A1/A2
- Step 18: Final UPFO succeeds, A(A1,A2) becomes primary

## Troubleshooting Reference

| Issue | Likely Cause | Solution |
|-------|---|---|
| "Snapshot timeout" | Network blocked | Check STEP 12 unblock, increase timeout to 3600s |
| "VM not found" | Previous step failed | Check logs, re-run failed step |
| "Network operation failed" | Connectivity issue | Check cluster IPs, verify network config |
| "PR not created" | Category mismatch | Verify test_args categories match cluster config |
| "Failover failed" | Invalid recovery plan | Check RP creation, verify cluster references |

## Next Steps After Test

1. **If Test Passes**:
   - Review logs for any warnings
   - Validate all VMs are in correct state
   - Check snapshot replication completed
   - Document test results

2. **If Test Fails**:
   - Review this guide's troubleshooting section
   - Check detailed logs
   - Verify cluster configuration
   - Contact test team with error details

3. **For Production Deployment**:
   - Run full test suite
   - Validate on actual production clusters
   - Document any customizations
   - Monitor performance metrics

---

**File**: `run_test_rpj_cluster_selection_hybrid_upfo_tfo.py`
**Purpose**: Line-by-line test execution for IPython terminal
**Key Fixes**: Network unblock + 2400s timeout for cross-AZ replication
**Status**: Ready for execution
