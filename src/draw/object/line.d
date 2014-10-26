module draw.object.line;

public import draw.object.base;
import draw.calcbuffer;

class Line : BaseDrawObject
{
protected:

    vec3[] pnt_data;
    GLBuffer data;

public:

    this( Node p=null )
    {
        super( p, SS_Line );
        clr = col4( 1,0,0, 1 );
        warn_if_empty = false;
    }

    void set( vec3[] p )
    {
        pnt_data = p.dup;
        updateBuffer();
    }

    void add( vec3[] p )
    {
        pnt_data ~= p;
        updateBuffer();
    }

    void reset() { pnt_data.length = 0; }

    void width( float s ) { glLineWidth(s); }

    override void draw( Camera cam )
    {
        shader.setUniformMat( "prj", cam(this) );
        shader.setUniformVec( "color", clr );

        if( pnt_data.length )
            drawArrays( DrawMode.LINE_STRIP );
    }

protected:

    void updateBuffer()
    {
        if( pnt_data.length )
            data.setData( pnt_data );
    }

    override void prepareBuffers()
    {
        auto b = createArrayBuffersFromAttributeInfo(
                APInfo( "pos", 3, GLType.FLOAT ) );
        data = b["pos"];
    }
}
