#!/usr/bin/env nextflow

// PIPELINE PARAMETERS

// input possibilities
params.input_file = null
params.url = null
params.default_url = "https://zenodo.org/record/RECORD_ID/FILENAME"

// output directory
params.outdir = "results"

// tool installation, reinstallation, caching
params.tool_cache_dir = "$HOME/.nextflow_tool_cache"
params.force_reinstall = false

// help message
params.help = false

// HELP COMMAND LINE MESSAGE
if (params.help) {
    log.info """
    CSYNCMER_FAST BENCHMARKING PIPELINE
    ===================================

    Usage:
    nextflow run benchmark.nf [options]
    nextflow run benchmark.nf --url <URL> --outdir <DIR>
    nextflow run benchmark.nf --input_file <FASTA/Q> --outdir <DIR>

    Input options (priority order):
    --input_file        Path to fasta/q file for benchmark
    --url               URL to some file for benchmark
    (default)           Pre-configured url will be used if neither above provided

    Other options:
    --outdir            Output directory (default: results)
    --force_reinstall   If reinstallation of source code tools is needed
    --help              Show this help message

    """
    exit 0
}

// RECORD RUN INFO 
process RECORD_RUN_INFO {
    label 'low_resources'
    publishDir "${params.run_outdir}", mode: 'copy'

    output:
    path "run.record", emit: record

    script:
    """
    
    RECORD_FILE="run.record"
    
    echo "=====================================" > \$RECORD_FILE
    echo "NEXTFLOW RUN RECORD" >> \$RECORD_FILE
    echo "=====================================" >> \$RECORD_FILE
    echo "" >> \$RECORD_FILE

    # Timestamp information
    echo "Run Information:" >> \$RECORD_FILE
    echo "----------------" >> \$RECORD_FILE
    echo "Date (UTC): \$(date -u '+%Y-%m-%d %H:%M:%S')" >> \$RECORD_FILE

    echo "Nextflow version: ${nextflow.version}" >> \$RECORD_FILE
    echo "Pipeline version: ${workflow.manifest.version}" >> \$RECORD_FILE
    echo "Run name: ${workflow.runName}" >> \$RECORD_FILE
    echo "Session ID: ${workflow.sessionId}" >> \$RECORD_FILE
    echo "" >> \$RECORD_FILE

    # 2 - Record system information
    echo "System Information:" >> \$RECORD_FILE
    echo "-------------------" >> \$RECORD_FILE
    echo "System INFO: \$(uname -a)" >> \$RECORD_FILE
    echo "" >> \$RECORD_FILE

    # 3 - Record processor information
    echo "CPU Architecture Information:" >> \$RECORD_FILE
    echo "----------------------" >> \$RECORD_FILE
    # Get CPU architecture information
    echo "\$(lscpu) " >> \$RECORD_FILE
    echo "" >> \$RECORD_FILE

    # 4 - Record memory information
    # Memory information
    echo "Memory Information:" >> \$RECORD_FILE
    echo "-------------------" >> \$RECORD_FILE
    echo "\$(free -h)" >> \$RECORD_FILE
    echo "" >> \$RECORD_FILE

    # 5 - Record pipeline configuration
    echo "Pipeline Configuration:" >> \$RECORD_FILE
    echo "-----------------------" >> \$RECORD_FILE
    echo "Work directory: ${workflow.workDir}" >> \$RECORD_FILE
    echo "Launch directory: ${workflow.launchDir}" >> \$RECORD_FILE
    echo "Profile: ${workflow.profile}" >> \$RECORD_FILE
    echo "Container engine: ${workflow.containerEngine ?: 'none'}" >> \$RECORD_FILE
    echo "" >> \$RECORD_FILE
    
    # Execution timeline
    echo "Execution Details:" >> \$RECORD_FILE
    echo "------------------" >> \$RECORD_FILE
    echo "Start time: ${workflow.start}" >> \$RECORD_FILE
    echo "Complete time: \$(date)" >> \$RECORD_FILE
    """
}

