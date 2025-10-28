#!/bin/bash
set -e

# Parse arguments
HELP=false
NEW_ENV=false
OMNIGIBSON=false
BDDL=false
JOYLO=false
DATASET=false
PRIMITIVES=false
EVAL=false
ASSET_PIPELINE=false
DEV=false
CUDA_VERSION="12.4"
ACCEPT_NVIDIA_EULA=false
ACCEPT_DATASET_TOS=false

[ "$#" -eq 0 ] && HELP=true

while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help) HELP=true; shift ;;
        --new-env) NEW_ENV=true; shift ;;
        --omnigibson) OMNIGIBSON=true; shift ;;
        --bddl) BDDL=true; shift ;;
        --joylo) JOYLO=true; shift ;;
        --dataset) DATASET=true; shift ;;
        --primitives) PRIMITIVES=true; shift ;;
        --eval) EVAL=true; shift ;;
        --asset-pipeline) ASSET_PIPELINE=true; shift ;;
        --dev) DEV=true; shift ;;
        --cuda-version) CUDA_VERSION="$2"; shift 2 ;;
        --accept-nvidia-eula) ACCEPT_NVIDIA_EULA=true; shift ;;
        --accept-dataset-tos) ACCEPT_DATASET_TOS=true; shift ;;
        *) echo "Unknown option: \$1"; exit 1 ;;
    esac
done

if [ "$HELP" = true ]; then
    cat << EOF
BEHAVIOR-1K Installation Script (Linux)
Usage: ./setup.sh [OPTIONS]

Options:
  -h, --help              Display this help message
  --new-env               Create a new uv-managed Python 3.10 environment '.venv_behavior'
  --omnigibson            Install OmniGibson (core physics simulator)
  --bddl                  Install BDDL (Behavior Domain Definition Language)
  --joylo                 Install JoyLo (teleoperation interface)
  --dataset               Download BEHAVIOR datasets (requires --omnigibson)
  --primitives            Install OmniGibson with primitives support
  --eval                  Install evaluation dependencies
  --asset-pipeline        Install the 3D scene and object asset pipeline
  --dev                   Install development dependencies
  --cuda-version VERSION  Specify CUDA version (default: 12.4)
  --accept-nvidia-eula    Automatically accept NVIDIA Isaac Sim EULA
  --accept-dataset-tos    Automatically accept BEHAVIOR Dataset Terms

Example: ./setup.sh --new-env --omnigibson --bddl --joylo --dataset
Example (non-interactive): ./setup.sh --new-env --omnigibson --dataset --accept-nvidia-eula --accept-dataset-tos
EOF
    exit 0
fi

# Validate dependencies
[ "$OMNIGIBSON" = true ] && [ "$BDDL" = false ] && { echo "ERROR: --omnigibson requires --bddl"; exit 1; }
[ "$PRIMITIVES" = true ] && [ "$OMNIGIBSON" = false ] && { echo "ERROR: --primitives requires --omnigibson"; exit 1; }
[ "$EVAL" = true ] && [ "$OMNIGIBSON" = false ] && { echo "ERROR: --eval requires --omnigibson"; exit 1; }
[ "$EVAL" = true ] && [ "$JOYLO" = false ] && { echo "ERROR: --eval requires --joylo"; exit 1; }

WORKDIR=$(pwd)

# Ensure local packages are importable when using editable installs
BBDL_PACKAGE_PATH="$WORKDIR/bddl"
if [ -d "$BBDL_PACKAGE_PATH" ]; then
    case ":${PYTHONPATH:-}:" in
        *":$BBDL_PACKAGE_PATH:"*) ;;
        *) export PYTHONPATH="$BBDL_PACKAGE_PATH${PYTHONPATH:+:$PYTHONPATH}" ;;
    esac
fi

PYTHON_PRELUDE=""
if [ -d "$BBDL_PACKAGE_PATH" ]; then
    printf -v PYTHON_PRELUDE "import sys; sys.path.insert(0, '%s');" "$BBDL_PACKAGE_PATH"
fi

