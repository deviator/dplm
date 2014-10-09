module draw.object.cube;

public import draw.object.base;

class Cube : BaseDrawObject
{
protected:

    override void fillBuffers()
    {
        auto pos_data = [
            // top
            vec3( 1, 1, 1), vec3(-1,-1, 1), vec3( 1,-1, 1),
            vec3( 1, 1, 1), vec3(-1, 1, 1), vec3(-1,-1, 1),

            // bottom
            vec3( 1, 1,-1), vec3(-1,-1,-1), vec3( 1,-1,-1),
            vec3( 1, 1,-1), vec3(-1, 1,-1), vec3(-1,-1,-1),

            // right
            vec3( 1, 1, 1), vec3( 1,-1, 1), vec3( 1, 1,-1),
            vec3( 1,-1, 1), vec3( 1,-1,-1), vec3( 1, 1,-1),

            // left
            vec3(-1, 1, 1), vec3(-1,-1, 1), vec3(-1, 1,-1),
            vec3(-1,-1, 1), vec3(-1,-1,-1), vec3(-1, 1,-1),

            // front
            vec3( 1, 1, 1), vec3(-1, 1, 1), vec3(-1, 1,-1),
            vec3( 1, 1, 1), vec3( 1, 1,-1), vec3(-1, 1,-1),

            // back
            vec3( 1,-1, 1), vec3(-1,-1, 1), vec3(-1,-1,-1),
            vec3( 1,-1, 1), vec3( 1,-1,-1), vec3(-1,-1,-1),
            ];

        auto norm_data =
            multiElem( 6, vec3( 0, 0, 1) ) ~ // top
            multiElem( 6, vec3( 0, 0,-1) ) ~ // bottom
            multiElem( 6, vec3( 1, 0, 0) ) ~ // right
            multiElem( 6, vec3(-1, 0, 0) ) ~ // left
            multiElem( 6, vec3( 0, 1, 0) ) ~ // front
            multiElem( 6, vec3( 0,-1, 0) ); // back


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

    this( Node p )
    {
        super(p);
        clr = col4(1,0,0,1);
    }

}

import std.algorithm;
import std.array;
import std.range;

T[] multiElem(T)( size_t N, T val ) { return array( map!(a=>val)( iota(0,N) ) ); }

unittest
{
    assert( multiElem(3,"str") == [ "str", "str", "str" ] );
}
