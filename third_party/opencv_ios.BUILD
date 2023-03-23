# Description:
#   OpenCV libraries for video/image processing on iOS

licenses(["notice"])  # BSD license

exports_files(["LICENSE"])

load(
    "@build_bazel_rules_apple//apple:apple.bzl",
    "apple_static_framework_import",
)


genrule(
    name = "build_framework",
    srcs = glob(["opencv-4.7.0/**"]),
    outs = ["opencv2.framework"],
    cmd = "$(location opencv-4.7.0/platforms/ios/build_framework.py) --iphonesimulator_archs arm64,x86_64 --build_only_specified_archs  $(RULEDIR)",
)

objc_library(
    hdrs = glob([
        "opencv2.framework/**",
    ]),
    name = "opencv_gen_objc_lib",
    data = [":build_framework"],
)

apple_static_framework_import(
    name = "OpencvFramework",
    framework_imports = glob(["opencv2.framework/**"]),
    visibility = ["//visibility:public"],
)

objc_library(
    name = "opencv_objc_lib",
    deps = [":OpencvFramework"],
)

cc_library(
    name = "opencv",
    hdrs = glob([
        "opencv2.framework/Versions/A/Headers/**/*.h*",
    ]),
    copts = [
        "-std=c++17",
        "-x objective-c++",
        "-ObjC++"
    ],
    include_prefix = "opencv2",
    linkopts = [
        "-framework AssetsLibrary",
        "-framework CoreFoundation",
        "-framework CoreGraphics",
        "-framework CoreMedia",
        "-framework Accelerate",
        "-framework CoreImage",
        "-framework AVFoundation",
        "-framework CoreVideo",
        "-framework QuartzCore",
    ],
    strip_include_prefix = "opencv2.framework/Versions/A/Headers",
    visibility = ["//visibility:public"],
    deps = [":opencv_objc_lib",],
)
