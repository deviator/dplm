module draw.object.shader;

public import des.gl.base;

enum ShaderSource SS_BASE =
{
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
};

enum ShaderSource SS_SIMPLE =
{
`#version 330
in vec3 position;
uniform mat4 prj;
void main(void)
{ gl_Position = prj * vec4( position, 1.0 ); }`,

`#version 330
uniform vec4 color;
out vec4 out_color;
void main(void) { out_color = color; }`
};