# Function to prompt for terms acceptance
prompt_for_terms() {
    echo ""
    echo "=== TERMS OF SERVICE AND LICENSING AGREEMENTS ==="
    echo ""
    
    NEEDS_NVIDIA_EULA=false
    NEEDS_DATASET_TOS=false

    if [ "$OMNIGIBSON" = true ] && [ "$ACCEPT_NVIDIA_EULA" = false ]; then
        NEEDS_NVIDIA_EULA=true
    fi

    if [ "$DATASET" = true ] && [ "$ACCEPT_DATASET_TOS" = false ]; then
        NEEDS_DATASET_TOS=true
    fi

    if [ "$NEEDS_NVIDIA_EULA" = false ] && [ "$NEEDS_DATASET_TOS" = false ]; then
        return 0
    fi

    echo "This installation requires acceptance of the following terms:"
    echo ""

    counter=1

    if [ "$NEEDS_NVIDIA_EULA" = true ]; then
        cat << EOF
${counter}. NVIDIA ISAAC SIM EULA
   - Required for OmniGibson installation
   - By accepting, you agree to NVIDIA Isaac Sim End User License Agreement
   - See: https://www.nvidia.com/en-us/agreements/enterprise-software/nvidia-software-license-agreement

EOF
        counter=$((counter + 1))
    fi
    
    if [ "$NEEDS_DATASET_TOS" = true ]; then
        cat << EOF
${counter}. BEHAVIOR DATA BUNDLE END USER LICENSE AGREEMENT
    Last revision: December 8, 2022
    This License Agreement is for the BEHAVIOR Data Bundle (“Data”). It works with OmniGibson (“Software”) which is a software stack licensed under the MIT License, provided in this repository: https://github.com/StanfordVL/BEHAVIOR-1K. 
    The license agreements for OmniGibson and the Data are independent. This BEHAVIOR Data Bundle contains artwork and images (“Third Party Content”) from third parties with restrictions on redistribution. 
    It requires measures to protect the Third Party Content which we have taken such as encryption and the inclusion of restrictions on any reverse engineering and use. 
    Recipient is granted the right to use the Data under the following terms and conditions of this License Agreement (“Agreement”):
        1. Use of the Data is permitted after responding "Yes" to this agreement. A decryption key will be installed automatically.
        2. Data may only be used for non-commercial academic research. You may not use a Data for any other purpose.
        3. The Data has been encrypted. You are strictly prohibited from extracting any Data from OmniGibson or reverse engineering.
        4. You may only use the Data within OmniGibson.
        5. You may not redistribute the key or any other Data or elements in whole or part.
        6. THE DATA AND SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. 
            IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE DATA OR SOFTWARE OR THE USE OR OTHER DEALINGS IN THE DATA OR SOFTWARE.

EOF
    fi
    
    echo "Do you accept ALL of the above terms? (y/N)"
    read -r response
    
    if [[ ! "$response" =~ ^[Yy]$ ]]; then
        echo "Terms not accepted. Installation cancelled."
        echo "You can bypass these prompts by using --accept-nvidia-eula and --accept-dataset-tos flags."
        exit 1
    fi
    
    # Set acceptance flags
    [ "$NEEDS_NVIDIA_EULA" = true ] && ACCEPT_NVIDIA_EULA=true
    [ "$NEEDS_DATASET_TOS" = true ] && ACCEPT_DATASET_TOS=true
    
    echo ""
    echo "✓ All terms accepted. Proceeding with installation..."
    echo ""
}

# Prompt for terms acceptance at the beginning
prompt_for_terms

# Ensure uv is available for package management
command -v uv >/dev/null || { echo "ERROR: uv not found"; exit 1; }

ENV_PATH="$WORKDIR/.venv_behavior"
ACTIVE_PYTHON=""
ENV_ALREADY_EXISTS=false

# Create uv-managed environment when requested
if [ "$NEW_ENV" = true ]; then
    if [ -d "$ENV_PATH" ]; then
        echo "Reusing existing uv environment '.venv_behavior'..."
        ENV_ALREADY_EXISTS=true
    else
        echo "Creating uv environment '.venv_behavior'..."
        echo "Ensuring Python 3.10 is available via uv..."
        uv python install 3.10 >/dev/null 2>&1
        uv venv --python 3.10 "$ENV_PATH"
    fi

    # shellcheck disable=SC1090
    source "$ENV_PATH/bin/activate"
    ACTIVE_PYTHON="$ENV_PATH/bin/python"
else
    ACTIVE_PYTHON=$(command -v python)
fi

if [ -z "$ACTIVE_PYTHON" ]; then
    echo "ERROR: Unable to resolve target Python interpreter"
    exit 1
fi

run_python() {
    local code="$1"
    "$ACTIVE_PYTHON" -c "${PYTHON_PRELUDE}${code}"
}

uv_pip_install() {
    uv pip install --python "$ACTIVE_PYTHON" "$@"
}

uv_pip_show() {
    uv pip show --python "$ACTIVE_PYTHON" "$@"
}

if [ "$NEW_ENV" = true ] && [ "$ENV_ALREADY_EXISTS" = false ]; then
    echo "Installing numpy and setuptools..."
    uv_pip_install "numpy<2" "setuptools<=79"

    echo "Installing PyTorch with CUDA $CUDA_VERSION support..."
    CUDA_VER_SHORT=$(echo "$CUDA_VERSION" | sed 's/\.//g')
    uv_pip_install --index-url "https://download.pytorch.org/whl/cu${CUDA_VER_SHORT}" \
        torch==2.6.0 torchvision==0.21.0 torchaudio==2.6.0
    echo "✓ PyTorch installation completed"
