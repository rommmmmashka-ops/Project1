extends Control

@onready var Item1 = $TextureRect
@onready var Item2 = $TextureRect2
@onready var Item3 = $TextureRect3
@onready var Item4 = $TextureRect4

@onready var Count1 = $Count
@onready var Count2 = $Count2
@onready var Count3 = $Count3
@onready var Count4 = $Count4

func _ready():
	pass

func _process(_delta):
	pass


func change(Inventory):
	#print("OK")
	if Inventory[0]:
		Item1.texture = Inventory[0].Icon
		Count1.text = str(Inventory[0].Count)
	else:
		Item1.texture = null
		Count1.text = ""
	if Inventory[1]:
		Item2.texture = Inventory[1].Icon
		Count2.text = str(Inventory[1].Count)
	else:
		Item2.texture = null
		Count2.text = ""
	if Inventory[2]:
		Item3.texture = Inventory[2].Icon
		Count3.text = str(Inventory[2].Count)
	else:
		Item3.texture = null
		Count3.text = ""
	if Inventory[3]:
		Item4.texture = str(Inventory[3].Count)
		Count4.text = Inventory[3].Count
	else:
		Item4.texture = null
		Count4.text = ""
