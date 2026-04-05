extends Control

@onready var year_opt: OptionButton = %YearOption
@onready var month_opt: OptionButton = %MonthOption
@onready var day_opt: OptionButton = %DayOption
@onready var calc_btn: Button = %CalcBtn
@onready var print_btn: Button = %PrintBtn
@onready var results: VBoxContainer = %ResultsList

var _export_text: String = ""

const MONTHS := [
	"January", "February", "March", "April", "May", "June",
	"July", "August", "September", "October", "November", "December"
]
const ABBR := [
	"Jan", "Feb", "Mar", "Apr", "May", "Jun",
	"Jul", "Aug", "Sep", "Oct", "Nov", "Dec"
]


func _ready() -> void:
	var now := Time.get_datetime_dict_from_system()

	for y in range(2020, 2051):
		year_opt.add_item(str(y))
	year_opt.selected = int(now.year) - 2020

	for m in MONTHS:
		month_opt.add_item(m)
	month_opt.selected = int(now.month) - 1

	_refresh_days()
	if int(now.day) - 1 < day_opt.item_count:
		day_opt.selected = int(now.day) - 1

	year_opt.item_selected.connect(_on_date_changed)
	month_opt.item_selected.connect(_on_date_changed)
	calc_btn.pressed.connect(_calculate)
	print_btn.pressed.connect(_on_print)


func _on_date_changed(_idx: int) -> void:
	_refresh_days()


func _refresh_days() -> void:
	var prev := day_opt.selected if day_opt.item_count > 0 else 0
	day_opt.clear()
	var y := int(year_opt.get_item_text(year_opt.selected))
	var m := month_opt.selected + 1
	for d in range(1, _dim(y, m) + 1):
		day_opt.add_item(str(d))
	day_opt.selected = mini(prev, day_opt.item_count - 1)


# -- Date helpers --------------------------------------------------------------

static func _leap(y: int) -> bool:
	return (y % 4 == 0 and y % 100 != 0) or y % 400 == 0


