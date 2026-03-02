extends RigidBody3D


@onready var Anim = $AnimationPlayer

#Inventory
@export var itemName = ""
@export var path = ""
@export var icon: Texture
@export var weight = 1
@export var canBeTaken = true
@export var isForBuilding = false
@export var isOneUsage = true
#Properties
var properties = []



func change_props(_props):
	pass

func _ready():
	continuous_cd = true

func changed():
	pass
