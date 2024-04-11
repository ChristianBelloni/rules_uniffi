#![allow(unused)]

use anyhow::Context;
use camino::Utf8PathBuf;
use clap::{Parser, Subcommand};
use uniffi_bindgen::bindings::TargetLanguage;
use uniffi_bindgen::BindingGeneratorDefault;

mod bazel_mode;

pub fn main() -> anyhow::Result<()> {
    println!("generate files");
    Ok(())
}

pub fn run_main() -> anyhow::Result<()> {
    let cli = Cli::parse();
    match cli.command {
        Commands::Generate {
            language,
            out_dir,
            no_format,
            config,
            lib_file,
            source,
            crate_name,
            library_mode,
            bazel_mode,
            metadata,
        } => {
            if library_mode {
                if lib_file.is_some() {
                    panic!("--lib-file is not compatible with --library.")
                }
                let out_dir = out_dir.expect("--out-dir is required when using --library");
                if language.is_empty() {
                    panic!("please specify at least one language with --language")
                }

                if bazel_mode {
                    crate::bazel_mode::generate_bindings(
                        &source,
                        crate_name,
                        &BindingGeneratorDefault {
                            target_languages: language,
                            try_format_code: !no_format,
                        },
                        config.as_deref(),
                        &out_dir,
                        !no_format,
                        metadata.context("bazel mode selected")?,
                    )?;
                } else {
                    uniffi_bindgen::library_mode::generate_bindings(
                        &source,
                        crate_name,
                        &BindingGeneratorDefault {
                            target_languages: language,
                            try_format_code: !no_format,
                        },
                        config.as_deref(),
                        &out_dir,
                        !no_format,
                    )?;
                }
            } else {
                uniffi_bindgen::generate_bindings(
                    &source,
                    config.as_deref(),
                    BindingGeneratorDefault {
                        target_languages: language,
                        try_format_code: !no_format,
                    },
                    out_dir.as_deref(),
                    lib_file.as_deref(),
                    crate_name.as_deref(),
                    !no_format,
                )?;
            }
        }
    }
    Ok(())
}

#[derive(Parser)]
#[clap(name = "uniffi-bindgen")]
#[clap(propagate_version = true)]
struct Cli {
    #[clap(subcommand)]
    command: Commands,
}

#[derive(Subcommand)]
enum Commands {
    /// Generate foreign language bindings
    Generate {
        /// Foreign language(s) for which to build bindings.
        #[clap(long, short, value_enum)]
        language: Vec<TargetLanguage>,

        /// Directory in which to write generated files. Default is same folder as .udl file.
        #[clap(long, short)]
        out_dir: Option<Utf8PathBuf>,

        /// Do not try to format the generated bindings.
        #[clap(long, short)]
        no_format: bool,

        /// Path to optional uniffi config file. This config is merged with the `uniffi.toml` config present in each crate, with its values taking precedence.
        #[clap(long, short)]
        config: Option<Utf8PathBuf>,

        /// Extract proc-macro metadata from a native lib (cdylib or staticlib) for this crate.
        #[clap(long)]
        lib_file: Option<Utf8PathBuf>,

        /// Pass in a cdylib path rather than a UDL file
        #[clap(long = "library")]
        library_mode: bool,

        #[clap(long = "bazel")]
        bazel_mode: bool,

        #[clap(long = "metadata")]
        metadata: Option<String>,

        /// When `--library` is passed, only generate bindings for one crate.
        /// When `--library` is not passed, use this as the crate name instead of attempting to
        /// locate and parse Cargo.toml.
        #[clap(long = "crate")]
        crate_name: Option<String>,

        /// Path to the UDL file, or cdylib if `library-mode` is specified
        source: Utf8PathBuf,
    },
}
