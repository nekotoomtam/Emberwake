extends Node
var sound: AudioStreamPlayer
var volume:=.65
var muted:=false
func _ready() -> void:
 if DisplayServer.get_name()=="headless":return
 sound=AudioStreamPlayer.new();add_child(sound);sound.volume_db=-20;sound.stream=_harbor_water();sound.play()
func _harbor_water() -> AudioStreamWAV:
 var rate:=11025;var count:=rate*12;var data:=PackedByteArray();data.resize(count*2);var random:=RandomNumberGenerator.new();random.seed=7703;var low:=0.0
 for i in count:
  var t: float=float(i)/rate;low=lerpf(low,random.randf_range(-1,1),.025)
  var value: float=low*(.26+.09*sin(t*TAU/6))+random.randf_range(-1,1)*.008
  var edge: float=minf(1,minf(t,12-t)/.1);data.encode_s16(i*2,int(clampf(value*edge,-1,1)*24000))
 var stream:=AudioStreamWAV.new();stream.format=AudioStreamWAV.FORMAT_16_BITS;stream.mix_rate=rate;stream.data=data;stream.loop_mode=AudioStreamWAV.LOOP_FORWARD;stream.loop_end=count;return stream
func set_volume(value: float) -> void:
 volume=clampf(value,0,1);_sync()
func set_muted(value: bool) -> void:muted=value;_sync()
func _sync() -> void:
 if is_instance_valid(sound):sound.volume_db=linear_to_db(maxf(.001,volume))-16;sound.stream_paused=muted or volume<=0
func set_paused(value: bool) -> void:
 if is_instance_valid(sound):sound.stream_paused=value or muted or volume<=0
func shutdown() -> void:
 if is_instance_valid(sound):sound.stop();sound.stream=null
func _exit_tree() -> void:shutdown()
