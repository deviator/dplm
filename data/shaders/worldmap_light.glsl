//### vert
#version 330
in float data;

out vec4 v_color;

uniform int size_x;
uniform int size_y;
uniform mat4 prj;

void main(void)
{
    vec3 pos;

    pos.z = int( gl_VertexID / (size_x * size_y) ) + 0.5;
    int k = gl_VertexID % ( size_x * size_y );
    pos.y = int( k / size_x ) + 0.5;
    pos.x = int( k % size_x ) + 0.5;

    gl_Position = prj * vec4( pos, 1.0 );

    if( data == data )
    {
        // has info
        if( data > 0 )
        {
            // has object
            v_color = vec4(1,0,0,1);
            gl_PointSize = 4;
        }
        else
        {
            // no object
            v_color = vec4(0);
            gl_PointSize = 0;
        }
    }
    else
    {
        // no info
        v_color = vec4( 0, 0, 1, 0.2 );
        gl_PointSize = 4;
    }
}

//### frag
#version 330
in vec4 v_color;
out vec4 out_color;
void main(void) { out_color = v_color; }
