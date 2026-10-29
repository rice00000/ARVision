class_name Adventure
extends Resource
## What the World plays when no session plan is given: the places and how
## colour comes back. content/adventure.tres.

@export var greeting := ""
@export var places: Array[Place] = []
## How the room looks as colour comes back, from the start (black and white)
## to full colour. Tasks' [member Task.colour] rewards move along it.
@export var colours: Array[View] = []
