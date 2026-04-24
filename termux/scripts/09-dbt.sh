#!/data/data/com.termux/files/usr/bin/bash
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_SH="${RUN_DIR:-$(cd "${SCRIPT_DIR}/.." && pwd)}/lib.sh"
source "${LIB_SH}"

main() {
    echo -e "${PURPLE}Installing dbt (core + adapters)...${NC}"
    echo ""

    install_pkg_list "dbt: native deps" postgresql duckdb libduckdb libduckdb-static

    pip_install "dbt core" -- \
        dbt-core

    pip_install "dbt postgres adapter" -- \
        dbt-postgres

    # The duckdb Python bindings (the pip package 'duckdb') currently fail to build reliably on
    # Termux/Android devices because there are no manylinux wheels for this platform and building
    # from source requires a complex native build environment. We do not attempt a pip install of
    # the duckdb Python bindings here. If you need the Python bindings, either install a
    # Termux-compatible wheel you have cross-built off-device, or attempt a manual on-device build
    # outside this installer.

    info "duckdb system library installed; duckdb Python bindings and dbt-duckdb adapter are skipped."

    if [ "${INSTALL_AIRFLOW:-0}" = "1" ]; then
        warn "Installing Apache Airflow on Termux can be fragile. This will attempt a pip install; prefer Docker or a remote orchestrator if possible."
        pip_install "apache-airflow (optional)" -- \
            apache-airflow
        info "Apache Airflow install attempted (check log for details)."
    fi

    info "dbt installation attempted. Verify with: dbt --version"
}

main "$@"
