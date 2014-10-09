module draw.object.base;

public import des.gl.base;
public import des.math.linear;

import std.stdio;

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

    vec4 light_color = vec4(1);

    float dc = 0.1;

    float dln = dot(ldir,norm);

    col_coef = dc + max(0.0f,dln) * (1.0f-dc);

    vec3 lnpp = norm * dln;

    vec3 lcam = lnpp + lnpp - ldir;
    if( lcam.z > 0 )
        br_coef = pow( 1.0f - length( lcam.xy ), 4 );

    out_color = color * vec4(vec3(col_coef),1) + light_color * br_coef;
}`
};

class BaseDrawObject : GLObj, Node
{
protected:
    GLBuffer pos, norm;
    CommonShaderProgram shader;

    Node _parent;

    abstract void fillBuffers();
    abstract void drawFunc();

    col4 clr;

public:

    this( Node p )
    {
        shader = registerChildEMM( new CommonShaderProgram( SS_BASE ) );
        auto loc = shader.getAttribLocations( "position", "normal" );

        pos  = registerChildEMM( new GLBuffer( GLBuffer.Target.ARRAY_BUFFER ) );
        setAttribPointer( pos, loc[0], 3, GLType.FLOAT );

        if( loc[0] < 0 ) assert( 0, "no position in shader" );
        if( loc[1] < 0 ) stderr.writeln( "no normal in shader" );

        if( loc[1] >= 0 )
        {
            norm = registerChildEMM( new GLBuffer( GLBuffer.Target.ARRAY_BUFFER ) );
            setAttribPointer( norm, loc[1], 3, GLType.FLOAT );
        }

        _parent = p;

        clr = col4( .5, .5, .5, 1 );

        fillBuffers();
    }

    void draw( Camera cam )
    {
        vao.bind();
        shader.use();

        auto rs = cam.resolve(this);

        shader.setUniformMat( "prj", cam(this) );
        shader.setUniformMat( "resolve", rs );
        shader.setUniformVec( "resolved_light_pos", (vec4(0,0,0,1)).xyz );
        shader.setUniformVec( "color", clr );

        glEnable( GL_DEPTH_TEST );

        drawFunc();
    }

    @property
    {
        col4 color() const { return clr; }
        col4 color( in col4 n ) 
        { clr = n; return clr; }
    }

    const @property
    {
        mat4 matrix() { return mat4(); }
        const(Node) parent() { return _parent; }
    }
}
