//### vert
#version 330
in vec3 pos;
uniform mat4 prj;
void main(void)
{ gl_Position = prj * vec4( pos, 1.0 ); }

//### frag
#version 330
in float fp;
uniform vec4 color;
out vec4 out_color;
void main(void) { out_color = color; }
