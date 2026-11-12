class_name SoundBank
extends Node
## 运行时合成的音效（柔和拨弦音、翻面的「嗖」），不依赖音频资源。

const SCALE: Array[float] = [523.25, 587.33, 659.25, 783.99, 880.0, 1046.5]
const RATE := 22050

var _tones: Dictionary[String, AudioStreamWAV] = {}
var _swishes: Dictionary[bool, AudioStreamWAV] = {}


## 本行第 index 针成针：音阶逐针上行；新线圈压在后面的针（如上针）低八度。
func play_stitch(index: int, stitch: StitchType) -> void:
	var freq := SCALE[index % SCALE.size()]
	play_tone(freq if stitch.new_loop_in_front() else freq * 0.5, 0.4, 0.3)


func play_reject() -> void:
	play_tone(196.0, 0.22, 0.25, 16.0)


func play_row_done() -> void:
	play_tone(523.25, 0.55, 0.18)
	play_tone(783.99, 0.55, 0.14)


func play_level_done() -> void:
	var tw := create_tween()
	for k in 4:
		tw.tween_callback(play_tone.bind(SCALE[k * 2 % SCALE.size()] * (1.0 if k < 3 else 2.0), 0.6, 0.25))
		tw.tween_interval(0.11)


## 翻面：翻到前面往上滑，翻到后面往下滑。
func play_swish(to_front: bool) -> void:
	if not _swishes.has(to_front):
		_swishes[to_front] = _make_swish(to_front)
	_play(_swishes[to_front])


func play_tone(freq: float, dur: float = 0.35, vol: float = 0.3, decay: float = 9.0) -> void:
	var key := "%d_%d_%d_%d" % [int(freq), int(dur * 100), int(vol * 100), int(decay)]
	if not _tones.has(key):
		_tones[key] = _make_tone(freq, dur, vol, decay)
	_play(_tones[key])


func _play(wav: AudioStreamWAV) -> void:
	var player := AudioStreamPlayer.new()
	player.stream = wav
	add_child(player)
	player.finished.connect(player.queue_free)
	player.play()


func _make_tone(freq: float, dur: float, vol: float, decay: float) -> AudioStreamWAV:
	var n := int(RATE * dur)
	var data := PackedByteArray()
	data.resize(n * 2)
	for s in n:
		var t := float(s) / RATE
		var env := exp(-t * decay) * minf(1.0, t * 300.0)
		var v := (sin(TAU * freq * t) + 0.3 * sin(TAU * freq * 2.0 * t) + 0.08 * sin(TAU * freq * 3.0 * t)) * env * vol
		data.encode_s16(s * 2, int(clampf(v, -1.0, 1.0) * 32767.0))
	return _wav(data)


## 滤波噪声 + 滑音的短促「嗖」。
func _make_swish(up: bool) -> AudioStreamWAV:
	var n := int(RATE * 0.2)
	var data := PackedByteArray()
	data.resize(n * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var lp := 0.0
	var phase := 0.0
	for s in n:
		var u := float(s) / n
		var g := u if up else 1.0 - u
		var env := sin(PI * u) * sin(PI * u)
		lp += (rng.randf_range(-1.0, 1.0) - lp) * lerpf(0.06, 0.25, g)
		phase += TAU * lerpf(620.0, 1240.0, g) / RATE
		var v := (0.9 * lp + 0.07 * sin(phase)) * env * 0.5
		data.encode_s16(s * 2, int(clampf(v, -1.0, 1.0) * 32767.0))
	return _wav(data)


func _wav(data: PackedByteArray) -> AudioStreamWAV:
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.stereo = false
	wav.data = data
	return wav
