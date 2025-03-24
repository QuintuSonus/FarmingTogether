# scripts/upgrades/DefaultUpgradeIcons.gd
class_name DefaultUpgradeIcons
extends Node

# This class provides default icons for upgrades when the specified icon files don't exist.
# It generates solid-colored icons with a distinctive border based on the upgrade type.

# Get a default icon for an upgrade type
static func get_default_icon(upgrade_type: int, upgrade_id: String) -> ImageTexture:
	# Create a new image
	var img = Image.create(64, 64, false, Image.FORMAT_RGBA8)
	
	# Fill with appropriate color
	var fill_color = get_color_for_type(upgrade_type)
	img.fill(fill_color)
	
	# Add border
	add_border(img, Color(0.2, 0.2, 0.2))
	
	# Add distinctive pattern based on upgrade ID (first letter)
	if upgrade_id.length() > 0:
		add_pattern(img, upgrade_id[0], Color(1, 1, 1, 0.5))
	
	# Create and return texture
	var texture = ImageTexture.create_from_image(img)
	return texture

# Get a color for an upgrade type
static func get_color_for_type(upgrade_type: int) -> Color:
	match upgrade_type:
		UpgradeData.UpgradeType.TILE:
			return Color(0.2, 0.6, 0.2)  # Green for tile upgrades
		UpgradeData.UpgradeType.TOOL: 
			return Color(0.2, 0.4, 0.8)  # Blue for tool upgrades
		UpgradeData.UpgradeType.PLAYER:
			return Color(0.8, 0.4, 0.2)  # Orange for player upgrades
		_:
			return Color(0.5, 0.5, 0.5)  # Grey default

# Add border to an image
static func add_border(img: Image, border_color: Color, width: int = 2):
	var size = img.get_size()
	
	# Draw horizontal borders
	for x in range(size.x):
		for w in range(width):
			if w < size.y:
				img.set_pixel(x, w, border_color)
				img.set_pixel(x, size.y - 1 - w, border_color)
	
	# Draw vertical borders
	for y in range(size.y):
		for w in range(width):
			if w < size.x:
				img.set_pixel(w, y, border_color)
				img.set_pixel(size.x - 1 - w, y, border_color)

# Add a pattern based on the first letter of the upgrade ID
static func add_pattern(img: Image, letter: String, pattern_color: Color):
	var size = img.get_size()
	var center_x = size.x / 2
	var center_y = size.y / 2
	
	# Turn letter into a simple pattern
	var ascii_val = letter.unicode_at(0)
	
	# Pattern options: circle, square, or cross
	var pattern_type = ascii_val % 3
	
	match pattern_type:
		0:  # Circle
			draw_circle(img, center_x, center_y, 20, pattern_color)
		1:  # Square
			draw_square(img, center_x, center_y, 32, pattern_color)
		2:  # Cross
			draw_cross(img, center_x, center_y, 24, pattern_color)

# Simple drawing functions
static func draw_circle(img: Image, center_x: int, center_y: int, radius: int, color: Color):
	for x in range(max(0, center_x - radius), min(img.get_width(), center_x + radius)):
		for y in range(max(0, center_y - radius), min(img.get_height(), center_y + radius)):
			var dist = sqrt(pow(x - center_x, 2) + pow(y - center_y, 2))
			if dist <= radius:
				img.set_pixel(x, y, color)

static func draw_square(img: Image, center_x: int, center_y: int, size: int, color: Color):
	var half = size / 2
	for x in range(max(0, center_x - half), min(img.get_width(), center_x + half)):
		for y in range(max(0, center_y - half), min(img.get_height(), center_y + half)):
			img.set_pixel(x, y, color)

static func draw_cross(img: Image, center_x: int, center_y: int, length: int, color: Color):
	var half_thickness = 4
	
	# Horizontal line
	for x in range(max(0, center_x - length/2), min(img.get_width(), center_x + length/2)):
		for y in range(max(0, center_y - half_thickness), min(img.get_height(), center_y + half_thickness)):
			img.set_pixel(x, y, color)
	
	# Vertical line
	for y in range(max(0, center_y - length/2), min(img.get_height(), center_y + length/2)):
		for x in range(max(0, center_x - half_thickness), min(img.get_width(), center_x + half_thickness)):
			img.set_pixel(x, y, color)
