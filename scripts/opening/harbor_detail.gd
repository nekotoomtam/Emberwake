extends "res://scripts/coast_form_detail.gd"
func cylinder(at: Vector3,radius: float,height: float,mat: Material,segments: int=16,upper: float=-1) -> void:
 if upper<0:upper=radius
 for i in segments:
  var a: float=TAU*i/segments;var b: float=TAU*(i+1)/segments
  var p:=at+Vector3(cos(a)*radius,-height*.5,sin(a)*radius);var q:=at+Vector3(cos(b)*radius,-height*.5,sin(b)*radius)
  var u:=at+Vector3(cos(a)*upper,height*.5,sin(a)*upper);var v:=at+Vector3(cos(b)*upper,height*.5,sin(b)*upper)
  var normal_:=Vector3(cos((a+b)*.5),0,sin((a+b)*.5))
  _triangle(p,u,v,normal_,mat);_triangle(p,v,q,normal_,mat)
  _triangle(at+Vector3.UP*height*.5,u,v,Vector3.UP,mat);_triangle(at-Vector3.UP*height*.5,q,p,Vector3.DOWN,mat)
 count+=1
func quad(a: Vector3,b: Vector3,c: Vector3,d: Vector3,mat: Material) -> void:
 var normal_: Vector3=(b-a).cross(c-a).normalized()
 if normal_.y<-.2:normal_=-normal_
 _triangle(a,b,c,normal_,mat);_triangle(a,c,d,normal_,mat);count+=1
