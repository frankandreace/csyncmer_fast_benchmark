# csyncmer_fast_benchmark
Benchmarking closed syncmer computation (C, C++, Rust, Python, Nexflow)


    nextflow run benchmark.nf --help
    nextflow run benchmark.nf [options]
    nextflow run benchmark.nf --url <URL> --outdir <DIR>
    nextflow run benchmark.nf --input_file <FASTA/Q> --outdir <DIR>
    nextflow run benchmark.nf -profile conda --input_file ~/Develop/csyncmer_fast/data/chr19_bit.fa
    nextflow run benchmark.nf -profile conda --url "https://ftp.ncbi.nlm.nih.gov/genomes/all/GCF/009/914/755/GCF_009914755.1_T2T-CHM13v2.0/GCF_009914755.1_T2T-CHM13v2.0_genomic.fna.gz"


    Input options (priority order):
    --input_file        Path to fasta/q file for benchmark
    --url               URL to some file for benchmark
    (default)           Pre-configured url will be used if neither above provided


    Other options:
    --outdir            Output directory (default: results)
    --force_reinstall   If reinstallation of source code tools is needed
    --help              Show this help message

