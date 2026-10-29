@tool
extends EditorPlugin
## Puts yolo.aar (built from android/) and ONNX Runtime into Android exports.
## The app reaches it as Engine.get_singleton("Yolo"); see modules/cv/detector.gd.

const ONNX_RUNTIME := "com.microsoft.onnxruntime:onnxruntime-android:1.31.1"

var _export := YoloExport.new()


func _enter_tree() -> void:
	add_export_plugin(_export)


func _exit_tree() -> void:
	remove_export_plugin(_export)


class YoloExport extends EditorExportPlugin:
	func _get_name() -> String:
		return "Yolo"

	func _supports_platform(platform: EditorExportPlatform) -> bool:
		return platform is EditorExportPlatformAndroid

	func _get_android_libraries(_platform: EditorExportPlatform, _debug: bool) -> PackedStringArray:
		return PackedStringArray(["yolo/yolo.aar"])

	func _get_android_dependencies(_platform: EditorExportPlatform, _debug: bool) -> PackedStringArray:
		return PackedStringArray([ONNX_RUNTIME])
