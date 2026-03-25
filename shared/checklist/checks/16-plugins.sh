#!/bin/bash
# Check: Custom plugins installed via openclaw plugins list --json

check_plugins() {
    section "CUSTOM PLUGINS"

    if ! has_cmd openclaw; then
        report_result "plugins.status" "fail" "openclaw CLI not found" \
            "Install openclaw to check plugins"
        return
    fi

    # ── Fetch plugin list (JSON) ───────────────────────────────────────────────
    local raw_output json_output
    raw_output=$(safe_timeout 30 openclaw plugins list --json 2>&1)

    # Strip stderr noise (e.g. [plugins] [lcm] lines) before feeding to jq
    json_output=$(echo "$raw_output" | grep -v '^\[plugins\]')

    if [ -z "$json_output" ] || ! echo "$json_output" | jq empty 2>/dev/null; then
        report_result "plugins.status" "fail" \
            "openclaw plugins list --json returned invalid output" \
            "openclaw plugins list  # check manually"
        return
    fi

    # ── Count by origin ────────────────────────────────────────────────────────
    # "bundled" = stock plugins shipped with openclaw
    # "config"  = loaded via plugins.load.paths in openclaw.json
    # "global"  = discovered from ~/.openclaw/extensions/
    local total_loaded custom_count
    total_loaded=$(echo "$json_output" | jq '[.plugins[] | select(.status == "loaded")] | length')
    custom_count=$(echo "$json_output" | jq '[.plugins[] | select(.origin != "bundled" and .status == "loaded")] | length')

    report_result "plugins.summary" "pass" \
        "${total_loaded} plugins loaded (${custom_count} custom)"

    # ── List each custom plugin ────────────────────────────────────────────────
    if [ "${custom_count:-0}" -gt 0 ]; then
        local plugin_lines
        plugin_lines=$(echo "$json_output" | jq -r '
            .plugins[]
            | select(.origin != "bundled" and .status == "loaded")
            | "\(.id)|\(.name // .id)|\(.version // "—")|\(.origin)"
        ')

        while IFS='|' read -r pid pname pver porigin; do
            [ -z "$pid" ] && continue
            local ver_display=""
            [ "$pver" != "—" ] && [ -n "$pver" ] && [ "$pver" != "null" ] && ver_display=" v${pver}"
            info_msg "${pname}${ver_display} (${porigin}, id: ${pid})"
        done <<< "$plugin_lines"
    fi

    # ── Check for custom plugins that failed to load ───────────────────────────
    local failed_custom
    failed_custom=$(echo "$json_output" | jq -r '
        .plugins[]
        | select(.origin != "bundled" and .status != "loaded" and .status != "disabled")
        | "\(.id)|\(.name // .id)|\(.status)"
    ')

    if [ -n "$failed_custom" ]; then
        while IFS='|' read -r pid pname pstatus; do
            [ -z "$pid" ] && continue
            report_result "plugins.error.${pid}" "warn" \
                "${pname} failed to load (status: ${pstatus})" \
                "openclaw plugins doctor  # diagnose load errors"
        done <<< "$failed_custom"
    fi

    # ── Check for enabled-but-not-loaded custom plugins ────────────────────────
    local enabled_not_loaded
    enabled_not_loaded=$(echo "$json_output" | jq '[.plugins[] | select(.origin != "bundled" and .enabled == true and .status != "loaded")] | length')

    if [ "${enabled_not_loaded:-0}" -gt 0 ]; then
        report_result "plugins.enabled_not_loaded" "warn" \
            "${enabled_not_loaded} custom plugin(s) enabled but not loaded" \
            "openclaw plugins doctor  # check for missing deps or config errors"
    fi
}
