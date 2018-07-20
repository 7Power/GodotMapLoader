# Licensed under the MIT License.
# Copyright (c) 2018 Leonardo (Toshiwo) Araki

tool
extends Spatial

var smf = preload("res://addons/TerrainLoader/helpers/slippy_map_functions.gd")
var tsh = preload("res://addons/TerrainLoader/TerrainShaper/TerrainShaper.tscn")

export(String) onready var access_token
export(Vector3) onready var coordinates setget _setCoordinates
export(Vector3) onready var tilecoords setget _setTile
export(float, 0.1, 50, 0.1) onready var HeighMultiplier
export(int) var pxlx = 0 setget , _get_pxlx
export(int) var pxly = 0 setget , _get_pxly
export(bool) onready var ArrangeTiles setget _set_arrangetile
export(bool) onready var UseThreads

var TerrainHeightMap
var TerrainTexture
var ThreadML = Thread.new()
var tree = null
var scene_root = null

func _ready():
	if access_token == null:
		access_token = ""
	if UseThreads == null:
		UseThreads = false
	tree = self.get_tree()
	scene_root = tree.current_scene
	if(scene_root == null):
		scene_root = tree.edited_scene_root

func _get_pxlx():
	return pxlx
	
func _get_pxly():
	return pxly

func _setTile(_newval):
	if(_newval != null):
		_newval.x = int(_newval.x)
		_newval.y = int(_newval.y)
		_newval.z = int(_newval.z)
		if(_newval.z > 15):
			_newval.z = 15
		elif(_newval.z < 1):
			_newval.z = 1
		
		if(tilecoords != _newval):
			tilecoords = _newval
			pxlx = 1
			pxly = 1
			_setTiles(int(tilecoords.x), int(tilecoords.y), int(tilecoords.z))
	
func _setCoordinates(_newval):
	if(_newval != null):
		_newval.z = int(_newval.z)
		if(_newval.z > 15):
			_newval.z = 15
		elif(_newval.z < 1):
			_newval.z = 1
	
		if(_newval.x > 180):
			_newval.x = 180
		elif(_newval.x < -180):
			_newval.x = -180
			
		if(_newval.y > 85.0511):
			_newval.y = 85.0511
		elif(_newval.y < -85.0511):
			_newval.y = -85.0511
			
		if(coordinates != _newval):
			coordinates = _newval
			_setCoords(coordinates.x, coordinates.y, int(coordinates.z))

func _set_arrangetile(_newval):
	ArrangeTiles = _newval
	if(ArrangeTiles):
		ArrangeTilesInGrid()

func _setCoords(_lon = 0, _lat = 0, _zoom = 1):
	if(self.is_inside_tree() && _lat != null && _lon != null && _zoom != null):
		print("Setting coords")
		TerrainHeightMap = Image.new()
		TerrainTexture = Image.new()
		var tile = smf.latlon_to_tile_pxl(_lat, _lon, _zoom)
		if(tilecoords == null):
			tilecoords = Vector3()
		tilecoords.x = tile.tilex
		tilecoords.y = tile.tiley
		tilecoords.z = _zoom
		pxlx = tile.pxlx
		pxly = tile.pxly
		if(getTilexyz(tile.tilex, tile.tiley, _zoom) != null):
			print("this tile already exists, remove it first")
		else:
			_request_map(tile.tilex, tile.tiley, _zoom, false)
			_request_map(tile.tilex, tile.tiley, _zoom, true)
		
func _setTiles(_tilex = 0, _tiley = 0, _zoom = 1):
	if(self.is_inside_tree() && _tilex != null && _tiley != null && _zoom != null):
		print("Setting coords")
		TerrainHeightMap = Image.new()
		TerrainTexture = Image.new()
		var latlon = smf.tile_to_latlon(_tilex, _tiley, _zoom)
		if(coordinates == null):
			coordinates = Vector3()
		coordinates.y = latlon.lat
		coordinates.x = latlon.lon
		coordinates.z = _zoom
		if(getTilexyz(_tilex, _tiley, _zoom) != null):
			print("this tile already exists, remove it first")
		else:
			_request_map(_tilex, _tiley, _zoom, false)
			_request_map(_tilex, _tiley, _zoom, true)
	
func _request_map(_tilex = 0, _tiley = 0, _zoom = 1, _isheightmap = true):
	if(self.is_inside_tree()):
		if(access_token.length() == 0):
			print("Access token is not set")
		else:
			var map_type = "terrain-rgb"
			var double_size = ""
			if(!_isheightmap):
				map_type = "satellite"
				double_size = "@2x"
			print("Requesting %s tile x/y/z %d/%d/%d" % [map_type, _tilex, _tiley, _zoom])
			var url = "https://api.mapbox.com/v4/mapbox." + map_type + "/" + var2str(_zoom) + "/" + var2str(_tilex) + "/" + var2str(_tiley) + double_size + ".pngraw?access_token=" + access_token
			print(url)
			if(_isheightmap):
				$MapLoaderHeightMap.cancel_request()
				$MapLoaderHeightMap.request(url
				, PoolStringArray(), false, 0)
			else:
				$MapLoaderTexture.cancel_request()
				$MapLoaderTexture.request(url
				, PoolStringArray(), false, 0)

