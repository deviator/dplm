//### vert
#version 330
in vec3 position;
uniform mat4 prj;
void main(void)
{ gl_Position = prj * vec4( position, 1.0 ); }

//### frag
#version 330
uniform vec4 color;
out vec4 out_color;
void main(void) { out_color = color; }
