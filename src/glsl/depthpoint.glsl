//### vert
#version 330
in vec4 data;
uniform mat4 prj;
out float fp;
void main(void)
{
    gl_Position = prj * vec4( data.xyz, 1.0 );
    fp = (data.w > 0.5) ? 1.0f : 0.0f;
}

//### frag
#version 330
in float fp;
uniform vec4 color;
out vec4 out_color;
void main(void)
{
    out_color = color * vec4(1,1,1, 0.2+0.8*fp );
}