func get_image_from_bytes(_bytes, _save_path = null):
	var resp_image = Image.new()
	resp_image.create(256, 256, true, Image.FORMAT_L8)
	var png_error = 0
	if(_bytes.size() > 33):
		png_error = resp_image.load_png_from_buffer(_bytes)
	else:
		print("No heightmap tile found, using default...")
	if(png_error !=0):
		print("Image load error code: " + var2str(png_error))
	print("Image Size: " + var2str(resp_image.get_size()))
	if(_save_path != null):
		resp_image.lock()
		var save_error = resp_image.save_png(_save_path)
		if(save_error !=0):
			print("Image load error code: " + var2str(png_error))
		resp_image.unlock()
	return resp_image
	
func generate_terrain_meshes():
	if(TerrainHeightMap != null && TerrainTexture != null):
		if(TerrainHeightMap.get_size().length() > 0
		&& TerrainTexture.get_size().length() > 0):
			print("Adding Terrain tiles...")
					
			var terrain = find_node("terrain")
			if(terrain == null):
				terrain = Spatial.new()
				terrain.name = "terrain"
				self.add_child(terrain)
				terrain.set_owner(scene_root)
					
			for tile in terrain.get_children():
				if(tile.Zoom == tilecoords.z && tile.TileX == tilecoords.x && tile.TileY == tilecoords.y):
					print("replacing tile " + tile.name)
					tile.free()
			var subdivide = 1 #TerrainHeightMap.get_size().x / 256 #For now no subdivision
			var total_tiles = subdivide * subdivide
			for tile_number in range(1, total_tiles + 1):
				var terr_node = tsh.instance()
				terr_node.name = "xyz_%s_%s_%s" % [tilecoords.x, tilecoords.y, tilecoords.z]
				terrain.add_child(terr_node)
				terr_node.set_owner(scene_root)
				terr_node.SubsetShift = true
				terr_node.initialize_map(int(tilecoords.z), int(tilecoords.x), int(tilecoords.y), HeighMultiplier, subdivide, tile_number, TerrainHeightMap, TerrainTexture)
				if UseThreads:
#					ThreadML = Thread.new()
					ThreadML.start(terr_node, "SetMapShapeAndCollision", null)
				else:
					terr_node.SetMapShapeAndCollision()
	if(ArrangeTiles):
		ArrangeTilesInGrid()

func ArrangeTilesInGrid():
	var terrain = find_node("terrain")
	if(terrain != null):
		var first_tile = null
		for tile in terrain.get_children():
			if(first_tile == null):
				first_tile = tile
			else:
				var dif_x = tile.TileX - first_tile.TileX
				var dif_y =tile.TileY - first_tile.TileY
				tile.translation.x = first_tile.translation.x + (first_tile.tileAABB.size.x * dif_x)
				tile.translation.y = first_tile.translation.y
				tile.translation.z = first_tile.translation.z + (first_tile.tileAABB.size.z * dif_y)
			tile.ModifyArea(getTilexyz(tile.TileX+1, tile.TileY, tile.Zoom), getTilexyz(tile.TileX, tile.TileY+1, tile.Zoom))

func getTilexyz(_x, _y, _z):
	var terrain = find_node("terrain")
	if(terrain != null):
		for tile in terrain.get_children():
			if(tile.TileX == _x && tile.TileY == _y && tile.Zoom == _z):
				return tile
	return null
	
func handleResponse(result, response_code, headers, body, _IsHeightmap):
	if(result == HTTPRequest.RESULT_SUCCESS):
		print("Download successful, Body Size: " + var2str(body.size()))
		if(_IsHeightmap):
			TerrainHeightMap = get_image_from_bytes(body)
		else:
			TerrainTexture = get_image_from_bytes(body)
		if(TerrainHeightMap.get_size().length() > 0
			&& TerrainTexture.get_size().length() > 0):
			generate_terrain_meshes()
	else:
		print("Error/Warning code: " + var2str(result))
		print("Response code: " + var2str(response_code))

func _on_MapLoaderHeightMap_request_completed(result, response_code, headers, body):
	handleResponse(result, response_code, headers, body, true)

func _on_MapLoaderTexture_request_completed(result, response_code, headers, body):
	handleResponse(result, response_code, headers, body, false)