module draw.object.shader;

public import des.gl.base;

enum SS_ShadeObject = ShaderSource(
`#version 330
in vec3 position;
in vec3 normal;

uniform mat4 prj;
uniform mat4 resolve;
uniform vec3 resolved_light_pos;

out vec3 v_norm;
out vec3 v_light;

void main(void)
{
    gl_Position = prj * vec4( position, 1.0 );
    v_norm  = normalize( (resolve * vec4( normal, 0.0 )).xyz );
    v_light = normalize( resolved_light_pos - (resolve * vec4( position, 1.0 )).xyz );
}`,

`#version 330

in vec3 v_norm;
in vec3 v_light;

uniform vec4 color;

out vec4 out_color;

void main(void)
{
    float col_coef = 0.0f;
    float br_coef = 0.0f;

    vec3 norm = v_norm;
    vec3 ldir = v_light;

    float dc = 0.1;
    float dln = dot(ldir,norm);
    col_coef = dc + max(0.0f,dln) * (1.0f-dc);

    out_color = color * vec4(vec3(col_coef),1);
}`
);

enum SS_Simple = ShaderSource(
`#version 330
in vec3 position;
uniform mat4 prj;
void main(void)
{ gl_Position = prj * vec4( position, 1.0 ); }`,

`#version 330
uniform vec4 color;
out vec4 out_color;
void main(void) { out_color = color; }`
);

enum SS_WorldMap = ShaderSource(
`#version 330
in int data;

out float val;
out float prop;
out vec4 v_color;

uniform int size_x;
uniform int size_y;

void main(void)
{
    vec3 pos;

    pos.z = int( gl_VertexID / (size_x * size_y) ) + 0.5;
    int k = gl_VertexID % ( size_x * size_y );
    pos.y = int( k / size_x ) + 0.5;
    pos.x = int( k % size_x ) + 0.5;

    gl_Position = vec4( pos, 1.0 );

    val = float(data>1);
    prop = float(data>0);
    v_color = vec4( val, 0, 1-val, 0.1 + prop * 0.45 + val * 0.45 );
}`,
`#version 330
layout(points) in;
layout(triangle_strip,max_vertices=36) out;

in float val[];
in float prop[];
in vec4 v_color[];

out vec4 g_color;

uniform float psize;
uniform mat4 prj;

void main(void)
{
    float sz = psize * (1+prop[0]+val[0]);
    vec3 p[8] = vec3[8](
        gl_in[0].gl_Position.xyz + vec3( 1, 1, 1) * sz,
        gl_in[0].gl_Position.xyz + vec3(-1, 1, 1) * sz,
        gl_in[0].gl_Position.xyz + vec3(-1,-1, 1) * sz,
        gl_in[0].gl_Position.xyz + vec3( 1,-1, 1) * sz,
        gl_in[0].gl_Position.xyz + vec3( 1, 1,-1) * sz,
        gl_in[0].gl_Position.xyz + vec3(-1, 1,-1) * sz,
        gl_in[0].gl_Position.xyz + vec3(-1,-1,-1) * sz,
        gl_in[0].gl_Position.xyz + vec3( 1,-1,-1) * sz
    );

    int ind[24] = int[24](
        0, 1, 2, 3, // top
        3, 2, 6, 7, // right
        0, 3, 7, 4, // back
        1, 0, 4, 5, // left
        2, 1, 5, 6, // front
        7, 6, 5, 4  // bottom
    );

    for( int i=0; i<6; i++ )
    {
        for( int j=0; j<4; j++ )
        {
            gl_Position = prj * vec4( p[ind[i*3+j]], 1 );
            g_color = v_color[0];
            EmitVertex();
        }
        EndPrimitive();
    }
}
`,
`#version 330
in vec4 g_color;
out vec4 out_color;
void main(void) { out_color = g_color; }`
);
