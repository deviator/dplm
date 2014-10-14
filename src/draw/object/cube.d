module draw.object.cube;

public import draw.object.base;

class Cube : BaseShadeObject
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

    override void drawFunc() { drawArrays( DrawMode.TRIANGLES ); }

public:

    this( Node p ) { super(p); }
}

class ColumnCube : Cube
{
    this( Node p ) { super(p); }

    void setOffsetAndSize( vec3 pos, vec3 size )
    {
        auto offset = pos + vec3(0,0,size.z/2);
        mtr = mat4.diag(vec4(size/2,1)).setCol(3,vec4(offset,1));
    }
}

class CellCube : Cube
{
    this( Node p ) { super(p); }

    void setOffsetAndSize( vec3 pos, vec3 size )
    {
        auto offset = pos + size/2;
        mtr = mat4.diag(vec4(size/2,1)).setCol(3,vec4(offset,1));
    }

    void setCorners( vec3 a, vec3 b )
    { setOffsetAndSize( a, b-a ); }
}

class MultiCube : BaseShadeObject
{
protected:

    override void fillBuffers() { }

    vec3[] full_pos_data,
           full_norm_data;

    override void drawFunc() { drawArrays( DrawMode.TRIANGLES ); }

public:

    this( Node p ) { super(p); }

    void addCube( vec3 offset, vec3 size )
    {
        auto p1 = offset + size * vec3(0,0,1);
        auto p2 = offset + size * vec3(0,1,1);
        auto p3 = offset + size * vec3(1,1,1);
        auto p4 = offset + size * vec3(1,0,1);

        auto p5 = offset + size * vec3(0,0,0);
        auto p6 = offset + size * vec3(0,1,0);
        auto p7 = offset + size * vec3(1,1,0);
        auto p8 = offset + size * vec3(1,0,0);

        auto pos_data = [
            p1, p4, p3,
            p1, p3, p2,

            p5, p6, p7,
            p5, p7, p8,

            p8, p3, p4,
            p8, p7, p3,

            p6, p1, p2,
            p6, p5, p1,

            p5, p4, p1,
            p5, p8, p4,

            p7, p2, p3,
            p7, p6, p2
            ];

        full_pos_data ~= pos_data;
        pos.setData( full_pos_data, GLBuffer.Usage.DYNAMIC_DRAW );

        if( norm !is null )
        {
            auto norm_data =
                multiElem( 6, vec3( 0, 0, 1) ) ~ // top
                multiElem( 6, vec3( 0, 0,-1) ) ~ // bottom
                multiElem( 6, vec3( 1, 0, 0) ) ~ // right
                multiElem( 6, vec3(-1, 0, 0) ) ~ // left
                multiElem( 6, vec3( 0, 1, 0) ) ~ // front
                multiElem( 6, vec3( 0,-1, 0) ); // back

            full_norm_data ~= norm_data;

            norm.setData( full_norm_data, GLBuffer.Usage.DYNAMIC_DRAW );
        }
    }

    void reset()
    {
        full_pos_data.length = 0;
        full_norm_data.length = 0;
    }
}
