#![feature(portable_simd)]
#![allow(dead_code)]
use itertools::Itertools;
use packed_seq::{PackedSeq, PackedSeqVec, SeqVec};
use simd_minimizers::private::{
    minimizers::*,
    nthash::{nthash_seq_simd, NtHasher},
    S,
};
use simd_minimizers_bench::*;
use std::{cell::LazyCell, simd::Simd, time::Duration};

use criterion::{black_box, criterion_group, criterion_main, BenchmarkId, Criterion};

criterion_group!(
    name = group;
    config = Criterion::default()
        // Make sure that benchmarks are fast.
        .warm_up_time(Duration::from_millis(500))
        .measurement_time(Duration::from_millis(2000))
        .sample_size(10);
    targets = 
        //initial_runtime_comparison,
        //counting::count_comparisons_bench,
        //optimized, ext_nthash, buffered, local_nthash,
        simd_minimizer, //human_genome
);
criterion_main!(group);

fn initial_runtime_comparison(c: &mut Criterion) {
    // Create a random string of length 1Mbp.
    let text = &(0..1000000)
        .map(|_| b"ACGT"[rand::random::<u8>() as usize % 4])
        .collect::<Vec<_>>();

    let hasher = FxHash;

    let w = 11;
    let k = 21;

    #[rustfmt::skip]
    let minimizers: &mut [(&str, &mut dyn Minimizer, bool)] = &mut [
        ("naive", &mut NaiveMinimizer { w, k, hasher }, true),
        ("buffered", &mut SlidingWindowMinimizer { w, k, alg: Buffered, hasher }, true),
        ("queue", &mut SlidingWindowMinimizer { w, k, alg: Queue, hasher }, true),
        ("jumping", &mut JumpingMinimizer { w, k, hasher }, false),
        ("rescan", &mut SlidingWindowMinimizer { w, k, alg: Rescan, hasher }, true),
        ("split", &mut SlidingWindowMinimizer { w, k, alg: Split, hasher }, true),
        ("queue_igor", &mut QueueIgor { w, k }, false),
        ("rescan_daniel", &mut RescanDaniel { w, k }, true),
    ];

    let mut g = c.benchmark_group("g");
    for (name, m, window_minimizers) in minimizers {
        g.bench_function(*name, move |b| {
            if *window_minimizers {
                b.iter(|| m.window_minimizers(text));
            } else {
                b.iter(|| m.minimizer_positions(text));
            }
        });
    }
}

fn optimized(c: &mut Criterion) {
    // Create a random string of length 1Mbp.
    let text = &(0..1000000)
        .map(|_| b"ACGT"[rand::random::<u8>() as usize % 4])
        .collect::<Vec<_>>();

    let hasher = FxHash;

    let w = 11;
    let k = 21;

    #[rustfmt::skip]
    let minimizers: &mut [(&str, &mut dyn Minimizer, bool)] = &mut [
        ("buffered_opt", &mut SlidingWindowMinimizer { w, k, alg: BufferedOpt, hasher }, true),
        ("rescan_opt", &mut SlidingWindowMinimizer { w, k, alg: RescanOpt, hasher }, true),
        ("split_opt", &mut SlidingWindowMinimizer { w, k, alg: SplitOpt, hasher }, true),
    ];

    let mut g = c.benchmark_group("g");
    for (name, m, window_minimizers) in minimizers {
        g.bench_function(*name, |b| {
            if *window_minimizers {
                b.iter(|| m.window_minimizers(text));
            } else {
                b.iter(|| m.minimizer_positions(text));
            }
        });
    }
}

