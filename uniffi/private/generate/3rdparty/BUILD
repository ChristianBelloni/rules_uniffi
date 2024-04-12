load("@rules_rust//crate_universe:defs.bzl", "crates_vendor")

package(default_visibility = ["//visibility:public"])

exports_files([
    "Cargo.Bazel.lock",
    "cargo-bazel-lock.json",
])

crates_vendor(
    name = "crates_vendor",
    cargo_lockfile = "//uniffi/private/generate:Cargo.lock",
    manifests = [
        "//uniffi/private/generate:Cargo.toml",
    ],
    mode = "local",
    # Short for 'crate universe index'. Keep this short to reduce the risk to
    # bump into absolute path length issues on Windows. See:
    # https://github.com/bazelbuild/rules_rust/issues/1120
    repository_name = "gi",
    tags = ["manual"],
    vendor_path = "crates",
)

filegroup(
    name = "bzl_srcs",
    srcs = glob(["*.bzl"]) + [
        "//uniffi/private/generate/3rdparty/crates:crates.bzl",
        "//uniffi/private/generate/3rdparty/crates:defs.bzl",
    ],
)
