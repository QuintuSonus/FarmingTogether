# scripts/resources/CropData.gd (New File)
class_name CropData
extends Resource

@export var crop_id: String = ""         # e.g., "carrot"
@export var display_name: String = ""    # e.g., "Carrot"
@export var score_value: int = 10
@export var growth_time: float = 20.0
@export var spoil_time: float = 15.0
@export var icon: Texture2D             # Assign in Inspector
@export_file("*.tscn") var plant_scene_path: String
# Add any other crop-specific data here