elif [ "$NEW_ENV" = true ]; then
    echo "Skipping base package install because '.venv_behavior' already exists"
fi
# Install BDDL
if [ "$BDDL" = true ]; then
    echo "Installing BDDL..."
    [ ! -d "bddl" ] && { echo "ERROR: bddl directory not found"; exit 1; }
    uv_pip_install --editable "$WORKDIR/bddl"
fi

# Install OmniGibson with Isaac Sim
if [ "$OMNIGIBSON" = true ]; then
    echo "Installing OmniGibson..."
    [ ! -d "OmniGibson" ] && { echo "ERROR: OmniGibson directory not found"; exit 1; }
    
    # Check Python version
    PYTHON_VERSION=$(run_python "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')")
    [ "$PYTHON_VERSION" != "3.10" ] && { echo "ERROR: Python 3.10 required, found $PYTHON_VERSION"; exit 1; }
    
    # Check for conflicting environment variables
    if [[ -n "$EXP_PATH" || -n "$CARB_APP_PATH" || -n "$ISAAC_PATH" ]]; then
        echo "ERROR: Found existing Isaac Sim environment variables."
        echo "Please unset EXP_PATH, CARB_APP_PATH, and ISAAC_PATH and restart."
        exit 1
    fi
    
    # Build extras
    EXTRAS=""
    if [ "$DEV" = true ]; then
        EXTRAS="${EXTRAS}dev,"
    fi
    if [ "$PRIMITIVES" = true ]; then
        EXTRAS="${EXTRAS}primitives,"
    fi
    if [ "$EVAL" = true ]; then
        EXTRAS="${EXTRAS}eval,"
    fi
    # Remove trailing comma, if any, and add brackets only if EXTRAS is not empty
    if [ -n "$EXTRAS" ]; then
        EXTRAS="[${EXTRAS%,}]"
    fi

    uv_pip_install --editable "$WORKDIR/OmniGibson$EXTRAS"

    # Install pre-commit for dev setup
    if [ "$DEV" = true ]; then
        echo "Setting up pre-commit..."
        uv_pip_install pre-commit
        cd "$WORKDIR/OmniGibson"
        pre-commit install
        cd "$WORKDIR"
    fi
    
    # Isaac Sim installation via pip
    if [ "$ACCEPT_NVIDIA_EULA" = true ]; then
        export OMNI_KIT_ACCEPT_EULA=YES
    else
        echo "ERROR: NVIDIA EULA not accepted. Cannot install Isaac Sim."
        exit 1
    fi
    
    # Check if already installed
    if run_python "import isaacsim" 2>/dev/null; then
        echo "Isaac Sim already installed, skipping..."
    else
        echo "Installing Isaac Sim via pip..."
        
        # Helper functions
        check_glibc_old() {
            ldd --version 2>&1 | grep -qE "2\.(31|32|33)"
        }
        
        install_isaac_packages() {
            local temp_dir=$(mktemp -d)
            local packages=(
                "omniverse_kit-106.5.0.162521" "isaacsim_kernel-4.5.0.0" "isaacsim_app-4.5.0.0"
                "isaacsim_core-4.5.0.0" "isaacsim_gui-4.5.0.0" "isaacsim_utils-4.5.0.0"
                "isaacsim_storage-4.5.0.0" "isaacsim_asset-4.5.0.0" "isaacsim_sensor-4.5.0.0"
                "isaacsim_robot_motion-4.5.0.0" "isaacsim_robot-4.5.0.0" "isaacsim_benchmark-4.5.0.0"
                "isaacsim_code_editor-4.5.0.0" "isaacsim_ros1-4.5.0.0" "isaacsim_cortex-4.5.0.0"
                "isaacsim_example-4.5.0.0" "isaacsim_replicator-4.5.0.0" "isaacsim_rl-4.5.0.0"
                "isaacsim_robot_setup-4.5.0.0" "isaacsim_ros2-4.5.0.0" "isaacsim_template-4.5.0.0"
                "isaacsim_test-4.5.0.0" "isaacsim-4.5.0.0" "isaacsim_extscache_physics-4.5.0.0"
                "isaacsim_extscache_kit-4.5.0.0" "isaacsim_extscache_kit_sdk-4.5.0.0"
            )
            
            local wheel_files=()
            for pkg in "${packages[@]}"; do
                local pkg_name=${pkg%-*}
                local filename="${pkg}-cp310-none-manylinux_2_34_x86_64.whl"
                local url="https://pypi.nvidia.com/${pkg_name//_/-}/$filename"
                local filepath="$temp_dir/$filename"
                
                echo "Downloading $pkg..."
                if ! curl -sL "$url" -o "$filepath"; then
                    echo "ERROR: Failed to download $pkg"
                    rm -rf "$temp_dir"
                    return 1
                fi
                
                # Rename for older GLIBC
                if check_glibc_old; then
                    local new_filepath="${filepath/manylinux_2_34/manylinux_2_31}"
                    mv "$filepath" "$new_filepath"
                    filepath="$new_filepath"
                fi
                
                wheel_files+=("$filepath")
            done
            
            echo "Installing Isaac Sim packages..."
            uv_pip_install "${wheel_files[@]}"
            rm -rf "$temp_dir"
            
            # Verify installation
            if ! run_python "import isaacsim" 2>/dev/null; then
                echo "ERROR: Isaac Sim installation verification failed"
                return 1
            fi
        }
        
        install_isaac_packages || { echo "ERROR: Isaac Sim installation failed"; exit 1; }
        
        # Fix cryptography conflict - remove conflicting version
        if [ -n "$ISAAC_PATH" ] && [ -d "$ISAAC_PATH/exts/omni.pip.cloud/pip_prebundle/cryptography" ]; then
            echo "Fixing cryptography conflict..."
            rm -rf "$ISAAC_PATH/exts/omni.pip.cloud/pip_prebundle/cryptography"
        fi
    fi
    
    echo "OmniGibson installation completed successfully!"
