## There's a lot of shared code at the beginning of `decrypt`, `sign_treehashes` and `verify_treehashes`
## so we list it out here so that it doesn't get too diverged as we fix bugs

if ! which shyaml >/dev/null 2>/dev/null; then
    die "We require shyaml to be installed for YAML parsing"
fi

# Get the `.yaml` file
if [[ "$#" -ge 3 ]]; then
    YAML_PATH="${3}"
else
    read -p 'pipeline.yaml file: ' YAML_PATH
fi

# YAML_PATH can be either a REPO_ROOT-relative path, or an absolute path
if [[ "${YAML_PATH}" != "${REPO_ROOT}"* ]] && [[ "${YAML_PATH}" == /* ]]; then
    die "File path must be either a repo-relative path, or an absolute path within the repo root"
fi
YAML_PATH="${YAML_PATH#${REPO_ROOT}/}"


# Extract the `variables:` section of a cryptic `pipeline.yml` plugin section
function extract_encrypted_variables() {
    # Iterate over the steps in the yaml file
    (shyaml get-values-0 steps <"${1}" || true) |
    while IFS='' read -r -d '' STEP; do
        # For each step, get its list of plugins
        (shyaml get-values-0 plugins <<<"${STEP}" 2>/dev/null || true) |
        while IFS='' read -r -d '' PLUGIN; do
            # For each plugin, if its `cryptic`, extract the variables
            (shyaml get-values-0 "staticfloat/cryptic.variables" <<<"${PLUGIN}" 2>/dev/null || true) |
            while IFS='' read -r -d '' VAR; do
                printf "%s\n" "${VAR}"
            done
        done
    done    
}

# Extract the `files:` section of a cryptic `pipeline.yml` plugin section
function extract_encrypted_files() {
    # Iterate over the steps in the yaml file
    (shyaml get-values-0 steps <"${1}" || true) |
    while IFS='' read -r -d '' STEP; do
        # For each step, get its list of plugins
        (shyaml get-values-0 plugins <<<"${STEP}" 2>/dev/null || true) |
        while IFS='' read -r -d '' PLUGIN; do
            # For each plugin, if its `cryptic`, extract the files
            (shyaml get-values-0 "staticfloat/cryptic.files" <<<"${PLUGIN}" 2>/dev/null || true) |
            while IFS='' read -r -d '' FILE; do
                FILE="$(echo ${FILE} | tr -d '"')"
                printf "%s\n" "${FILE}"
            done
        done
    done    
}

# Calculate the treehashes of each locked pipeline defined within a launching `.yml` file
function calculate_locked_pipeline_treehashes() {
    # Most of our paths are relative to the root directory, so this is just easier
    pushd "${REPO_ROOT}" >/dev/null

    # Iterate over the steps in the yaml file
    (shyaml get-values-0 steps <"${1}" || true) |
    while IFS='' read -r -d '' STEP; do
        # For each step, get its list of plugins
        (shyaml get-values-0 plugins <<<"${STEP}" 2>/dev/null || true) |
        while IFS='' read -r -d '' PLUGIN; do
            # For each plugin, if its `cryptic`, walk over the  the variables
            (shyaml get-values-0 "staticfloat/cryptic.locked_pipelines" <<<"${PLUGIN}" 2>/dev/null || true) |
            while IFS='' read -r -d '' PIPELINE; do
                # For each locked pipeline, get its pipeline path and its inputs
                PIPELINE_PATH=$(shyaml get-value "pipeline" <<<"${PIPELINE}" 2>/dev/null || true)

                # Start by calculating the treehash of the yaml file
                INPUT_TREEHASHES=( "$(calc_treehash <<<"${PIPELINE_PATH}")" )

                # Next, calculate the treehash of the rest of the glob patterns
                for PATTERN in $(shyaml get-values "inputs" <<<"${PIPELINE}" 2>/dev/null || true); do
                    INPUT_TREEHASHES+=( "$(collect_glob_pattern "${PATTERN}" | calc_treehash)" )
                done
                
                # Calculate full treehash
                FULL_TREEHASH="$(printf "%s" "${INPUT_TREEHASHES[@]}" | calc_shasum)"

                # Print out treehash and pipeline path
                printf "%s&%s\n" "${PIPELINE_PATH}" "${FULL_TREEHASH}"
            done
        done
    done

    # Don't stay in `${REPO_ROOT}`
    popd >/dev/null
}

# Calculate the treehashes of each locked pipeline defined within a launching `.yml` file
function extract_pipeline_signatures() {
    # Most of our paths are relative to the root directory, so this is just easier
    pushd "${REPO_ROOT}" >/dev/null

    # Iterate over the steps in the yaml file
    (shyaml get-values-0 steps <"${1}" || true) |
    while IFS='' read -r -d '' STEP; do
        # For each step, get its list of plugins
        (shyaml get-values-0 plugins <<<"${STEP}" 2>/dev/null || true) |
        while IFS='' read -r -d '' PLUGIN; do
            # For each plugin, if its `cryptic`, walk over the  the variables
            (shyaml get-values-0 "staticfloat/cryptic.locked_pipelines" <<<"${PLUGIN}" 2>/dev/null || true) |
            while IFS='' read -r -d '' PIPELINE; do
                # For each locked pipeline, get its pipeline path and its inputs
                (shyaml get-value "signature" <<<"${PIPELINE}" 2>/dev/null || true)
            done
        done
    done

    # Don't stay in `${REPO_ROOT}`
    popd >/dev/null
}