static func _dim(y: int, m: int) -> int:
	var t := [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
	return 29 if m == 2 and _leap(y) else t[m - 1]


static func _next_day(d: Dictionary) -> Dictionary:
	var day: int = int(d.day) + 1
	var mon: int = int(d.month)
	var yr: int = int(d.year)
	if day > _dim(yr, mon):
		day = 1
		mon += 1
		if mon > 12:
			mon = 1
			yr += 1
	return {"year": yr, "month": mon, "day": day}


static func _prev_day(d: Dictionary) -> Dictionary:
	var day: int = int(d.day) - 1
	var mon: int = int(d.month)
	var yr: int = int(d.year)
	if day < 1:
		mon -= 1
		if mon < 1:
			mon = 12
			yr -= 1
		day = _dim(yr, mon)
	return {"year": yr, "month": mon, "day": day}


## Returns {expiry, next} for a period of [months] months starting on [start].
## Month arithmetic follows the BC Interpretation Act:
##   - corresponding calendar day N months later, less one day
##   - if no corresponding day exists, use the last day of that month
static func _period(start: Dictionary, months: int) -> Dictionary:
	var tm: int = int(start.month) + months
	var ty: int = int(start.year)
	while tm > 12:
		tm -= 12
		ty += 1
	var mx: int = _dim(ty, tm)
	var expiry: Dictionary
	if int(start.day) <= mx:
		expiry = _prev_day({"year": ty, "month": tm, "day": int(start.day)})
	else:
		expiry = {"year": ty, "month": tm, "day": mx}
	return {"expiry": expiry, "next": _next_day(expiry)}


static func _dkey(d: Dictionary) -> int:
	return int(d.year) * 10000 + int(d.month) * 100 + int(d.day)


static func _fmt(d: Dictionary) -> String:
	return "%s %d, %d" % [ABBR[int(d.month) - 1], int(d.day), int(d.year)]


static func _ord(n: int) -> String:
	if n % 100 >= 11 and n % 100 <= 13:
		return "%dth" % n
	match n % 10:
		1: return "%dst" % n
		2: return "%dnd" % n
		3: return "%drd" % n
		_: return "%dth" % n


# -- Calculation ---------------------------------------------------------------

func _calculate() -> void:
	for c in results.get_children():
		c.queue_free()
	_export_text = ""

	var cert := {
		"year": int(year_opt.get_item_text(year_opt.selected)),
		"month": month_opt.selected + 1,
		"day": day_opt.selected + 1,
	}

	# 5-year horizon from certification date
	var lm: int = int(cert.month) + 60
	var ly: int = int(cert.year)
	while lm > 12:
		lm -= 12
		ly += 1
	var ld: int = mini(int(cert.day), _dim(ly, lm))
	var limit: int = _dkey({"year": ly, "month": lm, "day": ld})

	_label("Five-year horizon from:  %s  to  %s" % [_fmt(cert), _fmt({"year": ly, "month": lm, "day": ld})], 13, Color(0.4, 0.4, 0.5))
	_sep()

	_line("BC Mental Health Act - Recertification Schedule")
	_line("================================================")
	_line("Involuntary Hospitalization Date:  %s" % _fmt(cert))
	_line("Five-year horizon from:    %s" % _fmt({"year": ly, "month": lm, "day": ld}))
	_line("")

	# -- Table --
	var p0 := _period(cert, 1)

	var grid := GridContainer.new()
	grid.columns = 4
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 0)
	grid.add_theme_constant_override("v_separation", 0)
	results.add_child(grid)

	# Header row
	for h in ["Action", "Length of Involuntary Admission", "Begins", "Expires"]:
		_cell(grid, h, 15, Color(0.2, 0.15, 0.4), true, -1)

	# Row 0: 1st Medical Certificate
	_cell(grid, "1st Medical Certificate (Form 4.1)", 15, Color(0.3, 0.2, 0.5), true, 0, 0)
	_cell(grid, "48 hours", 15, Color(0.15, 0.15, 0.15), false, 0)
	_cell(grid, "%s (AKA - involuntary hospitalization date)" % _fmt(cert), 15, Color(0.15, 0.15, 0.15), false, 0)
	_cell(grid, "48 hours after Form 4.1 created on %s" % _fmt(cert), 15, Color(0.75, 0.2, 0.3), false, 0)

	# Row 1: 2nd Medical Certificate
	_cell(grid, "2nd Medical Certificate (Form 4.2)", 15, Color(0.3, 0.2, 0.5), true, 1, 0)
	_cell(grid, "1 month from involuntary hospitalization date (minus 1 day)", 15, Color(0.15, 0.15, 0.15), false, 1)
	_cell(grid, _fmt(cert), 15, Color(0.15, 0.15, 0.15), false, 1)
	_cell(grid, "%s @11:59pm" % _fmt(p0.expiry), 15, Color(0.75, 0.2, 0.3), false, 1)

	# Renewal rows
	var cur: Dictionary = p0.next
	var idx := 0

	while true:
		var dur: int
		var action: String

		if idx == 0:
			dur = 1
			action = "1st Renewal"
		elif idx == 1:
			dur = 3
			action = "2nd Renewal"
		else:
			dur = 6
			if idx == 2:
				action = "3rd Renewal"
			else:
				action = "%s Renewal" % _ord(idx + 1)

		var p := _period(cur, dur)
		var months_str := "%d month%s (minus 1 day)" % [dur, "" if dur == 1 else "s"]

		var row_num := idx + 2
		_cell(grid, "%s (Form 6)" % action, 15, Color(0.3, 0.2, 0.5), true, row_num, 0)
		_cell(grid, months_str, 15, Color(0.15, 0.15, 0.15), false, row_num)
		_cell(grid, _fmt(cur), 15, Color(0.15, 0.15, 0.15), false, row_num)
		_cell(grid, "%s @11:59pm" % _fmt(p.expiry), 15, Color(0.75, 0.2, 0.3), false, row_num)

		if _dkey(p.next) > limit:
			break

		cur = p.next
		idx += 1

	_sep()
	_label("Calculated per the Mental Health Act [RSBC 1996] CHAPTER 288 and BC Interpretation Act [RSBC 1996] CHAPTER 238:", 12, Color(0.45, 0.45, 0.5))
	_label("A \"month\" = corresponding calendar day of the target month, less one day.", 12, Color(0.45, 0.45, 0.5))
	_label("When no corresponding day exists, the last day of that month is used.", 12, Color(0.45, 0.45, 0.5))
	_label("Always manually double check calculations.", 12, Color(0.45, 0.45, 0.5))
	_sep()
	_label("Note: The Act offers no guidance regarding how many days prior to the end of the", 12, Color(0.45, 0.45, 0.5))
	_label("last month of a period the examination must be completed, however, it is", 12, Color(0.45, 0.45, 0.5))
	_label("recommended this be done reasonably close to the end of the period.", 12, Color(0.45, 0.45, 0.5))


