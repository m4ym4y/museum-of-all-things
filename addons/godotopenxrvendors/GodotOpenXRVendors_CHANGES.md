# Change history for the Godot OpenXR loaders asset

## 4.3.0

- Fix issue with instant splash screen
- Explicitly assign hand tracking mesh skeleton property to parent Skeleton3D
- Add Linux arm64 builds
- Minor tweaks to `XR_FB_space_warp` delta pose calculation and the sample
- Add support and manual page for `XR_ANDROID_scene_meshing` extension
- Add manual page for Android XR Passthrough Camera State
- Add documentation about Meta Boundary Visibility extension
- Add manual page for vendor performance metrics
- Add support and manual page for `XR_ANDROID_light_estimation` extension
- Add support and documentation for `XR_ANDROID_eye_tracking` extension
- Add support for `XR_META_colocation_discovery` extension
- Add the necessary permissions to enable EXT spatial entities on Meta headsets
- Fix errors in Meta Environment Depth documentation
- Add manual page for Body and Face Tracking
- Add manual page for Meta Color Space
- Only add shader globals when the environment depth extensions are enabled
- Add support and documentation for `XR_ANDROID_face_tracking` extension
- Fix issues with Meta hand-tracking extensions on Android XR
- Add support and manual page for `XR_ANDROID_depth_texture` extension
- Add XR Project Setup Wizard

## 4.2.2

- Fix crashes when using the plugin on Godot 4.4.x
- Fix background opacity on Android XR when using Compatibility renderer

## 4.2.1

- Fix generation of 16kb page compatible binaries
- Fix logic to detect when running on Android XR devices
- Fix the logic used to transfer data between hybrid apps' modes
- Fix generation of the release asset

## 4.2.0

- Add support for the **Android XR** OpenXR vendor
- Implement `XR_ANDROID_passthrough_camera_state` extension
- Implement `XR_ANDROID_performance_metrics` extension
- Document the settings required to make an app have a passthrough loading screen
- Add experimental support for the `XR_ML_marker_understanding` extension
- Fix the missing `com.oculus.permission.USE_SCENE` permission for the environment depth feature
- Add the required permission for enabling spatial entities on Pico devices
- Fix missing sample links for the passthrough and composition layer documentation pages
- Only add the global shader uniforms for Meta environment depth when it's enabled
- Fix missing shader uniform and Godot version in `project.godot` for meta-scene-sample
- Use `gdformat` to ensure consistent GDScript coding standards in CI
- Fix `OpenXRFbHandTrackingMesh` changes after startup and detecting when it's not supported
- Generate native debug symbols for Android
- Fix the manifest configuration for boundaryless apps: set `android.hardware.vr.headtracking` to `required="true"`
- Fix running the meta-scene-sample on Godot 4.4
- Add `quest3s` to the list of supported devices
- Fix errors reported by `XrApiLayer_core_validation`
- Allow using bilinear filtering in reprojection and provide example for smoothing in a shader
- Implement `XR_META_performance_metrics` extension
- Add documentation page about Meta Environment Depth
- Add method for getting the Meta environment depth map on the CPU side
- Clear `XRServer#remove_tracker` errors when closing the Godot editor
- Fix Meta passthrough when rendering with "Separate" thread model
- Fix `XR_META_environment_depth` when rendering with "Separate" thread model
- Fix issues with invalid data returned by `xrGetHandMeshFB`
- Implement `XR_META_headset_id` extension
- Implement `XR_META_simultaneous_hands_and_controllers` extension

## 4.1.1

- Update the export plugin version to match the maven central release

## 4.1.0

- Implement `XR_META_boundary_visibility` extension
- Add HorizonOS camera permissions when the Android CAMERA permission is enabled
- Implement `XR_FB_space_warp` extension (only with Godot 4.5+)
- Implement `XR_META_environment_depth` extension (only with Godot 4.5+)
- Implement `XR_FB_color_space` extension
- Update OpenXR to 1.1.49 release
- Implement `XR_META_body_tracking_full_body`, `XR_META_body_tracking_fidelity` and `XR_META_body_tracking_callibration`
- Clean-up editor plugins and class registration
- `OpenXRFbSceneManager`: Clarify how to check if scene capture is possible

## 4.0.0

