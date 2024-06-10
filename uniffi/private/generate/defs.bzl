"""
Utilities to generate uniffi bindings
"""

load("@build_bazel_rules_swift//swift:swift.bzl", "swift_c_module", "swift_library")
load("@rules_android//android:rules.bzl", "android_library")
load("@rules_kotlin//kotlin:android.bzl", "kt_android_library")
load("@rules_rust//rust:defs.bzl", "rust_library", "rust_shared_library", "rust_static_library")

# @rules_uniffi//uniffi:generate_bin

def _android_transition(_settings, _attr):
    return {"//command_line_option:platforms": "//:android_aarch64,//:android_armeabi,//:android_x86,//:android_x86_64"}

android_transition = transition(
    implementation = _android_transition,
    inputs = [],
    outputs = ["//command_line_option:platforms"],
)

def _android_rule_impl(ctx):
    return [DefaultInfo(
        files = depset(direct = ctx.files.srcs),
    )]

android_rule = rule(
    _android_rule_impl,
    attrs = {
        "_allowlist_function_transition": attr.label(
            default = "@bazel_tools//tools/allowlists/function_transition_allowlist",
        ),
        "srcs": attr.label_list(allow_files = True),
    },
    cfg = android_transition,
)

def define_lib(name = None, crate_name = None, **kwargs):
    """
    define rust libs

    Args:
        name:
        crate_name:
        **kwargs:
    """

    if crate_name == None:
        crate_name = name

    rust_library(
        name = name,
        crate_name = crate_name,
        **kwargs
    )

    rust_static_library(
        name = name + "_static",
        crate_name = crate_name,
        **kwargs
    )

    rust_shared_library(
        name = name + "_shared",
        crate_name = crate_name,
        **kwargs
    )

def expose_rust_lib(name, crate_name = None, **kwargs):
    """
    define all rust targets for ffi

    Args:
        name: rust target name
        crate_name:
        **kwargs:
    """
    define_lib(name, crate_name, **kwargs)

    native.genrule(
        name = "genrule_" + name + "_swift",
        srcs = [":" + name],
        outs = [name + ".swift", name + "FFI.h", name + "FFI.modulemap"],
        cmd = "$(location @rules_uniffi//uniffi:generate_bin) generate --bazel --library --out-dir $(@D) --language swift --metadata '{ \"packages\":[{\"name\":\"" + name + "\", \"dependencies\":[]}] }' $(location :" + name + ")",
        tools = ["@rules_uniffi//uniffi:generate_bin"],
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
        cmd = "$(location @rules_uniffi//uniffi:generate_bin) generate --bazel --library --out-dir $(@D) --language kotlin --metadata '{ \"packages\":[{\"name\":\"" + name + "\", \"dependencies\":[]}] }' $(location " + ":" + name + "_shared) && cp $(@D)/uniffi/service/* $(@D)",
        tools = ["@rules_uniffi//uniffi:generate_bin"],
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

    native.cc_import(
        name = "kt_shim_" + name,
        static_library = ":" + name + "_static",
    )

    android_library(
        name = name + "_kotlin",
        srcs = [],
        exports = [
            ":_" + name + "_kt",
            "kt_shim_" + name,
        ],
    )
