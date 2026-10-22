class_name SessionPlan
extends Resource
## What one sitting contains, in order. Plans live in content/sessions/.

@export var title := ""
@export var greeting := "Hi! Let's play a seeing game."
@export var farewell := "All done. Great work today!"
@export var blocks: Array[Block] = []
