extends Node

signal cue_requested(cue: String)

const RATE: int = 22050
var volume_db: float = -9.0
var enabled: bool = true
var ambient_enabled: bool = true
var _voices: Array[AudioStreamPlayer] = []
var _streams: Dictionary = {}
var _voice_index: int = 0
var _ambient: AudioStreamPlayer
var _rng = RandomNumberGenerator.new()

func _ready() -> void:
 process_mode = Node.PROCESS_MODE_ALWAYS
 # A headless server has no sound device; do not queue endless dummy playback.
 if DisplayServer.get_name() == "headless":
  return
 _rng.seed = 781930
 for i in range(12):
  var voice = AudioStreamPlayer.new()
  add_child(voice)
  _voices.append(voice)
 var cues: Dictionary = {
  "rifle": [62.0, 0.28, 0.9, -45.0],
  "reload": [280.0, 0.14, 0.5, -95.0], "reload_done": [420.0, 0.09, 0.4, -180.0], "bullet_impact": [135.0, 0.10, 0.8, -65.0],
  "staff_charge1": [420.0,.12,.02,100.0], "staff_charge2": [620.0,.14,.02,120.0], "staff_charge3": [860.0,.18,.02,180.0],
  "staff_charge4": [980.0,.15,.02,180.0], "staff_charge5": [1120.0,.18,.02,220.0],
  "fire_cast": [390.0, 0.24, 0.65, -270.0], "fire_impact": [110.0, 0.20, 0.8, -55.0],
  "gun": [125.0, 0.12, 0.85, -90.0], "heavy": [76.0, 0.3, 0.72, -35.0],
  "parry": [920.0,.22,.14,-380.0],
  "guard": [360.0, 0.16, 0.45, -230.0],
  "sword": [170.0, 0.16, 0.6, -95.0], "nova": [65.0, 0.42, 0.55, -32.0],
  "lance": [660.0, 0.26, 0.18, -430.0], "dodge": [210.0, 0.19, 0.65, 180.0],
  "potion": [470.0, 0.5, 0.02, 430.0], "hit": [95.0, 0.18, 0.65, -60.0],
  "death": [120.0, 0.9, 0.35, -90.0], "enemy_hit": [180.0, 0.12, 0.75, -100.0],
  "enemy_death": [130.0, 0.35, 0.4, -85.0], "enemy_attack": [90.0, 0.2, 0.5, -40.0],
  "windup": [240.0, 0.25, 0.08, 90.0], "warning": [110.0, 0.5, 0.04, 90.0],
  "slam": [48.0, 0.42, 0.75, -18.0], "charge": [85.0, 0.5, 0.4, 140.0],
  "boss_phase": [65.0, 1.2, 0.15, 125.0], "boss_death": [80.0, 1.5, 0.45, -65.0],
  "pickup": [690.0, 0.23, 0.02, 430.0], "level": [360.0, 0.8, 0.02, 640.0],
  "equip": [280.0, 0.18, 0.24, 150.0], "ui": [460.0, 0.08, 0.02, 80.0],
  "seal": [260.0, 0.9, 0.04, 360.0], "victory": [330.0, 1.4, 0.02, 660.0]
 }
 for cue in cues:
  var params: Array = cues[cue]
  _streams[cue] = _synthesize(params[0], params[1], params[2], params[3])
 _streams.pistol_reload_open=_mechanical(.10,0)
 _streams.pistol_spin=_synthesize(510,.16,.85,-320)
 _streams.pistol_catch=_mechanical(.12,1)
 _streams.pistol_reload_done=_mechanical(.08,1)
 _streams.rifle_reload_open=_mechanical(.15,2)
 _streams.rifle_insert=_mechanical(.16,3)
 _streams.rifle_rack=_mechanical(.18,4)
 _streams.rifle_reload_done=_mechanical(.10,2)
 _ambient = AudioStreamPlayer.new()
 _ambient.stream = _drone()
 _ambient.volume_db = volume_db - 18.0
 add_child(_ambient)
 if enabled and ambient_enabled:
  _ambient.play()

func _exit_tree() -> void:
 for voice in _voices:
  voice.stop()
  voice.stream = null
 if is_instance_valid(_ambient):
  _ambient.stop()
  _ambient.stream = null
 _streams.clear()

