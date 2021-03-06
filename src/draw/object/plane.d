module draw.object.plane;

import std.stdio;

public import draw.object.base;

class Plane : BaseDrawObject
{
protected:
    GLBuffer pos, norm, index;

    override void prepareBuffers()
    {
        createBuffers();

        auto pos_data = [
            vec3( 1, 1, 0 ), vec3(-1, 1, 0 ),
            vec3(-1,-1, 0 ), vec3( 1,-1, 0 )
            ];

        auto norm_data = multiElem( 4, vec3( 0, 0, 1) );

        pos.setData( pos_data, GLBuffer.Usage.STATIC_DRAW );
        norm.setData( norm_data, GLBuffer.Usage.STATIC_DRAW );
        index.setData( [0,1,2,0,2,3], GLBuffer.Usage.STATIC_DRAW );
    }

    void createBuffers()
    {
        auto bufs = createArrayBuffersFromAttributeInfo(
                APInfo( "position", 3, GLType.FLOAT ),
                APInfo( "normal", 3, GLType.FLOAT ),
                );

        pos  = bufs["position"];
        norm = bufs["normal"];

        index = createIndexBuffer();
    }

    override void preDraw()
    {
        super.preDraw();
        index.bind();
        glEnable( GL_DEPTH_TEST );
    }

public:

    this( SpaceNode p=null )
    {
        super( p, readShader( "shadeobject.glsl" ) );
        clr = col4( vec3(0.7), 1 );
    }

    void setOffsetAndSize( vec3 pos, vec2 size )
    { self_mtr = mat4.diag(vec4(size/2,1,1)).setCol(3,vec4(pos,1)); }

    override void draw( Camera cam )
    {
        auto rs = cam.resolve(this);

        shader.setUniform!mat4( "prj", cam.projection.matrix * cam.resolve(this) );
        shader.setUniform!mat4( "resolve", rs );
        shader.setUniform!vec3( "resolved_light_pos", vec3(0) );
        shader.setUniform!vec4( "color", vec4(clr) );

        drawElements( DrawMode.TRIANGLES );
    }
}
