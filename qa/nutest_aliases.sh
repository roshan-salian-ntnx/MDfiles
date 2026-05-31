#!/bin/bash
# =============================================================================
# Nutest Shell Aliases and Functions
# =============================================================================
#
# This file contains TWO sections:
#   1. LOCAL (Mac) aliases - for use on your development machine
#   2. DEV VM aliases - copy these to your dev VM's ~/.bashrc
#
# LOCAL Usage: Add to your ~/.zshrc or ~/.bashrc:
#   source /path/to/scripts/nutest_aliases.sh
#
# DEV VM Usage: Copy the "DEV VM SECTION" below to your dev VM's ~/.bashrc
#
# Author: Roshan Salian
# =============================================================================

# =============================================================================
# CONFIGURATION - Update these paths as needed
# =============================================================================
# Local Mac path
export NUTEST_LOCAL_PATH="${NUTEST_LOCAL_PATH:-$HOME/Documents/Nutest-Working}"

# Dev VM path (typical nutest installation path)
export NUTEST_VM_PATH="${NUTEST_VM_PATH:-/home/nutanix/nutest}"

# =============================================================================
# LOCAL (MAC) SECTION - Sync and SSH commands
# =============================================================================

# Sync local changes to dev VM
# Usage: nsync <dev_vm_ip>
nsync() {
    if [ -z "$1" ]; then
        if [ -z "$DEV_VM_IP" ]; then
            echo "Usage: nsync <dev_vm_ip>"
            echo "Or set: export DEV_VM_IP=<your_dev_vm_ip>"
            return 1
        fi
        local vm_ip="$DEV_VM_IP"
    else
        local vm_ip="$1"
    fi
    
    echo "Syncing to dev VM: $vm_ip"
    cd "$NUTEST_LOCAL_PATH" && nusync "$vm_ip"
}

# SSH to dev VM and optionally run a command
# Usage: devssh [command]
devssh() {
    if [ -z "$DEV_VM_IP" ]; then
        echo "Set DEV_VM_IP first: export DEV_VM_IP=<your_dev_vm_ip>"
        return 1
    fi
    
    if [ -z "$1" ]; then
        ssh nutanix@"$DEV_VM_IP"
    else
        ssh nutanix@"$DEV_VM_IP" "$@"
    fi
}

# Sync and SSH in one command
# Usage: syncdev [dev_vm_ip]
syncdev() {
    local vm_ip="${1:-$DEV_VM_IP}"
    if [ -z "$vm_ip" ]; then
        echo "Usage: syncdev <dev_vm_ip> or set DEV_VM_IP"
        return 1
    fi
    
    echo "Syncing to $vm_ip..."
    nsync "$vm_ip" && echo "SSH to $vm_ip..." && ssh nutanix@"$vm_ip"
}

# Local directory navigation (Mac)
alias cdnutest='cd $NUTEST_LOCAL_PATH'
alias cdfw='cd $NUTEST_LOCAL_PATH/nutest-py3/framework'
alias cdtests='cd $NUTEST_LOCAL_PATH/nutest-py3-tests/testcases'
alias cdwf='cd $NUTEST_LOCAL_PATH/nutest-py3-tests/workflows'
alias cdscripts='cd $NUTEST_LOCAL_PATH/scripts'

# =============================================================================
# DEV VM SECTION - Copy everything below this line to your dev VM's ~/.bashrc
# =============================================================================
# 
# ---- START DEV VM BASHRC ----
# 
# # Nutest environment setup
# export NUTEST_PATH="${NUTEST_PATH:-/home/nutanix/nutest}"
# 
# # Setup nutest environment (run this after login)
# nsetup() {
#     cd "$NUTEST_PATH"
#     source bin/activate_nutest_env.sh 2>/dev/null || echo "Activate script not found"
#     echo "Nutest environment ready at: $NUTEST_PATH"
# }
# 
# # Quick IPython with setup
# nipy() {
#     cd "$NUTEST_PATH"
#     source bin/activate_nutest_env.sh 2>/dev/null
#     ipython --no-banner -i scripts/setup_session.py
# }
# 
# # Run nutest tests
# alias nrun='nutest run --tests'
# alias nshell='nutest shell'
# 
# # Run unit tests
# alias nunit='python -m pytest'
# alias nunitv='python -m pytest -v'
# alias nunitpdb='python -m pytest --pdb'
# 
# # Navigation
# alias cdnutest='cd $NUTEST_PATH'
# alias cdfw='cd $NUTEST_PATH/nutest-py3/framework'
# alias cdtests='cd $NUTEST_PATH/nutest-py3-tests/testcases'
# alias cdscripts='cd $NUTEST_PATH/scripts'
# 
# # Quick tmux session for dev work
# ntmux() {
#     tmux new-session -d -s nutest -n "ipython" 2>/dev/null || tmux attach -t nutest
#     tmux send-keys -t nutest:0 'nipy' C-m
#     tmux new-window -t nutest:1 -n "shell" 2>/dev/null
#     tmux send-keys -t nutest:1 'cd $NUTEST_PATH && nsetup' C-m
#     tmux select-window -t nutest:0
#     tmux attach -t nutest
# }
# 
# ---- END DEV VM BASHRC ----
#

