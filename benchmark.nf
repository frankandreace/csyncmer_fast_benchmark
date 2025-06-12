#!/usr/bin/env nextflow

nexflow.enable.dsl=2

// PIPELINE PARAMETERS

// input possibilities
params.input_file = null
params.zenodo_url = null
params.zenodo_default_url = "https://zenodo.org/record/RECORD_ID/FILENAME"

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
    nextflow run benchmark.nf --zenodo_url <URL> --outdir <DIR>
    nextflow run benchmark.nf --input_file <FASTA/Q> --outdir <DIR>

    Input options (priority order):
    --input_file        Path to fasta/q file for benchmark
    --zenodo_url        URL to Zenodo file for benchmark
    (default)           Pre-configured Zenodo file will be used if neither above provided

    Other options:
    --outdir            Output directory (default: results)
    --tool_cache_dir    Directory for caching installed tools (default: ~/.nextflow_tool_cache)
    --force_reinstall   Force reinstallation of all tools (default: false)
    --help              Show this help message

    """
    exit 0
}

// RECORD RUN INFO 
process RECORD_RUN_INFO {
    label 'low_resources'
    publishDir "${params.outdir}/run_records", mode: 'copy'

    input:
    path "benchmarks/*"
    path "speed_results"

    output:
    path "run_*.reacord", emit: record

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

    # Resource allocation per process
    echo "Resource Allocation:" >> \$RECORD_FILE
    echo "--------------------" >> \$RECORD_FILE
    echo "Process 'process_low': ${params.process_low_cpus ?: 1} CPUs, ${params.process_low_memory ?: '2 GB'}" >> \$RECORD_FILE
    echo "Process 'process_medium': ${params.process_medium_cpus ?: 4} CPUs, ${params.process_medium_memory ?: '8 GB'}" >> \$RECORD_FILE
    echo "" >> \$RECORD_FILE

    # Benchmark summary
    echo "Benchmark Summary:" >> \$RECORD_FILE
    echo "------------------" >> \$RECORD_FILE
    if [ -f "${speed_results}" ]; then
        echo "" >> \$RECORD_FILE
        cat "${speed_results}" >> \$RECORD_FILE
    fi
    echo "" >> \$RECORD_FILE
    
    # Execution timeline
    echo "Execution Details:" >> \$RECORD_FILE
    echo "------------------" >> \$RECORD_FILE
    echo "Start time: ${workflow.start}" >> \$RECORD_FILE
    echo "Complete time: \$(date)" >> \$RECORD_FILE
    """
}

// CHECK AND INSTALL TOOLS IF NEEDED
process CHECK_INSTALL_GITHUB_TOOLS {
}

// DOWNLOAD FROM ZENODO
process DOWNLOAD_ZENODO {
    label 'low_resources'
    publishDir "${params.outdir}/input", mode: 'copy'

    output:
    path "downloaded_file", emit: file
    path "file_info.txt", emit: info

    script:
    """
    # Download file from Zenodo
    wget -O downloaded_file "${params.zenodo_url}}"

    # Get file size in bytes
    FILE_SIZE=\$(stat -c%s downloaded_file)
    echo "File size: \$FILE_SIZE bytes"> file_info.txt
    echo "\$FILE_SIZE" >> file_info.txt
    """
}

// CSYNCMER_FAST BENCHMARK
process BENCHMARK_CSYNCMER_FAST {
    label 'normal_resources'
    publishDir "${params.outdir}/benchmarks", mode: 'copy'

    input:
    path input_file

    output:
    path "csyncmer_fast_benchmark.txt", emit: benchmark

    script:
    """

    """
}

// CSYNCMER_FAST_SIMD BENCHMARK 
process BENCHMARK_CSYNCMER_FAST_SIMD {

}

// DIGEST BENCHMARK 
process BENCHMARK_DIGEST {
    
    label 'normal_resources'
    conda 'python=3.13 bioconda::digest'
    publishDir "${params.outdir}/benchmarks", mode: 'copy'

    input:
    path input_file

    output:
    path "digest_benchmark.tsv", emit: benchmark

    script:
    """
    ./tools/digest_benchmark.py -i ${input_file} -o digest_benchmark.tsv
    """
}

// SYNCMER ORIGINAL IMPLEMENTATION BENCHMARK
process BENCHMARK_SYNCMER_ORIGINAL {

}

// SIMD MINIMIZER BENCHMARK
process BENCHMARK_SIMD_MINIMIZER {

}


// Workflow
workflow {
    //GENERATE TIMESTAMP FOR OUTPUT DIRECTORY
    def timestamp = new Date().format("ddMMyyyy_HHmm'UTC'", TimeZone.getTimeZone("UTC"))

    // ADD TIMESTAMP FOR OUTPUT DIRECTORY
    params.run_timestamp = timestamp
    params.run_outdir = "${params.outdir}/run_${timestamp}"

    // SAVE RUN RECORDS

    // CHECK / INSTALL GITHUB TOOLS
    CHECK_OR_INSTALL_GITHUB_TOOLS()

    // DOWNLOAD FILE FROM ZENODO IF NEEDED

    // RUN BENCHMARK
    BENCHMARK_DIGEST(
        PREPARE_INPUT.out.file, 
        CHECK_OR_INSTALL_CONDA_TOOLS.out.ready
    )

    // COLLECTING ALL BENCHMARKS
    all_benchmarks = Channel.empty()
        .mix(BENCHMARK_DIGEST.out.benchmark)
        .mix(BENCHMARK_SYNCMER_ORIGINAL.out.benchmark)
        .mix(BENCHMARK_SIMD_MINIMIZER.out.benchmark)
        .mix(BENCHMARK_CSYNCMER_FAST.out.benchmark)
        .mix(BENCHMARK_CSYNCMER_FAST_SIMD.out.benchmark)
        .collect()

    // PLOT RESULTS
    PLOT_SPEED_AND_SYNCMER_COUNT(PREPARE_INPUT.out.info, all_benchmarks)
}