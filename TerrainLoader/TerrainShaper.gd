# Licensed under the MIT License.
# Copyright (c) 2018 Leonardo (Toshiwo) Araki

tool
extends StaticBody

export(int) var Zoom = 1 setget _setZoom
export(float) var TileX = 0
export(float) var TileY = 0
export(float) var Size  = 0 setget _setSize
export(float, 0.1, 50, 0.1) var HeigthMultiplier = 1 setget _setHeightM
export(int, 1, 1024, 1) var Subset = 1 setget _setSubSection
export(bool) var SubsetShift = false
export(int, 1, 32) var DivideInto = 4 setget _setDivideInto
export(String, FILE, "*.png, *.jpg, *.jpeg") var TerrainHeightMapPath setget _setMap
export(String, FILE, "*.png, *.jpg, *.jpeg") var TerrainTexturePath setget _setMapTexture
export(String, FILE, "*.tres") var MeshPath
export(Mesh) var ShapeMesh
export(ConcavePolygonShape) var Coll
export(Image) var TerrainImage = Image.new()
export(Image) var TerrainTextureImage = Image.new()

var hmp = preload("res://TerrainLoader/HeightmapParser.gd")
var NumberOfSections = 4
var HeightMap = []
var hmTool = hmp.new()

func _setZoom(_newvalue):
	if(Zoom != _newvalue):
		Zoom = _newvalue
		SetMapShapeAndCollision()
	
func _setSize(_newvalue):
	if(Size != _newvalue):
		Size = _newvalue
		SetMapShapeAndCollision()
	
func _setHeightM(_newvalue):
	if(HeigthMultiplier != _newvalue):
		HeigthMultiplier = _newvalue
		SetMapShapeAndCollision()
	
func _setSubSection(_newvalue):
	if(Subset != _newvalue):
		Subset = _FixSubset(_newvalue)
		SetMapShapeAndCollision()
	
func _setDivideInto(_newvalue):
	if(DivideInto != _newvalue):
		DivideInto = _newvalue
		Subset = _FixSubset(Subset)
		SetMapShapeAndCollision()
	
func _setMap(_newvalue):
	if(TerrainHeightMapPath != _newvalue):
		TerrainHeightMapPath = _newvalue
		TerrainImage.load(TerrainHeightMapPath)
		SetMapShapeAndCollision()
		
func _setMapTexture(_newvalue):
	if(TerrainTexturePath != _newvalue):
		TerrainTexturePath = _newvalue
		TerrainTextureImage.load(TerrainTexturePath)
		SetMapShapeAndCollision()
	
func _FixSubset(_subsVal):
	NumberOfSections = DivideInto * DivideInto
	if(_subsVal > NumberOfSections):
		_subsVal = NumberOfSections
	return _subsVal


func _ready():
	SetMapShapeAndCollision()

func initialize_map(_zoom = 1, _tilex = 0, _tiley = 0, _hmultiplier = 1, _divide = 4, _tile = 1, _hm_img = Image.new(), _txtr_img = Image.new(), _mesh_path = null, _subsetShift = true):
	HeigthMultiplier = _hmultiplier
	Zoom = _zoom
	TileX = _tilex
	TileY = _tiley
	DivideInto = _divide
	Subset = _tile
	SubsetShift = _subsetShift
	TerrainImage = _hm_img
	TerrainTextureImage = _txtr_img
	MeshPath = _mesh_path	
	$TerrainMesh.material_override = hmTool.SetMaterialTexture(_txtr_img)
	
func SetMapShapeAndCollision(params = null):
	if(ShapeMesh != null):
		$TerrainMesh.mesh = ShapeMesh
	if(Coll != null):
		$TerrainCollision.shape = Coll
	if(TerrainImage != null
		&& TerrainTextureImage != null
		&& !TerrainImage.is_empty()
		&& !TerrainTextureImage.is_empty()
		&& ($TerrainCollision.shape == null
		|| $TerrainMesh.mesh == null)):
#		HeightMap = hmTool.GenerateHeightMap(TerrainImage, TerrainTextureImage, Subset, DivideInto)
#		$TerrainMesh.mesh = hmTool.createMesh(HeightMap, Size, HeigthMultiplier, Zoom, Subset, DivideInto, SubsetShift, MeshPath)

		if(Zoom > 6):
			$TerrainMesh.mesh = hmTool.createMeshFromImage(TerrainImage, TerrainTextureImage, 0, HeigthMultiplier, Zoom, TileX, TileY, Subset, DivideInto, false)
		else:
			$TerrainMesh.mesh = hmTool.CreateMeshFromImage_sph(TerrainImage, TerrainTextureImage, 0, HeigthMultiplier, Zoom, TileX, TileY, Subset, DivideInto, false)
		ShapeMesh = $TerrainMesh.mesh
		var pos = $TerrainMesh.get_aabb()
		pos.size.y = 0
		self.translation = -pos.position - pos.size/2
		$TerrainCollision.shape = ConcavePolygonShape.new()
		$TerrainCollision.shape.set_faces($TerrainMesh.mesh.get_faces())
		Coll = $TerrainCollision.shape
		if(MeshPath != null):
			ResourceSaver.save(MeshPath, $TerrainMesh.mesh)
		if(SubsetShift):
			var Coords = hmTool._subsetToXYCoords(Subset, DivideInto)
			var actual_size = TerrainImage.get_width() / DivideInto
			var dist = 1
			if(Size != 0):
				actual_size = Size
			var x_shift = Coords["y"] * (actual_size - dist) - (actual_size - dist) * 0.5
			var z_shift = - Coords["x"] * (actual_size - dist) + (actual_size - dist) * 0.5
			self.translate(Vector3(x_shift, 0, z_shift))
		print("Terrain mesh generated")
		
func ModifyArea(_nextx, _nexty):
	var shapex = null
	var shapey = null
	if(_nextx != null):
		shapex = _nextx.ShapeMesh
	if(_nexty != null):
		shapey = _nexty.ShapeMesh
	hmTool.AlterTerrainMesh(ShapeMesh, shapex, shapey)
	