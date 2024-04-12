"""
Utilities to generate uniffi bindings
"""

load("@build_bazel_rules_swift//swift:swift.bzl", "swift_c_module", "swift_library")
load("@rules_android//android:rules.bzl", "android_library")
load("@rules_kotlin//kotlin:android.bzl", "kt_android_library")

def expose_rust_lib(name):
    """
    define all rust targets for ffi

    Args:
        name: rust target name
    """
    native.genrule(
        name = "genrule_" + name + "_swift",
        srcs = [":" + name],
        outs = [name + ".swift", name + "FFI.h", name + "FFI.modulemap"],
        cmd = "$(location //tools/uniffy-gen) generate --bazel --library --out-dir $(@D) --language swift --metadata '{ \"packages\":[{\"name\":\"" + name + "\", \"dependencies\":[]}] }' $(location :" + name + ")",
        tools = ["//tools/uniffy-gen"],
    )
    native.cc_library(
        name = "shim_" + name,
        hdrs = [name + "FFI.h"],
        deps = [":" + name + "_static"],
    )
    swift_c_module(
        name = "c_mod_" + name,
        deps = [":shim_" + name],
        module_name = name,
        module_map = name + "FFI.modulemap",
    )

    swift_library(
        name = name + "_swift",
        srcs = [name + ".swift"],
        deps = [":c_mod_" + name],
        module_name = name + "Lib",
    )

    native.genrule(
        name = "genrule_" + name + "_kotlin",
        srcs = [":" + name + "_shared"],
        outs = [name + ".kt"],
        cmd = "$(location //tools/uniffy-gen) generate --bazel --library --out-dir $(@D) --language kotlin --metadata '{ \"packages\":[{\"name\":\"" + name + "\", \"dependencies\":[]}] }' $(location " + ":" + name + "_shared) && cp $(@D)/uniffi/service/* $(@D)",
        tools = ["//tools/uniffy-gen"],
    )

    kt_android_library(
        name = "_" + name + "_kt",
        srcs = [name + ".kt"],
        deps = [
            "@maven//:net_java_dev_jna_jna",
            "@maven//:org_jetbrains_kotlinx_kotlinx_coroutines_core",
        ],
        exports = [
            "@net_java_dev_jna_jna//aar",
        ],
    )

    native.cc_library(
        name = "kt_shim_" + name,
        deps = [":" + name + "_shared"],
        linkopts = [
            "-lm",  # Required to avoid dlopen runtime failures unrelated to rust
            "-fuse-ld=lld",  # Work around https://github.com/bazelbuild/rules_rust/issues/1276, the default in newer NDK versions
        ],
        alwayslink = True,
    )

    android_library(
        name = name + "_kotlin",
        srcs = [],
        exports = [
            ":_" + name + "_kt",
            "kt_shim_" + name,
        ],
    )
