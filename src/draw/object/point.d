module draw.object.point;

public import draw.object.base;
import des.util.logsys;
import std.file;

abstract class BasePoint : BaseDrawObject
{
protected:
    GLBuffer data;

public:
    this( SpaceNode p )
    {
        super( p, readShader( "depthpoint.glsl" ) );
        clr = col4( 0,1,0,1 );
        warn_if_empty = false;
    }

    float size( float s ) @property
    {
        glPointSize( s );
        return s;
    }

    override void draw( Camera cam )
    {
        shader.setUniform!mat4( "prj", cam.projection.matrix * cam.resolve(this) );
        shader.setUniform!vec4( "color", vec4(clr) );

        drawArrays( DrawMode.POINTS );
    }

protected:

    override void prepareBuffers()
    {
        data = createData();

        connect( data.elementCountCB, &setDrawCount );
        auto loc = shader.getAttribLocation( "data" );
        setAttribPointer( data, loc, 4, GLType.FLOAT );
    }

    abstract GLBuffer createData();
}

class Point : BasePoint
{
protected:

    vec4[] pnt_data;

public:

    this( SpaceNode p ) { super( p ); }

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

protected:

    void updateBuffer()
    {
        if( pnt_data.length )
            data.setData( pnt_data );
    }

    override GLBuffer createData()
    { return newEMM!GLBuffer( GLBuffer.Target.ARRAY_BUFFER ); }
}

class CalcPoint : BasePoint
{
protected:

    CLGLEnv env;

public:

    CalcBuffer cdata;

    this( CLGLEnv e, SpaceNode p )
    {
        env = e;
        super( p );
    }

protected:

    override GLBuffer createData()
    { return cdata = newEMM!CalcBuffer( env ); }
}