fi

# Install JoyLo
if [ "$JOYLO" = true ]; then
    echo "Installing JoyLo..."
    [ ! -d "joylo" ] && { echo "ERROR: joylo directory not found"; exit 1; }
    uv_pip_install --editable "$WORKDIR/joylo"
fi

# Install Eval
if [ "$EVAL" = true ]; then
    # get torch version via uv and install corresponding torch-cluster
    TORCH_VERSION=$(uv_pip_show torch | grep Version | cut -d " " -f 2)
    uv_pip_install -f "https://data.pyg.org/whl/torch-${TORCH_VERSION}.html" torch-cluster
    # install av and pin numpy below 2 for compatibility
    uv_pip_install av "numpy<2"
fi
    
# Install asset pipeline
if [ "$ASSET_PIPELINE" = true ]; then
    echo "Installing asset pipeline..."
    [ ! -d "asset_pipeline" ] && { echo "ERROR: asset_pipeline directory not found"; exit 1; }
    uv_pip_install -r "$WORKDIR/asset_pipeline/requirements.txt"
fi

# Install datasets
if [ "$DATASET" = true ]; then
    run_python "import omnigibson" || {
        echo "ERROR: OmniGibson import failed, please make sure you have omnigibson installed before downloading datasets"
        exit 1
    }
    
    echo "Installing datasets..."
    
    # Determine if we should accept dataset license automatically
    DATASET_ACCEPT_FLAG=""
    if [ "$ACCEPT_DATASET_TOS" = true ]; then
        DATASET_ACCEPT_FLAG="True"
    else
        DATASET_ACCEPT_FLAG="False"
    fi
    
    export OMNI_KIT_ACCEPT_EULA=YES
    
    echo "Downloading OmniGibson robot assets..."
    run_python "from omnigibson.utils.asset_utils import download_omnigibson_robot_assets; download_omnigibson_robot_assets()" || {
        echo "ERROR: OmniGibson robot assets installation failed"
        exit 1
    }

    echo "Downloading BEHAVIOR-1K assets..."
    run_python "from omnigibson.utils.asset_utils import download_behavior_1k_assets; download_behavior_1k_assets(accept_license=${DATASET_ACCEPT_FLAG})" || {
        echo "ERROR: Dataset installation failed"
        exit 1
    }

    echo "Downloading 2025 BEHAVIOR Challenge Task Instances..."
    run_python "from omnigibson.utils.asset_utils import download_2025_challenge_task_instances; download_2025_challenge_task_instances()" || {
        echo "ERROR: 2025 BEHAVIOR Challenge Task Instances installation failed"
        exit 1
    }
fi

echo ""
echo "=== Installation Complete! ==="
if [ "$NEW_ENV" = true ]; then echo "✓ Created uv environment '.venv_behavior'"; fi
if [ "$OMNIGIBSON" = true ]; then echo "✓ Installed OmniGibson + Isaac Sim"; fi
if [ "$BDDL" = true ]; then echo "✓ Installed BDDL"; fi
if [ "$JOYLO" = true ]; then echo "✓ Installed JoyLo"; fi
if [ "$PRIMITIVES" = true ]; then echo "✓ Installed OmniGibson with primitives support"; fi
if [ "$EVAL" = true ]; then echo "✓ Installed evaluation support"; fi
if [ "$DATASET" = true ]; then echo "✓ Downloaded datasets"; fi
echo ""
if [ "$NEW_ENV" = true ]; then echo "To activate: source .venv_behavior/bin/activate"; fi
