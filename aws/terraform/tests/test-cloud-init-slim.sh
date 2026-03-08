#!/usr/bin/env bash
set -euo pipefail

# ── cloud-init-slim.sh.tftpl test suite ──────────────────────────────────────
# Static validation of the slim cloud-init template: required sections,
# variable usage, user references, systemd service, and ordering.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATE="$SCRIPT_DIR/../cloud-init-slim.sh.tftpl"

PASS=0
FAIL=0
TOTAL=0

run_test() {
  local name="$1"
  shift
  TOTAL=$((TOTAL + 1))
  echo -n "  $name ... "
  if "$@" 2>/dev/null; then
    echo "PASS"
    PASS=$((PASS + 1))
  else
    echo "FAIL"
    FAIL=$((FAIL + 1))
  fi
}

# ── Basic Structure ─────────────────────────────────────────────────────────

test_starts_with_shebang() {
  head -1 "$TEMPLATE" | grep -q '^#!/bin/bash'
}

test_has_set_e() {
  grep -q '^set -e' "$TEMPLATE"
}

test_has_log_redirect() {
  grep -q 'LOG=/var/log/openclaw-install.log' "$TEMPLATE"
  grep -q 'exec > >(tee -a' "$TEMPLATE"
}

test_logs_start_message() {
  grep -q 'Starting OpenClaw cloud-init (slim)' "$TEMPLATE"
}

test_logs_completion() {
  grep -q 'OpenClaw cloud-init (slim) complete!' "$TEMPLATE"
}

# ── Template Variables ───────────────────────────────────────────────────────

test_uses_timezone_var() {
  grep -q '${timezone}' "$TEMPLATE"
}

test_uses_openclaw_env_b64_var() {
  grep -q '${openclaw_env_b64}' "$TEMPLATE"
}

test_no_extra_template_vars() {
  # Extract all ${...} interpolations that look like Terraform vars.
  # Only Terraform vars use single-$ ${name} syntax (shell vars use $$ in .tftpl).
  local vars
  vars=$(grep -oE '\$\{[a-z_0-9]+\}' "$TEMPLATE" | sort -u)
  # Should only contain ${timezone} and ${openclaw_env_b64}
  local count
  count=$(echo "$vars" | wc -l | tr -d ' ')
  [[ "$count" -eq 2 ]]
  echo "$vars" | grep -q '${timezone}'
  echo "$vars" | grep -q '${openclaw_env_b64}'
}

test_no_has_config_conditional() {
  ! grep -q 'has_config' "$TEMPLATE"
}

test_no_openclaw_config_json_b64() {
  ! grep -q 'openclaw_config_json_b64' "$TEMPLATE"
}

test_no_workspace_files_b64() {
  ! grep -q 'workspace_files_b64' "$TEMPLATE"
}

test_no_custom_skills_b64() {
  ! grep -q 'custom_skills_b64' "$TEMPLATE"
}

test_no_cron_jobs_b64() {
  ! grep -q 'cron_jobs_b64' "$TEMPLATE"
}

test_no_auth_profiles_b64() {
  ! grep -q 'openclaw_auth_profiles_json_b64' "$TEMPLATE"
}

test_no_template_conditionals() {
  # Slim template should have no %{ if/for/endif/endfor } blocks
  ! grep -qE '%\{' "$TEMPLATE"
}

# ── User References ──────────────────────────────────────────────────────────

test_uses_ec2_user() {
  grep -q 'ec2-user' "$TEMPLATE"
}

test_no_openclaw_user_creation() {
  ! grep -q 'useradd.*openclaw' "$TEMPLATE"
  ! grep -q 'id -u openclaw' "$TEMPLATE"
}

test_home_dir_is_ec2_user() {
  grep -q '/home/ec2-user' "$TEMPLATE"
  ! grep -q '/home/openclaw' "$TEMPLATE"
}

# ── System Packages ──────────────────────────────────────────────────────────

test_dnf_update() {
  grep -q 'dnf update -y' "$TEMPLATE"
}

test_node22_install() {
  grep -q 'nodesource.*setup_22' "$TEMPLATE"
  grep -q 'dnf install.*nodejs' "$TEMPLATE"
}

test_base_packages() {
  grep -q 'dnf install.*git' "$TEMPLATE"
  grep -q 'dnf install.*jq' "$TEMPLATE"
  grep -q 'dnf install.*openssl' "$TEMPLATE"
  grep -q 'dnf install.*zsh' "$TEMPLATE"
}

test_no_extra_packages_var() {
  ! grep -q 'extra_packages' "$TEMPLATE"
}

# ── NPM Global Installs ─────────────────────────────────────────────────────

test_npm_global_prefix_setup() {
  grep -q 'npm config set prefix.*npm-global' "$TEMPLATE"
}

test_npm_global_tools() {
  grep -q 'npm install -g openclaw clawhub agent-browser mcporter' "$TEMPLATE"
}

# ── Claude Code ──────────────────────────────────────────────────────────────

test_claude_code_install_as_ec2_user() {
  grep -q 'su - ec2-user.*claude.ai/install.sh' "$TEMPLATE"
}

