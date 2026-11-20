class_name SessionPlan
extends Resource
## What one sitting contains, in order. Plans live in content/sessions/.

@export var title := ""
@export var greeting := "Hi! Let's play a seeing game."
@export var farewell := "All done. Great work today!"
@export var blocks: Array[Block] = []


func is_endless() -> bool:
	return blocks.any(func(block: Block) -> bool: return block.rounds < 0)


## Number of rounds in a finite plan, or -1 for an endless plan.
func round_count() -> int:
	var total := 0
	for block in blocks:
		if block.rounds < 0:
			return -1
		total += block.rounds
	return total
