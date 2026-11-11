extends RefCounted
## Results for the motion lab's optional post-block view (Nov 10 plan). Pure functions over
## saved records, so the graphs and the tests read exactly the same numbers.
##
## Rules kept here:
## * ELIGIBLE = a review-block attempt, answered, with no assistance. Only eligible judgments
##   enter "correct out of N", the median and the accuracy-versus-coherence denominator.
## * Interrupted, abandoned, assisted and missing attempts stay visible as counts and gaps; they
##   are never turned into wrong answers or zero times.
## * Accuracy versus coherence pools only blocks with the same dataset_id AND the same condition
##   key (everything except coherence, seeds and direction). Different conditions are separate
##   series. Observed points with 95 % Wilson intervals only: no fitted curve, no threshold.
## * Pooling is recomputed from the records every time, de-duplicated by (record, attempt id), so
##   reopening the results can never count a trial twice.

const Z := 1.959964   # 95 %


static func is_eligible(a: Dictionary) -> bool:
	return a.get("purpose", "") == "review" and a.get("status", "") == "answered" \
		and String(a.get("answer", "")) != "" and Array(a.get("assistance", [])).is_empty()


## One row per trial slot of [param block]: the answered attempt if any (else a gap), plus the
## attempts that did not count.
static func outcome_rows(block: Dictionary) -> Array:
	var rows: Array = []
	for slot in range(1, int(block.get("trials_planned", 0)) + 1):
		var row := {slot = slot, direction = block.planned[slot - 1], answered = false, eligible = false,
			correct = null, latency_s = null, coherence_pct = null, not_counted = []}
		for a: Dictionary in block.get("attempts", []):
			if int(a.slot) != slot:
				continue
			if a.status == "answered":
				row.answered = true
				row.eligible = is_eligible(a)
				row.correct = a.correct
				row.coherence_pct = snappedf(float(a.get("coherence_realized", a.coherence)) * 100.0, 0.1)
				if a.has("latency_ms"):
					row.latency_s = snappedf(float(a.latency_ms) / 1000.0, 0.001)
				row.assisted = not Array(a.get("assistance", [])).is_empty()
				row.attempt = a.id
			else:
				row.not_counted.append({attempt = a.id, status = a.status})
		rows.append(row)
	return rows


## Counts for the outcome view's caption.
static func block_summary(block: Dictionary) -> Dictionary:
	var out := {correct = 0, eligible = 0, assisted = 0, missing = 0, interrupted = 0, abandoned = 0}
	for row: Dictionary in outcome_rows(block):
		if row.eligible:
			out.eligible += 1
			out.correct += 1 if row.correct == true else 0
		elif row.answered:
			out.assisted += 1
		else:
			out.missing += 1
		for n: Dictionary in row.not_counted:
			if n.status == "interrupted":
				out.interrupted += 1
			elif n.status == "abandoned":
				out.abandoned += 1
	return out


## Median time to registered answer (s) over eligible trials, with its n. null when n = 0.
static func median_latency(block: Dictionary) -> Dictionary:
	var values: Array = []
	for row: Dictionary in outcome_rows(block):
		if row.eligible and row.latency_s != null:
			values.append(float(row.latency_s))
	values.sort()
	var n := values.size()
	if n == 0:
		return {median_s = null, n = 0}
	var mid := n / 2
	var median: float = values[mid] if n % 2 == 1 else (values[mid - 1] + values[mid]) / 2.0
	return {median_s = snappedf(median, 0.001), n = n}


## 95 % Wilson score interval for k successes out of n. [lo, hi] as proportions; [] when n = 0.
static func wilson(k: int, n: int) -> Array:
	if n <= 0:
		return []
	var p := float(k) / n
	var z2 := Z * Z
	var denom := 1.0 + z2 / n
	var centre := (p + z2 / (2.0 * n)) / denom
	var half := Z * sqrt(p * (1.0 - p) / n + z2 / (4.0 * n * n)) / denom
	return [maxf(0.0, centre - half), minf(1.0, centre + half)]


## Accuracy-versus-coherence series for one dataset. [param records] are whole records (saved or
## in memory). [param only_block] = "stem/blockid" limits to one block (the "current block" view).
## Returns {condition_key: {label, points: [{coherence_pct, k, n, accuracy, ci, left, right, blocks}]}}.
static func coherence_series(records: Array, dataset_id: String, only_block := "") -> Dictionary:
	var seen := {}
	var series := {}
	for r: Dictionary in records:
		if r.get("dataset_id", "") != dataset_id:
			continue
		for b: Dictionary in r.get("blocks", []):
			var block_ref := "%s/%s" % [r.get("file_stem", "?"), b.id]
			if only_block != "" and block_ref != only_block:
				continue
			var key: String = b.get("condition_key", "")
			if not series.has(key):
				series[key] = {label = b.get("condition_label", key), by_level = {}}
			for a: Dictionary in b.get("attempts", []):
				var uid := "%s/%s" % [r.get("file_stem", "?"), a.id]
				if seen.has(uid) or not is_eligible(a):
					continue
				seen[uid] = true
				var level := snappedf(float(a.get("coherence_realized", a.coherence)) * 100.0, 0.1)
				var bucket: Dictionary = series[key].by_level.get(level, {k = 0, n = 0, left = 0, right = 0, blocks = []})
				bucket.n += 1
				bucket.k += 1 if a.correct == true else 0
				bucket.left += 1 if a.direction == "left" else 0
				bucket.right += 1 if a.direction == "right" else 0
				if block_ref not in bucket.blocks:
					bucket.blocks.append(block_ref)
				series[key].by_level[level] = bucket
	var out := {}
	for key: String in series:
		var points: Array = []
		var levels: Array = series[key].by_level.keys()
		levels.sort()
		for level: float in levels:
			var b: Dictionary = series[key].by_level[level]
			points.append({coherence_pct = level, k = b.k, n = b.n,
				accuracy = float(b.k) / b.n, ci = wilson(b.k, b.n),
				left = b.left, right = b.right, blocks = b.blocks})
		if not points.is_empty():
			out[key] = {label = series[key].label, points = points}
	return out


## Every saved record in [param dir] for [param dataset_id], with [param current] (in memory)
## replacing its own saved copy. Synthetic fixtures live in their own directory and dataset.
static func dataset_records(dir: String, dataset_id: String, current: Dictionary) -> Array:
	var out: Array = []
	var absolute := ProjectSettings.globalize_path(dir)
	var stem: String = current.get("file_stem", "")
	if DirAccess.dir_exists_absolute(absolute):
		for name in DirAccess.get_files_at(absolute):
			if not name.ends_with(".json") or name == "latest.json" or name.trim_suffix(".json") == stem:
				continue
			var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(absolute.path_join(name)))
			if parsed is Dictionary and parsed.get("dataset_id", "") == dataset_id:
				out.append(parsed)
	if not current.is_empty():
		out.append(current)
	return out
