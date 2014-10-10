module draw.object.plane;

public import draw.object.base;

class Plane : BaseDrawObject
{
protected:

    override void fillBuffers()
    {
        auto pos_data = [
            // top
            vec3( 1, 1, 0), vec3(-1,-1, 0), vec3( 1,-1, 0),
            vec3( 1, 1, 0), vec3(-1, 1, 0), vec3(-1,-1, 0),
            ];

        auto norm_data = multiElem( 6, vec3( 0, 0, 1) );

        pos.setData( pos_data, GLBuffer.Usage.STATIC_DRAW );

        if( norm !is null )
            norm.setData( norm_data, GLBuffer.Usage.STATIC_DRAW );
    }

    override void drawFunc()
    {
        if( pos.elementCount > 0 )
            glDrawArrays( GL_TRIANGLES, 0, cast(uint)pos.elementCount );
    }

public:

    this( Node p ) { super(p); }

    void setOffsetAndSize( vec3 pos, vec2 size )
    { mtr = mat4.diag(vec4(size/2,1,1)).setCol(3,vec4(pos,1)); }
}