test_claude_code_npm_fallback() {
  grep -q 'npm install -g @anthropic-ai/claude-code' "$TEMPLATE"
}

test_claude_settings_json() {
  grep -q '/home/ec2-user/.claude/settings.json' "$TEMPLATE"
  grep -q '"Bash(\*)"' "$TEMPLATE"
  grep -q '"Read(\*)"' "$TEMPLATE"
  grep -q '"Write(\*)"' "$TEMPLATE"
  grep -q '"Edit(\*)"' "$TEMPLATE"
}

# ── .env File ────────────────────────────────────────────────────────────────

test_mkdir_openclaw_dir() {
  grep -q 'mkdir -p /home/ec2-user/.openclaw' "$TEMPLATE"
}

test_env_from_base64() {
  grep -q 'base64 -d > /home/ec2-user/.openclaw/.env' "$TEMPLATE"
}

test_gateway_token_generation() {
  grep -q 'GATEWAY_AUTH_TOKEN' "$TEMPLATE"
  grep -q 'openssl rand -hex 24' "$TEMPLATE"
}

test_env_permissions() {
  grep -q 'chmod 600.*/.openclaw/.env' "$TEMPLATE"
}

# ── Timezone ─────────────────────────────────────────────────────────────────

test_timezone_set() {
  grep -q 'timedatectl set-timezone' "$TEMPLATE"
}

# ── systemd Service ──────────────────────────────────────────────────────────

test_systemd_service_file() {
  grep -q 'openclaw-gateway.service' "$TEMPLATE"
}

test_systemd_service_description() {
  grep -q 'Description=OpenClaw Gateway' "$TEMPLATE"
}

test_systemd_after_network() {
  grep -q 'After=network-online.target' "$TEMPLATE"
  grep -q 'Wants=network-online.target' "$TEMPLATE"
}

test_systemd_exec_start() {
  grep -q 'ExecStart=%h/.npm-global/bin/openclaw gateway' "$TEMPLATE"
}

test_systemd_restart_always() {
  grep -q 'Restart=always' "$TEMPLATE"
  grep -q 'RestartSec=5' "$TEMPLATE"
}

test_systemd_path_includes_npm_global() {
  grep -q 'Environment=PATH=%h/.npm-global/bin' "$TEMPLATE"
}

test_systemd_environment_file() {
  grep -q 'EnvironmentFile=%h/.openclaw/.env' "$TEMPLATE"
}

test_systemd_wanted_by() {
  grep -q 'WantedBy=default.target' "$TEMPLATE"
}

test_loginctl_enable_linger() {
  grep -q 'loginctl enable-linger ec2-user' "$TEMPLATE"
}

test_systemd_user_enable() {
  grep -q 'systemctl --user enable openclaw-gateway' "$TEMPLATE"
}

test_systemd_user_daemon_reload() {
  grep -q 'systemctl --user daemon-reload' "$TEMPLATE"
}

test_xdg_runtime_dir_setup() {
  grep -q 'XDG_RUNTIME_DIR' "$TEMPLATE"
  grep -q 'id -u ec2-user' "$TEMPLATE"
}

# ── Repo Clone & Post-Clone ─────────────────────────────────────────────────

test_git_clone_repo() {
  grep -q 'git clone.*tychohq/openclaw-setup.git.*~/openclaw-setup' "$TEMPLATE"
}

test_post_clone_setup() {
  grep -q 'openclaw-setup/aws/scripts/post-clone-setup.sh' "$TEMPLATE"
}

test_clone_as_ec2_user() {
  # The git clone should run as ec2-user
  grep -q 'su - ec2-user.*git clone' "$TEMPLATE"
}

test_post_clone_as_ec2_user() {
  grep -q 'su - ec2-user.*post-clone-setup.sh' "$TEMPLATE"
}

# ── Section Ordering ─────────────────────────────────────────────────────────

test_ordering_packages_before_tools() {
  local pkg_line tool_line
  pkg_line=$(grep -n 'dnf update -y' "$TEMPLATE" | head -1 | cut -d: -f1)
  tool_line=$(grep -n 'npm install -g openclaw' "$TEMPLATE" | head -1 | cut -d: -f1)
  [[ "$pkg_line" -lt "$tool_line" ]]
}

test_ordering_tools_before_claude() {
  local tool_line claude_line
  tool_line=$(grep -n 'npm install -g openclaw' "$TEMPLATE" | head -1 | cut -d: -f1)
  claude_line=$(grep -n 'claude.ai/install.sh' "$TEMPLATE" | head -1 | cut -d: -f1)
  [[ "$tool_line" -lt "$claude_line" ]]
}

test_ordering_env_before_systemd() {
  local env_line svc_line
  env_line=$(grep -n 'openclaw_env_b64.*base64 -d' "$TEMPLATE" | head -1 | cut -d: -f1)
  svc_line=$(grep -n 'openclaw-gateway.service' "$TEMPLATE" | head -1 | cut -d: -f1)
  [[ "$env_line" -lt "$svc_line" ]]
}