// GET INPUT FASTA
process GET_FASTA_INPUT {
    label 'low_resources'
    publishDir "${params.input_file_dir}", mode: 'copy'

    output:
    path "test_file.*", emit: file
    path "input.info", emit: info

    script:

    if (params.input_file){

        """
        # IF THE USER GIVES THE INPUT FILE
        # Creating a symbolic link to the given file
        INPUT_PATH=${params.input_file}

        # Checking if file exists
        if [ ! -f "\${INPUT_PATH}" ]
        then
            echo "Error: Input File \${INPUT_PATH} does not exist."
            exit 1
        fi

        # Getting the file extension
        if [[ "\${INPUT_PATH}" == *.gz ]]; then
            EXTENSION="gz"
        elif [[ "\${INPUT_PATH}" == *.fasta || "\${INPUT_PATH}" == *.fa ]]; then
            EXTENSION="fasta"
        elif [[ "\${INPUT_PATH}" == *.fastq || "\${INPUT_PATH}" == *.fq ]]; then
            EXTENSION="fastq"
        fi

        # Creating the symbolic link
        ln -s "\${INPUT_PATH}" "test_file.\${EXTENSION}"

        # Creating the information file
        echo "Input source: Local file (symlink)" > input.info
        echo "Original path: \${INPUT_PATH}" >> input.info
        echo "File name: \$(basename "\${INPUT_PATH}")" >> input.info
        FILE_SIZE=\$(stat -c%s "\${INPUT_PATH}" 2>/dev/null || stat -f%z "\${INPUT_PATH}" 2>/dev/null || echo "unknown")
        echo "File size: \${FILE_SIZE} bytes" >> input.info

        """
    
    } else {
        
        def download_url = params.url ?: params.default_url
        def url_source = params.url ? "User-provided URL" : "Default URL"

        """
        # IF THE USER GIVES AN URL OR IF THE USER DOES NOT GIVE ANYTHING
        echo "Downloading from: ${download_url}"

        # Create cache directory
        CACHE_DIR="${params.cache_dir}"
        mkdir -p "\${CACHE_DIR}"

        # Generate cache filename based on URL
        URL_HASH=\$(echo "${download_url}" | md5sum | cut -d' ' -f1 | head -c 16)
        FILENAME=\$(basename "${download_url}")
        CACHED_FILE="\${CACHE_DIR}/\${URL_HASH}_\${FILENAME}"

        # Check if already cached
        if [ -f "\${CACHED_FILE}" ] && [ "${url_source}" == "Default URL" ]; then
            echo "Using cached file: \${CACHED_FILE}"
            ln -s "\${CACHED_FILE}" "input_file.\${FILENAME##*.}"
        else
            echo "Downloading file..."
            # Download with proper filename
            wget -O "temp_download" "${download_url}" || curl -L -o "temp_download" "${download_url}"
            
            # Determine extension from filename or content
            EXTENSION="\${FILENAME##*.}"
            if [[ "\${EXTENSION}" == "" || "\${EXTENSION}" == "\${FILENAME}" ]]; then
                # Try to detect from content
                if gunzip -t temp_download 2>/dev/null; then
                    EXTENSION="gz"
                else
                    EXTENSION="fasta"
                fi
            fi
            
            # Move to final location
            mv temp_download "input_file.\${EXTENSION}"
            # Cache if it's the default URL
            if [ "${url_source}" == "Default URL" ]; then
                cp "input_file.\${EXTENSION}" "\${CACHED_FILE}"
            fi
        fi

        # Creating info file
        echo "Input source: ${url_source}" > input.info
        echo "URL: ${download_url}" >> input.info
        echo "File name: \${FILENAME}" >> input.info
        FILE_SIZE=\$(stat -c%s "input_file."* 2>/dev/null || stat -f%z "input_file."* 2>/dev/null || echo "unknown")
        echo "File size: \${FILE_SIZE} bytes" >> input.info
        echo "\${FILE_SIZE}" >> input.info

        """
    }

}

// CSYNCMER_FAST BENCHMARK
process BENCHMARK_CSYNCMER_FAST {
    label 'normal_resources'
    publishDir "${params.benchmark_dir}", mode: 'copy'

    input:
    path input_file

    output:
    path "csyncmer_fast_benchmark.tsv", emit: benchmark

    script:
    """
    # Run csyncmer fast on the input sequence

    # Run script to get speed
    """
}

// CSYNCMER_FAST_AVX512 BENCHMARK 
process BENCHMARK_CSYNCMER_FAST_AVX512 {
    label 'normal_resources'
    publishDir "${params.benchmark_dir}", mode: 'copy'

    input: 
    path input_file

    output:
    path "csyncmer_fast_AVX512_benchmark.tsv", emit: benchmark

    script:
    """
    # if path to binary does not exist
    if [ ! -f "${workflow.projectDir}/tools/ntHash-AVX512/nttest" ] || [ "${params.force_reinstall}" == "true" ]; then
        # build the test suite
        NF_WORKDIR="\${PWD}"
        cd "${workflow.projectDir}/tools/ntHash-AVX512"
        ./autogen.sh
        ./configure --prefix="${workflow.projectDir}/tools/ntHash-AVX512"
        make
        make install
        cd "\$NF_WORKDIR" 
    fi

    # run test on input file 
    ${workflow.projectDir}/tools/ntHash-AVX512/nttest --kmer=31 ${input_file} > csyncmer_fast_AVX512_benchmark.tsv 2>&1
    
    # parse output and print speed

    """
}

// DIGEST BENCHMARK 
process BENCHMARK_DIGEST {
    
    label 'normal_resources'
    conda 'python=3.13 bioconda::digest'
    publishDir "${params.benchmark_dir}", mode: 'copy'

    input:
    path input_file

    output:
    path "digest_benchmark.tsv", emit: benchmark

    script:
    """
    ${workflow.projectDir}/tools/digest_benchmark.py -i ${input_file} -o digest_benchmark.tsv
    """
}

