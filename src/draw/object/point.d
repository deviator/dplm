module draw.object.point;

public import draw.object.base;

class Point : BaseDrawObject
{
protected:
    GLBuffer pnt;

    vec4[] pnt_data;

public:

    this( Node p )
    {
        super( p, SS_DepthPoint );
        clr = col4( 0,1,0, 1 );
        warn_if_empty = false;
    }

    void set( vec4[] p )
    {
        pnt_data = p.dup;
        updateBuffer();
    }

    void add( vec4[] p )
    {
        pnt_data ~= p;
        updateBuffer();
    }

    void reset() { pnt_data.length = 0; }

    void size( float s ) { glPointSize(s); }

    override void draw( Camera cam )
    {
        shader.setUniformMat( "prj", cam(this) );
        shader.setUniformVec( "color", clr );

        if( pnt_data.length )
            drawArrays( DrawMode.POINTS );
    }

protected:

    void updateBuffer()
    {
        if( pnt_data.length )
            pnt.setData( pnt_data );
    }

    override void prepareBuffers()
    {
        auto b = createArrayBuffersFromAttributeInfo(
                APInfo( "data", 4, GLType.FLOAT ) );

        pnt = b["data"];
    }
}

