//### vert
#version 330

in uint meas;
in float ts;
in vec2 val;

out vec4 v_color;

uniform int size_x;
uniform int size_y;
uniform mat4 prj;
uniform float time;

vec4 oldColor( float diff )
{
    float k = diff * 0.05;
    float lim = 0.8;
    if( k > lim ) k = lim;
    return vec4(0,1,0,1) * k;
}

void main(void)
{
    vec3 pos;

    pos.z = int( gl_VertexID / (size_x * size_y) ) + 0.5;
    int k = gl_VertexID % ( size_x * size_y );
    pos.y = int( k / size_x ) + 0.5;
    pos.x = int( k % size_x ) + 0.5;

    gl_Position = prj * vec4( pos, 1.0 );

    if( meas > 0U ) // has info
    {
        v_color = ( vec4(1,0,0,1) + oldColor( time - ts ) ) * val.x +
                    vec4(0,0,1,1) * ( 1 - val.x );
        gl_PointSize = val.x > 0.1 ? 4 * sqrt(val.x) : 0;
    }
    else // no info
    {
        v_color = vec4( 0, 0, 1, 0.2 );
        gl_PointSize = 4;
    }
}

//### frag
#version 330
in vec4 v_color;
out vec4 out_color;
void main(void) { out_color = v_color; }
