@tool
extends EditorPlugin

const InspectorPluginScript := preload("uid://8q3hva3bmlkl")
const SettingsScript := preload("uid://c5i7h2p7ixlc4")

var inspector_plugin: EditorInspectorPlugin

func _enter_tree() -> void:
	SettingsScript.register()
	inspector_plugin = InspectorPluginScript.new()
	add_inspector_plugin(inspector_plugin)

func _exit_tree() -> void:
	if inspector_plugin != null:
		remove_inspector_plugin(inspector_plugin)
		inspector_plugin = null
