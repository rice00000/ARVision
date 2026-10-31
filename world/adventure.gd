class_name Adventure
extends Resource
## What the World plays when no session plan is given: the story, the places
## and their tasks. content/adventure.tres.

@export var greeting := ""
## Said when a level is done.
@export var level_done := ""
@export var places: Array[Place] = []