# =============================================================================
# NUTEST COMMAND ALIASES (work on both local and VM)
# =============================================================================

# Run nutest tests
alias nrun='nutest run --tests'

# Nutest shell
alias nshell='nutest shell'

# -----------------------------------------------------------------------------
# FAST DEV LOOP - layered debugging workflow
# (see scripts/dev_loop.py and .cursor/plans/nutest_fast_debug_loop_*.plan.md)
# -----------------------------------------------------------------------------
#
# Typical loop after dropping `embed_here(locals())` in your test:
#
#   nfirst <test-path> --resources ...   # L1: one-time setup-and-stop
#   # ... iterate in IPython, edit code, reload_modules(...)
#   niter  <test-path> --resources ...   # L2: re-run, keep cluster state
#   nclean <test-path> --resources ...   # L4: full clean run to verify
#
# All three are thin wrappers around `nutest run --tests` with the right
# skip flags for the layer. They forward any extra args you pass.

# L1: first run. Builds class+test state on the cluster, but does NOT
# tear down so your --skip_teardown breakpoint workflow can iterate.
alias nfirst='nutest run --no_log_collection --verbose --skip_teardown --tests'

# L2: re-iterate. Skips class setup + test setup + test teardown so we
# reuse the cluster state nfirst left behind. Fresh Python process
# every time - if you need to keep `self` between iterations, stay in
# the embed_here() IPython prompt instead.
alias niter='nutest run --no_log_collection --verbose --skip_class_setup --skip_setup --skip_teardown --tests'

# L4: full clean run. No skip flags - use for the verification pass
# after you remove your breakpoint.
alias nclean='nutest run --no_log_collection --verbose --tests'

# Drop into IPython on the cluster you've already set up (via nfirst)
# without involving nutest at all. Loads scripts/setup_session.py so
# all the standard objects + helpers are in scope. Layer 3 entry point.
alias ndev='cd "${NUTEST_PATH:-$NUTEST_LOCAL_PATH}" && ipython --no-banner -i scripts/setup_session.py'

# Quick IPython with setup (for local - VM version is in the section above)
alias nipy='cd $NUTEST_LOCAL_PATH && ipython --no-banner -i scripts/setup_session.py'

# Run unit tests
alias nunit='python -m pytest'
alias nunitv='python -m pytest -v'
alias nunitpdb='python -m pytest --pdb'

# Run framework unit tests
alias nfwtest='cd $NUTEST_LOCAL_PATH/nutest-py3 && python -m pytest framework/unittests/ -v'

# Run workflow unit tests  
alias nwftest='cd $NUTEST_LOCAL_PATH/nutest-py3-tests && python -m pytest workflows/unittests/ -v'

# =============================================================================
# GIT SHORTCUTS FOR NUTEST
# =============================================================================

alias gst='git status'
alias gd='git diff'
alias gco='git checkout'
alias gcm='git commit -m'
alias gpl='git pull'
alias gps='git push'

# =============================================================================
# TMUX SESSION FUNCTIONS (for Dev VM)
# =============================================================================

# Start a nutest development tmux session on dev VM
# This creates a multi-window tmux layout for efficient development
nutest_tmux() {
    local session_name="${1:-nutest}"
    local nutest_path="${NUTEST_PATH:-$NUTEST_LOCAL_PATH}"
    
    # Check if session exists
    if tmux has-session -t "$session_name" 2>/dev/null; then
        echo "Session '$session_name' already exists. Attaching..."
        tmux attach-session -t "$session_name"
        return
    fi
    
    # Create new session
    echo "Creating new tmux session: $session_name"
    
    # Create session with first window
    tmux new-session -d -s "$session_name" -n "ipython"
    
    # Window 0: IPython - setup nutest env first, then start ipython
    tmux send-keys -t "$session_name:0" "cd $nutest_path && source bin/activate_nutest_env.sh 2>/dev/null; ipython -i scripts/setup_session.py" C-m
    
    # Window 1: Shell for running tests
    tmux new-window -t "$session_name:1" -n "shell"
    tmux send-keys -t "$session_name:1" "cd $nutest_path && source bin/activate_nutest_env.sh 2>/dev/null" C-m
    
    # Window 2: Logs (optional)
    tmux new-window -t "$session_name:2" -n "logs"
    tmux send-keys -t "$session_name:2" 'echo "Ready for log tailing - use: tail -f /var/log/nutest.log"' C-m
    
    # Select first window and attach
    tmux select-window -t "$session_name:0"
    tmux attach-session -t "$session_name"
}

