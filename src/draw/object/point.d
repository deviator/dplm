module draw.object.point;

public import draw.object.base;
import draw.calcbuffer;
import des.util.logger;

class Point : BaseDrawObject
{
protected:

    vec4[] pnt_data;
    GLBuffer data;

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
            data.setData( pnt_data );
    }

    override void prepareBuffers()
    {
        auto b = createArrayBuffersFromAttributeInfo(
                APInfo( "data", 4, GLType.FLOAT ) );
        data = b["data"];
    }
}

class CalcPoint : BaseDrawObject
{
protected:

public:

    CalcBuffer data;

    this( Node p )
    {
        logger = new InstanceFullLogger(this, "ddots");

        super( p, SS_DepthPoint );
        clr = col4( 0,1,0, 1 );
        warn_if_empty = false;
    }

    void size( float s ) { glPointSize(s); }

    override void draw( Camera cam )
    {
        shader.setUniformMat( "prj", cam(this) );
        shader.setUniformVec( "color", clr );

        drawArrays( DrawMode.POINTS );
    }

protected:

    override void prepareBuffers()
    {
        data = newEMM!CalcBuffer;
        data.elementCountCallback = &setDrawCount;

        auto loc = shader.getAttribLocation( "data" );
        setAttribPointer( data, loc, 4, GLType.FLOAT );
    }
}