func play(cue: String) -> void:
 cue_requested.emit(cue)
 if not enabled or _voices.is_empty():
  return
 if not _streams.has(cue):
  cue = "ui"
 var voice: AudioStreamPlayer = _voices[_voice_index]
 _voice_index = (_voice_index + 1) % _voices.size()
 voice.stream = _streams[cue]
 voice.volume_db = volume_db
 voice.pitch_scale = randf_range(0.95, 1.05) if cue in ["sword", "enemy_hit", "enemy_death", "hit"] else 1.0
 voice.play()

func set_enabled(value: bool) -> void:
 enabled = value
 if _ambient == null:
  return
 if value and ambient_enabled:
  _ambient.play()
 else:
  _ambient.stop()
  for voice in _voices:
   voice.stop()

func set_volume(value: float) -> void:
 volume_db = linear_to_db(clampf(value, 0.001, 1.0))
 if _ambient != null:
  _ambient.volume_db = volume_db - 18.0

func _synthesize(frequency: float, duration: float, noise_mix: float, sweep: float) -> AudioStreamWAV:
 var count: int = int(RATE * duration)
 var bytes = PackedByteArray()
 bytes.resize(count * 2)
 var phase: float = 0.0
 var smoothed_noise: float = 0.0
 for i in range(count):
  var progress: float = float(i) / float(count)
  phase += TAU * maxf(20.0, frequency + sweep * progress) / float(RATE)
  var envelope: float = minf(1.0, float(i) / (RATE * 0.012)) * pow(1.0 - progress, 1.6)
  smoothed_noise = lerpf(smoothed_noise, _rng.randf_range(-1.0, 1.0), 0.45)
  var tone: float = sin(phase) * 0.7 + sin(phase * 2.01) * 0.2 + sin(phase * 0.501) * 0.1
  var sample: float = (tone * (1.0 - noise_mix) + smoothed_noise * noise_mix) * envelope * 0.6
  bytes.encode_s16(i * 2, int(clampf(sample, -1.0, 1.0) * 32767.0))
 var stream = AudioStreamWAV.new()
 stream.format = AudioStreamWAV.FORMAT_16_BITS
 stream.mix_rate = RATE
 stream.stereo = false
 stream.data = bytes
 return stream

func _drone() -> AudioStreamWAV:
 var duration: float = 4.0
 var count: int = int(duration * RATE)
 var bytes = PackedByteArray()
 bytes.resize(count * 2)
 for i in range(count):
  var time: float = float(i) / float(RATE)
  var sample: float = sin(TAU * 55.0 * time) * 0.32 + sin(TAU * 82.5 * time) * 0.16 + sin(TAU * 110.0 * time) * 0.06
  sample *= 0.8 + 0.2 * cos(TAU * time / duration)
  bytes.encode_s16(i * 2, int(sample * 32767.0))
 var stream = AudioStreamWAV.new()
 stream.format = AudioStreamWAV.FORMAT_16_BITS
 stream.mix_rate = RATE
 stream.stereo = false
 stream.data = bytes
 stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
 stream.loop_begin = 0
 stream.loop_end = count
 return stream

func _mechanical(duration: float,kind: int) -> AudioStreamWAV:
 var count := int(RATE*duration)
 var bytes := PackedByteArray();bytes.resize(count*2)
 var previous := .0
 for i in range(count):
  var t := float(i)/RATE
  var noise := _rng.randf_range(-1,1)
  var high := noise-previous;previous=noise
  var sound := .0
  for strike in [0.0,.025+kind*.003,.065]:
   var age: float=t-strike
   if age>=0:
    sound+=(high*.23+sin(TAU*(970+kind*170)*age)*.23+sin(TAU*180*age)*.26)*exp(-age*(55 if kind<2 else 38))
  sound*=minf(1,t/.002)
  bytes.encode_s16(i*2,int(clampf(sound,-.85,.85)*32767))
 var stream := AudioStreamWAV.new();stream.format=AudioStreamWAV.FORMAT_16_BITS;stream.mix_rate=RATE;stream.data=bytes
 return stream