func _label(text: String, font_size: int = 14, color := Color.WHITE) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	results.add_child(l)


func _rich_label(bbcode: String, font_size: int = 14) -> void:
	var l := RichTextLabel.new()
	l.bbcode_enabled = true
	l.fit_content = true
	l.scroll_active = false
	l.add_theme_font_size_override("normal_font_size", font_size)
	l.text = bbcode
	results.add_child(l)


func _cell(grid: GridContainer, text: String, font_size: int = 11, color := Color.WHITE, bold := false, row: int = 0, col: int = -1) -> void:
	var panel := PanelContainer.new()
	if col == 0:
		panel.custom_minimum_size.x = 280
	var style := StyleBoxFlat.new()
	if row == -1:
		# Header
		style.bg_color = Color(0.85, 0.82, 0.95)
	elif row % 2 == 0:
		style.bg_color = Color(1.0, 1.0, 1.0)
	else:
		style.bg_color = Color(0.94, 0.93, 0.98)
	style.border_color = Color(0.75, 0.7, 0.85)
	style.border_width_top = 1
	style.border_width_bottom = 1
	style.border_width_left = 1
	style.border_width_right = 1
	style.content_margin_left = 6
	style.content_margin_right = 6
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	panel.add_theme_stylebox_override("panel", style)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel.add_child(l)
	grid.add_child(panel)


func _sep() -> void:
	results.add_child(HSeparator.new())


func _line(text: String) -> void:
	_export_text += text + "\n"


func _on_print() -> void:
	if _export_text.is_empty():
		return
	var html := _build_html()
	var path := OS.get_system_dir(OS.SYSTEM_DIR_DOCUMENTS).path_join("MHA_Recertification.html")
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f:
		f.store_string(html)
		f.close()
		OS.shell_open(path)


func _build_html() -> String:
	var lines := _export_text.split("\n")
	var body := ""
	for line in lines:
		if line.begins_with("BC Mental Health Act"):
			body += "<h1>%s</h1>\n" % line
		elif line.begins_with("===="):
			continue
		elif line.begins_with("Involuntary Hospitalization Date:"):
			body += "<p class=\"cert-date\">%s</p>\n" % line
		elif line.begins_with("Two-year horizon:"):
			body += "<p class=\"horizon\">%s</p>\n" % line
		elif line.begins_with("----"):
			body += "<hr>\n"
		elif line.begins_with("    Renewal must be completed by:"):
			body += "<p class=\"deadline\">%s</p>\n" % line.strip_edges()
		elif line.begins_with("    Period:"):
			body += "<p class=\"period\">%s</p>\n" % line.strip_edges()
		elif line.begins_with("Calculated per") or line.begins_with("A \"month\"") or line.begins_with("When no corresponding"):
			body += "<p class=\"note\">%s</p>\n" % line
		elif line.begins_with("Note:") or line.begins_with("last month of") or line.begins_with("recommended this"):
			body += "<p class=\"note\">%s</p>\n" % line
		elif not line.is_empty():
			body += "<h3>%s</h3>\n" % line

	return """<!DOCTYPE html>
<html><head>
<meta charset="utf-8">
<title>BC MHA Recertification Schedule</title>
<style>
  body { font-family: Arial, sans-serif; max-width: 700px; margin: 40px auto; color: #222; }
  h1 { font-size: 20px; margin-bottom: 4px; }
  h3 { font-size: 14px; margin: 12px 0 2px 0; color: #333; }
  .cert-date { font-size: 16px; font-weight: bold; color: #1a5276; }
  .horizon { font-size: 12px; color: #777; margin-top: 0; }
  .period { margin: 2px 0 2px 20px; font-size: 13px; }
  .deadline { margin: 2px 0 8px 20px; font-size: 13px; font-weight: bold; color: #c0392b; }
  .note { font-size: 11px; color: #888; margin: 2px 0; }
  hr { border: none; border-top: 1px solid #ccc; margin: 4px 0; }
  @media print { body { margin: 20px; } }
</style>
</head><body>
%s
<script>window.onload = function() { window.print(); }</script>
</body></html>""" % body