fn ext_nthash(c: &mut Criterion) {
    // Create a random string of length 1Mbp.
    let text = &(0..1000000)
        .map(|_| b"ACGT"[rand::random::<u8>() as usize % 4])
        .collect::<Vec<_>>();

    let w = 11;
    let k = 21;

    let hasher = ExtNtHash;

    #[rustfmt::skip]
    let minimizers: &mut [(&str, &mut dyn Minimizer, bool)] = &mut [
        ("buffered_nt", &mut SlidingWindowMinimizer { w, k, alg: BufferedOpt, hasher }, true),
        ("queue_nt", &mut SlidingWindowMinimizer { w, k, alg: Queue, hasher }, true),
        ("jumping_nt", &mut JumpingMinimizer { w, k, hasher }, false),
        ("rescan_nt", &mut SlidingWindowMinimizer { w, k, alg: RescanOpt, hasher }, true),
        ("split_nt", &mut SlidingWindowMinimizer { w, k, alg: SplitOpt, hasher }, true),
    ];

    let mut g = c.benchmark_group("g");
    for (name, m, window_minimizers) in minimizers {
        g.bench_function(*name, |b| {
            if *window_minimizers {
                b.iter(|| m.window_minimizers(text));
            } else {
                b.iter(|| m.minimizer_positions(text));
            }
        });
    }
}

fn buffered(c: &mut Criterion) {
    // Create a random string of length 1Mbp.
    let text = &(0..1000000)
        .map(|_| b"ACGT"[rand::random::<u8>() as usize % 4])
        .collect::<Vec<_>>();

    let w = 11;
    let k = 21;

    let fxhasher = Buffer { hasher: FxHash };
    let nthasher = Buffer { hasher: ExtNtHash };

    #[rustfmt::skip]
    let minimizers: &mut[(&str, &mut dyn Minimizer, bool)] = &mut [
        ("buffered_buf", &mut SlidingWindowMinimizer { w, k, alg: BufferedOpt, hasher: fxhasher }, true),
        ("queue_buf", &mut SlidingWindowMinimizer { w, k, alg: Queue, hasher: fxhasher }, true),
        ("jumping_buf", &mut JumpingMinimizer { w, k, hasher: fxhasher }, false),
        ("rescan_buf", &mut SlidingWindowMinimizer { w, k, alg: RescanOpt, hasher: fxhasher }, true),
        ("split_buf", &mut SlidingWindowMinimizer { w, k, alg: SplitOpt, hasher: fxhasher }, true),
        ("buffered_nt_buf", &mut SlidingWindowMinimizer { w, k, alg: BufferedOpt, hasher: nthasher }, true),
        ("queue_nt_buf", &mut SlidingWindowMinimizer { w, k, alg: Queue, hasher: nthasher }, true),
        ("jumping_nt_buf", &mut JumpingMinimizer { w, k, hasher: nthasher }, false),
        ("rescan_nt_buf", &mut SlidingWindowMinimizer { w, k, alg: RescanOpt, hasher: nthasher }, true),
        ("split_nt_buf", &mut SlidingWindowMinimizer { w, k, alg: SplitOpt, hasher: nthasher }, true),
    ];

    let mut g = c.benchmark_group("g");
    for (name, m, window_minimizers) in minimizers {
        g.bench_function(*name, |b| {
            if *window_minimizers {
                b.iter(|| m.window_minimizers(text));
            } else {
                b.iter(|| m.minimizer_positions(text));
            }
        });
    }
}

