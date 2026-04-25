#!/data/data/com.termux/files/usr/bin/bash
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_SH="${RUN_DIR:-$(cd "${SCRIPT_DIR}/.." && pwd)}/lib.sh"
# shellcheck disable=SC1091
# shellcheck source=../lib.sh
source "${LIB_SH}"

main() {
    echo -e "${PURPLE}Installing Python data science stack...${NC}"
    echo ""

    install_pkg_list "Data science: native libs" libopenblas fftw

    install_pkg_list "Data science: python pkgs (pkg)" \
        python-numpy python-pandas python-scipy matplotlib python-polars python-pyarrow python-psutil

    pip_install "Python build tools" -- \
        setuptools wheel packaging \
        pyproject_metadata meson-python \
        cython versioneer setuptools-scm

    local ldflags="-lpython${PYTHON_VER}"
    pip_install "scikit-learn" \
        "MATHLIB=m" "LDFLAGS=${ldflags}" -- \
        scikit-learn

    pip_install "maturin (build backend)" -- \
        maturin

    pip_install "Jupyter / JupyterLab" "NO_BUILD_ISOLATION=1" -- \
        jupyterlab ipykernel ipywidgets

    mkdir -p "${HOME}/.jupyter"
    install_config "${CONFIG_DIR}/jupyter/jupyter_notebook_config.py" "${HOME}/.jupyter/jupyter_notebook_config.py"
    info "Jupyter configured for local-only, tokenless access (127.0.0.1 only)."

    pip_install "data utilities" -- \
        sympy plotly tqdm

    pip_install "ML utilities" -- \
        joblib threadpoolctl

    info "Data science stack installed."
    echo ""
    echo -e "  ${YELLOW}⚠  IMPORTANT: do NOT run 'pip install --upgrade pip'.${NC}"
    echo -e "  ${YELLOW}     Termux ships a patched pip; upgrading it breaks native builds.${NC}"
}

main "$@"