test_ordering_systemd_before_clone() {
  local svc_line clone_line
  svc_line=$(grep -n 'systemctl --user enable openclaw-gateway' "$TEMPLATE" | head -1 | cut -d: -f1)
  clone_line=$(grep -n 'git clone.*openclaw-setup' "$TEMPLATE" | head -1 | cut -d: -f1)
  [[ "$svc_line" -lt "$clone_line" ]]
}

test_ordering_clone_before_post_clone() {
  local clone_line post_line
  clone_line=$(grep -n 'git clone.*openclaw-setup' "$TEMPLATE" | head -1 | cut -d: -f1)
  post_line=$(grep -n 'post-clone-setup.sh' "$TEMPLATE" | head -1 | cut -d: -f1)
  [[ "$clone_line" -lt "$post_line" ]]
}

# ── Shell Escaping ───────────────────────────────────────────────────────────

test_dollar_dollar_escaping() {
  # Terraform templates need $$ for literal $ in shell vars
  grep -q '\$\$' "$TEMPLATE"
}

# ── Run ──────────────────────────────────────────────────────────────────────

echo "cloud-init-slim.sh.tftpl test suite"
echo "===================================="
echo ""

echo "Basic Structure:"
run_test "starts with shebang"          test_starts_with_shebang
run_test "has set -e"                   test_has_set_e
run_test "has log redirect"             test_has_log_redirect
run_test "logs start message"           test_logs_start_message
run_test "logs completion"              test_logs_completion
echo ""

echo "Template Variables:"
run_test "uses timezone var"            test_uses_timezone_var
run_test "uses openclaw_env_b64 var"    test_uses_openclaw_env_b64_var
run_test "no extra template vars"       test_no_extra_template_vars
run_test "no has_config conditional"    test_no_has_config_conditional
run_test "no openclaw_config_json_b64"  test_no_openclaw_config_json_b64
run_test "no workspace_files_b64"       test_no_workspace_files_b64
run_test "no custom_skills_b64"         test_no_custom_skills_b64
run_test "no cron_jobs_b64"             test_no_cron_jobs_b64
run_test "no auth_profiles_b64"         test_no_auth_profiles_b64
run_test "no template conditionals"     test_no_template_conditionals
echo ""

echo "User References:"
run_test "uses ec2-user"                test_uses_ec2_user
run_test "no openclaw user creation"    test_no_openclaw_user_creation
run_test "home dir is ec2-user"         test_home_dir_is_ec2_user
echo ""

echo "System Packages:"
run_test "dnf update"                   test_dnf_update
run_test "node 22 install"              test_node22_install
run_test "base packages"                test_base_packages
run_test "no extra_packages var"        test_no_extra_packages_var
echo ""

echo "NPM Global Installs:"
run_test "npm global prefix setup"      test_npm_global_prefix_setup
run_test "npm global tools"             test_npm_global_tools
echo ""

echo "Claude Code:"
run_test "install as ec2-user"          test_claude_code_install_as_ec2_user
run_test "npm fallback"                 test_claude_code_npm_fallback
run_test "settings.json permissions"    test_claude_settings_json
echo ""

echo ".env File:"
run_test "mkdir .openclaw dir"          test_mkdir_openclaw_dir
run_test "env from base64"              test_env_from_base64
run_test "gateway token generation"     test_gateway_token_generation
run_test "env file permissions"         test_env_permissions
echo ""

echo "Timezone:"
run_test "timezone set"                 test_timezone_set
echo ""

echo "systemd Service:"
run_test "service file created"         test_systemd_service_file
run_test "service description"          test_systemd_service_description
run_test "after network target"         test_systemd_after_network
run_test "exec start"                   test_systemd_exec_start
run_test "restart always"               test_systemd_restart_always
run_test "path includes npm-global"     test_systemd_path_includes_npm_global
run_test "environment file"             test_systemd_environment_file
run_test "wanted by default"            test_systemd_wanted_by
run_test "loginctl enable-linger"       test_loginctl_enable_linger
run_test "systemctl user enable"        test_systemd_user_enable
run_test "systemctl daemon-reload"      test_systemd_user_daemon_reload
run_test "XDG_RUNTIME_DIR setup"        test_xdg_runtime_dir_setup
echo ""

echo "Repo Clone & Post-Clone:"
run_test "git clone repo"               test_git_clone_repo
run_test "post-clone-setup script"      test_post_clone_setup
run_test "clone as ec2-user"            test_clone_as_ec2_user
run_test "post-clone as ec2-user"       test_post_clone_as_ec2_user
echo ""

echo "Section Ordering:"
run_test "packages before tools"        test_ordering_packages_before_tools
run_test "tools before claude"          test_ordering_tools_before_claude
run_test "env before systemd"           test_ordering_env_before_systemd
run_test "systemd before clone"         test_ordering_systemd_before_clone
run_test "clone before post-clone"      test_ordering_clone_before_post_clone
echo ""

echo "Shell Escaping:"
run_test "\$\$ escaping for terraform"  test_dollar_dollar_escaping
echo ""

echo "Results: $PASS/$TOTAL passed, $FAIL failed"

if [[ $FAIL -gt 0 ]]; then
  exit 1
fi