# Quick tmux split for dev work
nutest_split() {
    local nutest_path="${NUTEST_PATH:-$NUTEST_LOCAL_PATH}"
    # Horizontal split with IPython on top, shell on bottom
    tmux split-window -v
    tmux send-keys -t 0 "cd $nutest_path && source bin/activate_nutest_env.sh 2>/dev/null; ipython -i scripts/setup_session.py" C-m
    tmux select-pane -t 1
}

# =============================================================================
# UTILITY FUNCTIONS
# =============================================================================

# Quick grep in nutest codebase
ngrep() {
    if [ -z "$1" ]; then
        echo "Usage: ngrep <pattern> [path]"
        return 1
    fi
    local pattern="$1"
    local nutest_path="${NUTEST_PATH:-$NUTEST_LOCAL_PATH}"
    local path="${2:-$nutest_path}"
    rg "$pattern" "$path" --type py 2>/dev/null || grep -r "$pattern" "$path" --include="*.py"
}

# Find Python files in nutest
nfind() {
    if [ -z "$1" ]; then
        echo "Usage: nfind <pattern>"
        return 1
    fi
    local nutest_path="${NUTEST_PATH:-$NUTEST_LOCAL_PATH}"
    find "$nutest_path" -name "*$1*.py" -type f
}

# Show test file structure
ntree() {
    local nutest_path="${NUTEST_PATH:-$NUTEST_LOCAL_PATH}"
    local path="${1:-$nutest_path/nutest-py3-tests/testcases}"
    tree -L 3 -P "*.py" --prune "$path" 2>/dev/null || find "$path" -name "*.py" -type f | head -50
}

# Quick lint check
nlint() {
    local file="${1:-.}"
    local nutest_path="${NUTEST_PATH:-$NUTEST_LOCAL_PATH}"
    cd "$nutest_path"
    python thirdparty_tools/nutest_linter/nutest_linter.py "$file"
}

# =============================================================================
# CLUSTER MANAGEMENT HELPERS
# =============================================================================

# SSH to cluster by IP
cssh() {
    if [ -z "$1" ]; then
        echo "Usage: cssh <cluster_ip>"
        return 1
    fi
    ssh nutanix@"$1"
}

# Check cluster connectivity
cping() {
    if [ -z "$1" ]; then
        echo "Usage: cping <cluster_ip>"
        return 1
    fi
    ping -c 3 "$1"
}

# =============================================================================
# HELPFUL MESSAGES
# =============================================================================

echo "Nutest aliases loaded!"
echo ""
echo "=== LOCAL (Mac) Commands ==="
echo "  nsync <vm_ip>  - Sync changes to dev VM"
echo "  devssh         - SSH to dev VM (set DEV_VM_IP first)"
echo "  syncdev        - Sync and SSH in one command"
echo ""
echo "=== Dev VM Commands ==="
echo "  nipy           - Start IPython with setup_session.py"
echo "  nrun <test>    - Run nutest test"
echo "  nutest_tmux    - Start tmux dev session"
echo "  nsetup         - Setup nutest environment"
echo ""
echo "=== Fast Dev Loop (see scripts/dev_loop.py) ==="
echo "  nfirst <test> --resources ... - L1: first run, --skip_teardown"
echo "  niter  <test> --resources ... - L2: re-run, --skip_class_setup --skip_setup --skip_teardown"
echo "  nclean <test> --resources ... - L4: full clean run (verification)"
echo "  ndev                           - L3: IPython attach to your existing setup"
echo ""
echo "=== General Commands ==="
echo "  ngrep <pat>    - Search in codebase"
echo "  nfind <pat>    - Find Python files"
echo ""
echo "Tip: Set DEV_VM_IP for easier dev VM access:"
echo "  export DEV_VM_IP=10.x.x.x"
echo ""
