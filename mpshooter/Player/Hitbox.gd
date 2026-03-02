class_name Hitbox
extends Area3D


@export var zone: String


func receive_dmg(dmg, hit):
	var multiplier = 1.0
	match zone:
		"Head":
			multiplier = 2.0
		"Body":
			multiplier = 1.0
	print(multiplier)
	var resultDmg = dmg * multiplier
	get_parent().receive_dmg(resultDmg, zone, hit)
