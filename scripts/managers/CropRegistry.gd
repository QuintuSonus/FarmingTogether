# scripts/global/CropRegistry.gd
extends Node

var crop_definitions: Dictionary = {}
const CROP_DATA_PATH = "res://resources/crop_data/" # ADJUST THIS PATH if you chose a different folder

func _ready():
	_load_crop_data()

func _load_crop_data():
	print("CropRegistry: Loading crop data...")
	crop_definitions.clear()

	var dir = DirAccess.open(CROP_DATA_PATH)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if not dir.current_is_dir() and file_name.ends_with(".tres"):
				var resource_path = CROP_DATA_PATH.path_join(file_name)
				var crop_data: CropData = load(resource_path)
				if crop_data and crop_data is CropData:
					if crop_data.crop_id == "":
						push_warning("CropRegistry: Resource '%s' has empty crop_id!" % resource_path)
					elif crop_definitions.has(crop_data.crop_id):
						push_warning("CropRegistry: Duplicate crop_id '%s' found in '%s'!" % [crop_data.crop_id, resource_path])
					else:
					   # Directly access instance variable
						crop_definitions[crop_data.crop_id] = crop_data
						print("  - Loaded: %s (ID: %s)" % [crop_data.display_name, crop_data.crop_id])
				else:
					push_warning("CropRegistry: Failed to load '%s' as CropData resource." % resource_path)
			file_name = dir.get_next()
		dir.list_dir_end()
	else:
		push_error("CropRegistry: Could not open directory: " + CROP_DATA_PATH)

	print("CropRegistry: Loaded %d crop definitions." % crop_definitions.size())


## Get the full CropData resource for a given ID.
## REMOVED STATIC keyword
func get_crop_data(crop_id: String) -> CropData:
	# Directly access instance variable
	if crop_definitions.has(crop_id):
		return crop_definitions[crop_id]
	push_error("CropRegistry: Crop data not found for ID: " + crop_id)
	return null # Return null if not found


## Helper function to quickly get just the score value.
## REMOVED STATIC keyword
func get_crop_score(crop_id: String) -> int:
	# Can now call the instance method directly
	var data = get_crop_data(crop_id)
	if data:
		return data.score_value
	return 5 # Default score if crop not found