// SYNCMER ORIGINAL IMPLEMENTATION BENCHMARK (EDGAR)
process BENCHMARK_SYNCMER_ORIGINAL {
    label 'normal_resources'
    publishDir "${params.benchmark_dir}", mode: 'copy'

    input: 
    path input_file

    output:
    path "original_implementation_benchmark.tsv", emit: benchmark

    script:
    """
    # if path to binary does not exist
    if [ ! -f "${workflow.projectDir}/tools/syncmer_original/o/syncmer" ] || [ "${params.force_reinstall}" == "true" ]; then
        # build the test suite
        NF_WORKDIR="\${PWD}"
        cd "${workflow.projectDir}/tools/syncmer_original"
        make clean && make -j
        cd "\$NF_WORKDIR" 
    fi

    # run test on input file 
    ${workflow.projectDir}/tools/syncmer_originalo/syncmer -speedbench 1 -input ${input_file} -k 31 -t 16 -algo 6 > original_implementation_benchmark.tsv 2>&1
    
    # parse output and print speed

    """
}

// SIMD MINIMIZER BENCHMARK
process BENCHMARK_SIMD_MINIMIZER {
    label 'normal_resources'
    conda 'conda-forge::rust conda-forge::rust-nightly conda-forge::gcc conda-forge::pkg-config'
    publishDir "${params.benchmark_dir}", mode: 'copy'

    output:
    path "simd_minimizer_benchmark.tsv", emit: benchmark
    path "simd_minimizer_output.txt", emit: outlog

    script:
    """
    #!/bin/bash
    set -euo pipefail
    
    # Use PWD environment variable instead of pwd command
    NF_WORKDIR="\${PWD}"

    # Verify Rust nightly is available
    rustc --version

    # Replace bench.rs
    rm -f ${workflow.projectDir}/tools/simd-minimizers/simd-minimizers-bench/benches/bench.rs
    cp ${workflow.projectDir}/tools/bench.rs ${workflow.projectDir}/tools/simd-minimizers/simd-minimizers-bench/benches/bench.rs

    # Run test
    cd ${workflow.projectDir}/tools/simd-minimizers/simd-minimizers-bench/
    cargo clean
    RUSTFLAGS="-C target-cpu=native" cargo +nightly bench -j 1 \\
        --bench bench -- --nocapture > "\${NF_WORKDIR}/simd_minimizer_output.txt" 2>&1

    cd "\$NF_WORKDIR"
    # Capture the speed computed by the tool
    ${workflow.projectDir}/tools/get_speed_simd_minimizers.py simd_minimizer_output.txt > simd_minimizer_benchmark.tsv

    """
}

// process my_process {
//     output:
//     stdout


//     script:
//     """
//     #!/bin/bash
//     SCRIPT_DIR="${workflow.projectDir}"
//     echo "The script directory is: \$SCRIPT_DIR"
//     """
// }


// Workflow
workflow {
    //GENERATE TIMESTAMP FOR OUTPUT DIRECTORY
    def timestamp = new Date().format("ddMMyyyy_HHmm'UTC'", TimeZone.getTimeZone("UTC"))

    // ADD TIMESTAMP FOR OUTPUT DIRECTORY
    params.run_timestamp = timestamp
    params.run_outdir = "${params.outdir}/run_${timestamp}"
    params.benchmark_dir = "${params.run_outdir}/benchmarks"
    params.input_file_dir = "${params.run_outdir}/input"

    // GENERATE OUTPUT DIRECTORY
    file(params.run_outdir).mkdirs()
    file(params.benchmark_dir).mkdirs()
    file(params.input_file_dir).mkdirs()

    // SAVE RUN RECORDS
    // RECORD_RUN_INFO()

    // CHECK / INSTALL GITHUB TOOLS
    // tools definition
    tool_list = Channel.from([
        [name: "syncmer_tool", dir: "tools/syncmer"],
        [name: "csyncmer_AVX512", dir: "tools/ntHash-AVX512"]
    ])

    // tools build
    tool_inputs = tool_list.map { tool -> [tool.name, tool.dir] }
    // BUILD_OR_CACHE_GITHUB_TOOL(tool_inputs)

    // DOWNLOAD FILE FROM ZENODO IF NEEDED
    // DOWNLOAD_ZENODO()
    GET_FASTA_INPUT()


    // RUN BENCHMARK
    BENCHMARK_DIGEST(
        GET_FASTA_INPUT.out.file
    )

    BENCHMARK_CSYNCMER_FAST_AVX512(GET_FASTA_INPUT.out.file)
    BENCHMARK_SYNCMER_ORIGINAL(GET_FASTA_INPUT.out.file)
    // BENCHMARK_SIMD_MINIMIZER()

    // COLLECTING ALL BENCHMARKS
    // all_benchmarks = Channel.empty()
    //     .mix(BENCHMARK_DIGEST.out.benchmark)
    //     .mix(BENCHMARK_SYNCMER_ORIGINAL.out.benchmark)
    //     .mix(BENCHMARK_SIMD_MINIMIZER.out.benchmark)
    //     .mix(BENCHMARK_CSYNCMER_FAST.out.benchmark)
    //     .mix(BENCHMARK_CSYNCMER_FAST_SIMD.out.benchmark)
    //     .collect()

    // PLOT RESULTS
    // PLOT_SPEED_AND_SYNCMER_COUNT(PREPARE_INPUT.out.info, all_benchmarks)
}