- Support making hybrid apps for Meta headsets
- Add support for `XR_FB_android_surface_swapchain_create`
- Implement `XR_META_recommended_layer_resolution`
- Remove CMake from the build process
- Implement instant splash screen for Meta headsets
- Avoid casting errors when building with `precision=double`
- Add missing Pico store manifest
- Add support for `XR_FB_composition_layer_image_layout`
- Update demo and samples for Godot 4.4
- Switch Meta and Lynx to the Khronos loader
- Fix `OpenXRFbSpatialEntityStorageExtensionWrapper` typos
- Add support for `XR_FB_composition_layer_depth_test`
- Use project settings to avoid enabling unneeded OpenXR extensions
- Passthrough extensions should override real alpha blend mode, if enabled
- Update the main manifest with the latest from the Khronos OpenXR loader AAR
- Improve hand tracking related code in demo project

## 3.1.2
- Fix passthrough sample color map display bug
- Fix the issue preventing overridden vendor options from being updated

## 3.1.1
- Emit correct signal from `OpenXRFbSpatialEntity.erase_from_storage()`
- Only add the `LAUNCHER` category if "Show in App Library" is enabled

## 3.1.0
- Fix wall, floor and ceiling collision shapes with Jolt physics
- Add option to enable permissions necessary for sharing of Meta's spatial anchors
- Fix crash when attempting to create a spatial anchor too early
- Reworked geometric algebra used by Meta body tracking extension
- Remove deprecated "Contextual" boundary mode on Meta Quest
- Add two modes of Pico hand tracking to selectable export features
- Fix `OpenXRFbPassthroughExtensionWrapper` from wiping out the next pointer chain for system properties
- Update OpenXR to Khronos 1.1.41 release
- Add a project setting to enable/disable automatic requests for runtime permissions
- Add export profile for Magic Leap 2

## 3.0.1
- Fixed hand tracking issue

## 3.0.0
- Merge GDExtension into a single implementation
- Upgrade Android, Gradle, Godot and Kotlin dependencies
- Add XR_FB_face_tracking support
- Update to OpenXR 1.0.34 headers
- Add XR_FB_render_model extension wrapper and OpenXRFBRenderModel node
- Add XR_FB_passthrough extension wrapper
- Add XR_FB_hand_tracking_mesh extension wrapper and OpenXRFbHandTrackingMesh node
- Add XR_FB_hand_tracking_aim support
- Update Meta OpenXR mobile SDK to version 62
- Add a developer-facing API for interacting with scene anchors
- Add support for developer-created spatial anchors via XR_FB_spatial_entity
- Add XR_FB_hand_tracking_capsules extension wrapper
- Add OpenXRFbPassthroughGeometry node
- Add OpenXRMetaPassthroughColorLut
- Add feature flags to Khronos loader for HTC
- Add XR_HTC_passthrough extension wrapper
- Add manifest entries to Pico and switch Pico to using the Khronos Loader
- Add Meta Passthrough tutorial doc

## 2.0.4
- Fix misc crash when reloading project on Godot 4.3
- Fix issue with only the first permission being requested

## 2.0.3
- Migrate the export scripts from gdscript to C++ via gdextension
- Manually request eye tracking permission if it's included in the app manifest
- Change how singletons are accessed
- Fix the plugin version for the export plugins
- Add OpenXR extension wrappers for fb_scene, fb_spatial_entity, fb_spatial_entity_query, fb_spatial_entity_container

## 2.0.0
- Update to the new Godot 4.2 Android plugin packaging format
- Update the plugin to Godot v2 Android plugin
- Update to the Godot 4.2 Android library
- Add warning when multiple loaders are selected
- Add configs for the OpenXR Eye gaze interaction extension
- Add the ability to customize supported Meta devices
- Add support for Quest 3 devices
- Update the directory structure for the v2 plugin
- Update Meta OpenXR mobile SDK to version 57
- Update the java version to 17
- Rename the plugin to 'Godot OpenXR Vendors'
- Add godot-cpp dependency
- Add OpenXR 1.0.30 headers
- Add support for the Meta scene capture API (Donated by [Migeran](https://migeran.com))

## 1.1.0
- Update Meta OpenXR loader to version 54
- Update PICO OpenXR loader to version 2.2.0
- Bump dependencies versions to match the latest Godot 4.x stable version (v4.0.3)

## 1.0.0
- First version
- Added support for Meta Quest loader
- Added support for Pico loader
- Added support for Khronos loader (Magic Leap 2, HTC, etc.)
- Added support for Lynx loader
- Add logic to automatically publish the Godot OpenXR loaders libraries to mavencentral on release