fn local_nthash(c: &mut Criterion) {
    // Create a random string of length 1Mbp.
    let text = &(0..1000000)
        .map(|_| b"ACGT"[rand::random::<u8>() as usize % 4])
        .collect::<Vec<_>>();

    let k = 21;

    let mut g = c.benchmark_group("g");
    g.bench_function("ext_nthash", |b| {
        b.iter(|| ExtNtHash.hash_kmers(k, text).collect::<Vec<_>>());
    });
    g.bench_function("nthash", |b| {
        b.iter(|| NtHash.hash_kmers(k, text).collect::<Vec<_>>());
    });
    g.bench_with_input("nthash_buf", text, |b, text| {
        b.iter(|| Buffer { hasher: NtHash }.hash_kmers(k, text).collect_vec());
    });
    g.bench_with_input("nthash_bufopt", text, |b, text| {
        b.iter(|| {
            BufferOpt { hasher: NtHash }
                .hash_kmers(k, text)
                .collect_vec()
        });
    });
    g.bench_with_input("nthash_bufdouble", text, |b, text| {
        b.iter(|| BufferDouble::new(NtHash).hash_kmers(k, text).collect_vec());
    });
    g.bench_with_input("nthash_bufpar1", text, |b, text| {
        b.iter(|| {
            BufferPar { hasher: NtHashPar::<1> }
                .hash_kmers(k, text)
                .collect_vec()
        });
    });
    g.bench_with_input("nthash_bufpar2", text, |b, text| {
        b.iter(|| {
            BufferPar { hasher: NtHashPar::<2> }
                .hash_kmers(k, text)
                .collect_vec()
        });
    });
    g.bench_with_input("nthash_bufpar3", text, |b, text| {
        b.iter(|| {
            BufferPar { hasher: NtHashPar::<3> }
                .hash_kmers(k, text)
                .collect_vec()
        });
    });
    g.bench_with_input("nthash_bufpar4", text, |b, text| {
        b.iter(|| {
            BufferPar { hasher: NtHashPar::<4> }
                .hash_kmers(k, text)
                .collect_vec()
        });
    });

    let packed_text = &(0..1000000 / 4)
        .map(|_| rand::random::<u8>())
        .collect::<Vec<_>>();

    g.bench_with_input("nthash_buf_simd", packed_text, |b, packed_text| {
        b.iter(|| {
            PackedBufferPar { hasher: NtHashSimd::<false> }
                .hash_kmers(k, packed_text)
                .collect_vec()
        });
    });

    g.bench_with_input("nthash_buf_simd_reuse", packed_text, |b, packed_text| {
        b.iter(|| {
            PackedBufferPar { hasher: NtHashSimd::<true> }
                .hash_kmers(k, packed_text)
                .collect_vec()
        });
    });

    g.bench_with_input("nthash_sum_simd_reuse", packed_text, |b, packed_text| {
        b.iter(|| {
            NtHashSimd::<true>
                .hash_kmers(k, packed_text)
                .map(|x| Simd::<u32, 8>::from(x))
                .sum::<Simd<u32, 8>>()
        });
    });

    let mut hasher = BufferParCached::new(NtHashSimd::<true>);
    g.bench_with_input("nthash_buf_simd_cached", packed_text, |b, packed_text| {
        b.iter(|| drop(black_box(hasher.hash_kmers(k, packed_text))));
    });

    let k = 15;
    g.bench_with_input("fxhash_simd", packed_text, |b, packed_text| {
        b.iter(|| {
            FxHashSimd
                .hash_kmers(k, packed_text)
                .map(|x| Simd::<u32, 8>::from(x))
                .sum::<Simd<u32, 8>>()
        });
    });

    let mut hasher = BufferParCached::new(FxHashSimd);
    g.bench_with_input("fxhash_bufsimd_cached", packed_text, |b, packed_text| {
        b.iter(|| drop(black_box(hasher.hash_kmers(k, packed_text))));
    });

    type H = NtHasher;

    let packed_text = PackedSeq { seq: packed_text, offset: 0, len: packed_text.len() * 4 };
    g.bench_with_input("nthash_simd_it_sum", &packed_text, |b, packed_text| {
        b.iter(|| {
            nthash_seq_simd::<false, PackedSeq, H>(*packed_text, k, 1)
                .0
                .sum::<S>()
        });
    });
    g.bench_with_input("nthash_simd_it_vec", &packed_text, |b, packed_text| {
        b.iter(|| {
            nthash_seq_simd::<false, PackedSeq, H>(*packed_text, k, 1)
                .0
                .collect_vec()
        });
    });
    g.bench_with_input("nthash_simd_it_sum_c", &packed_text, |b, packed_text| {
        b.iter(|| {
            nthash_seq_simd::<true, PackedSeq, H>(*packed_text, k, 1)
                .0
                .sum::<S>()
        });
    });
}

fn simd_minimizer(c: &mut Criterion) {
    // // Create a random string of length 1Mbp.
    let owned_packed_seq = PackedSeqVec::random(1000000);
    let raw_packed_seq = &owned_packed_seq.seq;
    // let packed_seq = owned_packed_seq.as_slice();

    let w = 11;
    let k = 21;

    {
        let mut g = c.benchmark_group("initial_benchmarks");
        let mut hasher = NtHashSimd::<true>;
        g.bench_function("split_simd_sum", |b| {
            b.iter(|| {
                SplitSimd
                    .sliding_min(w, hasher.hash_kmers(k, raw_packed_seq))
                    .map(|x| Simd::<u32, 8>::from(x))
                    .sum::<Simd<u32, 8>>()
            });
        });

        let hasher = NtHashSimd::<true>;
        let mut hasher = BufferParCached::new(hasher);
        g.bench_function("split_simd_buf_sum", |b| {
            b.iter(|| {
                SplitSimd
                    .sliding_min(w, hasher.hash_kmers(k, raw_packed_seq))
                    .map(|x| Simd::<u32, 8>::from(x))
                    .sum::<Simd<u32, 8>>()
            });
        });

        let mut hasher = NtHashSimd::<true>;
        g.bench_function("split_simd_collect", |b| {
            let mut v = vec![];
            b.iter(|| {
                v.extend(SplitSimd.sliding_min(w, hasher.hash_kmers(k, raw_packed_seq)));
                v.clear();
            });
        });

        let hasher = NtHashSimd::<true>;
        let mut hasher = BufferParCached::new(hasher);
        g.bench_function("split_simd_buf_collect", |b| {
            let mut v = vec![];
            b.iter(|| {
                v.extend(SplitSimd.sliding_min(w, hasher.hash_kmers(k, raw_packed_seq)));
                v.clear();
            });
        });
        
        g.finish();
    }

    let lens = [1000000, 100000000];
    for len in lens {
        eprintln!("\nLEN {len}\n");
        let owned_packed_seq = PackedSeqVec::random(len);
        let packed_seq = owned_packed_seq.as_slice();

        // g.bench_function(BenchmarkId::new("minimizer_scalar_it_vec", len), |b| {
        //     let mut vec = Vec::new();
        //     b.iter(|| {
        //         vec.extend(minimizer_scalar_it::<false>(packed_seq, k, w));
        //         black_box(&mut vec).clear();
        //     });
        // });
        // g.bench_function(BenchmarkId::new("minimizer_simd_it_vec", len), |b| {
        //     let mut vec = Vec::new();
        //     b.iter(|| {
        //         vec.extend(minimizer_simd_it::<false>(packed_seq, k, w));
        //         black_box(&mut vec).clear();
        //     });
        // });
        // g.bench_function(
        //     BenchmarkId::new("minimizer_simd_it_vec_dedup_it", len),
        //     |b| {
        //         let mut vec = Vec::new();
        //         b.iter(|| {
        //             vec.extend(minimizer_simd_it::<false>(packed_seq, k, w).dedup());
        //             black_box(&mut vec).clear();
        //         });
        //     },
        // );
        // g.bench_function(
        //     BenchmarkId::new("minimizer_simd_it_vec_dedup_vec", len),
        //     |b| {
        //         let mut vec = Vec::new();
        //         b.iter(|| {
        //             vec.extend(minimizer_simd_it::<false>(packed_seq, k, w));
        //             vec.dedup();
        //             black_box(&mut vec).clear();
        //         });
        //     },
        // );

        // Measuring throughput with benchmark group throughput settings
        let mb_per_sec = criterion::Throughput::Bytes(len as u64);  // 1/4th byte per base but reporting it as 1 base/byte
        
        {
            let mut group = c.benchmark_group(format!("simd_minimizers_{}", len));
            group.throughput(mb_per_sec);
            
            group.bench_with_input(BenchmarkId::new("minimizer_par_it_vec", len), &len, |b, _| {
                let mut vec = Vec::new();
                b.iter(|| {
                    vec.extend(minimizers_seq_simd::<_, NtHasher>(packed_seq, k, w).0);
                    black_box(&mut vec).clear();
                });
            });
            
            group.bench_with_input(BenchmarkId::new("minimizer_par_it_sum", len), &len, |b, _| {
                b.iter(|| black_box(minimizers_seq_simd::<_, NtHasher>(packed_seq, k, w).0.sum::<S>()));
            });
            
       
        /*
        // These functions don't appear to be available in scope
        g.bench_function(BenchmarkId::new("minimizer_collect", len), |b| {
            // Configure throughput in bytes processed per iteration
            let throughput_bytes = len as u64;
            b.throughput(criterion::Throughput::Bytes(throughput_bytes));
            
            b.iter(|| black_box(minimizers_collect(packed_seq, k, w)));
        });
        
        g.bench_function(BenchmarkId::new("minimizer_dedup", len), |b| {
            // Configure throughput in bytes processed per iteration
            let throughput_bytes = len as u64;
            b.throughput(criterion::Throughput::Bytes(throughput_bytes));
            
            b.iter(|| minimizers_dedup(packed_seq, k, w));
        });
        
        g.bench_function(BenchmarkId::new("minimizer_collect_and_dedup", len), |b| {
            // Configure throughput in bytes processed per iteration
            let throughput_bytes = len as u64;
            b.throughput(criterion::Throughput::Bytes(throughput_bytes));
            
            let mut vec = Vec::new();
            b.iter(|| {
                minimizers_collect_and_dedup::<false>(packed_seq, k, w, &mut vec);
                black_box(&mut vec).clear();
            });
        });

        g.bench_function(
            BenchmarkId::new("minimizer_collect_and_dedup_super", len),
            |b| {
                // Configure throughput in bytes processed per iteration
                let throughput_bytes = len as u64;
                b.throughput(criterion::Throughput::Bytes(throughput_bytes));
                
                let mut vec = Vec::new();
                b.iter(|| {
                    minimizers_collect_and_dedup::<true>(packed_seq, k, w, &mut vec);
                    black_box(&mut vec).clear();
                });
            },
        );
        */ 

            group.bench_with_input(BenchmarkId::new("minimizer_canonical", len), &len, |b, _| {
                let mut vec = Vec::new();
                b.iter(|| {
                    vec.extend(canonical_minimizers_seq_simd::<_, NtHasher>(packed_seq, k, w).0);
                    black_box(&mut vec).clear();
                });
            });

            group.bench_with_input(BenchmarkId::new("minimizer_canonical_sum", len), &len, |b, _| {
                b.iter(|| black_box(canonical_minimizers_seq_simd::<_, NtHasher>(packed_seq, k, w).0.sum::<S>()));
            });


            /*
            group.bench_with_input(BenchmarkId::new("minimizer_canonical_dedup", len), &len, |b, _| {
                let mut vec = Vec::new();
                b.iter(|| {
                    canonical_minimizer_collect_and_dedup::<false>(packed_seq, k, w, &mut vec);
                    black_box(&mut vec).clear();
                });
            });
            */
        
            // Close the benchmark group
            group.finish();
        }
 
    }
}

/*
fn human_genome(c: &mut Criterion) {
    let w = 11;
    let k = 21;

    let packed_text = LazyCell::new(|| read_human_genome(1));

    c.bench_function("human_genome", |b| {
        if packed_text.len() == 0 {
            return Default::default();
        }
        let mut vec = Vec::new();
        b.iter(|| {
            minimizers_collect_and_dedup::<true>(packed_text.as_slice(), k, w, &mut vec);
            black_box(&mut vec).clear();
        });
        
        // Calculate and print throughput
        let genome_len = packed_text.len() * 4; // Each packed byte represents 4 bases
        let genome_mb = (genome_len as f64) / 1_000_000.0;
        let time = b.elapsed();
        let throughput = genome_mb / (time.as_secs_f64());
        eprintln!("human_genome minimizers: {:.2} MB/s", throughput);
    });
    
    c.bench_function("human_genome_rc", |b| {
        if packed_text.len() == 0 {
            return Default::default();
        }
        let mut vec = Vec::new();
        b.iter(|| {
            canonical_minimizer_collect_and_dedup::<true>(packed_text.as_slice(), k, w, &mut vec);
            black_box(&mut vec).clear();
        });
        
        // Calculate and print throughput
        let genome_len = packed_text.len() * 4; // Each packed byte represents 4 bases
        let genome_mb = (genome_len as f64) / 1_000_000.0;
        let time = b.elapsed();
        let throughput = genome_mb / (time.as_secs_f64());
        eprintln!("human_genome canonical: {:.2} MB/s", throughput);
    });
}
*/
